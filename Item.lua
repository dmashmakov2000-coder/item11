script_properties('work-in-pause')

local samp = require('samp.events')
local effil = require('effil')
local inicfg = require('inicfg')
local ffi = require('ffi')
local imgui = require('mimgui')
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- ================= ÍÀÑÒÐÎÉÊÈ ÎÁÍÎÂËÅÍÈß =================
local SCRIPT_VERSION = "0.0.26" 
local UPDATE_URL = "https://raw.githubusercontent.com/dmashmakov2000-coder/item11/main/Item.lua"
-- ========================================================

local SCRIPT_CONFIG_NAME = 'Item'
local SCRIPT_CONFIG_FILENAME = SCRIPT_CONFIG_NAME .. '.ini'

local items = {
    1811, 522, 4344, 5991, 1146, 731, 9726, 9697,
    7480, 555, 1425, 556, 557, 4794 -- Óáðàë òî÷êó â êîíöå
}

local items_name = {
    [7480] = "Ëàðåö Fortnite",
    [555] = "Áðîíçîâàÿ ðóëåòêà",
    [1425] = "Ïëàòèíîâàÿ ðóëåòêà",
    [556] = "Ñåðåáðÿíàÿ ðóëåòêà",
    [557] = "Çîëîòàÿ ðóëåòêà",
    [4794] = "Ëàðåö Êëàäîèñêàòåëÿ",
    [1811] = "Bitcoin (BTC)",
    [522] = "Ñåìåéíûé òàëîí",
    [4344] = "Òàëîí +1 EXP",
    [5991] = "Ãðóíò",
    [1146] = "Ãðàæäàíñêèé òàëîí",
    [731] = "Àz-Coins",
    [9726] = "Ëîòåðåéíûé áèëåò 2ê26",
    [9697] = "Ìîíåòà Íîâîãî ãîäà (2026)",
}

local cfg = inicfg.load({
    config = {
        chat = '',
        token = '',
        itemAdding = false
    }
}, SCRIPT_CONFIG_NAME)

local chat = imgui.new.char[128](tostring(cfg.config.chat))
local token = imgui.new.char[128](tostring(cfg.config.token))
local itemAdding = imgui.new.bool(cfg.config.itemAdding)
local window = imgui.new.bool(false)

-- Ïîòîê äëÿ ðàáîòû ñ ñåòüþ (Telegram è Îáíîâëåíèÿ)
local networkThread = effil.thread(function(url, mode, data)
    local requests = require('requests')
    if mode == "telegram" then
        return requests.post(url, {params = data})
    elseif mode == "check_update" then
        local res = requests.get(url)
        if res.status_code == 200 then
            return res.text
        end
    end
    return nil
end)

function main()
    while not isSampAvailable() do wait(0) end
    
    sampAddChatMessage('[logg] {ffffff}Àêòèâàöèÿ: /item', 0x3083ff)
    
    -- Ðåãèñòðàöèÿ êîìàíä ÂÍÓÒÐÈ main
    sampRegisterChatCommand('item', function() window[0] = not window[0] end)
    sampRegisterChatCommand('itemupdate', function() checkUpdate(true) end)

    -- Àâòîïðîâåðêà ïðè ñòàðòå
    checkUpdate(false)

    while true do
        wait(0)
        -- Çäåñü ìîæíî äîáàâèòü ëîãèêó, åñëè íóæíà â öèêëå
    end
end

-- Ôóíêöèÿ ïðîâåðêè îáíîâëåíèé
function checkUpdate(manual)
    if manual then sampAddChatMessage("[Item] {ffffff}Ïðîâåðêà îáíîâëåíèé...", -1) end
    
    local proc = networkThread(UPDATE_URL, "check_update")
    lua_thread.create(function()
        while proc:status() == "running" do wait(0) end
        local result = proc:get()
        if result then
            local remote_version = result:match('local SCRIPT_VERSION = "(.-)"')
            if remote_version and remote_version ~= SCRIPT_VERSION then
                sampAddChatMessage(string.format('[Item] {ffff00}Íàéäåíà íîâàÿ âåðñèÿ: %s. {ffffff}Îáíîâëÿþ...', remote_version), -1)
                updateScript(result)
            else
                if manual then sampAddChatMessage("[Item] {00ff00}Ó âàñ óñòàíîâëåíà ïîñëåäíÿÿ âåðñèÿ.", -1) end
            end
        else
            if manual then sampAddChatMessage("[Item] {ff0000}Îøèáêà ïðè ïîäêëþ÷åíèè ê ñåðâåðó îáíîâëåíèé.", -1) end
        end
    end)
end

function updateScript(content)
    local f = io.open(thisScript().path, "w")
    if f then
        f:write(content)
        f:close()
        sampAddChatMessage("[Item] {00ff00}Îáíîâëåíèå óñïåøíî! Ïåðåçàãðóçêà...", -1)
        thisScript():reload()
    else
        sampAddChatMessage("[Item] {ff0000}Îøèáêà: Íå óäàëîñü ïåðåçàïèñàòü ôàéë. Ïðîâåðüòå ïðàâà äîñòóïà.", -1)
    end
end

-- mimgui èíòåðôåéñ
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
end)

imgui.OnFrame(
    function() return window[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(300, 180), imgui.Cond.FirstUseEver)
        imgui.Begin('Logg', window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
        
        if imgui.InputText(u8('ÈÄ ×àò'), chat, ffi.sizeof(chat), imgui.InputTextFlags.Password) then
            cfg.config.chat = ffi.string(chat)
            inicfg.save(cfg, SCRIPT_CONFIG_FILENAME)
        end
        if imgui.InputText(u8('Òîêåí'), token, ffi.sizeof(token), imgui.InputTextFlags.Password) then
            cfg.config.token = ffi.string(token)
            inicfg.save(cfg, SCRIPT_CONFIG_FILENAME)
        end
        if imgui.Checkbox(u8('Äîáàâëåíèå ïðåäìåòà'), itemAdding) then
            cfg.config.itemAdding = itemAdding[0]
            inicfg.save(cfg, SCRIPT_CONFIG_FILENAME)
        end
        
        if imgui.Button(u8("Ïðîâåðèòü îáíîâëåíèÿ")) then
            checkUpdate(true)
        end
        
        imgui.End()
    end
)

-- Ðàáîòà ñ ñîîáùåíèÿìè è Telegram
function sendTelegramMessage(text)
    local chat_id_str = ffi.string(chat)
    local token_str = ffi.string(token)
    if chat_id_str == '' or token_str == '' then return end

    local text_to_send = text:gsub('{......}', '')
    networkThread(('https://api.telegram.org/bot%s/sendMessage'):format(token_str), "telegram", {
        chat_id = chat_id_str,
        text = u8:decode(text_to_send)
    })
end

function samp.onServerMessage(color, text)
    if color == -65281 and itemAdding[0] and text:find("Âàì áûë äîáàâëåí ïðåäìåò") then
        local itemId = tonumber(text:match(":item(%d+):"))
        if itemId then
            if items_name[itemId] then
                sendTelegramMessage("Ïîëó÷åí ïðåäìåò: " .. items_name[itemId])
            else
                sendTelegramMessage("Ïîëó÷åí íåèçâåñòíûé ïðåäìåò. ID: " .. itemId)
            end
        end
    end
end
