-- TotemBuddy: Timers Module
-- Timer bars and icon timers

local addonName, addon = ...

-- Local references
local ELEMENT_COLORS = addon.ELEMENT_COLORS
local TOTEM_SLOTS = addon.TOTEM_SLOTS
local GetElementOrder = addon.GetElementOrder
local FormatTime = addon.FormatTime
local HasTotemBuff = addon.HasTotemBuff

-- Create timer bar
function addon.CreateTimerBar(parent, element, index)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetSize(190, 20)

    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

    local color = ELEMENT_COLORS[element]
    bar:SetBackdropBorderColor(color.r, color.g, color.b, 1)

    -- Status bar
    local statusBar = CreateFrame("StatusBar", nil, bar)
    statusBar:SetPoint("TOPLEFT", 2, -2)
    statusBar:SetPoint("BOTTOMRIGHT", -2, 2)
    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    statusBar:SetStatusBarColor(color.r, color.g, color.b, 0.8)
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(1)
    bar.statusBar = statusBar

    -- Text (on statusBar so it renders above the progress color)
    local fontData = addon.fontSizes[TotemBuddyDB.timerFontSize or "NORMAL"]
    local text = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", 4, 0)
    text:SetTextColor(1, 1, 1)
    local fontPath = text:GetFont()
    text:SetFont(fontPath, fontData.size, "OUTLINE")
    bar.text = text

    -- Time text (on statusBar so it renders above the progress color)
    local timeText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeText:SetPoint("RIGHT", -2, 0)
    timeText:SetTextColor(1, 1, 1)
    timeText:SetFont(fontPath, fontData.size, "OUTLINE")
    bar.timeText = timeText

    bar.element = element
    bar:Hide()

    return bar
end

-- Create timer frame (position based on timerPosition setting)
function addon.CreateTimerFrame()
    local actionBarFrame = addon.UI.actionBarFrame
    local timerPos = TotemBuddyDB.timerPosition or "ABOVE"

    local timerFrame = CreateFrame("Frame", "TotemBuddyTimers", actionBarFrame, "BackdropTemplate")
    timerFrame:SetSize(200, 100)
    timerFrame:SetFrameStrata("MEDIUM") -- Below popups (DIALOG) so they render on top

    -- Position based on timerPosition setting
    if timerPos == "ABOVE" then
        timerFrame:SetPoint("BOTTOM", actionBarFrame, "TOP", 0, 2)
    elseif timerPos == "BELOW" then
        timerFrame:SetPoint("TOP", actionBarFrame, "BOTTOM", 0, -2)
    elseif timerPos == "LEFT" then
        timerFrame:SetPoint("RIGHT", actionBarFrame, "LEFT", -2, 0)
    else -- RIGHT
        timerFrame:SetPoint("LEFT", actionBarFrame, "RIGHT", 2, 0)
    end

    timerFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    timerFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    timerFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    addon.UI.timerFrame = timerFrame

    -- Create timer bars for each element
    for i, element in ipairs(GetElementOrder()) do
        local bar = addon.CreateTimerBar(timerFrame, element, i)
        bar:SetPoint("BOTTOM", 0, 5 + (i - 1) * 24)
        addon.UI.timerBars[element] = bar
    end

    timerFrame:Hide()
end

-- Update timer bar fonts when font size setting changes
function addon.UpdateTimerBarFonts()
    local fontData = addon.fontSizes[TotemBuddyDB.timerFontSize or "NORMAL"]
    for element, bar in pairs(addon.UI.timerBars) do
        if bar.text then
            local fontPath = bar.text:GetFont()
            bar.text:SetFont(fontPath, fontData.size, "OUTLINE")
        end
        if bar.timeText then
            local fontPath = bar.timeText:GetFont()
            bar.timeText:SetFont(fontPath, fontData.size, "OUTLINE")
        end
    end
end

