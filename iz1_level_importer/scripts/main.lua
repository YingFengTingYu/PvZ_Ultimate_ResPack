api.log("iz1_level_importer loaded")

local launcher_id = "iz1_level_importer.launcher"
local panel_id = "iz1_level_importer.panel"
local loader_id = "iz1_level_importer.loader"

local launcher_created = false
local status_text = ""

local translations = {
    en = {
        title = "IZ1 Classic Level Importer",
        launcher = "IZ1",
        description = "Paste an IZ1 classic level string. Conversion is performed by Lua and saved as a custom level.",
        placeholder = "For example: IZFACWBxAA",
        import = "Convert and add",
        clear = "Clear",
        close = "Close",
        ready = "Waiting for an IZ1 string",
        empty = "Paste an IZ1 string first",
        success = "Added %s. Reopen Custom Levels to see it.",
        failure = "Import failed: %s",
        panel_error = "Could not open the IZ1 importer"
    },
    zh_cn = {
        title = "IZ1 经典关卡导入器",
        launcher = "IZ1",
        description = "粘贴 IZ1 经典关卡代码；Lua 会完成转换，并把结果保存为自定义关卡。",
        placeholder = "例如：IZFACWBxAA",
        import = "转换并添加",
        clear = "清空",
        close = "关闭",
        ready = "等待粘贴 IZ1 代码",
        empty = "请先粘贴 IZ1 代码",
        success = "已添加 %s；重新进入创意关卡页即可看到。",
        failure = "导入失败：%s",
        panel_error = "无法打开 IZ1 导入器"
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

status_text = tr("ready")

local base64_values = {}
local base64_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
for index = 1, #base64_alphabet do
    base64_values[string.sub(base64_alphabet, index, index)] = index - 1
end

local zombie_card_ids = {
    20000,
    20002,
    20003,
    20004,
    20021,
    20017,
    20020,
    20007,
    20016,
    20006,
    20012,
    20018,
    20008,
    20023,
    20024
}

local function fail(message)
    error(message, 0)
end

local function decode_character(text, index, field)
    local character = string.sub(text, index, index)
    local value = base64_values[character]
    if value == nil then
        fail(string.format("%s 包含无效字符 '%s'", field, character))
    end
    return value
end

local function decode_board_position(value, field)
    local row = math.floor(value / 10)
    local column = value % 10
    if column > 8 or row > 5 then
        fail(string.format("%s 的坐标（第 %d 列，第 %d 行）超出精华版 9×6 棋盘", field, column + 1, row + 1))
    end
    return column, row
end

local function decode_portal_position(value, field)
    if value < 0 or value > 172 then
        fail(field .. " 的位置必须在 0～172 之间")
    end

    local row = value % 11
    local column = math.floor(value / 11)
    if column > 8 or row > 5 then
        fail(string.format("%s 的坐标（第 %d 列，第 %d 行）超出精华版 9×6 棋盘", field, column + 1, row + 1))
    end
    return column, row
end

local function parse_portals(portal_text)
    if portal_text == nil then
        return nil
    end
    if string.find(portal_text, "|", 1, true) ~= nil then
        fail("传送门分隔符 '|' 最多只能出现一次")
    end

    local yellow1, yellow2, blue1, blue2 = string.match(portal_text, "^y(%d+)y(%d+)b(%d+)b(%d+)$")
    if yellow1 == nil then
        fail("传送门数据必须为 y<黄门1>y<黄门2>b<蓝门1>b<蓝门2>")
    end

    local portals = {}
    local function add_portal(type_id, value_text, field)
        local value = tonumber(value_text)
        local column, row = decode_portal_position(value, field)
        portals[#portals + 1] = { type_id, column, row }
    end

    add_portal(1, yellow1, "黄门1")
    add_portal(1, yellow2, "黄门2")
    add_portal(0, blue1, "蓝门1")
    add_portal(0, blue2, "蓝门2")
    return portals
end

local function parse_iz1(source)
    if source == nil or source == "" then
        fail(tr("empty"))
    end

    local code = string.gsub(source, "%s+", "")
    local separator = string.find(code, "|", 1, true)
    local body = code
    local portal_text = nil
    if separator ~= nil then
        body = string.sub(code, 1, separator - 1)
        portal_text = string.sub(code, separator + 1)
    end

    if string.sub(body, 1, 2) ~= "IZ" then
        fail("代码必须以 IZ 开头，且区分大小写")
    end
    if #body < 7 then
        fail("代码头部不完整")
    end

    local limit = decode_character(body, 3, "红线")
    if limit > 9 then
        fail("红线位置必须在 0～9 之间")
    end

    local sun_high = decode_character(body, 4, "阳光高位")
    local sun_middle = decode_character(body, 5, "阳光中位")
    local sun_low = decode_character(body, 6, "阳光低位")
    local starting_sun = sun_high * 4096 + sun_middle * 64 + sun_low

    local slot_count = decode_character(body, 7, "卡槽数量")
    if slot_count > 10 then
        fail("卡槽数量必须在 0～10 之间")
    end
    if #body < 7 + slot_count then
        fail("卡槽数据不完整")
    end

    local cards = {}
    for slot = 1, slot_count do
        local code_value = decode_character(body, 7 + slot, "卡槽" .. slot)
        if code_value <= 48 then
            cards[#cards + 1] = code_value
        else
            cards[#cards + 1] = zombie_card_ids[code_value - 48]
        end
    end

    local plants = {}
    local graves = {}
    local craters = {}
    local ladders = {}
    local rakes = {}
    local object_start = 8 + slot_count
    local object_length = #body - object_start + 1
    if object_length % 2 ~= 0 then
        fail("场地对象数据必须按两个字符一组")
    end

    local object_index = 1
    for index = object_start, #body, 2 do
        local type_value = decode_character(body, index, "场地对象" .. object_index .. "类型")
        local position_value = decode_character(body, index + 1, "场地对象" .. object_index .. "坐标")
        local column, row = decode_board_position(position_value, "场地对象" .. object_index)
        if type_value <= 52 then
            plants[#plants + 1] = { type_value, column, row }
        elseif type_value == 53 then
            fail("场地对象" .. object_index .. "使用了未定义的类型 53")
        elseif type_value == 54 then
            graves[#graves + 1] = { column, row }
        elseif type_value == 55 then
            craters[#craters + 1] = { column, row }
        elseif type_value == 56 then
            ladders[#ladders + 1] = { column, row }
        elseif type_value == 57 then
            rakes[#rakes + 1] = { column, row }
        else
            fail("场地对象" .. object_index .. "的类型必须在 0～52 或 54～57 之间")
        end
        object_index = object_index + 1
    end

    return {
        code = code,
        limit = limit,
        starting_sun = starting_sun,
        cards = cards,
        plants = plants,
        graves = graves,
        craters = craters,
        ladders = ladders,
        rakes = rakes,
        portals = parse_portals(portal_text)
    }
end

local function encode_number_array(values)
    local result = {}
    for index, value in ipairs(values) do
        result[index] = tostring(value)
    end
    return "[" .. table.concat(result, ",") .. "]"
end

local function encode_triples(values)
    local result = {}
    for index, value in ipairs(values) do
        result[index] = string.format("[%d,%d,%d]", value[1], value[2], value[3])
    end
    return "[" .. table.concat(result, ",") .. "]"
end

local function encode_pairs(values)
    local result = {}
    for index, value in ipairs(values) do
        result[index] = string.format("[%d,%d]", value[1], value[2])
    end
    return "[" .. table.concat(result, ",") .. "]"
end

local function create_level_json(level)
    local components = {
        string.format(
            '{"Type":"LevelProperty","ChineseName":"IZ1 导入关卡","EnglishName":"IZ1 Imported Level","Icon":11,"Background":1,"StartingSun":%d}',
            level.starting_sun),
        string.format(
            '{"Type":"SeedBank","NumPackets":%d,"LockedCards":%s,"UserChoose":false,"EnableHero":false}',
            #level.cards,
            encode_number_array(level.cards)),
        string.format(
            '{"Type":"IZombieLevel","Limit":%d,"PlantCardsAsPlants":false,"PlantInSquare":%s}',
            level.limit,
            encode_triples(level.plants))
    }

    if #level.graves > 0 then
        components[#components + 1] = string.format(
            '{"Type":"SpawnGraveStone","GraveStones":%s,"AllowGraveStoneOnDirt":false}',
            encode_pairs(level.graves))
    end

    if #level.craters > 0 then
        components[#components + 1] = string.format(
            '{"Type":"SpawnCrater","Craters":%s}',
            encode_pairs(level.craters))
    end

    if #level.ladders > 0 then
        components[#components + 1] = string.format(
            '{"Type":"SpawnLadder","Ladders":%s}',
            encode_pairs(level.ladders))
    end

    if #level.rakes > 0 then
        components[#components + 1] = string.format(
            '{"Type":"SpawnRake","Rakes":%s}',
            encode_pairs(level.rakes))
    end

    if level.portals ~= nil then
        components[#components + 1] = string.format(
            '{"Type":"SpawnPortal","Portals":%s,"FixPlantAttackView":false,"FixSpawnZombieView":true,"RandomPortalTime":-1}',
            encode_triples(level.portals))
    end

    return '{"Version":3,"Components":[' .. table.concat(components, ",") .. "]}"
end

local function set_status(value)
    status_text = value
    api.log("iz1_level_importer: " .. value)
end

local function import_source(source)
    local parsed_ok, parsed_or_error = pcall(parse_iz1, source)
    if not parsed_ok then
        set_status(tr("failure", tostring(parsed_or_error)))
        return
    end

    local json = create_level_json(parsed_or_error)
    local saved_ok, file_or_error = pcall(function()
        return CreativeLevelManager.AddDIYLevelJson(json)
    end)
    if not saved_ok then
        set_status(tr("failure", tostring(file_or_error)))
        return
    end

    set_status(tr("success", tostring(file_or_error)))
end

local function current_input()
    local snapshot = LuaUI.GetElement(panel_id, "iz_input")
    if snapshot == nil then
        return ""
    end
    return snapshot.text or ""
end

local function build_panel()
    return {
        id = panel_id,
        layout = {
            mode = "anchored",
            anchorX = 0.5,
            anchorY = 0.5,
            width = 760,
            height = 430
        },
        zOrder = 200110,
        style = "dialog",
        title = tr("title"),
        draggable = true,
        preservePosition = true,
        children = {
            {
                type = "text",
                id = "description",
                x = 42,
                y = 102,
                width = 676,
                height = 54,
                wrap = true,
                color = { r = 238, g = 231, b = 207, a = 255 },
                text = tr("description")
            },
            {
                type = "input",
                id = "iz_input",
                x = 42,
                y = 166,
                width = 676,
                height = 52,
                maxLength = 16384,
                placeholder = tr("placeholder"),
                onSubmit = function(action)
                    import_source(action.value)
                end
            },
            {
                type = "text",
                id = "status",
                x = 42,
                y = 232,
                width = 676,
                height = 66,
                wrap = true,
                color = { r = 244, g = 210, b = 105, a = 255 },
                text = function()
                    return status_text
                end
            },
            {
                type = "button",
                style = "stone",
                id = "import",
                x = 42,
                y = 320,
                width = 260,
                height = 48,
                text = tr("import"),
                callback = function()
                    import_source(current_input())
                end
            },
            {
                type = "button",
                style = "stone",
                id = "clear",
                x = 318,
                y = 320,
                width = 170,
                height = 48,
                text = tr("clear"),
                callback = function()
                    LuaUI.SetText(panel_id, "iz_input", "")
                    set_status(tr("ready"))
                    LuaUI.Focus(panel_id, "iz_input")
                end
            },
            {
                type = "button",
                style = "stone",
                id = "close",
                x = 504,
                y = 320,
                width = 214,
                height = 48,
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
        set_status(tr("panel_error"))
        return
    end

    LuaUI.SetVisible(launcher_id, false)
    LuaUI.SetVisible(panel_id, true)
    LuaUI.BringToFront(panel_id)
    LuaUI.Focus(panel_id, "iz_input")
end

local function build_launcher()
    return {
        id = launcher_id,
        x = 18,
        y = 180,
        width = 78,
        height = 48,
        zOrder = 200111,
        draggable = true,
        preservePosition = true,
        dragRegionWidth = 78,
        dragRegionHeight = 48,
        background = { r = 0, g = 0, b = 0, a = 0 },
        border = { r = 0, g = 0, b = 0, a = 0 },
        callback = open_panel,
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
        Resources.GetFontByName("FONT_DWARVENTODCRAFT15") == nil then
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
                        api.log("iz1_level_importer launcher mounted")
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
