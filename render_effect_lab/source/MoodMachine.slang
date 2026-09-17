Sampler2D<float4> SourceTexture;

cbuffer MoodMachineConstants
{
    // Keep these as four scalar parameters. D3D9 maps the first four PopFX
    // constants to c0.x, c1.x, c2.x and c3.x instead of packing a float4.
    float EffectTime;
    float EffectStrength;
    float AlarmEnvelope;
    float ReservedValue;
};

struct VertexInput
{
    float2 Position : POSITION;
    float2 TexCoord : TEXCOORD0;
    float4 Color : COLOR0;
};

struct PixelInput
{
    float4 Position : SV_Position;
    float2 TexCoord : TEXCOORD0;
    float4 Color : COLOR0;
    float2 ClipPosition : TEXCOORD1;
};

PixelInput VSMain(VertexInput input)
{
    PixelInput output;
    output.Position = float4(input.Position, 0.0f, 1.0f);
    output.TexCoord = input.TexCoord;
    output.Color = input.Color;
    output.ClipPosition = input.Position;
    return output;
}

float Luminance(float3 color)
{
    return dot(color, float3(0.299f, 0.587f, 0.114f));
}

float Hash(float value)
{
    return frac(sin(value * 12.9898f) * 43758.5453f);
}

float3 RotateHue(float3 color, float angle)
{
    const float3 axis = float3(0.577350269f, 0.577350269f, 0.577350269f);
    float cosine = cos(angle);
    float sine = sin(angle);
    return color * cosine + cross(axis, color) * sine + axis * dot(axis, color) * (1.0f - cosine);
}

float4 SampleSource(PixelInput input)
{
    return SourceTexture.Sample(input.TexCoord) * input.Color;
}

float4 Finish(float4 source, float3 styled)
{
    float strength = saturate(EffectStrength);
    return float4(lerp(source.rgb, saturate(styled), strength), source.a);
}

float4 PSCandyRush(PixelInput input) : SV_Target
{
    float4 source = SampleSource(input);
    float wave = sin(EffectTime * 2.4f + input.ClipPosition.x * 4.0f - input.ClipPosition.y * 2.0f);
    float angle = EffectTime * 0.9f + input.ClipPosition.x * 1.6f + input.ClipPosition.y * 0.7f;
    float3 rotated = saturate(RotateHue(source.rgb, angle));
    float luminance = Luminance(rotated);
    float3 candy = saturate(luminance.xxx + (rotated - luminance.xxx) * 1.65f);
    candy *= 0.98f + wave * 0.10f;
    return Finish(source, candy);
}

float4 PSArcadeCRT(PixelInput input) : SV_Target
{
    float4 source = SampleSource(input);
    float levels = 5.0f;
    float3 poster = floor(source.rgb * levels + 0.5f) / levels;
    float scanline = 0.82f + 0.18f * (0.5f + 0.5f * sin((input.ClipPosition.y + 1.0f) * 260.0f));
    float2 vignettePosition = input.ClipPosition * float2(0.62f, 0.82f);
    float vignette = saturate(1.08f - dot(vignettePosition, vignettePosition) * 0.34f);
    float phosphor = 0.96f + 0.04f * sin((input.ClipPosition.x + 1.0f) * 520.0f + EffectTime * 3.0f);
    return Finish(source, poster * scanline * vignette * phosphor * 1.12f);
}

float4 PSMoonlight(PixelInput input) : SV_Target
{
    float4 source = SampleSource(input);
    float luminance = Luminance(source.rgb);
    float shimmer = 0.93f + 0.07f * sin(EffectTime * 1.7f + input.ClipPosition.x * 3.0f + input.ClipPosition.y * 5.0f);
    float3 moon = float3(luminance * 0.34f, luminance * 0.67f, luminance * 1.18f);
    moon += float3(0.02f, 0.05f, 0.13f) * saturate((luminance - 0.35f) * 2.0f);
    return Finish(source, moon * shimmer);
}

