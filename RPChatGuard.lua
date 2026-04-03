----------------------------------------------------------------------
-- RP Chat Guard v4
-- Requires confirmation before sending to non-RP chat channels.
-- Toggle with /rpg  |  Manage channels with /rpg allow / /rpg block
----------------------------------------------------------------------

local ADDON_NAME = "RPChatGuard"
local PREFIX = "|cff88ccff[RPGuard]|r "

RPChatGuardDB = RPChatGuardDB or {}

local enabled = true
local debug_mode = false
local pendingMsg = nil

----------------------------------------------------------------------
-- All recognised chat channels and their friendly aliases
----------------------------------------------------------------------
local VALID_CHANNELS = {
    SAY           = true,
    EMOTE         = true,
    WHISPER       = true,
    YELL          = true,
    GUILD         = true,
    OFFICER       = true,
    PARTY         = true,
    PARTY_LEADER  = true,
    RAID          = true,
    RAID_WARNING  = true,
    INSTANCE_CHAT = true,
    CHANNEL       = true,
    BN_WHISPER    = true,
}

-- Friendly names users can type → internal channel key
local ALIASES = {
    ["say"]          = "SAY",
    ["s"]            = "SAY",
    ["emote"]        = "EMOTE",
    ["em"]           = "EMOTE",
    ["e"]            = "EMOTE",
    ["me"]           = "EMOTE",
    ["whisper"]      = "WHISPER",
    ["w"]            = "WHISPER",
    ["tell"]         = "WHISPER",
    ["yell"]         = "YELL",
    ["y"]            = "YELL",
    ["guild"]        = "GUILD",
    ["g"]            = "GUILD",
    ["officer"]      = "OFFICER",
    ["o"]            = "OFFICER",
    ["party"]        = "PARTY",
    ["p"]            = "PARTY",
    ["raid"]         = "RAID",
    ["ra"]           = "RAID",
    ["raidwarning"]  = "RAID_WARNING",
    ["rw"]           = "RAID_WARNING",
    ["instance"]     = "INSTANCE_CHAT",
    ["i"]            = "INSTANCE_CHAT",
    ["channel"]      = "CHANNEL",
    ["bnwhisper"]    = "BN_WHISPER",
    ["bnet"]         = "BN_WHISPER",
}

-- Display labels for popups and listings
local CHANNEL_LABELS = {
    SAY           = "Say",
    EMOTE         = "Emote",
    WHISPER       = "Whisper",
    YELL          = "Yell",
    GUILD         = "Guild",
    OFFICER       = "Officer",
    PARTY         = "Party",
    PARTY_LEADER  = "Party Leader",
    RAID          = "Raid",
    RAID_WARNING  = "Raid Warning",
    INSTANCE_CHAT = "Instance",
    CHANNEL       = "Channel",
    BN_WHISPER    = "BNet Whisper",
}

----------------------------------------------------------------------
-- Default safe channels (used on first install)
----------------------------------------------------------------------
local DEFAULT_SAFE = {
    SAY     = true,
    EMOTE   = true,
    WHISPER = true,
    YELL    = true,
}

-- The live safe-channel table (loaded from saved vars or defaults)
local safeChannels = {}

----------------------------------------------------------------------
-- Resolve a user-typed name to an internal channel key
----------------------------------------------------------------------
local function ResolveChannel(input)
    local lower = input:lower()
    if ALIASES[lower] then
        return ALIASES[lower]
    end
    local upper = input:upper()
    if VALID_CHANNELS[upper] then
        return upper
    end
    return nil
end

----------------------------------------------------------------------
-- Persist current safe channels
----------------------------------------------------------------------
local function SaveSettings()
    RPChatGuardDB.enabled = enabled
    RPChatGuardDB.safeChannels = {}
    for ch in pairs(safeChannels) do
        RPChatGuardDB.safeChannels[ch] = true
    end
end

----------------------------------------------------------------------
-- Confirmation popup
----------------------------------------------------------------------
local OriginalSendChatMessage = nil

