-- TotemBuddy: WeaponBuff Module
-- Weapon buff button and popup

local addonName, addon = ...

-- Local references
local GetKnownWeaponBuffs = addon.GetKnownWeaponBuffs
local GetCurrentWeaponBuff = addon.GetCurrentWeaponBuff
local GetWeaponBuffByName = addon.GetWeaponBuffByName
local IsPopupModifierPressed = addon.IsPopupModifierPressed

-- Called when a weapon buff is successfully cast
function addon.OnWeaponBuffCast(spellName)
    local buff = GetWeaponBuffByName(spellName)
    if not buff then return end

    -- Capture pre-cast state
    local preMain = addon.state.preCastMainHandEnchant
    local preOff = addon.state.preCastOffHandEnchant

    -- Check which weapon got the buff by comparing enchant state
    -- We need a slight delay because GetWeaponEnchantInfo may not update immediately
    C_Timer.After(0.1, function()
        local hasMainHandEnchant, mainExp, _, _,
              hasOffHandEnchant, offExp = GetWeaponEnchantInfo()

        -- Detect which slot changed or was refreshed
        -- If main hand now has enchant (and didn't before, or has fresh duration), it's main hand
        -- If off hand now has enchant (and didn't before, or has fresh duration), it's off hand
        if hasMainHandEnchant then
            -- Main hand has enchant - assume this cast went to main hand
            -- (most common case - weapon buffs default to main hand)
            addon.state.activeMainHandBuff = buff
            -- Save spellID to DB for persistence across reloads (language-independent)
            if TotemBuddyDB then
                TotemBuddyDB.lastMainHandBuff = buff.spellID
            end
        end

        -- If only off hand has enchant and main doesn't, it went to off hand
        if hasOffHandEnchant and not hasMainHandEnchant then
            addon.state.activeOffHandBuff = buff
            if TotemBuddyDB then
                TotemBuddyDB.lastOffHandBuff = buff.spellID
            end
        end

        -- If both have enchants and off hand is the "new" one (main was already enchanted)
        if hasOffHandEnchant and hasMainHandEnchant and preMain and not preOff then
            addon.state.activeOffHandBuff = buff
            if TotemBuddyDB then
                TotemBuddyDB.lastOffHandBuff = buff.spellID
            end
        end

        addon.UpdateWeaponBuffButton()
    end)
end

-- Restore saved weapon buff info on login (if enchant is still active)
function addon.RestoreSavedWeaponBuffs()
    local hasMainHandEnchant, _, _, _,
          hasOffHandEnchant = GetWeaponEnchantInfo()

    if hasMainHandEnchant and TotemBuddyDB and TotemBuddyDB.lastMainHandBuff then
        -- DB now stores spellID instead of name
        local buff = addon.GetWeaponBuffBySpellID(TotemBuddyDB.lastMainHandBuff)
        if buff then
            addon.state.activeMainHandBuff = buff
        end
    end

    if hasOffHandEnchant and TotemBuddyDB and TotemBuddyDB.lastOffHandBuff then
        -- DB now stores spellID instead of name
        local buff = addon.GetWeaponBuffBySpellID(TotemBuddyDB.lastOffHandBuff)
        if buff then
            addon.state.activeOffHandBuff = buff
        end
    end
end

-- Pre-cast hook to track enchant state before casting
function addon.TrackPreCastEnchantState()
    local hasMainHandEnchant, _, _, _,
          hasOffHandEnchant = GetWeaponEnchantInfo()
    addon.state.preCastMainHandEnchant = hasMainHandEnchant
    addon.state.preCastOffHandEnchant = hasOffHandEnchant
end

-- Create Weapon Buff button and popup
function addon.CreateWeaponBuffButton(isVertical)
    if not TotemBuddyDB.showWeaponBuffs then return end

    local knownBuffs = GetKnownWeaponBuffs()
    if #knownBuffs == 0 then return end -- No weapon buffs known

    local actionBarFrame = addon.UI.actionBarFrame

    -- Use SecureActionButtonTemplate so we can cast spells
    local btn = CreateFrame("Button", "TotemBuddyWeaponBuff", actionBarFrame, "SecureActionButtonTemplate")
    btn:SetSize(28, 28)

    if isVertical then
        btn:SetPoint("TOP", actionBarFrame, "BOTTOM", 0, -4)
    else
        btn:SetPoint("LEFT", actionBarFrame, "RIGHT", 4, 0)
        btn:SetPoint("BOTTOM", actionBarFrame, "BOTTOM", 0, 2)
    end

    -- Register for clicks
    btn:RegisterForClicks("AnyDown", "AnyUp")

    -- Set up default spell (first known buff, will be updated by UpdateWeaponBuffButton)
    local defaultBuffName = addon.GetWeaponBuffName(knownBuffs[1].spellID)
    btn:SetAttribute("type1", "spell")
    btn:SetAttribute("spell1", defaultBuffName)
    btn:SetAttribute("type2", "macro")
    btn:SetAttribute("macrotext2", "/use 17\n/cast " .. defaultBuffName)

    -- Background
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

    -- Border
    btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.border:SetPoint("TOPLEFT", -1, 1)
    btn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    btn.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn.border:SetBackdropBorderColor(0.4, 0.6, 0.8, 1) -- Blue-ish for weapons
    btn.border:EnableMouse(false)

    -- Icon (show first known weapon buff icon by default)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("CENTER")
    local defaultIcon = addon.GetWeaponBuffIcon(knownBuffs[1].spellID)
    icon:SetTexture(defaultIcon)
    btn.icon = icon
    btn.currentBuffName = defaultBuffName -- Track current buff for casting

    -- Timer text (shows remaining minutes) - large font overlapping frame
    local timerText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    timerText:SetPoint("CENTER", btn, "CENTER", 0, 0)
    timerText:SetTextColor(1, 1, 1)
    timerText:SetShadowOffset(1, -1)
    timerText:SetShadowColor(0, 0, 0, 1)
    btn.timerText = timerText

    -- Create popup for weapon buffs
    local direction = TotemBuddyDB.popupDirection or "UP"
    local popupIsHorizontal = (direction == "LEFT" or direction == "RIGHT")

    local popup = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    if popupIsHorizontal then
        popup:SetSize(#knownBuffs * 40 + 8, 44)
    else
        popup:SetSize(44, #knownBuffs * 40 + 8)
    end

    -- Anchor based on popup direction
    if direction == "UP" then
        popup:SetPoint("BOTTOM", btn, "TOP", 0, 2)
    elseif direction == "DOWN" then
        popup:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    elseif direction == "LEFT" then
        popup:SetPoint("RIGHT", btn, "LEFT", -2, 0)
    else -- RIGHT
        popup:SetPoint("LEFT", btn, "RIGHT", 2, 0)
    end

    popup:SetFrameStrata("DIALOG")
    popup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    popup:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    popup:SetBackdropBorderColor(0.4, 0.6, 0.8, 1)
    popup:Hide()
    addon.UI.weaponBuffPopup = popup

    -- Create popup buttons for each weapon buff
    addon.UI.weaponBuffPopupButtons = {}
    for i, buffData in ipairs(knownBuffs) do
        addon.UI.buttonCounter = addon.UI.buttonCounter + 1
        local btnName = "TotemBuddyWeaponBuffPopup" .. addon.UI.buttonCounter

        -- Visual frame
        local visual = CreateFrame("Frame", nil, popup, "BackdropTemplate")
        visual:SetSize(36, 36)
        visual:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        visual:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        visual:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        local buffIcon = visual:CreateTexture(nil, "ARTWORK")
        buffIcon:SetSize(32, 32)
        buffIcon:SetPoint("CENTER")
        local spellIcon = addon.GetWeaponBuffIcon(buffData.spellID)
        buffIcon:SetTexture(spellIcon)
        visual.icon = buffIcon

        -- Get localized name for casting
        local buffName = addon.GetWeaponBuffName(buffData.spellID)

        -- Secure button on top
        local popupBtn = CreateFrame("Button", btnName, popup, "SecureActionButtonTemplate")
        popupBtn:SetSize(36, 36)
        popupBtn:SetAllPoints(visual)
        popupBtn:SetFrameLevel(visual:GetFrameLevel() + 1)

        popupBtn.visual = visual
        popupBtn.border = visual
        popupBtn.buffName = buffName
        popupBtn.spellID = buffData.spellID  -- Store spell ID for tooltip

        -- Register for clicks
        popupBtn:RegisterForClicks("AnyDown", "AnyUp")

        -- Left click = cast on main hand (using localized name)
        popupBtn:SetAttribute("type1", "spell")
        popupBtn:SetAttribute("spell1", buffName)

        -- Right click = cast on offhand (uses macro approach with localized name)
        popupBtn:SetAttribute("type2", "macro")
        popupBtn:SetAttribute("macrotext2", "/use 17\n/cast " .. buffName)

        -- Position in popup
        if direction == "UP" then
            local yOffset = 4 + (i - 1) * 40
            visual:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 4, yOffset)
        elseif direction == "DOWN" then
            local yOffset = 4 + (i - 1) * 40
            visual:SetPoint("TOPLEFT", popup, "TOPLEFT", 4, -yOffset)
        elseif direction == "LEFT" then
            local xOffset = 4 + (i - 1) * 40
            visual:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -xOffset, -4)
        else -- RIGHT
            local xOffset = 4 + (i - 1) * 40
            visual:SetPoint("TOPLEFT", popup, "TOPLEFT", xOffset, -4)
        end

        -- Tooltip
        popupBtn:SetScript("OnEnter", function(self)
            self.border:SetBackdropBorderColor(1, 1, 1, 1)
            addon.state.weaponBuffPopupVisible = true -- Keep popup visible
            if TotemBuddyDB.showTooltips ~= false then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.spellID then
                    GameTooltip:SetSpellByID(self.spellID)
                else
                    GameTooltip:SetText(self.buffName, 1, 1, 1)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Click to apply to weapon", 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end
        end)

        popupBtn:SetScript("OnLeave", function(self)
            self.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            GameTooltip:Hide()
            -- Delay hiding popup to allow moving to other buttons
            C_Timer.After(0.15, function()
                local weaponBuffPopup = addon.UI.weaponBuffPopup
                local weaponBuffButton = addon.UI.weaponBuffButton
                local weaponBuffPopupButtons = addon.UI.weaponBuffPopupButtons
                if weaponBuffPopup and weaponBuffButton then
                    local overAnyBtn = weaponBuffPopup:IsMouseOver() or weaponBuffButton:IsMouseOver()
                    if not overAnyBtn then
                        for _, pb in ipairs(weaponBuffPopupButtons) do
                            if pb:IsMouseOver() then
                                overAnyBtn = true
                                break
                            end
                        end
                    end
                    if not overAnyBtn then
                        if not InCombatLockdown() then
                            weaponBuffPopup:Hide()
                        end
                        addon.state.weaponBuffPopupVisible = false
                    end
                end
            end)
        end)

        visual:Show()
        popupBtn:Show()
        addon.UI.weaponBuffPopupButtons[i] = popupBtn
    end

    -- Main button hover shows popup (if modifier key is pressed or not required)
    btn:SetScript("OnEnter", function(self)
        self.isHovering = true
        self.border:SetBackdropBorderColor(1, 1, 1, 1)
        if IsPopupModifierPressed() and not InCombatLockdown() then
            addon.UI.weaponBuffPopup:Show()
            addon.state.weaponBuffPopupVisible = true
        end

        -- Show tooltip with current weapon enchant info
        if TotemBuddyDB.showTooltips ~= false then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Weapon Buffs", 1, 1, 1)

            local enchantInfo = GetCurrentWeaponBuff()
            if enchantInfo.mainHand and enchantInfo.mainHandBuff then
                local buffName = addon.GetWeaponBuffName(enchantInfo.mainHandBuff.spellID)
                GameTooltip:AddLine("Main Hand: " .. (buffName or "Unknown"), 0, 1, 0)
            elseif enchantInfo.mainHand then
                GameTooltip:AddLine("Main Hand: Enchanted", 0, 1, 0)
            else
                GameTooltip:AddLine("Main Hand: None", 0.5, 0.5, 0.5)
            end
            if enchantInfo.offHand and enchantInfo.offHandBuff then
                local buffName = addon.GetWeaponBuffName(enchantInfo.offHandBuff.spellID)
                GameTooltip:AddLine("Off Hand: " .. (buffName or "Unknown"), 0, 1, 0)
            elseif enchantInfo.offHand then
                GameTooltip:AddLine("Off Hand: Enchanted", 0, 1, 0)
            else
                GameTooltip:AddLine("Off Hand: None", 0.5, 0.5, 0.5)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to apply to weapon", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function(self)
        self.isHovering = false
        -- Restore border color based on enchant state
        local enchantInfo = GetCurrentWeaponBuff()
        if enchantInfo.mainHand then
            self.border:SetBackdropBorderColor(0.2, 0.8, 0.2, 1) -- Green when buffed
        else
            self.border:SetBackdropBorderColor(0.8, 0.2, 0.2, 1) -- Red when no buff
        end
        GameTooltip:Hide()
        -- Delay hiding popup to allow moving to it
        C_Timer.After(0.15, function()
            local weaponBuffPopup = addon.UI.weaponBuffPopup
            if weaponBuffPopup and not weaponBuffPopup:IsMouseOver() and not btn:IsMouseOver() then
                if not InCombatLockdown() then
                    weaponBuffPopup:Hide()
                end
                addon.state.weaponBuffPopupVisible = false
            end
        end)
    end)

    -- Check for modifier key press/release while hovering
    btn:SetScript("OnUpdate", function(self)
        if self.isHovering then
            if not addon.state.weaponBuffPopupVisible and IsPopupModifierPressed() then
                if not InCombatLockdown() then
                    addon.UI.weaponBuffPopup:Show()
                    addon.state.weaponBuffPopupVisible = true
                end
            elseif addon.state.weaponBuffPopupVisible and not IsPopupModifierPressed() and not TotemBuddyDB.alwaysShowPopup then
                -- Hide popup when modifier released
                if not InCombatLockdown() then
                    addon.UI.weaponBuffPopup:Hide()
                end
                addon.state.weaponBuffPopupVisible = false
            end
        end
    end)

    -- Popup mouse leave handler
    popup:SetScript("OnLeave", function(self)
        C_Timer.After(0.15, function()
            local weaponBuffPopup = addon.UI.weaponBuffPopup
            local weaponBuffButton = addon.UI.weaponBuffButton
            local weaponBuffPopupButtons = addon.UI.weaponBuffPopupButtons
            if weaponBuffPopup and not weaponBuffPopup:IsMouseOver() and not btn:IsMouseOver() then
                local overAnyBtn = false
                for _, popBtn in ipairs(weaponBuffPopupButtons) do
                    if popBtn:IsMouseOver() then
                        overAnyBtn = true
                        break
                    end
                end
                if not overAnyBtn then
                    if not InCombatLockdown() then
                        weaponBuffPopup:Hide()
                    end
                    addon.state.weaponBuffPopupVisible = false
                end
            end
        end)
    end)

    addon.UI.weaponBuffButton = btn
    addon.UpdateWeaponBuffButton()
end

-- Update Weapon Buff button to show current main-hand enchant icon
function addon.UpdateWeaponBuffButton()
    local weaponBuffButton = addon.UI.weaponBuffButton
    if not weaponBuffButton then return end

    local enchantInfo = GetCurrentWeaponBuff()
    local buffToUse = nil

    -- Update icon to show active buff
    if enchantInfo.mainHand and enchantInfo.mainHandBuff then
        -- Show the active buff icon (use spellID to get texture)
        local buffIcon = addon.GetWeaponBuffIcon(enchantInfo.mainHandBuff.spellID)
        weaponBuffButton.icon:SetTexture(buffIcon)
        weaponBuffButton.icon:SetDesaturated(false)
        weaponBuffButton.icon:SetAlpha(1)
        weaponBuffButton.border:SetBackdropBorderColor(0.2, 0.8, 0.2, 1) -- Green when buffed
        buffToUse = addon.GetWeaponBuffName(enchantInfo.mainHandBuff.spellID)
    elseif enchantInfo.mainHand then
        -- Has enchant but we don't know which one (e.g., on login)
        -- Keep current icon but show green border
        weaponBuffButton.icon:SetDesaturated(false)
        weaponBuffButton.icon:SetAlpha(1)
        weaponBuffButton.border:SetBackdropBorderColor(0.2, 0.8, 0.2, 1) -- Green when buffed
    else
        -- No enchant - show last used buff or first known, dimmed with red border
        local knownBuffs = GetKnownWeaponBuffs()
        if #knownBuffs > 0 then
            -- Use saved buff spellID if available, otherwise first known
            local savedBuffID = TotemBuddyDB and TotemBuddyDB.lastMainHandBuff
            local buffData = savedBuffID and addon.GetWeaponBuffBySpellID(savedBuffID) or knownBuffs[1]
            local defaultIcon = addon.GetWeaponBuffIcon(buffData.spellID)
            weaponBuffButton.icon:SetTexture(defaultIcon)
            buffToUse = addon.GetWeaponBuffName(buffData.spellID)
        end
        weaponBuffButton.icon:SetDesaturated(true)
        weaponBuffButton.icon:SetAlpha(0.5)
        weaponBuffButton.border:SetBackdropBorderColor(0.8, 0.2, 0.2, 1) -- Red when no buff
    end

    -- Update spell attributes for clicking (only outside combat)
    if buffToUse and buffToUse ~= weaponBuffButton.currentBuffName and not InCombatLockdown() then
        weaponBuffButton:SetAttribute("spell1", buffToUse)
        weaponBuffButton:SetAttribute("macrotext2", "/use 17\n/cast " .. buffToUse)
        weaponBuffButton.currentBuffName = buffToUse
    end

    -- Update timer text (show minutes with "m" suffix)
    if weaponBuffButton.timerText then
        if enchantInfo.mainHandTime then
            -- mainHandTime is in milliseconds
            local minutes = math.ceil(enchantInfo.mainHandTime / 60000)
            weaponBuffButton.timerText:SetText(minutes .. "m")
        else
            weaponBuffButton.timerText:SetText("")
        end
    end
end
