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
local SCRIPT_VERSION = "0.0.4.2" -- Обновляем версию
local UPDATE_URL = "https://raw.githubusercontent.com/dmashmakov2000-coder/item11/main/Item.lua" -- URL для автообновления

local UPDATE_INFO = [[
0.0.4.2:
- Было добавлено новые предмеды из обновления 
- От 30 Января
]]

local CFG_FILENAME = 'Script [TM].ini'

-- Переменные для автообновления и информации
local remote_version_text = SCRIPT_VERSION
local update_available = false
local update_check_in_progress = false
local remote_update_info = "" 
local show_update_popup = imgui.new.bool(false) 

-- === БАЗА ПРЕДМЕТОВ ===

local items_name = {



		
[9774] = "Легендарный предмет: Нашивка Экономиста  (19300)",
[9790] = "Сертификат BMW M5 G90 2k26  (1307)",
[9788] = "Основной набор характеристик для скина  (19300)",
local default_config = {
    config = {
        chat = '',
        token = '',
        itemAdding = false,
        sendUnknownItems = false,
        shortMessage = false,
        itemCollectionDelay = 7.0, -- Значение по умолчанию
        payday = false,
        storage = false,
        spawnSelect = false,
        enableUINotifications = true,
        quest = true
    }
}

local cfg
local ok_cfg, err_cfg = pcall(inicfg.load, default_config, CFG_FILENAME)
if ok_cfg then cfg = err_cfg else cfg = default_config end

-- Инициализация переменных UI
local chat = imgui.new.char[128](tostring(cfg.config.chat))
local token = imgui.new.char[128](tostring(cfg.config.token))
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
local PAYDAY_TIMEOUT_DURATION = 10

local window = imgui.new.bool(false)
local currentTab = imgui.new.int(1) -- 1: Настройки, 2: Уведомления

local collectedItemNames = {}
local itemCollectionDelay = imgui.new.float(cfg.config.itemCollectionDelay)

-- === ПЕРЕМЕННЫЕ ДЛЯ НАДЕЖНОГО СБОРЩИКА ===
local lastItemReceiveTime = 0 -- Время (os.time()) последнего полученного предмета
local itemCollectorActive = false -- Флаг, что сборщик активен и ждет
-- =========================================

-- Определение effilTelegramSendMessage
local effilTelegramSendMessage = effil_ok and effil.thread(function(text, chatID, token)
    if not requests_ok then
        sampAddChatMessage('{FF0000}[TM] Ошибка: Библиотека "requests" не найдена для отправки Telegram.', 0xFFFFFF)
        print("[TM] Ошибка: Библиотека 'requests' не найдена для отправки Telegram.")
        return
    end
    local requests = require('requests')
    local ok, res = pcall(function()
        return requests.post(('https://api.telegram.org/bot%s/sendMessage'):format(token), {
            params = { text = text, chat_id = chatID }
        })
    end)
    if not ok then
        sampAddChatMessage('{FF0000}[TM] Ошибка отправки сообщения в Telegram: ' .. (res or 'Неизвестная ошибка'), 0xFFFFFF)
        print("[TM] Ошибка отправки сообщения в Telegram: " .. (res or 'Неизвестная ошибка'))
    end
end) or nil

function url_encode(text)
    local text = string.gsub(text, "([^%w-_ %.~=])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(text, " ", "+")
end

local function sendTelegramMessage(text)
    local chat_id_str, token_str = ffi.string(chat), ffi.string(token)
	    if chat_id_str == '' or token_str == '' then
        sampAddChatMessage('{FFFF00}[TM] Предупреждение: ID чата или токен Telegram не указаны.', 0xFFFFFF)
        return
    end
    if not effilTelegramSendMessage then
        sampAddChatMessage('{FF0000}[TM] Ошибка: Не удалось инициализировать effil Telegram поток.', 0xFFFFFF)
        return
    end
    local clean_text = text:gsub('{......}', '')
    effilTelegramSendMessage(url_encode(u8(clean_text)), chat_id_str, token_str)
end

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
            sampAddChatMessage("{ff0000}[TM] Ошибка при скачиваниифайла.", -1)
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

local function saveConfig()
    cfg.config.chat = ffi.string(chat)
    cfg.config.token = ffi.string(token)
    cfg.config.itemAdding = itemAdding[0]
    cfg.config.sendUnknownItems = sendUnknownItems[0]
    cfg.config.shortMessage = shortMessage[0]
    cfg.config.itemCollectionDelay = itemCollectionDelay[0]
    cfg.config.payday = payday[0]
    cfg.config.storage = storage[0]
    cfg.config.quest = quest[0]
    cfg.config.spawnSelect = spawnSelect[0]
    cfg.config.enableUINotifications = enableUINotifications[0]
    inicfg.save(cfg, CFG_FILENAME)
end

-- Функция для отправки накопленных предметов
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

-- === ОСНОВНОЙ ЦИКЛ СБОРЩИКА ПРЕДМЕТОВ (НАДЕЖНЫЙ МЕТОД) ===
local function itemCollectorLoop()
    while true do
        wait(100) -- Проверяем каждые 100 мс
        
        if itemAdding[0] and itemCollectorActive and #collectedItemNames > 0 then
            local delay = itemCollectionDelay[0] or 7.0
            
            -- Проверяем, прошло ли достаточно времени с момента последнего получения
            if os.time() - lastItemReceiveTime >= delay then
                sendCollectedItems()
                itemCollectorActive = false -- Сбрасываем флаг, пока не придет новый предмет
            end
        end
    end
end
-- =========================================================

function main()
    while not isSampAvailable() do wait(0) end
    for _, err in ipairs(load_errors) do sampAddChatMessage("{ff0000}[TM] " .. err, -1) end
    sampAddChatMessage('Script [TM] {ffffff}Активация командой: /tm', 0x3083ff)
    sampAddChatMessage('Script [TM] {ffffff}Разработан и написан Dima_Shmakov', 0x3083ff)
    sampAddChatMessage('Script [TM] {ffffff}Версия скрипта ' .. SCRIPT_VERSION, 0x3083ff)
    sampRegisterChatCommand('tm', function() window[0] = not window[0] end)
    
    -- Запускаем постоянный цикл сборщика
    lua_thread.create(itemCollectorLoop)
    
    checkUpdate()
    wait(-1)
end

-- Функция для показа уведомлений ARZ (если включены)
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
    white_style()
end)

function white_style()
    imgui.SwitchContext()
    local style = imgui.GetStyle()

    style.WindowRounding        = 7.0
    style.ChildRounding         = 7.0
    style.FrameRounding         = 10.0
    style.FramePadding          = imgui.ImVec2(5, 3)
    style.WindowPadding         = imgui.ImVec2(8, 8)
    style.ButtonTextAlign       = imgui.ImVec2(0.5, 0.5)
    style.GrabMinSize           = 7
    style.GrabRounding          = 15

    style.Colors[imgui.Col.WindowBg] = imgui.ImVec4(0.12, 0.12, 0.12, 0.94) -- фон
    style.Colors[imgui.Col.TitleBg] = imgui.ImVec4(0.10, 0.10, 0.10, 1.00)
    style.Colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.18, 0.18, 0.18, 1.00) -- название
    style.Colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.10, 0.10, 0.10, 0.75)
    style.Colors[imgui.Col.Text] = imgui.ImVec4(0.85, 0.85, 0.85, 1.00)
    style.Colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    style.Colors[imgui.Col.Border] = imgui.ImVec4(0.30, 0.30, 0.30, 0.50)

    style.Colors[imgui.Col.Button] = imgui.ImVec4(0.26, 0.26, 0.26, 0.40)
    style.Colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.40, 0.40, 0.40, 1.00)
    style.Colors[imgui.Col.FrameBg] = imgui.ImVec4(0.20, 0.20, 0.20, 0.54)
    style.Colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.25, 0.25, 0.25, 0.78)
    style.Colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)

    local accentColor = imgui.ImVec4(0.2, 0.6, 0.8, 1.0)
    style.Colors[imgui.Col.Header] = accentColor
    style.Colors[imgui.Col.HeaderHovered] = imgui.ImVec4(accentColor.x + 0.1, accentColor.y + 0.1, accentColor.z + 0.1, 1.0)
    style.Colors[imgui.Col.HeaderActive] = imgui.ImVec4(accentColor.x + 0.2, accentColor.y + 0.2, accentColor.z + 0.2, 1.0)
    style.Colors[imgui.Col.CheckMark] = accentColor
    style.Colors[imgui.Col.SliderGrab] = accentColor
    style.Colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(accentColor.x + 0.2, accentColor.y + 0.2, accentColor.z + 0.2, 1.0)
    style.Colors[imgui.Col.Separator] = imgui.ImVec4(0.40, 0.40, 0.40, 0.50)
    style.Colors[imgui.Col.SeparatorHovered] = imgui.ImVec4(0.60, 0.60, 0.60, 0.78)
    style.Colors[imgui.Col.SeparatorActive] = imgui.ImVec4(0.80, 0.80, 0.80, 1.00)

    style.WindowRounding = 6.0
    style.FrameRounding = 4.0
    style.PopupRounding = 4.0
	style.GrabRounding = 4.0
    style.TabRounding = 4.0

    style.WindowPadding = imgui.ImVec2(10, 10)
    style.FramePadding = imgui.ImVec2(6, 4)
    style.ItemSpacing = imgui.ImVec2(8, 4)
    style.ItemInnerSpacing = imgui.ImVec2(4, 4)
    style.IndentSpacing = 20.0
    style.ScrollbarSize = 10.0
    style.ScrollbarRounding = 9.0

    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