-- Update timer bars
function addon.UpdateTimers()
    local timerFrame = addon.UI.timerFrame
    local timerBars = addon.UI.timerBars
    local activeTotemButtons = addon.UI.activeTotemButtons

    -- Guard: UI not initialized yet
    if not timerFrame then return end

    local anyActive = false
    local timerStyle = TotemBuddyDB.timerStyle or "bars"
    local showTimers = TotemBuddyDB.showTimers

    for slot = 1, 4 do
        local haveTotem, totemName, startTime, duration = GetTotemInfo(slot)
        local element = nil

        -- Map slot to element
        for elem, slotNum in pairs(TOTEM_SLOTS) do
            if slotNum == slot then
                element = elem
                break
            end
        end

        -- Reset sound flag if no totem in slot
        if not haveTotem then
            addon.state.totemSoundPlayed[slot] = false
        end

        if element then
            local bar = timerBars[element]
            local btn = activeTotemButtons[element]
            local activeSpellID = TotemBuddyDB["active" .. element]
            local activeTotemName = addon.GetTotemName(activeSpellID)

            if haveTotem and duration > 0 then
                local remaining = (startTime + duration) - GetTime()

                if remaining > 0 then
                    anyActive = true

                    -- Totem expiry sound alert
                    if remaining <= 5 then
                        if TotemBuddyDB.totemExpirySound and not addon.state.totemSoundPlayed[slot] then
                            local soundValue = TotemBuddyDB.totemExpirySoundIDs and TotemBuddyDB.totemExpirySoundIDs[element] or 8959
                            if soundValue then
                                if type(soundValue) == "string" then
                                    PlaySoundFile(soundValue, "Master")
                                elseif soundValue > 0 then
                                    PlaySound(soundValue, "Master")
                                end
                            end
                            addon.state.totemSoundPlayed[slot] = true
                        end
                    else
                        -- Reset flag when totem has more than 5 seconds (handles new totem placement)
                        addon.state.totemSoundPlayed[slot] = false
                    end

                    -- Update bar timer (bars mode)
                    if bar and timerStyle == "bars" then
                        bar:Show()
                        bar.statusBar:SetMinMaxValues(0, duration)
                        bar.statusBar:SetValue(remaining)
                        -- totemName may be nil in some WoW versions
                        if totemName then
                            bar.text:SetText(totemName:gsub(" Totem", ""))
                        else
                            bar.text:SetText(element)
                        end
                        bar.timeText:SetText(FormatTime(math.floor(remaining)))
                    elseif bar then
                        bar:Hide()
                    end

                    -- Update icon timer (icons mode)
                    if btn and btn.iconTimer then
                        if timerStyle == "icons" and showTimers then
                            btn.iconTimerText:SetText(FormatTime(math.floor(remaining)))
                            btn.iconTimer:Show()
                        else
                            btn.iconTimer:Hide()
                        end
                    end

                    -- Update button to show placed totem (if different from active)
                    if btn and totemName then
                        -- Strip rank suffix for comparison (e.g., "Searing Totem VII" -> "Searing Totem")
                        local baseTotemName = totemName:gsub("%s+[IVXLCDM]+$", "")
                        -- Compare localized names (activeTotemName is also localized now)
                        if activeTotemName and baseTotemName ~= activeTotemName then
                            -- Placed totem differs from active - show with visual indicator
                            local placedIcon = GetSpellTexture(baseTotemName) or GetSpellTexture(totemName)
                            if placedIcon then
                                btn.icon:SetTexture(placedIcon)
                                -- Only grey out if setting is enabled
                                if TotemBuddyDB.greyOutPlacedTotem then
                                    btn.icon:SetDesaturated(true)
                                    btn.border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
                                end
                                btn.showingPlaced = true
                                btn.placedTotemName = totemName
                                -- Try to get spell ID for the placed totem for tooltip
                                local _, _, _, _, _, _, placedSpellID = GetSpellInfo(baseTotemName)
                                btn.placedSpellID = placedSpellID
                            end
                        elseif btn.showingPlaced then
                            -- Placed totem matches active - revert to normal display
                            local activeIcon = addon.GetTotemIcon(activeSpellID)
                            if activeIcon then
                                btn.icon:SetTexture(activeIcon)
                            end
                            btn.icon:SetDesaturated(false)
                            btn.border:SetBackdropBorderColor(btn.color.r, btn.color.g, btn.color.b, 1)
                            btn.showingPlaced = false
                            btn.placedTotemName = nil
                            btn.placedSpellID = nil
                        end

                        -- Check if player is out of range (buff-based detection)
                        if TotemBuddyDB.dimOutOfRange then
                            local hasBuff = HasTotemBuff(totemName)
                            if hasBuff == false then
                                -- Totem is placed but player doesn't have the buff = out of range
                                btn.icon:SetAlpha(0.4)
                            else
                                -- Has buff (in range) OR totem doesn't provide buffs
                                btn.icon:SetAlpha(1.0)
                            end
                        else
                            btn.icon:SetAlpha(1.0)
                        end

                        -- Hide mana overlay when totem is active
                        if btn.manaOverlay then
                            btn.manaOverlay:Hide()
                        end
                    end
                else
                    if bar then bar:Hide() end
                    if btn and btn.iconTimer then btn.iconTimer:Hide() end
                    -- Revert button display when totem expires
                    if btn and btn.showingPlaced then
                        local activeIcon = addon.GetTotemIcon(activeSpellID)
                        if activeIcon then
                            btn.icon:SetTexture(activeIcon)
                        end
                        btn.icon:SetDesaturated(false)
                        btn.border:SetBackdropBorderColor(btn.color.r, btn.color.g, btn.color.b, 1)
                        btn.showingPlaced = false
                        btn.placedTotemName = nil
                        btn.placedSpellID = nil
                    end
                    -- Reset alpha when totem expires
                    if btn then
                        btn.icon:SetAlpha(1.0)
                    end
                    -- Check mana for blue overlay when totem expired
                    if btn and btn.manaOverlay then
                        if TotemBuddyDB.showLowManaOverlay then
                            local hasEnoughMana = addon.HasManaForTotem(activeSpellID)
                            if not hasEnoughMana then
                                btn.manaOverlay:Show()
                            else
                                btn.manaOverlay:Hide()
                            end
                        else
                            btn.manaOverlay:Hide()
                        end
                    end
                end
            else
                if bar then bar:Hide() end
                if btn and btn.iconTimer then btn.iconTimer:Hide() end
                -- Revert button display when no totem placed
                if btn and btn.showingPlaced then
                    local activeIcon = addon.GetTotemIcon(activeSpellID)
                    if activeIcon then
                        btn.icon:SetTexture(activeIcon)
                    end
                    btn.icon:SetDesaturated(false)
                    btn.border:SetBackdropBorderColor(btn.color.r, btn.color.g, btn.color.b, 1)
                    btn.showingPlaced = false
                    btn.placedTotemName = nil
                    btn.placedSpellID = nil
                end
                -- Reset alpha when no totem placed
                if btn then
                    btn.icon:SetAlpha(1.0)
                end
                -- Check mana for blue overlay when no totem is placed
                if btn and btn.manaOverlay then
                    if TotemBuddyDB.showLowManaOverlay then
                        local hasEnoughMana = addon.HasManaForTotem(activeSpellID)
                        if not hasEnoughMana then
                            btn.manaOverlay:Show()
                        else
                            btn.manaOverlay:Hide()
                        end
                    else
                        btn.manaOverlay:Hide()
                    end
                end
            end
        end
    end

    -- Show/hide bar timer frame
    if anyActive and showTimers and timerStyle == "bars" then
        timerFrame:Show()
        -- Resize timer frame based on visible bars
        local visibleCount = 0
        for _, bar in pairs(timerBars) do
            if bar:IsShown() then
                visibleCount = visibleCount + 1
            end
        end
        timerFrame:SetHeight(10 + visibleCount * 24)

        -- Reposition visible bars based on timer position
        local timerPos = TotemBuddyDB.timerPosition or "ABOVE"
        local yOffset = 5
        for _, element in ipairs(GetElementOrder()) do
            local bar = timerBars[element]
            if bar:IsShown() then
                bar:ClearAllPoints()
                -- ABOVE, LEFT, RIGHT stack from bottom; BELOW stacks from top
                if timerPos == "BELOW" then
                    bar:SetPoint("TOP", 0, -yOffset)
                else
                    bar:SetPoint("BOTTOM", 0, yOffset)
                end
                yOffset = yOffset + 24
            end
        end
    else
        timerFrame:Hide()
    end
end
