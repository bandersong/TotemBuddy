-- TotemBuddy: Core Module
-- Addon namespace, constants, data tables, and utility functions

local addonName, addon = ...

-- Export addon table for other modules
addon.addonName = addonName

-- Default saved variables (using spell IDs for language-independent storage)
addon.defaults = {
    activeEarth = 8075,  -- Strength of Earth Totem
    activeFire = 3599,   -- Searing Totem
    activeWater = 5675,  -- Mana Spring Totem
    activeAir = 8512,    -- Windfury Totem
    barPos = { point = "CENTER", x = 0, y = -200 },
    showTimers = true,
    locked = false,
    popupDirection = "UP", -- UP, DOWN, LEFT, RIGHT
    timerPosition = "ABOVE", -- ABOVE, BELOW, LEFT, RIGHT, ON (ON only for icons style)
    timerStyle = "bars", -- "bars" or "icons"
    timerFontSize = "NORMAL", -- "SMALL", "NORMAL", "LARGE"
    alwaysShowPopup = false, -- Always show popup bars instead of on hover
    elementOrder = { "Earth", "Fire", "Water", "Air" }, -- Order of element groups
    totemOrder = { -- Custom totem order per element (empty = use default)
        Earth = {},
        Fire = {},
        Water = {},
        Air = {},
    },
    hiddenTotems = { -- Totems hidden from popup
        Earth = {},
        Fire = {},
        Water = {},
        Air = {},
    },
    showReincarnation = true, -- Show Reincarnation tracker button
    showWeaponBuffs = true, -- Show Weapon Buffs button
    dimOutOfRange = true, -- Dim totem icons when player is out of range
    popupModifier = "NONE", -- Modifier key required to show popup (NONE, SHIFT, CTRL, ALT)
    greyOutPlacedTotem = true, -- Grey out icon when placed totem differs from active
    barScale = 1.0, -- Scale factor for the action bar
    disablePopupInCombat = false, -- Completely disable popup bars in combat (not just hide)
    showTooltips = true, -- Show tooltips on hover
    showLowManaOverlay = true, -- Show blue overlay when low mana and no active totem
    totemExpirySound = true, -- Master enable/disable expiry sounds
    totemExpirySoundIDs = { -- Per-element sound IDs (0 = None)
        Earth = 8959,
        Fire = 8959,
        Water = 8959,
        Air = 8959,
    },
    customMacros = {}, -- User-defined macros with template placeholders
    defaultMacrosEnabled = { -- Toggle default macros on/off
        TBEarth = true,
        TBFire = true,
        TBWater = true,
        TBAir = true,
        TBAll = true,
    },
}

-- Totem data: spellID (universal across all languages), duration in seconds
-- Names are looked up dynamically via GetSpellInfo(spellID)
addon.TOTEMS = {
    Earth = {
        { spellID = 2484, duration = 45 },   -- Earthbind Totem
        { spellID = 5730, duration = 15 },   -- Stoneclaw Totem
        { spellID = 8071, duration = 120 },  -- Stoneskin Totem
        { spellID = 8075, duration = 120 },  -- Strength of Earth Totem
        { spellID = 8143, duration = 120 },  -- Tremor Totem
        { spellID = 2062, duration = 120 },  -- Earth Elemental Totem
    },
    Fire = {
        { spellID = 1535, duration = 5 },    -- Fire Nova Totem
        { spellID = 8227, duration = 120 },  -- Flametongue Totem
        { spellID = 8181, duration = 120 },  -- Frost Resistance Totem
        { spellID = 8190, duration = 20 },   -- Magma Totem
        { spellID = 3599, duration = 60 },   -- Searing Totem
        { spellID = 30706, duration = 120 }, -- Totem of Wrath
        { spellID = 2894, duration = 120 },  -- Fire Elemental Totem
    },
    Water = {
        { spellID = 8170, duration = 120 },  -- Disease Cleansing Totem
        { spellID = 8184, duration = 120 },  -- Fire Resistance Totem
        { spellID = 5394, duration = 120 },  -- Healing Stream Totem
        { spellID = 5675, duration = 120 },  -- Mana Spring Totem
        { spellID = 16190, duration = 12 },  -- Mana Tide Totem
        { spellID = 8166, duration = 120 },  -- Poison Cleansing Totem
    },
    Air = {
        { spellID = 8835, duration = 120 },  -- Grace of Air Totem
        { spellID = 8177, duration = 45 },   -- Grounding Totem
        { spellID = 10595, duration = 120 }, -- Nature Resistance Totem
        { spellID = 6495, duration = 300 },  -- Sentry Totem
        { spellID = 25908, duration = 120 }, -- Tranquil Air Totem
        { spellID = 8512, duration = 120 },  -- Windfury Totem
        { spellID = 15107, duration = 120 }, -- Windwall Totem
        { spellID = 3738, duration = 120 },  -- Wrath of Air Totem
    },
}

