-- TotemBuddy: Sets tab (UI)
-- The "Sets" tab in the config window. Lets the player save the current four
-- active totems as a named set, then apply / rename / delete / reorder saved
-- sets. The set logic lives in Sets.lua; this file is presentation only.

local addonName, addon = ...

local ROW_HEIGHT = 26

-- Rename dialog (reused for every set; the target is passed via .data)
StaticPopupDialogs["TOTEMBUDDY_RENAME_SET"] = {
    text = "Rename totem set:",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 16,
    OnShow = function(self)
        self.editBox:SetText(self.data and self.data.name or "")
        self.editBox:HighlightText()
    end,
    OnAccept = function(self)
        local ok, err = addon.RenameSet(self.data.index, self.editBox:GetText())
        if not ok then
            print("|cFFFF0000TotemBuddy:|r " .. (err or "rename failed"))
        end
        if addon.RefreshSetsTab then addon.RefreshSetsTab() end
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Delete confirmation
StaticPopupDialogs["TOTEMBUDDY_DELETE_SET"] = {
    text = "Delete totem set '%s'?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        addon.DeleteSetByName(self.data.name)
        if addon.RefreshSetsTab then addon.RefreshSetsTab() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Small helper: a UIPanelButton anchored to the right of a row
local function RowButton(row, label, width, rightAnchor, gap)
    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btn:SetSize(width, 20)
    if rightAnchor then
        btn:SetPoint("RIGHT", rightAnchor, "LEFT", -(gap or 4), 0)
    else
        btn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    end
    btn:SetText(label)
    return btn
end

-- Rebuild the list rows from the saved sets
local function Refresh()
    local tab = addon.UI.setsTab
    if not tab then return end

    -- Tear down previous rows
    for _, row in ipairs(tab.rows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(tab.rows)

    local sets = addon.GetSets()

    if #sets == 0 then
        tab.emptyText:Show()
    else
        tab.emptyText:Hide()
    end

    for i, set in ipairs(sets) do
        local row = CreateFrame("Frame", nil, tab.list)
        row:SetSize(tab.list:GetWidth(), ROW_HEIGHT)
        row:SetPoint("TOPLEFT", tab.list, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)

        -- Buttons, anchored from the right edge inward
        local delBtn = RowButton(row, "Del", 44)
        delBtn:SetScript("OnClick", function()
            StaticPopup_Show("TOTEMBUDDY_DELETE_SET", set.name, nil, { name = set.name })
        end)

        local renBtn = RowButton(row, "Rename", 62, delBtn)
        renBtn:SetScript("OnClick", function()
            StaticPopup_Show("TOTEMBUDDY_RENAME_SET", nil, nil, { index = i, name = set.name })
        end)

        local applyBtn = RowButton(row, "Apply", 54, renBtn)
        applyBtn:SetScript("OnClick", function()
            addon.ApplySetByIndex(i)
            if InCombatLockdown() then
                print("|cFF00FF00TotemBuddy:|r Set '" .. set.name .. "' queued — applies when you leave combat")
            end
            Refresh()
        end)

        local downBtn = RowButton(row, "v", 22, applyBtn)
        downBtn:SetEnabled(i < #sets)
        downBtn:SetScript("OnClick", function()
            if addon.MoveSet(i, 1) then Refresh() end
        end)

        local upBtn = RowButton(row, "^", 22, downBtn)
        upBtn:SetEnabled(i > 1)
        upBtn:SetScript("OnClick", function()
            if addon.MoveSet(i, -1) then Refresh() end
        end)

        -- Name (green if this is the active set)
        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("LEFT", row, "LEFT", 4, 0)
        name:SetWidth(120)
        name:SetWordWrap(false)
        name:SetJustifyH("LEFT")
        name:SetText(set.name)
        if TotemBuddyDB.activeSet == i then
            name:SetTextColor(0, 1, 0)
        else
            name:SetTextColor(1, 1, 1)
        end

        -- Totem summary, clipped to the gap between name and the buttons
        local summary = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        summary:SetPoint("LEFT", name, "RIGHT", 6, 0)
        summary:SetPoint("RIGHT", upBtn, "LEFT", -6, 0)
        summary:SetWordWrap(false)
        summary:SetJustifyH("LEFT")
        summary:SetText(addon.DescribeSet(set))

        table.insert(tab.rows, row)
    end
end

-- Public refresh hook (called by Sets.lua command handlers and on tab show)
function addon.RefreshSetsTab()
    if addon.UI.setsTab then Refresh() end
end

-- Build the static chrome of the Sets tab into `parent` (the tab content frame)
function addon.BuildSetsTab(parent)
    -- Save-current row
    local saveLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    saveLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -6)
    saveLabel:SetText("Save current totems as:")

    local nameBox = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    nameBox:SetSize(140, 20)
    nameBox:SetPoint("LEFT", saveLabel, "RIGHT", 8, 0)
    nameBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    nameBox:SetBackdropColor(0.1, 0.1, 0.1, 1)
    nameBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    nameBox:SetFontObject("GameFontNormalSmall")
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(16)
    nameBox:SetTextInsets(4, 4, 0, 0)

    local saveBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    saveBtn:SetSize(60, 22)
    saveBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    saveBtn:SetText("Save")

    local function DoSave()
        local set, isNew = addon.SaveCurrentAsSet(nameBox:GetText())
        if set then
            print("|cFF00FF00TotemBuddy:|r " .. (isNew and "Saved" or "Updated")
                .. " set '" .. set.name .. "': " .. addon.DescribeSet(set))
            nameBox:SetText("")
            nameBox:ClearFocus()
            Refresh()
        end
    end
    saveBtn:SetScript("OnClick", DoSave)
    nameBox:SetScript("OnEnterPressed", DoSave)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Divider label / hint
    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", saveLabel, "BOTTOMLEFT", 0, -8)
    hint:SetText("Apply writes a set into your active totems and rebuilds the cast macro.")

    -- List container
    local list = CreateFrame("Frame", nil, parent)
    list:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
    list:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)

    local emptyText = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", list, "TOP", 0, -10)
    emptyText:SetText("No sets yet — set your totems, type a name above, and click Save.")
    emptyText:Hide()

    addon.UI.setsTab = { parent = parent, nameBox = nameBox, list = list, emptyText = emptyText, rows = {} }
    Refresh()
end
