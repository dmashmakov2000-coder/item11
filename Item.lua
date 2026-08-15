--[[
    Script [TM] - Ежедневный Финансовый Журнал и Трекер
    Разработчик: Dima_Shmakov
]]

script_properties('work-in-pause')

local ffi = require('ffi')
local fa_ok, fa = pcall(require, 'fAwesome6')

local load_errors = {}
local function check_lib(name)
    local ok, lib = pcall(require, name)
    if not ok then
        print(('[TM] Warning: Library \'%s\' not found.'):format(name))
        table.insert(load_errors, ('Библиотека \'%s\' не найдена.'):format(name))
        return false, nil
    end
    return true, lib
end

local samp = require('samp.events')
local inicfg = require('inicfg')
local imgui = require('mimgui')
local json = require('json')
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local effil_ok, effil = check_lib('effil')
local requests_ok, requests_lib = check_lib('requests')

-- === ЕДИНАЯ ПАПКА Script [TM] ===
local base_dir = getWorkingDirectory()
local script_folder = base_dir .. "\\Script [TM]"

if not doesDirectoryExist(script_folder) then
    createDirectory(script_folder)
    print("[TM] Папка 'Script [TM]' создана по пути: " .. script_folder)
end

local items_db_path = script_folder .. "\\items.json"
local logo_path = script_folder .. "\\logo1.png"
local stats_file_path = script_folder .. "\\ScriptTM_stats.json"

local ITEMS_DB_URL = "https://raw.githubusercontent.com/dmashmakov2000-coder/item11/main/items.json"
local LOGO_URL = "https://raw.githubusercontent.com/dmashmakov2000-coder/item11/main/logo1.png"

local SCRIPT_VERSION = "0.3.8"
local UPDATE_URL = "https://raw.githubusercontent.com/dmashmakov2000-coder/item11/main/Item.lua"
local CFG_FILENAME = 'Script [TM].ini'

local ANTIBLOCK_URL = "https://tg.bakh.us"
local DEFAULT_API = "https://api.telegram.org"
local wasOpenedByCommand = false

local UPDATE_INFO = [[исправлено получение предметов в сторедж
теперь сообщения вновь приходят 
новый спписок предметов будет обновлен на днях]]

-- Точный IP-адрес Vice City
local VC_IP = "80.66.82.147"

-- === 100% ТОЧНОЕ ОПРЕДЕЛЕНИЕ СЕРВЕРА VICE CITY ===
local function isViceCityServer()
    local ip, port = sampGetCurrentServerAddress()
    if not ip then return false end
    
    local clean_ip = tostring(ip):lower():gsub("%s+", "")
    
    -- Если IP точно равен 80.66.82.147 или домену vc.arizona-rp.com
    if clean_ip == VC_IP or clean_ip:find("^80%.66%.82%.147") or clean_ip:find("vc%.arizona") then
        return true
    end

    -- Дополнительная проверка по названию сервера в SAMP
    if sampIsLocalPlayerSpawned() then
        local sName = sampGetCurrentServerName()
        if sName then
            local cleanName = sName:lower()
            if cleanName:find("vice city") or cleanName:find("vice_city") then
                return true
            end
        end
    end

    return false
end

-- === ПРОВЕРКА СДЕЛКИ (ОБЫЧНЫЙ СЕРВЕР ИЛИ VICE CITY) ===
local function isViceCityTransaction(text, cleanText)
    -- Если игрок находитесь на сервере Vice City
    if isViceCityServer() then
        return true
    end

    -- Дополнительная проверка: если в самом тексте есть значок VC$
    if cleanText then
        local lowerText = cleanText:lower()
        if lowerText:find("vc%$") or lowerText:find("vc %$") or lowerText:find("%d+%s*vc") then
            return true
        end
    end

    return false
end



-- === ПАКЕТ ИЗ 33 СМАЙЛИКОВ ===
local emojis_list = {
    { key = "emoji_none", char = "", name = "Без смайла", ui_name = "[ Без смайла ]", desc = "Не отправлять смайлик" },
    { key = "emoji_dollar", char = "\xf0\x9f\x92\xb2", name = "Бакс", ui_name = "[ Бакс ]", desc = "Зеленый знак доллара" },
    { key = "emoji_money", char = "\xf0\x9f\x92\xb5", name = "Пачка", ui_name = "[ Пачка ]", desc = "Пачка бумажных долларов" },
    { key = "emoji_bag", char = "\xf0\x9f\x92\xb0", name = "Мешок", ui_name = "[ Мешок ]", desc = "Мешок с золотыми монетами" },
    { key = "emoji_fly", char = "\xf0\x9f\x92\xb8", name = "Полет", ui_name = "[ Полет ]", desc = "Деньги с крылышками" },
    { key = "emoji_coin", char = "\xf0\x9f\xaa\x99", name = "Монета", ui_name = "[ Монета ]", desc = "Золотые монетки" },
    { key = "emoji_card", char = "\xf0\x9f\x92\xb3", name = "Карта", ui_name = "[ Карта ]", desc = "Банковская кредитная карта" },
    { key = "emoji_car", char = "\xf0\x9f\x9a\x97", name = "Авто", ui_name = "[ Авто ]", desc = "Легковой автомобиль" },
    { key = "emoji_house", char = "\xf0\x9f\x8f\xa0", name = "Дом", ui_name = "[ Дом ]", desc = "Жилой дом" },
    { key = "emoji_biz", char = "\xf0\x9f\x8f\xa2", name = "Бизнес", ui_name = "[ Бизнес ]", desc = "Здание предприятия" },
    { key = "emoji_key", char = "\xf0\x9f\x94\x91", name = "Ключ", ui_name = "[ Ключ ]", desc = "Золотой ключик" },
    { key = "emoji_box", char = "\xf0\x9f\x93\xa6", name = "Ящик", ui_name = "[ Ящик ]", desc = "Коробка / Посылка" },
    { key = "emoji_backpack", char = "\xf0\x9f\x8e\x92", name = "Рюкзак", ui_name = "[ Рюкзак ]", desc = "Рюкзак / Сумка для покупок" },
    { key = "emoji_gift", char = "\xf0\x9f\x8e\x81", name = "Подарок", ui_name = "[ Подарок ]", desc = "Подарочная коробка с лентой" },
    { key = "emoji_mine", char = "\xf0\x9f\xaa\xa3", name = "Кирка", ui_name = "[ Кирка ]", desc = "Кирка / Молоток" },
    { key = "emoji_fish", char = "\xf0\x9f\x90\x9f", name = "Рыба", ui_name = "[ Рыба ]", desc = "Тропическая рыбка" },
    { key = "emoji_gun", char = "\xf0\x9f\x94\xab", name = "Оружие", ui_name = "[ Оружие ]", desc = "Оружие / Пистолет" },
    { key = "emoji_cart", char = "\xf0\x9f\x9b\x92", name = "Тележка", ui_name = "[ Лавка ]", desc = "Торговая лавка" },
    { key = "emoji_pill", char = "\xf0\x9f\x92\x8a", name = "Таблетка", ui_name = "[ Таблетка ]", desc = "Медицинская капсула" },
    { key = "emoji_check", char = "\xe2\x9c\x85", name = "ОК", ui_name = "[ Галочка ]", desc = "Зеленая галочка" },
    { key = "emoji_cross", char = "\xe2\x9d\x8c", name = "Отмена", ui_name = "[ Крестик ]", desc = "Красный крестик отмены" },
    { key = "emoji_warn", char = "\xe2\x9a\xa0\xef\xb8\x8f", name = "Варн", ui_name = "[ Внимание ]", desc = "Знак предупреждения" },
    { key = "emoji_bell", char = "\xf0\x9f\x94\x94", name = "Звонок", ui_name = "[ Звонок ]", desc = "Золоток колокольчик" },
    { key = "emoji_siren", char = "\xf0\x9f\x9a\xa8", name = "Сирена", ui_name = "[ Сирена ]", desc = "Громкоговоритель" },
    { key = "emoji_shield", char = "\xf0\x9f\x9b\xa1\xef\xb8\x8f", name = "Щит", ui_name = "[ Щит ]", desc = "Защитный щит" },
    { key = "emoji_lock", char = "\xf0\x9f\x94\x92", name = "Замок", ui_name = "[ Замок ]", desc = "Закрытый навесной замок" },
    { key = "emoji_unlock", char = "\xf0\x9f\x94\x93", name = "Открыто", ui_name = "[ Открытый замок ]", desc = "Открытый навесной замок" },
    { key = "emoji_wave", char = "\xf0\x9f\x91\x8b", name = "Привет", ui_name = "[ Привет ]", desc = "Машущая рука приветствия" },
    { key = "emoji_chat", char = "\xf0\x9f\x92\xac", name = "Чат", ui_name = "[ Чат ]", desc = "Облако диалога / Чат" },
    { key = "emoji_ad", char = "\xf0\x9f\x93\xa2", name = "Реклама", ui_name = "[ Реклама ]", desc = "Объявление" },
    { key = "emoji_crown", char = "\xf0\x9f\x91\x91", name = "Корона", ui_name = "[ Корона ]", desc = "Золотая корона лидера" },
    { key = "emoji_star", char = "\xe2\xad\x90", name = "Звезда", ui_name = "[ Звезда ]", desc = "Золотая звезда" },
    { key = "emoji_trophy", char = "\xf0\x9f\x8f\x86", name = "Кубок", ui_name = "[ Кубок ]", desc = "Наградной золотой кубок" },
    { key = "emoji_rocket", char = "\xf0\x9f\x9a\x80", name = "Ракета", ui_name = "[ Ракета ]", desc = "Космическая ракета" },
}

local emoji_fa_mappings = {
    emoji_none     = {"BAN", "SLASH"},
    emoji_dollar   = {"DOLLAR_SIGN", "DOLLAR"},
    emoji_money    = {"MONEY_BILL", "MONEY_BILL_ALT"},
    emoji_bag      = {"SACK_DOLLAR", "MONEY_BILL_ALT"},
    emoji_fly      = {"MONEY_BILL_WAVE", "MONEY_BILL"},
    emoji_coin     = {"COINS", "COIN"},
    emoji_card     = {"CREDIT_CARD", "CREDIT_CARD_ALT"},
    emoji_car      = {"CAR", "AUTOMOBILE"},
    emoji_house    = {"HOUSE", "HOME"},
    emoji_biz      = {"BUILDING", "BRIEFCASE"},
    emoji_key      = {"KEY"},
    emoji_box      = {"BOX", "ARCHIVE"},
    emoji_backpack = {"BAG_SHOPPING", "SHOPPING_BAG", "BRIEFCASE"},
    emoji_gift     = {"GIFT"},
    emoji_mine     = {"HAMMER", "WRENCH"},
    emoji_fish     = {"FISH"},
    emoji_gun      = {"GUN", "CROSSHAIRS"},
    emoji_cart     = {"CART_SHOPPING", "SHOPPING_CART"},
    emoji_pill     = {"PILL", "PILLS", "MEDKIT"},
    emoji_check    = {"CIRCLE_CHECK", "CHECK_CIRCLE", "CHECK"},
    emoji_cross    = {"CIRCLE_XMARK", "TIMES_CIRCLE", "TIMES"},
    emoji_warn     = {"TRIANGLE_EXCLAMATION", "EXCLAMATION_TRIANGLE", "EXCLAMATION"},
    emoji_bell     = {"BELL"},
    emoji_siren    = {"BULLHORN", "VOLUME_UP"},
    emoji_shield   = {"SHIELD_HALVED", "SHIELD_ALT", "SHIELD"},
    emoji_lock     = {"LOCK"},
    emoji_unlock   = {"UNLOCK"},
    emoji_wave     = {"HAND_WAVING", "HAND_PAPER", "HAND"},
    emoji_chat     = {"COMMENT", "COMMENTS"},
    emoji_ad       = {"BULLHORN", "AD"},
    emoji_crown    = {"CROWN"},
    emoji_star     = {"STAR"},
    emoji_trophy   = {"TROPHY"},
    emoji_rocket   = {"ROCKET"},
}

-- === ДАННЫЕ СЕССИОННОГО АНАЛИТИКА ===
local session_stats = {
    last_active_date = "",
    time_in_game = 0,
    quests_completed = 0,
    wages_accumulated = 0,
    dep_growth = 0,
    biz_income = 0,
    btc_income = 0,
    az_accumulated = 0,
    trade_income = 0,
    deal_income = 0,
    expenses_accumulated = 0,
	
	mining_expenses = 0,
    mining_electricity = 0,
    mining_coolants = 0,
	

    manually_added_money = 0,
    manually_added_az = 0,
    report_sent = false,
    
    daily_history = {},

    last_payday_wage = 0,
    last_payday_dep = 0,
    last_payday_az = 0,

    goal_amount = 10000000000,
    goal_type = 1,
    goal_scope = 1,
    goal_notified = false,
    goal_configured = false,
    goal_enabled = true,
    goal_start_from_zero = true,
    goal_start_money = 0,
    goal_start_az = 0,
    ignored_items = {}
}

local items_name = {}
local items_loaded = false
local font_loaded = false
local logo_texture = nil

show_add_funds_modal = imgui.new.bool(false)
add_funds_input = imgui.new.char[64]("")

show_chart_window = imgui.new.bool(false)
show_goal_settings = imgui.new.bool(false)
show_projection_pinned = imgui.new.bool(false)
is_proj_window_hovered = false

item_search_input = imgui.new.char[128]("")

chart_view_mode = imgui.new.int(0)
chart_category_mode = imgui.new.int(0) -- <-- ДОБАВИТЬ ЭТУ СТРОЧКУ!
chart_days_period = imgui.new.int(7)


goal_edit_amount = imgui.new.char[64]("10000000000")
goal_edit_type = imgui.new.int(1)
goal_edit_scope = imgui.new.int(1)
goal_edit_start_zero = imgui.new.bool(true)

local tm_trade_waiting_money = false
local tm_trade_waiting_time = 0
local tm_last_money = nil

-- === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
local function formatNumber(amount)
    if not amount then return "0" end
    local formatted = tostring(math.floor(tonumber(amount) or 0))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
        if (k == 0) then break end
    end
    return formatted
end

local function parse_numeric_value(str)
    if not str then return 0 end
    local clean = tostring(str):gsub("{%x%x%x%x%x%x}", ""):gsub("%.", ""):gsub(",", ""):gsub("%s+", ""):gsub("[^%d%-]", "")
    return tonumber(clean) or 0
end

local function formatNumbersInText(text)
    if type(text) ~= "string" then return text end
    local res = text:gsub("(%d%d%d%d+)", function(num)
        return formatNumber(num)
    end)
    return res
end

function cleanColors(text)
    if type(text) ~= "string" then return text end
    local res = text:gsub("{%x%x%x%x%x%x}", "")
    return res
end

local function getCurrentIncome()
    local total_earned = (session_stats.wages_accumulated or 0) + 
                         (session_stats.dep_growth or 0) + 
                         (session_stats.biz_income or 0) + 
                         (session_stats.btc_income or 0) + 
                         (session_stats.trade_income or 0) +
                         (session_stats.deal_income or 0)

    local total_expenses = math.abs(tonumber(session_stats.expenses_accumulated) or 0)
    return total_earned - total_expenses
end

local function getTotalIncomeOverall()
    local total = 0
    local today_str = session_stats.last_active_date ~= "" and session_stats.last_active_date or os.date("%d.%m.%Y")
    
    for date_str, data in pairs(session_stats.daily_history or {}) do
        if date_str ~= today_str then
            total = total + (tonumber(data.income) or 0)
        end
    end
    total = total + getCurrentIncome()
    return total
end

local function getTotalAZOverall()
    local total = 0
    local today_str = session_stats.last_active_date ~= "" and session_stats.last_active_date or os.date("%d.%m.%Y")
    
    for date_str, data in pairs(session_stats.daily_history or {}) do
        if date_str ~= today_str then
            total = total + (tonumber(data.az_accumulated) or 0)
        end
    end
    total = total + (session_stats.az_accumulated or 0)
    return total
end

local function save_stats_to_file()
    local data = {
        last_active_date = session_stats.last_active_date,
        time_in_game = session_stats.time_in_game,
        quests_completed = session_stats.quests_completed,
        wages_accumulated = session_stats.wages_accumulated,
        dep_growth = session_stats.dep_growth,
        biz_income = session_stats.biz_income,
        btc_income = session_stats.btc_income,
        az_accumulated = session_stats.az_accumulated,
        trade_income = session_stats.trade_income or 0,
        deal_income = session_stats.deal_income or 0,
		
		           mining_expenses = session_stats.mining_expenses or 0,
           mining_electricity = session_stats.mining_electricity or 0,
           mining_coolants = session_stats.mining_coolants or 0,
   

		
		
        expenses_accumulated = math.abs(tonumber(session_stats.expenses_accumulated) or 0),

        manually_added_money = session_stats.manually_added_money,
        manually_added_az = session_stats.manually_added_az,   
        report_sent = session_stats.report_sent,
        daily_history = session_stats.daily_history or {},
        last_payday_wage = session_stats.last_payday_wage,
        last_payday_dep = session_stats.last_payday_dep,
        last_payday_az = session_stats.last_payday_az,
        goal_amount = session_stats.goal_amount or 10000000000,
        goal_type = session_stats.goal_type or 1,
        goal_scope = session_stats.goal_scope or 1,
        goal_notified = session_stats.goal_notified or false,
        goal_configured = session_stats.goal_configured or false,
        goal_enabled = (session_stats.goal_enabled == nil) and true or session_stats.goal_enabled,
        goal_start_from_zero = session_stats.goal_start_from_zero or false,
        goal_start_money = session_stats.goal_start_money or 0,
        goal_start_az = session_stats.goal_start_az or 0,
ignored_items = session_stats.ignored_items or {},
tx_history = session_stats.tx_history or {} -- <-- ДОБАВИТЬ ЭТУ СТРОКУ

    }
    local f = io.open(stats_file_path, "w")
    if f then
        f:write(json.encode(data))
        f:close()
    end
end

local function saveDayToHistory(date_str)
    if not date_str or date_str == "" then return end
    session_stats.daily_history = session_stats.daily_history or {}
    session_stats.daily_history[date_str] = {
        income = getCurrentIncome(),
        wages = session_stats.wages_accumulated or 0,
		
		
		
	           mining_expenses = session_stats.mining_expenses or 0,
           mining_electricity = session_stats.mining_electricity or 0,
           mining_coolants = session_stats.mining_coolants or 0,
   
	
		
		
		
		
	
        deposit = session_stats.dep_growth or 0,
        business = session_stats.biz_income or 0,
        bitcoin = session_stats.btc_income or 0,
        az_accumulated = session_stats.az_accumulated or 0,
        quests = session_stats.quests_completed or 0,
        time_in_game = session_stats.time_in_game or 0,
        expenses = math.abs(tonumber(session_stats.expenses_accumulated) or 0)
    }
    save_stats_to_file()
end

local function getDateTable(date_str)
    if type(date_str) ~= "string" then return nil end
    local day, month, year = date_str:match("^(%d%d)%.(%d%d)%.(%d%d%d%d)$")
    if not day then return nil end
    return { day = tonumber(day), month = tonumber(month), year = tonumber(year) }
