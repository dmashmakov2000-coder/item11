--[[
    Script [TM]
    Разработал: Dima_Shmakov
    Версия: 0.0.9.9 (Единая папка Script [TM])
    Модификация: Все файлы (items.json, logo.png, stats) хранятся в папке Script [TM].
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

-- Создаём папку Script [TM], если нет
if not doesDirectoryExist(script_folder) then
    createDirectory(script_folder)
    print("[TM] Папка 'Script [TM]' создана по пути: " .. script_folder)
end

-- Все файлы теперь в Script [TM]
local items_db_path = script_folder .. "\\items.json"
local logo_path = script_folder .. "\\logo.png"
local stats_file_path = script_folder .. "\\ScriptTM_stats.json"

-- URL для скачивания
local ITEMS_DB_URL = "https://raw.githubusercontent.com/dmashmakov2000-coder/item11/main/items.json"
local LOGO_URL = "https://raw.githubusercontent.com/dmashmakov2000-coder/item11/main/logo.png"

-- === КОНФИГУРАЦИЯ СТАТИСТИКИ И ПРОЧЕЕ ===
local SCRIPT_VERSION = "0.0.9.0"
local UPDATE_URL = "https://raw.githubusercontent.com/dmashmakov2000-coder/item11/main/Item.lua"
local CFG_FILENAME = 'Script [TM].ini'

local ANTIBLOCK_URL = "https://tg.bakh.us"
local DEFAULT_API = "https://api.telegram.org"

local UPDATE_INFO = [[
0.0.9.0:

]]




-- === ПАКЕТ ИЗ 33 БЕЗОПАСНЫХ СМАЙЛИКОВ ===
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
    { key = "emoji_unlock", char = "\xf0\x9f\x94\x93", name = "Открыто", ui_name = "[ Открыто ]", desc = "Открытый навесной замок" },
    { key = "emoji_wave", char = "\xf0\x9f\x91\x8b", name = "Привет", ui_name = "[ Привет ]", desc = "Машущая рука приветствия" },
    { key = "emoji_chat", char = "\xf0\x9f\x92\xac", name = "Чат", ui_name = "[ Чат ]", desc = "Облако диалога / Чат" },
    { key = "emoji_ad", char = "\xf0\x9f\x93\xa2", name = "Реклама", ui_name = "[ Реклама ]", desc = "Объявление" },
    { key = "emoji_crown", char = "\xf0\x9f\x91\x91", name = "Корона", ui_name = "[ Корона ]", desc = "Золотая корона лидера" },
    { key = "emoji_star", char = "\xe2\xad\x90", name = "Звезда", ui_name = "[ Звезда ]", desc = "Золотая звезда" },
    { key = "emoji_trophy", char = "\xf0\x9f\x8f\x86", name = "Кубок", ui_name = "[ Кубок ]", desc = "Наградной золотой кубок" },
    { key = "emoji_rocket", char = "\xf0\x9f\x9a\x80", name = "Ракета", ui_name = "[ Ракета ]", desc = "Космическая ракета" },
}

-- Таблица совместимости векторных имен (FA6 -> FA5 Fallbacks)
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
    az_accumulated = 0,
    report_sent = false,
    
    -- Для окна проекции заработка
    last_payday_wage = 0,
    last_payday_dep = 0,
    last_payday_az = 0
}

local items_name = {}
local items_loaded = false
local font_loaded = false

-- === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ОЧИСТКИ И ИКОНОК ===
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
function cleanColors(text)
    if type(text) ~= "string" then return text end
    return text:gsub("{%x%x%x%x%x%x}", "")
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

-- Безопасное получение векторной иконки FontAwesome
local function getIcon(name, fallback)
    if font_loaded and fa_ok and fa and fa[name] then
        return fa[name] .. " "
    end
    return fallback or ""
end

-- Функция безопасного перевода UTF-8 в нативную CP1251
local function to_cp1251(str)
    if type(str) ~= "string" then return str end
    if str:find("[\208\209]") then
        local ok, decoded = pcall(function() return u8:decode(str) end)
        if ok then return decoded end
    end
    return str
end

-- Вспомогательная функция очистки строки в чистое число
local function parse_numeric_value(str)
    if not str then return 0 end
    local clean = str:gsub("{%x%x%x%x%x%x}", ""):gsub("[^%d%-]", "")
    return tonumber(clean) or 0
end

-- Форматирование времени игры в ЧЧ:ММ:СС
local function format_game_time(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

-- === УНИВЕРСАЛЬНЫЙ ЗАГРУЗЧИК БАЗЫ ДАННЫХ ===
function loadItemsDatabase()
    if doesFileExist(items_db_path) then
        local f = io.open(items_db_path, "r")
        if f then
            local content = f:read("*a")
            f:close()
            
            local raw_data = nil
            
            if content:find("local%s+items_name%s*=") or content:find("%[%s*%d+%s*%]%s*=") then
                local clean_lua = content:gsub("local%s+items_name%s*=%s*", "return ")
                local fn, err = load(clean_lua)
                if fn then
                    local ok, res = pcall(fn)
                    if ok and type(res) == "table" then
                        raw_data = res
                    end
                end
            else
                local ok, decoded = pcall(json.decode, content)
                if ok then 
                    raw_data = decoded
                end
            end

            if raw_data then
                items_name = {}
                for k, v in pairs(raw_data) do
                    items_name[tostring(k)] = to_cp1251(v)
                end
                items_loaded = true
                print("[TM] База предметов успешно загружена!")
            else
                print("[TM] Ошибка: Не удалось распознать структуру items.json!")
            end
        end
    else
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
                print("[TM] База предметов успешно обновлена.")
            end
        end
    end)
end

-- === СКАЧИВАНИЕ ЛОГОТИПА ===
function downloadLogo()
    if not requests_ok then
        sampAddChatMessage("{ff0000}[TM] Ошибка: библиотека 'requests' не найдена. Невозможно скачать логотип.", -1)
        return
    end
    lua_thread.create(function()
        local ok, res = pcall(requests_lib.get, LOGO_URL)
        if ok and res.status_code == 200 then
            local f = io.open(logo_path, "wb")
            if f then
                f:write(res.body or res.text)
                f:close()
                print("[TM] Логотип успешно скачан в: " .. logo_path)
                -- Перезагружаем текстуру
                local ok_tex, tex = pcall(imgui.CreateTextureFromFile, logo_path)
                if ok_tex and tex then
                    logo_texture = tex
                    sampAddChatMessage("{00FF00}[TM] Логотип обновлён и загружен!", -1)
                else
                    sampAddChatMessage("{ffff00}[TM] Логотип скачан, но не удалось загрузить текстуру.", -1)
                end
            else
                sampAddChatMessage("{ff0000}[TM] Ошибка: не удалось создать файл логотипа.", -1)
            end
        else
            sampAddChatMessage("{ff0000}[TM] Ошибка при скачивании логотипа (статус: " .. tostring(res and res.status_code) .. ").", -1)
        end
    end)
end