float4 PSThermal(PixelInput input) : SV_Target
{
    float4 source = SampleSource(input);
    float luminance = saturate(Luminance(source.rgb));
    float3 heat = float3(0.015f, 0.0f, 0.055f);
    heat = lerp(heat, float3(0.38f, 0.0f, 0.68f), smoothstep(0.05f, 0.34f, luminance));
    heat = lerp(heat, float3(0.96f, 0.03f, 0.02f), smoothstep(0.30f, 0.62f, luminance));
    heat = lerp(heat, float3(1.0f, 0.82f, 0.02f), smoothstep(0.58f, 0.84f, luminance));
    heat = lerp(heat, float3(1.0f, 1.0f, 0.92f), smoothstep(0.82f, 1.0f, luminance));
    heat *= 0.97f + 0.03f * sin(EffectTime * 4.0f + input.ClipPosition.y * 8.0f);
    return Finish(source, heat);
}

float4 PSXRay(PixelInput input) : SV_Target
{
    float4 source = SampleSource(input);
    float3 inverted = 1.0f - source.rgb;
    float3 contrast = saturate((inverted - 0.5f) * 1.75f + 0.5f);
    float luminance = Luminance(contrast);
    float pulse = 0.96f + 0.04f * sin(EffectTime * 2.6f + input.ClipPosition.x * 5.0f);
    float3 xray = lerp(contrast * float3(0.55f, 0.86f, 1.18f), luminance.xxx, 0.18f);
    return Finish(source, xray * pulse);
}

float4 PSGlitchParty(PixelInput input) : SV_Target
{
    float4 source = SampleSource(input);
    float timeSlice = floor(EffectTime * 13.0f);
    float band = floor((input.ClipPosition.y + 1.0f) * 24.0f);
    float bandNoise = Hash(band + timeSlice * 31.0f);
    float glitchMask = step(0.70f, bandNoise);
    float pixelNoise = Hash(floor((input.ClipPosition.x + 1.0f) * 90.0f) + band * 17.0f + timeSlice * 7.0f);
    float3 swapped = source.gbr;
    float3 glitch = lerp(source.rgb, swapped, glitchMask * 0.82f);
    glitch += (pixelNoise - 0.5f) * glitchMask * 0.22f;
    float brightStripe = step(0.94f, frac((input.ClipPosition.y + 1.0f) * 46.0f + EffectTime * 5.0f));
    glitch += float3(0.08f, 0.0f, 0.12f) * brightStripe;
    return Finish(source, glitch);
}

float4 PSComicBook(PixelInput input) : SV_Target
{
    float4 source = SampleSource(input);
    float luminance = Luminance(source.rgb);
    float3 saturated = saturate(luminance.xxx + (source.rgb - luminance.xxx) * 1.55f);
    float3 poster = floor(saturated * 5.0f + 0.5f) / 5.0f;
    float2 dotCell = frac((input.ClipPosition + 1.0f) * float2(92.0f, 55.0f)) - 0.5f;
    float dotDistance = dot(dotCell, dotCell);
    float inkDot = step(0.09f + luminance * 0.15f, dotDistance);
    float ink = lerp(0.72f, 1.0f, inkDot);
    return Finish(source, poster * ink * 1.08f);
}

float4 PSWaveAlarm(PixelInput input) : SV_Target
{
    float4 source = SampleSource(input);
    float luminance = Luminance(source.rgb);
    float pulse = 0.55f + 0.45f * (0.5f + 0.5f * sin(EffectTime * 9.0f));
    pulse = saturate(pulse + AlarmEnvelope * 0.18f);
    float sweepPosition = frac(EffectTime * 0.34f) * 2.4f - 1.2f;
    float sweep = saturate(1.0f - abs(input.ClipPosition.y - sweepPosition) * 8.0f);
    float3 alarm = float3(luminance * (0.72f + pulse * 0.55f), luminance * 0.08f, luminance * 0.04f);
    alarm += float3(0.42f, 0.06f, 0.01f) * sweep * (1.0f + AlarmEnvelope * 0.35f);
    return Finish(source, alarm);
}