end

imgui.OnFrame(function() return window[0] or show_update_popup[0] end, function(player)
    local resX, resY = getScreenResolution()

    -- === ГЛАВНОЕ ОКНО ===
    if window[0] then
        local sizeX, sizeY = 320, 380
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)

imgui.Begin('Script [TM] ' .. SCRIPT_VERSION, nil, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)


        -- Tabs
        if imgui.Button(u8('Настройки')) then currentTab[0] = 1 end
        imgui.SameLine()
        if imgui.Button(u8('Уведомления')) then currentTab[0] = 2 end

        imgui.Separator()

        -- Область прокрутки для контента
        imgui.BeginChild("##content_scroll", imgui.ImVec2(imgui.GetWindowWidth() - 20, imgui.GetWindowHeight() - 110), false)

        if currentTab[0] == 1 then -- Настройки
            imgui.Text(u8('Telegram:'))
            imgui.InputText(u8('ИД Чата'), chat, ffi.sizeof(chat), imgui.InputTextFlags.Password)
            imgui.InputText(u8('Токен'), token, ffi.sizeof(token), imgui.InputTextFlags.Password)
            if imgui.Button(u8('Сохранить'), imgui.ImVec2(130, 25)) then
                saveConfig()
                show_arz_notify('success', 'Настройки', 'Данные Telegram успешно сохранены!', 5000)
            end
            imgui.SameLine()
            if imgui.Button(u8('Тест'), imgui.ImVec2(130, 25)) then
                sendTelegramMessage("Тестовое сообщение от Script [TM]!")
                show_arz_notify('success', 'Тестовое сообщение', 'Тестовое сообщение отправлено', 5000)
            end
            imgui.Separator()
            imgui.Text(u8('Автообновление:'))
            imgui.Text(u8('Текущая версия: ') .. SCRIPT_VERSION)
            if update_available then
                imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0, 1, 0, 1))
                imgui.Text(u8('Доступна версия: ') .. remote_version_text)
                imgui.PopStyleColor()

                -- КНОПКА ОТКРЫВАЮЩАЯ ВСПЛЫВАЮЩЕЕ ОКНО
                if imgui.Button(u8('Информация об обновлении'), imgui.ImVec2(-1, 25)) then
                    show_update_popup[0] = true -- <--- ОТКРЫВАЕМ НОВОЕ ОКНО
                end

                if imgui.Button(u8('Обновить скрипт'), imgui.ImVec2(-1, 25)) then downloadAndInstallUpdate() end
            else
                imgui.Text(u8('Версия актуальна.'))
                if imgui.Button(u8('Проверить обновления'), imgui.ImVec2(-1, 25)) then checkUpdate() end
            end

        elseif currentTab[0] == 2 then -- Уведомления
            -- Галочка для визуальных уведомлений
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

            -- Оповещение о предметах
            if imgui.Checkbox(u8('Оповещение о предметах'), itemAdding) then 
                saveConfig() 
                local state = itemAdding[0] and "активировано" or "деактивировано"
                show_arz_notify('info', 'Предметы', 'Отслеживание предметов ' .. state, 3000)
            end
      
            if itemAdding[0] then
                imgui.Indent(20)
                -- Неизвестные предметы
                if imgui.Checkbox(u8('Отправлять неизвестные предметы'), sendUnknownItems) then 
                    saveConfig() 
                    local state = sendUnknownItems[0] and "будут отправляться" or "скрыты"
                    show_arz_notify('info', 'Настройка', 'Неизвестные предметы ' .. state, 3000)
                end

                -- Короткие сообщения
                if imgui.Checkbox(u8('Короткие сообщения (только название)'), shortMessage) then
                    saveConfig()
                    if shortMessage[0] then
                        show_arz_notify('info', 'Режим сообщений', 'Включен компактный режим отправки', 3000)
                    else
                        show_arz_notify('info', 'Режим сообщений', 'Включен полный режим (с текстом из чата)', 3000)
                    end
                end

                -- Слайдер задержки (1 до 30 секунд) - ВИДЕН ТОЛЬКО ПРИ ВКЛЮЧЕННЫХ КОРОТКИХ СООБЩЕНИЯХ
                if shortMessage[0] then
                    imgui.Text(u8('Задержка отправки (сек)'))
                    if imgui.SliderFloat('##itemCollectionDelay', itemCollectionDelay, 0.0, 30.0, '%.1f') then
                        -- При движении ползунка ничего не делаем
                    end
                    
                    -- УВЕДОМЛЕНИЕ ПРИ ОТПУСКАНИИ ПОЛЗУНКА
                    if imgui.IsItemDeactivatedAfterEdit() then 
                        saveConfig()
                        show_arz_notify('info', 'Настройка', ('Задержка установлена: %.1f сек.'):format(itemCollectionDelay[0]), 3000)
                    end
                end

                imgui.Unindent(20)
            end

            -- PayDay
            if imgui.Checkbox(u8('PayDay'), payday) then
                saveConfig()
                local state = payday[0] and "включены" or "выключены"
                show_arz_notify('info', 'PayDay', 'Уведомления PayDay ' .. state, 3000)
            end

            -- Хранилище
            if imgui.Checkbox(u8('Хранилище'), storage) then
                saveConfig()
                local state = storage[0] and "включены" or "выключены"
                show_arz_notify('info', 'Хранилище', 'Уведомления о хранилище ' .. state, 3000)
            end
		    if imgui.Checkbox(u8('квесты/задания'), quest) then
                saveConfig()
                local state = quest[0] and "включены" or "выключены"
                show_arz_notify('info', 'квесты/задания', 'Уведомления о хранилище ' .. state, 3000)
            end
      
            -- Выбор места спавна
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

        -- Кнопка "Закрыть" снизу по центру
        local b_width, b_height = 120, 30
        imgui.SetCursorPos(imgui.ImVec2((imgui.GetWindowWidth() - b_width) * 0.5, imgui.GetWindowHeight() - b_height - 10))
        if imgui.Button(u8('Закрыть'), imgui.ImVec2(b_width, b_height)) then
            window[0] = false
        end

        imgui.End()
    end -- end if window[0]

    -- === ВСПЛЫВАЮЩЕЕ ОКНО "ИНФОРМАЦИЯ ОБ ОБНОВЛЕНИИ" ===
    if show_update_popup[0] then
    imgui.SetNextWindowPos(imgui.ImVec2(resX/2, resY/2), imgui.Cond.Appearing, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(400, 280), imgui.Cond.Appearing)

    -- ВТОРОЙ АРГУМЕНТ = nil (чтобы убрать крестик), НО НЕ NoTitleBar (чтобы заголовок остался)
    imgui.Begin(u8('Информация об обновлении'), nil,
        imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)

    imgui.Text(u8('Новая версия: ') .. remote_version_text)
    imgui.Separator()
    imgui.TextWrapped(u8(remote_update_info))
    imgui.Dummy(imgui.ImVec2(0, 8))

    local b_width, b_height = 120, 25
    local padding_bottom = 10
    local btn_pos_x = (imgui.GetWindowWidth() - b_width) * 0.5
    local btn_pos_y = imgui.GetWindowHeight() - b_height - padding_bottom
    imgui.SetCursorPos(imgui.ImVec2(btn_pos_x, btn_pos_y))

    if imgui.Button(u8('Закрыть'), imgui.ImVec2(b_width, b_height)) then
        show_update_popup[0] = false
    end

    imgui.End()