-- Получение названия предмета из базы данных
function getItemName(id)
    if not items_loaded then return "ID: " .. id end
    return items_name[tostring(id)] or items_name[tonumber(id)] or ("ID: " .. id)
end

-- === СОХРАНЕНИЕ СТАТИСТИКИ В ФАЙЛ ===
local function save_stats_to_file()
    local data = {
        last_active_date = session_stats.last_active_date,
        time_in_game = session_stats.time_in_game,
        quests_completed = session_stats.quests_completed,
        wages_accumulated = session_stats.wages_accumulated,
        dep_growth = session_stats.dep_growth,
        az_accumulated = session_stats.az_accumulated,
        report_sent = session_stats.report_sent,
        
        last_payday_wage = session_stats.last_payday_wage,
        last_payday_dep = session_stats.last_payday_dep,
        last_payday_az = session_stats.last_payday_az
    }
    local f = io.open(stats_file_path, "w")
    if f then
        f:write(json.encode(data))
        f:close()
    end
end

-- === ГЕНЕРАТОР ТЕКСТОВОГО ЕЖЕДНЕВНОГО ОТЧЁТА В ТЕЛЕГРАМ ===
local function get_session_report_text(date_str)
    local lines = {}
    table.insert(lines, "{emoji_bag} *ЕЖЕДНЕВНЫЙ ОТЧЁТ ЗА " .. tostring(date_str) .. "*")
    table.insert(lines, "====================================")
    table.insert(lines, "? *Время в игре:* " .. format_game_time(session_stats.time_in_game))
    table.insert(lines, "{emoji_trophy} *Выполнено квестов:* " .. tostring(session_stats.quests_completed))
    table.insert(lines, "")
    table.insert(lines, "{emoji_money} *ФИНАНСЫ ЗА ДЕНЬ:*")
    table.insert(lines, "  > {emoji_dollar} *Зарплата (общая):* $" .. tostring(session_stats.wages_accumulated))
    table.insert(lines, "  > {emoji_card} *Прирост по депозиту:* $" .. tostring(session_stats.dep_growth))
    table.insert(lines, "  > {emoji_coin} *Заработано AZ-Coins:* " .. tostring(session_stats.az_accumulated) .. " AZ")
    table.insert(lines, "====================================")
    
    return table.concat(lines, "\n")
end

-- === ЗАГРУЗКА СТАТИСТИКИ И ОФФЛАЙН ДОГОН ===
local function load_stats_from_file()
    local current_date = os.date("%d.%m.%Y")
    if doesFileExist(stats_file_path) then
        local f = io.open(stats_file_path, "r")
        if f then
            local content = f:read("*a")
            f:close()
            local ok, decoded = pcall(json.decode, content)
            if ok and decoded then
                if decoded.last_active_date == current_date then
                    -- Загружаем сегодняшнюю сессию
                    session_stats.last_active_date = decoded.last_active_date or current_date
                    session_stats.time_in_game = decoded.time_in_game or 0
                    session_stats.quests_completed = decoded.quests_completed or 0
                    session_stats.wages_accumulated = decoded.wages_accumulated or 0
                    session_stats.dep_growth = decoded.dep_growth or 0
                    session_stats.az_accumulated = decoded.az_accumulated or 0
                    session_stats.report_sent = decoded.report_sent or false
                    
                    session_stats.last_payday_wage = decoded.last_payday_wage or 0
                    session_stats.last_payday_dep = decoded.last_payday_dep or 0
                    session_stats.last_payday_az = decoded.last_payday_az or 0
                else
                    -- ДАТА ИЗМЕНИЛАСЬ: Автодогон по дате
                    if decoded.report_sent == false and (decoded.wages_accumulated > 0 or decoded.quests_completed > 0 or decoded.dep_growth > 0 or decoded.az_accumulated > 0 or (decoded.time_in_game or 0) > 60) then
                        -- Временно восстанавливаем вчерашние статы для генерации отчета
                        session_stats.time_in_game = decoded.time_in_game or 0
                        session_stats.quests_completed = decoded.quests_completed or 0
                        session_stats.wages_accumulated = decoded.wages_accumulated or 0
                        session_stats.dep_growth = decoded.dep_growth or 0
                        session_stats.az_accumulated = decoded.az_accumulated or 0
                        
                        local old_date = decoded.last_active_date or "Прошлый день"
                        local report_text = get_session_report_text(old_date)
                        sendTelegramMessage(report_text)
                    end

                    -- Очищаем для сегодняшнего дня
                    session_stats.last_active_date = current_date
                    session_stats.time_in_game = 0
                    session_stats.quests_completed = 0
                    session_stats.wages_accumulated = 0
                    session_stats.dep_growth = 0
                    session_stats.az_accumulated = 0
                    session_stats.report_sent = false
                    
                    session_stats.last_payday_wage = decoded.last_payday_wage or 0
                    session_stats.last_payday_dep = decoded.last_payday_dep or 0
                    session_stats.last_payday_az = decoded.last_payday_az or 0
                    save_stats_to_file()
                end
                return
            end
        end
    end
    -- Инициализируем с нуля
    session_stats.last_active_date = current_date
    session_stats.time_in_game = 0
    session_stats.quests_completed = 0
    session_stats.wages_accumulated = 0
    session_stats.dep_growth = 0
    session_stats.az_accumulated = 0
    session_stats.report_sent = false
    
    session_stats.last_payday_wage = 0
    session_stats.last_payday_dep = 0
    session_stats.last_payday_az = 0
    save_stats_to_file()
end

