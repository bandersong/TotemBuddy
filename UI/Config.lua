-- TotemBuddy: Config Module
-- Configuration window

local addonName, addon = ...

-- Local references
local ELEMENT_ORDER = addon.ELEMENT_ORDER
local ELEMENT_COLORS = addon.ELEMENT_COLORS
local GetOrderedTotems = addon.GetOrderedTotems
local IsTotemHidden = addon.IsTotemHidden
local GetElementOrder = addon.GetElementOrder

local function SaveTotemOrder(element)
    local configTotemRows = addon.UI.configTotemRows
    local order = {}
    for _, row in ipairs(configTotemRows[element] or {}) do
        if row.spellID then
            table.insert(order, row.spellID)
        end
    end
    TotemBuddyDB.totemOrder[element] = order
end

local function RefreshConfigList(element)
    local configTotemRows = addon.UI.configTotemRows
    local rows = configTotemRows[element]
    if not rows then return end

    for i, row in ipairs(rows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", 0, -((i - 1) * 24))
        row.upBtn:SetEnabled(i > 1)
        row.downBtn:SetEnabled(i < #rows)
    end
end

local function MoveTotemUp(element, rowIndex)
    local configTotemRows = addon.UI.configTotemRows
    local rows = configTotemRows[element]
    if rowIndex <= 1 then return end
    rows[rowIndex], rows[rowIndex - 1] = rows[rowIndex - 1], rows[rowIndex]
    RefreshConfigList(element)
    SaveTotemOrder(element)
end

local function MoveTotemDown(element, rowIndex)
    local configTotemRows = addon.UI.configTotemRows
    local rows = configTotemRows[element]
    if rowIndex >= #rows then return end
    rows[rowIndex], rows[rowIndex + 1] = rows[rowIndex + 1], rows[rowIndex]
    RefreshConfigList(element)
    SaveTotemOrder(element)
end

local function CreateTotemRow(parent, totemData, element, index)
    local configTotemRows = addon.UI.configTotemRows
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(200, 20)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * 22))
    row.spellID = totemData.spellID  -- Store spell ID instead of name
    row.element = element

    -- Get localized name from spell ID
    local totemName = addon.GetTotemName(totemData.spellID) or "Unknown"

    local upBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    upBtn:SetSize(16, 16)
    upBtn:SetPoint("LEFT", 0, 0)
    upBtn:SetText("^")
    upBtn:SetScript("OnClick", function()
        for i, r in ipairs(configTotemRows[element]) do
            if r == row then
                MoveTotemUp(element, i)
                break
            end
        end
    end)
    row.upBtn = upBtn

    local downBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    downBtn:SetSize(16, 16)
    downBtn:SetPoint("LEFT", upBtn, "RIGHT", 1, 0)
    downBtn:SetText("v")
    downBtn:SetScript("OnClick", function()
        for i, r in ipairs(configTotemRows[element]) do
            if r == row then
                MoveTotemDown(element, i)
                break
            end
        end
    end)
    row.downBtn = downBtn

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", downBtn, "RIGHT", 2, 0)
    icon:SetTexture(addon.GetTotemIcon(totemData.spellID))  -- Use spell ID for icon
    row.icon = icon

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("LEFT", icon, "RIGHT", 2, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -18, 0)
    name:SetJustifyH("LEFT")
    name:SetText(totemName:gsub(" Totem", ""))  -- Use localized name
    row.nameText = name

    -- Hide/show toggle button
    local hideBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    hideBtn:SetSize(16, 16)
    hideBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)

    local function UpdateHideState()
        if IsTotemHidden(element, totemData.spellID) then  -- Use spell ID
            hideBtn:SetText("O")
            row.icon:SetAlpha(0.4)
            row.nameText:SetAlpha(0.4)
        else
            hideBtn:SetText("X")
            row.icon:SetAlpha(1)
            row.nameText:SetAlpha(1)
        end
    end

    hideBtn:SetScript("OnClick", function()
        local hidden = TotemBuddyDB.hiddenTotems[element]
        if IsTotemHidden(element, totemData.spellID) then  -- Use spell ID
            -- Remove from hidden list
            for i, hiddenID in ipairs(hidden) do
                if hiddenID == totemData.spellID then
                    table.remove(hidden, i)
                    break
                end
            end
        else
            -- Add to hidden list (using spell ID)
            table.insert(hidden, totemData.spellID)
        end
        UpdateHideState()
    end)

    hideBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if IsTotemHidden(element, totemData.spellID) then  -- Use spell ID
            GameTooltip:SetText("Click to show in popup")
        else
            GameTooltip:SetText("Click to hide from popup")
        end
        GameTooltip:Show()
    end)
    hideBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdateHideState()
    row.hideBtn = hideBtn

    return row
end

local function PopulateConfigSection(parent, element)
    local configTotemRows = addon.UI.configTotemRows
    if configTotemRows[element] then
        for _, row in ipairs(configTotemRows[element]) do
            row:Hide()
            row:SetParent(nil)
        end
    end
    configTotemRows[element] = {}

    local totems = GetOrderedTotems(element)
    for i, totemData in ipairs(totems) do
        local row = CreateTotemRow(parent, totemData, element, i)
        configTotemRows[element][i] = row
    end
    RefreshConfigList(element)
end

local function CreateDropdown(parent, label, options, currentValue, x, y, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(120, 40)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("TOPLEFT", 0, 0)
    labelText:SetText(label)
    labelText:SetTextColor(1, 0.82, 0)

    local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
    btn:SetSize(110, 22)
    btn:SetPoint("TOPLEFT", 0, -14)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnText:SetPoint("LEFT", 8, 0)
    btn.text = btnText

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("v")

    -- Find current label
    local function UpdateText()
        for _, opt in ipairs(options) do
            if opt.value == currentValue then
                btnText:SetText(opt.label)
                return
            end
        end
        btnText:SetText(options[1].label)
    end
    UpdateText()

    -- Dropdown menu
    local maxVisible = 15
    local itemHeight = 20
    local totalHeight = #options * itemHeight + 4
    local needsScroll = #options > maxVisible
    local menuHeight = needsScroll and (maxVisible * itemHeight + 4) or totalHeight
    local menuWidth = needsScroll and 126 or 110  -- wider to fit scrollbar

    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menu:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    menu:SetSize(menuWidth, menuHeight)
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    menu:SetBackdropColor(0.15, 0.15, 0.15, 1)
    menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    menu:SetFrameStrata("TOOLTIP")
    menu:Hide()

    -- Parent for items: either a scroll child or the menu itself
    local itemParent
    if needsScroll then
        local scrollFrame = CreateFrame("ScrollFrame", nil, menu)
        scrollFrame:SetPoint("TOPLEFT", 2, -2)
        scrollFrame:SetPoint("BOTTOMRIGHT", -18, 2)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(106, totalHeight)
        scrollFrame:SetScrollChild(scrollChild)

        -- Scrollbar
        local slider = CreateFrame("Slider", nil, menu, "BackdropTemplate")
        slider:SetPoint("TOPRIGHT", -2, -2)
        slider:SetPoint("BOTTOMRIGHT", -2, 2)
        slider:SetWidth(14)
        slider:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        slider:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        slider:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        slider:SetOrientation("VERTICAL")
        slider:SetMinMaxValues(0, totalHeight - (menuHeight - 4))
        slider:SetValue(0)
        slider:SetValueStep(itemHeight)

        local thumb = slider:CreateTexture(nil, "OVERLAY")
        thumb:SetColorTexture(0.4, 0.4, 0.4, 0.8)
        thumb:SetSize(10, 40)
        slider:SetThumbTexture(thumb)

        slider:SetScript("OnValueChanged", function(self, value)
            scrollFrame:SetVerticalScroll(value)
        end)

        local function OnMouseWheel(self, delta)
            local cur = slider:GetValue()
            local _, maxVal = slider:GetMinMaxValues()
            slider:SetValue(math.max(0, math.min(maxVal, cur - delta * itemHeight * 3)))
        end

        menu:EnableMouseWheel(true)
        menu:SetScript("OnMouseWheel", OnMouseWheel)
        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", OnMouseWheel)
        scrollChild:EnableMouseWheel(true)
        scrollChild:SetScript("OnMouseWheel", OnMouseWheel)

        itemParent = scrollChild
    else
        itemParent = menu
    end

    for i, opt in ipairs(options) do
        local item = CreateFrame("Button", nil, itemParent)
        item:SetSize(106, 18)
        item:SetPoint("TOP", itemParent, "TOP", 0, -2 - (i-1) * itemHeight)
        item:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
        item:GetHighlightTexture():SetVertexColor(0.3, 0.3, 0.5, 0.5)

        local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemText:SetPoint("LEFT", 8, 0)
        itemText:SetText(opt.label)

        item:SetScript("OnClick", function()
            currentValue = opt.value
            btnText:SetText(opt.label)
            menu:Hide()
            onChange(opt.value)
        end)
    end

    btn:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
        else
            menu:Show()
        end
    end)

    btn.menu = menu
    btn.currentValue = currentValue
    btn.UpdateValue = function(newValue)
        currentValue = newValue
        UpdateText()
    end

    return btn
