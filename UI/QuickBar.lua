-- TotemBuddy: Quick-React Bar
-- A small, movable bar of *secure* one-totem cast buttons for the reactive
-- utility totems a resto shaman drops on demand (Grounding, Tremor, Poison/
-- Disease Cleansing, Earthbind, ...). Each button is a SecureActionButton with
-- a "/cast <totem>" macrotext, so a click or a bound key drops exactly one
-- totem per press -- ToS-clean, no automation of the decision.
--
-- The bar is configured from its own small window (/tb quick config). All
-- secure work (macrotext, keybinds) is deferred out of combat, mirroring the
-- set-binding module.

local addonName, addon = ...

local BTN_SIZE = 36
local BTN_GAP = 4
local PAD = 6

local quickOwner = CreateFrame("Frame", "TotemBuddyQuickOwner", UIParent)
local quickButtons = {}
local quickBar
local pendingQuick = false

-- ---- Data helpers -------------------------------------------------------

local function GetList()
    if not TotemBuddyDB.quickReact then TotemBuddyDB.quickReact = {} end
    return TotemBuddyDB.quickReact
end

local function GetKeybinds()
    if not TotemBuddyDB.quickReactKeybinds then TotemBuddyDB.quickReactKeybinds = {} end
    return TotemBuddyDB.quickReactKeybinds
end

-- Resolve a user string (totem name or numeric spell ID) to a known totem
-- spell ID, searching the addon's TOTEMS table. Returns spellID or nil.
function addon.FindTotemSpellID(input)
    if not input then return nil end
    input = tostring(input):trim()
    if input == "" then return nil end

    local asNumber = tonumber(input)
    local lower = input:lower()
    for _, list in pairs(addon.TOTEMS) do
        for _, t in ipairs(list) do
            if asNumber and t.spellID == asNumber then
                return t.spellID
            end
            local name = addon.GetTotemName(t.spellID)
            if name and name:lower() == lower then
                return t.spellID
            end
        end
    end
    return nil
end

local function ListContains(spellID)
    for _, id in ipairs(GetList()) do
        if id == spellID then return true end
    end
    return false
end

-- Add a totem to the bar by name or spell ID. Returns spellID, or nil + reason.
function addon.AddQuickTotem(input)
    local spellID = addon.FindTotemSpellID(input)
    if not spellID then return nil, "unknown totem '" .. tostring(input) .. "'" end
    if ListContains(spellID) then return nil, "already on the bar" end
    table.insert(GetList(), spellID)
    addon.NotifyQuickChanged()
    return spellID
end

-- Remove a totem from the bar by spell ID.
function addon.RemoveQuickTotem(spellID)
    local list = GetList()
    for i, id in ipairs(list) do
        if id == spellID then
            table.remove(list, i)
            GetKeybinds()[spellID] = nil
            addon.NotifyQuickChanged()
            return true
        end
    end
    return false
end

function addon.SetQuickKeybind(spellID, chord)
    GetKeybinds()[spellID] = chord -- nil clears
    addon.NotifyQuickChanged()
end

function addon.SetQuickBarShown(shown)
    TotemBuddyDB.quickReactEnabled = shown and true or false
    addon.RefreshQuickBar()
end

function addon.ToggleQuickBar()
    addon.SetQuickBarShown(not TotemBuddyDB.quickReactEnabled)
    return TotemBuddyDB.quickReactEnabled
end

-- ---- The bar ------------------------------------------------------------

local function CreateBarFrame()
    if quickBar then return quickBar end

    local f = CreateFrame("Frame", "TotemBuddyQuickBar", UIParent, "BackdropTemplate")
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

    local pos = TotemBuddyDB.quickReactPos or { point = "CENTER", x = 0, y = -260 }
    f:SetPoint(pos.point or "CENTER", pos.x or 0, pos.y or -260)

    f:SetScript("OnDragStart", function(self)
        if not TotemBuddyDB.locked and IsControlKeyDown() and not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        TotemBuddyDB.quickReactPos = { point = point, x = x, y = y }
    end)

    quickBar = f
    return f
end

