-- TotemBuddy: Set Bindings Module
-- This is what makes in-combat set switching legal under Blizzard's policy.
--
-- Each saved set gets its own hidden *secure* button whose macrotext is the
-- set's /castsequence. The player binds a key to that button (an override
-- binding). Pressing the key fires ONE totem per press (one hardware event =
-- one protected cast), and switching sets mid-fight is simply pressing a
-- different, already-bound key -- no secure attribute is changed during combat.
--
-- All secure work (creating buttons, setting macrotext, (un)binding keys) is
-- forbidden in combat, so it is deferred to PLAYER_REGEN_ENABLED via a pending
-- flag, mirroring the addon's existing pendingActiveUpdates pattern.

local addonName, addon = ...

local MAX_SET_BUTTONS = 16            -- cap on how many sets can be key-bound
local CASTSEQUENCE_RESET = "reset=5"  -- matches the default TBAll macro

-- Owner frame for ClearOverrideBindings / SetOverrideBindingClick
local bindingOwner = CreateFrame("Frame", "TotemBuddyBindingOwner", UIParent)

local setButtons = {}      -- pool of secure buttons, created lazily (out of combat)
local pendingBindings = false

-- Build the /castsequence macro body for a set (using localized totem names).
-- Returns nil if the set has no totems.
function addon.BuildSetCastSequence(set)
    local names = {}
    for _, element in ipairs(addon.SET_ELEMENTS) do
        local spellID = set[element]
        local totemName = spellID and addon.GetTotemName(spellID) or nil
        if totemName then
            table.insert(names, totemName)
        end
    end
    if #names == 0 then return nil end
    return "#showtooltip\n/castsequence " .. CASTSEQUENCE_RESET .. " " .. table.concat(names, ", ")
end

-- Get or create the secure button for slot i (caller guarantees out of combat)
local function EnsureButton(i)
    if setButtons[i] then return setButtons[i] end
    local btn = CreateFrame("Button", "TotemBuddySetButton" .. i, UIParent, "SecureActionButtonTemplate")
    btn:Hide()
    btn:SetAttribute("type", "macro")
    btn:RegisterForClicks("AnyDown") -- cast on key-down: one cast per keypress
    setButtons[i] = btn
    return btn
end

-- Rebuild every set button's macrotext and override keybinding from the saved
-- sets. Deferred until out of combat (secure ops are locked during combat).
function addon.RefreshSetBindings()
    if InCombatLockdown() then
        pendingBindings = true
        return
    end
    pendingBindings = false

    ClearOverrideBindings(bindingOwner)

    local sets = addon.GetSets()
    for i = 1, MAX_SET_BUTTONS do
        local set = sets[i]
        if set then
            local btn = EnsureButton(i)
            btn:SetAttribute("macrotext", addon.BuildSetCastSequence(set) or "")
            if set.keybind and set.keybind ~= "" then
                SetOverrideBindingClick(bindingOwner, true, set.keybind, btn:GetName(), "LeftButton")
            end
        elseif setButtons[i] then
            setButtons[i]:SetAttribute("macrotext", "")
        end
    end
end

-- Called from PLAYER_REGEN_ENABLED to flush work deferred during combat
function addon.ApplyPendingSetBindings()
    if pendingBindings then
        addon.RefreshSetBindings()
    end
end

-- Central "sets changed" hook: rebuild secure bindings AND refresh the config
-- tab. Call this after any change to the set list or a set's contents/keybind.
function addon.NotifySetsChanged()
    if addon.RefreshSetBindings then addon.RefreshSetBindings() end
    if addon.RefreshSetsTab then addon.RefreshSetsTab() end
end