StaticPopupDialogs["RPCHATGUARD_CONFIRM"] = {
    text    = "RP Chat Guard\n\nSend to |cffff6666%s|r?\n\n\"|cffffffff%s|r\"",
    button1 = "Send",
    button2 = "Cancel",
    timeout = 0,
    whileDead    = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function()
        if pendingMsg and pendingMsg.origFunc then
            pendingMsg.origFunc(
                pendingMsg.msg,
                pendingMsg.chatType,
                pendingMsg.language,
                pendingMsg.target
            )
        end
        pendingMsg = nil
    end,
    OnCancel = function()
        if pendingMsg then
            print(PREFIX .. "Cancelled message to |cffff6666"
                .. (CHANNEL_LABELS[pendingMsg.chatType] or pendingMsg.chatType)
                .. "|r.")
        end
        pendingMsg = nil
    end,
}

----------------------------------------------------------------------
-- Layer 1: Hook SendChatMessage
----------------------------------------------------------------------
local function HookedSendChatMessage(msg, chatType, language, target, ...)
    local ct = chatType and chatType:upper() or "SAY"

    if debug_mode then
        print(PREFIX .. "|cffffcc00DEBUG:|r SendChatMessage - type="
            .. tostring(ct) .. "  safe=" .. tostring(safeChannels[ct] or false))
    end

    if (not enabled) or safeChannels[ct] then
        return OriginalSendChatMessage(msg, ct, language, target, ...)
    end

    local label
    if ct == "CHANNEL" then
        local chanName = target
        if tonumber(target) then
            local _, n = GetChannelName(tonumber(target))
            if n then chanName = n end
        end
        label = "Channel: " .. tostring(chanName or target)
    else
        label = CHANNEL_LABELS[ct] or ct
    end

    local displayMsg = msg or ""
    if #displayMsg > 120 then
        displayMsg = displayMsg:sub(1, 117) .. "..."
    end

    pendingMsg = {
        msg      = msg,
        chatType = ct,
        language = language,
        target   = target,
        origFunc = OriginalSendChatMessage,
    }

    StaticPopup_Show("RPCHATGUARD_CONFIRM", label, displayMsg)
end

----------------------------------------------------------------------
-- Layer 2: Hook chat edit boxes
----------------------------------------------------------------------

local SLASH_MAP = {
    ["/g"]        = "GUILD",   ["/guild"]    = "GUILD",
    ["/o"]        = "OFFICER", ["/officer"]  = "OFFICER",
    ["/p"]        = "PARTY",   ["/party"]    = "PARTY",
    ["/ra"]       = "RAID",    ["/raid"]     = "RAID",
    ["/rw"]       = "RAID_WARNING",
    ["/y"]        = "YELL",    ["/yell"]     = "YELL",
    ["/i"]        = "INSTANCE_CHAT", ["/instance"] = "INSTANCE_CHAT",
    ["/s"]        = "SAY",     ["/say"]      = "SAY",
    ["/e"]        = "EMOTE",   ["/em"]       = "EMOTE",
    ["/emote"]    = "EMOTE",   ["/me"]       = "EMOTE",
    ["/w"]        = "WHISPER", ["/whisper"]  = "WHISPER",
    ["/tell"]     = "WHISPER",
}

local function DetectChatType(editBox)
    local text = editBox:GetText() or ""
    local cmd = text:match("^(/[%a]+)")
    if cmd then
        local mapped = SLASH_MAP[cmd:lower()]
        if mapped then
            local rest = text:match("^/[%a]+%s+(.*)")
            return mapped, rest or ""
        end
        local num, rest = text:match("^/(%d+)%s+(.*)")
        if num then
            return "CHANNEL", rest or "", num
        end
        -- Unknown slash command - let it through
        return nil
    end
    local ct = editBox:GetAttribute("chatType") or "SAY"
    return ct:upper(), text
end