-- === КОНФИГУРАЦИЯ ПО УМОЛЧАНИЮ ===
local default_config = {
    config = {
        chat = '',
        token = '',
        useAntiBlock = true,
        itemAdding = false,
        sendUnknownItems = false,
        shortMessage = false, 
        payday = false,
        storage = false,
        spawnSelect = false,
        enableUINotifications = true,
        quest = true,
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

-- === ПЕРЕМЕННЫЕ ДЛЯ АВТООБНОВЛЕНИЯ ===
local remote_version_text = SCRIPT_VERSION
local update_available = false
local update_check_in_progress = false
local remote_update_info = "" 
local show_update_popup = imgui.new.bool(false) 

-- === ЗАГРУЗКА КОНФИГА ===
local cfg
local ok_cfg, err_cfg = pcall(inicfg.load, default_config, CFG_FILENAME)
if ok_cfg then 
    cfg = err_cfg 
else 
    cfg = default_config 
    print(('[TM] Error loading config. Using default. Error: %s'):format(err_cfg or 'N/A'))
end

-- Фиксы отсутствия полей
cfg.config.paydayHeaderEmoji = cfg.config.paydayHeaderEmoji or "emoji_bag"
cfg.config.paydayBankEmoji = cfg.config.paydayBankEmoji or "emoji_dollar"
cfg.config.paydayDepositEmoji = cfg.config.paydayDepositEmoji or "emoji_dollar"
cfg.config.paydayWageEmoji = cfg.config.paydayWageEmoji or "emoji_dollar"
cfg.config.paydayAZEmoji = cfg.config.paydayAZEmoji or "emoji_coin"
cfg.config.itemEmoji = cfg.config.itemEmoji or "emoji_gift"
cfg.config.storageEmoji = cfg.config.storageEmoji or "emoji_box"
cfg.config.questEmoji = cfg.config.questEmoji or "emoji_trophy"
cfg.config.spawnEmoji = cfg.config.spawnEmoji or "emoji_house"

-- === ИНИЦИАЛИЗАЦИЯ ПЕРЕМЕННЫХ UI ===
local chat = imgui.new.char[128](tostring(cfg.config.chat))
local token = imgui.new.char[128](tostring(cfg.config.token))
local useAntiBlock = imgui.new.bool(cfg.config.useAntiBlock or true)

local itemAdding = imgui.new.bool(cfg.config.itemAdding)
local sendUnknownItems = imgui.new.bool(cfg.config.sendUnknownItems)
local shortMessage = imgui.new.bool(cfg.config.shortMessage)
local payday = imgui.new.bool(cfg.config.payday)
local storage = imgui.new.bool(cfg.config.storage)
local spawnSelect = imgui.new.bool(cfg.config.spawnSelect)
local quest = imgui.new.bool(cfg.config.quest)
local enableUINotifications = imgui.new.bool(cfg.config.enableUINotifications)

local getPayday = false
local listPayday = {}
local paydayTimeout = 0

local window = imgui.new.bool(false)
local currentTab = imgui.new.int(1) -- 1: Настройки, 2: Уведомления, 3: Стилизация, 4: Статистика

-- Переменные для полноэкранного модального окна выбора смайликов
local show_emoji_selector_modal = imgui.new.bool(false)
local selected_emoji_setting = ""

-- =========================================
-- === ОПРЕДЕЛЕНИЕ effilTelegramSendMessage ===
local effilTelegramSendMessage = effil_ok and effil.thread(function(text, chatID, token, baseUrl)
    local requests = require('requests')
    local post_data = {
        params = { 
            text = text, 
            chat_id = chatID 
        }
    }
    local ok, res = pcall(function()
        local url = ("%s/bot%s/sendMessage"):format(baseUrl, token)
        return requests.post(url, post_data)
    end)
    if not ok then
        print(('[TM] Ошибка запроса: %s'):format(res or 'Unknown'))
    end
end) or nil

-- === ФУНКЦИЯ КОДИРОВАНИЯ URL ===
function urlencode(str)
   if str then
      local utf8_str = u8:encode(str)
      
      -- Проходим по всем смайликам
      for _, emoji in ipairs(emojis_list) do
         utf8_str = utf8_str:gsub("{" .. emoji.key .. "}", emoji.char)
      end

      -- Экранируем символы для URL
      utf8_str = utf8_str:gsub("([^%w _%%%-%.~])", function(c) 
         return string.format("%%%02X", string.byte(c)) 
      end)
      utf8_str = utf8_str:gsub(" ", "%%20")
      return utf8_str
   end
   return ""
end

-- === ФУНКЦИЯ ОТПРАВКИ СООБЩЕНИЯ В TELEGRAM ===
local function sendTelegramMessage(text)
    local chat_id_str = ffi.string(chat)
    local token_str = ffi.string(token)

    if chat_id_str == '' or token_str == '' or not effilTelegramSendMessage then 
        return 
    end
    
    local baseUrl = useAntiBlock[0] and ANTIBLOCK_URL or "https://api.telegram.org"
    local clean_text = text:gsub('{......}', '')
    local encoded_text = urlencode(clean_text)
    
    effilTelegramSendMessage(encoded_text, chat_id_str, token_str, baseUrl)
end

-- === ФУНКЦИЯ АВТООБНОВЛЕНИЯ ===
function downloadAndInstallUpdate()
    if not requests_ok then
        sampAddChatMessage("{ff0000}[TM] Ошибка: Библиотека 'requests' не найдена. Невозможно обновить.", -1)
        return
    end
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
            else
                sampAddChatMessage("{ff0000}[TM] Ошибка: Не удалось перезаписать файл.", -1)
            end
        else
            sampAddChatMessage("{ff0000}[TM] Ошибка при скачивании файла.", -1)
        end
    end)
end

function checkUpdate()
    if update_check_in_progress or not requests_ok then return end
    update_check_in_progress = true
    remote_update_info = "" 
    show_update_popup[0] = false 
    lua_thread.create(function()
        local requests = require('requests')
        local ok, response = pcall(requests.get, UPDATE_URL)
        update_check_in_progress = false
        if ok and response.status_code == 200 then
            local remote_version = response.text:match('local%s+SCRIPT_VERSION%s*=%s*"([^"]+)"')
            local remote_info = response.text:match('local%s+UPDATE_INFO%s*=%s*%[%[(.-)%]%]')

            if remote_version and remote_version ~= SCRIPT_VERSION then
                update_available = true
                remote_version_text = remote_version
                remote_update_info = remote_info or "Информация об изменениях отсутствует." 
                sampAddChatMessage("{00FF00}[TM] Найдено обновление: " .. remote_version .. ". Откройте /tm и перейдите в 'Настройки' для обновления.", -1)
            else
                sampAddChatMessage("{00FF00}[TM] У вас актуальная версия скрипта.", -1)
            end
        else
             sampAddChatMessage("{FF0000}[TM] Ошибка при проверке обновлений.", -1)
        end
    end)
end

-- === СОХРАНЕНИЕ КОНФИГА ===
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

    -- Сохранение смайликов
    cfg.config.paydayHeaderEmoji = cfg.config.paydayHeaderEmoji
    cfg.config.paydayBankEmoji = cfg.config.paydayBankEmoji
    cfg.config.paydayDepositEmoji = cfg.config.paydayDepositEmoji
    cfg.config.paydayWageEmoji = cfg.config.paydayWageEmoji
    cfg.config.paydayAZEmoji = cfg.config.paydayAZEmoji
    cfg.config.itemEmoji = cfg.config.itemEmoji
    cfg.config.storageEmoji = cfg.config.storageEmoji
    cfg.config.questEmoji = cfg.config.questEmoji
    cfg.config.spawnEmoji = cfg.config.spawnEmoji

    local ok, err = pcall(inicfg.save, cfg, CFG_FILENAME)
    if not ok then
        print(('[TM] Error saving config: %s'):format(err))
        sampAddChatMessage(("{FF0000}[TM] Ошибка сохранения конфига: %s"):format(err or 'Неизвестно'), -1)
    end
end

function main()
    while not isSampAvailable() do wait(0) end
    for _, err in ipairs(load_errors) do sampAddChatMessage("{ff0000}[TM] " .. err, -1) end
    
    loadItemsDatabase()
    load_stats_from_file() -- Загрузка вечной сессии из JSON

    sampAddChatMessage('Script [TM] {ffffff}Активация командой: /tm', 0x3083ff)
    sampAddChatMessage('Script [TM] {ffffff}Разработан и написан Dima_Shmakov', 0x3083ff)
    sampAddChatMessage('Script [TM] {ffffff}Версия скрипта ' .. SCRIPT_VERSION, 0x3083ff)
    sampRegisterChatCommand('tm', function() 
        if update_available then
            show_update_popup[0] = true
            window[0] = false 
        else
            window[0] = not window[0] 
        end
    end)
    checkUpdate()

    -- === ФОНОВЫЙ ПОТОК: СЕКУНДОМЕР И АВТО-ОТПРАВКА В 00:00 ===
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
            
            -- Проверка наступления 00:00 (Нового дня)
            local current_date = os.date("%d.%m.%Y")
            if session_stats.last_active_date ~= "" and session_stats.last_active_date ~= current_date then
                -- Отменяем отчёт за вчерашний день, если не отправлен
                if session_stats.report_sent == false then
                    local report_text = get_session_report_text(session_stats.last_active_date)
                    sendTelegramMessage(report_text)
                    session_stats.report_sent = true
                    save_stats_to_file()
                end

                -- Очищаем данные для нового дня
                session_stats.last_active_date = current_date
                session_stats.quests_completed = 0
                session_stats.wages_accumulated = 0
                session_stats.dep_growth = 0
                session_stats.az_accumulated = 0
                session_stats.time_in_game = 0
                session_stats.report_sent = false
                save_stats_to_file()
            end
        end
    end)

    wait(-1)
