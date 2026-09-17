api.log("music_box LuaUI mod loaded")

local launcher_id = "music_box.launcher"
local panel_id = "music_box.panel"
local loader_id = "music_box.loader"

local current_app = nil
local launcher_created = false
local selected_index = 1

local translations = {
    en = {
        title = "Music Box",
        tunes = "MusicTune tracks (%d)",
        current = "Now playing: %s",
        nothing = "Nothing",
        progress = "Progress",
        drums = "Enable drums",
        drums_on = "Drums enabled",
        drums_off = "Drums disabled",
        previous = "Previous",
        next = "Next",
        pause = "Pause",
        resume = "Resume",
        play = "Play",
        stop = "Stop",
        close = "Close",
        ready = "Choose a tune on the left",
        playing = "Playing %s",
        paused = "Paused",
        resumed = "Resumed",
        stopped = "Stopped",
        music_unavailable = "Music is not initialized yet",
        panel_error = "Could not open the music box"
    },
    zh_cn = {
        title = "音乐盒",
        tunes = "MusicTune 曲目（%d）",
        current = "正在播放：%s",
        nothing = "无",
        progress = "播放进度",
        drums = "启用鼓点",
        drums_on = "已开启鼓点",
        drums_off = "已关闭鼓点",
        previous = "上一首",
        next = "下一首",
        pause = "暂停",
        resume = "继续",
        play = "播放",
        stop = "停止",
        close = "关闭",
        ready = "请在左侧选择曲目",
        playing = "正在播放 %s",
        paused = "已暂停",
        resumed = "已继续",
        stopped = "已停止",
        music_unavailable = "音乐系统尚未初始化",
        panel_error = "无法打开音乐盒"
    }
}

local language = Resources.GetLanguage()
local localized = translations[language] or translations.en

local function tr(key, ...)
    local text = localized[key] or translations.en[key] or key
    if select("#", ...) > 0 then
        return string.format(text, ...)
    end
    return text
end

local white = { r = 255, g = 255, b = 255, a = 255 }
local muted = { r = 203, g = 203, b = 213, a = 255 }
local accent = { r = 244, g = 210, b = 105, a = 255 }
local panel_background = { r = 28, g = 31, b = 38, a = 220 }
local panel_border = { r = 113, g = 103, b = 77, a = 235 }

local excluded_tunes = {
    MainMusic = true,
    Drums = true,
    Hihats = true,
    MusicTuneCount = true,
    DrumBase = true
}

local function pretty_enum_name(name)
    local result = string.gsub(name, "(%u)(%u%l)", "%1 %2")
    return string.gsub(result, "(%l)(%u)", "%1 %2")
end

local tune_entries = {}
local tune_by_value = {}
for name, value in pairs(MusicTune) do
    if type(name) == "string" and
        type(value) == "number" and
        value >= 0 and
        value < MusicTune.DrumBase and
        not excluded_tunes[name] then
        tune_entries[#tune_entries + 1] = {
            enum_name = name,
            label = pretty_enum_name(name),
            value = value
        }
    end
end

table.sort(tune_entries, function(left, right)
    if left.value == right.value then
        return left.enum_name < right.enum_name
    end
    return left.value < right.value
end)

for index, entry in ipairs(tune_entries) do
    tune_by_value[entry.value] = entry
    entry.index = index
end

local status_text = tr("ready")

local function remember_app(action)
    if action ~= nil and action.app ~= nil then
        current_app = action.app
    end
    return current_app
end

local function get_music(action)
    local app = remember_app(action)
    if app == nil then
        return nil
    end
    return app.mMusic
end

local function set_status(text)
    status_text = text
    api.log("music_box: " .. text)
end

local function format_time(seconds)
    local safe_seconds = math.max(0, math.floor((seconds or 0) + 0.5))
    return string.format("%d:%02d", math.floor(safe_seconds / 60), safe_seconds % 60)
end

local function current_entry(music)
    if music == nil then
        return nil
    end
    return tune_by_value[music.mCurMusicTune]
end