-- Font size mapping for timers
addon.fontSizes = {
    SMALL = { size = 10 },
    NORMAL = { size = 12 },
    LARGE = { size = 14 },
}

-- Element colors
addon.ELEMENT_COLORS = {
    Earth = { r = 0.6, g = 0.4, b = 0.2 },
    Fire = { r = 1.0, g = 0.3, b = 0.1 },
    Water = { r = 0.2, g = 0.5, b = 1.0 },
    Air = { r = 0.7, g = 0.7, b = 0.9 },
}

-- Map totem spell IDs to whether they provide a player buff (for out-of-range detection)
-- Value is true if the totem provides a buff that can be checked
addon.TOTEM_PROVIDES_BUFF = {
    [8835] = true,   -- Grace of Air Totem
    [25908] = true,  -- Tranquil Air Totem
    [3738] = true,   -- Wrath of Air Totem
    [15107] = true,  -- Windwall Totem
    [8075] = true,   -- Strength of Earth Totem
    [8071] = true,   -- Stoneskin Totem
    [5675] = true,   -- Mana Spring Totem
    [8184] = true,   -- Fire Resistance Totem
    [8181] = true,   -- Frost Resistance Totem
    [10595] = true,  -- Nature Resistance Totem
    [8227] = true,   -- Flametongue Totem
    [30706] = true,  -- Totem of Wrath
}

-- Element order for display
addon.ELEMENT_ORDER = { "Earth", "Fire", "Water", "Air" }

-- Expiry sound options (0 = None)
addon.EXPIRY_SOUNDS = {
    { id = 0, name = "None" },
    -- Alert sounds
    { id = 8959, name = "Raid Warning" },
    { id = 8960, name = "Ready Check" },
    { id = 9379, name = "PvP Flag Taken" },
    { id = 11466, name = "Not Prepared" },
    { id = 8066, name = "Low Health" },
    -- UI sounds
    { id = 7355, name = "Alarm Clock" },
    { id = 3081, name = "Auction Close" },
    { id = 878, name = "Quest Complete" },
    { id = 888, name = "Level Up" },
    { id = 120, name = "Loot Coin" },
    { id = 3175, name = "Map Ping" },
    -- Fun sounds
    { id = 416, name = "Murloc Aggro" },
    { id = 3605, name = "Owl Screech" },
    { id = 12571, name = "Headless Horseman" },
    { id = 9036, name = "Wolf Howl" },
    { id = 3337, name = "Drum Hit" },
    -- Game sounds (file path based)
    { path = "Sound/Creature/Peon/PeonBuildingComplete1.ogg", name = "Peon Work Complete" },
    { path = "Sound/Interface/iquestupdate.ogg", name = "Quest Update" },
    { path = "Sound/Interface/AuctionWindowOpen.ogg", name = "Auction Open" },
    { path = "Sound/Doodad/BoatDockedWarning.ogg", name = "Boat Docked" },
    { path = "Sound/Doodad/BellTollAlliance.ogg", name = "Bell Toll Alliance" },
    { path = "Sound/Doodad/BellTollHorde.ogg", name = "Bell Toll Horde" },
    { path = "Sound/Doodad/Hellfire_Raid_FX_Explosion05.ogg", name = "Explosion" },
    { path = "Sound/Doodad/PortcullisActive_Closed.ogg", name = "Shing!" },
    { path = "Sound/Doodad/PVP_Lordaeron_Door_Open.ogg", name = "Wham!" },
    { path = "Sound/Doodad/SimonGame_LargeBlueTree.ogg", name = "Simon Chime" },
    { path = "Sound/Event Sounds/Event_wardrum_ogre.ogg", name = "War Drums" },
    { path = "Sound/Spells/SimonGame_Visual_GameStart.ogg", name = "Humm" },
    { path = "Sound/Spells/SimonGame_Visual_BadPress.ogg", name = "Short Circuit" },
    { path = "Sound/Creature/OrcMaleShadyNPC/OrcMaleShadyNPCGreeting05.ogg", name = "Zug Zug" },
}