end

-- === ФУНКЦИЯ ДЛЯ UI УВЕДОМЛЕНИЙ ARЗ ===
function visualCEF(str, is_encoded)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt16(bs, #str)
    raknetBitStreamWriteInt8(bs, is_encoded and 1 or 0)
    if is_encoded then
        raknetBitStreamEncodeString(bs, str)
    else
        raknetBitStreamWriteString(bs, str)
    end
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

function show_arz_notify(type, title, text, time)
    if enableUINotifications[0] then
        local function escape_js(s)
            return s:gsub("\\", "\\\\"):gsub('"', '\\"')
        end
        local safe_type = escape_js(type)
        local safe_title = escape_js(title)
        local safe_text = escape_js(text)
        local safe_time = tostring(time)
        local str = ('window.executeEvent("event.notify.initialize", "[\\"%s\\", \\"%s\\", \\"%s\\", \\"%s\\"]");'):format(safe_type, safe_title, safe_text, safe_time)
        visualCEF(str, true)
    end
end

-- === IMGUI ИНТЕРФЕЙС ===
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    modern_style() 
if doesFileExist(logo_path) then
        local ok, tex = pcall(imgui.CreateTextureFromFile, logo_path)
        if ok and tex then
            logo_texture = tex
            print("[TM] Текстура логотипа успешно загружена!")
        else
            print("[TM] Ошибка при создании текстуры логотипа: " .. tostring(tex))
        end
    else
        print("[TM] Логотип по пути '" .. logo_path .. "' отсутствует. Используется стандартное оформление.")
    end
    -- Автоматическое создание папок под ресурс логотипа
    if not doesDirectoryExist(getWorkingDirectory() .. "\\resource") then
        createDirectory(getWorkingDirectory() .. "\\resource")
    end
    if not doesDirectoryExist(getWorkingDirectory() .. "\\resource\\ScriptTM") then
        createDirectory(getWorkingDirectory() .. "\\resource\\ScriptTM")
    end

    -- Загрузка кастомного логотипа при наличии файла
    if doesFileExist(logo_path) then
        local ok, tex = pcall(imgui.CreateTextureFromFile, logo_path)
        if ok and tex then
            logo_texture = tex
            print("[TM] Текстура логотипа успешно загружена!")
        else
            print("[TM] Ошибка при создании текстуры логотипа: " .. tostring(tex))
        end
    else
        print("[TM] Логотип по пути '" .. logo_path .. "' отсутствует. Используется стандартное оформление.")
    end

    -- СЛИЯНИЕ ШРИФТОВ НАПРЯМУЮ ИЗ OPERATIVE MEMORY (Оригинальный метод Mining Tools)
    if fa_ok and fa then
        local config = imgui.ImFontConfig()
        config.MergeMode = true
        config.PixelSnapH = true
        
        -- Выделяем виртуальный диапазон символов векторных глифов
        local iconRanges = imgui.new.ImWchar[3](fa.min_range, fa.max_range, 0)
        
        -- Внедряем FontAwesome поверх стандартного системного Cyrillic шрифта mimgui
        local font = imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85('solid'), 14, config, iconRanges)
        if font ~= nil then
            font_loaded = true
            print("[TM] Нативный шрифт fAwesome6 успешно импортирован!")
        else
            print("[TM] Ошибка: Не удалось инициализировать fAwesome6.")
        end
    else
        print("[TM] Ошибка: Библиотека fAwesome6 не найдена в moonloader/lib/")
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

