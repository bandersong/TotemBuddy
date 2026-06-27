-- TotemBuddy: Cooldown / Proc Cluster
-- A small movable, DISPLAY-ONLY bar of trackers for the cooldowns and buffs a
-- resto shaman watches: Nature's Swiftness, Mana Tide Totem, your equipped
-- trinkets, and your Healing Way stacks on the tank. Nothing here casts, so
-- there are no secure/combat restrictions -- it's pure information.
--
--   * spell trackers  -> GetSpellCooldown(spellID)         (swipe + ready glow)
--   * trinket trackers-> GetInventoryItemCooldown(13/14)   (swipe + ready glow)
--   * buff trackers   -> ScanUnitAura (Healing Way stacks on focus/target)
--   * Nature's Swiftness "active" -> gold pulse on its icon when the buff is up

local addonName, addon = ...

local BTN_SIZE = 34
local BTN_GAP = 4
local PAD = 6

local bar
local trackers = {}   -- pool of tracker frames

-- Build the spec list of what to show right now (order matters).
local function BuildSpecs()
    local specs = {}
    -- Only show NS / Mana Tide if the player actually trained them (talents).
    if addon.IsTotemKnown(addon.NS_SPELL) then
        table.insert(specs, { kind = "spell", spellID = addon.NS_SPELL, ns = true })
    end
    if addon.IsTotemKnown(addon.MANA_TIDE_SPELL) then
        table.insert(specs, { kind = "spell", spellID = addon.MANA_TIDE_SPELL })
    end
    if TotemBuddyDB.cooldownTrackTrinkets then
        if GetInventoryItemTexture("player", 13) then table.insert(specs, { kind = "item", slot = 13 }) end
        if GetInventoryItemTexture("player", 14) then table.insert(specs, { kind = "item", slot = 14 }) end
    end
    if TotemBuddyDB.showHealingWay then
        table.insert(specs, { kind = "buff", spellID = addon.HEALING_WAY_BUFF, units = { "focus", "target" } })
    end
    return specs
end

local function CreateBarFrame()
    if bar then return bar end
    local f = CreateFrame("Frame", "TotemBuddyCooldownBar", UIParent, "BackdropTemplate")
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)

    local pos = TotemBuddyDB.cooldownBarPos or { point = "CENTER", x = 0, y = -380 }
    f:SetPoint(pos.point or "CENTER", pos.x or 0, pos.y or -380)
    f:SetScale(TotemBuddyDB.cooldownBarScale or 1.0)

    f:SetScript("OnDragStart", function(self)
        if not TotemBuddyDB.cooldownBarLocked and not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        TotemBuddyDB.cooldownBarPos = { point = point, x = x, y = y }
    end)

    bar = f
    return f
end

local function EnsureTracker(i)
    if trackers[i] then return trackers[i] end
    local t = CreateFrame("Frame", "TotemBuddyCDTracker" .. i, bar)
    t:SetSize(BTN_SIZE, BTN_SIZE)

    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetPoint("TOPLEFT", 2, -2)
    t.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    t.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    t.border = CreateFrame("Frame", nil, t, "BackdropTemplate")
    t.border:SetPoint("TOPLEFT", -1, 1)
    t.border:SetPoint("BOTTOMRIGHT", 1, -1)
    t.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
    t.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local cd = CreateFrame("Cooldown", nil, t, "CooldownFrameTemplate")
    cd:SetAllPoints(t.icon)
    cd:SetDrawEdge(false)
    cd:SetHideCountdownNumbers(false)
    cd:EnableMouse(false)
    t.cooldown = cd

    local overlay = CreateFrame("Frame", nil, t)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(t:GetFrameLevel() + 8)
    t.countText = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    t.countText:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -2, 2)
    t.countText:SetTextColor(1, 1, 1)

    -- Hover tooltip (uses spec set in RefreshCooldownBar)
    t:EnableMouse(true)
    t:SetScript("OnEnter", function(self)
        if TotemBuddyDB.showTooltips == false or not self.spec then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.spec.kind == "item" then
            GameTooltip:SetInventoryItem("player", self.spec.slot)
        elseif self.spec.spellID then
            GameTooltip:SetSpellByID(self.spec.spellID)
        end
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)

    trackers[i] = t
    return t