end -- end if show_update_popup[0]

end)


function samp.onServerMessage(color, text)
    -- === Игнорируем сообщение о пункте выдачи хранилища ===
    if text:find("[Хранилище предметов] У Вас есть предметы в хранилище пункта выдачи.") then
        return -- Прерываем выполнение функции, игнорируя это сообщение
    end

    -- === Оповещение о предметах (СБОРЩИК) ===
    if itemAdding[0] then
        local itemId = tonumber(text:match(":item(%d+):"))
        if itemId and color == -65281 then -- Цвет для сообщений о получении предметов (обычно розовый)
            local itemName = items_name[itemId]
            if not itemName and not sendUnknownItems[0] then return end

            local nameToDisplay = itemName or ("ID: " .. itemId)
            local message_to_send

            if shortMessage[0] then
                -- Для коротких сообщений отправляем только название предмета
                message_to_send = nameToDisplay
            else
                -- Для полных сообщений, заменяем ":item<ID>:" на название
                message_to_send = text:gsub(":item%d+:", nameToDisplay)
            end

            table.insert(collectedItemNames, message_to_send)
            
            -- === ЛОГИКА СБРОСА ТАЙМЕРА ===
            lastItemReceiveTime = os.time() -- Сбрасываем время
            itemCollectorActive = true      -- Активируем сборщик
            -- ==============================
            
            return -- Прерываем, чтобы не попасть в логику PayDay/Storage, если это сообщение о предмете
        end
    end
    
    -- === Выбор места спавна ===
    if spawnSelect[0] and text:find("Вы выбрали местом спавна") then
        sendTelegramMessage(text)
    end
	
        -- НОВОЕ: === Боевой Пропуск ===