local function HookEditBox(editBox)
    if editBox._rpgHooked then return end
    editBox._rpgHooked = true

    local origScript = editBox:GetScript("OnEnterPressed")

    editBox:SetScript("OnEnterPressed", function(self, ...)
        if not enabled then
            if origScript then return origScript(self, ...) end
            return
        end

        local text = self:GetText() or ""
        if text == "" then
            if origScript then return origScript(self, ...) end
            return
        end

        local chatType, msgBody, chanTarget = DetectChatType(self)

        if chatType == nil then
            if origScript then return origScript(self, ...) end
            return
        end

        if debug_mode then
            print(PREFIX .. "|cffffcc00DEBUG:|r EditBox - type="
                .. tostring(chatType) .. "  safe=" .. tostring(safeChannels[chatType] or false))
        end

        if safeChannels[chatType] then
            if origScript then return origScript(self, ...) end
            return
        end

        local target = chanTarget
        if not target then
            if chatType == "WHISPER" or chatType == "BN_WHISPER" then
                target = self:GetAttribute("tellTarget")
            elseif chatType == "CHANNEL" then
                target = self:GetAttribute("channelTarget")
            end
        end

        local label
        if chatType == "CHANNEL" then
            local chanName = target
            if tonumber(target) then
                local _, n = GetChannelName(tonumber(target))
                if n then chanName = n end
            end
            label = "Channel: " .. tostring(chanName or target)
        else
            label = CHANNEL_LABELS[chatType] or chatType
        end

        local displayMsg = msgBody or text
        if #displayMsg > 120 then
            displayMsg = displayMsg:sub(1, 117) .. "..."
        end

        pendingMsg = {
            msg      = msgBody or text,
            chatType = chatType,
            language = nil,
            target   = target,
            origFunc = OriginalSendChatMessage or SendChatMessage,
        }

        ChatEdit_AddHistory(self)
        self:SetText("")
        ChatEdit_DeactivateChat(self)

        StaticPopup_Show("RPCHATGUARD_CONFIRM", label, displayMsg)
    end)
end

local function HookAllEditBoxes()
    for i = 1, NUM_CHAT_WINDOWS do
        local box = _G["ChatFrame" .. i .. "EditBox"]
        if box then HookEditBox(box) end
    end
end

----------------------------------------------------------------------
-- Toggle
----------------------------------------------------------------------
local function SetEnabled(state)
    enabled = state
    SaveSettings()
    if enabled then
        print(PREFIX .. "Guard |cff00ff00ON|r")
    else
        print(PREFIX .. "Guard |cffff4444OFF|r")
    end
end

