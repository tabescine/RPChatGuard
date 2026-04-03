std = "lua51"

-- WoW API globals
globals = {
    -- Chat functions
    "SendChatMessage",
    "GetChannelName",
    "ChatEdit_AddHistory",
    "ChatEdit_DeactivateChat",

    -- UI functions
    "CreateFrame",
    "StaticPopupDialogs",
    "StaticPopup_Show",

    -- Chat frames
    "NUM_CHAT_WINDOWS",
    "_G",

    -- Slash commands
    "SlashCmdList",
    "SLASH_RPCHATGUARD1",
    "SLASH_RPCHATGUARD2",

    -- SavedVariables
    "RPChatGuardDB",

    -- Addon namespace
    "RPChatGuard",

    -- Utility
    "strtrim",
    "print",
    "tostring",
    "tonumber",
    "pairs",
    "ipairs",
    "table",
    "string",
    "math",
}

-- Allow unused variables that are part of the API
unused_args = false
unused_secondaries = false