local function EnsureQuickButton(i)
    if quickButtons[i] then return quickButtons[i] end
    local btn = CreateFrame("Button", "TotemBuddyQuickButton" .. i, quickBar, "SecureActionButtonTemplate")
    btn:SetSize(BTN_SIZE, BTN_SIZE)
    btn:SetAttribute("type", "spell")
    btn:RegisterForClicks("AnyDown", "AnyUp")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    btn:SetScript("OnEnter", function(self)
        if self.spellID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    quickButtons[i] = btn
    return btn
end

-- Rebuild the bar's buttons + keybindings from the DB. Deferred out of combat.
function addon.RefreshQuickBar()
    if not quickBar then return end

    if InCombatLockdown() then
        pendingQuick = true
        return
    end
    pendingQuick = false

    -- Hidden entirely?
    if not TotemBuddyDB.quickReactEnabled then
        quickBar:Hide()
        ClearOverrideBindings(quickOwner)
        return
    end

    local list = GetList()
    local keybinds = GetKeybinds()
    ClearOverrideBindings(quickOwner)

    for i, spellID in ipairs(list) do
        local btn = EnsureQuickButton(i)
        btn.spellID = spellID
        local name = addon.GetTotemName(spellID)
        btn:SetAttribute("spell", name)
        local icon = addon.GetTotemIcon(spellID)
        if icon then btn.icon:SetTexture(icon) end
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", quickBar, "LEFT", PAD + (i - 1) * (BTN_SIZE + BTN_GAP), 0)
        btn:Show()

        local chord = keybinds[spellID]
        if chord and chord ~= "" then
            SetOverrideBindingClick(quickOwner, true, chord, btn:GetName(), "LeftButton")
        end
    end

    -- Hide any leftover buttons from a previously longer list
    for i = #list + 1, #quickButtons do
        quickButtons[i]:Hide()
        quickButtons[i].spellID = nil
    end

    local n = #list
    if n == 0 then
        quickBar:Hide()
    else
        quickBar:SetSize(PAD * 2 + n * BTN_SIZE + (n - 1) * BTN_GAP, BTN_SIZE + PAD * 2)
        quickBar:Show()
    end
end

-- Called from PLAYER_REGEN_ENABLED to flush deferred work
function addon.ApplyPendingQuick()
    if pendingQuick then
        addon.RefreshQuickBar()
    end
end

-- Build the bar (once) and do the first refresh. Called on login.
function addon.CreateQuickBar()
    CreateBarFrame()
    addon.RefreshQuickBar()
end

-- ---- Sets/quick change hook --------------------------------------------

function addon.NotifyQuickChanged()
    addon.RefreshQuickBar()
    if addon.RefreshQuickConfig then addon.RefreshQuickConfig() end
end

-- ---- Config window ------------------------------------------------------

local function BuildConfigWindow()
    if addon.UI.quickConfig then return addon.UI.quickConfig end

    local frame = CreateFrame("Frame", "TotemBuddyQuickConfig", UIParent, "BackdropTemplate")
    frame:SetSize(360, 320)
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
    title:SetText("Quick-React Bar")

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    tinsert(UISpecialFrames, "TotemBuddyQuickConfig")

    -- Show-bar checkbox
    local showCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    showCheck:SetPoint("TOPLEFT", 12, -36)
    showCheck:SetSize(22, 22)
    showCheck:SetScript("OnClick", function(self)
        addon.SetQuickBarShown(self:GetChecked())
    end)
    local showLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showLabel:SetPoint("LEFT", showCheck, "RIGHT", 2, 0)
    showLabel:SetText("Show quick-react bar  (Ctrl+drag the bar to move it)")
    frame.showCheck = showCheck

    -- List container
    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", 12, -66)
    list:SetPoint("BOTTOMRIGHT", -12, 52)
    frame.list = list
    frame.rows = {}

    -- Add row at the bottom
    local addLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLabel:SetPoint("BOTTOMLEFT", 12, 20)
    addLabel:SetText("Add totem:")

    local addBox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    addBox:SetSize(160, 20)
    addBox:SetPoint("LEFT", addLabel, "RIGHT", 6, 0)
    addBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    addBox:SetBackdropColor(0.1, 0.1, 0.1, 1)
    addBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    addBox:SetFontObject("GameFontNormalSmall")
    addBox:SetAutoFocus(false)
    addBox:SetTextInsets(4, 4, 0, 0)

    local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addBtn:SetSize(50, 22)
    addBtn:SetPoint("LEFT", addBox, "RIGHT", 6, 0)
    addBtn:SetText("Add")
    local function DoAdd()
        local _, err = addon.AddQuickTotem(addBox:GetText())
        if err then
            print("|cFFFF0000TotemBuddy:|r " .. err)
        else
            addBox:SetText("")
            addBox:ClearFocus()
        end
    end
    addBtn:SetScript("OnClick", DoAdd)
    addBox:SetScript("OnEnterPressed", DoAdd)
    addBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    addon.UI.quickConfig = frame
    return frame
end

-- Rebuild the config window's totem rows
function addon.RefreshQuickConfig()
    local frame = addon.UI.quickConfig
    if not frame then return end

    frame.showCheck:SetChecked(TotemBuddyDB.quickReactEnabled)

    for _, row in ipairs(frame.rows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(frame.rows)

    local keybinds = GetKeybinds()
    for i, spellID in ipairs(GetList()) do
        local row = CreateFrame("Frame", nil, frame.list)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", frame.list, "TOPLEFT", 0, -(i - 1) * 26)
        row:SetPoint("TOPRIGHT", frame.list, "TOPRIGHT", 0, -(i - 1) * 26)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        local tex = addon.GetTotemIcon(spellID)
        if tex then icon:SetTexture(tex) end

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        name:SetWidth(150)
        name:SetWordWrap(false)
        name:SetJustifyH("LEFT")
        name:SetText(addon.GetTotemName(spellID) or ("Spell " .. spellID))

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(60, 20)
        removeBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        removeBtn:SetText("Remove")
        removeBtn:SetScript("OnClick", function() addon.RemoveQuickTotem(spellID) end)

        local bindBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        bindBtn:SetSize(74, 20)
        bindBtn:SetPoint("RIGHT", removeBtn, "LEFT", -4, 0)
        bindBtn:SetText(keybinds[spellID] or "Bind")
        bindBtn:SetScript("OnClick", function(self)
            self:SetText("press key…")
            addon.CaptureKeybind(self, function(chord)
                addon.SetQuickKeybind(spellID, chord)
            end)
        end)

        table.insert(frame.rows, row)
    end
end

function addon.ToggleQuickConfig()
    local frame = BuildConfigWindow()
    if frame:IsShown() then
        frame:Hide()
    else
        addon.RefreshQuickConfig()
        frame:Show()
    end
end