imgui.OnFrame(function() return window[0] or show_update_popup[0] or show_emoji_selector_modal[0] end, function(player)
    local resX, resY = getScreenResolution()

    -- === ГЛАВНОЕ ОКНО ===
    if window[0] then
        local sizeX, sizeY = 440, 520 
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('##MainSettings', window, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar)
        local w_width = imgui.GetWindowWidth()
        
        -- 1. Шапка с Высокотехнологичным Векторным/Растровым Логотипом [Script TM]
        imgui.BeginChild("##header_main", imgui.ImVec2(w_width - 30, 65), true)
            local draw_list = imgui.GetWindowDrawList()
            local p = imgui.GetCursorScreenPos()
            
            -- Рисуем золотой неоновый круг-подложку логотипа
            local badge_center = imgui.ImVec2(p.x + 30, p.y + 25)
            local badge_radius = 28.0
            
            -- Получаем цвет заливки из стиля и контурный цвет безопасным способом GetColorU32Vec4
            local bg_color = imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.ButtonActive])
            local stroke_color = imgui.GetColorU32Vec4(imgui.ImVec4(0.95, 0.76, 0.18, 1.00))
            
            draw_list:AddCircleFilled(badge_center, badge_radius, bg_color, 32)
            
            -- Отрисовка кастомной картинки (логотипа) с автоматическим скруглением по маске золотого круга
            if logo_texture then
                local p_min = imgui.ImVec2(badge_center.x - 27, badge_center.y - 27)
                local p_max = imgui.ImVec2(badge_center.x + 27, badge_center.y + 27)
                local white_tint = imgui.GetColorU32Vec4(imgui.ImVec4(1.0, 1.0, 1.0, 1.0))
                -- Используем AddImageRounded для идеального скругления краёв картинки в ровный круг
                draw_list:AddImageRounded(logo_texture, p_min, p_max, imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), white_tint, 27.0)
            else
                -- Отрисовка короны лидера внутри эмблемы, если файл логотипа не найден
                imgui.SetCursorPos(imgui.ImVec2(15, 10))
                local logo_icon = getIcon("CROWN", "")
                if logo_icon ~= "" then
                    imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), logo_icon)
                else
                    imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), "TM")
                end
            end
            
            -- Накладываем золотой неоновый контур ПОВЕРХ картинки для сокрытия неровностей и бесшовного стыка
            draw_list:AddCircle(badge_center, badge_radius, stroke_color, 32, 1.5)
            
            -- Название бренда SCRIPT [TM] (Корона возвращена в текстовую часть заголовка)
            imgui.SetCursorPos(imgui.ImVec2(75, 12))
            imgui.PushStyleVarFloat(imgui.StyleVar.FrameBorderSize, 1.0)
            local crown_prefix = getIcon("CROWN", "")
            imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), crown_prefix .. "SCRIPT [TM]")
            imgui.PopStyleVar()
            
            -- Платиновый статус-подзаголовок
            imgui.SetCursorPos(imgui.ImVec2(75, 34))
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.60, 0.65, 0.73, 1.00))
            imgui.Text(u8("Телеграм логгер"))
            imgui.PopStyleColor()
        imgui.EndChild()
        imgui.Dummy(imgui.ImVec2(0, 10))
        
        -- 2. Переключатель Табов
        local tab_btn_w = (w_width - 45) / 4
        local is_tab1_active = (currentTab[0] == 1)
        local is_tab2_active = (currentTab[0] == 2)
        local is_tab3_active = (currentTab[0] == 3)
        local is_tab4_active = (currentTab[0] == 4)
        
        -- Таб 1 (Настройки)
		
        local stat_tab_label = getIcon("GEAR", "") .. u8('Настройки')
        if is_tab1_active then imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.3)) end
        if imgui.Button(stat_tab_label, imgui.ImVec2(tab_btn_w, 30)) then currentTab[0] = 1 end
        if is_tab1_active then imgui.PopStyleColor() end
        
        imgui.SameLine(nil, 5)
        
        -- Таб 2 (Уведомления)
        local stat_tab_label = getIcon("BELL", "") .. u8('Уведомления')
        if is_tab2_active then imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.3)) end
        if imgui.Button(stat_tab_label, imgui.ImVec2(tab_btn_w, 30)) then currentTab[0] = 2 end
        if is_tab2_active then imgui.PopStyleColor() end

        imgui.SameLine(nil, 5)

        -- Таб 3 (Стилизация)
		
		
        local stat_tab_label = getIcon("SLIDERS", "") .. u8('Стилизация')
        if is_tab3_active then imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.3)) end
        if imgui.Button(stat_tab_label, imgui.ImVec2(tab_btn_w, 30)) then currentTab[0] = 3 end
        if is_tab3_active then imgui.PopStyleColor() end

        imgui.SameLine(nil, 5)

        -- Таб 4 (Статистика)
        local stat_tab_label = getIcon("CHART_LINE", "") .. u8('Статистика')
        if is_tab4_active then imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.3)) end
        if imgui.Button(stat_tab_label, imgui.ImVec2(tab_btn_w, 30)) then currentTab[0] = 4 end
        if is_tab4_active then imgui.PopStyleColor() end

        imgui.Dummy(imgui.ImVec2(0, 10))


        -- 3. Основной контент
        imgui.BeginChild("##main_content", imgui.ImVec2(w_width - 30, sizeY - 185), true)
            
            if currentTab[0] == 1 then -- ВКЛАДКА НАСТРОЙКИ
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
				if imgui.Button(u8('Обновить Список предметов)'), imgui.ImVec2(-1, 30)) then
    downloadLogo()
    downloadItemsDatabase()
    show_arz_notify('success', 'TM', 'Файлы обновлены: logo.png, items.json', 3000)
