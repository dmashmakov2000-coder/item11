script_properties('work-in-pause')

local samp = require('samp.events')
local effil = require('effil')
local inicfg = require('inicfg')
local ffi = require('ffi')
local imgui = require('mimgui')
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local SCRIPT_VERSION = "0.0.4" 
local UPDATE_URL = "https://raw.githubusercontent.com/dmashmakov2000-coder/item11/main/Item.lua"

local SCRIPT_CONFIG_NAME = 'Item'
local SCRIPT_CONFIG_FILENAME = SCRIPT_CONFIG_NAME .. '.ini'

-- Ñïèñîê ïðåäìåòîâ (ID)
local items = {
    1811, 555, 1425, 522, 4344, 5991, 1146, 731, 730, 673, 9726, 9697, 556, 557,
    7480, 4794, 1769, 1639, 1638, 1637
}

-- Ñïèñîê íàçâàíèé
local items_name = {
    [1811] = "Bitcoin (BTC)",
    [555] = "Áðîíçîâàÿ ðóëåòêà",
    [1425] = "Ïëàòèíîâàÿ ðóëåòêà",
    [522] = "Ñåìåéíûé òàëîí",
    [4344] = "Òàëîí +1 EXP ",
    [5991] = "Ãðóíò",
    [1146] = "Ãðàæäàíñêèé òàëîí",
    [731] = "Àz-Coins",
    [730] = "Àz-Coins",
    [673] = "Òàëîí EXP",
    [9726] = "Ëîòåðåéíûé áèëåò 2ê26",
    [9697] = "Ìîíåòà Íîâîãî ãîäà (2026)",
    [556] = "Ñåðåáðÿíàÿ ðóëåòêà",
    [557] = "Çîëîòàÿ ðóëåòêà",
    [7480] = "Ëàðåö Fortnite",
    [4794] = "Ëàðåö Êëàäîèñêàòåëÿ",
    [1769] = "Ñóïåð Ìîòî-ÿùèê",
    [1639] = "Rare box Blue",
    [1638] = "Rare box Red",
    [1637] = "Rare box Yellow",
}

local function tableIncludes(self, value)
    for _, v in pairs(self) do if v == value then return true end end
    return false
end

local cfg = inicfg.load({
    config = { chat = '', token = '', itemAdding = false }
}, SCRIPT_CONFIG_NAME)

local chat = imgui.new.char[128](tostring(cfg.config.chat))
local token = imgui.new.char[128](tostring(cfg.config.token))
local itemAdding = imgui.new.bool(cfg.config.itemAdding)
local window = imgui.new.bool(false)
local activeTab = imgui.new.int(1) -- 1: Íàñòðîéêè, 2: Óâåäîìëåíèÿ, 3: Áóäóùåå

-- Ïîòîê Telegram
local effilTelegramSendMessage = effil.thread(function(text, chatID, token)
    local requests = require('requests')
    pcall(function()
        requests.post(('https://api.telegram.org/bot%s/sendMessage'):format(token), {
            params = { text = text, chat_id = chatID }
        })
    end)
end)