end

local function getDateNumber(date_str)
    local d = getDateTable(date_str)
    if not d then return 0 end
    return os.time({ year = d.year, month = d.month, day = d.day, hour = 12 })
end

local function getMondayTimestamp(ts)
    local w = tonumber(os.date("%w", ts))
    if w == 0 then w = 7 end
    return ts - ((w - 1) * 86400)
end

local function getWeekStatistics(ts)
    ts = ts or os.time()
    local monday = getMondayTimestamp(ts)
    local sunday = monday + (6 * 86400) + 86399

    local total = 0
    local days = 0
    local max_income = 0
    local max_date = ""

    for date_str, data in pairs(session_stats.daily_history or {}) do
        local date_num = getDateNumber(date_str)
        if date_num >= monday and date_num <= sunday then
            local inc = tonumber(data.income) or 0
            total = total + inc
            days = days + 1
            if inc > max_income then
                max_income = inc
                max_date = date_str
            end
        end
    end

    local today_str = session_stats.last_active_date ~= "" and session_stats.last_active_date or os.date("%d.%m.%Y")
    local today_num = getDateNumber(today_str)
    if today_num >= monday and today_num <= sunday then
        if not session_stats.daily_history[today_str] then
            local today_inc = getCurrentIncome()
            total = total + today_inc
            days = days + 1
            if today_inc > max_income then
                max_income = today_inc
                max_date = today_str
            end
        end
    end

    return { total = total, days = days, max_income = max_income, max_date = max_date }
end

local function getMonthStatistics(ts)
    ts = ts or os.time()
    local month = tonumber(os.date("%m", ts))
    local year = tonumber(os.date("%Y", ts))

    local total = 0
    local days = 0
    local max_income = 0
    local max_date = ""

    for date_str, data in pairs(session_stats.daily_history or {}) do
        local d = getDateTable(date_str)
        if d and d.month == month and d.year == year then
            local inc = tonumber(data.income) or 0
            total = total + inc
            days = days + 1
            if inc > max_income then
                max_income = inc
                max_date = date_str
            end
        end
    end

    local today_str = session_stats.last_active_date ~= "" and session_stats.last_active_date or os.date("%d.%m.%Y")
    local today_d = getDateTable(today_str)
    if today_d and today_d.month == month and today_d.year == year then
        if not session_stats.daily_history[today_str] then
            local today_inc = getCurrentIncome()
            total = total + today_inc
            days = days + 1
            if today_inc > max_income then
                max_income = today_inc
                max_date = today_str
            end
        end
    end

    return { total = total, days = days, max_income = max_income, max_date = max_date }
end

local function getMaxIncomeOverall()
    local max_income = 0
    local max_date = ""

    for date_str, data in pairs(session_stats.daily_history or {}) do
        local inc = tonumber(data.income) or 0
        if inc > max_income then
            max_income = inc
            max_date = date_str
        end
    end

    local today_inc = getCurrentIncome()
    if today_inc > max_income then
        max_income = today_inc
        max_date = session_stats.last_active_date ~= "" and session_stats.last_active_date or os.date("%d.%m.%Y")
    end

    return max_income, max_date
end

local function getEmojiRenderString(key)
    if font_loaded and fa_ok and fa then
        local alternatives = emoji_fa_mappings[key]
        if alternatives then
            for _, fa_name in ipairs(alternatives) do
                local icon = fa[fa_name]
                if icon then return icon end
            end
        end
    end
    for _, e in ipairs(emojis_list) do
        if e.key == key then
            return u8(e.ui_name)
        end
    end
    return u8("[ ? ]")
end

local function getIcon(name, fallback)
    if font_loaded and fa_ok and fa and fa[name] then
        return fa[name] .. " "
    end
    return fallback or ""
end

local function to_cp1251(str)
    if type(str) ~= "string" then return str end
    if str:find("[\208\209]") then
        local ok, decoded = pcall(function() return u8:decode(str) end)
        if ok then return decoded end
    end
    return str
end

