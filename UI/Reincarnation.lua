-- TotemBuddy: Reincarnation Module
-- Reincarnation tracker button

local addonName, addon = ...

-- Local references
local ANKH_ITEM_ID = addon.ANKH_ITEM_ID

-- Create Reincarnation tracker button
function addon.CreateReincarnationButton(isVertical)
    if not TotemBuddyDB.showReincarnation then return end

    local actionBarFrame = addon.UI.actionBarFrame

    local btn = CreateFrame("Button", "TotemBuddyReincarnation", actionBarFrame)
    btn:SetSize(28, 28)

    if isVertical then
        btn:SetPoint("BOTTOM", actionBarFrame, "TOP", 0, 4)
    else
        btn:SetPoint("RIGHT", actionBarFrame, "LEFT", -4, 0)
        btn:SetPoint("BOTTOM", actionBarFrame, "BOTTOM", 0, 2)
    end

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
    btn.border:SetBackdropBorderColor(0.5, 0.3, 0.6, 1) -- Purple for Reincarnation
    btn.border:EnableMouse(false)

    -- Icon (Reincarnation spell)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("CENTER")
    local reincIcon = GetSpellTexture("Reincarnation")
    icon:SetTexture(reincIcon or "Interface\\Icons\\Spell_Nature_Reincarnation")
    btn.icon = icon

    -- Overlay frame for text (above cooldown so it's not dimmed)
    local textOverlay = CreateFrame("Frame", nil, btn)
    textOverlay:SetAllPoints()
    textOverlay:SetFrameLevel(btn:GetFrameLevel() + 10)

    -- Ankh count text (bottom-right corner)
    local countText = textOverlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    countText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    countText:SetTextColor(1, 1, 1)
    btn.countText = countText

    -- Timer text (top, shows cooldown in minutes)
    local timerText = textOverlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    timerText:SetPoint("TOP", btn, "TOP", 0, -1)
    timerText:SetTextColor(1, 1, 1)
    timerText:SetShadowOffset(1, -1)
    timerText:SetShadowColor(0, 0, 0, 1)
    btn.timerText = timerText

    -- Cooldown frame (keep for swipe animation)
    local cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawSwipe(true)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(true) -- Hide default numbers, we use our own
    cooldown.noCooldownCount = true -- Prevent OmniCC/tullaCC from adding duplicate timers
    btn.cooldown = cooldown

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        self.border:SetBackdropBorderColor(1, 1, 1, 1)
        if TotemBuddyDB.showTooltips ~= false then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local _, _, _, _, _, _, spellID = GetSpellInfo("Reincarnation")
            if spellID then
                GameTooltip:SetSpellByID(spellID)
            else
                GameTooltip:SetText("Reincarnation", 1, 1, 1)
            end
            local ankhCount = GetItemCount(ANKH_ITEM_ID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Ankhs: " .. ankhCount, 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function(self)
        -- Restore border color based on Ankh count
        local ankhCount = GetItemCount(ANKH_ITEM_ID)
        if ankhCount == 0 then
            self.border:SetBackdropBorderColor(0.8, 0.2, 0.2, 1) -- Red when no Ankhs
        else
            self.border:SetBackdropBorderColor(0.5, 0.3, 0.6, 1) -- Purple normally
        end
        GameTooltip:Hide()
    end)

    addon.UI.reincarnationButton = btn
    addon.UpdateReincarnationButton()
end

-- Update Reincarnation button state (Ankh count, cooldown)
function addon.UpdateReincarnationButton()
    local reincarnationButton = addon.UI.reincarnationButton
    if not reincarnationButton then return end

    local ankhCount = GetItemCount(ANKH_ITEM_ID)
    reincarnationButton.countText:SetText(ankhCount > 0 and ankhCount or "")

    -- Update cooldown
    local start, duration, enabled = GetSpellCooldown("Reincarnation")
    if start and duration and duration > 1.5 then
        reincarnationButton.cooldown:SetCooldown(start, duration)
        -- Calculate remaining time and show in "Xm" format
        local remaining = (start + duration) - GetTime()
        if remaining > 0 then
            local minutes = math.ceil(remaining / 60)
            reincarnationButton.timerText:SetText(minutes .. "m")
        else
            reincarnationButton.timerText:SetText("")
        end
    else
        reincarnationButton.cooldown:Clear()
        reincarnationButton.timerText:SetText("")
    end

    -- Dim if no Ankhs or on cooldown
    local onCooldown = start and duration and duration > 1.5
    if ankhCount == 0 or onCooldown then
        reincarnationButton.icon:SetDesaturated(true)
        reincarnationButton.icon:SetAlpha(0.5)
    else
        reincarnationButton.icon:SetDesaturated(false)
        reincarnationButton.icon:SetAlpha(1)
    end

    -- Update border color based on Ankh count
    if ankhCount == 0 then
        reincarnationButton.border:SetBackdropBorderColor(0.8, 0.2, 0.2, 1) -- Red when no Ankhs
    else
        reincarnationButton.border:SetBackdropBorderColor(0.5, 0.3, 0.6, 1) -- Purple normally
    end
end
