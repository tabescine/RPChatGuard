# RPChatGuard — Claude Code Handoff Plan

Work through these phases in order. Each phase should end with a working addon — don't break things between steps. Test advice is inline since there's no automated testing; the user will `/reload` in-game.

---

## Phase 1: Split into multiple files

The single `RPChatGuard.lua` is getting large. Split it into focused modules. All files communicate through a shared addon table — this is standard WoW addon practice.

### Create the shared addon table

Create `Core.lua` as the first loaded file. It should:
- Create the addon namespace: `RPChatGuard = RPChatGuard or {}`
- Store references that other files need (enabled state, safeChannels table, debug flag, CHANNEL_LABELS, VALID_CHANNELS, ALIASES, PREFIX, etc.)
- Handle `ADDON_LOADED` event, load SavedVariables into the shared table, apply defaults if first run
- Expose `RPChatGuard:SaveSettings()` for other modules to call
- Expose `RPChatGuard:IsChannelSafe(chatType)` helper

### Create `Guard.lua`

Move all hook logic here:
- The `SendChatMessage` replacement (Layer 1)
- The edit box `OnEnterPressed` hook (Layer 2)
- `DetectChatType()`, `SLASH_MAP`
- The `StaticPopupDialogs["RPCHATGUARD_CONFIRM"]` definition
- `HookEditBox()`, `HookAllEditBoxes()`
- Read enabled/safe state from the shared addon table, not local variables

### Create `Config.lua`

Move all slash command logic here:
- `SlashCmdList["RPCHATGUARD"]` and all subcommands
- `ResolveChannel()`, `AllowChannels()`, `BlockChannels()`, `PrintStatus()`
- The ALIASES table (or keep in Core if other modules need it)

### Update `RPChatGuard.toc`

Replace the single file entry with the load order:
```
Core.lua
Guard.lua
Config.lua
```

### Verify nothing broke

After splitting, every existing feature must still work: toggle, allow/block, status, debug mode, confirmation popups, SavedVariables persistence. The file split is purely structural — zero behaviour changes.

---

## Phase 2: Minimap button

Use LibDataBroker-1.1 (LDB) and LibDBIcon-1.0 for the minimap button. These are the standard libraries every WoW addon uses for this.

### Vendor the libraries

Download and place in `Libs/`:
```
Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua
Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua
Libs/LibStub/LibStub.lua
Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua
```

LibDBIcon depends on LibStub and CallbackHandler. All four are needed. Source them from https://github.com/tekkub/libdatabroker-1-1 and https://github.com/rossnichols/LibDBIcon-1.0 (or grab from any popular addon that bundles them).

### Update `RPChatGuard.toc`

Add the libs before addon files:
```
Libs/LibStub/LibStub.lua
Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua
Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua
Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua

Core.lua
Guard.lua
Config.lua
Minimap.lua
```

### Create `Minimap.lua`

- Create an LDB data object with:
  - `type = "launcher"`
  - `icon` — use a built-in WoW texture like `"Interface\\Icons\\Spell_Shadow_MindTwisting"` or similar chat/shield icon. Browse https://www.wowhead.com/icons for options.
  - `OnClick`:
    - Left-click → toggle guard on/off
    - Right-click → open settings panel (Phase 3) or print `/rpg help` as a placeholder
  - `OnTooltipShow`:
    - Line 1: "RP Chat Guard"
    - Line 2: current state (ON/OFF) in green/red
    - Line 3: "Left-click to toggle"
    - Line 4: "Right-click for settings"
- Register with LibDBIcon: `LibDBIcon:Register("RPChatGuard", ldbObject, RPChatGuardDB.minimap)`
- Store minimap position in `RPChatGuardDB.minimap` (LibDBIcon handles the sub-table automatically)
- Update the icon tooltip/appearance when guard state changes — call `ldbObject.icon` swap or just update the tooltip text dynamically

---

## Phase 3: Settings GUI

Use WoW's built-in Settings panel (the `Settings` API introduced in Dragonflight). This avoids depending on AceConfig and keeps the addon lightweight.

### Create `SettingsPanel.lua`

Register a settings category:
```lua
local category = Settings.RegisterCanvasLayoutCategory(panel, "RP Chat Guard")
Settings.RegisterAddOnCategory(category)
```

The panel should contain:

1. **Enable/Disable checkbox** — bound to `RPChatGuardDB.enabled`. Toggle guard state.

2. **Channel checklist** — one checkbox per channel in `VALID_CHANNELS`. Checked = safe (allowed without confirmation), unchecked = guarded. Bind each to `safeChannels[CHANNEL_KEY]`. Display the friendly label from `CHANNEL_LABELS`.
   - Group visually: "RP Channels" (Say, Emote, Whisper, Yell) and "Group Channels" (Party, Raid, Guild, Officer, Instance, Raid Warning, Channel, BNet Whisper).

3. **Reset to Defaults button** — restores `DEFAULT_SAFE` and refreshes all checkboxes.

4. **Minimap icon checkbox** — show/hide the minimap button (`LibDBIcon:Show`/`Hide`).

Wire the right-click on the minimap button to open this panel:
```lua
Settings.OpenToCategory("RP Chat Guard")
```

### Update `RPChatGuard.toc`

Add after Config.lua:
```
SettingsPanel.lua
```

### Slash command integration

Make `/rpg settings` or `/rpg config` open the panel too.

---

## Phase 4: README.md

Write `README.md` for the repo. Include:

- **Title + one-line description**
- **The problem** — brief explanation of why RP players need this (accidental OOC messages to guild/party/raid)
- **Features** — bullet list: confirmation popup, configurable safe channels, slash commands, minimap button, settings panel, persisted config
- **Installation** — download zip, extract to `Interface/AddOns/RPChatGuard`, reload. Mention CurseForge/WoWInterface if published.
- **Usage** — quick start: it's on by default, just install and go. Mention `/rpg help` for commands.
- **Slash command reference** — table from CLAUDE.md
- **Configuration** — mention both slash commands and the settings panel
- **Default safe channels** — list them
- **Screenshots** — add later, leave placeholder `![Confirmation popup](screenshots/popup.png)`
- **License** — mention the license (suggest MIT)
- **Contributing** — keep it brief, mention issues/PRs welcome

Tone: casual, concise, aimed at WoW players not developers.

---

## General notes

- **Do not introduce new dependencies** beyond LibStub, CallbackHandler, LibDataBroker, and LibDBIcon. Keep the addon lightweight.
- **Lua 5.1 only.** No `goto`, no bitwise ops, no integer division, no `utf8` library.
- **Test each phase** before moving to the next. Every phase must leave the addon fully functional.
- **Preserve all existing behaviour.** The split and new features are additive — don't change how the guard, slash commands, or SavedVariables work unless fixing a bug.
- **Color codes** use WoW's `|cAARRGGBB...|r` format. Keep the existing colour scheme (blue for addon name, green for ON/safe, red for OFF/guarded, yellow for debug).
