api.log("ultimate_cheat LuaUI mod loaded")

local launcher_id = "ultimate_cheat.launcher"
local panel_id = "ultimate_cheat.panel"
local loader_id = "ultimate_cheat.loader"
local active_page = 1
local selected_plant_row = 0
local selected_plant_column = 0
local selected_zombie_row = 0
local selected_zombie_column = 0
local selected_plant = 1
local selected_zombie = 1
local sun_amount = 9999
local free_plant = false
local pause_zombie_spawning = false
local pause_sun_spawning = false
local clear_plants_frames = 0
local paused_counter = 2147483647
local saved_zombie_countdown = nil
local saved_huge_wave_countdown = nil
local saved_rise_from_grave_counter = nil
local saved_sun_countdown = nil

local translations = {
    en = {
        title = "Ultimate Cheat",
        launcher = "CHEAT",
        current_page = "Current page: %s",
        plant_page = "Plants",
        zombie_page = "Zombies",
        level = "Level",
        cleanup = "Cleanup",
        back = "Back",
        ready = "Ready",
        row = "Row: %d",
        column = "Column: %d",
        plant_coordinate_hint = "Rows and columns start at 0. Plant columns range from 0 to 8.",
        zombie_coordinate_hint = "Rows start at 0. Zombie column 9 keeps the default spawn X position.",
        plants = "Plants (%d)",
        zombies = "Zombies (%d)",
        selected = "Selected: %s",
        selected_plant = "Selected plant: %s",
        selected_zombie = "Selected zombie: %s",
        cell = "Cell",
        row_action = "Row",
        column_action = "Column",
        all = "All",
        placed_plant = "Placed plant %s (%s)",
        placed_zombie = "Placed zombie %s (%s)",
        level_controls = "Level controls",
        free_planting = "Free planting",
        pause_zombies = "Pause zombie spawning",
        pause_sun = "Pause sky sun spawning",
        on = "ON",
        off = "OFF",
        toggle_status = "%s: %s",
        sun_amount = "Sun amount: %d",
        set_sun = "Set sun",
        sun_set = "Sun set to %d",
        next_wave = "Spawn next wave",
        next_wave_done = "Spawned next wave",
        restore_mowers = "Restore mowers",
        restore_mowers_done = "Restored lawn mowers",
        clear_mowers = "Clear mowers",
        clear_mowers_done = "Cleared lawn mowers",
        cleanup_title = "Global cleanup",
        clear_plants = "Clear all plants",
        clear_zombies = "Clear all zombies",
        clearing_plants = "Clearing all plants",
        cleared_zombies = "Cleared all zombies",
        status = "Status: %s",
        panel_collapsed = "Panel collapsed",
        panel_expanded = "Panel expanded",
        launcher_mounted = "Draggable launcher mounted",
        panel_mount_error = "ERROR: LuaUI panel could not mount",
        launcher_mount_error = "ERROR: LuaUI launcher could not mount",
        error = "ERROR: %s"
    },
    zh_cn = {
        title = "精华版修改器",
        launcher = "修改",
        current_page = "当前页面：%s",
        plant_page = "植物",
        zombie_page = "僵尸",
        level = "关卡",
        cleanup = "清理",
        back = "返回",
        ready = "就绪",
        row = "行：%d",
        column = "列：%d",
        plant_coordinate_hint = "行列从 0 开始；植物列只能选择 0 至 8。",
        zombie_coordinate_hint = "行从 0 开始；僵尸列选择 9 时不额外设置横坐标。",
        plants = "植物（%d）",
        zombies = "僵尸（%d）",
        selected = "已选择：%s",
        selected_plant = "已选择植物：%s",
        selected_zombie = "已选择僵尸：%s",
        cell = "单格",
        row_action = "整行",
        column_action = "整列",
        all = "全场",
        placed_plant = "已放置植物 %s（%s）",
        placed_zombie = "已放置僵尸 %s（%s）",
        level_controls = "关卡控制",
        free_planting = "免费种植",
        pause_zombies = "暂停出怪",
        pause_sun = "暂停天空阳光",
        on = "开启",
        off = "关闭",
        toggle_status = "%s：%s",
        sun_amount = "阳光数：%d",
        set_sun = "设置阳光",
        sun_set = "阳光已设为 %d",
        next_wave = "立即进入下一波",
        next_wave_done = "已进入下一波",
        restore_mowers = "恢复小推车",
        restore_mowers_done = "已恢复小推车",
        clear_mowers = "清除小推车",
        clear_mowers_done = "已清除小推车",
        cleanup_title = "全场清理",
        clear_plants = "清除全部植物",
        clear_zombies = "清除全部僵尸",
        clearing_plants = "正在清除全部植物",
        cleared_zombies = "已清除全部僵尸",
        status = "状态：%s",
        panel_collapsed = "面板已收起",
        panel_expanded = "面板已展开",
        launcher_mounted = "可拖动入口已挂载",
        panel_mount_error = "错误：无法挂载 LuaUI 面板",
        launcher_mount_error = "错误：无法挂载 LuaUI 入口",
        error = "错误：%s"
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

local status_text = tr("ready")
local panel_background = { r = 30, g = 31, b = 43, a = 222 }
local panel_border = { r = 111, g = 112, b = 148, a = 230 }
local accent = { r = 224, g = 187, b = 98, a = 255 }
local white = { r = 255, g = 255, b = 255, a = 255 }

local lawn_name_cache = {}
local lawn_translation_definition = nil

local function resolve_plant_name(value)
    return Plant.GetNameString(value, SeedType.None)
end

local function translate_lawn_name_key(name_key)
    local cached = lawn_name_cache[name_key]
    if cached ~= nil then
        return cached
    end

    if lawn_translation_definition == nil then
        local ok, definition = pcall(Plant.GetPlantDefinition, SeedType.Peashooter)
        if not ok or definition == nil then
            return nil
        end
        lawn_translation_definition = definition
    end

    -- Plant.GetNameString is the exposed static entry point that performs a
    -- LawnStrings lookup. Reuse one definition only for the duration of the
    -- synchronous call, then restore it before returning to the game.
    local original_name = lawn_translation_definition.mPlantName
    lawn_translation_definition.mPlantName = name_key
    local ok, translated = pcall(Plant.GetNameString, SeedType.Peashooter, SeedType.None)
    lawn_translation_definition.mPlantName = original_name

    if not ok or type(translated) ~= "string" or translated == "" or
        string.match(translated, "^<Missing ") then
        return nil
    end

    lawn_name_cache[name_key] = translated
    return translated
end

local function resolve_zombie_name(value)
    local definition = Zombie.GetZombieDefinition(value)
    if definition == nil or type(definition.mZombieName) ~= "string" or
        definition.mZombieName == "" then
        return nil
    end
    return translate_lawn_name_key(definition.mZombieName)
end

local function collect_enum(enum_table, maximum_exclusive, name_resolver)
    local entries = {}
    for name, value in pairs(enum_table) do
        if type(name) == "string" and
            type(value) == "number" and
            value >= 0 and
            value < maximum_exclusive then
            entries[#entries + 1] = { enum_name = name, name = name, value = value }
        end
    end

    table.sort(entries, function(left, right)
        if left.value == right.value then
            return left.enum_name < right.enum_name
        end
        return left.value < right.value
    end)

    local names = {}
    for index, entry in ipairs(entries) do
        if name_resolver ~= nil then
            local ok, resolved_name = pcall(name_resolver, entry.value)
            if ok and type(resolved_name) == "string" and resolved_name ~= "" then
                entry.name = resolved_name
            end
        end
        names[index] = entry.name
    end
    return entries, names
end

-- These lists are populated after LawnApp.LoadingCompleted(), when both the
-- definitions and LawnStrings are ready.
local plant_entries = {}
local plant_names = {}
local zombie_entries = {}
local zombie_names = {}
local entity_names_ready = false

local function prepare_entity_names()
    if entity_names_ready then
        return true
    end

    -- Enum values remain the source of truth for placement. Display names are
    -- read from the running game's LawnStrings through the static type tables.
    local next_plant_entries, next_plant_names = collect_enum(
        SeedType,
        SeedType.Imitater,
        resolve_plant_name)
    local next_zombie_entries, next_zombie_names = collect_enum(
        ZombieType,
        ZombieType.ZombieTypesCount,
        resolve_zombie_name)

    if #next_plant_entries == 0 or #next_zombie_entries == 0 then
        return false
    end

    plant_entries = next_plant_entries
    plant_names = next_plant_names
    zombie_entries = next_zombie_entries
    zombie_names = next_zombie_names
    selected_plant = math.min(selected_plant, #plant_entries)
    selected_zombie = math.min(selected_zombie, #zombie_entries)
    entity_names_ready = true
    return true
end

local function set_status(text)
    status_text = text
    api.log("ultimate_cheat: " .. text)
end

local function selected_plant_entry()
    return plant_entries[selected_plant]
end

local function selected_zombie_entry()
    return zombie_entries[selected_zombie]
end

local function get_automatic_max_row(board)
    -- Dirt(0) marks the unused sixth row on ordinary five-row lawns.
    if board.mPlantRow[5] == 0 then
        return 4
    end
    return 5
end

local function visit_scope(board, scope, selected_row, selected_column, callback)
    if scope == "single" then
        callback(selected_column, selected_row)
    elseif scope == "row" then
        for column = 0, 8 do
            callback(column, selected_row)
        end
    elseif scope == "column" then
        for row = 0, get_automatic_max_row(board) do
            callback(selected_column, row)
        end
    elseif scope == "all" then
        for row = 0, get_automatic_max_row(board) do
            for column = 0, 8 do
                callback(column, row)
            end
        end
    else
        error("unknown placement scope: " .. tostring(scope))
    end
end

local function place_plant(board, scope)
    local entry = selected_plant_entry()
    visit_scope(board, scope, selected_plant_row, selected_plant_column, function(column, row)
        board:AddPlant(column, row, entry.value, SeedType.None, false, true)
    end)
end

local function place_zombie(board, scope)
    local entry = selected_zombie_entry()
    visit_scope(board, scope, selected_zombie_row, selected_zombie_column, function(column, row)
        local zombie = board:AddZombieInRow(entry.value, row, -1, true)
        if zombie ~= nil and column < 9 then
            local x = board:GridToPixelX(column, row)
            zombie.mPosX = x
            zombie.mX = x
        end
    end)
end

local function clear_mowers(board)
    for row = 0, 5 do
        local mower = board:FindLawnMowerInRow(row)
        while mower ~= nil do
            mower:Die()
            mower = board:FindLawnMowerInRow(row)
        end
    end
end

local function restore_mowers(board)
    clear_mowers(board)
    board:InitLawnMowers()
    for row = 0, 5 do
        local mower = board:FindLawnMowerInRow(row)
        if mower ~= nil then
            mower.mPosX = -21
            mower.mPosY = board:GetPosYBasedOnRow(mower.mPosX + 40, row) + 23
            mower.mVisible = true
        end
    end
end

local function perform(action, success_text, callback)
    local ok, result = pcall(callback, action.board)
    if ok then
        set_status(success_text)
    else
        set_status(tr("error", tostring(result)))
    end
end

local function placement_button(id, text_key, x, y, width, entity, scope)
    return {
        type = "button",
        style = "stone",
        id = id,
        x = x,
        y = y,
        width = width,
        height = 34,
        text = tr(text_key),
        callback = function(action)
            if entity == "plant" then
                local entry = selected_plant_entry()
                perform(action, tr("placed_plant", entry.name, tr(text_key)), function(board)
                    place_plant(board, scope)
                end)
            else
                local entry = selected_zombie_entry()
                perform(action, tr("placed_zombie", entry.name, tr(text_key)), function(board)
                    place_zombie(board, scope)
                end)
            end
        end
    }
end

local function build_entity_page(entity, page_number)
    local is_plant = entity == "plant"
    local page_id = entity .. "_page"
    local title_key = is_plant and "plants" or "zombies"
    local hint_key = is_plant and "plant_coordinate_hint" or "zombie_coordinate_hint"
    local entries = is_plant and plant_entries or zombie_entries
    local names = is_plant and plant_names or zombie_names
    local selected_index = is_plant and selected_plant or selected_zombie
    local selected_row = is_plant and selected_plant_row or selected_zombie_row
    local selected_column = is_plant and selected_plant_column or selected_zombie_column
    local maximum_column = is_plant and 8 or 9

    return {
        type = "scroll",
        id = page_id,
        x = 40,
        y = 150,
        width = 350,
        height = 290,
        bounce = false,
        wheelScrollAmount = 58,
        visible = function()
            return active_page == page_number
        end,
        children = {
            {
                type = "panel",
                id = entity .. "_coordinates",
                x = 0,
                y = 0,
                width = 330,
                height = 130,
                background = panel_background,
                border = panel_border,
                children = {
                    {
                        type = "text",
                        id = entity .. "_row_value",
                        x = 10,
                        y = 7,
                        width = 90,
                        height = 24,
                        text = function()
                            local row = is_plant and selected_plant_row or selected_zombie_row
                            return tr("row", row)
                        end
                    },
                    {
                        type = "slider",
                        id = entity .. "_row_slider",
                        x = 96,
                        y = 0,
                        width = 224,
                        height = 44,
                        min = 0,
                        max = 5,
                        step = 1,
                        value = selected_row,
                        callback = function(action)
                            local value = math.floor(action.value + 0.5)
                            if is_plant then
                                selected_plant_row = value
                            else
                                selected_zombie_row = value
                            end
                        end
                    },
                    {
                        type = "text",
                        id = entity .. "_column_value",
                        x = 10,
                        y = 48,
                        width = 90,
                        height = 24,
                        text = function()
                            local column = is_plant and selected_plant_column or selected_zombie_column
                            return tr("column", column)
                        end
                    },
                    {
                        type = "slider",
                        id = entity .. "_column_slider",
                        x = 96,
                        y = 41,
                        width = 224,
                        height = 44,
                        min = 0,
                        max = maximum_column,
                        step = 1,
                        value = selected_column,
                        callback = function(action)
                            local value = math.floor(action.value + 0.5)
                            if is_plant then
                                selected_plant_column = value
                            else
                                selected_zombie_column = value
                            end
                        end
                    },
                    {
                        type = "text",
                        id = entity .. "_coordinate_hint",
                        x = 10,
                        y = 86,
                        width = 310,
                        height = 38,
                        wrap = true,
                        maxLines = 2,
                        color = { r = 205, g = 205, b = 218, a = 255 },
                        text = tr(hint_key)
                    }
                }
            },
            {
                type = "panel",
                id = entity .. "_panel",
                x = 0,
                y = 140,
                width = 330,
                height = 344,
                background = panel_background,
                border = panel_border,
                children = {
                    {
                        type = "text",
                        id = entity .. "_title",
                        x = 12,
                        y = 8,
                        width = 306,
                        height = 24,
                        color = accent,
                        text = tr(title_key, #entries)
                    },
                    {
                        type = "list",
                        id = entity .. "_list",
                        x = 12,
                        y = 34,
                        width = 306,
                        height = 202,
                        items = names,
                        selectedIndex = selected_index,
                        callback = function(action)
                            if is_plant then
                                selected_plant = math.floor(action.value)
                                set_status(tr("selected_plant", selected_plant_entry().name))
                            else
                                selected_zombie = math.floor(action.value)
                                set_status(tr("selected_zombie", selected_zombie_entry().name))
                            end
                        end
                    },
                    {
                        type = "text",
                        id = "selected_" .. entity,
                        x = 12,
                        y = 241,
                        width = 306,
                        height = 22,
                        text = function()
                            local entry = is_plant and selected_plant_entry() or selected_zombie_entry()
                            return tr("selected", entry.name)
                        end
                    },
                    placement_button(entity .. "_single", "cell", 12, 268, 145, entity, "single"),
                    placement_button(entity .. "_row", "row_action", 173, 268, 145, entity, "row"),
                    placement_button(entity .. "_column", "column_action", 12, 308, 145, entity, "column"),
                    placement_button(entity .. "_all", "all", 173, 308, 145, entity, "all")
                }
            }
        }
    }
end

local function build_level_page()
    return {
        type = "scroll",
        id = "level_page",
        x = 40,
        y = 150,
        width = 350,
        height = 290,
        bounce = false,
        wheelScrollAmount = 58,
        visible = function()
            return active_page == 3
        end,
        children = {
            {
                type = "text",
                id = "level_title",
                x = 8,
                y = 4,
                width = 314,
                height = 26,
                color = accent,
                text = tr("level_controls")
            },
            {
                type = "checkbox",
                id = "free_plant",
                x = 8,
                y = 36,
                width = 314,
                height = 38,
                text = tr("free_planting"),
                checked = function()
                    return free_plant
                end,
                callback = function(action)
                    free_plant = action.value == true
                    action.board.mApp.mEasyPlantingCheat = free_plant
                    set_status(tr("toggle_status", tr("free_planting"), tr(free_plant and "on" or "off")))
                end
            },
            {
                type = "checkbox",
                id = "pause_zombies",
                x = 8,
                y = 80,
                width = 314,
                height = 38,
                text = tr("pause_zombies"),
                checked = function()
                    return pause_zombie_spawning
                end,
                callback = function(action)
                    pause_zombie_spawning = action.value == true
                    set_status(tr("toggle_status", tr("pause_zombies"), tr(pause_zombie_spawning and "on" or "off")))
                end
            },
            {
                type = "checkbox",
                id = "pause_sun",
                x = 8,
                y = 124,
                width = 314,
                height = 38,
                text = tr("pause_sun"),
                checked = function()
                    return pause_sun_spawning
                end,
                callback = function(action)
                    pause_sun_spawning = action.value == true
                    set_status(tr("toggle_status", tr("pause_sun"), tr(pause_sun_spawning and "on" or "off")))
                end
            },
            {
                type = "text",
                id = "sun_amount",
                x = 8,
                y = 176,
                width = 314,
                height = 26,
                text = function()
                    return tr("sun_amount", sun_amount)
                end
            },
            {
                type = "slider",
                id = "sun_slider",
                x = 0,
                y = 200,
                width = 330,
                height = 48,
                min = 0,
                max = 99990,
                step = 100,
                largeStep = 1000,
                value = sun_amount,
                callback = function(action)
                    sun_amount = math.floor(action.value + 0.5)
                end
            },
            {
                type = "button",
                style = "stone",
                id = "set_sun",
                x = 8,
                y = 252,
                width = 314,
                height = 42,
                text = tr("set_sun"),
                callback = function(action)
                    action.board.mSunMoney = sun_amount
                    set_status(tr("sun_set", sun_amount))
                end
            },
            {
                type = "button",
                style = "stone",
                id = "next_wave",
                x = 8,
                y = 306,
                width = 314,
                height = 44,
                text = tr("next_wave"),
                callback = function(action)
                    perform(action, tr("next_wave_done"), function(board)
                        board:SpawnZombieWave()
                    end)
                end
            }
        }
    }
end

local function build_cleanup_page()
    return {
        type = "scroll",
        id = "cleanup_page",
        x = 40,
        y = 150,
        width = 350,
        height = 290,
        bounce = false,
        visible = function()
            return active_page == 4
        end,
        children = {
            {
                type = "text",
                id = "cleanup_title",
                x = 8,
                y = 8,
                width = 314,
                height = 30,
                color = accent,
                text = tr("cleanup_title")
            },
            {
                type = "button",
                style = "stone",
                id = "clear_plants",
                x = 8,
                y = 48,
                width = 314,
                height = 50,
                text = tr("clear_plants"),
                callback = function()
                    clear_plants_frames = 4
                    set_status(tr("clearing_plants"))
                end
            },
            {
                type = "button",
                style = "stone",
                id = "clear_zombies",
                x = 8,
                y = 112,
                width = 314,
                height = 50,
                text = tr("clear_zombies"),
                callback = function(action)
                    perform(action, tr("cleared_zombies"), function(board)
                        board:RemoveAllZombies()
                    end)
                end
            },
            {
                type = "button",
                style = "stone",
                id = "restore_mowers",
                x = 8,
                y = 176,
                width = 314,
                height = 50,
                text = tr("restore_mowers"),
                callback = function(action)
                    perform(action, tr("restore_mowers_done"), restore_mowers)
                end
            },
            {
                type = "button",
                style = "stone",
                id = "clear_mowers",
                x = 8,
                y = 240,
                width = 314,
                height = 50,
                text = tr("clear_mowers"),
                callback = function(action)
                    perform(action, tr("clear_mowers_done"), clear_mowers)
                end
            }
        }
    }
end

local page_keys = { "plant_page", "zombie_page", "level", "cleanup" }

local function page_choice_button(id, page_number, x, y)
    return {
        type = "button",
        style = "stone",
        id = id,
        x = x,
        y = y,
        width = 150,
        height = 48,
        text = tr(page_keys[page_number]),
        callback = function()
            active_page = page_number
            LuaUI.CloseModal(panel_id, "page_menu")
        end
    }
end

local function build_page_menu()
    return {
        type = "popup",
        id = "page_menu",
        x = 40,
        y = 150,
        width = 350,
        height = 128,
        background = panel_background,
        border = panel_border,
        dismissOnOutside = true,
        drawScrim = false,
        children = {
            page_choice_button("page_plant", 1, 17, 10),
            page_choice_button("page_zombie", 2, 183, 10),
            page_choice_button("page_level", 3, 17, 68),
            page_choice_button("page_cleanup", 4, 183, 68)
        }
    }
end

local function build_ui()
    return {
        id = panel_id,
        x = 10,
        y = 34,
        width = 430,
        height = 548,
        zOrder = 200000,
        style = "dialog",
        title = tr("title"),
        tallBottom = false,
        draggable = true,
        children = {
            {
                type = "button",
                style = "stone",
                id = "current_page",
                x = 45,
                y = 104,
                width = 350,
                height = 38,
                text = function()
                    return tr("current_page", tr(page_keys[active_page]))
                end,
                callback = function()
                    LuaUI.ShowModal(panel_id, "page_menu")
                end
            },
            build_entity_page("plant", 1),
            build_entity_page("zombie", 2),
            build_level_page(),
            build_cleanup_page(),
            build_page_menu(),
            {
                type = "text",
                id = "status",
                x = 40,
                y = 463,
                width = 190,
                height = 42,
                wrap = true,
                maxLines = 2,
                color = white,
                text = function()
                    return tr("status", status_text)
                end
            },
            {
                type = "button",
                style = "stone",
                id = "back",
                x = 240,
                y = 463,
                width = 150,
                height = 42,
                text = tr("back"),
                callback = function()
                    LuaUI.SetVisible(panel_id, false)
                    LuaUI.SetVisible(launcher_id, true)
                    LuaUI.BringToFront(launcher_id)
                    set_status(tr("panel_collapsed"))
                end
            }
        }
    }
end

local function build_launcher()
    return {
        id = launcher_id,
        x = 18,
        y = 92,
        width = 78,
        height = 48,
        zOrder = 200001,
        draggable = true,
        preservePosition = true,
        dragRegionWidth = 78,
        dragRegionHeight = 48,
        background = { r = 0, g = 0, b = 0, a = 0 },
        border = { r = 0, g = 0, b = 0, a = 0 },
        callback = function()
            if not LuaUI.IsMounted(panel_id) and not LuaUI.Mount("screen", build_ui()) then
                set_status(tr("panel_mount_error"))
                return
            end

            if not LuaUI.SetVisible(panel_id, true) then
                set_status(tr("panel_mount_error"))
                return
            end

            LuaUI.BringToFront(panel_id)
            LuaUI.SetVisible(launcher_id, false)
            set_status(tr("panel_expanded"))
        end,
        children = {
            {
                type = "image",
                id = "launcher_stone",
                x = 0,
                y = 0,
                width = 78,
                height = 48,
                image = "IMAGE_BUTTON",
                stretch = "fill"
            },
            {
                type = "text",
                id = "launcher_text",
                x = 0,
                y = 0,
                width = 78,
                height = 48,
                font = "FONT_DWARVENTODCRAFT15",
                color = { r = 21, g = 175, b = 0, a = 255 },
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
    if Resources.GetImageByName("IMAGE_BUTTON") == nil or
        Resources.GetFontByName("FONT_DWARVENTODCRAFT15") == nil or
        not prepare_entity_names() then
        return false
    end
    return LuaUI.Mount("screen", build_launcher())
end

local launcher_created = false

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
                        set_status(tr("launcher_mounted"))
                    end
                    return ""
                end
            }
        }
    }
end

local function hook(id, phase, callback)
    if api.has_hook(id) then
        api.hook(id, phase, callback)
        api.log("ultimate_cheat hooked " .. id .. " " .. phase)
    else
        api.log("ultimate_cheat missing hook " .. id)
    end
end

hook("Lawn.Board.Update()", "prefix", function(board)
    if not LuaUI.IsMounted(launcher_id) and not LuaUI.IsMounted(panel_id) and mount_launcher() then
        launcher_created = true
        set_status(tr("launcher_mounted"))
    end

    board.mApp.mEasyPlantingCheat = free_plant

    if clear_plants_frames > 0 then
        clear_plants_frames = clear_plants_frames - 1
    end

    if pause_zombie_spawning then
        saved_zombie_countdown = board.mZombieCountDown
        saved_huge_wave_countdown = board.mHugeWaveCountDown
        saved_rise_from_grave_counter = board.mRiseFromGraveCounter
        board.mZombieCountDown = paused_counter
        board.mHugeWaveCountDown = paused_counter
        board.mRiseFromGraveCounter = paused_counter
    end
    if pause_sun_spawning then
        saved_sun_countdown = board.mSunCountDown
        board.mSunCountDown = paused_counter
    end
    return true
end)

if not LuaUI.Mount("screen", build_loader()) then
    set_status(tr("launcher_mount_error"))
end

hook("Lawn.Board.Update()", "postfix", function(board)
    if saved_zombie_countdown ~= nil then
        board.mZombieCountDown = saved_zombie_countdown
        board.mHugeWaveCountDown = saved_huge_wave_countdown
        board.mRiseFromGraveCounter = saved_rise_from_grave_counter
        saved_zombie_countdown = nil
        saved_huge_wave_countdown = nil
        saved_rise_from_grave_counter = nil
    end
    if saved_sun_countdown ~= nil then
        board.mSunCountDown = saved_sun_countdown
        saved_sun_countdown = nil
    end
end)

hook("Lawn.Plant.Update()", "prefix", function(plant)
    if clear_plants_frames > 0 and not plant.mDead then
        plant:Die()
        return false
    end
    return true
end)