local function play_entry(action, entry)
    local music = get_music(action)
    if music == nil then
        set_status(tr("music_unavailable"))
        return false
    end

    music:MakeSureMusicIsPlaying(entry.value)
    selected_index = entry.index
    set_status(tr("playing", entry.label))
    return true
end

local function drums_available(music)
    return music ~= nil and
        music.mCurMusicTune ~= MusicTune.None and
        music.mCurMusicFileDrums ~= MusicTune.None
end

local function set_drums_enabled(action, enabled)
    local music = get_music(action)
    if not drums_available(music) then
        return
    end

    music.mBurstOverride = enabled and 1 or 2
    if enabled then
        music:StartBurst()
    end
    set_status(enabled and tr("drums_on") or tr("drums_off"))
end

local function step_tune(action, delta)
    if #tune_entries == 0 then
        return
    end

    local music = get_music(action)
    local playing = current_entry(music)
    if playing ~= nil then
        selected_index = playing.index
    end

    selected_index = ((selected_index - 1 + delta) % #tune_entries) + 1
    play_entry(action, tune_entries[selected_index])
end

local function build_tune_buttons()
    local children = {}
    for index, entry in ipairs(tune_entries) do
        local tune = entry.value
        local label = entry.label
        local tune_index = index
        children[#children + 1] = {
            type = "button",
            style = "stone",
            id = "tune_" .. entry.enum_name,
            x = 4,
            y = (index - 1) * 42,
            width = 330,
            height = 36,
            text = function(action)
                local music = get_music(action)
                local prefix = music ~= nil and music.mCurMusicTune == tune and "▶ " or ""
                return prefix .. label
            end,
            callback = function(action)
                play_entry(action, tune_entries[tune_index])
            end
        }
    end
    return children
end

local function control_button(id, text, x, callback)
    return {
        type = "button",
        style = "stone",
        id = id,
        x = x,
        y = 298,
        width = 82,
        height = 42,
        text = text,
        callback = callback
    }
end

local function build_panel()
    return {
        id = panel_id,
        layout = {
            mode = "anchored",
            anchorX = 0.5,
            anchorY = 0.5,
            width = 860,
            height = 548
        },
        zOrder = 200100,
        style = "dialog",
        title = tr("title"),
        tallBottom = false,
        draggable = true,
        preservePosition = true,
        children = {
            {
                type = "panel",
                id = "left_panel",
                x = 34,
                y = 102,
                width = 386,
                height = 354,
                background = panel_background,
                border = panel_border,
                children = {
                    {
                        type = "text",
                        id = "tune_title",
                        x = 14,
                        y = 10,
                        width = 354,
                        height = 26,
                        color = accent,
                        text = tr("tunes", #tune_entries)
                    },
                    {
                        type = "scroll",
                        id = "tune_scroll",
                        x = 14,
                        y = 42,
                        width = 354,
                        height = 292,
                        bounce = false,
                        wheelScrollAmount = 84,
                        children = build_tune_buttons()
                    }
                }
            },
            {
                type = "panel",
                id = "right_panel",
                x = 440,
                y = 102,
                width = 386,
                height = 354,
                background = panel_background,
                border = panel_border,
                children = {
                    {
                        type = "image",
                        id = "phonograph",
                        x = 159,
                        y = 14,
                        width = 68,
                        height = 68,
                        image = "IMAGE_PHONOGRAPH"
                    },
                    {
                        type = "text",
                        id = "current_tune",
                        x = 18,
                        y = 88,
                        width = 350,
                        height = 32,
                        color = white,
                        horizontalAlignment = "center",
                        text = function(action)
                            local entry = current_entry(get_music(action))
                            return tr("current", entry == nil and tr("nothing") or entry.label)
                        end
                    },
                    {
                        type = "text",
                        id = "progress_title",
                        x = 22,
                        y = 132,
                        width = 342,
                        height = 24,
                        color = accent,
                        text = tr("progress")
                    },
                    {
                        type = "slider",
                        id = "progress",
                        x = 18,
                        y = 153,
                        width = 350,
                        height = 48,
                        min = 0,
                        max = 100,
                        step = 0.1,
                        enabled = false,
                        value = function(action)
                            local music = get_music(action)
                            return music == nil and 0 or music:GetMusicProgress() * 100
                        end
                    },
                    {
                        type = "text",
                        id = "progress_time",
                        x = 22,
                        y = 202,
                        width = 342,
                        height = 24,
                        color = muted,
                        horizontalAlignment = "center",
                        text = function(action)
                            local music = get_music(action)
                            if music == nil then
                                return "0:00 / 0:00"
                            end
                            return format_time(music:GetMusicPositionSeconds()) ..
                                " / " .. format_time(music:GetMusicDurationSeconds())
                        end
                    },
                    {
                        type = "checkbox",
                        id = "has_drums",
                        x = 105,
                        y = 238,
                        width = 180,
                        height = 38,
                        text = tr("drums"),
                        enabled = function(action)
                            return drums_available(get_music(action))
                        end,
                        checked = function(action)
                            local music = get_music(action)
                            return drums_available(music) and music.mBurstOverride == 1
                        end,
                        onChange = function(action)
                            set_drums_enabled(action, action.value)
                        end
                    },
                    control_button("previous", tr("previous"), 16, function(action)
                        step_tune(action, -1)
                    end),
                    control_button("pause", function(action)
                        local music = get_music(action)
                        if music == nil or music.mCurMusicTune == MusicTune.None then
                            return tr("play")
                        end
                        return music.mPaused and tr("resume") or tr("pause")
                    end, 108, function(action)
                        local music = get_music(action)
                        if music == nil then
                            set_status(tr("music_unavailable"))
                        elseif music.mCurMusicTune == MusicTune.None then
                            play_entry(action, tune_entries[selected_index])
                        else
                            local pause = not music.mPaused
                            music:GameMusicPause(pause, true)
                            set_status(pause and tr("paused") or tr("resumed"))
                        end
                    end),
                    control_button("next", tr("next"), 200, function(action)
                        step_tune(action, 1)
                    end),
                    control_button("stop", tr("stop"), 292, function(action)
                        local music = get_music(action)
                        if music ~= nil then
                            music.mBurstOverride = -1
                            music:StopAllMusic()
                            set_status(tr("stopped"))
                        end
                    end)
                }
            },
            {
                type = "text",
                id = "status",
                x = 40,
                y = 470,
                width = 590,
                height = 40,
                color = muted,
                verticalAlignment = "center",
                text = function()
                    return status_text
                end
            },
            {
                type = "button",
                style = "stone",
                id = "close",
                x = 660,
                y = 468,
                width = 160,
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

local function open_panel(action)
    local app = remember_app(action)
    if app == nil or app.mMusic == nil then
        set_status(tr("music_unavailable"))
        return
    end

    if not LuaUI.IsMounted(panel_id) and not LuaUI.Mount("screen", build_panel()) then
        set_status(tr("panel_error"))
        return
    end

    LuaUI.SetVisible(launcher_id, false)
    LuaUI.SetVisible(panel_id, true)
    LuaUI.BringToFront(panel_id)
end

local function build_launcher()
    return {
        id = launcher_id,
        x = 18,
        y = 92,
        width = 84,
        height = 84,
        zOrder = 200101,
        draggable = true,
        preservePosition = true,
        dragRegionWidth = 84,
        dragRegionHeight = 84,
        background = { r = 0, g = 0, b = 0, a = 0 },
        border = { r = 0, g = 0, b = 0, a = 0 },
        callback = open_panel,
        children = {
            {
                type = "image",
                id = "launcher_phonograph",
                x = 8,
                y = 8,
                width = 68,
                height = 68,
                image = "IMAGE_PHONOGRAPH"
            }
        }
    }
end

local function mount_launcher()
    if LuaUI.IsMounted(launcher_id) then
        return true
    end
    if Resources.GetImageByName("IMAGE_PHONOGRAPH") == nil then
        return false
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
                    if not launcher_created and mount_launcher() then
                        launcher_created = true
                        api.log("music_box launcher mounted")
                    end
                    return ""
                end
            }
        }
    }
end

if not LuaUI.Mount("screen", build_loader()) then
    set_status(tr("panel_error"))
end