local function format_game_time(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function getEmojiForDisplay(config_key)
    if not cfg or not cfg.config then return "" end
    local emoji_key = cfg.config[config_key]
    if emoji_key and emoji_key ~= "emoji_none" then
        for _, e in ipairs(emojis_list) do
            if e.key == emoji_key then
                return u8(e.char) .. " "
            end
        end
    end
    return ""
end

local function get_average_daily_value(value_type)
    local total_sum = 0
    local total_days = 0
    local today_str = os.date("%d.%m.%Y")

    for date_str, data in pairs(session_stats.daily_history or {}) do
        local val = tonumber(data[value_type]) or 0
        total_sum = total_sum + val
        total_days = total_days + 1
    end

    if not session_stats.daily_history[today_str] then
        if value_type == 'income' then
            total_sum = total_sum + getCurrentIncome()
        elseif value_type == 'az_accumulated' then
            total_sum = total_sum + (session_stats.az_accumulated or 0)
        end
        total_days = total_days + 1
    end
    
    if total_days > 0 then
        return total_sum / total_days
    end
    return 0
end

function loadItemsDatabase()
    if doesFileExist(items_db_path) then
        local f = io.open(items_db_path, "r")
        if f then
            local content = f:read("*a")
            f:close()
            
            local raw_data = nil
            
            -- Попытка загрузить как Lua-таблицу (старый формат)
            if content:find("local%s+items_name%s*=") or content:find("%[%s*%d+%s*%]%s*=") then
                local clean_lua = content:gsub("local%s+items_name%s*=%s*", "return ")
                local fn, err = load(clean_lua)
                if fn then
                    local ok, res = pcall(fn)
                    if ok and type(res) == "table" then raw_data = res end
                else
                    sampAddChatMessage("{FF0000}[TM Debug] Ошибка при загрузке items.json как Lua: " .. tostring(err), -1)
                end
            else
                -- Попытка загрузить как JSON (новый/стандартный формат)
                local ok, decoded = pcall(json.decode, content)
                if ok then raw_data = decoded
                else sampAddChatMessage("{FF0000}[TM Debug] Ошибка при загрузке items.json как JSON: " .. tostring(decoded), -1)
                end
            end

            if raw_data then
                items_name = {}
                local count = 0
                for k, v in pairs(raw_data) do
                    items_name[tostring(k)] = to_cp1251(v)
                    count = count + 1
                end
                items_loaded = true
                sampAddChatMessage("{00FF00}[TM Debug] items.json успешно загружен, предметов: " .. count, -1)
            else
                sampAddChatMessage("{FF0000}[TM Debug] items.json загружен, но данные не распознаны.", -1)
            end
        else
            sampAddChatMessage("{FF0000}[TM Debug] Не удалось открыть items.json для чтения.", -1)
        end
    else
        sampAddChatMessage("{FF0000}[TM Debug] items.json не найден. Загружаю с сервера.", -1)
        downloadItemsDatabase()
    end
end


function downloadItemsDatabase()
    if not requests_ok then return end
    lua_thread.create(function()
        local ok, res = pcall(requests_lib.get, ITEMS_DB_URL)
        if ok and res.status_code == 200 then
            local f = io.open(items_db_path, "w")
            if f then 
                f:write(res.text)
                f:close()
                loadItemsDatabase() 
            end
        end
    end)
end

function updateFilesAsync()
    if not requests_ok then 
        show_arz_notify('error', 'TM', 'Библиотека requests не найдена!', 3000)
        return 
    end

    lua_thread.create(function()
        show_arz_notify('info', 'TM', 'Удаление старых файлов...', 2000)
        
        logo_texture = nil
        wait(500)

        if doesFileExist(logo_path) then 
            os.remove(logo_path) 
        end
        if doesFileExist(items_db_path) then 
            os.remove(items_db_path) 
        end

        wait(1000)
        show_arz_notify('info', 'TM', 'Загрузка новых файлов...', 2000)

        local requests = require('requests')

        local ok_logo, res_logo = pcall(requests.get, LOGO_URL)
        if ok_logo and res_logo.status_code == 200 then
            local f = io.open(logo_path, "wb")
            if f then
                f:write(res_logo.body or res_logo.text)
                f:close()
            end
        end

        wait(500)

        local ok_db, res_db = pcall(requests.get, ITEMS_DB_URL)
        if ok_db and res_db.status_code == 200 then
            local f = io.open(items_db_path, "w")
            if f then 
                f:write(res_db.text)
                f:close()
            end
        end

        wait(500)

        loadItemsDatabase()
        if doesFileExist(logo_path) then
            local ok_tex, tex = pcall(imgui.CreateTextureFromFile, logo_path)
            if ok_tex and tex then logo_texture = tex end
        end

        show_arz_notify('success', 'TM', 'База предметов и логотип обновлены!', 3000)
        sampAddChatMessage("{00FF00}[TM] Файлы logo1.png и items.json успешно переустановлены!", -1)
    end)
end

function downloadLogo()
    if not requests_ok then return end
    lua_thread.create(function()
        local ok, res = pcall(requests_lib.get, LOGO_URL)
        if ok and res.status_code == 200 then
            local f = io.open(logo_path, "wb")
            if f then
                f:write(res.body or res.text)
                f:close()
                local ok_tex, tex = pcall(imgui.CreateTextureFromFile, logo_path)
                if ok_tex and tex then logo_texture = tex end
            end
        end
    end)
end

function getItemName(id)
    if not items_loaded then return "ID: " .. id end
    return items_name[tostring(id)] or items_name[tonumber(id)] or ("ID: " .. id)
end

local function get_session_report_text(date_str)
    local target_date = (date_str and date_str ~= "") and date_str or os.date("%d.%m.%Y")
    
    local wage_val = session_stats.wages_accumulated or 0
    local dep_val = session_stats.dep_growth or 0
    local biz_val = session_stats.biz_income or 0
    local btc_val = session_stats.btc_income or 0
    local deal_val = session_stats.deal_income or 0
    local quests_val = session_stats.quests_completed or 0

    local total_val = wage_val + dep_val + biz_val + btc_val + deal_val

    local lines = {
        "{emoji_bag} *ЕЖЕДНЕВНЫЙ ОТЧЁТ ЗА " .. tostring(target_date) .. "*",
        "=============== Script [TM] ===============",
        "{emoji_clock} *Время в игре:* " .. format_game_time(session_stats.time_in_game or 0)
    }

    if quests_val > 0 then
        table.insert(lines, "{emoji_trophy} *Выполнено квестов:* " .. tostring(quests_val))
    end

    table.insert(lines, "")
    table.insert(lines, "{emoji_money} *ФИНАНСЫ ЗА ДЕНЬ:*")
    table.insert(lines, "  > {emoji_dollar} *Зарплата (общая):* $" .. formatNumber(wage_val))
    table.insert(lines, "  > {emoji_card} *Прирост по депозиту:* $" .. formatNumber(dep_val))

    if biz_val > 0 then table.insert(lines, "  > {emoji_biz} *Прибыль с бизнеса:* $" .. formatNumber(biz_val)) end
    if btc_val > 0 then table.insert(lines, "  > {emoji_coin} *Продажа BTC:* $" .. formatNumber(btc_val)) end
    if deal_val > 0 then
        table.insert(lines, "  > {emoji_money} *Доход от продаж (обмен):* $" .. formatNumber(deal_val))
    end

    table.insert(lines, "  > {emoji_fly} *ИТОГО ЗАРАБОТАНО:* $" .. formatNumber(total_val))
    if (session_stats.az_accumulated or 0) > 0 then
        table.insert(lines, "  > {emoji_coin} *Заработано AZ-Coins:* " .. formatNumber(session_stats.az_accumulated or 0) .. " AZ")
    end
    table.insert(lines, "===================================")

    return table.concat(lines, "\n")
end

local function get_week_report_text()
    local stats = getWeekStatistics(os.time())
    local lines = {
        "{emoji_money} *ЕЖЕНЕДЕЛЬНЫЙ ОТЧЁТ (Пн — Вс)*",
        "=============== Script [TM] ===============",
        "{emoji_money} *Общий доход за неделю:* $" .. formatNumber(stats.total),
        "{emoji_chart} Отслежено активных дней: " .. tostring(stats.days)
    }

    if stats.max_income > 0 then
        table.insert(lines, "{emoji_crown} *Самый прибыльный день:* " .. tostring(stats.max_date) .. " ($" .. formatNumber(stats.max_income) .. ")")
    end

    table.insert(lines, "===================================")
    return table.concat(lines, "\n")
end

local function get_month_report_text()
    local stats = getMonthStatistics(os.time())
    local lines = {
        "{emoji_bag} *ЕЖЕМЕСЯЧНЫЙ ОТЧЁТ (" .. os.date("%m.%Y") .. ")*",
        "=============== Script [TM] ===============",
        "{emoji_money} *Общий доход за месяц:* $" .. formatNumber(stats.total),
        "{emoji_chart} Отслежено активных дней: " .. tostring(stats.days)
    }

    if stats.max_income > 0 then
        table.insert(lines, "{emoji_crown} *Рекордный день месяца:* " .. tostring(stats.max_date) .. " ($" .. formatNumber(stats.max_income) .. ")")
    end

    table.insert(lines, "===================================")
    return table.concat(lines, "\n")
end

local function get_max_income_report_text()
    local max_inc, max_dt = getMaxIncomeOverall()
    if max_inc <= 0 then
        return "{emoji_warn} *РЕКОРДНЫЙ ДОХОД:* Данные о заработке пока отсутствуют."
    end
    
    local lines = {
        "{emoji_crown} *РЕКОРДНЫЙ ДЕНЬ ПО ЗАРАБОТКУ*",
        "=============== Script [TM] ===============",
        "{emoji_star} *Дата рекорда:* " .. tostring(max_dt),
        "{emoji_dollar} *Максимальная сумма за день:* $" .. formatNumber(max_inc),
        "==================================="
    }
    return table.concat(lines, "\n")
end




-- === ЛОГИРОВАНИЕ ОПЕРАЦИЙ В ИСТОРИЮ ===
local function add_history_log(category, desc, amount_str, is_expense)
    session_stats.tx_history = session_stats.tx_history or {}
    
    local now_ts = os.time()
    local now_time = os.date("%H:%M:%S", now_ts)
    local now_date = os.date("%d.%m.%Y", now_ts)

    table.insert(session_stats.tx_history, 1, { -- Новые записи всегда вверху
        timestamp = now_ts,
        date = now_date,
        time = now_time,
        category = category or "Финансы",
        desc = desc or "Операция",
        amount_text = tostring(amount_str),
        is_expense = is_expense or false
    })

    -- Храним последние 1000 операций
    while #session_stats.tx_history > 1000 do
        table.remove(session_stats.tx_history)
    end

    if type(save_stats_to_file) == "function" then
        save_stats_to_file()
    end
end





local function load_stats_from_file()
    local current_date = os.date("%d.%m.%Y")
    
    if doesFileExist(stats_file_path) then
        local f = io.open(stats_file_path, "r")
        if f then
            local content = f:read("*a")
            f:close()
            
            local ok, decoded = pcall(json.decode, content)
            if ok and decoded then
                session_stats = decoded
                                   session_stats.mining_expenses = session_stats.mining_expenses or 0
                   session_stats.mining_electricity = session_stats.mining_electricity or 0
                   session_stats.mining_coolants = session_stats.mining_coolants or 0
   

                session_stats.manually_added_money = session_stats.manually_added_money or 0
                session_stats.manually_added_az = session_stats.manually_added_az or 0
                session_stats.trade_income = session_stats.trade_income or 0
                session_stats.deal_income = session_stats.deal_income or 0
                session_stats.expenses_accumulated = math.abs(tonumber(session_stats.expenses_accumulated or 0))

                session_stats.goal_amount = session_stats.goal_amount or 10000000000
                session_stats.goal_type = session_stats.goal_type or 1
                session_stats.goal_scope = session_stats.goal_scope or 1
                session_stats.goal_notified = session_stats.goal_notified or false
                session_stats.goal_configured = session_stats.goal_configured or false
                session_stats.goal_enabled = (session_stats.goal_enabled == nil) and true or session_stats.goal_enabled
                session_stats.goal_start_from_zero = session_stats.goal_start_from_zero or false
                session_stats.goal_start_money = session_stats.goal_start_money or 0
                session_stats.goal_start_az = session_stats.goal_start_az or 0
session_stats.ignored_items = session_stats.ignored_items or {}
session_stats.tx_history = session_stats.tx_history or {} -- <-- ДОБАВИТЬ ЭТУ СТРОКУ


                if session_stats.last_active_date ~= current_date then
                    session_stats.time_in_game = 0
                    session_stats.quests_completed = 0
                    session_stats.wages_accumulated = 0
					
				                       session_stats.mining_expenses = 0
                       session_stats.mining_electricity = 0
                       session_stats.mining_coolants = 0
   

					
                    session_stats.dep_growth = 0
                    session_stats.biz_income = 0
                    session_stats.btc_income = 0
                    session_stats.az_accumulated = 0
                    session_stats.trade_income = 0
                    session_stats.deal_income = 0
                    session_stats.expenses_accumulated = 0
                    session_stats.report_sent = false
                end
            end
        end
    end
    
    session_stats.last_active_date = current_date
    session_stats.time_in_game = session_stats.time_in_game or 0
    session_stats.quests_completed = session_stats.quests_completed or 0
    session_stats.wages_accumulated = session_stats.wages_accumulated or 0
    session_stats.dep_growth = session_stats.dep_growth or 0
    session_stats.biz_income = session_stats.biz_income or 0
    session_stats.btc_income = session_stats.btc_income or 0
    session_stats.az_accumulated = session_stats.az_accumulated or 0
    session_stats.trade_income = session_stats.trade_income or 0
    session_stats.deal_income = session_stats.deal_income or 0
    session_stats.expenses_accumulated = math.abs(tonumber(session_stats.expenses_accumulated or 0))

    session_stats.report_sent = session_stats.report_sent or false
    session_stats.manually_added_money = session_stats.manually_added_money or 0
    session_stats.manually_added_az = session_stats.manually_added_az or 0
    session_stats.goal_amount = session_stats.goal_amount or 10000000000
    session_stats.goal_type = session_stats.goal_type or 1
    session_stats.goal_scope = session_stats.goal_scope or 1
    session_stats.goal_notified = session_stats.goal_notified or false
    session_stats.goal_configured = session_stats.goal_configured or false
    session_stats.goal_enabled = (session_stats.goal_enabled == nil) and true or session_stats.goal_enabled
    session_stats.goal_start_from_zero = session_stats.goal_start_from_zero or false
    session_stats.goal_start_money = session_stats.goal_start_money or 0
    session_stats.goal_start_az = session_stats.goal_start_az or 0
    session_stats.ignored_items = session_stats.ignored_items or {}
end

local default_config = {
    config = {
        chat = '',
        token = '',
        useAntiBlock = true,
		  skipped_version = '',
        itemAdding = false,
        sendUnknownItems = false,
        shortMessage = false, 
        payday = false,
        storage = false,
        spawnSelect = false,
        enableUINotifications = true,
        quest = true,
        autoDailyReport = true,
        autoWeeklyReport = true,
        autoMonthlyReport = true,
        autoMaxIncomeReport = true,
        paydayHeaderEmoji = "emoji_bag",
        paydayBankEmoji = "emoji_dollar",
        paydayDepositEmoji = "emoji_dollar",
        paydayWageEmoji = "emoji_dollar",
        paydayAZEmoji = "emoji_coin",
        itemEmoji = "emoji_gift",
        storageEmoji = "emoji_box",
        questEmoji = "emoji_trophy",
        spawnEmoji = "emoji_house"
    }
}

local remote_version_text = SCRIPT_VERSION
local update_available = false
local update_check_in_progress = false
local remote_update_info = "" 
local show_update_popup = imgui.new.bool(false) 

local cfg
local ok_cfg, err_cfg = pcall(inicfg.load, default_config, CFG_FILENAME)
if ok_cfg then 
    cfg = err_cfg 
else 
    cfg = default_config 
end

cfg.config.paydayHeaderEmoji = cfg.config.paydayHeaderEmoji or "emoji_bag"
cfg.config.paydayBankEmoji = cfg.config.paydayBankEmoji or "emoji_dollar"
cfg.config.paydayDepositEmoji = cfg.config.paydayDepositEmoji or "emoji_dollar"
cfg.config.paydayWageEmoji = cfg.config.paydayWageEmoji or "emoji_dollar"
cfg.config.paydayAZEmoji = cfg.config.paydayAZEmoji or "emoji_coin"
cfg.config.itemEmoji = cfg.config.itemEmoji or "emoji_gift"
cfg.config.storageEmoji = cfg.config.storageEmoji or "emoji_box"
cfg.config.questEmoji = cfg.config.questEmoji or "emoji_trophy"
cfg.config.spawnEmoji = cfg.config.spawnEmoji or "emoji_house"
if cfg.config.autoDailyReport == nil then cfg.config.autoDailyReport = true end
if cfg.config.autoWeeklyReport == nil then cfg.config.autoWeeklyReport = true end
if cfg.config.autoMonthlyReport == nil then cfg.config.autoMonthlyReport = true end
if cfg.config.autoMaxIncomeReport == nil then cfg.config.autoMaxIncomeReport = true end

ui = {
    window = imgui.new.bool(false),
    currentTab = imgui.new.int(1),
    show_update_popup = imgui.new.bool(false),
    show_emoji_selector_modal = imgui.new.bool(false),
    show_chart_window = imgui.new.bool(false),
    show_goal_settings = imgui.new.bool(false),
    show_add_funds_modal = imgui.new.bool(false),
    show_projection_pinned = imgui.new.bool(false),
    is_proj_window_hovered = false,

    chart_view_mode = imgui.new.int(0),
	chart_category_mode = imgui.new.int(0), -- 0: Общее, 1: Майнинг, 2: Торговля, 3: Бизнес

    chart_days_period = imgui.new.int(7),

    goal_edit_amount = imgui.new.char[64]("10000000000"),
    goal_edit_type = imgui.new.int(1),
    goal_edit_scope = imgui.new.int(1),
    goal_edit_start_zero = imgui.new.bool(true),

    item_search_input = imgui.new.char[128](""),
    add_funds_input = imgui.new.char[64](""),
    selected_emoji_setting = "",

    chat = imgui.new.char[128](tostring(cfg.config.chat)),
    token = imgui.new.char[128](tostring(cfg.config.token)),
    useAntiBlock = imgui.new.bool(cfg.config.useAntiBlock or true),
    itemAdding = imgui.new.bool(cfg.config.itemAdding or false),
    sendUnknownItems = imgui.new.bool(cfg.config.sendUnknownItems or false),
    shortMessage = imgui.new.bool(cfg.config.shortMessage or false),
    payday = imgui.new.bool(cfg.config.payday or false),
    storage = imgui.new.bool(cfg.config.storage or false),
    spawnSelect = imgui.new.bool(cfg.config.spawnSelect or false),
    quest = imgui.new.bool(cfg.config.quest or false),
    enableUINotifications = imgui.new.bool(cfg.config.enableUINotifications or false),
    autoDailyReport = imgui.new.bool(cfg.config.autoDailyReport),
    autoWeeklyReport = imgui.new.bool(cfg.config.autoWeeklyReport),
    autoMonthlyReport = imgui.new.bool(cfg.config.autoMonthlyReport),
    autoMaxIncomeReport = imgui.new.bool(cfg.config.autoMaxIncomeReport)
}

chat = imgui.new.char[128](tostring(cfg.config.chat))
token = imgui.new.char[128](tostring(cfg.config.token))
useAntiBlock = imgui.new.bool(cfg.config.useAntiBlock or true)

itemAdding = imgui.new.bool(cfg.config.itemAdding or false)
sendUnknownItems = imgui.new.bool(cfg.config.sendUnknownItems or false)
shortMessage = imgui.new.bool(cfg.config.shortMessage or false)
payday = imgui.new.bool(cfg.config.payday or false)
storage = imgui.new.bool(cfg.config.storage or false)
spawnSelect = imgui.new.bool(cfg.config.spawnSelect or false)
quest = imgui.new.bool(cfg.config.quest or false)
enableUINotifications = imgui.new.bool(cfg.config.enableUINotifications or false)

autoDailyReport = imgui.new.bool(cfg.config.autoDailyReport)
autoWeeklyReport = imgui.new.bool(cfg.config.autoWeeklyReport)
autoMonthlyReport = imgui.new.bool(cfg.config.autoMonthlyReport)
autoMaxIncomeReport = imgui.new.bool(cfg.config.autoMaxIncomeReport)

getPayday = false
listPayday = {}
paydayTimeout = 0

window = imgui.new.bool(false)
currentTab = imgui.new.int(1)

show_emoji_selector_modal = imgui.new.bool(false)
selected_emoji_setting = ""

local effilTelegramSendMessage = effil_ok and effil.thread(function(text, chatID, token, baseUrl)
    local requests = require('requests')
    local post_data = { params = { text = text, chat_id = chatID } }
    pcall(function()
        local url = ("%s/bot%s/sendMessage"):format(baseUrl, token)
        return requests.post(url, post_data)
    end)
end) or nil

function urlencode(str)
   if str then
      local utf8_str = u8:encode(str)
      for _, emoji in ipairs(emojis_list) do
         utf8_str = utf8_str:gsub("{" .. emoji.key .. "}", emoji.char)
      end
      utf8_str = utf8_str:gsub("([^%w _%%%-%.~])", function(c) 
         return string.format("%%%02X", string.byte(c)) 
      end)
      utf8_str = utf8_str:gsub(" ", "%%20")
      return utf8_str
   end
   return ""
end

local function sendTelegramMessage(text)
    local chat_id_str = ffi.string(chat)
    local token_str = ffi.string(token)

    if chat_id_str == '' or token_str == '' or not effilTelegramSendMessage then return end
    
    local baseUrl = useAntiBlock[0] and ANTIBLOCK_URL or "https://api.telegram.org"
    local clean_text = text:gsub('{......}', '')
    clean_text = formatNumbersInText(clean_text)
    local encoded_text = urlencode(clean_text)
    
    effilTelegramSendMessage(encoded_text, chat_id_str, token_str, baseUrl)
end

local function checkGoalCompletion()
    local target = tonumber(session_stats.goal_amount) or 0
    if target <= 0 or not session_stats.goal_configured or not session_stats.goal_enabled then return end

    local current = 0
    local unit = "$"

    if session_stats.goal_type == 1 then
        if session_stats.goal_scope == 1 then
            local base = getTotalIncomeOverall()
            if session_stats.goal_start_from_zero then
                base = base - (session_stats.goal_start_money or 0)
            end
            current = math.max(0, base) + (session_stats.manually_added_money or 0)
        else
            local total_earned_today = (session_stats.wages_accumulated or 0) + (session_stats.dep_growth or 0) + (session_stats.biz_income or 0) + (session_stats.btc_income or 0) + (session_stats.trade_income or 0) + (session_stats.deal_income or 0)
            local net_total = total_earned_today - math.abs(tonumber(session_stats.expenses_accumulated) or 0)
            current = net_total + (session_stats.manually_added_money or 0)
        end
        unit = "$"
    else
        if session_stats.goal_scope == 1 then
            local base = getTotalAZOverall()
            if session_stats.goal_start_from_zero then
                base = base - (session_stats.goal_start_az or 0)
            end
            current = math.max(0, base) + (session_stats.manually_added_az or 0)
        else
            current = (session_stats.az_accumulated or 0) + (session_stats.manually_added_az or 0)
        end
        unit = "AZ"
    end
    
    if current >= target and not session_stats.goal_notified then
        session_stats.goal_notified = true
        save_stats_to_file()
        
        show_arz_notify('success', 'ПОБЕДА!', 'Финансовая цель 100% достигнута!', 5000)
        
        local goal_text = string.format(
            "{emoji_crown} *ФИНАНСОВАЯ ЦЕЛЬ УСПЕШНО ДОСТИГНУТА!* {emoji_trophy}\n" ..
            "=============== Script [TM] ===============\n" ..
            "{emoji_star} *Заданная цель:* %s %s\n" ..
            "{emoji_bag} *Накопленный результат:* %s %s\n" ..
            "{emoji_rocket} *Прогресс:* 100%%\n" ..
            "=====================================",
            formatNumber(target), unit, formatNumber(current), unit
        )
        sendTelegramMessage(goal_text)
    end
end

function downloadAndInstallUpdate()
    if not requests_ok then return end
    sampAddChatMessage("{ffff00}[TM] Загрузка обновления...", -1)
    lua_thread.create(function()
        local requests = require('requests')
        local ok, response = pcall(requests.get, UPDATE_URL)
        if ok and response.status_code == 200 then
            local script_path = thisScript().path
            local f = io.open(script_path, "wb")
            if f then
                f:write(response.text)
                f:close()
                sampAddChatMessage("{00FF00}[TM] Скрипт обновлен! Перезагрузка...", -1)
                thisScript():reload()
            end
        end
    end)
end

function checkUpdate()
    if update_check_in_progress or not requests_ok then return end
    update_check_in_progress = true
    remote_update_info = "" 
    lua_thread.create(function()
        local requests = require('requests')
        local ok, response = pcall(requests.get, UPDATE_URL)
        update_check_in_progress = false
        if ok and response.status_code == 200 then
            local remote_version = response.text:match('local%s+SCRIPT_VERSION%s*=%s*"([^"]+)"')
            local remote_info = response.text:match('local%s+UPDATE_INFO%s*=%s*%[%[(.-)%]%]')

            if remote_version and remote_version ~= SCRIPT_VERSION then
                -- Проверяем, не пропускает ли пользователь именно эту версию
                if cfg.config.skipped_version ~= remote_version then
                    update_available = true
                    remote_version_text = remote_version
                    remote_update_info = remote_info or "Информация об изменениях отсутствует." 
                    show_update_popup[0] = true
                    window[0] = false
                end
            end

        end
    end)
end

local function saveConfig()
    cfg.config.chat = ffi.string(chat)
    cfg.config.token = ffi.string(token)
    cfg.config.useAntiBlock = useAntiBlock[0]
    cfg.config.itemAdding = itemAdding[0]
    cfg.config.sendUnknownItems = sendUnknownItems[0]
    cfg.config.shortMessage = shortMessage[0] 
    cfg.config.payday = payday[0]
    cfg.config.storage = storage[0]
    cfg.config.quest = quest[0]
    cfg.config.spawnSelect = spawnSelect[0]
    cfg.config.enableUINotifications = enableUINotifications[0]
    cfg.config.autoDailyReport = autoDailyReport[0]
    cfg.config.autoWeeklyReport = autoWeeklyReport[0]
    cfg.config.autoMonthlyReport = autoMonthlyReport[0]
    cfg.config.autoMaxIncomeReport = autoMaxIncomeReport[0]
	 cfg.config.skipped_version = cfg.config.skipped_version or ''

    pcall(inicfg.save, cfg, CFG_FILENAME)
end

function main()
    while not isSampAvailable() do wait(0) end
    
    loadItemsDatabase()
    load_stats_from_file()

    sampAddChatMessage('Script [TM] {ffffff}Активация командой: /tm', 0x3083ff)
    sampAddChatMessage('Script [TM] {ffffff}Разработан и написан Dima_Shmakov', 0x3083ff)
    sampAddChatMessage('Script [TM] {ffffff}Версия скрипта ' .. SCRIPT_VERSION, 0x3083ff)
    
    sampRegisterChatCommand('tm', function() 
        wasOpenedByCommand = true
        if update_available then
            show_update_popup[0] = true
            window[0] = false 
        else
            if show_add_funds_modal[0] then
                window[0] = true
                show_add_funds_modal[0] = false
            else
                window[0] = not window[0]
            end
        end
    end)
    sampRegisterChatCommand('tpmineexp', function(param)
        if not param or param == "" then
            sampAddChatMessage("{FF6347}[TM] Использование: /tpmineexp [сумма]", -1)
            sampAddChatMessage("{FF6347}[TM] Текущие траты на майнинг за сегодня: $" .. formatNumber(session_stats.mining_expenses or 0), -1)
            return
        end
        local val = parse_numeric_value(param)
        session_stats.mining_expenses = val
        save_stats_to_file()
        show_arz_notify('success', 'TM', 'Траты на майнинг изменены!', 3000)
        sampAddChatMessage("{00FF00}[TM] Траты на майнинг за сегодня установлены на: $" .. formatNumber(val), -1)
    end)

    -- === НОВЫЕ КОМАНДЫ ===
    sampRegisterChatCommand('myip', function()
        local ip, port = sampGetCurrentServerAddress()
        local sName = sampGetCurrentServerName() or "Неизвестен"
        local is_vc = isViceCityServer() and "{00FF00}(Vice City)" or "{FF6347}(Обычный сервер)"
        sampAddChatMessage(string.format("{00FF00}[TM] IP: {FFFFFF}%s:%d | Сервер: %s %s", ip, port, sName, is_vc), -1)
    end)


    sampRegisterChatCommand('tptrats', function(param)
        if not param or param == "" then
            sampAddChatMessage("{FF6347}[TM] Использование: /tptrats [сумма]", -1)
            sampAddChatMessage("{FF6347}[TM] Текущие траты за сегодня: $" .. formatNumber(session_stats.expenses_accumulated or 0), -1)
            return
        end
        local val = parse_numeric_value(param)
        session_stats.expenses_accumulated = val
        save_stats_to_file()
        show_arz_notify('success', 'TM', 'Траты за сегодня изменены!', 3000)
        sampAddChatMessage("{00FF00}[TM] Траты за сегодня установлены на: $" .. formatNumber(val), -1)
    end)

    sampRegisterChatCommand('tpdov', function(param)
        if not param or param == "" then
            sampAddChatMessage("{FF6347}[TM] Использование: /tpdov [сумма]", -1)
            sampAddChatMessage("{FF6347}[TM] Текущий доход от продаж за сегодня: $" .. formatNumber(session_stats.trade_income or 0), -1)
            return
        end
        local val = parse_numeric_value(param)
        session_stats.trade_income = val
        save_stats_to_file()
        show_arz_notify('success', 'TM', 'Доход от продаж изменен!', 3000)
        sampAddChatMessage("{00FF00}[TM] Доход от продаж за сегодня установлен на: $" .. formatNumber(val), -1)
    end)

    checkUpdate()

    lua_thread.create(function()
        local last_tick = os.time()
        while true do
            wait(1000)
            local current_tick = os.time()
            local diff = current_tick - last_tick
            last_tick = current_tick
            if diff > 0 then
                session_stats.time_in_game = (session_stats.time_in_game or 0) + diff
                save_stats_to_file()
            end
            
            checkGoalCompletion()

            local current_date = os.date("%d.%m.%Y")
            if session_stats.last_active_date ~= "" and session_stats.last_active_date ~= current_date then
                local previous_date = session_stats.last_active_date
                local previous_ts = getDateNumber(previous_date)

                saveDayToHistory(previous_date)

                if autoDailyReport[0] and session_stats.report_sent == false then
                    sendTelegramMessage(get_session_report_text(previous_date))
                    session_stats.report_sent = true
                end

                local previous_wday = tonumber(os.date("%w", previous_ts))
                if autoWeeklyReport[0] and previous_wday == 0 then
                    sendTelegramMessage(get_week_report_text())
                end

                local old_m = tonumber(os.date("%m", previous_ts))
                local new_m = tonumber(os.date("%m", os.time()))
                if autoMonthlyReport[0] and old_m ~= new_m then
                    sendTelegramMessage(get_month_report_text())
                end

                if autoMaxIncomeReport[0] then
                    sendTelegramMessage(get_max_income_report_text())
                end

                session_stats.last_active_date = current_date
                session_stats.quests_completed = 0
                session_stats.wages_accumulated = 0
                session_stats.dep_growth = 0
                session_stats.biz_income = 0
                session_stats.btc_income = 0
                session_stats.az_accumulated = 0
                session_stats.trade_income = 0
                session_stats.deal_income = 0
                session_stats.expenses_accumulated = 0
                session_stats.time_in_game = 0
                session_stats.report_sent = false

                if session_stats.goal_scope == 2 then
                    session_stats.goal_notified = false
                end

                save_stats_to_file()
            end
        end
    end)

    wait(-1)
end

function visualCEF(str, is_encoded)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt16(bs, #str)
    raknetBitStreamWriteInt8(bs, is_encoded and 1 or 0)
    if is_encoded then raknetBitStreamEncodeString(bs, str) else raknetBitStreamWriteString(bs, str) end
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

function show_arz_notify(type, title, text, time)
    if enableUINotifications[0] then
        local function escape_js(s) return s:gsub("\\", "\\\\"):gsub('"', '\\"') end
        local str = ('window.executeEvent("event.notify.initialize", "[\\"%s\\", \\"%s\\", \\"%s\\", \\"%s\\"]");'):format(escape_js(type), escape_js(title), escape_js(text), tostring(time))
        visualCEF(str, true)
    end
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    modern_style() 
    if doesFileExist(logo_path) then
        local ok, tex = pcall(imgui.CreateTextureFromFile, logo_path)
        if ok and tex then logo_texture = tex end
    end

    if fa_ok and fa then
        local config = imgui.ImFontConfig()
        config.MergeMode = true
        config.PixelSnapH = true
        local iconRanges = imgui.new.ImWchar[3](fa.min_range, fa.max_range, 0)
        local font = imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85('solid'), 14, config, iconRanges)
        if font ~= nil then font_loaded = true end
    end
end)