function url_encode(text)
    local text = string.gsub(text, "([^%w-_ %.~=])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return string.gsub(text, " ", "+")
end

function sendTelegramMessage(text)
    local chat_id_str = ffi.string(chat)
    local token_str = ffi.string(token)
    if chat_id_str == '' or token_str == '' then return end
    -- Èñïîëüçóåì u8:encode ÷òîáû ãàðàíòèðîâàòü UTF-8 äëÿ Telegram
    effilTelegramSendMessage(url_encode(u8:encode(text)), chat_id_str, token_str)
end

function main()
    while not isSampAvailable() do wait(0) end
    sampAddChatMessage('{3083ff}[ItemLog] {ffffff}Àêòèâàöèÿ: /item', -1)
    
    sampRegisterChatCommand('item', function() window[0] = not window[0] end)
    sampRegisterChatCommand('itemupdate', function() checkUpdate(true) end)

    checkUpdate(false)
    wait(-1)
end

imgui.OnInitialize(function() imgui.GetIO().IniFilename = nil end)

imgui.OnFrame(function() return window[0] end, function()
    local resX, resY = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(350, 300), imgui.Cond.FirstUseEver)
    imgui.Begin('Script [TM]', window, imgui.WindowFlags.NoResize)
    
    -- Âêëàäêè (Êíîïêè ñâåðõó)
    if imgui.Button(u8"Íàñòðîéêè", imgui.ImVec2(105, 25)) then activeTab[0] = 1 end
    imgui.SameLine()
    if imgui.Button(u8"Óâåäîìëåíèÿ", imgui.ImVec2(105, 25)) then activeTab[0] = 2 end
    imgui.SameLine()
    if imgui.Button(u8"Áóäóùåå", imgui.ImVec2(105, 25)) then activeTab[0] = 3 end
    
    imgui.Separator()

    if activeTab[0] == 1 then -- ÂÊËÀÄÊÀ ÍÀÑÒÐÎÉÊÈ
        imgui.PushItemWidth(200)
        if imgui.InputText(u8('ÈÄ ×àò'), chat, ffi.sizeof(chat), imgui.InputTextFlags.Password) then
            cfg.config.chat = ffi.string(chat)
            inicfg.save(cfg, SCRIPT_CONFIG_FILENAME)
        end
        if imgui.InputText(u8('Òîêåí'), token, ffi.sizeof(token), imgui.InputTextFlags.Password) then
            cfg.config.token = ffi.string(token)
            inicfg.save(cfg, SCRIPT_CONFIG_FILENAME)
        end
        imgui.PopItemWidth()

        if imgui.Checkbox(u8('Âêëþ÷èòü óâåäîìëåíèÿ î ïðåäìåòàõ'), itemAdding) then
            cfg.config.itemAdding = itemAdding[0]
            inicfg.save(cfg, SCRIPT_CONFIG_FILENAME)
        end

        imgui.SetCursorPosY(imgui.GetWindowHeight() - 40)
        if imgui.Button(u8("Òåñò ñîîáùåíèÿ"), imgui.ImVec2(120, 25)) then
            sendTelegramMessage("Ýòî òåñòîâîå ñîîáùåíèå! Ñêðèïò íàñòðîåí âåðíî.")
            sampAddChatMessage("{00ff00}[ItemLog] Òåñòîâîå ñîîáùåíèå îòïðàâëåíî!", -1)
        end

    elseif activeTab[0] == 2 then -- ÂÊËÀÄÊÀ ÓÂÅÄÎÌËÅÍÈß
        imgui.Text(u8"Ñïèñîê îòñëåæèâàåìûõ ïðåäìåòîâ:")
        imgui.BeginChild("item_list", imgui.ImVec2(0, 180), true)
        for id, name in pairs(items_name) do
            imgui.TextColored(imgui.ImVec4(0.2, 0.5, 1.0, 1.0), "["..id.."] ")
            imgui.SameLine()
            imgui.Text(u8(name))
        end
        imgui.EndChild()
        if imgui.Button(u8("Ïðîâåðèòü îáíîâëåíèå ñêðèïòà"), imgui.ImVec2(-1, 25)) then
            checkUpdate(true)
        end

    elseif activeTab[0] == 3 then -- ÂÊËÀÄÊÀ ÁÓÄÓÙÅÅ
        imgui.Text(u8"Çäåñü ïîÿâÿòñÿ íîâûå ôóíêöèè...")
        imgui.Text(u8"Íàïðèìåð: ëîã ïðîäàæ èëè ñòàòèñòèêà.")
    end

    imgui.End()
end)

function samp.onServerMessage(color, text)
    if color == -65281 and itemAdding[0] then
        -- Ïîèñê ID
        local itemId = text:match(":item(%d+):")
        if itemId then
            itemId = tonumber(itemId)
            if tableIncludes(items, itemId) then
                -- Ôîðìàò: ÂÀÌ ÁÛË ÄÎÁÀÂËÅÍ ÏÐÅÄÌÅÒ (íîâàÿ ñòðîêà) Íàçâàíèå
                local itemName = items_name[itemId] or "Ïðåäìåò "..itemId
                sendTelegramMessage("ÂÀÌ ÁÛË ÄÎÁÀÂËÅÍ ÏÐÅÄÌÅÒ\n" .. itemName)
            else
                -- Ôîðìàò äëÿ íåèçâåñòíûõ
				sendTelegramMessage("Ïîëó÷åí íåèçâåñòíûé ïðåäìåò. ID: " .. itemId .. ". Ïîæàëóéñòà, äîáàâüòå åãî â ñïèñîê.")
            end
        end
    end
end

function checkUpdate(manual)
    lua_thread.create(function()
        if manual then sampAddChatMessage("[ItemLog] Ïðîâåðêà îáíîâëåíèé...", -1) end
        local requests = require('requests')
        local ok, response = pcall(requests.get, UPDATE_URL)
        if ok and response.status_code == 200 then
            local remote_version = response.text:match('local SCRIPT_VERSION = "(.-)"')
            if remote_version and remote_version ~= SCRIPT_VERSION then
                sampAddChatMessage("[ItemLog] Íàéäåíà íîâàÿ âåðñèÿ: " .. remote_version, -1)
                local file = io.open(thisScript().path, "w")
                if file then
                    file:write(response.text)
                    file:close()
                    sampAddChatMessage("[ItemLog] Ñêðèïò îáíîâëåí! Ïåðåçàãðóçêà...", -1)
                    thisScript():reload()
                end
            elseif manual then
                sampAddChatMessage("[ItemLog] Îáíîâëåíèé íå íàéäåíî.", -1)
            end
        end
    end)
end