-- === Боевой Пропуск (точная фильтрация и красивый вывод) ===
if quest[0] then
    -- Очищаем от цветовых кодов вида {RRGGBB}
    local cleaned = text:gsub("{%x%x%x%x%x%x}", "")
    -- Убираем начальные/конечные пробелы
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")

    -- Проверяем, что сообщение начинается именно с "[Боевой Пропуск]"
    if cleaned:find("^%[Боевой Пропуск%]") then
        -- Получаем часть сообщения после префикса "[Боевой Пропуск]"
        local body = cleaned:match("^%[Боевой Пропуск%]%s*(.*)") or ""

        local event_type = nil    -- Например: "забрал" или "выполнил задание"
        local item_or_task_name = nil -- Название предмета или задания
        local final_message_part = "" -- Часть сообщения после типа события

        -- Шаблон 1: "Вы успешно забрали предмет - 'НАЗВАНИЕ'"
        local item_pickup_match = body:match("^Вы%s+успешно%s+забрали%s+предмет%s*%-%s*'([^']+)'")
        if item_pickup_match then
            event_type = "забрал"
            item_or_task_name = item_pickup_match
            final_message_part = "Предмет " .. item_or_task_name
        end

        -- Шаблон 2: "Вы успешно забрали - 'НАЗВАНИЕ'" (для опыта или валюты)
        if not item_or_task_name then -- Проверяем, если предыдущий шаблон не сработал
            local xp_pickup_match = body:match("^Вы%s+успешно%s+забрали%s*%-%s*'([^']+)'")
            if xp_pickup_match then
                event_type = "забрал"
                item_or_task_name = xp_pickup_match
                final_message_part = "Предмет " .. item_or_task_name
            end
        end

        -- Шаблон 3: "Вы успешно выполнили задание - 'НАЗВАНИЕ'"
        if not item_or_task_name then -- Проверяем, если предыдущие шаблоны не сработали
            local task_complete_match = body:match("^Вы%s+успешно%s+выполнили%s+задание%s*%-%s*'([^']+)'")
            if task_complete_match then
                event_type = "выполнил задание"
                item_or_task_name = task_complete_match
                final_message_part = item_or_task_name -- Здесь не добавляем "Предмет"
            end
        end

        -- Если мы нашли совпадение по одному из шаблонов, формируем и отправляем сообщение
        if event_type and item_or_task_name then
            local telegram_message = "[Боевой Пропуск]\n" .. event_type .. "\n" .. final_message_part
            sendTelegramMessage(telegram_message)
        end
        -- Если ни один шаблон не совпал, это другое сообщение Боевого Пропуска, и мы его игнорируем.
    end