function modern_style()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors

    style.WindowRounding = 12.0     
    style.ChildRounding = 10.0      
    style.FrameRounding = 8.0       
    style.PopupRounding = 10.0
    style.ScrollbarRounding = 12.0  
    style.GrabRounding = 8.0

    colors[imgui.Col.WindowBg]         = imgui.ImVec4(0.09, 0.11, 0.15, 1.00)
    colors[imgui.Col.ChildBg]          = imgui.ImVec4(0.14, 0.17, 0.23, 1.00)
    colors[imgui.Col.PopupBg]          = imgui.ImVec4(0.09, 0.11, 0.15, 1.00)
    colors[imgui.Col.Border]           = imgui.ImVec4(0.14, 0.17, 0.23, 1.00)
    colors[imgui.Col.FrameBg]          = imgui.ImVec4(0.06, 0.08, 0.11, 1.00)
    colors[imgui.Col.FrameBgHovered]   = imgui.ImVec4(0.12, 0.14, 0.18, 1.00)
    colors[imgui.Col.FrameBgActive]    = imgui.ImVec4(0.15, 0.18, 0.25, 1.00)
    colors[imgui.Col.Button]           = imgui.ImVec4(0.18, 0.20, 0.26, 1.00)
    colors[imgui.Col.ButtonHovered]    = imgui.ImVec4(0.24, 0.26, 0.33, 1.00)
    colors[imgui.Col.ButtonActive]     = imgui.ImVec4(0.14, 0.15, 0.20, 1.00)
    colors[imgui.Col.CheckMark]        = imgui.ImVec4(0.18, 0.80, 0.44, 1.00)
    colors[imgui.Col.SliderGrab]       = imgui.ImVec4(0.18, 0.80, 0.44, 1.00)
    colors[imgui.Col.Text]             = imgui.ImVec4(0.90, 0.90, 0.90, 1.00)
    colors[imgui.Col.TextDisabled]     = imgui.ImVec4(0.50, 0.55, 0.63, 1.00)
end

imgui.OnFrame(function() return window[0] or show_update_popup[0] or show_emoji_selector_modal[0] or show_chart_window[0] or show_goal_settings[0] or show_add_funds_modal[0] end, function(player)
    local resX, resY = getScreenResolution()
 
    if window[0] then
        local sizeX, sizeY = 700, 500
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.Always)

        imgui.Begin('##MainSettings', window, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar)
        
        if imgui.IsWindowHovered(1) and imgui.IsMouseDragging(0) and not imgui.IsAnyItemActive() then
            local delta = imgui.GetIO().MouseDelta
            local pos = imgui.GetWindowPos()
            imgui.SetWindowPos(imgui.ImVec2(pos.x + delta.x, pos.y + delta.y))
        end

        imgui.BeginChild("##left_sidebar", imgui.ImVec2(180, sizeY - 20), true)
            local sidebar_w = 160

            imgui.SetCursorPos(imgui.ImVec2(10, 10))
            if logo_texture then
                imgui.Image(logo_texture, imgui.ImVec2(sidebar_w, 70))
            else
                local draw_list = imgui.GetWindowDrawList()
                local p = imgui.GetCursorScreenPos()
                local bg_col = imgui.GetColorU32Vec4(imgui.ImVec4(0.14, 0.17, 0.23, 1.00))
                local border_col = imgui.GetColorU32Vec4(imgui.ImVec4(0.95, 0.76, 0.18, 1.00))
                draw_list:AddRectFilled(p, imgui.ImVec2(p.x + sidebar_w, p.y + 70), bg_col, 8.0)
                draw_list:AddRect(p, imgui.ImVec2(p.x + sidebar_w, p.y + 70), border_col, 8.0, 0, 1.5)
                
                local crown_ic = getIcon("CROWN", "TM")
                local ic_w = imgui.CalcTextSize(crown_ic).x
                imgui.SetCursorPos(imgui.ImVec2((sidebar_w - ic_w) / 2 + 10, 30))
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), crown_ic)
            end

            imgui.SetCursorPosY(86)
            local title_text = "SCRIPT [TM]"
            local title_w = imgui.CalcTextSize(u8(title_text)).x
            imgui.SetCursorPosX((180 - title_w) / 2)
            imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8(title_text))

            imgui.SetCursorPosY(108)
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 10))
 
            local function drawSidebarTab(tab_index, icon_name, label_text)
                local is_active = (currentTab[0] == tab_index)
                if is_active then
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.4))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.80, 0.44, 0.6))
                    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.18, 0.80, 0.44, 0.8))
                else
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.20, 0.26, 0.6))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.26, 0.33, 0.8))
                    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.14, 0.15, 0.20, 1.0))
                end

                if imgui.Button(getIcon(icon_name, "") .. u8(label_text), imgui.ImVec2(sidebar_w, 36)) then
                    currentTab[0] = tab_index
                end
                imgui.PopStyleColor(3)
            end