-- Totem slot indices (for tracking active totems)
addon.TOTEM_SLOTS = {
    Fire = 1,
    Earth = 2,
    Water = 3,
    Air = 4,
}

-- Weapon buff data: spellID (universal across all languages)
-- Names are looked up dynamically via GetSpellInfo(spellID)
addon.WEAPON_BUFFS = {
    { spellID = 8017 },  -- Rockbiter Weapon
    { spellID = 8024 },  -- Flametongue Weapon
    { spellID = 8033 },  -- Frostbrand Weapon
    { spellID = 8232 },  -- Windfury Weapon
}

-- Ankh item ID for Reincarnation
addon.ANKH_ITEM_ID = 17030

-- Totem item IDs (required in inventory to cast totems of each element)
addon.TOTEM_ITEM_IDS = {
    Earth = 5175,
    Fire = 5176,
    Water = 5177,
    Air = 5178,
}

-- Shared UI state
addon.UI = {
    actionBarFrame = nil,
    timerFrame = nil,
    timerBars = {},
    activeTotemButtons = {},
    popupButtons = {},
    popupContainers = {},
    reincarnationButton = nil,
    weaponBuffButton = nil,
    weaponBuffPopup = nil,
    weaponBuffPopupButtons = {},
    buttonCounter = 0,
    configWindow = nil,
    configTotemRows = {},
}

addon.state = {
    popupVisible = false,
    popupHideDelay = 0,
    weaponBuffPopupVisible = false,
    activeMainHandBuff = nil,
    activeOffHandBuff = nil,
    pendingActiveUpdates = {},
    preCastMainHandEnchant = false,
    preCastOffHandEnchant = false,
    pendingVisibilityUpdate = false,
    totemSoundPlayed = { -- Track per-slot to prevent spam
        [1] = false, [2] = false, [3] = false, [4] = false
    },
}

-- Utility: Check if player is a Shaman
function addon.IsShaman()
    local _, class = UnitClass("player")
    return class == "SHAMAN"
end

-- Utility: Check if player has the totem item for an element
function addon.HasTotemItem(element)
    local itemID = addon.TOTEM_ITEM_IDS[element]
    if not itemID then return false end
    return GetItemCount(itemID) > 0
end

-- Utility: Get localized totem name from spell ID
function addon.GetTotemName(spellID)
    if not spellID then return nil end
    local name = GetSpellInfo(spellID)
    return name
end

-- Utility: Get totem icon from spell ID
function addon.GetTotemIcon(spellID)
    if not spellID then return nil end
    return GetSpellTexture(spellID)
end

-- Utility: Get localized weapon buff name from spell ID
function addon.GetWeaponBuffName(spellID)
    if not spellID then return nil end
    return GetSpellInfo(spellID)
end

-- Utility: Get weapon buff icon from spell ID
function addon.GetWeaponBuffIcon(spellID)
    if not spellID then return nil end
    return GetSpellTexture(spellID)
end

-- Utility: Get totem data by spell ID
function addon.GetTotemBySpellID(spellID)
    for element, totems in pairs(addon.TOTEMS) do
        for _, totem in ipairs(totems) do
            if totem.spellID == spellID then
                return totem, element
            end
        end
    end
    return nil, nil
end

-- Utility: Get totem data by spell ID (alias for compatibility)
function addon.GetTotemData(spellID)
    return addon.GetTotemBySpellID(spellID)
end

-- Get element order (saved or default)
function addon.GetElementOrder()
    if TotemBuddyDB and TotemBuddyDB.elementOrder then
        return TotemBuddyDB.elementOrder
    end
    return addon.ELEMENT_ORDER
end

