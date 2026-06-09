-- TotemBuddy: Sets Module
-- Named totem sets: save the current four active totems as a named preset,
-- list them, apply one, or delete one. Applying writes the set's totems into
-- the active slots via addon.SetActiveTotem, which already handles combat
-- lockdown (secure updates are queued and replayed on PLAYER_REGEN_ENABLED).

local addonName, addon = ...

-- Canonical element order for sets (independent of the user's display order)
local SET_ELEMENTS = { "Earth", "Fire", "Water", "Air" }
addon.SET_ELEMENTS = SET_ELEMENTS

-- Ensure the sets array exists and return it
local function EnsureSets()
    if not TotemBuddyDB.sets then TotemBuddyDB.sets = {} end
    return TotemBuddyDB.sets
end

-- Find a set index by case-insensitive name; returns index or nil
local function FindSetIndex(name)
    if not name or name == "" then return nil end
    local target = name:lower()
    for i, set in ipairs(EnsureSets()) do
        if set.name and set.name:lower() == target then
            return i
        end
    end
    return nil
end
addon.FindSetIndex = FindSetIndex

-- Return the sets array
function addon.GetSets()
    return EnsureSets()
end

-- Save the current active totems as a named set.
-- Overwrites an existing set with the same name (case-insensitive).
-- Returns: set table, isNew (boolean) -- or nil if the name is blank.
function addon.SaveCurrentAsSet(name)
    name = name and name:trim() or ""
    if name == "" then return nil, false end

    local set = { name = name }
    for _, element in ipairs(SET_ELEMENTS) do
        set[element] = TotemBuddyDB["active" .. element]
    end

    local sets = EnsureSets()
    local existing = FindSetIndex(name)
    local isNew
    if existing then
        set.name = sets[existing].name       -- preserve original capitalization
        set.keybind = sets[existing].keybind -- preserve the existing keybind
        sets[existing] = set
        isNew = false
    else
        table.insert(sets, set)
        isNew = true
    end

    if addon.NotifySetsChanged then addon.NotifySetsChanged() end
    return set, isNew
end

-- Apply a set by index: write its totems into the active slots.
-- Reuses addon.SetActiveTotem (queues secure updates if in combat).
-- Returns: set table or nil.
function addon.ApplySetByIndex(index)
    local set = EnsureSets()[index]
    if not set then return nil end

    for _, element in ipairs(SET_ELEMENTS) do
        local spellID = set[element]
        if spellID then
            addon.SetActiveTotem(element, spellID)
        end
    end
    TotemBuddyDB.activeSet = index
    if addon.RefreshSetsTab then addon.RefreshSetsTab() end
    return set
end

-- Apply a set by name (case-insensitive). Returns set or nil.
function addon.ApplySetByName(name)
    local index = FindSetIndex(name)
    if not index then return nil end
    return addon.ApplySetByIndex(index)
end

-- Delete a set by name (case-insensitive). Returns the removed set or nil.
function addon.DeleteSetByName(name)
    local index = FindSetIndex(name)
    if not index then return nil end

    local sets = EnsureSets()
    local removed = table.remove(sets, index)

    -- Keep activeSet pointing at the right entry after the shift
    if TotemBuddyDB.activeSet == index then
        TotemBuddyDB.activeSet = nil
    elseif TotemBuddyDB.activeSet and TotemBuddyDB.activeSet > index then
        TotemBuddyDB.activeSet = TotemBuddyDB.activeSet - 1
    end

    if addon.NotifySetsChanged then addon.NotifySetsChanged() end
    return removed
end

-- Rename a set by index. Returns true, or false + reason string.
function addon.RenameSet(index, newName)
    newName = newName and newName:trim() or ""
    local set = EnsureSets()[index]
    if not set then return false, "no such set" end
    if newName == "" then return false, "name required" end
    local clash = FindSetIndex(newName)
    if clash and clash ~= index then
        return false, "a set named '" .. newName .. "' already exists"
    end
    set.name = newName
    if addon.NotifySetsChanged then addon.NotifySetsChanged() end
    return true
end

-- Move a set up (delta -1) or down (delta +1), swapping with its neighbor.
-- Keeps activeSet pointing at the same entries. Returns the new index or nil.
function addon.MoveSet(index, delta)
    local sets = EnsureSets()
    local target = index + delta
    if not sets[index] or not sets[target] then return nil end

    sets[index], sets[target] = sets[target], sets[index]
    if TotemBuddyDB.activeSet == index then
        TotemBuddyDB.activeSet = target
    elseif TotemBuddyDB.activeSet == target then
        TotemBuddyDB.activeSet = index
    end

    if addon.NotifySetsChanged then addon.NotifySetsChanged() end
    return target
end

-- Human-readable summary of a set's totems, e.g.
-- "Earth: Tremor Totem, Fire: Searing Totem, Water: Mana Spring Totem, Air: ..."
function addon.DescribeSet(set)
    local parts = {}
    for _, element in ipairs(SET_ELEMENTS) do
        local spellID = set[element]
        local name = spellID and addon.GetTotemName(spellID) or nil
        table.insert(parts, element .. ": " .. (name or "\226\128\148")) -- em dash
    end
    return table.concat(parts, ", ")
end