end

-- (Re)build the visible trackers from the current spec list. Cheap; safe in combat.
function addon.RefreshCooldownBar()
    if not bar then return end
    bar:SetScale(TotemBuddyDB.cooldownBarScale or 1.0)

    if not TotemBuddyDB.showCooldownBar then
        bar:Hide()
        return
    end

    local specs = BuildSpecs()
    for i, spec in ipairs(specs) do
        local t = EnsureTracker(i)
        t.spec = spec
        -- static icon
        if spec.kind == "item" then
            t.icon:SetTexture(GetInventoryItemTexture("player", spec.slot))
        else
            t.icon:SetTexture(GetSpellTexture(spec.spellID))
        end
        t:ClearAllPoints()
        t:SetPoint("LEFT", bar, "LEFT", PAD + (i - 1) * (BTN_SIZE + BTN_GAP), 0)
        t:Show()
    end
    for i = #specs + 1, #trackers do
        trackers[i]:Hide()
        trackers[i].spec = nil
    end

    local n = #specs
    if n == 0 then
        bar:Hide()
    else
        bar:SetSize(PAD * 2 + n * BTN_SIZE + (n - 1) * BTN_GAP, BTN_SIZE + PAD * 2)
        bar:Show()
    end
    addon.UpdateCooldownBar()
end

-- Per-tick value update: swipes, ready glow, Healing Way stacks, NS pulse.
function addon.UpdateCooldownBar()
    if not bar or not bar:IsShown() then return end
    local now = GetTime()
    local pulse = 0.6 + 0.4 * math.abs(math.sin(now * 3)) -- gold pulse alpha

    for _, t in ipairs(trackers) do
        if t:IsShown() and t.spec then
            local spec = t.spec

            if spec.kind == "buff" then
                -- Healing Way stacks on the tank (focus first, then target)
                local name = addon.GetTotemName(spec.spellID)
                local count, duration, expiration
                for _, u in ipairs(spec.units) do
                    count, duration, expiration = addon.ScanUnitAura(u, name, "PLAYER")
                    if count then break end
                end
                if count and count > 0 then
                    t.icon:SetDesaturated(false)
                    t.icon:SetAlpha(1)
                    t.countText:SetText(count)
                    t.border:SetBackdropBorderColor(0.2, 0.8, 0.4, 1)
                    if expiration and duration and expiration > 0 and duration > 0 then
                        t.cooldown:SetCooldown(expiration - duration, duration)
                    else
                        t.cooldown:Clear()
                    end
                else
                    t.icon:SetDesaturated(true)
                    t.icon:SetAlpha(0.4)
                    t.countText:SetText("")
                    t.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                    t.cooldown:Clear()
                end

            else
                -- spell or item cooldown
                local start, duration, enable
                if spec.kind == "item" then
                    start, duration, enable = GetInventoryItemCooldown("player", spec.slot)
                else
                    start, duration, enable = GetSpellCooldown(spec.spellID)
                end
                t.countText:SetText("")

                local onCD = start and duration and enable == 1 and duration > 1.5
                if onCD then
                    t.cooldown:SetCooldown(start, duration)
                    t.icon:SetDesaturated(true)
                    t.icon:SetAlpha(0.6)
                    t.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                else
                    t.cooldown:Clear()
                    t.icon:SetDesaturated(false)
                    t.icon:SetAlpha(1)
                    -- ready: subtle green border
                    t.border:SetBackdropBorderColor(0.2, 0.7, 0.3, 1)
                end

                -- Nature's Swiftness active = gold pulsing border (it's a buff, not a CD)
                if spec.ns and TotemBuddyDB.nsGlowEnabled then
                    local nsName = addon.GetTotemName(addon.NS_SPELL)
                    local active = addon.ScanUnitAura("player", nsName, "PLAYER")
                    if active then
                        t.icon:SetDesaturated(false)
                        t.icon:SetAlpha(1)
                        t.border:SetBackdropBorderColor(1, 0.85, 0.1, pulse)
                    end
                end
            end
        end
    end
end

function addon.CreateCooldownBar()
    CreateBarFrame()
    addon.RefreshCooldownBar()
end