drawSidebarTab(1, "GEAR", "Настройки")
imgui.Dummy(imgui.ImVec2(0, 5))
drawSidebarTab(2, "BELL", "Уведомления")
imgui.Dummy(imgui.ImVec2(0, 5))
drawSidebarTab(3, "SLIDERS", "Стилизация")
imgui.Dummy(imgui.ImVec2(0, 5))
drawSidebarTab(4, "CHART_LINE", "Статистика")
imgui.Dummy(imgui.ImVec2(0, 5))
drawSidebarTab(5, "BAN", "Игнор предметов")
imgui.Dummy(imgui.ImVec2(0, 5))
drawSidebarTab(6, "CLOCK_ROTATE_LEFT", "История") -- <-- ДОБАВЛЕНО


            imgui.SetCursorPosY(sizeY - 80)
            imgui.Separator()
            imgui.SetCursorPosY(sizeY - 65)
            
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.20, 0.26, 0.8))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.26, 0.33, 1.0))
            if imgui.Button(u8("Закрыть"), imgui.ImVec2(sidebar_w, 30)) then
                window[0] = false
            end
            imgui.PopStyleColor(2)

        imgui.EndChild()

        imgui.SameLine()

        imgui.BeginChild("##right_content", imgui.ImVec2(sizeX - 210, sizeY - 20), true)
            
            if currentTab[0] == 1 then
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("GEAR", "") .. u8("Telegram Настройки"))
                imgui.Dummy(imgui.ImVec2(0, 5))
                imgui.TextDisabled(u8("ID Чата:"))
                imgui.SetNextItemWidth(-1)
                imgui.InputText("##chatid", chat, ffi.sizeof(chat), imgui.InputTextFlags.Password)
                imgui.TextDisabled(u8("Токен бота:"))
                imgui.SetNextItemWidth(-1)
                imgui.InputText("##token", token, ffi.sizeof(token), imgui.InputTextFlags.Password)
                imgui.Dummy(imgui.ImVec2(0, 10))
                imgui.Separator()
                imgui.Dummy(imgui.ImVec2(0, 5))
                imgui.Checkbox(u8('Использовать обход блокировки'), useAntiBlock)
                imgui.TextDisabled(u8("(Рекомендуется для жителей РФ)"))
                imgui.Dummy(imgui.ImVec2(0, 10))
                if imgui.Button(u8('Сохранить настройки'), imgui.ImVec2(-1, 30)) then
                    saveConfig()
                    show_arz_notify('success', 'TM', 'Сохранено', 3000)
                end
                if imgui.Button(u8('Проверить соединение (Тест)'), imgui.ImVec2(-1, 30)) then
                    sendTelegramMessage("Проверка связи с Script [TM] {emoji_wave}")
                end
                if imgui.Button(u8('Проверить обновления'), imgui.ImVec2(-1, 30)) then
                    checkUpdate()
                end
                if imgui.Button(u8('Обновить Список предметов'), imgui.ImVec2(-1, 30)) then
                    updateFilesAsync()
                end

            elseif currentTab[0] == 2 then
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("BELL", "") .. u8("Управление уведомлениями и авто-отчётами"))
                imgui.Separator()
                imgui.Dummy(imgui.ImVec2(0, 5))

                local col_h = 240
                if not preview_hover_text then preview_hover_text = "" end

                imgui.BeginChild("##notif_col_left", imgui.ImVec2(235, col_h), false)
                    imgui.TextColored(imgui.ImVec4(0.18, 0.80, 0.44, 1.00), u8("— Оповещения —"))
                    imgui.Dummy(imgui.ImVec2(0, 5))
                    
                    if imgui.Checkbox(u8('Визуальные UI уведомления'), enableUINotifications) then saveConfig() end
                    if imgui.IsItemHovered() then
                        preview_hover_text = "Показывать всплывающие уведомления в интерфейсе игры (снизу в центре)."
                    end
                    imgui.Separator()

                    if imgui.Checkbox(u8('Оповещение о предметах'), itemAdding) then saveConfig() end
                    if imgui.IsItemHovered() then
                        local tag = getEmojiForDisplay("itemEmoji")
                        if shortMessage[0] then
                            preview_hover_text = "Вам был добавлен предмет 'Платиновая рулетка', используйте клавишу 'Y' или /invent"
                        else
                            preview_hover_text = tag .. "Вам был добавлен предмет Платиновая рулетка"
                        end
                    end

                    if itemAdding[0] then
                        imgui.Indent(15)
                        if imgui.Checkbox(u8('Отправлять неизвестные'), sendUnknownItems) then saveConfig() end
                        if imgui.IsItemHovered() then preview_hover_text = "Отправлять сообщения даже если предметов нет в базе скрипта." end
                        
                        if imgui.Checkbox(u8('Старый вид сообщений'), shortMessage) then saveConfig() end
                        if imgui.IsItemHovered() then preview_hover_text = "Вам был добавлен предмет 'Платиновая рулетка', используйте клавишу 'Y' или /invent." end
                        imgui.Unindent(15)
                    end
                    
                    if imgui.Checkbox(u8('PayDay Чек'), payday) then saveConfig() end
                    if imgui.IsItemHovered() then
                        local h = getEmojiForDisplay("paydayHeaderEmoji")
                        local b = getEmojiForDisplay("paydayBankEmoji")
                        local d = getEmojiForDisplay("paydayDepositEmoji")
                        local w = getEmojiForDisplay("paydayWageEmoji")
                        local a = getEmojiForDisplay("paydayAZEmoji")
                        preview_hover_text = string.format("%sPayDay | БАНКОВСКИЙ ЧЕК%s\n==================================\n| Текущая сумма в банке: %s2.177.123 (+%s1.430.313)\n| В данный момент у вас 244-й уровень\n| Текущая сумма на депозите: %s554.622.304 (+%s1.434.264)\n| Общая заработная плата: %s1.430.313\n| Баланс на донат-счет: %s97.714 (+%s14)\n==================================", h, h, b, b, d, d, w, a, a)
                    end

                    if imgui.Checkbox(u8('Хранилище предметов'), storage) then saveConfig() end
                    if imgui.IsItemHovered() then
                        preview_hover_text = getEmojiForDisplay("storageEmoji") .. "Вам добавлен новый предмет 'Платиновая рулетка' в хранилище! /storage"
                    end

                    if imgui.Checkbox(u8('Квесты и Задания'), quest) then saveConfig() end
                    if imgui.IsItemHovered() then
                        preview_hover_text = getEmojiForDisplay("questEmoji") .. "[Боевой Пропуск]\nВыполнил задание: 'Тестовое Задание'"
                    end

                    if imgui.Checkbox(u8('Выбор места спавна'), spawnSelect) then saveConfig() end
                    if imgui.IsItemHovered() then
                        preview_hover_text = getEmojiForDisplay("spawnEmoji") .. "Вы выбрали местом спавна: Дом #394"
                    end

                imgui.EndChild()

                imgui.SameLine()

                local line_pos = imgui.GetCursorScreenPos()
                local d_list = imgui.GetWindowDrawList()
                d_list:AddRectFilled(imgui.ImVec2(line_pos.x + 2, line_pos.y), imgui.ImVec2(line_pos.x + 4, line_pos.y + col_h), imgui.GetColorU32Vec4(imgui.ImVec4(0.95, 0.76, 0.18, 0.60)))
                imgui.Dummy(imgui.ImVec2(10, 0))

                imgui.SameLine()

                imgui.BeginChild("##notif_col_right", imgui.ImVec2(220, col_h), false)
                    imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8("— Авто-отчёты —"))
                    imgui.Dummy(imgui.ImVec2(0, 5))
                    
                    if imgui.Checkbox(u8('Ежедневный отчёт в 00:00'), autoDailyReport) then saveConfig() end
                    if imgui.IsItemHovered() then preview_hover_text = get_session_report_text("01.08.2026") end

                    if imgui.Checkbox(u8('Недельный отчёт (Пн-Вс)'), autoWeeklyReport) then saveConfig() end
                    if imgui.IsItemHovered() then preview_hover_text = get_week_report_text() end

                    if imgui.Checkbox(u8('Месячный отчёт'), autoMonthlyReport) then saveConfig() end
                    if imgui.IsItemHovered() then preview_hover_text = get_month_report_text() end

                    if imgui.Checkbox(u8('Отчёт о рекорде дохода'), autoMaxIncomeReport) then saveConfig() end
                    if imgui.IsItemHovered() then preview_hover_text = get_max_income_report_text() end
                imgui.EndChild()

                imgui.Separator()
                imgui.Dummy(imgui.ImVec2(0, 2))
                imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), getIcon("EYE", "") .. u8("Предпросмотр сообщения (наведите на любой пункт выше):"))
                
                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.06, 0.08, 0.11, 1.00))
                imgui.BeginChild("##preview_msg", imgui.ImVec2(-1, 140), true)
                    if preview_hover_text == "" then
                        local tag = getEmojiForDisplay("itemEmoji")
                        preview_hover_text = tag .. "Вам был добавлен предмет Сертификат Платиновая рулетка "
                    end
                    imgui.TextWrapped(u8(preview_hover_text))
                imgui.EndChild()
                imgui.PopStyleColor()

            elseif currentTab[0] == 3 then
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("SLIDERS", "") .. u8("Настройка шаблонов и смайликов"))
                imgui.TextDisabled(u8("Выберите смайлик для отображения в отчетах Telegram:"))
                imgui.Dummy(imgui.ImVec2(0, 5))

                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.06, 0.08, 0.11, 1.00))
                imgui.BeginChild("##styling_interactive", imgui.ImVec2(0, sizeY - 85), true)
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.2))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.80, 0.44, 0.4))
                    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(6, 4))

                    local function drawEmojiConfigRow(label, config_key, test_message_base)
                        imgui.Text(label)
                        imgui.SameLine(220)
                        local render_str = getEmojiRenderString(cfg.config[config_key])
                        if imgui.Button(render_str .. "##btn_" .. config_key, imgui.ImVec2(100, 24)) then
                            selected_emoji_setting = config_key
                            show_emoji_selector_modal[0] = true
                        end
                        if test_message_base then
                            imgui.SameLine()
                            if imgui.Button(u8("Тест##test_" .. config_key), imgui.ImVec2(50, 24)) then
                                local current_emoji_key = cfg.config[config_key]
                                local emoji_tag = current_emoji_key ~= "emoji_none" and "{" .. current_emoji_key .. "} " or ""
                                sendTelegramMessage(emoji_tag .. test_message_base)
                                show_arz_notify('info', 'Тест', 'Тестовое сообщение отправлено в Telegram.', 3000)
                            end
                        end
                    end

                    imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8("— Шаблон PayDay —"))
                    imgui.Separator()
                    drawEmojiConfigRow(u8("PayDay Шапка"), "paydayHeaderEmoji")
                    drawEmojiConfigRow(u8("PayDay Банк"), "paydayBankEmoji")
                    drawEmojiConfigRow(u8("PayDay Депозит"), "paydayDepositEmoji")
                    drawEmojiConfigRow(u8("PayDay Зарплата"), "paydayWageEmoji")
                    drawEmojiConfigRow(u8("PayDay Донат (AZ)"), "paydayAZEmoji")

                    imgui.Dummy(imgui.ImVec2(0, 5))
                    if imgui.Button(u8("Тест PayDay сообщения"), imgui.ImVec2(-1, 28)) then
                        local header_tag = cfg.config.paydayHeaderEmoji ~= "emoji_none" and "{" .. cfg.config.paydayHeaderEmoji .. "}" or ""
                        local bank_tag = cfg.config.paydayBankEmoji ~= "emoji_none" and "{" .. cfg.config.paydayBankEmoji .. "}" or ""
                        local dep_tag = cfg.config.paydayDepositEmoji ~= "emoji_none" and "{" .. cfg.config.paydayDepositEmoji .. "}" or ""
                        local wage_tag = cfg.config.paydayWageEmoji ~= "emoji_none" and "{" .. cfg.config.paydayWageEmoji .. "}" or ""
                        local az_tag = cfg.config.paydayAZEmoji ~= "emoji_none" and "{" .. cfg.config.paydayAZEmoji .. "}" or ""
                        local test_message = string.format("%sPayDay | БАНКОВСКИЙ ЧЕК%s\n==========\nТекущая сумма в банке: %s200400500$\nВ данный момент у вас 200 уровень\nТекущая сумма на депозите: %s987654321$\nОбщая заработная плата: %s500000$\nБаланс на донат-счет: %s12AZ\n==========", header_tag, header_tag, bank_tag, dep_tag, wage_tag, az_tag)
                        sendTelegramMessage(test_message)
                        show_arz_notify('info', 'Тест PayDay', 'Тестовое сообщение PayDay отправлено в Telegram.', 3000)
                    end
                    imgui.Separator()

                    imgui.Dummy(imgui.ImVec2(0, 5))
                    imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8("— Другие Сообщения —"))
                    imgui.Separator()
                    drawEmojiConfigRow(u8("Инвентарь (Предметы)"), "itemEmoji", "Вам был добавлен предмет: 'Платиновая рулетка'")
                    drawEmojiConfigRow(u8("Сообщение Хранилища"), "storageEmoji", "У Вас есть предметы в хранилище пункта выдачи.")
                    drawEmojiConfigRow(u8("Выбор места спавна"), "spawnEmoji", "Вы выбрали местом спавна: Дом #394")
                    drawEmojiConfigRow(u8("Квесты / Задания"), "questEmoji", "[Боевой Пропуск] Выполнил задание: 'Тестовое Задание'")

                    imgui.PopStyleVar()
                    imgui.PopStyleColor(2)
                imgui.EndChild()
                imgui.PopStyleColor()

            elseif currentTab[0] == 4 then
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("CHART_LINE", "") .. u8("Ежедневный Финансовый Журнал"))
                
                imgui.SameLine(sizeX - 250)
                local q_icon = (font_loaded and fa_ok and fa and fa.CIRCLE_QUESTION) and fa.CIRCLE_QUESTION or "?"
                imgui.PushStyleColor(imgui.Col.Button, show_projection_pinned[0] and imgui.ImVec4(0.95, 0.76, 0.18, 0.5) or imgui.ImVec4(0.95, 0.76, 0.18, 0.2))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.95, 0.76, 0.18, 0.4))
                if imgui.Button(q_icon .. "##projection_btn", imgui.ImVec2(28, 24)) then
                    show_projection_pinned[0] = not show_projection_pinned[0]
                    imgui.OpenPopup("ProjectionPopup")
                end
                
                local btn_hovered = imgui.IsItemHovered()
                if imgui.IsItemHovered() then
                    imgui.BeginTooltip()
                    imgui.Text(u8("Прогноз прибыли"))
                    imgui.EndTooltip()
                end
                imgui.PopStyleColor(2)
                
                imgui.SetNextWindowSize(imgui.ImVec2(380, 420), imgui.Cond.Always)
                if imgui.BeginPopup("ProjectionPopup") then
                    imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("CHART_LINE", "") .. u8("Прогноз прибыли (при непрерывной игре)"))
                    imgui.Separator()
                    imgui.Dummy(imgui.ImVec2(0, 3))
                    
                    local last_w = session_stats.last_payday_wage or 0
                    local last_d = session_stats.last_payday_dep or 0
                    local last_a = session_stats.last_payday_az or 0
                    
                    imgui.TextColored(imgui.ImVec4(0.60, 0.65, 0.73, 1.00), getIcon("CLOCK", "") .. u8("Последний полученный PayDay:"))
                    imgui.BeginChild("##last_payday_card", imgui.ImVec2(0, 70), true)
                        imgui.Text(getIcon("DOLLAR_SIGN", "") .. u8("Зарплата: $") .. formatNumber(last_w))
                        imgui.Text(getIcon("CREDIT_CARD", "") .. u8("Депозит: $") .. formatNumber(last_d))
                        imgui.Text(getIcon("COINS", "") .. u8("AZ-Coins: ") .. formatNumber(last_a) .. " AZ")
                    imgui.EndChild()
                    imgui.Dummy(imgui.ImVec2(0, 5))
                    
                    local function drawProjectionCard(title_label, icon_name, multiplier)
                        imgui.TextColored(imgui.ImVec4(0.18, 0.80, 0.44, 1.00), getIcon(icon_name, "") .. u8(title_label))
                        imgui.BeginChild("##card_" .. title_label, imgui.ImVec2(0, 70), true)
                            imgui.Text(getIcon("DOLLAR_SIGN", "") .. u8("Зарплата: $") .. formatNumber(last_w * multiplier))
                            imgui.Text(getIcon("CREDIT_CARD", "") .. u8("Депозит: $") .. formatNumber(last_d * multiplier))
                            imgui.Text(getIcon("COINS", "") .. u8("AZ: ") .. formatNumber(last_a * multiplier) .. " AZ")
                        imgui.EndChild()
                        imgui.Dummy(imgui.ImVec2(0, 5))
                    end
                    
                    drawProjectionCard("За 1 час:", "CLOCK", 2)
                    drawProjectionCard("За 24 часа:", "CALENDAR_DAYS", 48)
                    drawProjectionCard("За месяц:", "CALENDAR_DAYS", 1440)
                    
                    imgui.EndPopup()
                end



                imgui.Separator()
                imgui.Dummy(imgui.ImVec2(0, 2))

                local info_card_h = (session_stats.quests_completed or 0) > 0 and 70 or 50
                imgui.BeginChild("##session_info_card", imgui.ImVec2(0, info_card_h), true)
                    imgui.TextColored(imgui.ImVec4(0.60, 0.65, 0.73, 1.00), getIcon("CALENDAR_DAYS", "") .. u8("Дата сбора данных: ") .. tostring(session_stats.last_active_date))
                    imgui.TextColored(imgui.ImVec4(0.60, 0.65, 0.73, 1.00), getIcon("CLOCK", "") .. u8("Время в игре сегодня: ") .. format_game_time(session_stats.time_in_game))
                    if (session_stats.quests_completed or 0) > 0 then
                        imgui.TextColored(imgui.ImVec4(0.60, 0.65, 0.73, 1.00), getIcon("TROPHY", "") .. u8("Выполнено квестов за сегодня: ") .. tostring(session_stats.quests_completed))
                    end
                imgui.EndChild()
                
                imgui.Separator()
                imgui.Dummy(imgui.ImVec2(0, 2))

                imgui.TextColored(imgui.ImVec4(0.18, 0.80, 0.44, 1.00), getIcon("MONEY_BILL_WAVE", "") .. u8("Чистый баланс за сегодня:"))
                
                local wage_val = session_stats.wages_accumulated or 0
                local dep_val = session_stats.dep_growth or 0
                local biz_val = session_stats.biz_income or 0
                local btc_val = session_stats.btc_income or 0
                local trade_val = session_stats.trade_income or 0
                local deal_val = session_stats.deal_income or 0
                local expenses_val = math.abs(tonumber(session_stats.expenses_accumulated) or 0)
                local az_val = session_stats.az_accumulated or 0
                
                local total_earned = wage_val + dep_val + biz_val + btc_val + trade_val + deal_val
                local net_total = total_earned - expenses_val

                local rows_count = 3
                if biz_val > 0 then rows_count = rows_count + 1 end
                if btc_val > 0 then rows_count = rows_count + 1 end
                if trade_val > 0 then rows_count = rows_count + 1 end
                if deal_val > 0 then rows_count = rows_count + 1 end
                if expenses_val > 0 then rows_count = rows_count + 1 end
                if az_val > 0 then rows_count = rows_count + 1 end

                local card_height = 5 + (rows_count * 20) + 0

                imgui.BeginChild("##finance_card", imgui.ImVec2(0, card_height), true)
                    local function drawStatRow(icon_name, label, value, val_color)
                        imgui.TextColored(imgui.ImVec4(0.88, 0.89, 0.92, 1.0), getIcon(icon_name, "") .. u8(label))
                        imgui.SameLine(250)
                        imgui.TextColored(val_color or imgui.ImVec4(1,1,1,1), value)
                    end

                    drawStatRow("DOLLAR_SIGN", "Зарплата (общая):", "$" .. formatNumber(wage_val), imgui.ImVec4(0.25, 0.85, 0.48, 1.00))
                    drawStatRow("CREDIT_CARD", "Прирост по депозиту:", "$" .. formatNumber(dep_val), imgui.ImVec4(0.25, 0.85, 0.48, 1.00))
                    if biz_val > 0 then drawStatRow("BRIEFCASE", "Прибыль с бизнеса:", "$" .. formatNumber(biz_val), imgui.ImVec4(0.25, 0.85, 0.48, 1.00)) end
                    if btc_val > 0 then drawStatRow("COINS", "Продажа BTC:", "$" .. formatNumber(btc_val), imgui.ImVec4(0.25, 0.85, 0.48, 1.00)) end
                    if trade_val > 0 then drawStatRow("CART_SHOPPING", "Продажа товаров:", "$" .. formatNumber(trade_val), imgui.ImVec4(0.25, 0.85, 0.48, 1.00)) end
                    if deal_val > 0 then drawStatRow("HANDSHAKE", "Доход от трейда:", "$" .. formatNumber(deal_val), imgui.ImVec4(0.25, 0.85, 0.48, 1.00)) end

                    if expenses_val > 0 then 
                        drawStatRow("TRASH", "Траты за сегодня:", "-$" .. formatNumber(expenses_val), imgui.ImVec4(0.95, 0.26, 0.26, 1.00)) 
                    end
                    
                    imgui.Separator()
                    
                    local net_color = net_total >= 0 and imgui.ImVec4(0.98, 0.78, 0.20, 1.00) or imgui.ImVec4(0.95, 0.26, 0.26, 1.00)
                    local net_prefix = net_total >= 0 and "$" or "-$"
                    drawStatRow("MONEY_BILL_WAVE", "Итого чистый баланс:", net_prefix .. formatNumber(math.abs(net_total)), net_color)
                    
                    if az_val > 0 then drawStatRow("COINS", "Заработано AZ-Coins:", formatNumber(az_val) .. " AZ", imgui.ImVec4(0.98, 0.78, 0.20, 1.00)) end
                imgui.EndChild()

                imgui.Separator()
            
                local target_icon = (font_loaded and fa_ok and fa and fa.BULLSEYE) and fa.BULLSEYE or "?"
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0, 0, 0, 0))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1, 1, 1, 0.08))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(1, 1, 1, 0.15))
                local active_icon_col = session_stats.goal_enabled and imgui.ImVec4(0.95, 0.76, 0.18, 1.00) or imgui.ImVec4(0.50, 0.55, 0.63, 1.00)
                imgui.PushStyleColor(imgui.Col.Text, active_icon_col)
                if imgui.Button(target_icon .. "##toggle_goal_collapse", imgui.ImVec2(24, 24)) then
                    session_stats.goal_enabled = not session_stats.goal_enabled
                    save_stats_to_file()
                end
                imgui.PopStyleColor(4)
                if imgui.IsItemHovered() then
                    imgui.BeginTooltip()
                    imgui.Text(u8(session_stats.goal_enabled and "Свернуть трекер цели" or "Развернуть трекер цели"))
                    imgui.EndTooltip()
                end
                imgui.SameLine()
                
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8("Трекер финансовой цели:"))

                if session_stats.goal_enabled then
                    imgui.SameLine(sizeX - 265)

                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.95, 0.26, 0.26, 0.25))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.95, 0.35, 0.35, 0.50))
                    if imgui.Button(getIcon("GEAR", "?") .. "##goal_settings_btn", imgui.ImVec2(32, 24)) then
                        ffi.copy(goal_edit_amount, tostring(session_stats.goal_amount))
                        goal_edit_type[0] = session_stats.goal_type
                        goal_edit_scope[0] = session_stats.goal_scope
                        goal_edit_start_zero[0] = session_stats.goal_start_from_zero
                        show_goal_settings[0] = true
                    end
                    imgui.PopStyleColor(2)

                    imgui.BeginChild("##goal_tracker_card", imgui.ImVec2(0, 60), true)
                        local target = tonumber(session_stats.goal_amount) or 1
                        local cur = 0
                        local sym = "$"
                        if session_stats.goal_type == 1 then
                            if session_stats.goal_scope == 1 then
                                local base = getTotalIncomeOverall()
                                if session_stats.goal_start_from_zero then
                                    base = base - (session_stats.goal_start_money or 0)
                                end
                                cur = math.max(0, base) + (session_stats.manually_added_money or 0)
                            else
                                local total_earned_today_local = (session_stats.wages_accumulated or 0) + (session_stats.dep_growth or 0) + (session_stats.biz_income or 0) + (session_stats.btc_income or 0) + (session_stats.trade_income or 0) + (session_stats.deal_income or 0)
                                local net_total_local = total_earned_today_local - math.abs(tonumber(session_stats.expenses_accumulated) or 0)
                                cur = net_total_local + (session_stats.manually_added_money or 0)
                            end
                            sym = "$"
                        else
                            if session_stats.goal_scope == 1 then
                                local base = getTotalAZOverall()
                                if session_stats.goal_start_from_zero then
                                    base = base - (session_stats.goal_start_az or 0)
                                end
                                cur = math.max(0, base) + (session_stats.manually_added_az or 0)
                            else
                                cur = (session_stats.az_accumulated or 0) + (session_stats.manually_added_az or 0)
                            end
                            sym = "AZ"
                        end
                        
                        local progress = math.min(1.0, math.max(0.0, cur / target))
                        local remaining = math.max(0, target - cur)
                        
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.25))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.80, 0.44, 0.45))
                        if imgui.Button("+##add_funds_button", imgui.ImVec2(25, 20)) then
                            show_add_funds_modal[0] = true
                        end
                        if imgui.IsItemHovered() then
                            imgui.BeginTooltip()
                            imgui.Text(u8("Прибавить ранее заработанные средства"))
                            imgui.EndTooltip()
                        end
                        imgui.PopStyleColor(2)
                        imgui.SameLine()

                        imgui.ProgressBar(progress, imgui.ImVec2(-1, 20), string.format("%.1f%%", progress * 100))
                        
                        imgui.Text(u8("Осталось: ") .. formatNumber(remaining) .. " " .. sym)
                        
                        local week_stats = getWeekStatistics()
                        local avg_daily_income = get_average_daily_value('income')
                        local avg_daily_az = get_average_daily_value('az_accumulated')
                    
                        if remaining > 0 then
                            local days_needed = 0
                            local current_avg_value = (session_stats.goal_type == 1) and avg_daily_income or avg_daily_az

                            if current_avg_value > 0 then
                                days_needed = math.ceil(remaining / current_avg_value)
                                imgui.SameLine()
                                imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), u8(string.format(" (~ %d дн.)", days_needed)))
                                if imgui.IsItemHovered() then
                                    imgui.BeginTooltip()
                                    imgui.Text(u8("Примерно дней до цели при среднем доходе за день: "))
                                    imgui.Text(u8(formatNumber(current_avg_value) .. " " .. sym))
                                    imgui.EndTooltip()
                                end
                            else
                                imgui.SameLine()
                                imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), u8(" (Нет данных для прогноза) "))
                            end
                        end
                    imgui.EndChild()

                    imgui.Separator()
                else
                    imgui.Dummy(imgui.ImVec2(0, 2))
                end

                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.50, 0.80, 0.25))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.50, 0.80, 0.45))

                if imgui.Button(getIcon("CHART_COLUMN", "") .. u8("Посмотреть график доходов"), imgui.ImVec2(-1, 26)) then
                    show_chart_window[0] = true
                end
                imgui.PopStyleColor(2)

                imgui.Dummy(imgui.ImVec2(0, 2))

                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.25))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.80, 0.44, 0.45))
                if imgui.Button(getIcon("PAPER_PLANE", "") .. u8("Тест: Отправить отчёт за сегодня"), imgui.ImVec2(-1, 26)) then
                    sendTelegramMessage(get_session_report_text(session_stats.last_active_date))
                    show_arz_notify('success', 'Отчёт', 'Ежедневный отчёт отправлен в Telegram!', 3000)
                end
                imgui.PopStyleColor(2)

                imgui.Dummy(imgui.ImVec2(0, 2))

                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.95, 0.26, 0.26, 0.15))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.95, 0.26, 0.26, 0.3))
                if imgui.Button(getIcon("TRASH", "") .. u8("Сбросить статистику текущего дня"), imgui.ImVec2(-1, 26)) then
                    session_stats.last_active_date = os.date("%d.%m.%Y")
                    session_stats.quests_completed = 0
                    session_stats.wages_accumulated = 0
                    session_stats.dep_growth = 0
                    session_stats.biz_income = 0
                    session_stats.btc_income = 0
                    session_stats.az_accumulated = 0
                    session_stats.time_in_game = 0
                    session_stats.trade_income = 0
                    session_stats.deal_income = 0
                    session_stats.expenses_accumulated = 0
                    session_stats.report_sent = false
                    save_stats_to_file()
                    show_arz_notify('info', 'Сброс', 'Статистика дня успешно обнулена.', 3000)
                end
                imgui.PopStyleColor(2)

            elseif currentTab[0] == 5 then
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("BAN", "") .. u8("Черный список предметов"))
                imgui.TextDisabled(u8("Предметы из этого списка НЕ будут отправляться в Telegram при получении."))
                imgui.Separator()
                imgui.Dummy(imgui.ImVec2(0, 5))

                imgui.TextDisabled(u8("Поиск по названию предмета или ID:"))
                imgui.SetNextItemWidth(-1)
                imgui.InputText("##item_search", ui.item_search_input, ffi.sizeof(ui.item_search_input))

                imgui.Dummy(imgui.ImVec2(0, 5))

                local ignored_count = 0
                for _ in pairs(session_stats.ignored_items or {}) do ignored_count = ignored_count + 1 end
                imgui.TextColored(imgui.ImVec4(0.60, 0.65, 0.73, 1.00), u8("Всего предметов в игноре: ") .. tostring(ignored_count))

                imgui.Dummy(imgui.ImVec2(0, 5))

                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.06, 0.08, 0.11, 1.00))
                imgui.BeginChild("##items_ignore_list", imgui.ImVec2(0, sizeY - 180), true)

                local raw_search = ffi.string(ui.item_search_input)
                local ok_dec, search_cp1251 = pcall(function() return u8:decode(raw_search) end)
                local search_query = (ok_dec and search_cp1251 or raw_search):lower()
                
                local all_items_to_display = {}
                for id_str, name_str in pairs(items_name or {}) do
                    local name_lower = name_str:lower()
                    local id_lower = id_str:lower()

                    if search_query == "" or name_lower:find(search_query, 1, true) or id_lower:find(search_query, 1, true) then
                        local is_ignored = session_stats.ignored_items[id_str] ~= nil
                        table.insert(all_items_to_display, {
                            id = id_str,
                            name = name_str,
                            is_ignored = is_ignored
                        })
                    end
                end

                table.sort(all_items_to_display, function(a, b)
                    if a.is_ignored ~= b.is_ignored then
                        return a.is_ignored
                    end
                    return a.name < b.name
                end)

                local rendered_count = 0
                for _, item in ipairs(all_items_to_display) do
                    rendered_count = rendered_count + 1
                    imgui.PushIDInt(tonumber(item.id) or rendered_count)

                    local text_color = item.is_ignored and imgui.ImVec4(0.95, 0.76, 0.18, 1.00) or imgui.ImVec4(0.88, 0.89, 0.92, 1.00)
                    imgui.TextColored(text_color, "[" .. item.id .. "] ")
                    imgui.SameLine()
                    imgui.TextColored(text_color, u8(item.name))

                    imgui.SameLine(330)

                    if item.is_ignored then
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.80, 0.20, 0.20, 0.6))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.90, 0.30, 0.30, 0.8))
                        if imgui.Button(u8("Удалить##btn"), imgui.ImVec2(110, 22)) then
                            session_stats.ignored_items[item.id] = nil
                            save_stats_to_file()
                        end
                        imgui.PopStyleColor(2)
                    else
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.6))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.85, 0.48, 0.8))
                        if imgui.Button(u8("Игнорировать##btn"), imgui.ImVec2(110, 22)) then
                            session_stats.ignored_items[item.id] = true
                            save_stats_to_file()
                        end
                        imgui.PopStyleColor(2)
                    end

                    imgui.PopID()
                end

                if rendered_count == 0 then
                    imgui.TextDisabled(u8("Список предметов пуст или ничего не найдено по запросу."))
                end 

                imgui.EndChild()
                imgui.PopStyleColor()
            elseif currentTab[0] == 6 then
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("CLOCK_ROTATE_LEFT", "") .. u8("История финансовых операций"))
                imgui.TextDisabled(u8("Подробный лог всех доходов и расходов по дням."))
                imgui.Separator()
                imgui.Dummy(imgui.ImVec2(0, 3))

                -- Переменные фильтра истории
                if history_date_filter == nil then history_date_filter = 0 end -- 0: За все время, 1: Сегодня, 2: Конкретная дата

                -- КНОПКИ ВЫБОРА ФИЛЬТРА ДАТЫ
                local function drawHistFilterBtn(label, mode_id, w)
                    local is_active = (history_date_filter == mode_id)
                    if is_active then
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.60))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.80, 0.44, 0.80))
                    else
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.20, 0.26, 0.80))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.26, 0.33, 1.00))
                    end
                    if imgui.Button(u8(label), imgui.ImVec2(w or 110, 26)) then
                        history_date_filter = mode_id
                    end
                    imgui.PopStyleColor(2)
                end

                drawHistFilterBtn("За всё время", 0, 130)
                imgui.SameLine()
                drawHistFilterBtn("Сегодня", 1, 100)

                imgui.SameLine(sizeX - 320)
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.95, 0.26, 0.26, 0.20))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.95, 0.26, 0.26, 0.40))
                if imgui.Button(getIcon("TRASH", "") .. u8("Очистить историю"), imgui.ImVec2(100, 26)) then
                    session_stats.tx_history = {}
                    save_stats_to_file()
                    show_arz_notify('info', 'TM', 'История операций очищена.', 3000)
                end
                imgui.PopStyleColor(2)

                imgui.Dummy(imgui.ImVec2(0, 4))

                -- СПИСОК ОПЕРАЦИЙ С РАЗДЕЛИТЕЛЯМИ ПО ДНЯМ
                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.06, 0.08, 0.11, 1.00))
                imgui.BeginChild("##history_scroll_list", imgui.ImVec2(0, sizeY - 125), true)

                local today_str = os.date("%d.%m.%Y")
                local tx_list = session_stats.tx_history or {}
                local filtered_tx = {}

                for _, item in ipairs(tx_list) do
                    if history_date_filter == 0 or (history_date_filter == 1 and item.date == today_str) then
                        table.insert(filtered_tx, item)
                    end
                end

                if #filtered_tx == 0 then
                    imgui.Dummy(imgui.ImVec2(0, 20))
                    imgui.TextDisabled(u8("  История операций пуста за выбранный период."))
                else
                    local last_rendered_date = ""

                    for idx, item in ipairs(filtered_tx) do
                        -- РАЗДЕЛИТЕЛЬ ДНЕЙ С ЛИНИЕЙ И ДАТОЙ
                        if item.date ~= last_rendered_date then
                            last_rendered_date = item.date
                            imgui.Dummy(imgui.ImVec2(0, 6))
                            
                            local date_label = (item.date == today_str) and ("Сегодня (" .. item.date .. ")") or item.date
                            imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("CALENDAR_DAYS", "") .. u8("— " .. date_label .. " —"))
                            imgui.Separator()
                            imgui.Dummy(imgui.ImVec2(0, 2))
                        end

                        -- СТРОКА ОПЕРАЦИИ
                        imgui.PushIDInt(idx)

                        -- Время
                        imgui.TextColored(imgui.ImVec4(0.50, 0.55, 0.63, 1.00), item.time or "00:00")
                        imgui.SameLine(70)

                        -- Описание события
                        imgui.TextColored(imgui.ImVec4(0.88, 0.89, 0.92, 1.00), u8(item.desc or "Операция"))

                        -- Категория (серый тег)
                        imgui.SameLine(280)
                        imgui.TextColored(imgui.ImVec4(0.40, 0.45, 0.55, 1.00), u8("[" .. (item.category or "Финансы") .. "]"))

                        -- Сумма (зеленая при доходе, красная при трате)
                        imgui.SameLine(sizeX - 350)
                        local amount_color = item.is_expense and imgui.ImVec4(0.95, 0.26, 0.26, 1.00) or imgui.ImVec4(0.18, 0.80, 0.44, 1.00)
                        imgui.TextColored(amount_color, u8(item.amount_text or "$0"))

                        imgui.PopID()
                    end
                end

                imgui.EndChild()
                imgui.PopStyleColor()
            end
            imgui.EndChild()

        imgui.End()
    end

    if show_goal_settings[0] then
        local gW, gH = 390, 320
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(gW, gH), imgui.Cond.Always)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.09, 0.11, 0.15, 0.98))

        if imgui.Begin("##GoalSettingsModal", show_goal_settings, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse) then
            if imgui.IsWindowHovered(1) and imgui.IsMouseDragging(0) and not imgui.IsAnyItemActive() then
                local delta = imgui.GetIO().MouseDelta
                local pos = imgui.GetWindowPos()
                imgui.SetWindowPos(imgui.ImVec2(pos.x + delta.x, pos.y + delta.y))
            end

            imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("GEAR", "?") .. u8("Настройка финансовой цели"))
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))

            imgui.TextDisabled(u8("Целевая сумма:"))
            imgui.SetNextItemWidth(-1)
            imgui.InputText("##goal_edit_input", goal_edit_amount, ffi.sizeof(goal_edit_amount), imgui.InputTextFlags.CharsDecimal)

            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.TextDisabled(u8("Тип валюты:"))
            
            local function drawChoiceButton(label, icon_name, is_selected, width)
                if is_selected then
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.4))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.80, 0.44, 0.6))
                    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.18, 0.80, 0.44, 0.8))
                else
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.20, 0.26, 0.6))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.26, 0.33, 0.8))
                    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.14, 0.15, 0.20, 1.0))
                end
                local res_btn = imgui.Button(getIcon(icon_name, "") .. u8(label), imgui.ImVec2(width, 26))
                imgui.PopStyleColor(3)
                return res_btn
            end

            if drawChoiceButton("Вирты ($)", "DOLLAR_SIGN", goal_edit_type[0] == 1, 180) then
                goal_edit_type[0] = 1
            end
            imgui.SameLine()
            if drawChoiceButton("AZ-Coins", "COINS", goal_edit_type[0] == 2, 180) then
                goal_edit_type[0] = 2
            end

            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.TextDisabled(u8("Период подсчёта:"))
            
            if drawChoiceButton("За день", "CLOCK", goal_edit_scope[0] == 2, 180) then
                goal_edit_scope[0] = 2
            end
            imgui.SameLine()
            if drawChoiceButton("Всего (Накопительно)", "CALENDAR_DAYS", goal_edit_scope[0] == 1, 180) then
                goal_edit_scope[0] = 1
                show_projection_pinned[0] = true
            end

            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.Checkbox(u8("Начать отсчёт с 0$ (только новые доходы)"), goal_edit_start_zero)

            imgui.Dummy(imgui.ImVec2(0, 8))
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))

            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.35))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.80, 0.44, 0.55))
            if imgui.Button(u8("Принять и сохранить"), imgui.ImVec2(-1, 30)) then
                local parsed = parse_numeric_value(ffi.string(goal_edit_amount))
                if parsed > 0 then
                    session_stats.goal_amount = parsed
                    session_stats.goal_type = goal_edit_type[0]
                    session_stats.goal_scope = goal_edit_scope[0]
                    session_stats.goal_start_from_zero = goal_edit_start_zero[0]
                    
                    if goal_edit_start_zero[0] then
                        session_stats.goal_start_money = getTotalIncomeOverall()
                        session_stats.goal_start_az = getTotalAZOverall()
                    else
                        session_stats.goal_start_money = 0
                        session_stats.goal_start_az = 0
                    end

                    session_stats.goal_notified = false
                    session_stats.goal_configured = true
                    save_stats_to_file()
                    show_goal_settings[0] = false
                    show_arz_notify('success', 'Цель', 'Финансовая цель успешно сохранена!', 3000)
                else
                    show_arz_notify('error', 'Ошибка', 'Введите корректную сумму!', 3000)
                end
            end
            imgui.PopStyleColor(2)

            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.20, 0.26, 0.8))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.26, 0.33, 1.0))
            if imgui.Button(u8("Отмена"), imgui.ImVec2(-1, 26)) then
                show_goal_settings[0] = false
            end
            imgui.PopStyleColor(2)

            imgui.End()
        end
        imgui.PopStyleColor()
    end

    if show_add_funds_modal[0] then
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.Appearing, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(340, 200), imgui.Cond.Always)
        imgui.Begin(u8("Прибавить средства"), show_add_funds_modal, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar)
            if imgui.IsWindowHovered(1) and imgui.IsMouseDragging(0) and not imgui.IsAnyItemActive() then
                local delta = imgui.GetIO().MouseDelta
                local pos = imgui.GetWindowPos()
                imgui.SetWindowPos(imgui.ImVec2(pos.x + delta.x, pos.y + delta.y))
            end

            local t_name = (session_stats.goal_type == 1) and "Вирты ($)" or "AZ-Coins"
            imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("PLUS", "+") .. u8(" Добавить капитал (" .. t_name .. ")"))
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.TextDisabled(u8("Введите сумму для прогресса цели:"))
            imgui.SetNextItemWidth(-1)
            imgui.InputText("##addinput", add_funds_input, 64, imgui.InputTextFlags.CharsDecimal)
            
            imgui.Dummy(imgui.ImVec2(0, 10))
            
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.6))
            if imgui.Button(u8("Добавить"), imgui.ImVec2(-1, 26)) then
                local val = parse_numeric_value(ffi.string(add_funds_input))
                if val > 0 then
                    if session_stats.goal_type == 1 then 
                        session_stats.manually_added_money = session_stats.manually_added_money + val
                    else 
                        session_stats.manually_added_az = session_stats.manually_added_az + val 
                    end
                    save_stats_to_file()
                    show_add_funds_modal[0] = false
                end
            end
            imgui.PopStyleColor()

            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.70, 0.20, 0.20, 0.6))
            if imgui.Button(u8("Отнять"), imgui.ImVec2(-1, 26)) then
                local val = parse_numeric_value(ffi.string(add_funds_input))
                if val > 0 then
                    if session_stats.goal_type == 1 then 
                        session_stats.manually_added_money = math.max(0, session_stats.manually_added_money - val)
                    else 
                        session_stats.manually_added_az = math.max(0, session_stats.manually_added_az - val) 
                    end
                    save_stats_to_file()
                    show_add_funds_modal[0] = false
                end
            end
            imgui.PopStyleColor()

            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.20, 0.26, 0.8))
            if imgui.Button(u8("Отмена"), imgui.ImVec2(-1, 24)) then 
                show_add_funds_modal[0] = false 
            end
            imgui.PopStyleColor()
        imgui.End()
    end

    if show_chart_window[0] then
        local cWinW, cWinH = 650, 410

        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(cWinW, cWinH), imgui.Cond.Always)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.09, 0.11, 0.15, 0.98))

        if imgui.Begin("##IncomeChartWindow", show_chart_window, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse) then
            if imgui.IsWindowHovered(1) and imgui.IsMouseDragging(0) and not imgui.IsAnyItemActive() then
                local delta = imgui.GetIO().MouseDelta
                local pos = imgui.GetWindowPos()
                imgui.SetWindowPos(imgui.ImVec2(pos.x + delta.x, pos.y + delta.y))
            end

            imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("CHART_COLUMN", "") .. u8("График доходов и расходов"))
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 3))

                            imgui.BeginChild("##chart_sidebar", imgui.ImVec2(145, cWinH - 80), true)
                    imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("SLIDERS", "") .. u8("Вид:"))
                    imgui.Dummy(imgui.ImVec2(0, 2))

                    local function drawModeBtn(mode_id, icon_name, tooltip_str, width)
                        local is_sel = (chart_view_mode[0] == mode_id)
                        if is_sel then
                            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.60))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.80, 0.44, 0.80))
                        else
                            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.20, 0.26, 0.80))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.26, 0.33, 1.00))
                        end
                        if imgui.Button(getIcon(icon_name, "") .. "##mode_" .. mode_id, imgui.ImVec2(width or 62, 28)) then
                            chart_view_mode[0] = mode_id
                        end
                        if imgui.IsItemHovered() then
                            imgui.BeginTooltip()
                            imgui.Text(u8(tooltip_str))
                            imgui.EndTooltip()
                        end
                        imgui.PopStyleColor(2)
                    end

                    drawModeBtn(0, "CHART_COLUMN", "Столбцовый графцик")
                    imgui.SameLine()
                    drawModeBtn(1, "CHART_LINE", "Линейный графцик (Доход / Траты)")

                    imgui.Dummy(imgui.ImVec2(0, 2))
                    drawModeBtn(2, "CHART_AREA", "Общий линейный график", 127) -- Новая третья ячейка
                    
                    imgui.Dummy(imgui.ImVec2(0, 6))
                    imgui.Separator()
                    imgui.Dummy(imgui.ImVec2(0, 6))


                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("CALENDAR_DAYS", "") .. u8("Период:"))
                imgui.Dummy(imgui.ImVec2(0, 2))

                local function drawSidebarPeriodBtn(label, periodVal)
                    local isActive = (chart_days_period[0] == periodVal)
                    if isActive then
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.60))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.80, 0.44, 0.80))
                    else
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.20, 0.26, 0.80))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.26, 0.33, 1.00))
                    end
                    if imgui.Button(label, imgui.ImVec2(127, 26)) then
                        chart_days_period[0] = periodVal
                        if periodVal == 0 then
                            show_projection_pinned[0] = true
                        end
                    end
                    imgui.PopStyleColor(2)
                end

                drawSidebarPeriodBtn(u8("7 дней"), 7)
                imgui.Dummy(imgui.ImVec2(0, 2))
                drawSidebarPeriodBtn(u8("14 дней"), 14)
                imgui.Dummy(imgui.ImVec2(0, 2))
                drawSidebarPeriodBtn(u8("30 дней"), 30)
                imgui.Dummy(imgui.ImVec2(0, 2))
                drawSidebarPeriodBtn(u8("За всё время"), 0)

            imgui.EndChild()

            imgui.SameLine()







   

            imgui.BeginChild("##chart_plot_area", imgui.ImVec2(cWinW - 170, cWinH - 80), true)
                local period = chart_days_period[0]
                local today_str = session_stats.last_active_date ~= "" and session_stats.last_active_date or os.date("%d.%m.%Y")
                local cat_mode = chart_category_mode[0] -- 0: Общее, 1: Майнинг, 2: Торговля, 3: Бизнес

                if cat_mode == 2 or cat_mode == 3 then
                    -- === В РАЗРАБОТКЕ ===
                    local dev_title = (cat_mode == 2) and "ТОРГОВЛЯ" or "БИЗНЕС"
                    imgui.SetCursorPosY(100)
                    local text_w = imgui.CalcTextSize(u8(dev_title .. " — В РАЗРАБОТКЕ")).x
                    imgui.SetCursorPosX((cWinW - 170 - text_w) / 2)
                    imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("GEAR", "") .. u8(dev_title .. " — В РАЗРАБОТКЕ"))
                    
                    imgui.Dummy(imgui.ImVec2(0, 5))
                    local sub_w = imgui.CalcTextSize(u8("Этот раздел находится в процессе написания.")).x
                    imgui.SetCursorPosX((cWinW - 170 - sub_w) / 2)
                    imgui.TextDisabled(u8("Этот раздел находится в процессе написания."))
                else
                    -- === РАСЧЕТ ДАННЫХ ДЛЯ ГРАФИКА ===
                    local chart_data = {}
                    local max_value = 1
                    local total_income_period = 0
                    local total_expenses_period = 0

                    local today_gross = 0
                    local today_expenses = 0

                    if cat_mode == 1 then
                        today_gross = session_stats.btc_income or 0
                        today_expenses = session_stats.mining_expenses or 0
                    else
                        today_gross = (session_stats.wages_accumulated or 0) + 
                                      (session_stats.dep_growth or 0) + 
                                      (session_stats.biz_income or 0) + 
                                      (session_stats.btc_income or 0) + 
                                      (session_stats.trade_income or 0) +
                                      (session_stats.deal_income or 0)
                        today_expenses = math.abs(tonumber(session_stats.expenses_accumulated) or 0)
                    end

                    -- Формирование точек
                    if period == 0 then
                        local all_dates = {}
                        local date_exists = {}

                        for date_str, _ in pairs(session_stats.daily_history or {}) do
                            if not date_exists[date_str] then
                                date_exists[date_str] = true
                                table.insert(all_dates, date_str)
                            end
                        end
                        if not date_exists[today_str] then table.insert(all_dates, today_str) end
                        table.sort(all_dates, function(a, b) return getDateNumber(a) < getDateNumber(b) end)

                        for _, date_str in ipairs(all_dates) do
                            local inc, exp = 0, 0
                            if date_str == today_str then
                                inc, exp = today_gross, today_expenses
                            else
                                local day_data = session_stats.daily_history and session_stats.daily_history[date_str]
                                if day_data then
                                    if cat_mode == 1 then
                                        inc = tonumber(day_data.bitcoin or day_data.btc_income) or 0
                                        exp = tonumber(day_data.mining_expenses) or 0
                                    else
                                        exp = math.abs(tonumber(day_data.expenses) or 0)
                                        inc = (tonumber(day_data.income) or 0) + exp
                                    end
                                end
                            end

                            total_income_period = total_income_period + inc
                            total_expenses_period = total_expenses_period + exp
                            if inc > max_value then max_value = inc end
                            if exp > max_value then max_value = exp end

                            table.insert(chart_data, { date = date_str, short = date_str:sub(1, 5), income = inc, expenses = exp })
                        end
                    else
                        for i = period - 1, 0, -1 do
                            local ts = os.time() - (i * 86400)
                            local date_str = os.date("%d.%m.%Y", ts)
                            local short_str = os.date("%d.%m", ts)
                            local inc, exp = 0, 0

                            if date_str == today_str then
                                inc, exp = today_gross, today_expenses
                            elseif session_stats.daily_history and session_stats.daily_history[date_str] then
                                local day_data = session_stats.daily_history[date_str]
                                if cat_mode == 1 then
                                    inc = tonumber(day_data.bitcoin or day_data.btc_income) or 0
                                    exp = tonumber(day_data.mining_expenses) or 0
                                else
                                    exp = math.abs(tonumber(day_data.expenses) or 0)
                                    inc = (tonumber(day_data.income) or 0) + exp
                                end
                            end

                            total_income_period = total_income_period + inc
                            total_expenses_period = total_expenses_period + exp
                            if inc > max_value then max_value = inc end
                            if exp > max_value then max_value = exp end

                            table.insert(chart_data, { date = date_str, short = short_str, income = inc, expenses = exp })
                        end
                    end

                    -- === ОТРИСОВКА СЕТКИ И ОСЕЙ (Скрины 2, 3, 4) ===
                    local draw_list = imgui.GetWindowDrawList()
                    local canvas_pos = imgui.GetCursorScreenPos()
                    local canvas_w, canvas_h = cWinW - 190, 130

                    draw_list:AddRectFilled(canvas_pos, imgui.ImVec2(canvas_pos.x + canvas_w, canvas_pos.y + canvas_h), imgui.GetColorU32Vec4(imgui.ImVec4(0.06, 0.08, 0.11, 1.00)), 6.0)
                    draw_list:AddRect(canvas_pos, imgui.ImVec2(canvas_pos.x + canvas_w, canvas_pos.y + canvas_h), imgui.GetColorU32Vec4(imgui.ImVec4(0.18, 0.22, 0.30, 1.00)), 6.0)

                    local margin_left = 65
                    local margin_bottom = 20
                    local plot_w = canvas_w - margin_left - 10
                    local plot_h = canvas_h - margin_bottom - 15

                    -- Шкала по оси Y ($)
                    for g = 0, 4 do
                        local y = canvas_pos.y + 8 + (plot_h * (g / 4))
                        draw_list:AddLine(imgui.ImVec2(canvas_pos.x + margin_left, y), imgui.ImVec2(canvas_pos.x + canvas_w - 10, y), imgui.GetColorU32Vec4(imgui.ImVec4(0.15, 0.18, 0.25, 0.60)))
                        local grid_val = max_value * (1 - (g / 4))
                        draw_list:AddText(imgui.ImVec2(canvas_pos.x + 4, y - 6), imgui.GetColorU32Vec4(imgui.ImVec4(0.50, 0.55, 0.63, 1.00)), u8("$" .. formatNumber(grid_val)))
                    end

                    local num_points = math.max(1, #chart_data)
                    local bar_gap = plot_w / num_points
                    local mouse_pos = imgui.GetMousePos()
                    local y1_base = canvas_pos.y + 8 + plot_h

                    -- === РЕНДЕР 3-Х ВИДОВ ГРАФИКА ===

                    -- 1. СТОЛБЦЫ (СКРИНШОТ №2)
                    if chart_view_mode[0] == 0 then
                        local bar_w = math.max(bar_gap * 0.55, 4)
                        for idx, item in ipairs(chart_data) do
                            local x_center = canvas_pos.x + margin_left + ((idx - 0.5) * bar_gap)
                            local x0 = x_center - (bar_w / 2)
                            local x1 = x_center + (bar_w / 2)

                            local income_ratio = math.min(1.0, math.max(0.0, item.income / max_value))
                            local income_bar_h = math.max(plot_h * income_ratio, item.income > 0 and 3 or 0)
                            local income_y0 = y1_base - income_bar_h

                            local is_hovered = (mouse_pos.x >= x0 and mouse_pos.x <= x1 and mouse_pos.y >= (canvas_pos.y + 8) and mouse_pos.y <= y1_base)
                            local income_bar_col = is_hovered and imgui.GetColorU32Vec4(imgui.ImVec4(0.98, 0.78, 0.20, 1.00)) or imgui.GetColorU32Vec4(imgui.ImVec4(0.18, 0.80, 0.44, 0.85))
                            if item.income == 0 then income_bar_col = imgui.GetColorU32Vec4(imgui.ImVec4(0.25, 0.28, 0.35, 0.40)) end

                            if income_bar_h > 0 then
                                draw_list:AddRectFilled(imgui.ImVec2(x0, income_y0), imgui.ImVec2(x1, y1_base), income_bar_col, 3.0, 1 + 2)
                            end

                            local expenses_ratio = math.min(1.0, math.max(0.0, item.expenses / max_value))
                            local expenses_bar_h = math.max(plot_h * expenses_ratio, item.expenses > 0 and 3 or 0)
                            local expenses_y0 = y1_base - expenses_bar_h
                            local expenses_bar_col = imgui.GetColorU32Vec4(imgui.ImVec4(0.95, 0.26, 0.26, 0.65))

                            if expenses_bar_h > 0 then
                                draw_list:AddRectFilled(imgui.ImVec2(x0, expenses_y0), imgui.ImVec2(x1, y1_base), expenses_bar_col, 3.0, 1 + 2)
                            end

                            draw_list:AddText(imgui.ImVec2(x_center - 10, y1_base + 3), imgui.GetColorU32Vec4(imgui.ImVec4(0.60, 0.65, 0.73, 1.00)), item.short)

                            if is_hovered then
                                imgui.BeginTooltip()
                                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8("Дата: " .. item.date))
                                imgui.TextColored(imgui.ImVec4(0.25, 0.85, 0.48, 1.00), u8(cat_mode == 1 and "Продажа BTC: $" or "Доход: $") .. formatNumber(item.income))
                                imgui.TextColored(imgui.ImVec4(0.95, 0.26, 0.26, 1.00), u8(cat_mode == 1 and "Траты майнинга: $" or "Траты: $") .. formatNumber(item.expenses))
                                imgui.EndTooltip()
                            end
                        end

                    -- 2. ДВЕ ЛИНИИ: ДОХОД И ТРАТЫ (СКРИНШОТ №3)
                    elseif chart_view_mode[0] == 1 then
                        local inc_points = {}
                        local exp_points = {}
                        for idx, item in ipairs(chart_data) do
                            local x = canvas_pos.x + margin_left + ((idx - 0.5) * bar_gap)
                            local inc_ratio = math.min(1.0, math.max(0.0, item.income / max_value))
                            local exp_ratio = math.min(1.0, math.max(0.0, item.expenses / max_value))
                            table.insert(inc_points, imgui.ImVec2(x, y1_base - (plot_h * inc_ratio)))
                            table.insert(exp_points, imgui.ImVec2(x, y1_base - (plot_h * exp_ratio)))
                        end

                        local col_inc_line = imgui.GetColorU32Vec4(imgui.ImVec4(0.18, 0.80, 0.44, 1.00))
                        local col_exp_line = imgui.GetColorU32Vec4(imgui.ImVec4(0.95, 0.26, 0.26, 1.00))

                        for i = 1, #inc_points - 1 do
                            draw_list:AddLine(inc_points[i], inc_points[i+1], col_inc_line, 2.0)
                            draw_list:AddLine(exp_points[i], exp_points[i+1], col_exp_line, 2.0)
                        end

                        for idx, item in ipairs(chart_data) do
                            local pt_inc = inc_points[idx]
                            local pt_exp = exp_points[idx]
                            draw_list:AddCircleFilled(pt_inc, 3.5, col_inc_line)
                            draw_list:AddCircleFilled(pt_exp, 3.5, col_exp_line)

                            local x_min = pt_inc.x - (bar_gap / 2)
                            local x_max = pt_inc.x + (bar_gap / 2)
                            local is_hovered = (mouse_pos.x >= x_min and mouse_pos.x <= x_max and mouse_pos.y >= (canvas_pos.y + 8) and mouse_pos.y <= y1_base)

                            if is_hovered then
                                draw_list:AddLine(imgui.ImVec2(pt_inc.x, canvas_pos.y + 8), imgui.ImVec2(pt_inc.x, y1_base), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,0.25)), 1.0)
                                imgui.BeginTooltip()
                                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8("Дата: " .. item.date))
                                imgui.TextColored(imgui.ImVec4(0.25, 0.85, 0.48, 1.00), u8(cat_mode == 1 and "Продажа BTC: $" or "Доход: $") .. formatNumber(item.income))
                                imgui.TextColored(imgui.ImVec4(0.95, 0.26, 0.26, 1.00), u8(cat_mode == 1 and "Траты майнинга: $" or "Траты: $") .. formatNumber(item.expenses))
                                imgui.EndTooltip()
                            end

                            draw_list:AddText(imgui.ImVec2(pt_inc.x - 10, y1_base + 3), imgui.GetColorU32Vec4(imgui.ImVec4(0.60, 0.65, 0.73, 1.00)), item.short)
                        end

                    -- 3. ОБЩИЙ ЛИНЕЙНЫЙ ЖЕЛТЫЙ ГРАФИК (СКРИНШОТ №4)
                    elseif chart_view_mode[0] == 2 then
                        local net_points = {}
                        for idx, item in ipairs(chart_data) do
                            local x = canvas_pos.x + margin_left + ((idx - 0.5) * bar_gap)
                            local net_val = item.income - item.expenses
                            local net_ratio = math.min(1.0, math.max(0.0, net_val / max_value))
                            table.insert(net_points, imgui.ImVec2(x, y1_base - (plot_h * net_ratio)))
                        end

                        local col_yellow_line = imgui.GetColorU32Vec4(imgui.ImVec4(0.95, 0.76, 0.18, 1.00))

                        for i = 1, #net_points - 1 do
                            draw_list:AddLine(net_points[i], net_points[i+1], col_yellow_line, 2.5)
                        end

                        for idx, item in ipairs(chart_data) do
                            local pt = net_points[idx]
                            draw_list:AddCircleFilled(pt, 4.0, col_yellow_line)

                            local x_min = pt.x - (bar_gap / 2)
                            local x_max = pt.x + (bar_gap / 2)
                            local is_hovered = (mouse_pos.x >= x_min and mouse_pos.x <= x_max and mouse_pos.y >= (canvas_pos.y + 8) and mouse_pos.y <= y1_base)

                            if is_hovered then
                                draw_list:AddLine(imgui.ImVec2(pt.x, canvas_pos.y + 8), imgui.ImVec2(pt.x, y1_base), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,0.25)), 1.0)
                                imgui.BeginTooltip()
                                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8("Дата: " .. item.date))
                                local net = item.income - item.expenses
                                imgui.TextColored(net >= 0 and imgui.ImVec4(0.25, 0.85, 0.48, 1.00) or imgui.ImVec4(0.95, 0.26, 0.26, 1.00), u8("Чистый доход: $") .. formatNumber(net))
                                imgui.EndTooltip()
                            end

                            draw_list:AddText(imgui.ImVec2(pt.x - 10, y1_base + 3), imgui.GetColorU32Vec4(imgui.ImVec4(0.60, 0.65, 0.73, 1.00)), item.short)
                        end
                    end

                    imgui.Dummy(imgui.ImVec2(0, canvas_h + 2))

                    -- Текстовые данные под графиком
                    if cat_mode == 1 then
                        imgui.TextColored(imgui.ImVec4(0.18, 0.80, 0.44, 1.00), getIcon("COINS", "") .. u8("Продажа BTC (Майнинг): $") .. formatNumber(total_income_period))
                        imgui.TextColored(imgui.ImVec4(0.95, 0.26, 0.26, 1.00), getIcon("TRASH", "") .. u8("Траты (Свет + Охлаждайки): -$") .. formatNumber(total_expenses_period))
                    else
                        imgui.TextColored(imgui.ImVec4(0.18, 0.80, 0.44, 1.00), getIcon("MONEY_BILL_WAVE", "") .. u8("Доходы: $") .. formatNumber(total_income_period))
                        imgui.TextColored(imgui.ImVec4(0.95, 0.26, 0.26, 1.00), getIcon("TRASH", "") .. u8("Траты: -$") .. formatNumber(total_expenses_period))
                    end

                    imgui.Dummy(imgui.ImVec2(0, 1))
                    imgui.Separator()
                    imgui.Dummy(imgui.ImVec2(0, 1))

                    local net_result = total_income_period - total_expenses_period
                    local is_plus = (net_result >= 0)
                    local res_color = is_plus and imgui.ImVec4(0.18, 0.80, 0.44, 1.00) or imgui.ImVec4(0.95, 0.26, 0.26, 1.00)
                    
                    local status_text = is_plus and "В плюсе:" or "В минусе:"
                    if cat_mode == 1 then
                        status_text = is_plus and "Майнинг окупается (плюс):" or "Майнинг в минусе:"
                    end

                    imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8("Итог за выбранный период:"))
                    imgui.TextColored(res_color, u8(status_text))
                    imgui.TextColored(res_color, u8((is_plus and "+$" or "-$") .. formatNumber(math.abs(net_result))))
                end

                -- Кнопки категорий снизу
                imgui.SetCursorPosY(cWinH - 130)
                imgui.Separator()
                imgui.Dummy(imgui.ImVec2(0, 2))

                local function drawCategoryBtn(label, mode_id, btn_w)
                    local is_selected = (chart_category_mode[0] == mode_id)
                    if is_selected then
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.70))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.80, 0.44, 0.90))
                    else
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.20, 0.26, 0.80))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.26, 0.33, 1.00))
                    end
                    if imgui.Button(u8(label) .. "##cat_" .. mode_id, imgui.ImVec2(btn_w, 24)) then
                        chart_category_mode[0] = mode_id
                    end
                    imgui.PopStyleColor(2)
                end

                local cat_btn_w = 110
                drawCategoryBtn("Общее", 0, cat_btn_w)
                imgui.SameLine()
                drawCategoryBtn("Майнинг", 1, cat_btn_w)
                imgui.SameLine()
                drawCategoryBtn("Торговля", 2, cat_btn_w)
                imgui.SameLine()
                drawCategoryBtn("Бизнес", 3, cat_btn_w)

            imgui.EndChild()





            imgui.Dummy(imgui.ImVec2(0, 0))
            
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.20, 0.26, 0.80))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.26, 0.33, 1.00))
            if imgui.Button(u8("Закрыть график"), imgui.ImVec2(-1, 26)) then
                show_chart_window[0] = false
            end
            imgui.PopStyleColor(2)

            imgui.End()
        end
        imgui.PopStyleColor()
    end

    if show_emoji_selector_modal[0] then
        imgui.SetNextWindowPos(imgui.ImVec2(0, 0), imgui.Cond.Always)
        imgui.SetNextWindowSize(imgui.ImVec2(resX, resY), imgui.Cond.Always)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0.6))
        imgui.Begin("##ModalDimmer", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoCollapse)
        
        local cardW, cardH = 370, 440
        imgui.SetNextWindowPos(imgui.ImVec2((resX - cardW) / 2, (resY - cardH) / 2), imgui.Cond.Always)
        imgui.SetNextWindowSize(imgui.ImVec2(cardW, cardH), imgui.Cond.Always)
        
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.14, 0.17, 0.23, 1.00)) 
        imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 12.0)
        
        if imgui.Begin("##EmojiPickerDialog", show_emoji_selector_modal, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse) then
            imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8("Выберите смайлик для Telegram:"))
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            local columns = 4
            local button_w = 80
            local button_h = 32
            
            for i, emoji in ipairs(emojis_list) do
                local label = getEmojiRenderString(emoji.key)
                if imgui.Button(label .. "##select" .. i, imgui.ImVec2(button_w, button_h)) then
                    cfg.config[selected_emoji_setting] = emoji.key
                    saveConfig()
                    show_emoji_selector_modal[0] = false
                end
                if imgui.IsItemHovered() then
                    imgui.BeginTooltip()
                    imgui.Text(u8("Будет отправлен: " .. emoji.desc))
                    imgui.EndTooltip()
                end
                if i % columns ~= 0 and i < #emojis_list then
                    imgui.SameLine()
                end
            end
            
            imgui.Dummy(imgui.ImVec2(0, 15))
            
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.20, 0.26, 0.8))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.26, 0.33, 1.0))
            if imgui.Button(u8("Назад / Отмена"), imgui.ImVec2(-1, 35)) then
                show_emoji_selector_modal[0] = false
            end
            imgui.PopStyleColor(2)

            imgui.End()
        end
        imgui.PopStyleVar()
        imgui.PopStyleColor() 
        imgui.End()
        imgui.PopStyleColor() 
    end

        if show_update_popup[0] then
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(480, 380), imgui.Cond.Always) -- Увеличили высоту окна под 3 кнопки
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.09, 0.11, 0.15, 1.00))

        if imgui.Begin('##UpdatePopup', nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse) then
            local w_width = imgui.GetWindowWidth()
            imgui.SetCursorPosX(15) 
            imgui.SetCursorPosY(15)
            imgui.BeginGroup()

            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.14, 0.17, 0.23, 1.00))
            imgui.BeginChild("##header", imgui.ImVec2(w_width - 30, 40), true)
                local header_text = u8("Доступно обновление")
                imgui.SetCursorPosY(10)
                imgui.SetCursorPosX((w_width - 30 - imgui.CalcTextSize(header_text).x) / 2)
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), header_text)
            imgui.EndChild()
            imgui.PopStyleColor()

            imgui.Dummy(imgui.ImVec2(0, 10))
            local safe_remote_ver = tostring(remote_version_text or "0.0.0")
            
            imgui.SetCursorPosX((w_width - 30 - (imgui.CalcTextSize(u8("Текущая ") .. SCRIPT_VERSION).x + imgui.CalcTextSize(u8("Новая ") .. safe_remote_ver).x + 30)) / 2)
            imgui.TextColored(imgui.ImVec4(0.60, 0.65, 0.73, 1.00), u8("Текущая "))
            imgui.SameLine()
            imgui.Text(SCRIPT_VERSION)
            imgui.SameLine()
            if font_loaded and fa_ok and fa.ARROW_RIGHT then
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), fa.ARROW_RIGHT)
            else
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8(" --&gt; "))
            end
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(0.60, 0.65, 0.73, 1.00), u8("Новая "))
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(0.18, 0.80, 0.44, 1.00), safe_remote_ver)

            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8("• Что нового"))
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(0.50, 0.55, 0.63, 1.00), u8(" — список изменений"))
            imgui.Dummy(imgui.ImVec2(0, 4))

            imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.06, 0.08, 0.11, 1.00))
            imgui.BeginChild("##changelog", imgui.ImVec2(w_width - 30, 100), true)
                local safe_update_info = tostring(remote_update_info or "Нет информации")
                imgui.TextWrapped(u8(safe_update_info))
            imgui.EndChild()
            imgui.PopStyleColor()

            imgui.Dummy(imgui.ImVec2(0, 12))
            
            -- === КНОПКИ УПРАВЛЕНИЯ ОБНОВЛЕНИЕМ ===
            local full_btn_w = w_width - 30

            -- 1. Кнопка "Обновить сейчас" (Зеленая во всю ширину сверху)
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15, 0.45, 0.24, 1.00))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.55, 0.29, 1.00))
            if imgui.Button(u8("Обновить сейчас"), imgui.ImVec2(full_btn_w, 32)) then
                downloadAndInstallUpdate()
            end
            imgui.PopStyleColor(2)

            imgui.Dummy(imgui.ImVec2(0, 4))

            -- 2 нижние кнопки рядом ("Пропустить" и "Напомнить позже")
            local half_btn_w = (full_btn_w - 6) / 2

            -- Кнопка "Пропустить это обновление" (Красная / Серая)
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.18, 0.18, 0.80))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.65, 0.22, 0.22, 1.00))
            if imgui.Button(u8("Пропустить версию"), imgui.ImVec2(half_btn_w, 30)) then
                cfg.config.skipped_version = remote_version_text
                saveConfig()
                show_update_popup[0] = false
                show_arz_notify('info', 'Обновление', 'Вы пропустили это обновление.', 3000)
                if wasOpenedByCommand then
                    window[0] = true
                    wasOpenedByCommand = false
                end
            end
            imgui.PopStyleColor(2)

            imgui.SameLine()

            -- Кнопка "Напомнить позже"
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.20, 0.26, 1.00))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.26, 0.33, 1.00))
            if imgui.Button(u8("Напомнить позже"), imgui.ImVec2(half_btn_w, 30)) then
                show_update_popup[0] = false
                if wasOpenedByCommand then
                    window[0] = true
                    wasOpenedByCommand = false
                end
            end 
            imgui.PopStyleColor(2)

            imgui.EndGroup()
            imgui.End()
        end
        imgui.PopStyleColor()
    end