-- Check if a totem spell is trained (accepts spell ID)
-- Uses localized name lookup to find any trained rank of the spell
function addon.IsTotemKnown(spellID)
    if not spellID then return false end
    local name = GetSpellInfo(spellID)
    if not name then return false end
    -- GetSpellInfo with a name returns info for the trained rank (if any)
    local _, _, _, _, _, _, trainedSpellID = GetSpellInfo(name)
    return trainedSpellID ~= nil
end

-- Get the highest trained rank's spell ID for a base spell
-- Useful for tooltip display or when we need the actual trained spell ID
function addon.GetHighestRankSpellID(baseSpellID)
    local name = GetSpellInfo(baseSpellID)
    if not name then return nil end
    local _, _, _, _, _, _, trainedSpellID = GetSpellInfo(name)
    return trainedSpellID
end

-- Check if a totem is hidden by the user (accepts spell ID)
function addon.IsTotemHidden(element, spellID)
    if not TotemBuddyDB or not TotemBuddyDB.hiddenTotems or not TotemBuddyDB.hiddenTotems[element] then
        return false
    end
    for _, hidden in ipairs(TotemBuddyDB.hiddenTotems[element]) do
        if hidden == spellID then
            return true
        end
    end
    return false
end

-- Check if the required popup modifier key is pressed
function addon.IsPopupModifierPressed()
    local modifier = TotemBuddyDB and TotemBuddyDB.popupModifier or "NONE"
    if modifier == "NONE" then
        return true
    elseif modifier == "SHIFT" then
        return IsShiftKeyDown()
    elseif modifier == "CTRL" then
        return IsControlKeyDown()
    elseif modifier == "ALT" then
        return IsAltKeyDown()
    end
    return true
end

-- Check if player has the buff from a totem (for out-of-range detection)
-- Returns: true = has buff (in range), false = no buff (out of range), nil = totem doesn't provide a buff
-- Now accepts either spellID or localized totem name
function addon.HasTotemBuff(totemIdentifier)
    local spellID
    if type(totemIdentifier) == "number" then
        spellID = totemIdentifier
    else
        -- Try to find spell ID from name (for backward compatibility with GetTotemInfo)
        local name, _, _, _, _, _, sid = GetSpellInfo(totemIdentifier)
        spellID = sid
        -- If we still don't have a spell ID, try to match to our totem list
        if not spellID then
            for element, totems in pairs(addon.TOTEMS) do
                for _, totem in ipairs(totems) do
                    local totemName = addon.GetTotemName(totem.spellID)
                    -- Strip rank suffix from both for comparison
                    local baseName = totemIdentifier:gsub("%s+[IVXLCDM]+$", "")
                    if totemName and totemName:find(baseName, 1, true) then
                        spellID = totem.spellID
                        break
                    end
                end
                if spellID then break end
            end
        end
    end

    if not spellID or not addon.TOTEM_PROVIDES_BUFF[spellID] then
        return nil -- Totem doesn't provide a player buff we can check
    end

    -- Get localized totem name for buff checking
    local totemName = addon.GetTotemName(spellID)
    if not totemName then return nil end

    -- Check if player has the buff (using localized name)
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        -- Check for exact match or partial match (buff name may be shorter)
        if name == totemName or totemName:find(name, 1, true) or name:find(totemName:gsub(" Totem$", ""), 1, true) then
            return true
        end
    end
    return false
end

-- Check if player has enough mana to cast a totem by spell ID
function addon.HasManaForTotem(spellID)
    if not spellID then return true end
    -- Get the spell name to check the trained (max) rank
    local spellName = GetSpellInfo(spellID)
    if not spellName then return true end
    -- IsUsableSpell checks the highest trained rank and returns (usable, noMana)
    local usable, noMana = IsUsableSpell(spellName)
    -- If noMana is true, player doesn't have enough mana
    if noMana then
        return false
    end
    -- If usable is false but not due to mana, still consider mana sufficient
    return true
end

-- Check if a weapon buff spell is known (accepts spell ID)
-- Uses localized name lookup to find any trained rank of the spell
function addon.IsWeaponBuffKnown(spellID)
    if not spellID then return false end
    local name = GetSpellInfo(spellID)
    if not name then return false end
    -- GetSpellInfo with a name returns info for the trained rank (if any)
    local _, _, _, _, _, _, trainedSpellID = GetSpellInfo(name)
    return trainedSpellID ~= nil
