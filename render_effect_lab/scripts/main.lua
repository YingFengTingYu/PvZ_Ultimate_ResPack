api.log("render_effect_lab loaded")

local launcher_id = "render_effect_lab.launcher"
local panel_id = "render_effect_lab.panel"
local loader_id = "render_effect_lab.loader"

local translations = {
    en = {
        title = "RenderEffect Visual Lab",
        launcher = "FX",
        effect = "Visual style",
        enabled = "Enable effect",
        auto_rotate = "Auto DJ (change every 8 seconds)",
        whole_lawn = "Include lawn background",
        wave_reactive = "Wave alarm burst",
        strength = "Strength: %d%%",
        speed = "Animation speed: %.2fx",
        close = "Close",
        disabled = "Effect disabled",
        active = "Active: %s",
        alarm_active = "Wave alarm! Returning to %s",
        unavailable = "RenderEffect unavailable on this backend",
        missing = "EFFECT_MOOD_MACHINE could not be loaded",
        invalid = "No compatible technique: %s",
        pass_error = "The selected technique is not single-pass",
        panel_error = "Could not open the visual lab",
        candy = "Candy Rush",
        arcade = "Arcade CRT",
        moonlight = "Moonlit Ghosts",
        thermal = "Thermal Vision",
        xray = "X-Ray Invert",
        glitch = "Glitch Party",
        comic = "Comic Book",
        alarm = "Wave Alarm"
    },
    zh_cn = {
        title = "RenderEffect 视觉实验室",
        launcher = "特效",
        effect = "视觉风格",
        enabled = "启用特效",
        auto_rotate = "自动 DJ（每 8 秒换台）",
        whole_lawn = "连草坪背景一起处理",
        wave_reactive = "每波触发尸潮警报",
        strength = "强度：%d%%",
        speed = "动画速度：%.2f 倍",
        close = "收起",
        disabled = "特效已关闭",
        active = "正在使用：%s",
        alarm_active = "尸潮警报！稍后返回「%s」",
        unavailable = "当前图形后端不支持 RenderEffect",
        missing = "无法加载 EFFECT_MOOD_MACHINE",
        invalid = "当前后端没有兼容的 technique：%s",
        pass_error = "所选 technique 不是单 pass",
        panel_error = "无法打开视觉实验室",
        candy = "糖果风暴",
        arcade = "街机显像管",
        moonlight = "月光幽灵",
        thermal = "热成像",
        xray = "X 光反相",
        glitch = "故障派对",
        comic = "漫画网点",
        alarm = "尸潮警报"
    }
}

local language = Resources.GetLanguage()
local localized = translations[language] or translations.en

local function tr(key, ...)
    local value = localized[key] or translations.en[key] or key
    if select("#", ...) > 0 then
        return string.format(value, ...)
    end
    return value
end

local modes = {
    { technique = "CandyRush", label = tr("candy") },
    { technique = "ArcadeCRT", label = tr("arcade") },
    { technique = "Moonlight", label = tr("moonlight") },
    { technique = "Thermal", label = tr("thermal") },
    { technique = "XRay", label = tr("xray") },
    { technique = "GlitchParty", label = tr("glitch") },
    { technique = "ComicBook", label = tr("comic") },
    { technique = "WaveAlarm", label = tr("alarm") }
}

local mode_labels = {}
for index, mode in ipairs(modes) do
    mode_labels[index] = mode.label
end

local white = { r = 255, g = 255, b = 255, a = 255 }
local muted = { r = 205, g = 208, b = 220, a = 255 }
local accent = { r = 111, g = 235, b = 255, a = 255 }
local panel_background = { r = 20, g = 24, b = 35, a = 228 }
local panel_border = { r = 77, g = 181, b = 205, a = 245 }

local selected_mode = 1
local enabled = true
local auto_rotate = false
local whole_lawn = false
local wave_reactive = true
local strength = 0.85
local animation_speed = 1.0
local animation_time = 0.0
local auto_ticks = 0
local alarm_ticks = 0

local effect = nil
local active_effect = nil
local active_run_handle = nil
local active_pass = nil
local active_owner = nil
local unavailable_reason = nil
local logged_messages = {}

local function log_once(message)
    if logged_messages[message] then
        return
    end
    logged_messages[message] = true
    api.log("render_effect_lab: " .. message)
end

local function load_effect()
    if effect == nil then
        effect = Resources.GetRenderEffectByName("EFFECT_MOOD_MACHINE")
    end
    if effect == nil then
        unavailable_reason = tr("missing")
        log_once(unavailable_reason)
        return false
    end
    return true
end

local function active_mode()
    return modes[selected_mode] or modes[1]
end

local function displayed_status()
    if not enabled then
        return tr("disabled")
    end
    if unavailable_reason ~= nil then
        return unavailable_reason
    end
    local mode = active_mode()
    if wave_reactive and alarm_ticks > 0 and mode.technique ~= "WaveAlarm" then
        return tr("alarm_active", mode.label)
    end
    return tr("active", mode.label)