end)

local function processTradeMoneyChange(new_money)
    new_money = tonumber(new_money)
    if not new_money then return end

    if tm_last_money == nil then
        tm_last_money = new_money
        return
    end

    local difference = new_money - tm_last_money
    tm_last_money = new_money

    if not tm_trade_waiting_money then return end

    if os.clock() - tm_trade_waiting_time > 5.0 then
        tm_trade_waiting_money = false
        return
    end

    if difference >= 0 then return end

    local expense = math.abs(difference)
    if expense <= 0 then return end

    tm_trade_waiting_money = false

    if samp._tm_last_trade_expense == expense and samp._tm_last_trade_expense_time and (os.clock() - samp._tm_last_trade_expense_time < 3.0) then
        return
    end

    samp._tm_last_trade_expense = expense
    samp._tm_last_trade_expense_time = os.clock()

    session_stats.expenses_accumulated = (session_stats.expenses_accumulated or 0) + expense
    save_stats_to_file()

    sampAddChatMessage("{FF6347}[TM] Переданные деньги учтены как расход: -$" .. formatNumber(expense), -1)
end

function samp.onSetPlayerMoney(money)
    processTradeMoneyChange(money)
end

function samp.onShowDialog(dialogId, style, title, button1, button2, text)
    if not text then return end

    local cleanTitle = cleanColors(tostring(title or "")):upper()
    local cleanText = cleanColors(tostring(text or ""))

    if dialogId == 28149 or cleanTitle:find("РЕЗУЛЬТАТ СДЕЛКИ") or cleanText:find("РЕЗУЛЬТАТ СДЕЛКИ") or cleanText:find("Передано:") then
        tm_trade_waiting_money = true
        tm_trade_waiting_time = os.clock()

        local received_block = cleanText:match("Получено:%s*([^\r\n]+)")
        if received_block and not received_block:find("^%s*%-") then
            local inc_val = parse_numeric_value(received_block)
            if inc_val and inc_val > 0 then
                local now = os.clock()
                if samp._tm_last_deal_amount ~= inc_val or not samp._tm_last_deal_time or (now - samp._tm_last_deal_time >= 3.0) then
                    samp._tm_last_deal_amount = inc_val
                    samp._tm_last_deal_time = now

                    session_stats.deal_income = (session_stats.deal_income or 0) + inc_val
                    save_stats_to_file()
                    sampAddChatMessage("{00FF00}[TM] Доход от трейда добавлен в финансы: $" .. formatNumber(inc_val), -1)
                end
            end
        end
    end
