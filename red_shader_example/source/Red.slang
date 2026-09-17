Sampler2D<float4> SourceTexture;

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
};

PixelInput VSMain(VertexInput input)
{
    PixelInput output;
    output.Position = float4(input.Position, 0.0f, 1.0f);
    output.TexCoord = input.TexCoord;
    output.Color = input.Color;
    return output;
}

float4 PSMain(PixelInput input) : SV_Target
{
    float4 color = SourceTexture.Sample(input.TexCoord) * input.Color;
    float luminance = dot(color.rgb, float3(0.299f, 0.587f, 0.114f));
    color.rgb = float3(luminance, 0.0f, 0.0f);
    return color;
}