end

-- Get list of known weapon buffs
function addon.GetKnownWeaponBuffs()
    local known = {}
    for _, buff in ipairs(addon.WEAPON_BUFFS) do
        if addon.IsWeaponBuffKnown(buff.spellID) then
            table.insert(known, buff)
        end
    end
    return known
end

-- Get current weapon enchant info and match to weapon buff name
function addon.GetCurrentWeaponBuff()
    local hasMainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID,
          hasOffHandEnchant, offHandExpiration, offHandCharges, offHandEnchantID = GetWeaponEnchantInfo()

    -- Clear tracked buffs if enchant is gone
    if not hasMainHandEnchant then
        addon.state.activeMainHandBuff = nil
    end
    if not hasOffHandEnchant then
        addon.state.activeOffHandBuff = nil
    end

    -- Return info about current enchants
    return {
        mainHand = hasMainHandEnchant and mainHandEnchantID or nil,
        mainHandTime = hasMainHandEnchant and mainHandExpiration or nil,
        mainHandBuff = addon.state.activeMainHandBuff,
        offHand = hasOffHandEnchant and offHandEnchantID or nil,
        offHandTime = hasOffHandEnchant and offHandExpiration or nil,
        offHandBuff = addon.state.activeOffHandBuff,
    }
end

-- Get weapon buff data by spell ID
function addon.GetWeaponBuffBySpellID(spellID)
    for _, buff in ipairs(addon.WEAPON_BUFFS) do
        if buff.spellID == spellID then
            return buff
        end
    end
    return nil
end

-- Check if a spell name is a weapon buff and return the buff data
-- Now works with localized names by looking up each buff's name dynamically
function addon.GetWeaponBuffByName(spellName)
    for _, buff in ipairs(addon.WEAPON_BUFFS) do
        local name = addon.GetWeaponBuffName(buff.spellID)
        if name == spellName then
            return buff
        end
    end
    return nil
end

-- Get totems for an element in custom order (if set)
-- savedOrder now contains spell IDs instead of names
function addon.GetOrderedTotems(element)
    local savedOrder = TotemBuddyDB and TotemBuddyDB.totemOrder and TotemBuddyDB.totemOrder[element]
    if not savedOrder or #savedOrder == 0 then
        return addon.TOTEMS[element] -- Use default order
    end

    -- Build ordered list from saved spell IDs
    local ordered = {}
    for _, savedID in ipairs(savedOrder) do
        for _, totem in ipairs(addon.TOTEMS[element]) do
            if totem.spellID == savedID then
                table.insert(ordered, totem)
                break
            end
        end
    end

    -- Add any totems not in saved order (e.g., newly added)
    for _, totem in ipairs(addon.TOTEMS[element]) do
        local found = false
        for _, savedID in ipairs(savedOrder) do
            if totem.spellID == savedID then
                found = true
                break
            end
        end
        if not found then
            table.insert(ordered, totem)
        end
    end

    return ordered
end

-- Format time for display
function addon.FormatTime(seconds)
    if seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    else
        return string.format("%d", seconds)
    end
end

-- Process a macro template, replacing placeholders with active totem names
-- Placeholders: {earth}, {fire}, {water}, {air}
function addon.ProcessMacroTemplate(template)
    if not template then return "" end

    local result = template

    -- Get active totem names for each element
    local replacements = {
        ["{earth}"] = addon.GetTotemName(TotemBuddyDB.activeEarth) or "",
        ["{fire}"] = addon.GetTotemName(TotemBuddyDB.activeFire) or "",
        ["{water}"] = addon.GetTotemName(TotemBuddyDB.activeWater) or "",
        ["{air}"] = addon.GetTotemName(TotemBuddyDB.activeAir) or "",
    }

    -- Also support uppercase variants
    replacements["{Earth}"] = replacements["{earth}"]
    replacements["{Fire}"] = replacements["{fire}"]
    replacements["{Water}"] = replacements["{water}"]
    replacements["{Air}"] = replacements["{air}"]

    -- Replace all placeholders
    for placeholder, totemName in pairs(replacements) do
        result = result:gsub(placeholder:gsub("[{}]", "%%%1"), totemName)
    end

    return result
end
