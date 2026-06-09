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