end




            elseif currentTab[0] == 2 then -- ВКЛАДКА УВЕДОМЛЕНИЯ
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("BELL", "") .. u8("Управление уведомлениями"))
                imgui.Dummy(imgui.ImVec2(0, 5))

                if imgui.Checkbox(u8('Включить/выключить UI уведомления'), enableUINotifications) then
                    saveConfig()
                    local state = enableUINotifications[0] and "включены" or "выключены"
                    show_arz_notify('info', 'Интерфейс', 'Визуальные уведомления ' .. state, 3000)
                end
                imgui.SameLine()
                imgui.TextDisabled('(?)')
                if imgui.IsItemHovered() then
                    imgui.BeginTooltip()
                    imgui.Text(u8('Включает или выключает всплывающие уведомления в правом нижнем углу экрана (уведомления ARZ).'))
                    imgui.EndTooltip()
                end
                imgui.Separator()

                if imgui.Checkbox(u8('Оповещение о предметах'), itemAdding) then 
                    saveConfig() 
                    local state = itemAdding[0] and "активировано" or "деактивировано"
                    show_arz_notify('info', 'Предметы', 'Отслеживание предметов ' .. state, 3000)
                end
          
                if itemAdding[0] then
                    imgui.Indent(20)
                    if imgui.Checkbox(u8('Отправлять неизвестные предметы'), sendUnknownItems) then 
                        saveConfig() 
                        local state = sendUnknownItems[0] and "будут отправляться" or "скрыты"
                        show_arz_notify('info', 'Настройка', 'Неизвестные предметы ' .. state, 3000)
                    end

                    if imgui.Checkbox(u8('Отправлять старый вид сообщений'), shortMessage) then
                        saveConfig()
                        if shortMessage[0] then
                            show_arz_notify('info', 'Режим сообщений', 'Будет отправляться старый (полный) вид сообщений', 3000)
                        else
                            show_arz_notify('info', 'Режим сообщений', 'Будет отправляться новый компактный вид сообщений', 3000)
                        end
                    end
                    imgui.Unindent(20)
                end

                if imgui.Checkbox(u8('PayDay'), payday) then
                    saveConfig()
                    local state = payday[0] and "включены" or "выключены"
                    show_arz_notify('info', 'PayDay', 'Уведомления PayDay ' .. state, 3000)
                end

                if imgui.Checkbox(u8('Хранилище'), storage) then
                    saveConfig()
                    local state = storage[0] and "включены" or "выключены"
                    show_arz_notify('info', 'Хранилище', 'Уведомления о хранилище ' .. state, 3000)
                end

                if imgui.Checkbox(u8('квесты/задания'), quest) then
                    saveConfig()
                    local state = quest[0] and "включены" or "выключены"
                    show_arz_notify('info', 'квесты/задания', 'Уведомления о квестах/заданиях ' .. state, 3000)
                end
          
                if imgui.Checkbox(u8('Выбор места спавна'), spawnSelect) then
                    saveConfig()
                    if spawnSelect[0] then
                        show_arz_notify('info', 'Настройка', 'Уведомления о выборе спавна включены.', 3000)
                    else
                        show_arz_notify('info', 'Настройка', 'Уведомления о выборе спавна выключены.', 3000)
                    end
                end

            elseif currentTab[0] == 3 then -- ВКЛАДКА СТИЛИЗАЦИЯ SLIDERS
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("SLIDERS", "") .. u8("Управление уведомлениями"))
                imgui.TextDisabled(u8("Кликните на кнопку, чтобы выбрать новый смайл:"))
                imgui.Dummy(imgui.ImVec2(0, 5))

                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.06, 0.08, 0.11, 1.00))
                imgui.BeginChild("##styling_interactive", imgui.ImVec2(w_width - 50, 240), true)
                    
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.2))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.80, 0.44, 0.4))
                    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(6, 4))

                    local function drawEmojiConfigRow(label, config_key, test_message_base)
                        imgui.Text(label)
                        imgui.SameLine(180)
                        local render_str = getEmojiRenderString(cfg.config[config_key])
                        
                        -- Кнопка выбора
                        if imgui.Button(render_str .. "##btn_" .. config_key, imgui.ImVec2(100, 24)) then
                            selected_emoji_setting = config_key
                            show_emoji_selector_modal[0] = true
                        end

                        if test_message_base then
                            imgui.SameLine()
                            -- Кнопка ТЕСТ
                            if imgui.Button(u8("Тест##test_" .. config_key), imgui.ImVec2(50, 24)) then
                                local current_emoji_key = cfg.config[config_key]
                                local emoji_tag = current_emoji_key ~= "emoji_none" and "{" .. current_emoji_key .. "} " or ""
                                sendTelegramMessage(emoji_tag .. test_message_base)
                                show_arz_notify('info', 'Тест', 'Тестовое сообщение отправлено в Telegram.', 3000)
                            end
                            
                            imgui.SameLine()
                            imgui.TextDisabled('(?)')
                            if imgui.IsItemHovered() then
                                imgui.BeginTooltip()
                                imgui.Text(u8('Отправить тестовое сообщение в Telegram с текущим смайлом.'))
                                imgui.EndTooltip()
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

                    -- Большая кнопка теста общего сообщения PayDay
                    imgui.Dummy(imgui.ImVec2(0, 10))
                    if imgui.Button(u8("Тест PayDay сообщения"), imgui.ImVec2(-1, 30)) then
                        local header_tag = cfg.config.paydayHeaderEmoji ~= "emoji_none" and "{" .. cfg.config.paydayHeaderEmoji .. "}" or ""
                        local bank_tag = cfg.config.paydayBankEmoji ~= "emoji_none" and "{" .. cfg.config.paydayBankEmoji .. "}" or ""
                        local dep_tag = cfg.config.paydayDepositEmoji ~= "emoji_none" and "{" .. cfg.config.paydayDepositEmoji .. "}" or ""
                        local wage_tag = cfg.config.paydayWageEmoji ~= "emoji_none" and "{" .. cfg.config.paydayWageEmoji .. "}" or ""
                        local az_tag = cfg.config.paydayAZEmoji ~= "emoji_none" and "{" .. cfg.config.paydayAZEmoji .. "}" or ""
                        
                        local test_message = string.format(
                            "%sPayDay | БАНКОВСКИЙ ЧЕК%s\n" ..
                            "==========\n" ..
                            "Текущая сумма в банке: %s200.400.500$\n" ..
                            "В данный момент у вас 200 уровень\n" ..
                            "Текущая сумма на депозите: %s987.654.321$\n" ..
                            "Общая заработная плата: %s500.000$\n" ..
                            "Баланс на донат-счет: %s1AZ\n" ..
                            "==========" ,
                            header_tag, header_tag, bank_tag, dep_tag, wage_tag, az_tag
                        )
                        sendTelegramMessage(test_message)
                        show_arz_notify('info', 'Тест PayDay', 'Тестовое сообщение PayDay отправлено в Telegram.', 3000)
                    end
                    imgui.Separator()

                    imgui.Dummy(imgui.ImVec2(0, 5))
                    imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8("— Другие Сообщения —"))
                    imgui.Separator()
                    drawEmojiConfigRow(u8("Инвентарь (Предметы)"), "itemEmoji", "Вам был добавлен предмет: 'Резиновый пенис )'")
                    drawEmojiConfigRow(u8("Сообщение Хранилища"), "storageEmoji", "У Вас есть предметы в хранилище пункта выдачи.")
                    drawEmojiConfigRow(u8("Выбор места спавна"), "spawnEmoji", "Вы выбрали местом спавна: Дом #394")
                    drawEmojiConfigRow(u8("Квесты / Задания"), "questEmoji", "[Боевой Пропуск] Выполнил задание: 'Тестовое Задание'")

                    imgui.PopStyleVar()
                    imgui.PopStyleColor(2)
                imgui.EndChild()
                imgui.PopStyleColor()

            elseif currentTab[0] == 4 then -- ВКЛАДКА СТАТИСТИКА
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("CHART_LINE", "") .. u8("Ежедневный Финансовый Журнал"))
                
                -- КНОПКА [?] С КРАСИВЫМ ОФОРМЛЕНИЕМ ИКОНКИ
                imgui.SameLine(w_width - 65)
                local q_icon = (font_loaded and fa_ok and fa and fa.CIRCLE_QUESTION) and (fa.CIRCLE_QUESTION .. " ") or "[?] "
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.95, 0.76, 0.18, 0.2))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.95, 0.76, 0.18, 0.4))
                if imgui.Button(q_icon .. "##projection_btn", imgui.ImVec2(32, 24)) then
                    imgui.OpenPopup("ProjectionPopup")
                end
                imgui.PopStyleColor(2)
                
                -- РЕНДЕРИНГ ОКНА МИНИ-СТАТИСТИКИ ПРОГНОЗА С РАЗДЕЛЕНИЕМ ЧИСЕЛ ТОЧКАМИ
                imgui.SetNextWindowSize(imgui.ImVec2(380, 420), imgui.Cond.Always)
                if imgui.BeginPopup("ProjectionPopup") then
                    imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), getIcon("CHART_LINE", "") .. u8("Прогноз прибыли (при непрерывной игре)"))
                    imgui.Separator()
                    imgui.Dummy(imgui.ImVec2(0, 3))
                    
                    local last_w = session_stats.last_payday_wage or 0
                    local last_d = session_stats.last_payday_dep or 0
                    local last_a = session_stats.last_payday_az or 0
                    
                    -- Последний PayDay Card
                    imgui.TextColored(imgui.ImVec4(0.60, 0.65, 0.73, 1.00), getIcon("CLOCK", "") .. u8("Последний полученный PayDay:"))
                    imgui.BeginChild("##last_payday_card", imgui.ImVec2(0, 70), true)
                        imgui.Text(getIcon("DOLLAR_SIGN", "") .. u8("Зарплата: $") .. formatNumber(last_w))
                        imgui.Text(getIcon("CREDIT_CARD", "") .. u8("Депозит: $") .. formatNumber(last_d))
                        imgui.Text(getIcon("COINS", "") .. u8("AZ-Coins: ") .. formatNumber(last_a) .. " AZ")
                    imgui.EndChild()
                    imgui.Dummy(imgui.ImVec2(0, 5))
                    
                    -- Прогнозы
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
                imgui.Dummy(imgui.ImVec2(0, 5))

                -- КРАСИВАЯ КАРТОЧКА СЕССИИ (Date, Time, Quests)
                imgui.BeginChild("##session_info_card", imgui.ImVec2(0, 75), true)
                    imgui.TextColored(imgui.ImVec4(0.60, 0.65, 0.73, 1.00), getIcon("CALENDAR_DAYS", "") .. u8("Дата сбора данных: ") .. tostring(session_stats.last_active_date))
                    imgui.TextColored(imgui.ImVec4(0.60, 0.65, 0.73, 1.00), getIcon("CLOCK", "") .. u8("Время в игре сегодня: ") .. format_game_time(session_stats.time_in_game))
                    imgui.TextColored(imgui.ImVec4(0.60, 0.65, 0.73, 1.00), getIcon("TROPHY", "") .. u8("Выполнено квестов за сегодня: ") .. tostring(session_stats.quests_completed))
                imgui.EndChild()
                
                imgui.Dummy(imgui.ImVec2(0, 5))

                imgui.TextColored(imgui.ImVec4(0.18, 0.80, 0.44, 1.00), getIcon("MONEY_BILL_WAVE", "") .. u8("Чистый баланс за сегодня:"))
                
                -- КРАСИВАЯ КАРТОЧКА БАЛАНСА С РАЗДЕЛЕНИЕМ ЧИСЕЛ ТОЧКАМИ
                imgui.BeginChild("##finance_card", imgui.ImVec2(0, 80), true)
                    local function drawStatRow(icon_name, label, value, val_color)
                        imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1.0), getIcon(icon_name, "") .. u8(label))
                        imgui.SameLine(220)
                        imgui.TextColored(val_color or imgui.ImVec4(1,1,1,1), value)
                    end
                    drawStatRow("DOLLAR_SIGN", "Получено зарплат (общая):", "$" .. formatNumber(session_stats.wages_accumulated), imgui.ImVec4(0.18, 0.80, 0.44, 1.00))
                    drawStatRow("CREDIT_CARD", "Прирост по депозиту:", "$" .. formatNumber(session_stats.dep_growth), imgui.ImVec4(0.18, 0.80, 0.44, 1.00))
                    drawStatRow("COINS", "Заработано AZ-Coins:", formatNumber(session_stats.az_accumulated) .. " AZ", imgui.ImVec4(0.95, 0.76, 0.18, 1.00))
                imgui.EndChild()

                imgui.Dummy(imgui.ImVec2(0, 10))

                -- Кнопка ручной отправки текущей статистики
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.2))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.80, 0.44, 0.4))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.18, 0.80, 0.44, 0.1))
                if imgui.Button(getIcon("PAPER_PLANE", "") .. u8("Отправить текущий отчёт в Telegram"), imgui.ImVec2(-1, 30)) then
                    local report_text = get_session_report_text(session_stats.last_active_date)
                    sendTelegramMessage(report_text)
                    show_arz_notify('success', 'Отчет', 'Сводный чек-отчет отправлен в Telegram!', 3000)
                end
                imgui.PopStyleColor(3)

                imgui.Dummy(imgui.ImVec2(0, 5))

                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.95, 0.26, 0.26, 0.15))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.95, 0.26, 0.26, 0.3))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.95, 0.26, 0.26, 0.1))
                if imgui.Button(getIcon("TRASH", "") .. u8("Принудительно сбросить и начать новый день"), imgui.ImVec2(-1, 24)) then
                    session_stats.last_active_date = os.date("%d.%m.%Y")
                    session_stats.quests_completed = 0
                    session_stats.wages_accumulated = 0
                    session_stats.dep_growth = 0
                    session_stats.az_accumulated = 0
                    session_stats.time_in_game = 0
                    session_stats.report_sent = false
                    save_stats_to_file()
                    show_arz_notify('info', 'Сброс', 'Статистика дня успешно обнулена.', 3000)
                end
                imgui.PopStyleColor(3)

            end
            imgui.EndChild()

        -- 4. Футер
        imgui.Dummy(imgui.ImVec2(0, 1))
        imgui.SetCursorPosX(15)
        if imgui.Button(u8("Закрыть меню"), imgui.ImVec2(w_width - 30, 35)) then
            window[0] = false
        end

        imgui.End()
		end

    -- === ПОЛНОЭКРАННОЕ ОКНО ВЫБОРА СМАЙЛИКА ===
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
            if imgui.Button(u8("Назад / Отмена"), imgui.ImVec2(-1, 35)) then
                show_emoji_selector_modal[0] = false
            end
            imgui.End()
        end
        imgui.PopStyleVar()
        imgui.PopStyleColor() 
        
        imgui.End()
        imgui.PopStyleColor() 
    end

    -- === ВСПЛЫВАЮЩЕЕ ОКНО "ИНФОРМАЦИЯ ОБ ОБНОВЛЕНИИ" ===
    if show_update_popup[0] then
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(480, 330), imgui.Cond.Always)

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
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8(" --> "))
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
            imgui.BeginChild("##changelog", imgui.ImVec2(w_width - 30, 110), true)
                local safe_update_info = tostring(remote_update_info or "Нет информации")
                imgui.TextWrapped(u8(safe_update_info))
            imgui.EndChild()
            imgui.PopStyleColor()

            imgui.Dummy(imgui.ImVec2(0, 12))

            local btn_w = (w_width - 40) / 2

            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15, 0.45, 0.24, 1.00))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.55, 0.29, 1.00))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.12, 0.35, 0.19, 1.00))
            if imgui.Button(u8("Обновить сейчас"), imgui.ImVec2(btn_w, 35)) then
                downloadAndInstallUpdate()
            end
            imgui.PopStyleColor(3)

            imgui.SameLine()

            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.20, 0.26, 1.00))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.26, 0.33, 1.00))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.14, 0.15, 0.20, 1.00))
            if imgui.Button(u8("Напомнить позже"), imgui.ImVec2(btn_w, 35)) then
                show_update_popup[0] = false
                window[0] = true 
            end
            imgui.PopStyleColor(3)

            imgui.EndGroup()
            imgui.End()
        end
        imgui.PopStyleColor()
    end