end

function addon.CreateConfigWindow()
    if addon.UI.configWindow then
        return addon.UI.configWindow
    end

    local frame = CreateFrame("Frame", "TotemBuddyConfigWindow", UIParent, "BackdropTemplate")
    frame:SetSize(560, 360)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("TotemBuddy Configuration")

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Enable Escape key to close (UISpecialFrames handles this automatically)
    tinsert(UISpecialFrames, "TotemBuddyConfigWindow")

    -- Tab system
    local tabs = {}
    local tabContent = {}

    local function SelectTab(tabName)
        for name, tab in pairs(tabs) do
            if name == tabName then
                tab:SetBackdropColor(0.2, 0.2, 0.2, 1)
                tab.text:SetTextColor(1, 1, 1)
                tabContent[name]:Show()
            else
                tab:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                tab.text:SetTextColor(0.6, 0.6, 0.6)
                tabContent[name]:Hide()
            end
        end
        frame.activeTab = tabName
    end

    local function CreateTab(name, displayName, xOffset)
        local tab = CreateFrame("Button", nil, frame, "BackdropTemplate")
        tab:SetSize(100, 28)
        tab:SetPoint("TOPLEFT", frame, "TOPLEFT", xOffset, -32)
        tab:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        tab:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        tab:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

        local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        text:SetText(displayName)
        tab.text = text

        tab:SetScript("OnClick", function() SelectTab(name) end)
        tabs[name] = tab
        return tab
    end

    CreateTab("layout", "Layout", 15)
    CreateTab("ordering", "Totem Order", 120)
    CreateTab("sounds", "Sounds", 225)
    CreateTab("macros", "Macros", 330)

    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", 15, -65)
    contentFrame:SetPoint("BOTTOMRIGHT", -15, 15)

    --------------------------
    -- LAYOUT TAB
    --------------------------
    local layoutContent = CreateFrame("Frame", nil, contentFrame)
    layoutContent:SetAllPoints()
    tabContent["layout"] = layoutContent

    local function CreateLayoutSection(parent, sectionTitle, yOffset, height, width, xOffset)
        local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        section:SetSize(width or 510, height)
        if xOffset then
            section:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
        else
            section:SetPoint("TOP", parent, "TOP", 0, yOffset)
        end
        section:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        section:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
        section:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        local label = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 10, -8)
        label:SetText(sectionTitle)
        label:SetTextColor(1, 0.82, 0)

        return section
    end

    -- Settings row with dropdowns
    local settingsSection = CreateLayoutSection(layoutContent, "Settings", 0, 100)

    frame.popupDirDropdown = CreateDropdown(settingsSection, "Popup Direction", {
        { label = "Up", value = "UP" },
        { label = "Down", value = "DOWN" },
        { label = "Left", value = "LEFT" },
        { label = "Right", value = "RIGHT" },
    }, TotemBuddyDB.popupDirection or "UP", 10, -20, function(value)
        TotemBuddyDB.popupDirection = value
        if not InCombatLockdown() then addon.RebuildPopupColumns() end
    end)

    -- Helper function to get timer position options based on style
    local function GetTimerPositionOptions(style)
        local options = {
            { label = "Above", value = "ABOVE" },
            { label = "Below", value = "BELOW" },
            { label = "Left", value = "LEFT" },
            { label = "Right", value = "RIGHT" },
        }
        if style == "icons" then
            table.insert(options, { label = "On Button", value = "ON" })
        end
        return options
    end

    -- Helper to rebuild timer position dropdown
    local function RebuildTimerPosDropdown(style)
        if frame.timerPosDropdownContainer then
            frame.timerPosDropdownContainer:Hide()
            frame.timerPosDropdownContainer:SetParent(nil)
        end

        local currentPos = TotemBuddyDB.timerPosition or "ABOVE"
        -- If "ON" is selected but we're switching to bars, reset to "ABOVE"
        if style == "bars" and currentPos == "ON" then
            currentPos = "ABOVE"
            TotemBuddyDB.timerPosition = currentPos
            addon.RebuildTimerFrame()
        end

        local container = CreateFrame("Frame", nil, settingsSection)
        container:SetSize(120, 40)
        container:SetPoint("TOPLEFT", settingsSection, "TOPLEFT", 135, -20)

        local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        labelText:SetPoint("TOPLEFT", 0, 0)
        labelText:SetText("Timer Position")
        labelText:SetTextColor(1, 0.82, 0)

        local options = GetTimerPositionOptions(style)

        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetSize(110, 22)
        btn:SetPoint("TOPLEFT", 0, -14)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
        btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnText:SetPoint("LEFT", 8, 0)
        btn.text = btnText

        local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrow:SetPoint("RIGHT", -6, 0)
        arrow:SetText("v")

        local function UpdateText()
            for _, opt in ipairs(options) do
                if opt.value == currentPos then
                    btnText:SetText(opt.label)
                    return
                end
            end
            btnText:SetText(options[1].label)
        end
        UpdateText()

        local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        menu:SetPoint("TOP", btn, "BOTTOM", 0, -2)
        menu:SetSize(110, #options * 20 + 4)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        menu:SetBackdropColor(0.15, 0.15, 0.15, 1)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:SetFrameStrata("TOOLTIP")
        menu:Hide()

        for i, opt in ipairs(options) do
            local item = CreateFrame("Button", nil, menu)
            item:SetSize(106, 18)
            item:SetPoint("TOP", menu, "TOP", 0, -2 - (i-1) * 20)
            item:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
            item:GetHighlightTexture():SetVertexColor(0.3, 0.3, 0.5, 0.5)

            local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            itemText:SetPoint("LEFT", 8, 0)
            itemText:SetText(opt.label)

            item:SetScript("OnClick", function()
                currentPos = opt.value
                TotemBuddyDB.timerPosition = opt.value
                btnText:SetText(opt.label)
                menu:Hide()
                addon.RebuildTimerFrame()
            end)
        end

        btn:SetScript("OnClick", function()
            if menu:IsShown() then
                menu:Hide()
            else
                menu:Show()
            end
        end)

        frame.timerPosDropdownContainer = container
        frame.timerPosDropdown = btn
    end

    -- Initial build of timer position dropdown
    RebuildTimerPosDropdown(TotemBuddyDB.timerStyle or "bars")

    frame.timerStyleDropdown = CreateDropdown(settingsSection, "Timer Style", {
        { label = "Bars", value = "bars" },
        { label = "Icons", value = "icons" },
    }, TotemBuddyDB.timerStyle or "bars", 260, -20, function(value)
        TotemBuddyDB.timerStyle = value
        -- Rebuild timer position dropdown to show/hide "On Button" option
        RebuildTimerPosDropdown(value)
        addon.UpdateTimers()
    end)

    frame.popupModDropdown = CreateDropdown(settingsSection, "Popup Modifier", {
        { label = "None", value = "NONE" },
        { label = "Shift", value = "SHIFT" },
        { label = "Ctrl", value = "CTRL" },
        { label = "Alt", value = "ALT" },
    }, TotemBuddyDB.popupModifier or "NONE", 385, -20, function(value)
        TotemBuddyDB.popupModifier = value
    end)

    frame.timerFontSizeDropdown = CreateDropdown(settingsSection, "Timer Font Size", {
        { label = "Small", value = "SMALL" },
        { label = "Normal", value = "NORMAL" },
        { label = "Large", value = "LARGE" },
    }, TotemBuddyDB.timerFontSize or "NORMAL", 260, -58, function(value)
        TotemBuddyDB.timerFontSize = value
        addon.UpdateTimerBarFonts()
        addon.UpdateIconTimerFonts()
    end)

    -- Scale slider
    local scaleContainer = CreateFrame("Frame", nil, settingsSection, "BackdropTemplate")
    scaleContainer:SetSize(200, 40)
    scaleContainer:SetPoint("TOPLEFT", settingsSection, "TOPLEFT", 10, -58)
    scaleContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    scaleContainer:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
    scaleContainer:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local scaleLabel = scaleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleLabel:SetPoint("TOPLEFT", 4, -2)
    scaleLabel:SetText("Scale")
    scaleLabel:SetTextColor(1, 0.82, 0)

    local scaleSlider = CreateFrame("Slider", nil, scaleContainer, "OptionsSliderTemplate")
    scaleSlider:SetSize(150, 16)
    scaleSlider:SetPoint("TOPLEFT", 4, -16)
    scaleSlider:SetMinMaxValues(0.5, 1.5)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:SetValue(TotemBuddyDB.barScale or 1.0)
    scaleSlider.Low:SetText("50%")
    scaleSlider.High:SetText("150%")

    local scaleValueText = scaleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleValueText:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
    scaleValueText:SetText(string.format("%d%%", (TotemBuddyDB.barScale or 1.0) * 100))

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20 -- Round to nearest 0.05
        TotemBuddyDB.barScale = value
        scaleValueText:SetText(string.format("%d%%", value * 100))
        if addon.UI.actionBarFrame then
            addon.UI.actionBarFrame:SetScale(value)
        end
    end)
    frame.scaleSlider = scaleSlider


    -- Options (full width, 2-column layout for checkboxes)
    local optionsSection = CreateLayoutSection(layoutContent, "Options", -130, 155)

    -- Left column
    local showTimersCheck = CreateFrame("CheckButton", nil, optionsSection, "UICheckButtonTemplate")
    showTimersCheck:SetPoint("TOPLEFT", 10, -28)
    showTimersCheck:SetChecked(TotemBuddyDB.showTimers)
    showTimersCheck:SetScript("OnClick", function(self)
        TotemBuddyDB.showTimers = self:GetChecked()
        local timerFrame = addon.UI.timerFrame
        if not TotemBuddyDB.showTimers and timerFrame then
            timerFrame:Hide()
        elseif TotemBuddyDB.showTimers then
            addon.UpdateTimers()
        end
    end)
    local showTimersLabel = optionsSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showTimersLabel:SetPoint("LEFT", showTimersCheck, "RIGHT", 4, 0)
    showTimersLabel:SetText("Show Timers")
    frame.showTimersCheck = showTimersCheck

    local lockPosCheck = CreateFrame("CheckButton", nil, optionsSection, "UICheckButtonTemplate")
    lockPosCheck:SetPoint("TOPLEFT", 10, -52)
    lockPosCheck:SetChecked(TotemBuddyDB.locked)
    lockPosCheck:SetScript("OnClick", function(self)
        TotemBuddyDB.locked = self:GetChecked()
    end)
    local lockPosLabel = optionsSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lockPosLabel:SetPoint("LEFT", lockPosCheck, "RIGHT", 4, 0)
    lockPosLabel:SetText("Lock Bar Position")
    frame.lockPosCheck = lockPosCheck

    local alwaysShowCheck = CreateFrame("CheckButton", nil, optionsSection, "UICheckButtonTemplate")
    alwaysShowCheck:SetPoint("TOPLEFT", 10, -76)
    alwaysShowCheck:SetChecked(TotemBuddyDB.alwaysShowPopup)
    alwaysShowCheck:SetScript("OnClick", function(self)
        TotemBuddyDB.alwaysShowPopup = self:GetChecked()
        if TotemBuddyDB.alwaysShowPopup then
            addon.ShowPopup(GetElementOrder()[1])
            -- Disable "Disable Popup in Combat" option
            if frame.disablePopupCombatCheck then
                frame.disablePopupCombatCheck:SetChecked(false)
                frame.disablePopupCombatCheck:Disable()
                frame.disablePopupCombatCheck.label:SetTextColor(0.5, 0.5, 0.5)
                TotemBuddyDB.disablePopupInCombat = false
            end
        else
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
            -- Re-enable "Disable Popup in Combat" option
            if frame.disablePopupCombatCheck then
                frame.disablePopupCombatCheck:Enable()
                frame.disablePopupCombatCheck.label:SetTextColor(1, 1, 1)
            end
        end
    end)
    local alwaysShowLabel = optionsSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alwaysShowLabel:SetPoint("LEFT", alwaysShowCheck, "RIGHT", 4, 0)
    alwaysShowLabel:SetText("Always Show Popup")
    frame.alwaysShowCheck = alwaysShowCheck

    local dimRangeCheck = CreateFrame("CheckButton", nil, optionsSection, "UICheckButtonTemplate")
    dimRangeCheck:SetPoint("TOPLEFT", 10, -100)
    dimRangeCheck:SetChecked(TotemBuddyDB.dimOutOfRange)
    dimRangeCheck:SetScript("OnClick", function(self)
        TotemBuddyDB.dimOutOfRange = self:GetChecked()
    end)
    local dimRangeLabel = optionsSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dimRangeLabel:SetPoint("LEFT", dimRangeCheck, "RIGHT", 4, 0)
    dimRangeLabel:SetText("Dim out of range")
    -- Example icons showing the effect
    local dimExampleIcon1 = optionsSection:CreateTexture(nil, "ARTWORK")
    dimExampleIcon1:SetSize(18, 18)
    dimExampleIcon1:SetPoint("LEFT", dimRangeLabel, "RIGHT", 8, 0)
    dimExampleIcon1:SetTexture(136102) -- Earthbind Totem icon
    dimExampleIcon1:SetAlpha(0.4)
    local dimArrowLabel = optionsSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dimArrowLabel:SetPoint("LEFT", dimExampleIcon1, "RIGHT", 4, 0)
    dimArrowLabel:SetText("vs")
    dimArrowLabel:SetTextColor(0.6, 0.6, 0.6)
    local dimExampleIcon2 = optionsSection:CreateTexture(nil, "ARTWORK")
    dimExampleIcon2:SetSize(18, 18)
    dimExampleIcon2:SetPoint("LEFT", dimArrowLabel, "RIGHT", 4, 0)
    dimExampleIcon2:SetTexture(136102) -- Earthbind Totem icon
    dimExampleIcon2:SetAlpha(1.0)
    frame.dimRangeCheck = dimRangeCheck

    local greyPlacedCheck = CreateFrame("CheckButton", nil, optionsSection, "UICheckButtonTemplate")
    greyPlacedCheck:SetPoint("TOPLEFT", 10, -124)
    greyPlacedCheck:SetChecked(TotemBuddyDB.greyOutPlacedTotem)
    greyPlacedCheck:SetScript("OnClick", function(self)
        TotemBuddyDB.greyOutPlacedTotem = self:GetChecked()
    end)
    local greyPlacedLabel = optionsSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    greyPlacedLabel:SetPoint("LEFT", greyPlacedCheck, "RIGHT", 4, 0)
    greyPlacedLabel:SetText("Grey out non-active totem")
    -- Example icons showing the effect
    local exampleIcon1 = optionsSection:CreateTexture(nil, "ARTWORK")
    exampleIcon1:SetSize(18, 18)
    exampleIcon1:SetPoint("LEFT", greyPlacedLabel, "RIGHT", 8, 0)
    exampleIcon1:SetTexture(136102) -- Earthbind Totem icon
    exampleIcon1:SetDesaturated(true)
    local arrowLabel = optionsSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrowLabel:SetPoint("LEFT", exampleIcon1, "RIGHT", 4, 0)
    arrowLabel:SetText("vs")
    arrowLabel:SetTextColor(0.6, 0.6, 0.6)
    local exampleIcon2 = optionsSection:CreateTexture(nil, "ARTWORK")
    exampleIcon2:SetSize(18, 18)
    exampleIcon2:SetPoint("LEFT", arrowLabel, "RIGHT", 4, 0)
    exampleIcon2:SetTexture(136102) -- Earthbind Totem icon
    exampleIcon2:SetDesaturated(false)
    frame.greyPlacedCheck = greyPlacedCheck

    -- Right column
    local showReincCheck = CreateFrame("CheckButton", nil, optionsSection, "UICheckButtonTemplate")
    showReincCheck:SetPoint("TOPLEFT", 260, -28)
    showReincCheck:SetChecked(TotemBuddyDB.showReincarnation)
    showReincCheck:SetScript("OnClick", function(self)
        TotemBuddyDB.showReincarnation = self:GetChecked()
        if not InCombatLockdown() then
            addon.RebuildPopupColumns()
        else
            print("|cFF00FF00TotemBuddy:|r Change will apply after combat")
        end
    end)
    local showReincLabel = optionsSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showReincLabel:SetPoint("LEFT", showReincCheck, "RIGHT", 4, 0)
    showReincLabel:SetText("Show Reincarnation")
    frame.showReincCheck = showReincCheck

    local showWeaponCheck = CreateFrame("CheckButton", nil, optionsSection, "UICheckButtonTemplate")
    showWeaponCheck:SetPoint("TOPLEFT", 260, -52)
    showWeaponCheck:SetChecked(TotemBuddyDB.showWeaponBuffs)
    showWeaponCheck:SetScript("OnClick", function(self)
        TotemBuddyDB.showWeaponBuffs = self:GetChecked()
        if not InCombatLockdown() then
            addon.RebuildPopupColumns()
        else
            print("|cFF00FF00TotemBuddy:|r Change will apply after combat")
        end
    end)
    local showWeaponLabel = optionsSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showWeaponLabel:SetPoint("LEFT", showWeaponCheck, "RIGHT", 4, 0)
    showWeaponLabel:SetText("Show Weapon Buffs")
    frame.showWeaponCheck = showWeaponCheck

    local disablePopupCombatCheck = CreateFrame("CheckButton", nil, optionsSection, "UICheckButtonTemplate")
    disablePopupCombatCheck:SetPoint("TOPLEFT", 260, -76)
    disablePopupCombatCheck:SetChecked(TotemBuddyDB.disablePopupInCombat)
    disablePopupCombatCheck:SetScript("OnClick", function(self)
        TotemBuddyDB.disablePopupInCombat = self:GetChecked()
    end)
    local disablePopupCombatLabel = optionsSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    disablePopupCombatLabel:SetPoint("LEFT", disablePopupCombatCheck, "RIGHT", 4, 0)
    disablePopupCombatLabel:SetText("Disable Popup in Combat")
    disablePopupCombatCheck.label = disablePopupCombatLabel
    -- Tooltip for the checkbox
    disablePopupCombatCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Disable Popup in Combat")
        GameTooltip:AddLine("Workaround for in-combat click-through issues.", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("When enabled, popup bars are completely removed during combat instead of just hidden.", 0.7, 0.7, 0.7, true)
        if TotemBuddyDB.alwaysShowPopup then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Disabled while 'Always Show Popup' is enabled.", 1, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end)
    disablePopupCombatCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Disable if Always Show Popup is enabled
    if TotemBuddyDB.alwaysShowPopup then
        disablePopupCombatCheck:SetChecked(false)
        disablePopupCombatCheck:Disable()
        disablePopupCombatLabel:SetTextColor(0.5, 0.5, 0.5)
        TotemBuddyDB.disablePopupInCombat = false
    end
    frame.disablePopupCombatCheck = disablePopupCombatCheck

    local showTooltipsCheck = CreateFrame("CheckButton", nil, optionsSection, "UICheckButtonTemplate")
    showTooltipsCheck:SetPoint("TOPLEFT", 260, -100)
    showTooltipsCheck:SetChecked(TotemBuddyDB.showTooltips ~= false) -- Default to true
    showTooltipsCheck:SetScript("OnClick", function(self)
        TotemBuddyDB.showTooltips = self:GetChecked()
    end)
    local showTooltipsLabel = optionsSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showTooltipsLabel:SetPoint("LEFT", showTooltipsCheck, "RIGHT", 4, 0)
    showTooltipsLabel:SetText("Show Tooltips")
    frame.showTooltipsCheck = showTooltipsCheck

    local showOOMOverlayCheck = CreateFrame("CheckButton", nil, optionsSection, "UICheckButtonTemplate")
    showOOMOverlayCheck:SetPoint("TOPLEFT", 260, -124)
    showOOMOverlayCheck:SetChecked(TotemBuddyDB.showLowManaOverlay ~= false)
    showOOMOverlayCheck:SetScript("OnClick", function(self)
        TotemBuddyDB.showLowManaOverlay = self:GetChecked()
        addon.UpdateManaOverlays()
    end)
    local showOOMOverlayLabel = optionsSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showOOMOverlayLabel:SetPoint("LEFT", showOOMOverlayCheck, "RIGHT", 4, 0)
    showOOMOverlayLabel:SetText("Show Low Mana Overlay")
    frame.showOOMOverlayCheck = showOOMOverlayCheck

    --------------------------
    -- ORDERING TAB
    --------------------------
    local orderingContent = CreateFrame("Frame", nil, contentFrame)
    orderingContent:SetAllPoints()
    tabContent["ordering"] = orderingContent

    -- Element Order Section (at the top)
    local elementOrderSection = CreateFrame("Frame", nil, orderingContent, "BackdropTemplate")
    elementOrderSection:SetSize(520, 45)
    elementOrderSection:SetPoint("TOP", orderingContent, "TOP", 0, 0)
    elementOrderSection:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    elementOrderSection:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    elementOrderSection:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local elementOrderLabel = elementOrderSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    elementOrderLabel:SetPoint("TOP", 0, -4)
    elementOrderLabel:SetText("Element Order")

    local elementOrderButtons = {}
    local function RefreshElementOrderButtons()
        local order = GetElementOrder()
        for i, btn in ipairs(elementOrderButtons) do
            local element = order[i]
            local color = ELEMENT_COLORS[element]
            btn.element = element
            btn.text:SetText(element:sub(1, 1))
            btn.text:SetTextColor(color.r, color.g, color.b)
            btn:SetBackdropBorderColor(color.r, color.g, color.b, 1)
            btn.leftBtn:SetEnabled(i > 1)
            btn.rightBtn:SetEnabled(i < 4)
        end
    end

    local function SwapElements(idx1, idx2)
        local order = TotemBuddyDB.elementOrder
        order[idx1], order[idx2] = order[idx2], order[idx1]
        RefreshElementOrderButtons()
    end

    for i = 1, 4 do
        local btnFrame = CreateFrame("Frame", nil, elementOrderSection, "BackdropTemplate")
        btnFrame:SetSize(32, 22)
        btnFrame:SetPoint("LEFT", elementOrderSection, "LEFT", 70 + (i - 1) * 100, -4)
        btnFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btnFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)

        local text = btnFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        btnFrame.text = text

        local leftBtn = CreateFrame("Button", nil, btnFrame, "UIPanelButtonTemplate")
        leftBtn:SetSize(18, 18)
        leftBtn:SetPoint("RIGHT", btnFrame, "LEFT", -2, 0)
        leftBtn:SetText("<")
        leftBtn:SetScript("OnClick", function() SwapElements(i, i - 1) end)
        btnFrame.leftBtn = leftBtn

        local rightBtn = CreateFrame("Button", nil, btnFrame, "UIPanelButtonTemplate")
        rightBtn:SetSize(18, 18)
        rightBtn:SetPoint("LEFT", btnFrame, "RIGHT", 2, 0)
        rightBtn:SetText(">")
        rightBtn:SetScript("OnClick", function() SwapElements(i, i + 1) end)
        btnFrame.rightBtn = rightBtn

        elementOrderButtons[i] = btnFrame
    end

    RefreshElementOrderButtons()
    frame.RefreshElementOrderButtons = RefreshElementOrderButtons

    -- Totem Order Sections (shifted down)
    local sectionWidth = 255
    local sectionHeight = 90
    local sections = {}
    local totemSectionTopOffset = -50

    for i, element in ipairs(ELEMENT_ORDER) do
        local color = ELEMENT_COLORS[element]
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)

        local section = CreateFrame("Frame", nil, orderingContent, "BackdropTemplate")
        section:SetSize(sectionWidth, sectionHeight)
        section:SetPoint("TOPLEFT", orderingContent, "TOPLEFT", col * (sectionWidth + 10), totemSectionTopOffset - row * (sectionHeight + 5))
        section:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        section:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
        section:SetBackdropBorderColor(color.r, color.g, color.b, 1)

        local label = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOP", 0, -4)
        label:SetText(element)
        label:SetTextColor(color.r, color.g, color.b)

        local scrollFrame = CreateFrame("ScrollFrame", nil, section, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 8, -20)
        scrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(sectionWidth - 40, 200)
        scrollFrame:SetScrollChild(scrollChild)

        section.scrollChild = scrollChild
        section.element = element
        sections[element] = section
    end

    local orderButtonContainer = CreateFrame("Frame", nil, orderingContent)
    orderButtonContainer:SetSize(520, 26)
    orderButtonContainer:SetPoint("BOTTOM", orderingContent, "BOTTOM", 0, 0)

    local resetBtn = CreateFrame("Button", nil, orderButtonContainer, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 24)
    resetBtn:SetPoint("RIGHT", orderButtonContainer, "CENTER", 65, 0)
    resetBtn:SetText("Reset to Default")
    resetBtn:SetScript("OnClick", function()
        -- Reset element order
        TotemBuddyDB.elementOrder = { "Earth", "Fire", "Water", "Air" }
        RefreshElementOrderButtons()
        -- Reset totem order and hidden totems within each element
        for _, element in ipairs(ELEMENT_ORDER) do
            TotemBuddyDB.totemOrder[element] = {}
            TotemBuddyDB.hiddenTotems[element] = {}
            PopulateConfigSection(sections[element].scrollChild, element)
        end
        print("|cFF00FF00TotemBuddy:|r Order reset to default")
    end)

    local applyBtn = CreateFrame("Button", nil, orderButtonContainer, "UIPanelButtonTemplate")
    applyBtn:SetSize(100, 24)
    applyBtn:SetPoint("RIGHT", resetBtn, "LEFT", -10, 0)
    applyBtn:SetText("Apply")
    applyBtn:SetScript("OnClick", function()
        if InCombatLockdown() then
            print("|cFF00FF00TotemBuddy:|r Cannot apply changes in combat")
            return
        end
        addon.RebuildPopupColumns()
        print("|cFF00FF00TotemBuddy:|r Order applied")
    end)

    --------------------------
    -- SOUNDS TAB
    --------------------------
    local soundsContent = CreateFrame("Frame", nil, contentFrame)
    soundsContent:SetAllPoints()
    tabContent["sounds"] = soundsContent

    -- Totem Expiry Alerts Section
    local expirySection = CreateFrame("Frame", nil, soundsContent, "BackdropTemplate")
    expirySection:SetSize(520, 220)
    expirySection:SetPoint("TOP", soundsContent, "TOP", 0, 0)
    expirySection:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    expirySection:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    expirySection:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local expiryLabel = expirySection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    expiryLabel:SetPoint("TOPLEFT", 10, -8)
    expiryLabel:SetText("Totem Expiry Alerts")
    expiryLabel:SetTextColor(1, 0.82, 0)

    -- Master enable checkbox
    local masterSoundCheck = CreateFrame("CheckButton", nil, expirySection, "UICheckButtonTemplate")
    masterSoundCheck:SetPoint("TOPLEFT", 10, -30)
    masterSoundCheck:SetChecked(TotemBuddyDB.totemExpirySound ~= false)
    local masterSoundLabel = expirySection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    masterSoundLabel:SetPoint("LEFT", masterSoundCheck, "RIGHT", 4, 0)
    masterSoundLabel:SetText("Enable expiry sounds (5 sec warning)")
    frame.masterSoundCheck = masterSoundCheck

    -- Build sound options list for dropdowns
    local soundOptions = {}
    for _, sound in ipairs(addon.EXPIRY_SOUNDS) do
        table.insert(soundOptions, { label = sound.name, value = sound.path or sound.id })
    end

    -- Per-element sound dropdowns
    local elementSoundDropdowns = {}
    local elementSoundPreviews = {}

    local function UpdateSoundDropdownStates()
        local enabled = masterSoundCheck:GetChecked()
        for element, dropdown in pairs(elementSoundDropdowns) do
            if enabled then
                dropdown:Enable()
                dropdown:SetAlpha(1)
                if elementSoundPreviews[element] then
                    elementSoundPreviews[element]:Enable()
                    elementSoundPreviews[element]:SetAlpha(1)
                end
            else
                dropdown:Disable()
                dropdown:SetAlpha(0.5)
                if elementSoundPreviews[element] then
                    elementSoundPreviews[element]:Disable()
                    elementSoundPreviews[element]:SetAlpha(0.5)
                end
            end
        end
        if frame.setAllSoundDropdown then
            if enabled then
                frame.setAllSoundDropdown:Enable()
                frame.setAllSoundDropdown:SetAlpha(1)
            else
                frame.setAllSoundDropdown:Disable()
                frame.setAllSoundDropdown:SetAlpha(0.5)
            end
        end
    end

    masterSoundCheck:SetScript("OnClick", function(self)
        TotemBuddyDB.totemExpirySound = self:GetChecked()
        UpdateSoundDropdownStates()
    end)

    for i, element in ipairs(ELEMENT_ORDER) do
        local color = ELEMENT_COLORS[element]
        local yOffset = -55 - (i - 1) * 30

        -- Element label
        local elemLabel = expirySection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        elemLabel:SetPoint("TOPLEFT", 20, yOffset)
        elemLabel:SetText(element .. ":")
        elemLabel:SetTextColor(color.r, color.g, color.b)
        elemLabel:SetWidth(50)
        elemLabel:SetJustifyH("RIGHT")

        -- Sound dropdown
        local currentSoundID = (TotemBuddyDB.totemExpirySoundIDs and TotemBuddyDB.totemExpirySoundIDs[element]) or 8959
        local dropdown = CreateDropdown(expirySection, "", soundOptions, currentSoundID, 80, yOffset + 12, function(value)
            if not TotemBuddyDB.totemExpirySoundIDs then
                TotemBuddyDB.totemExpirySoundIDs = {}
            end
            TotemBuddyDB.totemExpirySoundIDs[element] = value
        end)
        elementSoundDropdowns[element] = dropdown

        -- Preview button
        local previewBtn = CreateFrame("Button", nil, expirySection, "UIPanelButtonTemplate")
        previewBtn:SetSize(22, 22)
        previewBtn:SetPoint("LEFT", dropdown, "RIGHT", 5, 0)
        previewBtn:SetText(">")
        previewBtn:SetScript("OnClick", function()
            local soundValue = TotemBuddyDB.totemExpirySoundIDs and TotemBuddyDB.totemExpirySoundIDs[element] or 8959
            if soundValue then
                if type(soundValue) == "string" then
                    PlaySoundFile(soundValue, "Master")
                elseif soundValue > 0 then
                    PlaySound(soundValue, "Master")
                end
            end
        end)
        previewBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Preview sound")
            GameTooltip:Show()
        end)
        previewBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        elementSoundPreviews[element] = previewBtn
    end

    frame.elementSoundDropdowns = elementSoundDropdowns

    -- "Set All" dropdown
    local setAllLabel = expirySection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    setAllLabel:SetPoint("TOPLEFT", 20, -180)
    setAllLabel:SetText("Set All:")
    setAllLabel:SetTextColor(0.7, 0.7, 0.7)

    local setAllDropdown = CreateDropdown(expirySection, "", soundOptions, 8959, 80, -168, function(value)
        if not TotemBuddyDB.totemExpirySoundIDs then
            TotemBuddyDB.totemExpirySoundIDs = {}
        end
        for _, element in ipairs(ELEMENT_ORDER) do
            TotemBuddyDB.totemExpirySoundIDs[element] = value
            if elementSoundDropdowns[element] and elementSoundDropdowns[element].UpdateValue then
                elementSoundDropdowns[element].UpdateValue(value)
            end
        end
    end)
    frame.setAllSoundDropdown = setAllDropdown

    -- Initialize dropdown states based on master toggle
    UpdateSoundDropdownStates()
    frame.UpdateSoundDropdownStates = UpdateSoundDropdownStates

    --------------------------
    -- MACROS TAB
    --------------------------
    local macrosContent = CreateFrame("Frame", nil, contentFrame)
    macrosContent:SetAllPoints()
    tabContent["macros"] = macrosContent

    -- Default Macros Section
    local defaultMacrosSection = CreateFrame("Frame", nil, macrosContent, "BackdropTemplate")
    defaultMacrosSection:SetSize(520, 100)
    defaultMacrosSection:SetPoint("TOP", macrosContent, "TOP", 0, 0)
    defaultMacrosSection:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    defaultMacrosSection:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    defaultMacrosSection:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local defaultMacrosLabel = defaultMacrosSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    defaultMacrosLabel:SetPoint("TOPLEFT", 10, -8)
    defaultMacrosLabel:SetText("Default Macros")
    defaultMacrosLabel:SetTextColor(1, 0.82, 0)

    local defaultMacroCheckboxes = {}
    local defaultMacroInfo = {
        { name = "TBEarth", desc = "Earth" },
        { name = "TBFire", desc = "Fire" },
        { name = "TBWater", desc = "Water" },
        { name = "TBAir", desc = "Air" },
        { name = "TBAll", desc = "All sequence" },
    }

    for i, info in ipairs(defaultMacroInfo) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)

        local check = CreateFrame("CheckButton", nil, defaultMacrosSection, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 10 + col * 170, -28 - row * 24)

        local enabled = true
        if TotemBuddyDB.defaultMacrosEnabled and TotemBuddyDB.defaultMacrosEnabled[info.name] ~= nil then
            enabled = TotemBuddyDB.defaultMacrosEnabled[info.name]
        end
        check:SetChecked(enabled)

        check:SetScript("OnClick", function(self)
            addon.SetDefaultMacroEnabled(info.name, self:GetChecked())
        end)

        local label = defaultMacrosSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", check, "RIGHT", 2, 0)
        label:SetText(info.name .. " - " .. info.desc)

        defaultMacroCheckboxes[info.name] = check
    end
    frame.defaultMacroCheckboxes = defaultMacroCheckboxes

    local macrosBtn = CreateFrame("Button", nil, defaultMacrosSection, "UIPanelButtonTemplate")
    macrosBtn:SetSize(120, 22)
    macrosBtn:SetPoint("TOPLEFT", 10, -76)
    macrosBtn:SetText("Recreate Macros")
    macrosBtn:SetScript("OnClick", function()
        local success, message = addon.CreateTotemMacros()
        if success then
            print("|cFF00FF00TotemBuddy:|r " .. message)
        else
            print("|cFFFF0000TotemBuddy:|r " .. message)
        end
    end)

    -- Custom Macros Section
    local customMacrosSection = CreateFrame("Frame", nil, macrosContent, "BackdropTemplate")
    customMacrosSection:SetSize(520, 190)
    customMacrosSection:SetPoint("TOP", defaultMacrosSection, "BOTTOM", 0, -10)
    customMacrosSection:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    customMacrosSection:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    customMacrosSection:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local customMacrosLabel = customMacrosSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    customMacrosLabel:SetPoint("TOPLEFT", 10, -8)
    customMacrosLabel:SetText("Custom Macros")
    customMacrosLabel:SetTextColor(1, 0.82, 0)

    -- Custom macro list (scrollable)
    local customListScroll = CreateFrame("ScrollFrame", nil, customMacrosSection, "UIPanelScrollFrameTemplate")
    customListScroll:SetPoint("TOPLEFT", 10, -28)
    customListScroll:SetSize(110, 130)

    local customListChild = CreateFrame("Frame", nil, customListScroll)
    customListChild:SetSize(85, 200)
    customListScroll:SetScrollChild(customListChild)

    local customMacroButtons = {}
    local selectedCustomMacro = nil

    local function RefreshCustomMacroList()
        for _, btn in ipairs(customMacroButtons) do
            btn:Hide()
        end
        customMacroButtons = {}

        if not TotemBuddyDB.customMacros then return end

        for i, macro in ipairs(TotemBuddyDB.customMacros) do
            local btn = CreateFrame("Button", nil, customListChild)
            btn:SetSize(80, 20)
            btn:SetPoint("TOPLEFT", 0, -((i - 1) * 22))
            btn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
            btn:GetHighlightTexture():SetVertexColor(0.3, 0.3, 0.5, 0.5)

            local btnBg = btn:CreateTexture(nil, "BACKGROUND")
            btnBg:SetAllPoints()
            btnBg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
            btn.bg = btnBg

            local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btnText:SetPoint("LEFT", 4, 0)
            btnText:SetText((macro.enabled and "" or "|cFF888888") .. macro.name .. (macro.enabled and "" or "|r"))
            btn.text = btnText

            btn.macroIndex = i
            btn:SetScript("OnClick", function(self)
                selectedCustomMacro = self.macroIndex
                -- Update selection highlight
                for _, b in ipairs(customMacroButtons) do
                    if b.macroIndex == selectedCustomMacro then
                        b.bg:SetColorTexture(0.2, 0.3, 0.4, 1)
                    else
                        b.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
                    end
                end
                -- Load into editor
                local m = TotemBuddyDB.customMacros[selectedCustomMacro]
                if m then
                    frame.macroNameEditBox:SetText(m.name or "")
                    frame.macroTemplateEditBox:SetText(m.template or "")
                    frame.macroEnabledCheck:SetChecked(m.enabled)
                end
            end)

            customMacroButtons[i] = btn
        end
    end

    -- Editor panel (positioned absolutely so it doesn't move with list width)
    local editorPanel = CreateFrame("Frame", nil, customMacrosSection)
    editorPanel:SetPoint("TOPLEFT", customMacrosSection, "TOPLEFT", 160, -28)
    editorPanel:SetSize(350, 140)

    -- Name input
    local nameLabel = editorPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", 0, 0)
    nameLabel:SetText("Name:")
    nameLabel:SetTextColor(0.8, 0.8, 0.8)

    local nameEditBox = CreateFrame("EditBox", nil, editorPanel, "BackdropTemplate")
    nameEditBox:SetSize(100, 18)
    nameEditBox:SetPoint("LEFT", nameLabel, "RIGHT", 5, 0)
    nameEditBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    nameEditBox:SetBackdropColor(0.1, 0.1, 0.1, 1)
    nameEditBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    nameEditBox:SetFontObject("GameFontNormalSmall")
    nameEditBox:SetAutoFocus(false)
    nameEditBox:SetMaxLetters(16)
    nameEditBox:SetTextInsets(4, 4, 0, 0)
    frame.macroNameEditBox = nameEditBox

    -- Enabled checkbox
    local enabledCheck = CreateFrame("CheckButton", nil, editorPanel, "UICheckButtonTemplate")
    enabledCheck:SetPoint("LEFT", nameEditBox, "RIGHT", 10, 0)
    enabledCheck:SetChecked(true)
    enabledCheck:SetSize(20, 20)
    frame.macroEnabledCheck = enabledCheck

    local enabledLabel = editorPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enabledLabel:SetPoint("LEFT", enabledCheck, "RIGHT", 0, 0)
    enabledLabel:SetText("Enabled")

    -- Template input
    local templateLabel = editorPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    templateLabel:SetPoint("TOPLEFT", 0, -24)
    templateLabel:SetText("Template:")
    templateLabel:SetTextColor(0.8, 0.8, 0.8)

    local templateScroll = CreateFrame("ScrollFrame", nil, editorPanel, "UIPanelScrollFrameTemplate")
    templateScroll:SetPoint("TOPLEFT", 0, -40)
    templateScroll:SetSize(340, 42)

    local templateEditBox = CreateFrame("EditBox", nil, templateScroll, "BackdropTemplate")
    templateEditBox:SetSize(320, 100)
    templateEditBox:SetMultiLine(true)
    templateEditBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    templateEditBox:SetBackdropColor(0.1, 0.1, 0.1, 1)
    templateEditBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    templateEditBox:SetFontObject("GameFontNormalSmall")
    templateEditBox:SetAutoFocus(false)
    templateEditBox:SetMaxLetters(255)
    templateEditBox:SetTextInsets(4, 4, 4, 4)
    templateScroll:SetScrollChild(templateEditBox)
    frame.macroTemplateEditBox = templateEditBox

    -- Placeholder insert buttons
    local placeholderLabel = editorPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    placeholderLabel:SetPoint("TOPLEFT", templateScroll, "BOTTOMLEFT", 0, -6)
    placeholderLabel:SetText("Insert:")
    placeholderLabel:SetTextColor(0.6, 0.6, 0.6)

    local placeholderButtons = {}
    local placeholders = {
        { name = "{earth}", color = ELEMENT_COLORS["Earth"] },
        { name = "{fire}", color = ELEMENT_COLORS["Fire"] },
        { name = "{water}", color = ELEMENT_COLORS["Water"] },
        { name = "{air}", color = ELEMENT_COLORS["Air"] },
    }

    for i, placeholder in ipairs(placeholders) do
        local btn = CreateFrame("Button", nil, editorPanel, "UIPanelButtonTemplate")
        btn:SetSize(52, 18)
        if i == 1 then
            btn:SetPoint("LEFT", placeholderLabel, "RIGHT", 5, 0)
        else
            btn:SetPoint("LEFT", placeholderButtons[i-1], "RIGHT", 3, 0)
        end
        btn:SetText(placeholder.name)
        btn:GetFontString():SetTextColor(placeholder.color.r, placeholder.color.g, placeholder.color.b)
        btn:SetScript("OnClick", function()
            local cursorPos = templateEditBox:GetCursorPosition()
            local text = templateEditBox:GetText()
            local before = text:sub(1, cursorPos)
            local after = text:sub(cursorPos + 1)
            templateEditBox:SetText(before .. placeholder.name .. after)
            templateEditBox:SetCursorPosition(cursorPos + #placeholder.name)
            templateEditBox:SetFocus()
        end)
        placeholderButtons[i] = btn
    end

    -- Buttons
    local addNewBtn = CreateFrame("Button", nil, customMacrosSection, "UIPanelButtonTemplate")
    addNewBtn:SetSize(50, 18)
    addNewBtn:SetPoint("LEFT", customMacrosLabel, "RIGHT", 10, 0)
    addNewBtn:SetText("+ New")
    addNewBtn:SetScript("OnClick", function()
        selectedCustomMacro = nil
        nameEditBox:SetText("")
        templateEditBox:SetText("#showtooltip\n/cast ")
        enabledCheck:SetChecked(true)
        -- Clear selection highlight
        for _, b in ipairs(customMacroButtons) do
            b.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
        end
    end)

    local saveBtn = CreateFrame("Button", nil, editorPanel, "UIPanelButtonTemplate")
    saveBtn:SetSize(60, 20)
    saveBtn:SetPoint("TOPLEFT", placeholderLabel, "BOTTOMLEFT", 0, -8)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        local name = nameEditBox:GetText():gsub("^%s*(.-)%s*$", "%1") -- trim
        local template = templateEditBox:GetText()
        local enabled = enabledCheck:GetChecked()

        if name == "" then
            print("|cFFFF0000TotemBuddy:|r Macro name is required")
            return
        end

        if not TotemBuddyDB.customMacros then
            TotemBuddyDB.customMacros = {}
        end

        if selectedCustomMacro then
            -- Update existing
            local oldName = TotemBuddyDB.customMacros[selectedCustomMacro].name
            if oldName ~= name then
                -- Name changed, delete old macro
                addon.DeleteCustomMacro(oldName)
            end
            TotemBuddyDB.customMacros[selectedCustomMacro] = {
                name = name,
                template = template,
                enabled = enabled,
            }
        else
            -- Check for duplicate name
            for _, m in ipairs(TotemBuddyDB.customMacros) do
                if m.name == name then
                    print("|cFFFF0000TotemBuddy:|r A macro with that name already exists")
                    return
                end
            end
            -- Add new
            table.insert(TotemBuddyDB.customMacros, {
                name = name,
                template = template,
                enabled = enabled,
            })
            selectedCustomMacro = #TotemBuddyDB.customMacros
        end

        addon.UpdateCustomMacros()
        RefreshCustomMacroList()
        print("|cFF00FF00TotemBuddy:|r Macro saved")
    end)

    local previewBtn = CreateFrame("Button", nil, editorPanel, "UIPanelButtonTemplate")
    previewBtn:SetSize(60, 20)
    previewBtn:SetPoint("LEFT", saveBtn, "RIGHT", 5, 0)
    previewBtn:SetText("Preview")
    previewBtn:SetScript("OnClick", function()
        local template = templateEditBox:GetText()
        local expanded = addon.ProcessMacroTemplate(template)
        print("|cFF00FF00TotemBuddy Preview:|r")
        for line in expanded:gmatch("[^\n]+") do
            print("  " .. line)
        end
    end)

    local deleteBtn = CreateFrame("Button", nil, editorPanel, "UIPanelButtonTemplate")
    deleteBtn:SetSize(60, 20)
    deleteBtn:SetPoint("LEFT", previewBtn, "RIGHT", 5, 0)
    deleteBtn:SetText("Delete")
    deleteBtn:SetScript("OnClick", function()
        if not selectedCustomMacro then
            print("|cFFFF0000TotemBuddy:|r No macro selected")
            return
        end

        local macro = TotemBuddyDB.customMacros[selectedCustomMacro]
        if macro then
            addon.DeleteCustomMacro(macro.name)
            table.remove(TotemBuddyDB.customMacros, selectedCustomMacro)
        end

        selectedCustomMacro = nil
        nameEditBox:SetText("")
        templateEditBox:SetText("")
        enabledCheck:SetChecked(true)
        RefreshCustomMacroList()
        print("|cFF00FF00TotemBuddy:|r Macro deleted")
    end)

    -- Example macro
    local exampleLabel = customMacrosSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    exampleLabel:SetPoint("BOTTOMLEFT", customMacrosSection, "BOTTOMLEFT", 10, 8)
    exampleLabel:SetPoint("RIGHT", customMacrosSection, "RIGHT", -10, 0)
    exampleLabel:SetJustifyH("LEFT")
    exampleLabel:SetText("|cFF888888Example:|r  /castsequence reset=combat {earth}, {fire}, {water}, {air}")
    exampleLabel:SetTextColor(0.6, 0.6, 0.6)

    -- Store refresh function for later use
    frame.RefreshCustomMacroList = RefreshCustomMacroList

    frame.sections = sections
    frame.tabContent = tabContent
    frame:Hide()

    SelectTab("layout")

    addon.UI.configWindow = frame
    return frame
end

local function RefreshConfigWindowState()
    local configWindow = addon.UI.configWindow
    if not configWindow then return end

    local popupDir = TotemBuddyDB.popupDirection or "UP"
    local popupDirValues = { "UP", "DOWN", "LEFT", "RIGHT" }
    for i, btn in ipairs(configWindow.popupDirButtons or {}) do
        btn:SetChecked(popupDirValues[i] == popupDir)
    end

    local timerPos = TotemBuddyDB.timerPosition or "ABOVE"
    local timerPosValues = { "ABOVE", "BELOW", "LEFT", "RIGHT" }
    for i, btn in ipairs(configWindow.timerPosButtons or {}) do
        btn:SetChecked(timerPosValues[i] == timerPos)
    end

    if configWindow.showTimersCheck then
        configWindow.showTimersCheck:SetChecked(TotemBuddyDB.showTimers)
    end
    if configWindow.lockPosCheck then
        configWindow.lockPosCheck:SetChecked(TotemBuddyDB.locked)
    end
    if configWindow.alwaysShowCheck then
        configWindow.alwaysShowCheck:SetChecked(TotemBuddyDB.alwaysShowPopup)
    end
    if configWindow.showReincCheck then
        configWindow.showReincCheck:SetChecked(TotemBuddyDB.showReincarnation)
    end
    if configWindow.showWeaponCheck then
        configWindow.showWeaponCheck:SetChecked(TotemBuddyDB.showWeaponBuffs)
    end
    if configWindow.disablePopupCombatCheck then
        if TotemBuddyDB.alwaysShowPopup then
            configWindow.disablePopupCombatCheck:SetChecked(false)
            configWindow.disablePopupCombatCheck:Disable()
            configWindow.disablePopupCombatCheck.label:SetTextColor(0.5, 0.5, 0.5)
        else
            configWindow.disablePopupCombatCheck:SetChecked(TotemBuddyDB.disablePopupInCombat)
            configWindow.disablePopupCombatCheck:Enable()
            configWindow.disablePopupCombatCheck.label:SetTextColor(1, 1, 1)
        end
    end
    if configWindow.scaleSlider then
        configWindow.scaleSlider:SetValue(TotemBuddyDB.barScale or 1.0)
    end
    if configWindow.showTooltipsCheck then
        configWindow.showTooltipsCheck:SetChecked(TotemBuddyDB.showTooltips ~= false)
    end
    if configWindow.showOOMOverlayCheck then
        configWindow.showOOMOverlayCheck:SetChecked(TotemBuddyDB.showLowManaOverlay ~= false)
    end
    if configWindow.timerFontSizeDropdown and configWindow.timerFontSizeDropdown.UpdateValue then
        configWindow.timerFontSizeDropdown.UpdateValue(TotemBuddyDB.timerFontSize or "NORMAL")
    end
    -- Sounds tab
    if configWindow.masterSoundCheck then
        configWindow.masterSoundCheck:SetChecked(TotemBuddyDB.totemExpirySound ~= false)
    end
    if configWindow.elementSoundDropdowns then
        for element, dropdown in pairs(configWindow.elementSoundDropdowns) do
            if dropdown.UpdateValue then
                local soundID = (TotemBuddyDB.totemExpirySoundIDs and TotemBuddyDB.totemExpirySoundIDs[element]) or 8959
                dropdown.UpdateValue(soundID)
            end
        end
    end
    if configWindow.UpdateSoundDropdownStates then
        configWindow.UpdateSoundDropdownStates()
    end
    -- Refresh default macro checkboxes
    if configWindow.defaultMacroCheckboxes then
        for name, check in pairs(configWindow.defaultMacroCheckboxes) do
            local enabled = true
            if TotemBuddyDB.defaultMacrosEnabled and TotemBuddyDB.defaultMacrosEnabled[name] ~= nil then
                enabled = TotemBuddyDB.defaultMacrosEnabled[name]
            end
            check:SetChecked(enabled)
        end
    end
end

function addon.ToggleConfigWindow()
    local frame = addon.CreateConfigWindow()

    if frame:IsShown() then
        frame:Hide()
    else
        RefreshConfigWindowState()
        for element, section in pairs(frame.sections) do
            PopulateConfigSection(section.scrollChild, element)
        end
        -- Refresh custom macro list
        if frame.RefreshCustomMacroList then
            frame.RefreshCustomMacroList()
        end
        frame:Show()
    end
end