end

local function processDealIncomeMessage(text)
    if not text then return end

    local clean = tostring(text):gsub("{%x%x%x%x%x%x}", "")

    local amount_text = clean:match("[Зз]а обмен вы получили%s*.-%s*([%d%.,%s]+)%s*,%s*комиссия")
                     or clean:match("[Зз]а обмен вы получили%s*.-%s*([%d%.,]+)")

    if not amount_text then return end

    local amount = parse_numeric_value(amount_text)
    if not amount or amount <= 0 then return end

    local now = os.clock()
    if samp._tm_last_deal_amount == amount and samp._tm_last_deal_time and (now - samp._tm_last_deal_time < 3.0) then
        return
    end

    samp._tm_last_deal_amount = amount
    samp._tm_last_deal_time = now

    session_stats.deal_income = (session_stats.deal_income or 0) + amount
    save_stats_to_file()

    sampAddChatMessage("{00FF00}[TM] Доход от трейда добавлен в финансы: $" .. formatNumber(amount), -1)
end

function samp.onServerMessage(color, text)
    if not text then return end

    local cleanText = text:gsub("{%x%x%x%x%x%x}", "")
	
	
	    -- === [МАЙНИНГ] ПЕРЕХВАТ ОПЛАТЫ ЭЛЕКТРОЭНЕРГИИ ===
    -- Пример: [Информация] Вы успешно пополнили счёт дома за электроэнергию на 28.640.
    -- === [МАЙНИНГ] ПЕРЕХВАТ ОПЛАТЫ ЭЛЕКТРОЭНЕРГИИ ===
    -- Пример 1: [Информация] Вы успешно пополнили счёт дома за электроэнергию на 28.640.
    -- Пример 2 (VC): [Информация] Вы успешно пополнили счёт дома за электроэнергию на ??57.280.
    -- === [МАЙНИНГ] ПЕРЕХВАТ ОПЛАТЫ ЭЛЕКТРОЭНЕРГИИ (БЕЗ УМНОЖЕНИЯ) ===
    -- Пример: [Информация] Вы успешно пополнили счёт дома за электроэнергию на $ 300.000.
    if cleanText:find("Вы успешно пополнили") and cleanText:find("электроэнергию") then
        local sum_str = cleanText:match("электроэнергию на%s*[^%d]*(%d[%d%.,]*)")
                     or cleanText:match("на%s*[^%d]*(%d[%d%.,]*)")
                     
        if sum_str then
            local val = parse_numeric_value(sum_str)
            if val > 0 then
                -- Записываем ровно ту сумму, которая в чате (без x136)
                session_stats.mining_electricity = (session_stats.mining_electricity or 0) + val
                session_stats.mining_expenses = (session_stats.mining_expenses or 0) + val
                session_stats.expenses_accumulated = (session_stats.expenses_accumulated or 0) + val
                
                -- Запись в Историю (вкладка 6)
                add_history_log("Майнинг", "Оплата электроэнергии дома", "-$" .. formatNumber(val), true)
                save_stats_to_file()
                
                sampAddChatMessage("{00FF00}[Script TM] Успешно учтена оплата электроэнергии: {FFFFFF}$" .. formatNumber(val), -1)
            end
        end
    end

    -- === [МАЙНИНГ] ПЕРЕХВАТ ПОКУПКИ ОХЛАЖДАЮЩЕЙ ЖИДКОСТИ (БЕЗ УМНОЖЕНИЯ) ===
    if cleanText:find("Вы успешно купили") and cleanText:find("Охлаждающая жидкость для видеокарты") then
        local qty_str = cleanText:match("%((%d+)%s*шт%.%)") or "1"
        local qty = tonumber(qty_str) or 1
        
        local price_str = cleanText:match("за%s*[^%d]*(%d[%d%.,]*)")
        if price_str then
            local total_price = parse_numeric_value(price_str)
            if total_price > 0 then
                -- Записываем ровно точное значение (без x136)
                session_stats.mining_coolants = (session_stats.mining_coolants or 0) + total_price
                session_stats.mining_expenses = (session_stats.mining_expenses or 0) + total_price
                session_stats.expenses_accumulated = (session_stats.expenses_accumulated or 0) + total_price
                
                -- Запись в Историю (вкладка 6)
                add_history_log("Майнинг", "Купил охлаждайку ("..qty.." шт.)", "-$" .. formatNumber(total_price), true)
                save_stats_to_file()
                
                sampAddChatMessage("{00FF00}[Script TM] Учтена покупка охлаждаек ("..qty.." шт.): {FFFFFF}$" .. formatNumber(total_price), -1)
            end
        end
    end
	
	
    -- === ОБРАБОТКА НАЧИСЛЕНИЯ AZ-COINS ИЗ ИНВЕНТАРЯ И ЛОТЕРЕИ ===
    if cleanText:find("Вам начислено") and cleanText:find("AZ%-Coins") then
        local az_str = cleanText:match("Вам начислено%s+(%d[%d%.,%s]*)")
        local az_val = parse_numeric_value(az_str)
        if az_val > 0 then
            session_stats.az_accumulated = (session_stats.az_accumulated or 0) + az_val
            save_stats_to_file()
            sampAddChatMessage("{00FF00}[TM] Получено AZ из инвентаря: +" .. formatNumber(az_val) .. " AZ", -1)
        end
    end

    if cleanText:find("были начислены на ваш донат%-счет") then
        local az_str = cleanText:match("(%d[%d%.,%s]*)%s*AZ%s+Coins%s+были%s+начислены")
                    or cleanText:match("начислены%s+(%d[%d%.,%s]*)%s*AZ")
        local az_val = parse_numeric_value(az_str)
        if az_val > 0 then
            session_stats.az_accumulated = (session_stats.az_accumulated or 0) + az_val
            save_stats_to_file()
            sampAddChatMessage("{00FF00}[TM] Получено AZ из лотереи: +" .. formatNumber(az_val) .. " AZ", -1)
        end
    end

    -- === ОБРАБОТКА ИСХОДЯЩЕГО ПЕРЕВОДА (ТРАТЫ) ===
    if cleanText:find("Вы перевели") and cleanText:find("на счет") then
        local transfer_val_str = cleanText:match("Вы перевели.-(%d[%d%.,%s]*)%s*игроку")
        if transfer_val_str then
            local val = parse_numeric_value(transfer_val_str)
            if val > 0 then
                local multiplier = isViceCityTransaction(text, cleanText) and 136 or 1
                val = val * multiplier
                session_stats.expenses_accumulated = (session_stats.expenses_accumulated or 0) + val
                save_stats_to_file()
            end
        end
    end

    -- === ОБРАБОТКА ВХОДЯЩЕГО ПЕРЕВОДА (ПРИБЫЛЬ) ===
    if cleanText:find("перевод на ваш счет") then
        local income_val_str = cleanText:match("в размере.-(%d[%d%.,%s]*)%s*от жителя")
        if income_val_str then
            local val = parse_numeric_value(income_val_str)
            if val > 0 then
                local multiplier = isViceCityTransaction(text, cleanText) and 136 or 1
                val = val * multiplier
                session_stats.trade_income = (session_stats.trade_income or 0) + val
                save_stats_to_file()
            end
        end
    end

    if cleanText:find("подтвердил сделку", 1, true)
        or cleanText:find("подтвердили сделку", 1, true)
        or cleanText:find("совершили сделку", 1, true) then

        tm_trade_waiting_money = true
        tm_trade_waiting_time = os.clock()
    end

    processDealIncomeMessage(cleanText)

