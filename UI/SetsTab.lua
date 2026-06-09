-- TotemBuddy: Sets tab (UI)
-- The "Sets" tab in the config window. Lets the player save the current four
-- active totems as a named set, then apply / rename / delete / reorder / bind
-- a key to each saved set. Set logic lives in Sets.lua and Bindings.lua; this
-- file is presentation only. Mutations go through addon.* functions which call
-- addon.NotifySetsChanged(), which in turn calls back into addon.RefreshSetsTab.

local addonName, addon = ...

local ROW_HEIGHT = 40

-- Rename dialog (reused for every set; the target is passed as Show()'s 4th arg
-- so it is available to OnShow as self.data)
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
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- A UIPanelButton on a row's top line, anchored right-to-left
local function RowButton(row, label, width, rightAnchor, gap)
    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btn:SetSize(width, 20)
    if rightAnchor then
        btn:SetPoint("TOPRIGHT", rightAnchor, "TOPLEFT", -(gap or 4), 0)
    else
        btn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -1)
    end
    btn:SetText(label)
    return btn
end

-- Rebuild the list rows from the saved sets
local function Refresh()
    local tab = addon.UI.setsTab
    if not tab then return end

    for _, row in ipairs(tab.rows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(tab.rows)

    local sets = addon.GetSets()
    tab.emptyText:SetShown(#sets == 0)

    for i, set in ipairs(sets) do
        local row = CreateFrame("Frame", nil, tab.list)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", tab.list, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", tab.list, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)

        -- Action buttons (top line), anchored from the right edge inward
        local delBtn = RowButton(row, "Del", 40)
        delBtn:SetScript("OnClick", function()
            StaticPopup_Show("TOTEMBUDDY_DELETE_SET", set.name, nil, { name = set.name })
        end)

        local renBtn = RowButton(row, "Rename", 58, delBtn)
        renBtn:SetScript("OnClick", function()
            StaticPopup_Show("TOTEMBUDDY_RENAME_SET", nil, nil, { index = i, name = set.name })
        end)

        local applyBtn = RowButton(row, "Apply", 50, renBtn)
        applyBtn:SetScript("OnClick", function()
            addon.ApplySetByIndex(i)
            if InCombatLockdown() then
                print("|cFF00FF00TotemBuddy:|r Set '" .. set.name .. "' queued — applies when you leave combat")
            end
        end)

        local downBtn = RowButton(row, "v", 22, applyBtn)
        downBtn:SetEnabled(i < #sets)
        downBtn:SetScript("OnClick", function() addon.MoveSet(i, 1) end)

        local upBtn = RowButton(row, "^", 22, downBtn)
        upBtn:SetEnabled(i > 1)
        upBtn:SetScript("OnClick", function() addon.MoveSet(i, -1) end)

        -- Keybind button (shows current chord or "Bind")
        local keyBtn = RowButton(row, set.keybind or "Bind", 74, upBtn)
        keyBtn:SetScript("OnClick", function(self)
            self:SetText("press key…")
            addon.CaptureKeybind(self, function(chord)
                set.keybind = chord -- nil clears it
                addon.NotifySetsChanged()
            end)
        end)

        -- Name (green when this is the active set)
        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -3)
        name:SetWidth(140)
        name:SetWordWrap(false)
        name:SetJustifyH("LEFT")
        name:SetText(set.name)
        name:SetTextColor(TotemBuddyDB.activeSet == i and 0 or 1, 1, TotemBuddyDB.activeSet == i and 0 or 1)

        -- Totem summary (second line)
        local summary = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        summary:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
        summary:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        summary:SetWordWrap(false)
        summary:SetJustifyH("LEFT")
        summary:SetText(addon.DescribeSet(set))

        table.insert(tab.rows, row)
    end
end

-- Public refresh hook (called by addon.NotifySetsChanged and on tab build)
function addon.RefreshSetsTab()
    if addon.UI.setsTab then Refresh() end
end

-- Build the static chrome of the Sets tab into `parent` (the tab content frame)
function addon.BuildSetsTab(parent)
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
        local set = addon.SaveCurrentAsSet(nameBox:GetText())
        if set then
            nameBox:SetText("")
            nameBox:ClearFocus()
            -- the list is refreshed by NotifySetsChanged inside SaveCurrentAsSet
        end
    end
    saveBtn:SetScript("OnClick", DoSave)
    nameBox:SetScript("OnEnterPressed", DoSave)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", saveLabel, "BOTTOMLEFT", 0, -8)
    hint:SetText("Apply writes a set into your active totems. Bind a key to cast a set's sequence (one totem per press) — switch sets in combat by pressing a different bound key.")
    hint:SetWidth(520)
    hint:SetJustifyH("LEFT")

    local list = CreateFrame("Frame", nil, parent)
    list:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
    list:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)

    local emptyText = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", list, "TOP", 0, -10)
    emptyText:SetText("No sets yet — set your totems, type a name above, and click Save.")
    emptyText:Hide()

    addon.UI.setsTab = { parent = parent, nameBox = nameBox, list = list, emptyText = emptyText, rows = {} }
    Refresh()
end
