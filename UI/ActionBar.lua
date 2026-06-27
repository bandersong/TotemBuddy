-- TotemBuddy: ActionBar Module
-- Main 4-button bar creation

local addonName, addon = ...

-- Local references
local ELEMENT_COLORS = addon.ELEMENT_COLORS
local TOTEM_SLOTS = addon.TOTEM_SLOTS
local GetTotemData = addon.GetTotemData
local GetElementOrder = addon.GetElementOrder
local IsPopupModifierPressed = addon.IsPopupModifierPressed

-- Update an active totem button's spell binding
function addon.UpdateActiveTotemButton(element)
    local btn = addon.UI.activeTotemButtons[element]
    if not btn then return end

    local activeKey = "active" .. element
    local spellID = TotemBuddyDB[activeKey]
    local totemData = GetTotemData(spellID)

    if totemData then
        -- Cast by name so WoW auto-selects highest trained rank
        local totemName = addon.GetTotemName(spellID)
        btn:SetAttribute("spell1", totemName)
        -- Get icon from spell ID
        btn.icon:SetTexture(addon.GetTotemIcon(spellID))
        btn.spellID = spellID
        btn.totemName = totemName  -- Cache localized name for tooltips
    end
end

-- Create the action bar with active totem buttons
function addon.CreateActionBarFrame()
    local direction = TotemBuddyDB.popupDirection or "UP"
    local isVertical = (direction == "LEFT" or direction == "RIGHT")

    local actionBarFrame = CreateFrame("Frame", "TotemBuddyBar", UIParent, "BackdropTemplate")
    if isVertical then
        actionBarFrame:SetSize(48, 200) -- Vertical bar
    else
        actionBarFrame:SetSize(200, 48) -- Horizontal bar
    end
    actionBarFrame:SetPoint(TotemBuddyDB.barPos.point, TotemBuddyDB.barPos.x, TotemBuddyDB.barPos.y)

    actionBarFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    actionBarFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    actionBarFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    actionBarFrame:SetMovable(true)
    actionBarFrame:EnableMouse(true)
    actionBarFrame:RegisterForDrag("LeftButton")
    actionBarFrame:SetScript("OnDragStart", function(self)
        if not TotemBuddyDB.locked and not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    actionBarFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        TotemBuddyDB.barPos = { point = point, x = x, y = y }
    end)

    addon.UI.actionBarFrame = actionBarFrame

    -- Apply scale from saved settings
    actionBarFrame:SetScale(TotemBuddyDB.barScale or 1.0)

    -- Create 4 active totem buttons
    for i, element in ipairs(GetElementOrder()) do
        local activeKey = "active" .. element
        local spellID = TotemBuddyDB[activeKey]
        local totemData = GetTotemData(spellID)
        local color = ELEMENT_COLORS[element]

        local btn = CreateFrame("Button", "TotemBuddyActive" .. element, actionBarFrame, "SecureActionButtonTemplate")
        btn:SetSize(40, 40)
        if isVertical then
            btn:SetPoint("TOP", 0, -8 - (i - 1) * 48) -- Stacked vertically
        else
            btn:SetPoint("LEFT", 8 + (i - 1) * 48, 0) -- Spaced horizontally
        end

        -- Add backdrop manually
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

        btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        btn.border:SetPoint("TOPLEFT", -2, 2)
        btn.border:SetPoint("BOTTOMRIGHT", 2, -2)
        btn.border:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
        })
        btn.border:SetBackdropBorderColor(color.r, color.g, color.b, 1)
        btn.border:EnableMouse(false) -- Don't intercept clicks

        -- Icon
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("CENTER")
        if totemData then
            icon:SetTexture(addon.GetTotemIcon(spellID))
        end
        btn.icon = icon

        -- Blue mana overlay (shown when low mana and no active totem)
        local manaOverlay = btn:CreateTexture(nil, "OVERLAY", nil, 1)
        manaOverlay:SetSize(36, 36)
        manaOverlay:SetPoint("CENTER")
        manaOverlay:SetColorTexture(0.1, 0.3, 0.8, 0.5)  -- Blue with 50% alpha
        manaOverlay:Hide()
        btn.manaOverlay = manaOverlay

        -- Spell cooldown swipe (so you can see when a totem with a real cooldown --
        -- Mana Tide, Fire Nova, the Elementals -- is ready to recast again). The
        -- GCD is filtered out in UpdateActiveCooldowns so it doesn't flicker.
        local spellCooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        spellCooldown:SetAllPoints(icon)
        spellCooldown:SetDrawEdge(false)
        spellCooldown:SetHideCountdownNumbers(false)
        spellCooldown:EnableMouse(false) -- don't let the swipe eat clicks to the cast button
        btn.spellCooldown = spellCooldown

        -- Register for clicks BEFORE setting attributes.
        -- AnyDown only: AnyDown+AnyUp fired the secure cast twice per click and
        -- double-ran the right-click PostClick (dismiss), which felt unreliable.
        btn:RegisterForClicks("AnyDown")

        -- Set up secure casting (but not when ctrl is held)
        btn:SetAttribute("type1", "spell")
        btn:SetAttribute("ctrl-type1", nil) -- ctrl+click should not cast; drag takes over
        if totemData then
            -- Cast by name so WoW auto-selects highest trained rank
            local totemName = addon.GetTotemName(spellID)
            btn:SetAttribute("spell1", totemName)
            btn.spellID = spellID
            btn.totemName = totemName  -- Cache localized name for tooltips
        end

        -- Shift+right-click to cast Totemic Call (recall all totems)
        -- Use spell ID 36936 for locale-independent lookup
        btn:SetAttribute("shift-type2", "spell")
        btn:SetAttribute("shift-spell2", GetSpellInfo(36936))

        -- Right-click to dismiss totem (but not when shift is held)
        btn:HookScript("PostClick", function(self, button)
            if button == "RightButton" and not IsShiftKeyDown() then
                local slot = TOTEM_SLOTS[self.element]
                if slot then
                    DestroyTotem(slot)
                end
            end
        end)

        btn:RegisterForDrag("LeftButton")
        btn:SetScript("OnDragStart", function(self)
            if not TotemBuddyDB.locked and not InCombatLockdown() then
                actionBarFrame:StartMoving()
            end
        end)
        btn:SetScript("OnDragStop", function(self)
            actionBarFrame:StopMovingOrSizing()
            local point, _, _, x, y = actionBarFrame:GetPoint()
            TotemBuddyDB.barPos = { point = point, x = x, y = y }
        end)

        -- Show popup on hover (if modifier key is pressed or not required)
        btn:SetScript("OnEnter", function(self)
            self.isHovering = true
            self.border:SetBackdropBorderColor(1, 1, 1, 1)
            if IsPopupModifierPressed() then
                addon.ShowPopup(self.element, self)
            end
            -- Show tooltip using spell info (if enabled)
            if TotemBuddyDB.showTooltips ~= false then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.showingPlaced and self.placedSpellID then
                    -- Show placed totem info using spell ID
                    GameTooltip:SetSpellByID(self.placedSpellID)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Currently placed (not your active totem)", 0.7, 0.7, 0.7)
                elseif self.spellID then
                    -- Use highest trained rank for tooltip
                    local trainedID = addon.GetHighestRankSpellID(self.spellID) or self.spellID
                    GameTooltip:SetSpellByID(trainedID)
                elseif self.totemName then
                    GameTooltip:SetText(self.totemName, 1, 1, 1)
                else
                    GameTooltip:SetText(self.element .. " Totem", 1, 1, 1)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Left-click to cast", 0.5, 0.5, 0.5)
                GameTooltip:AddLine("Right-click to dismiss", 0.5, 0.5, 0.5)
                GameTooltip:AddLine("Shift+Right-click for Totemic Call", 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end
        end)

        btn:SetScript("OnLeave", function(self)
            self.isHovering = false
            if self.showingPlaced then
                self.border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            else
                self.border:SetBackdropBorderColor(color.r, color.g, color.b, 1)
            end
            GameTooltip:Hide()
            -- Popup hides via OnUpdate check
        end)

        -- Check for modifier key press/release while hovering
        btn:SetScript("OnUpdate", function(self)
            if self.isHovering then
                if not addon.state.popupVisible and IsPopupModifierPressed() then
                    addon.ShowPopup(self.element, self)
                elseif addon.state.popupVisible and not IsPopupModifierPressed() and not TotemBuddyDB.alwaysShowPopup then
                    -- Hide popup when modifier released (unless alwaysShow is enabled)
                    addon.state.popupVisible = false
                    for _, container in pairs(addon.UI.popupContainers) do
                        if not InCombatLockdown() then
                            container:Hide()
                        else
                            container:SetAlpha(0)
                        end
                        if container.blocker then
                            container.blocker:EnableMouse(true)
                        end
                    end
                end
            end
        end)

        btn.element = element
        btn.color = color
        addon.UI.activeTotemButtons[element] = btn

        -- Icon timer display (shown when timerStyle == "icons")
        local iconTimer = CreateFrame("Frame", nil, btn)
        iconTimer:SetSize(40, 16)

        local fontData = addon.fontSizes[TotemBuddyDB.timerFontSize or "NORMAL"]
        local iconTimerText = iconTimer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        iconTimerText:SetPoint("CENTER")
        iconTimerText:SetTextColor(1, 1, 1)
        local fontPath, _, fontFlags = iconTimerText:GetFont()
        iconTimerText:SetFont(fontPath, fontData.size, "OUTLINE")

        -- Function to update icon timer position based on timerPosition setting
        local function UpdateIconTimerPosition()
            iconTimer:ClearAllPoints()
            local pos = TotemBuddyDB.timerPosition or "ABOVE"
            if pos == "ABOVE" then
                iconTimer:SetSize(40, 16)
                iconTimer:SetPoint("BOTTOM", btn, "TOP", 0, 2)
            elseif pos == "BELOW" then
                iconTimer:SetSize(40, 16)
                iconTimer:SetPoint("TOP", btn, "BOTTOM", 0, -2)
            elseif pos == "LEFT" then
                iconTimer:SetSize(40, 16)
                iconTimer:SetPoint("RIGHT", btn, "LEFT", -2, 0)
            elseif pos == "RIGHT" then
                iconTimer:SetSize(40, 16)
                iconTimer:SetPoint("LEFT", btn, "RIGHT", 2, 0)
            elseif pos == "ON" then
                iconTimer:SetSize(40, 40)
                iconTimer:SetPoint("CENTER", btn, "CENTER", 0, 0)
            end
        end
        UpdateIconTimerPosition()

        btn.iconTimer = iconTimer
        btn.iconTimerText = iconTimerText
        btn.UpdateIconTimerPosition = UpdateIconTimerPosition
        iconTimer:Hide()

        -- Create popup column for this element (anchored to this button)
        addon.CreatePopupColumn(element, btn)
    end

    -- Create Reincarnation tracker button (left/top side)
    addon.CreateReincarnationButton(isVertical)

    -- Create Weapon Buff button (right/bottom side)
    addon.CreateWeaponBuffButton(isVertical)

    actionBarFrame:Show()

    -- Initial update of element visibility based on totem items
    addon.UpdateElementVisibility()
end

-- Update the spell-cooldown swipe on each active totem button. Driven by
-- SPELL_UPDATE_COOLDOWN. GCD-length cooldowns (<= 2.5s) are ignored so the
-- swipe only shows for totems with a meaningful recast cooldown.
function addon.UpdateActiveCooldowns()
    for element, btn in pairs(addon.UI.activeTotemButtons) do
        if btn.spellCooldown and btn.totemName then
            local start, duration, enable = GetSpellCooldown(btn.totemName)
            if enable == 1 and start and duration and duration > 2.5 then
                btn.spellCooldown:SetCooldown(start, duration)
            else
                btn.spellCooldown:Clear()
            end
        end
    end
end

-- Update icon timer fonts when font size setting changes
function addon.UpdateIconTimerFonts()
    local fontData = addon.fontSizes[TotemBuddyDB.timerFontSize or "NORMAL"]
    for element, btn in pairs(addon.UI.activeTotemButtons) do
        if btn.iconTimerText then
            local fontPath = btn.iconTimerText:GetFont()
            btn.iconTimerText:SetFont(fontPath, fontData.size, "OUTLINE")
        end
    end
end

-- Update visibility of element buttons based on whether player has the required totem item
function addon.UpdateElementVisibility()
    if InCombatLockdown() then
        -- Queue update for after combat
        addon.state.pendingVisibilityUpdate = true
        return
    end

    local actionBarFrame = addon.UI.actionBarFrame
    if not actionBarFrame then return end

    local direction = TotemBuddyDB.popupDirection or "UP"
    local isVertical = (direction == "LEFT" or direction == "RIGHT")

    local visibleIndex = 0
    for i, element in ipairs(GetElementOrder()) do
        local btn = addon.UI.activeTotemButtons[element]
        local popupContainer = addon.UI.popupContainers[element]

        if btn then
            local hasTotem = addon.HasTotemItem(element)
            if hasTotem then
                visibleIndex = visibleIndex + 1
                btn:Show()
                btn:ClearAllPoints()
                if isVertical then
                    btn:SetPoint("TOP", 0, -8 - (visibleIndex - 1) * 48)
                else
                    btn:SetPoint("LEFT", 8 + (visibleIndex - 1) * 48, 0)
                end
                if popupContainer then
                    -- Popup visibility is managed by ShowPopup/HidePopup
                end
            else
                btn:Hide()
                if popupContainer then
                    popupContainer:Hide()
                    popupContainer:EnableMouse(false)
                    for _, popupBtn in ipairs(addon.UI.popupButtons[element] or {}) do
                        popupBtn:EnableMouse(false)
                        popupBtn.visual:EnableMouse(false)
                    end
                end
            end
        end
    end

    -- Resize action bar frame based on visible buttons
    if visibleIndex > 0 then
        if isVertical then
            actionBarFrame:SetSize(48, 8 + visibleIndex * 48)
        else
            actionBarFrame:SetSize(8 + visibleIndex * 48, 48)
        end
        actionBarFrame:Show()
    else
        actionBarFrame:Hide()
    end
end