if cleanText:find("Вы успешно сняли") and cleanText:find("со счета бизнес") then
    local biz_amount_str = cleanText:match("Вы успешно сняли%s*.-(%d[%d%.,%s]*)")
    local biz_val = parse_numeric_value(biz_amount_str)
    if biz_val > 0 then
        session_stats.biz_income = (session_stats.biz_income or 0) + biz_val
        add_history_log("Бизнес", "Снятие со счета бизнеса", "+$" .. formatNumber(biz_val), false)
        save_stats_to_file()
    end
end


if cleanText:find("Вы совершили обмен") and cleanText:find("BTC на") then
    local btc_amount_str = cleanText:match("BTC на%s*.-(%d[%d%.,%s]*)")
    local btc_val = parse_numeric_value(btc_amount_str)
    if btc_val > 0 then
        session_stats.btc_income = (session_stats.btc_income or 0) + btc_val
        add_history_log("BTC", "Продажа BTC", "+$" .. formatNumber(btc_val), false)
        save_stats_to_file()
    end
end


if cleanText:find("Вы совершили обмен") and cleanText:find("на") and cleanText:find("BTC") then
    local money_amount_str = cleanText:match("Вы совершили обмен%s+(.-)%s+на")
    if money_amount_str then
        local cost_val = parse_numeric_value(money_amount_str)
        if cost_val > 0 then
            session_stats.expenses_accumulated = (session_stats.expenses_accumulated or 0) + cost_val
            add_history_log("BTC", "Покупка BTC", "-$" .. formatNumber(cost_val), true)
            save_stats_to_file()
        end
    end
end


    -- === ОБРАБОТКА ПРОДАЖИ (ПРИБЫЛЬ) ===
    -- === ОБРАБОТКА ПРОДАЖИ (ПРИБЫЛЬ) ===
    -- === ОБРАБОТКА ПРОДАЖИ (ПРИБЫЛЬ) ===
if cleanText:find("Вы успешно продали") and cleanText:find("получили") then
    local earned_str = cleanText:match("получили%s+([^%s%()]+)")
    if earned_str then
        local earned_val = parse_numeric_value(earned_str)
        if earned_val > 0 then
            local multiplier = isViceCityTransaction(text, cleanText) and 136 or 1
            earned_val = earned_val * multiplier
            session_stats.trade_income = (session_stats.trade_income or 0) + earned_val
            add_history_log("Продажа", "Продажа товара", "+$" .. formatNumber(earned_val), false)
            save_stats_to_file()
        end
    end
end


    -- === ОБРАБОТКА ПОКУПКИ (ТРАТЫ) ===
if cleanText:find("Вы успешно купили") and cleanText:find("за") then
    local spent_str = cleanText:match("за%s+([^%s%()]+)")
    if spent_str then
        local spent_val = parse_numeric_value(spent_str)
        if spent_val > 0 then
            local multiplier = isViceCityTransaction(text, cleanText) and 136 or 1
            spent_val = spent_val * multiplier
            session_stats.expenses_accumulated = (session_stats.expenses_accumulated or 0) + spent_val
            add_history_log("Покупка", "Покупка товара", "-$" .. formatNumber(spent_val), true)
            save_stats_to_file()
        end
    end
end


    -- === ОБРАБОТКА ПОЛУЧЕНИЯ ПОСЫЛКИ В ПУНКТЕ ВЫДАЧИ ===
    -- Пример сообщения: ?? В пункт выдачи пришла посылка item:123. Забрать: /storage
       -- === ОБРАБОТКА ПОЛУЧЕНИЯ ПОСЫЛКИ В ПУНКТЕ ВЫДАЧИ ===
    -- Триггер: В пункт выдачи пришла посылка item:номер.
    if cleanText:find("В пункт выдачи пришла посылка") then
        local is_player_chat = cleanText:find("говорит:") or cleanText:find("сказал:") or cleanText:find("%[%d+%]%s*:")
        if is_player_chat then return end

        -- Извлекаем ID (поддерживаем оба формата на всякий случай)
        local storageItemId = cleanText:match("item:(%d+)") or text:match(":item(%d+):")
        
        if storageItemId then
            -- Используем твою рабочую систему получения имени
            local name = getItemName(storageItemId)

            -- Используем твою рабочую систему черного списка
            if session_stats.ignored_items then
                if session_stats.ignored_items[name] or session_stats.ignored_items[tostring(storageItemId)] then
                    return -- Если в игноре, выходим
                end
            end

            -- Отправка в Telegram
            if storage[0] then
                local storage_tag = cfg.config.storageEmoji ~= "emoji_none" and ("{" .. cfg.config.storageEmoji .. "} ") or ""
                -- Формируем чистое сообщение без "Забрать: /storage"
                local msg = storage_tag .. "В пункт выдачи пришла посылка: " .. name
                sendTelegramMessage(msg)
            end
        end
        return 
    end





    -- === ОБРАБОТКА ПОЛУЧЕНИЯ ПРЕДМЕТОВ ===
    local itemId = text:match(":item(%d+):")

if color == -65281 or text:find("Вам добавлен предмет") or text:find("добавлен предмет") then
        local is_player_chat = cleanText:find("говорит:") or cleanText:find("сказал:") or cleanText:find("%[%d+%]%s*:")
        if is_player_chat then return end

        local oldItemName = text:match(
            "В инвентарь добавлен предмет:%s*'([^']-)%s*'%s*%.?[,%.]?%s*используйте клавишу 'Y' или /invent"
        )

        if oldItemName then
            oldItemName = oldItemName:gsub("%s+$", "")

            if itemAdding[0] then
                local message_to_send = string.format(
                    "Вам был добавлен предмет '%s'. Откройте инвентарь, используйте клавишу 'Y' или /invent",
                    oldItemName
                )

                sendTelegramMessage(message_to_send)
            end

            return
        end

        local itemId = text:match(":item(%d+):")
        if itemId then
            local name = getItemName(itemId)

            if session_stats.ignored_items then
                if session_stats.ignored_items[name] or session_stats.ignored_items[tostring(itemId)] then
                    return
                end
            end

            if not sendUnknownItems[0] and name:find("ID:") then return end

            if itemAdding[0] then
                local message_to_send = string.format(
                    "Вам был добавлен предмет '%s'. Откройте инвентарь, используйте клавишу 'Y' или /invent",
                    name
                )

                sendTelegramMessage(message_to_send)
            end

            return
        end
    end


    if cleanText:find("Вы выбрали местом спавна") then
        if update_available then
            wasOpenedByCommand = false
            show_update_popup[0] = true
        end

        if spawnSelect[0] then
            local spawn_tag = cfg.config.spawnEmoji ~= "emoji_none" and ("{" .. cfg.config.spawnEmoji .. "} ") or ""
            sendTelegramMessage(spawn_tag .. cleanText)
        end
    end

    if cleanText:find("^%[Боевой Пропуск%]") or cleanText:find("выполнили задание") then
        local cleaned = cleanText:gsub("^%s+", ""):gsub("%s+$", "")
        session_stats.quests_completed = session_stats.quests_completed + 1
        save_stats_to_file()

        if quest[0] and cleaned:find("^%[Боевой Пропуск%]") then
            local body = cleaned:match("^%[Боевой Пропуск%]%s*(.*)") or ""
            local item_pickup = body:match("забрали предмет%s*-%s*'([^']+)'") or body:match("забрали%s*-%s*'([^']+)'")
            local task_complete = body:match("выполнили задание%s*-%s*'([^']+)'")
            local event_type = item_pickup and "Забрал предмет" or (task_complete and "Выполнил задание" or nil)
            local item_or_task_name = item_pickup or task_complete

            if event_type and item_or_task_name then
                local quest_tag = cfg.config.questEmoji ~= "emoji_none" and ("{" .. cfg.config.questEmoji .. "} ") or ""
                sendTelegramMessage(quest_tag .. "[Боевой Пропуск]\n" .. event_type .. ": " .. item_or_task_name)
            end
        end
    end 

    local PayDayLineDetector = false
    if cleanText:find('БАНКОВСКИЙ ЧЕК') or cleanText:find('Банковский чек') then
        getPayday = true
        listPayday = {}
        paydayTimeout = os.time() + 5
        local h_tag = cfg.config.paydayHeaderEmoji ~= "emoji_none" and ("{" .. cfg.config.paydayHeaderEmoji .. "}") or ""
        table.insert(listPayday, h_tag .. "PayDay | БАНКОВСКИЙ ЧЕК" .. h_tag)
    elseif getPayday then
        local cleanLine = cleanText
        local bank_tag = cfg.config.paydayBankEmoji ~= "emoji_none" and "{" .. cfg.config.paydayBankEmoji .. "}" or ""
        local dep_tag = cfg.config.paydayDepositEmoji ~= "emoji_none" and "{" .. cfg.config.paydayDepositEmoji .. "}" or ""
        local wage_tag = cfg.config.paydayWageEmoji ~= "emoji_none" and "{" .. cfg.config.paydayWageEmoji .. "}" or ""
        local az_tag = cfg.config.paydayAZEmoji ~= "emoji_none" and "{" .. cfg.config.paydayAZEmoji .. "}" or ""
        
        local keep = false
        if cleanLine:find('==========') or cleanLine:find('__________') then
            keep = true
        elseif cleanLine:find('Текущая сумма в банке:') then
            cleanLine = cleanLine:gsub(':CASH:', bank_tag)
            keep = true
        elseif cleanLine:find('В данный момент у вас') and cleanLine:find('респектов') then
            keep = true
        elseif cleanLine:find('Текущая сумма на депозите:') then
            local dep_text = cleanLine:match("депозите:.*%((.+)%)")
            local dep_val = dep_text and parse_numeric_value(dep_text) or 0
            session_stats.dep_growth = (session_stats.dep_growth or 0) + dep_val
            session_stats.last_payday_dep = dep_val
            cleanLine = cleanLine:gsub(':CASH:', dep_tag)
            keep = true
            PayDayLineDetector = true
        elseif cleanLine:find('Общая заработная плата:') then
            local wage_val = parse_numeric_value(cleanLine:match("плата:%s*(.*)"))
            session_stats.wages_accumulated = (session_stats.wages_accumulated or 0) + wage_val
            session_stats.last_payday_wage = wage_val
            cleanLine = cleanLine:gsub(':CASH:', wage_tag)
            keep = true
            PayDayLineDetector = true
        elseif cleanLine:find('Баланс на донат') then
            local az_text = cleanLine:match("донат.-%((.+)%)")
            local az_val = az_text and parse_numeric_value(az_text) or 0
            session_stats.az_accumulated = (session_stats.az_accumulated or 0) + az_val
            session_stats.last_payday_az = az_val
            cleanLine = cleanLine:gsub('AZ', az_tag)
            keep = true
            PayDayLineDetector = true
        end
        
        if PayDayLineDetector then save_stats_to_file() end

        if keep then
            table.insert(listPayday, formatNumbersInText(cleanLine))
            if (cleanText:find('==========') or cleanText:find('__________')) and #listPayday > 4 then
                if payday[0] then sendTelegramMessage(table.concat(listPayday, '\n')) end
                getPayday = false 
            end
        end
    end

    if getPayday and os.time() > paydayTimeout then
        if #listPayday > 2 and payday[0] then
            sendTelegramMessage(table.concat(listPayday, '\n'))
        end
        getPayday = false 
    end
end

function __gc()
    save_stats_to_file()
end
