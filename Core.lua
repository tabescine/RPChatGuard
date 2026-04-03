-- RP Chat Guard — Core
-- Shared namespace, data tables, SavedVariables, and initialisation.

RPChatGuard = RPChatGuard or {}
local addon = RPChatGuard

addon.PREFIX     = "|cff88ccff[RPGuard]|r "
addon.enabled    = true
addon.debug_mode = false
addon.pendingMsg = nil
addon.safeChannels = {}

-- All recognised WoW chat channel types.
addon.VALID_CHANNELS = {
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

-- Friendly names users can type → internal channel key.
addon.ALIASES = {
    ["say"]         = "SAY",
    ["s"]           = "SAY",
    ["emote"]       = "EMOTE",
    ["em"]          = "EMOTE",
    ["e"]           = "EMOTE",
    ["me"]          = "EMOTE",
    ["whisper"]     = "WHISPER",
    ["w"]           = "WHISPER",
    ["tell"]        = "WHISPER",
    ["yell"]        = "YELL",
    ["y"]           = "YELL",
    ["guild"]       = "GUILD",
    ["g"]           = "GUILD",
    ["officer"]     = "OFFICER",
    ["o"]           = "OFFICER",
    ["party"]       = "PARTY",
    ["p"]           = "PARTY",
    ["raid"]        = "RAID",
    ["ra"]          = "RAID",
    ["raidwarning"] = "RAID_WARNING",
    ["rw"]          = "RAID_WARNING",
    ["instance"]    = "INSTANCE_CHAT",
    ["i"]           = "INSTANCE_CHAT",
    ["channel"]     = "CHANNEL",
    ["bnwhisper"]   = "BN_WHISPER",
    ["bnet"]        = "BN_WHISPER",
}

-- Display labels used in popups and status output.
addon.CHANNEL_LABELS = {
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

-- Channels that are safe by default on first install.
addon.DEFAULT_SAFE = {
    SAY        = true,
    EMOTE      = true,
    WHISPER    = true,
    YELL       = true,
    BN_WHISPER = true,
}

function addon:SaveSettings()
    RPChatGuardDB.enabled = self.enabled
    RPChatGuardDB.safeChannels = {}
    for ch in pairs(self.safeChannels) do
        RPChatGuardDB.safeChannels[ch] = true
    end
end

function addon:IsChannelSafe(chatType)
    return self.safeChannels[chatType] == true
end

-- Init

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= "RPChatGuard" then return end

    -- Load saved enabled state, defaulting to true on first run.
    if RPChatGuardDB.enabled == nil then
        RPChatGuardDB.enabled = true
    end
    addon.enabled = RPChatGuardDB.enabled

    -- Load saved safe channels, or apply defaults on first run.
    if RPChatGuardDB.safeChannels then
        addon.safeChannels = {}
        for ch, v in pairs(RPChatGuardDB.safeChannels) do
            if addon.VALID_CHANNELS[ch] then
                addon.safeChannels[ch] = v
            end
        end
    else
        addon.safeChannels = {}
        for ch, v in pairs(addon.DEFAULT_SAFE) do
            addon.safeChannels[ch] = v
        end
    end

    -- Guard.lua exposes InstallHooks after all files are loaded.
    addon:InstallHooks()

    print(addon.PREFIX .. "v4 loaded — guard is "
        .. (addon.enabled and "|cff00ff00ON|r" or "|cffff4444OFF|r")
        .. ".  |cff88ccff/rpg help|r for commands.")
end)