-- ---- Keybind registry / conflict detection -----------------------------
-- TotemBuddy hands out *override* bindings (sets, quick-react totems, shields).
-- Override bindings silently win over each other and over normal bindings, so a
-- duplicate chord = a silently dead button. This collects every chord TB itself
-- has assigned so the UI can warn before a clash happens.
--
-- Returns a flat list of { chord=, label= } for every TB-assigned keybind.
function addon.CollectTotemBuddyKeybinds()
    local out = {}

    for _, set in ipairs(addon.GetSets and addon.GetSets() or {}) do
        if set.keybind and set.keybind ~= "" then
            table.insert(out, { chord = set.keybind, label = "Set: " .. (set.name or "?") })
        end
    end

    for spellID, chord in pairs(TotemBuddyDB and TotemBuddyDB.quickReactKeybinds or {}) do
        if chord and chord ~= "" then
            table.insert(out, { chord = chord, label = "Quick: " .. (addon.GetTotemName(spellID) or spellID) })
        end
    end

    for key, chord in pairs(TotemBuddyDB and TotemBuddyDB.shieldKeybinds or {}) do
        if chord and chord ~= "" then
            local def = addon.SHIELD_BY_KEY and addon.SHIELD_BY_KEY[key]
            local nm = def and addon.GetTotemName(def.spellID) or key
            table.insert(out, { chord = chord, label = "Shield: " .. nm })
        end
    end

    for key, chord in pairs(TotemBuddyDB and TotemBuddyDB.dispelKeybinds or {}) do
        if chord and chord ~= "" then
            local def = addon.DISPEL_BY_KEY and addon.DISPEL_BY_KEY[key]
            local nm = def and addon.GetTotemName(def.spellID) or key
            table.insert(out, { chord = chord, label = "Dispel: " .. nm })
        end
    end

    return out
end

-- Return the label of the FIRST existing TB binding that already uses `chord`,
-- ignoring the one identified by `excludeLabel` (so re-binding the same slot
-- doesn't flag itself). Returns nil if there's no clash.
function addon.FindKeybindConflict(chord, excludeLabel)
    if not chord or chord == "" then return nil end
    for _, b in ipairs(addon.CollectTotemBuddyKeybinds()) do
        if b.chord == chord and b.label ~= excludeLabel then
            return b.label
        end
    end
    return nil
end

-- Print a chat warning if `chord` clashes with another TB binding. Non-blocking:
-- the override still applies (last-writer-wins), the user just gets told.
function addon.WarnKeybindConflict(chord, excludeLabel)
    local clash = addon.FindKeybindConflict(chord, excludeLabel)
    if clash then
        print("|cFFFFFF00TotemBuddy:|r " .. chord .. " is already bound to |cFFFFFFFF"
            .. clash .. "|r — the older binding will stop working.")
    end
    return clash
end

-- Capture the next key chord and pass it (e.g. "SHIFT-1") to onCaptured.
-- Escape calls onCaptured(nil) to clear. Modifier-only presses are ignored.
local MODIFIER_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
}
function addon.CaptureKeybind(frame, onCaptured)
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(false)
    frame:SetScript("OnKeyDown", function(self, key)
        self:EnableKeyboard(false)
        self:SetPropagateKeyboardInput(true)
        self:SetScript("OnKeyDown", nil)

        if key == "ESCAPE" then
            onCaptured(nil)
            return
        end
        if MODIFIER_KEYS[key] then
            -- a modifier was pressed alone; re-arm and wait for the real key
            addon.CaptureKeybind(frame, onCaptured)
            return
        end

        local chord = ""
        if IsAltKeyDown() then chord = chord .. "ALT-" end
        if IsControlKeyDown() then chord = chord .. "CTRL-" end
        if IsShiftKeyDown() then chord = chord .. "SHIFT-" end
        onCaptured(chord .. key)
    end)
end

-- ── Shared keybind context menu ──────────────────────────────────────────────

local keybindMenu
local keybindCapture

