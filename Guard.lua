-- RP Chat Guard — Guard
-- SendChatMessage hook (Layer 1) and edit box hook (Layer 2).

local addon = RPChatGuard

-- Slash command prefixes → WoW chat type. Used by DetectChatType to resolve
-- typed commands before WoW processes them.
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

-- Confirmation popup shown when a guarded channel is targeted.
StaticPopupDialogs["RPCHATGUARD_CONFIRM"] = {
    text    = "RP Chat Guard\n\nSend to |cffff6666%s|r?\n\n\"|cffffffff%s|r\"",
    button1 = "Send",
    button2 = "Cancel",
    timeout = 0,
    whileDead    = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function()
        local p = addon.pendingMsg
        if p and p.origFunc then
            p.origFunc(p.msg, p.chatType, p.language, p.target)
        end
        addon.pendingMsg = nil
    end,
    OnCancel = function()
        local p = addon.pendingMsg
        if p then
            print(addon.PREFIX .. "Cancelled message to |cffff6666"
                .. (addon.CHANNEL_LABELS[p.chatType] or p.chatType) .. "|r.")
        end
        addon.pendingMsg = nil
    end,
}

-- Layer 1: Hook SendChatMessage

local function HookedSendChatMessage(msg, chatType, language, target, ...)
    local ct = chatType and chatType:upper() or "SAY"

    if addon.debug_mode then
        print(addon.PREFIX .. "|cffffcc00DEBUG:|r SendChatMessage — type="
            .. tostring(ct) .. "  safe=" .. tostring(addon.safeChannels[ct] or false))
    end

    -- Safe channels and disabled state pass through immediately.
    if (not addon.enabled) or addon.safeChannels[ct] then
        return addon.OriginalSendChatMessage(msg, ct, language, target, ...)
    end

    -- Build a human-readable label for the popup.
    local label
    if ct == "CHANNEL" then
        local chanName = target
        if tonumber(target) then
            local _, n = GetChannelName(tonumber(target))
            if n then chanName = n end
        end
        label = "Channel: " .. tostring(chanName or target)
    else
        label = addon.CHANNEL_LABELS[ct] or ct
    end

    -- Truncate long messages for the confirmation preview.
    local displayMsg = msg or ""
    if #displayMsg > 120 then
        displayMsg = displayMsg:sub(1, 117) .. "..."
    end

    -- Store pending message and show the confirmation popup.
    addon.pendingMsg = {
        msg      = msg,
        chatType = ct,
        language = language,
        target   = target,
        origFunc = addon.OriginalSendChatMessage,
    }
    StaticPopup_Show("RPCHATGUARD_CONFIRM", label, displayMsg)
end

-- Layer 2: Hook chat edit boxes

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
        -- Unknown slash command — let it pass through untouched.
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
        -- Pass through when guard is off, box is empty, or command is unknown.
        if not addon.enabled then
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

        if addon.debug_mode then
            print(addon.PREFIX .. "|cffffcc00DEBUG:|r EditBox — type="
                .. tostring(chatType) .. "  safe=" .. tostring(addon.safeChannels[chatType] or false))
        end

        -- Safe channels pass through immediately.
        if addon.safeChannels[chatType] then
            if origScript then return origScript(self, ...) end
            return
        end

        -- Resolve the send target for whispers and numbered channels.
        local target = chanTarget
        if not target then
            if chatType == "WHISPER" or chatType == "BN_WHISPER" then
                target = self:GetAttribute("tellTarget")
            elseif chatType == "CHANNEL" then
                target = self:GetAttribute("channelTarget")
            end
        end

        -- Build a human-readable label for the popup.
        local label
        if chatType == "CHANNEL" then
            local chanName = target
            if tonumber(target) then
                local _, n = GetChannelName(tonumber(target))
                if n then chanName = n end
            end
            label = "Channel: " .. tostring(chanName or target)
        else
            label = addon.CHANNEL_LABELS[chatType] or chatType
        end

        -- Truncate long messages for the confirmation preview.
        local displayMsg = msgBody or text
        if #displayMsg > 120 then
            displayMsg = displayMsg:sub(1, 117) .. "..."
        end

        -- Clear the edit box and show the confirmation popup.
        addon.pendingMsg = {
            msg      = msgBody or text,
            chatType = chatType,
            language = nil,
            target   = target,
            origFunc = addon.OriginalSendChatMessage or SendChatMessage,
        }
        ChatEdit_AddHistory(self)
        self:SetText("")
        ChatEdit_DeactivateChat(self)
        StaticPopup_Show("RPCHATGUARD_CONFIRM", label, displayMsg)
    end)
end

function addon:HookAllEditBoxes()
    for i = 1, NUM_CHAT_WINDOWS do
        local box = _G["ChatFrame" .. i .. "EditBox"]
        if box then HookEditBox(box) end
    end
end

function addon:InstallHooks()
    addon.OriginalSendChatMessage = SendChatMessage
    SendChatMessage = HookedSendChatMessage
    addon:HookAllEditBoxes()
end