end)

function samp.onServerMessage(color, text)
    if not text then return end

    -- 1. Логика Хранилища предметов (при условии, что storage[0] включен)
    if text:find("У Вас есть предметы в хранилище пункта выдачи") or text:find("%[Хранилище предметов%]") then
        if storage[0] then
            local storage_tag = ""
            if cfg.config.storageEmoji ~= "emoji_none" then
                storage_tag = "{" .. cfg.config.storageEmoji .. "} "
            end
            sendTelegramMessage(storage_tag .. text:gsub("{%x%x%x%x%x%x}", ""))
        end
        return 
    end

    -- 2. Логика добавления предметов (Инвентарь)
    if color == -65281 or text:find("Вам добавлен предмет") or text:find("добавлен предмет") then
        local itemId = text:match(":item(%d+):")
        if itemId then
            local name = getItemName(itemId)
            if not sendUnknownItems[0] and name:find("ID:") then return end
            
            -- ПРЕДМЕТЫ В СТАТИСТИКЕ СТЁРТЫ, ПРЯМАЯ ПЕРЕДАЧА СООБЩЕНИЯ В TELEGRAM РАБОТАЕТ В ДЕФОЛТНОМ РЕЖИМЕ
            if itemAdding[0] then
                local item_tag = ""
                if cfg.config.itemEmoji ~= "emoji_none" then
                    item_tag = "{" .. cfg.config.itemEmoji .. "} "
                end
                local pack_tag = " {emoji_backpack}"

                local message_to_send
                if shortMessage[0] then
                    message_to_send = text:gsub(":item%d+:", "'" .. name .. "'")
                    if message_to_send:sub(-1) == "." then message_to_send = message_to_send:sub(1, -2) end
                    message_to_send = message_to_send .. ", используйте клавишу 'Y' или /invent"
                else
                    message_to_send = (item_tag .. "Вам был добавлен предмет %s" .. pack_tag):format(name)
                end

                sendTelegramMessage(message_to_send)
            end
            return
        end
    end

    -- 3. Выбор места спавна
    if spawnSelect[0] and text:find("Вы выбрали местом спавна") then
        local spawn_tag = ""
        if cfg.config.spawnEmoji ~= "emoji_none" then
            spawn_tag = "{" .. cfg.config.spawnEmoji .. "} "
        end
        sendTelegramMessage(spawn_tag .. text:gsub("{%x%x%x%x%x%x}", ""))
    end
 
    -- 4. Квесты и Боевой Пропуск
    if text:find("^%[Боевой Пропуск%]") or text:find("выполнили задание") then
        local cleaned = text:gsub("{%x%x%x%x%x%x}", ""):gsub("^%s+", ""):gsub("%s+$", "")

        -- ЗАПИСЬ КВЕСТА В СТАТИСТИКУ И ЗАПИСЬ В ФАЙЛ
        session_stats.quests_completed = session_stats.quests_completed + 1
        save_stats_to_file()

        if quest[0] and cleaned:find("^%[Боевой Пропуск%]") then
            local body = cleaned:match("^%[Боевой Пропуск%]%s*(.*)") or ""
            local event_type = nil    
            local item_or_task_name = nil 

            local item_pickup = body:match("забрали предмет%s*-%s*'([^']+)'") or body:match("забрали%s*-%s*'([^']+)'")
            local task_complete = body:match("выполнили задание%s*-%s*'([^']+)'")
            
            if item_pickup then
                event_type = "Забрал предмет"
                item_or_task_name = item_pickup
            elseif task_complete then
                event_type = "Выполнил задание"
                item_or_task_name = task_complete
            end

            if event_type and item_or_task_name then
                local quest_tag = ""
                if cfg.config.questEmoji ~= "emoji_none" then
                    quest_tag = "{" .. cfg.config.questEmoji .. "} "
                end
                sendTelegramMessage(quest_tag .. "[Боевой Пропуск]\n" .. event_type .. ": " .. item_or_task_name)
            end
        end
    end
 
    -- 5. PayDay
    PayDayLineDetector = false
    if text:find('БАНКОВСКИЙ ЧЕК') or text:find('Банковский чек') then
        getPayday = true
        listPayday = {}
        paydayTimeout = os.time() + 5
        
        local h_tag = ""
        if cfg.config.paydayHeaderEmoji ~= "emoji_none" then
            local raw_h = "{" .. cfg.config.paydayHeaderEmoji .. "}"
            h_tag = raw_h
        end
        table.insert(listPayday, h_tag .. "PayDay | БАНКОВСКИЙ ЧЕК" .. h_tag)
        
    elseif getPayday then
        local cleanLine = text:gsub('{......}', '')
        
        local bank_tag = cfg.config.paydayBankEmoji ~= "emoji_none" and "{" .. cfg.config.paydayBankEmoji .. "}" or ""
        local dep_tag = cfg.config.paydayDepositEmoji ~= "emoji_none" and "{" .. cfg.config.paydayDepositEmoji .. "}" or ""
        local wage_tag = cfg.config.paydayWageEmoji ~= "emoji_none" and "{" .. cfg.config.paydayWageEmoji .. "}" or ""
        local az_tag = cfg.config.paydayAZEmoji ~= "emoji_none" and "{" .. cfg.config.paydayAZEmoji .. "}" or ""
        
        local keep = false
        if cleanLine:find('==========') or cleanLine:find('__________') then
            keep = true
        elseif cleanLine:find('Текущая сумма в банке:') then
            -- Пропускаем, так как "Прирост в банке" удален из вычислений
            cleanLine = cleanLine:gsub(':CASH:', bank_tag)
            keep = true
        elseif cleanLine:find('В данный момент у вас') and cleanLine:find('респектов') then
            keep = true
        elseif cleanLine:find('Текущая сумма на депозите:') then
            -- === КРИТИЧЕСКИЙ ФИКС: ВЫТЯГИВАЕМ ТОЛЬКО ПРИБАВКУ ДЕПОЗИТА ИЗ СКOБOК ===
            -- "Текущая сумма на депозите: $ 367.893.404 (+ $ 913.796)"
            local dep_text = cleanLine:match("депозите:.*%((.+)%)")
            local dep_val = 0
            if dep_text then
                dep_val = parse_numeric_value(dep_text)
            end
            
            session_stats.dep_growth = (session_stats.dep_growth or 0) + dep_val
            session_stats.last_payday_dep = dep_val

            cleanLine = cleanLine:gsub(':CASH:', dep_tag)
            keep = true
            PayDayLineDetector = true
        elseif cleanLine:find('Общая заработная плата:') then
            -- === НАКОПЛЕНИЕ ЗАРПЛАТЫ ===
            local wage_val = parse_numeric_value(cleanLine:match("плата:%s*(.*)"))
            session_stats.wages_accumulated = (session_stats.wages_accumulated or 0) + wage_val
            session_stats.last_payday_wage = wage_val

            cleanLine = cleanLine:gsub(':CASH:', wage_tag)
            keep = true
            PayDayLineDetector = true
        elseif cleanLine:find('Баланс на донат') then
            -- === КРИТИЧЕСКИЙ ФИКС: ВЫТЯГИВАЕМ ТОЛЬКО ПРИБАВКУ AZ ИЗ СКОБОК ===
            -- "Баланс на донат-счет: 86902 AZ (+12 AZ)"
            local az_text = cleanLine:match("донат.-%((.+)%)")
            local az_val = 0
            if az_text then
                az_val = parse_numeric_value(az_text)
            end
            
            session_stats.az_accumulated = (session_stats.az_accumulated or 0) + az_val
            session_stats.last_payday_az = az_val

            cleanLine = cleanLine:gsub('AZ', az_tag)
            keep = true
            PayDayLineDetector = true
        end
        
        if PayDayLineDetector then
            save_stats_to_file()
        end

        if keep then
            table.insert(listPayday, cleanLine)
            if (text:find('==========') or text:find('__________')) and #listPayday > 4 then
                if payday[0] then
                    sendTelegramMessage(table.concat(listPayday, '\n'))
                end
                getPayday = false 
            end
        end
    end

    if getPayday and os.time() > paydayTimeout then
        if #listPayday > 2 then
            if payday[0] then
                sendTelegramMessage(table.concat(listPayday, '\n'))
            end
        end
        getPayday = false 
    end
end
