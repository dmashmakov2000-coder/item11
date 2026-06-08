--[[
    Script [TM]
    Разработал: Dima_Shmakov
    Версия с всплывающим окном информации об обновлении.
]]

script_properties('work-in-pause')

-- Проверка и загрузка критически важных библиотек
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
local ffi = require('ffi')
local imgui = require('mimgui')
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Проверка effil и requests
local effil_ok, effil = check_lib('effil')
local requests_ok, requests_lib = check_lib('requests')

-- === КОНФИГУРАЦИЯ СКРИПТА ===
local SCRIPT_VERSION = "0.0.6.0" -- Обновляем версию до 0.0.4.4 после исправлений
local UPDATE_URL = "https://raw.githubusercontent.com/dmashmakov2000-coder/item11/main/Item.lua" -- URL для автообновления
local CFG_FILENAME = 'Script [TM].ini'

-- Личная ссылка Cloudflare Worker
local ANTIBLOCK_URL = "https://tg.bakh.us"
local DEFAULT_API = "https://api.telegram.org"

-- Информация об обновлениях (для всплывающего окна)
local UPDATE_INFO = [[
0.0.6.0:
- Исправлен PayDay
- Заменина полностью система под новый дизайн

- Планы на будущее 
- Заменить :CASH: на стикеры 

]]

-- === БАЗА ПРЕДМЕТОВ ===
-- Эту таблицу нужно заполнить или убедиться, что она существует
-- (если ее нет, скрипт не упадет, но предметы будут отображаться как "ID: <номер>")
-- === БАЗА ПРЕДМЕТОВ ===


	