end

local function technique_for_frame()
    if wave_reactive and alarm_ticks > 0 then
        return "WaveAlarm"
    end
    return active_mode().technique
end

local function end_run(owner)
    if active_run_handle == nil or active_owner ~= owner then
        return
    end

    local current_effect = active_effect
    local run_handle = active_run_handle
    local pass = active_pass
    active_effect = nil
    active_run_handle = nil
    active_pass = nil
    active_owner = nil

    local pass_ok, pass_error = pcall(function()
        current_effect:EndPass(run_handle, pass)
    end)
    local end_ok, end_error = pcall(function()
        current_effect:End(run_handle)
    end)
    if not pass_ok then
        log_once("EndPass failed: " .. tostring(pass_error))
    end
    if not end_ok then
        log_once("End failed: " .. tostring(end_error))
    end
end

local function begin_run(owner, graphics)
    if not enabled or active_run_handle ~= nil then
        return false
    end
    if not RenderEffects.IsSupported() then
        unavailable_reason = tr("unavailable")
        log_once(unavailable_reason)
        return false
    end
    if not load_effect() then
        return false
    end

    local technique = technique_for_frame()
    effect:SetCurrentTechnique(technique, true)
    if effect:GetCurrentTechniqueName() == "" then
        unavailable_reason = tr("invalid", technique)
        log_once(unavailable_reason)
        return false
    end

    local alarm_envelope = 0.0
    if alarm_ticks > 0 then
        alarm_envelope = math.min(1.0, alarm_ticks / 35.0)
    end
    effect:SetFloat("EffectTime", animation_time)
    effect:SetFloat("EffectStrength", strength)
    effect:SetFloat("AlarmEnvelope", alarm_envelope)
    effect:SetFloat("ReservedValue", 0.0)

    local begin_ok, pass_count, run_handle = pcall(function()
        return effect:Begin(graphics.mRenderContext)
    end)
    if not begin_ok then
        log_once("Begin failed: " .. tostring(pass_count))
        return false
    end
    if pass_count ~= 1 then
        pcall(function()
            effect:End(run_handle)
        end)
        unavailable_reason = tr("pass_error")
        log_once(unavailable_reason)
        return false
    end

    local pass = 0
    local pass_ok, pass_error = pcall(function()
        effect:BeginPass(run_handle, pass)
    end)
    if not pass_ok then
        pcall(function()
            effect:End(run_handle)
        end)
        log_once("BeginPass failed: " .. tostring(pass_error))
        return false
    end

    unavailable_reason = nil
    active_effect = effect
    active_run_handle = run_handle
    active_pass = pass
    active_owner = owner
    return true
end

