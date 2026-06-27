-- TotemBuddy: Dispel Bar
-- Two secure cast buttons -- Cure Disease and Cure Poison -- with a smart
-- friendly-target cast (@mouseover -> @target -> @player) so you can cleanse the
-- person under your cursor WITHOUT dropping your current target. Click or bound
-- key = one cast per press (ToS-clean). Secure work is deferred out of combat.

local addonName, addon = ...

local BTN_SIZE = 36
local BTN_GAP = 4
local PAD = 6

local dispelOwner = CreateFrame("Frame", "TotemBuddyDispelOwner", UIParent)
local dispelButtons = {}
local dispelBar
local pendingDispel = false

local function GetDispelKeybinds()
    if not TotemBuddyDB.dispelKeybinds then TotemBuddyDB.dispelKeybinds = {} end
    return TotemBuddyDB.dispelKeybinds
end

function addon.SetDispelKeybind(key, chord)
    GetDispelKeybinds()[key] = chord
    addon.RefreshDispelBar()
end

function addon.SetDispelShown(shown)
    TotemBuddyDB.showDispelBar = shown and true or false
    addon.RefreshDispelBar()
end

function addon.ToggleDispelBar()
    addon.SetDispelShown(not TotemBuddyDB.showDispelBar)
    return TotemBuddyDB.showDispelBar
end

function addon.SetDispelTargetMode(mode)
    TotemBuddyDB.dispelTargetMode = mode
    addon.RefreshDispelBar()
end

local function DispelMacroText(name)
    local mode = TotemBuddyDB.dispelTargetMode or "smart"
    if mode == "player" then
        return "/cast [@player] " .. name
    elseif mode == "target" then
        return "/cast [@target,help,nodead][@player] " .. name
    elseif mode == "mouseover" then
        return "/cast [@mouseover,help,nodead][@player] " .. name
    else
        return "/cast [@mouseover,help,nodead][@target,help,nodead][@player] " .. name
    end
end

local function CreateBarFrame()
    if dispelBar then return dispelBar end
    local f = CreateFrame("Frame", "TotemBuddyDispelBar", UIParent, "BackdropTemplate")
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

    local pos = TotemBuddyDB.dispelPos or { point = "CENTER", x = 0, y = -420 }
    f:SetPoint(pos.point or "CENTER", pos.x or 0, pos.y or -420)
    f:SetScale(TotemBuddyDB.dispelScale or 1.0)

    f:SetScript("OnDragStart", function(self)
        if not TotemBuddyDB.dispelLocked and not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        TotemBuddyDB.dispelPos = { point = point, x = x, y = y }
    end)

    dispelBar = f
    return f
end

local function EnsureDispelButton(def)
    if dispelButtons[def.key] then return dispelButtons[def.key] end
    local btn = CreateFrame("Button", "TotemBuddyDispel_" .. def.key, dispelBar, "SecureActionButtonTemplate")
    btn:SetSize(BTN_SIZE, BTN_SIZE)
    btn:RegisterForClicks("AnyDown")
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if not TotemBuddyDB.dispelLocked and not InCombatLockdown() then
            dispelBar:StartMoving()
        end
    end)
    btn:SetScript("OnDragStop", function(self)
        dispelBar:StopMovingOrSizing()
        local point, _, _, x, y = dispelBar:GetPoint()
        TotemBuddyDB.dispelPos = { point = point, x = x, y = y }
    end)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon:SetTexture(GetSpellTexture(def.spellID))

    btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.border:SetPoint("TOPLEFT", -1, 1)
    btn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    btn.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
    btn.border:SetBackdropBorderColor(def.color.r, def.color.g, def.color.b, 1)
    btn.border:EnableMouse(false)

    btn:SetScript("OnEnter", function(self)
        self.border:SetBackdropBorderColor(1, 1, 1, 1)
        if TotemBuddyDB.showTooltips ~= false then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(def.spellID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Cast on: " .. (TotemBuddyDB.dispelTargetMode or "smart"), 0.6, 0.8, 0.6)
            local chord = GetDispelKeybinds()[def.key]
            GameTooltip:AddLine(chord and ("Bound: " .. chord) or "Right-click for keybind options", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self.border:SetBackdropBorderColor(def.color.r, def.color.g, def.color.b, 1)
        GameTooltip:Hide()
    end)

    btn:HookScript("PostClick", function(self, clickButton)
        if clickButton == "RightButton" and not InCombatLockdown() then
            local name = addon.GetTotemName(def.spellID)
            local chord = GetDispelKeybinds()[def.key]
            addon.ShowKeybindMenu(self, name, chord,
                function()
                    addon.ShowKeybindCapture(self, name, function(newChord)
                        if newChord and addon.WarnKeybindConflict then
                            addon.WarnKeybindConflict(newChord, "Dispel: " .. (name or def.key))
                        end
                        addon.SetDispelKeybind(def.key, newChord)
                    end)
                end,
                function()
                    addon.SetDispelKeybind(def.key, nil)
                end
            )
        end
    end)

    dispelButtons[def.key] = btn
    return btn
end

function addon.RefreshDispelBar()
    if not dispelBar then return end
    if InCombatLockdown() then
        pendingDispel = true
        return
    end
    pendingDispel = false

    ClearOverrideBindings(dispelOwner)
    dispelBar:SetScale(TotemBuddyDB.dispelScale or 1.0)

    if not TotemBuddyDB.showDispelBar then
        dispelBar:Hide()
        return
    end

    local keybinds = GetDispelKeybinds()
    local shown = 0
    for _, def in ipairs(addon.DISPELS) do
        local btn = EnsureDispelButton(def)
        local name = addon.GetTotemName(def.spellID)
        -- Only show a dispel the player has actually trained.
        if name and addon.IsTotemKnown(def.spellID) then
            btn:SetAttribute("type1", "macro")
            btn:SetAttribute("macrotext1", DispelMacroText(name))
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", dispelBar, "LEFT", PAD + shown * (BTN_SIZE + BTN_GAP), 0)
            btn:Show()
            shown = shown + 1
            local chord = keybinds[def.key]
            if chord and chord ~= "" then
                SetOverrideBindingClick(dispelOwner, true, chord, btn:GetName(), "LeftButton")
            end
        else
            btn:Hide()
        end
    end

    if shown == 0 then
        dispelBar:Hide()
    else
        dispelBar:SetSize(PAD * 2 + shown * BTN_SIZE + (shown - 1) * BTN_GAP, BTN_SIZE + PAD * 2)
        dispelBar:Show()
    end
end

function addon.ApplyPendingDispel()
    if pendingDispel then addon.RefreshDispelBar() end
end

function addon.CreateDispelBar()
    CreateBarFrame()
    addon.RefreshDispelBar()
end
