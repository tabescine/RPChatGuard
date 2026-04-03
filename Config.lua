-- RP Chat Guard - Config
-- Slash commands, channel management, and status reporting.

local addon = RPChatGuard

local function ResolveChannel(input)
    local lower = input:lower()
    if addon.ALIASES[lower] then
        return addon.ALIASES[lower]
    end
    local upper = input:upper()
    if addon.VALID_CHANNELS[upper] then
        return upper
    end
    return nil
end

local function PrintStatus()
    print(addon.PREFIX .. "Guard is "
        .. (addon.enabled and "|cff00ff00ON|r" or "|cffff4444OFF|r"))

    local allowed = {}
    for ch in pairs(addon.safeChannels) do
        allowed[#allowed + 1] = "|cff00ff00" .. (addon.CHANNEL_LABELS[ch] or ch) .. "|r"
    end
    table.sort(allowed)

    local guarded = {}
    for ch in pairs(addon.VALID_CHANNELS) do
        if not addon.safeChannels[ch] then
            guarded[#guarded + 1] = "|cffff6666" .. (addon.CHANNEL_LABELS[ch] or ch) .. "|r"
        end
    end
    table.sort(guarded)

    print(addon.PREFIX .. "Allowed: " .. (#allowed > 0 and table.concat(allowed, ", ") or "none"))
    print(addon.PREFIX .. "Guarded: " .. (#guarded > 0 and table.concat(guarded, ", ") or "none"))
end

local function AllowChannels(input)
    local changed = {}
    for word in input:gmatch("%S+") do
        local ch = ResolveChannel(word)
        if ch then
            if not addon.safeChannels[ch] then
                addon.safeChannels[ch] = true
                changed[#changed + 1] = "|cff00ff00" .. (addon.CHANNEL_LABELS[ch] or ch) .. "|r"
            end
        else
            print(addon.PREFIX .. "Unknown channel: |cffff6666" .. word .. "|r")
        end
    end
    if #changed > 0 then
        addon:SaveSettings()
        print(addon.PREFIX .. "Now allowed: " .. table.concat(changed, ", "))
    end
end

local function BlockChannels(input)
    local changed = {}
    for word in input:gmatch("%S+") do
        local ch = ResolveChannel(word)
        if ch then
            if addon.safeChannels[ch] then
                addon.safeChannels[ch] = nil
                changed[#changed + 1] = "|cffff6666" .. (addon.CHANNEL_LABELS[ch] or ch) .. "|r"
            end
        else
            print(addon.PREFIX .. "Unknown channel: |cffff6666" .. word .. "|r")
        end
    end
    if #changed > 0 then
        addon:SaveSettings()
        print(addon.PREFIX .. "Now guarded: " .. table.concat(changed, ", "))
    end
end

local function SetEnabled(state)
    addon.enabled = state
    addon:SaveSettings()
    if addon.enabled then
        print(addon.PREFIX .. "Guard |cff00ff00ON|r")
    else
        print(addon.PREFIX .. "Guard |cffff4444OFF|r")
    end
end

-- Slash commands

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
            print(addon.PREFIX .. "Usage: /rpg allow <channel> [channel ...]")
            print(addon.PREFIX .. "Examples: /rpg allow guild  |  /rpg allow party raid")
        else
            AllowChannels(rest)
        end
    elseif cmd == "block" then
        if rest == "" then
            print(addon.PREFIX .. "Usage: /rpg block <channel> [channel ...]")
            print(addon.PREFIX .. "Examples: /rpg block yell  |  /rpg block guild officer")
        else
            BlockChannels(rest)
        end
    elseif cmd == "reset" then
        addon.safeChannels = {}
        for ch, v in pairs(addon.DEFAULT_SAFE) do
            addon.safeChannels[ch] = v
        end
        addon:SaveSettings()
        print(addon.PREFIX .. "Channels reset to defaults.")
        PrintStatus()
    elseif cmd == "debug" then
        addon.debug_mode = not addon.debug_mode
        print(addon.PREFIX .. "Debug " .. (addon.debug_mode and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
    elseif cmd == "help" then
        print(addon.PREFIX .. "Commands:")
        print("  /rpg              Toggle guard on/off")
        print("  /rpg on|off       Set guard explicitly")
        print("  /rpg status       Show state and channel lists")
        print("  /rpg allow <ch>   Allow one or more channels")
        print("  /rpg block <ch>   Guard one or more channels")
        print("  /rpg reset        Restore default channels")
        print("  /rpg debug        Toggle debug output")
        print(addon.PREFIX .. "Channel names: say, emote, whisper, yell, guild,")
        print("  officer, party, raid, rw, instance, channel, bnet")
    else
        SetEnabled(not addon.enabled)
    end
end