local function set_selected_mode(index)
    selected_mode = math.max(1, math.min(#modes, math.floor(index)))
    auto_ticks = 0
    api.log("render_effect_lab: " .. tr("active", active_mode().label))
end

local function build_panel()
    return {
        id = panel_id,
        x = 18,
        y = 34,
        width = 430,
        height = 548,
        zOrder = 210000,
        style = "dialog",
        title = tr("title"),
        titleColor = accent,
        tallBottom = false,
        draggable = true,
        preservePosition = true,
        children = {
            {
                type = "text",
                id = "effect_label",
                x = 40,
                y = 104,
                width = 350,
                height = 24,
                color = accent,
                text = tr("effect")
            },
            {
                type = "list",
                id = "effect_list",
                x = 40,
                y = 130,
                width = 350,
                height = 128,
                items = mode_labels,
                selectedIndex = function()
                    return selected_mode
                end,
                callback = function(action)
                    set_selected_mode(action.value)
                end
            },
            {
                type = "checkbox",
                id = "enabled",
                x = 40,
                y = 265,
                width = 350,
                height = 32,
                text = tr("enabled"),
                checked = function()
                    return enabled
                end,
                callback = function(action)
                    enabled = action.value == true
                end
            },
            {
                type = "checkbox",
                id = "auto_rotate",
                x = 40,
                y = 299,
                width = 350,
                height = 32,
                text = tr("auto_rotate"),
                checked = function()
                    return auto_rotate
                end,
                callback = function(action)
                    auto_rotate = action.value == true
                    auto_ticks = 0
                end
            },
            {
                type = "checkbox",
                id = "whole_lawn",
                x = 40,
                y = 333,
                width = 350,
                height = 32,
                text = tr("whole_lawn"),
                checked = function()
                    return whole_lawn
                end,
                callback = function(action)
                    whole_lawn = action.value == true
                end
            },
            {
                type = "checkbox",
                id = "wave_reactive",
                x = 40,
                y = 367,
                width = 350,
                height = 32,
                text = tr("wave_reactive"),
                checked = function()
                    return wave_reactive
                end,
                callback = function(action)
                    wave_reactive = action.value == true
                    if not wave_reactive then
                        alarm_ticks = 0
                    end
                end
            },
            {
                type = "text",
                id = "strength_label",
                x = 40,
                y = 402,
                width = 350,
                height = 22,
                color = white,
                text = function()
                    return tr("strength", math.floor(strength * 100.0 + 0.5))
                end
            },
            {
                type = "slider",
                id = "strength_slider",
                x = 32,
                y = 421,
                width = 366,
                height = 38,
                min = 0.0,
                max = 1.0,
                step = 0.05,
                value = function()
                    return strength
                end,
                callback = function(action)
                    strength = action.value
                end
            },
            {
                type = "text",
                id = "speed_label",
                x = 40,
                y = 459,
                width = 350,
                height = 22,
                color = white,
                text = function()
                    return tr("speed", animation_speed)
                end
            },
            {
                type = "slider",
                id = "speed_slider",
                x = 32,
                y = 478,
                width = 194,
                height = 38,
                min = 0.25,
                max = 3.0,
                step = 0.25,
                value = function()
                    return animation_speed
                end,
                callback = function(action)
                    animation_speed = action.value
                end
            },
            {
                type = "text",
                id = "status",
                x = 40,
                y = 513,
                width = 210,
                height = 28,
                color = muted,
                maxLines = 2,
                text = displayed_status
            },
            {
                type = "button",
                style = "stone",
                id = "close",
                x = 252,
                y = 489,
                width = 138,
                height = 42,
                text = tr("close"),
                callback = function()
                    LuaUI.SetVisible(panel_id, false)
                    LuaUI.SetVisible(launcher_id, true)
                    LuaUI.BringToFront(launcher_id)
                end
            }
        }
    }
end

local function open_panel()
    if not LuaUI.IsMounted(panel_id) and not LuaUI.Mount("screen", build_panel()) then
        log_once(tr("panel_error"))
        return
    end
    LuaUI.SetVisible(panel_id, true)
    LuaUI.BringToFront(panel_id)
    LuaUI.SetVisible(launcher_id, false)
end

local function build_launcher()
    return {
        id = launcher_id,
        x = 18,
        y = 146,
        width = 82,
        height = 48,
        zOrder = 210001,
        draggable = true,
        preservePosition = true,
        dragRegionWidth = 82,
        dragRegionHeight = 48,
        background = { r = 9, g = 18, b = 27, a = 218 },
        border = panel_border,
        callback = open_panel,
        children = {
            {
                type = "text",
                id = "launcher_text",
                x = 0,
                y = 0,
                width = 82,
                height = 48,
                color = accent,
                horizontalAlignment = "center",
                verticalAlignment = "center",
                text = tr("launcher")
            }
        }
    }
end

local function mount_launcher()
    if LuaUI.IsMounted(launcher_id) then
        return true
    end
    return LuaUI.Mount("screen", build_launcher())
end

local function build_loader()
    return {
        id = loader_id,
        x = 0,
        y = 0,
        width = 1,
        height = 1,
        visible = false,
        background = { r = 0, g = 0, b = 0, a = 0 },
        border = { r = 0, g = 0, b = 0, a = 0 },
        children = {
            {
                type = "text",
                id = "loader_tick",
                x = 0,
                y = 0,
                width = 1,
                height = 1,
                text = function()
                    mount_launcher()
                    return ""
                end
            }
        }
    }
end

local function hook(id, phase, callback)
    if api.has_hook(id) then
        api.hook(id, phase, callback)
    else
        log_once("missing hook " .. id)
    end
end

hook("Lawn.Board.Update()", "prefix", function(board)
    mount_launcher()
    animation_time = animation_time + 0.01 * animation_speed

    if alarm_ticks > 0 then
        alarm_ticks = alarm_ticks - 1
    end
    if enabled and auto_rotate then
        auto_ticks = auto_ticks + 1
        if auto_ticks >= 800 then
            set_selected_mode((selected_mode % #modes) + 1)
        end
    end
    return true
end)

hook("Lawn.Board.SpawnZombieWave()", "postfix", function(board)
    if enabled and wave_reactive then
        alarm_ticks = 90
    end
end)

hook("Lawn.Board.DrawBackdrop(Sexy.Graphics)", "prefix", function(board, graphics)
    if whole_lawn then
        begin_run("backdrop", graphics)
    end
end)

hook("Lawn.Board.DrawBackdrop(Sexy.Graphics)", "postfix", function(board, graphics)
    end_run("backdrop")
end)

hook("Lawn.Board.DrawGameObjects(Sexy.Graphics)", "prefix", function(board, graphics)
    begin_run("game_objects", graphics)
end)

hook("Lawn.Board.DrawGameObjects(Sexy.Graphics)", "postfix", function(board, graphics)
    end_run("game_objects")
end)

if not LuaUI.Mount("screen", build_loader()) then
    log_once("loader UI will retry from Board.Update")
end

mount_launcher()