local function GetKeybindMenu()
    if keybindMenu then return keybindMenu end

    local f = CreateFrame("Frame", "TotemBuddyKeybindMenu", UIParent, "BackdropTemplate")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetSize(174, 100)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.97)
    f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    -- Spell name
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetPoint("TOPRIGHT", -10, -10)
    title:SetJustifyH("LEFT")
    title:SetTextColor(1, 0.82, 0)
    f.title = title

    -- Current chord
    local bindLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bindLabel:SetPoint("TOPLEFT", 10, -27)
    bindLabel:SetPoint("TOPRIGHT", -10, -27)
    bindLabel:SetJustifyH("LEFT")
    f.bindLabel = bindLabel

    -- Divider
    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  6, -42)
    div:SetPoint("TOPRIGHT", -6, -42)
    div:SetColorTexture(0.4, 0.4, 0.4, 0.6)

    local function MakeRow(yOff, label)
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(156, 22)
        btn:SetPoint("TOPLEFT", 8, yOff)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0)
        btn.bg = bg
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        txt:SetPoint("LEFT", 6, 0)
        txt:SetText(label)
        btn.txt = txt
        return btn
    end

    f.setBtn   = MakeRow(-49, "Set Keybind")
    f.clearBtn = MakeRow(-73, "Clear Keybind")

    f.setBtn.txt:SetTextColor(0.9, 0.9, 0.9)

    f.setBtn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.2, 0.4, 0.8, 0.5) end)
    f.setBtn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0, 0, 0, 0) end)

    -- Click-off blocker sits behind the menu in the same strata group
    local blocker = CreateFrame("Frame", nil, UIParent)
    blocker:SetAllPoints()
    blocker:EnableMouse(true)
    blocker:SetFrameStrata("FULLSCREEN")
    blocker:SetScript("OnMouseDown", function() f:Hide() end)
    blocker:Hide()
    f.blocker = blocker

    f:SetScript("OnHide", function(self)
        self.blocker:Hide()
        self:EnableKeyboard(false)
        self:SetPropagateKeyboardInput(true)
    end)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide() end
    end)

    keybindMenu = f
    return f
end

local function GetKeybindCapture()
    if keybindCapture then return keybindCapture end

    local f = CreateFrame("Frame", "TotemBuddyKeybindCapture", UIParent, "BackdropTemplate")
    f:SetSize(190, 66)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.15, 0.97)
    f:SetBackdropBorderColor(0.3, 0.3, 0.9, 1)

    local header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", 10, -10)
    header:SetTextColor(0.6, 0.6, 0.6)
    header:SetText("Setting keybind for:")
    f.header = header

    local nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 10, -26)
    nameLabel:SetTextColor(1, 0.82, 0)
    f.nameLabel = nameLabel

    local prompt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    prompt:SetPoint("TOPLEFT", 10, -44)
    prompt:SetTextColor(0.85, 0.85, 0.85)
    prompt:SetText("Press a key...  (Esc to cancel)")
    f.prompt = prompt

    keybindCapture = f
    return f
end

-- Show a right-click keybind context menu anchored to a button.
-- onSet() is called when the user picks "Set Keybind".
-- onClear() is called when the user picks "Clear Keybind" (only enabled when chord is set).
function addon.ShowKeybindMenu(anchor, spellName, currentChord, onSet, onClear)
    local f = GetKeybindMenu()

    f.title:SetText(spellName or "Keybind")
    if currentChord then
        f.bindLabel:SetText("|cFFFFFF00" .. currentChord .. "|r")
        f.clearBtn.txt:SetTextColor(0.9, 0.4, 0.4)
        f.clearBtn:SetScript("OnEnter", function(s) s.bg:SetColorTexture(0.6, 0.2, 0.2, 0.5) end)
        f.clearBtn:SetScript("OnLeave", function(s) s.bg:SetColorTexture(0, 0, 0, 0) end)
        f.clearBtn:SetScript("OnClick", function()
            f:Hide()
            if onClear then onClear() end
        end)
    else
        f.bindLabel:SetText("|cFF666666No keybind set|r")
        f.clearBtn.txt:SetTextColor(0.35, 0.35, 0.35)
        f.clearBtn:SetScript("OnEnter", nil)
        f.clearBtn:SetScript("OnLeave", nil)
        f.clearBtn:SetScript("OnClick", nil)
    end

    f.setBtn:SetScript("OnClick", function()
        f:Hide()
        if onSet then onSet() end
    end)

    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "BOTTOMRIGHT", -2, -2)

    f:EnableKeyboard(true)
    f:SetPropagateKeyboardInput(false)
    f.blocker:Show()
    f:Show()
    f:Raise()
end

-- Show a small capture overlay near anchor; calls onCaptured(chord) when done.
function addon.ShowKeybindCapture(anchor, spellName, onCaptured)
    local f = GetKeybindCapture()
    f.nameLabel:SetText(spellName or "")
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "BOTTOMRIGHT", -2, -2)
    f:Show()
    f:Raise()

    addon.CaptureKeybind(f, function(chord)
        f:Hide()
        onCaptured(chord)
    end)
end