----------------------------------------------------------------------
-- Print status + allowed channels
----------------------------------------------------------------------
local function PrintStatus()
    print(PREFIX .. "Guard is "
        .. (enabled and "|cff00ff00ON|r" or "|cffff4444OFF|r"))

    local allowed = {}
    for ch in pairs(safeChannels) do
        allowed[#allowed + 1] = "|cff00ff00" .. (CHANNEL_LABELS[ch] or ch) .. "|r"
    end
    table.sort(allowed)

    local guarded = {}
    for ch in pairs(VALID_CHANNELS) do
        if not safeChannels[ch] then
            guarded[#guarded + 1] = "|cffff6666" .. (CHANNEL_LABELS[ch] or ch) .. "|r"
        end
    end
    table.sort(guarded)

    print(PREFIX .. "Allowed: " .. (#allowed > 0 and table.concat(allowed, ", ") or "none"))
    print(PREFIX .. "Guarded: " .. (#guarded > 0 and table.concat(guarded, ", ") or "none"))
end

----------------------------------------------------------------------
-- Allow / block channels
----------------------------------------------------------------------
local function AllowChannels(input)
    local changed = {}
    for word in input:gmatch("%S+") do
        local ch = ResolveChannel(word)
        if ch then
            if not safeChannels[ch] then
                safeChannels[ch] = true
                changed[#changed + 1] = "|cff00ff00" .. (CHANNEL_LABELS[ch] or ch) .. "|r"
            end
        else
            print(PREFIX .. "Unknown channel: |cffff6666" .. word .. "|r")
        end
    end
    if #changed > 0 then
        SaveSettings()
        print(PREFIX .. "Now allowed: " .. table.concat(changed, ", "))
    end
end

local function BlockChannels(input)
    local changed = {}
    for word in input:gmatch("%S+") do
        local ch = ResolveChannel(word)
        if ch then
            if safeChannels[ch] then
                safeChannels[ch] = nil
                changed[#changed + 1] = "|cffff6666" .. (CHANNEL_LABELS[ch] or ch) .. "|r"
            end
        else
            print(PREFIX .. "Unknown channel: |cffff6666" .. word .. "|r")
        end
    end
    if #changed > 0 then
        SaveSettings()
        print(PREFIX .. "Now guarded: " .. table.concat(changed, ", "))
    end
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
SLASH_RPCHATGUARD1 = "/rpg"
SLASH_RPCHATGUARD2 = "/rpchatguard"

SlashCmdList["RPCHATGUARD"] = function(input)
    local cmd, rest = strtrim(input or ""):match("^(%S*)%s*(.*)")
    cmd = (cmd or ""):lower()
    rest = strtrim(rest or "")

    if cmd == "on" then
        SetEnabled(true)
    elseif cmd == "off" then
        SetEnabled(false)
    elseif cmd == "status" then
        PrintStatus()
    elseif cmd == "allow" then
        if rest == "" then
            print(PREFIX .. "Usage: /rpg allow <channel> [channel ...]")
            print(PREFIX .. "Examples: /rpg allow guild  |  /rpg allow party raid")
        else
            AllowChannels(rest)
        end
    elseif cmd == "block" then
        if rest == "" then
            print(PREFIX .. "Usage: /rpg block <channel> [channel ...]")
            print(PREFIX .. "Examples: /rpg block yell  |  /rpg block guild officer")
        else
            BlockChannels(rest)
        end
    elseif cmd == "reset" then
        safeChannels = {}
        for ch, v in pairs(DEFAULT_SAFE) do
            safeChannels[ch] = v
        end
        SaveSettings()
        print(PREFIX .. "Channels reset to defaults.")
        PrintStatus()
    elseif cmd == "debug" then
        debug_mode = not debug_mode
        print(PREFIX .. "Debug " .. (debug_mode and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
    elseif cmd == "help" then
        print(PREFIX .. "Commands:")
        print("  /rpg              Toggle guard on/off")
        print("  /rpg on|off       Set guard explicitly")
        print("  /rpg status       Show state and channel lists")
        print("  /rpg allow <ch>   Allow one or more channels")
        print("  /rpg block <ch>   Guard one or more channels")
        print("  /rpg reset        Restore default channels")
        print("  /rpg debug        Toggle debug output")
        print(PREFIX .. "Channel names: say, emote, whisper, yell, guild,")
        print("  officer, party, raid, rw, instance, channel, bnet")
    else
        SetEnabled(not enabled)
    end
end

----------------------------------------------------------------------
-- Init
----------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
    if addon ~= ADDON_NAME then return end

    -- Load saved settings or apply defaults
    if RPChatGuardDB.enabled == nil then
        RPChatGuardDB.enabled = true
    end
    enabled = RPChatGuardDB.enabled

    if RPChatGuardDB.safeChannels then
        safeChannels = {}
        for ch, v in pairs(RPChatGuardDB.safeChannels) do
            if VALID_CHANNELS[ch] then
                safeChannels[ch] = v
            end
        end
    else
        safeChannels = {}
        for ch, v in pairs(DEFAULT_SAFE) do
            safeChannels[ch] = v
        end
    end

    -- Install hooks
    OriginalSendChatMessage = SendChatMessage
    SendChatMessage = HookedSendChatMessage
    HookAllEditBoxes()

    print(PREFIX .. "v4 loaded - guard is "
        .. (enabled and "|cff00ff00ON|r" or "|cffff4444OFF|r")
        .. ".  |cff88ccff/rpg help|r for commands.")
end)