-- === КОНФИГУРАЦИЯ ПО УМОЛЧАНИЮ ===
-- (фрагмент default_config — убрана itemCollectionDelay)
local default_config = {
    config = {
        chat = '',
        token = '',
        useAntiBlock = true, -- Галочка по умолчанию включена
        itemAdding = false,
        sendUnknownItems = false,
        shortMessage = false, 
        payday = false,
        storage = false,
        spawnSelect = false,
        enableUINotifications = true,
        quest = true
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
    print(('[TM] Error loading config or config file not found. Using default. Error: %s'):format(err_cfg or 'N/A'))
end


-- === ИНИЦИАЛИЗАЦИЯ ПЕРЕМЕННЫХ UI ===
local chat = imgui.new.char[128](tostring(cfg.config.chat))
local token = imgui.new.char[128](tostring(cfg.config.token))
local useAntiBlock = imgui.new.bool(cfg.config.useAntiBlock or true)

local itemAdding = imgui.new.bool(cfg.config.itemAdding)
local sendUnknownItems = imgui.new.bool(cfg.config.sendUnknownItems)
local shortMessage = imgui.new.bool(cfg.config.shortMessage) -- true = отправлять старый вид сообщений (полный)
local payday = imgui.new.bool(cfg.config.payday)
local storage = imgui.new.bool(cfg.config.storage)
local spawnSelect = imgui.new.bool(cfg.config.spawnSelect)
local quest = imgui.new.bool(cfg.config.quest)
local enableUINotifications = imgui.new.bool(cfg.config.enableUINotifications)

local getPayday = false
local listPayday = {}
local paydayTimeout = 0
local PAYDAY_TIMEOUT_DURATION = 10

local window = imgui.new.bool(false)
local currentTab = imgui.new.int(1) -- 1: Настройки, 2: Уведомления

local collectedItemNames = {}
local itemCollectionDelay = imgui.new.float(cfg.config.itemCollectionDelay)

-- === ПЕРЕМЕННЫЕ ДЛЯ НАДЕЖНОГО СБОРЩИКА ===
local lastItemReceiveTime = 0 
local itemCollectorActive = false 
-- =========================================
-- === ОПРЕДЕЛЕНИЕ effilTelegramSendMessage ===
local effilTelegramSendMessage = effil_ok and effil.thread(function(text, chatID, token, baseUrl)
    local requests = require('requests')
    -- Библиотека requests сама закодирует 'text' и 'chat_id'
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
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

function urlencode(str)
   if str then
      -- Сначала переводим из кодировки SAMP (CP1251) в UTF-8
      local utf8_str = u8:encode(str, 'CP1251')
      
      -- Список поддерживаемых смайликов (добавляются в виде UTF-8 байт-кодов)
      utf8_str = utf8_str:gsub("{emoji_wave}", "\xf0\x9f\x91\x8b")    -- ?? (Машет рукой)
      utf8_str = utf8_str:gsub("{emoji_check}", "\xe2\x9c\x85")   -- ? (Галочка)
      utf8_str = utf8_str:gsub("{emoji_bell}", "\xf0\x9f\x94\x94")    -- ?? (Колокольчик)
      utf8_str = utf8_str:gsub("{emoji_rocket}", "\xf0\x9f\x9a\x80")  -- ?? (Ракета)
      utf8_str = utf8_str:gsub("{emoji_warn}", "\xe2\x9a\xa0\xef\xb8\x8f") -- ?? (Предупреждение)
      utf8_str = utf8_str:gsub("{emoji_pay}", "\xf0\x9f\x92\xb5")     -- ?? (Доллары)

      -- Экранируем символы для URL
      utf8_str = utf8_str:gsub("([^%w _%%%-%.~])", function(c) 
         return string.format("%%%02X", string.byte(c)) 
      end)
      -- Заменяем пробелы на %20 (вместо плюсиков, так надежнее)
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
    
    -- Определяем базовый URL
    local baseUrl = useAntiBlock[0] and ANTIBLOCK_URL or "https://api.telegram.org"
    
    -- Очищаем текст от SAMP-цветов типа {FFFFFF}
    local clean_text = text:gsub('{......}', '')
    
    -- Кодируем текст (через стандартную функцию urlencode)
    local encoded_text = urlencode(clean_text)
    
    -- === КОРРЕКТНЫЙ И НАДЕЖНЫЙ ПЕРЕВОД СМАЙЛИКОВ ===
    -- Заменяем текстовые теги прямо в закодированной строке на UTF-8 коды смайликов
    encoded_text = encoded_text:gsub("%%5Bwave%%5D", "%%F0%%9F%%91%%8B")     -- [wave]   -> ?? (Машет рукой)
    encoded_text = encoded_text:gsub("%%5Bcheck%%5D", "%%E2%%9C%%85")    -- [check]  -> ? (Галочка)
    encoded_text = encoded_text:gsub("%%5Bbell%%5D", "%%F0%%9F%%94%%94")     -- [bell]   -> ?? (Колокольчик)
    encoded_text = encoded_text:gsub("%%5Brocket%%5D", "%%F0%%9F%%9A%%80")   -- [rocket] -> ?? (Ракета)
    encoded_text = encoded_text:gsub("%%5Bwarn%%5D", "%%E2%%9A%%A0%%EF%%B8%%8F") -- [warn] -> ?? (Внимание)
    encoded_text = encoded_text:gsub("%%5Bmoney%%5D", "%%F0%%9F%%92%%B5")   -- [money]  -> ?? (Пачка денег)
    encoded_text = encoded_text:gsub("%%5Bbox%%5D", "%%F0%%9F%%93%%A6")     -- [box]    -> ?? (Коробка/Предмет)
    
    -- Отправляем в поток effil
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
    cfg.config.shortMessage = shortMessage[0] -- сохранить новое состояние (старый/новый вид)
    cfg.config.payday = payday[0]
    cfg.config.storage = storage[0]
    cfg.config.quest = quest[0]
    cfg.config.spawnSelect = spawnSelect[0]
    cfg.config.enableUINotifications = enableUINotifications[0]

    local ok, err = pcall(inicfg.save, cfg, CFG_FILENAME)
    if not ok then
        print(('[TM] Error saving config: %s'):format(err))
        sampAddChatMessage(("{FF0000}[TM] Ошибка сохранения конфига: %s"):format(err or 'Неизвестно'), -1)
    end
end


-- === ФУНКЦИЯ ОТПРАВКИ СОБРАННЫХ ПРЕДМЕТОВ ===
local function sendCollectedItems()
    if #collectedItemNames > 0 then
        local message_parts = {}

        if shortMessage[0] then
            table.insert(message_parts, "Вам был добавлен предмет")
        else
            table.insert(message_parts, "Вы получили следующие предметы:")
        end

        for _, item_name in ipairs(collectedItemNames) do
            table.insert(message_parts, item_name)
        end

        local message = table.concat(message_parts, "\n")
        sendTelegramMessage(message)

        collectedItemNames = {}
    end
end

-- === ОСНОВНОЙ ЦИКЛ СБОРЩИКА ПРЕДМЕТОВ ===
local function itemCollectorLoop()
    while true do
        wait(100) 
        if itemAdding[0] and itemCollectorActive and #collectedItemNames > 0 then
            local delay = itemCollectionDelay[0] or 7.0
            if os.time() - lastItemReceiveTime >= delay then
                sendCollectedItems()
                itemCollectorActive = false 
            end
        end
    end
end
-- =========================================

function main()
    while not isSampAvailable() do wait(0) end
    for _, err in ipairs(load_errors) do sampAddChatMessage("{ff0000}[TM] " .. err, -1) end
    sampAddChatMessage('Script [TM] {ffffff}Активация командой: /tm', 0x3083ff)
    sampAddChatMessage('Script [TM] {ffffff}Разработан и написан Dima_Shmakov', 0x3083ff)
    sampAddChatMessage('Script [TM] {ffffff}Версия скрипта ' .. SCRIPT_VERSION, 0x3083ff)
        sampRegisterChatCommand('tm', function() 
        if update_available then
            -- Если есть обновление, показываем только окно обновления
            show_update_popup[0] = true
            window[0] = false 
        else
            -- Если обновлений нет, просто открываем/закрываем настройки
            window[0] = not window[0] 
        end
    end)
    -- lua_thread.create(itemCollectorLoop) -- удалено, буферизация предметов не используется
    checkUpdate()
    wait(-1) -- Скрипт остается активным
end


-- === ФУНКЦИЯ ДЛЯ UI УВЕДОМЛЕНИЙ ARZ ===
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
    modern_style() -- Вызываем новый стиль, который мы добавили.
end)
	

function modern_style()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors

    style.WindowRounding = 12.0     -- Было 10
    style.ChildRounding = 10.0      -- Было 8
    style.FrameRounding = 8.0       -- Было 6
    style.PopupRounding = 10.0
    style.ScrollbarRounding = 12.0  -- Скроллбар тоже будет круглым, если появится
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


imgui.OnFrame(function() return window[0] or show_update_popup[0] end, function(player)
    local resX, resY = getScreenResolution()

    -- === ГЛАВНОЕ ОКНО ===
    if window[0] then
        local sizeX, sizeY = 400, 480 
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('##MainSettings', window, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar)
        local w_width = imgui.GetWindowWidth()
        
        -- 1. Кастомная шапка
        imgui.BeginChild("##header_main", imgui.ImVec2(w_width - 30, 40), true)
            local header_text = "Script [TM] " .. u8("")
            imgui.SetCursorPosY(10)
            imgui.SetCursorPosX((w_width - 30 - imgui.CalcTextSize(header_text).x) / 2)
            imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), header_text)
        imgui.EndChild()
        imgui.Dummy(imgui.ImVec2(0, 10))
        -- 2. Переключатель Табов (БЕЗОПАСНЫЙ)
        local tab_btn_w = (w_width - 35) / 2
        -- Фикс краша: сохраняем состояния во временные переменные
        local is_tab1_active = (currentTab[0] == 1)
        local is_tab2_active = (currentTab[0] == 2)
        -- Таб 1 (Настройки)
        if is_tab1_active then 
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.3)) 
        end
        if imgui.Button(u8('Настройки'), imgui.ImVec2(tab_btn_w, 30)) then 
            currentTab[0] = 1 
        end
        if is_tab1_active then 
            imgui.PopStyleColor() 
        end
        
        imgui.SameLine(nil, 5)
        
        -- Таб 2 (Уведомления)
        if is_tab2_active then 
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.80, 0.44, 0.3)) 
        end
        if imgui.Button(u8('Уведомления'), imgui.ImVec2(tab_btn_w, 30)) then 
            currentTab[0] = 2 
        end
        if is_tab2_active then 
            imgui.PopStyleColor() 
        end

        imgui.Dummy(imgui.ImVec2(0, 10))

        -- 3. Основной контент
        imgui.BeginChild("##main_content", imgui.ImVec2(w_width - 30, sizeY - 160), true)
            
            if currentTab[0] == 1 then -- ВКЛАДКА НАСТРОЙКИ
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8("• Telegram Настройки"))
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


            elseif currentTab[0] == 2 then -- ВКЛАДКА УВЕДОМЛЕНИЯ
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), u8("• Управление уведомлениями"))
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
end

        imgui.EndChild()

        -- 4. Футер
        imgui.Dummy(imgui.ImVec2(0, 5))
        imgui.SetCursorPosX(15)
        if imgui.Button(u8("Закрыть меню"), imgui.ImVec2(w_width - 30, 35)) then
            window[0] = false
        end

        imgui.End()
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

            -- Шапка "Доступно обновление"
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.14, 0.17, 0.23, 1.00))
            imgui.BeginChild("##header", imgui.ImVec2(w_width - 30, 40), true)
                local header_text = u8("Доступно обновление")
                imgui.SetCursorPosY(10)
                imgui.SetCursorPosX((w_width - 30 - imgui.CalcTextSize(header_text).x) / 2)
                imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), header_text)
            imgui.EndChild()
            imgui.PopStyleColor()

            imgui.Dummy(imgui.ImVec2(0, 10))

            -- Версии
            local safe_remote_ver = tostring(remote_version_text or "0.0.0")
            local ver_text = u8("Текущая ") .. SCRIPT_VERSION .. u8("Новая ") .. safe_remote_ver
            imgui.SetCursorPosX((w_width - 30 - imgui.CalcTextSize(ver_text).x) / 2)
            imgui.TextColored(imgui.ImVec4(0.60, 0.65, 0.73, 1.00), u8("Текущая "))
            imgui.SameLine()
            imgui.Text(SCRIPT_VERSION)
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(0.95, 0.76, 0.18, 1.00), " -->  ")
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(0.60, 0.65, 0.73, 1.00), u8("Новая "))
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(0.18, 0.80, 0.44, 1.00), safe_remote_ver)

            imgui.Dummy(imgui.ImVec2(0, 10))

            -- Лог изменений
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

            -- Кнопки
            local btn_w = (w_width - 40) / 2

            -- Кнопка "Обновить"
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15, 0.45, 0.24, 1.00))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.55, 0.29, 1.00))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.12, 0.35, 0.19, 1.00))
            if imgui.Button(u8("Обновить сейчас"), imgui.ImVec2(btn_w, 35)) then
                downloadAndInstallUpdate()
            end
            imgui.PopStyleColor(3)

            imgui.SameLine()

            -- Кнопка "Напомнить позже"
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
    items_name = items_name or {}

    -- 1. Игнорирование сообщений хранилища
    if text:find("[Хранилище предметов] У Вас есть предметы в хранилище пункта выдачи.") then
        return 
    end

    -- 2. Логика добавления предметов
    if itemAdding[0] then
        local itemId = tonumber(text:match(":item(%d+):"))
        if itemId and color == -65281 then
            local known_name = items_name[itemId]
            
            if not sendUnknownItems[0] and not known_name then
                return
            end

            local itemName = known_name or ("ID: " .. itemId)
            local message_to_send

            if shortMessage[0] then
                message_to_send = text:gsub(":item%d+:", "'" .. itemName .. "'")
                if message_to_send:sub(-1) == "." then
                    message_to_send = message_to_send:sub(1, -2)
                end
                message_to_send = message_to_send .. ", используйте клавишу 'Y' или /invent"
            else
                message_to_send = ("Вам был добавлен предмет %s ."):format(itemName)
            end

            sendTelegramMessage(message_to_send)
            return
        end
    end

    -- 3. Выбор места спавна
    if spawnSelect[0] and text:find("Вы выбрали местом спавна") then
        sendTelegramMessage(text)
    end
 
    -- 4. Квесты и Боевой Пропуск
    if quest[0] then
        local cleaned = text:gsub("{%x%x%x%x%x%x}", "")
        cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")

        if cleaned:find("^%[Боевой Пропуск%]") then
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
                sendTelegramMessage("[Боевой Пропуск]\n" .. event_type .. ": " .. item_or_task_name)
            end
        end
    end
 
    -- 5. PayDay (ПОЛНОСТЬЮ БЕЗОПАСНЫЙ И БЕЗ КРАШЕЙ)
    if payday[0] then
        -- 1. Ищем начало чека
        if text:find('БАНКОВСКИЙ ЧЕК') or text:find('Банковский чек') then
            getPayday = true
            listPayday = {}
            paydayTimeout = os.time() + 5
            
            -- Вместо кодов пишем просто текст, чтобы не было "???"
            table.insert(listPayday, "PayDay | БАНКОВСКИЙ ЧЕК")
            
        elseif getPayday then
            -- 2. Очищаем строку от мусора
            local cleanLine = text:gsub('{......}', '') -- Удаляем цвета
            cleanLine = cleanLine:gsub('?', '$'):gsub('?', 'bc') -- Меняем иконки на текст
            
            -- Добавляем строку в таблицу
            table.insert(listPayday, cleanLine)
            
            -- 3. Условие завершения:
            -- Должна быть линия ==== И в таблице должно быть уже больше 4 строк 
            -- (чтобы не закрылось на самой первой линии)
            if (text:find('==========') or text:find('__________')) and #listPayday > 4 then
                sendTelegramMessage(table.concat(listPayday, '\n'))
                getPayday = false 
            end
        end

        -- Защита: если за 5 секунд чек не собрался полностью, отправляем что есть
        if getPayday and os.time() > paydayTimeout then
            if #listPayday > 2 then
                sendTelegramMessage(table.concat(listPayday, '\n'))
            end
            getPayday = false 
        end
    end
end