end


	
	
    -- === Хранилище предметов ===
    if storage[0] then
        if text:find("Добавлен новый предмет") or text:find("Вы забрали предмет") then
            -- Сообщение о пункте выдачи уже игнорируется в начале функции
            sendTelegramMessage(text)
        end
    end

    -- === PayDay ===
    if payday[0] then
        -- Отлавливаем начало блока PayDay
        if color and text:find('Банковский чек') then
            getPayday = true
            listPayday = {}
            paydayTimeout = os.time() + PAYDAY_TIMEOUT_DURATION
            table.insert(listPayday, text)
        elseif getPayday then
            -- Собираем строки PayDay
            table.insert(listPayday, text)
        end

        -- Отлавливаем конец блока PayDay (обычно линия из подчеркиваний)
        if color and text:find('__________________________________________________________________________') then
            if getPayday then
                sendTelegramMessage(table.concat(listPayday, '\n'))
            end
			getPayday = false -- Сбрасываем флаг
        -- Если тайм-аут истек, а блок PayDay не закончился, отправляем то, что успели собрать
        elseif getPayday and os.time() > paydayTimeout then
            sampAddChatMessage("{FF0000}[TM] Таймаут Payday, отправка неполных данных.", 0xFFFFFF)
            sendTelegramMessage(table.concat(listPayday, '\n'))
            getPayday = false -- Сбрасываем флаг
        end
    end

end
