-- TotemBuddy: Shield Trackers
-- Earth Shield and Lightning Shield as assignable cast buttons that ALSO act as
-- live trackers: each button shows the charges and remaining duration of YOUR
-- active shield.
--
--   * Lightning Shield is self-only -> we read it straight off "player".
--   * Earth Shield is cast on a friendly (usually the tank) -> we scan your
--     target/focus/mouseover/group for an Earth Shield whose caster is you,
--     using the "PLAYER" aura filter so other shamans' shields never show up.
--
-- Each button is a SecureActionButton (one cast per click / bound key, ToS-clean).
-- Earth Shield uses a smart @mouseover>@target>@player cast; Lightning Shield
-- casts on the player. Charges + duration come from UnitBuff and drive a cooldown
-- swipe + count/time text, mirroring the Reincarnation tracker.
--
-- All secure work (attributes, keybinds) is forbidden in combat, so it is
-- deferred to PLAYER_REGEN_ENABLED via a pending flag, like the other modules.

local addonName, addon = ...

local BTN_SIZE = 40
local BTN_GAP = 4
local PAD = 6
local SCAN_THROTTLE = 0.25 -- seconds between Earth Shield group rescans
local NAME_H = 14           -- extra bar height below buttons for Earth Shield target name

local shieldOwner = CreateFrame("Frame", "TotemBuddyShieldOwner", UIParent)
local shieldButtons = {}   -- key -> button
local shieldBar
local pendingShields = false

-- Cached scan results: key -> { count, duration, expiration } or nil
local shieldState = {}
local lastEarthScan = 0

-- ---- Data helpers -------------------------------------------------------

local function GetShieldKeybinds()
    if not TotemBuddyDB.shieldKeybinds then TotemBuddyDB.shieldKeybinds = {} end
    return TotemBuddyDB.shieldKeybinds
end

local function IsShieldEnabled(key)
    if key == "earth" then return TotemBuddyDB.showEarthShield ~= false end
    if key == "lightning" then return TotemBuddyDB.showLightningShield ~= false end
    if key == "water" then return TotemBuddyDB.showWaterShield ~= false end
    return false
end

function addon.SetShieldKeybind(key, chord)
    GetShieldKeybinds()[key] = chord -- nil clears
    addon.RefreshShieldBar()
    if addon.RefreshShieldConfig then addon.RefreshShieldConfig() end
end

function addon.SetShieldShown(key, shown)
    if key == "earth" then
        TotemBuddyDB.showEarthShield = shown and true or false
    elseif key == "lightning" then
        TotemBuddyDB.showLightningShield = shown and true or false
    elseif key == "water" then
        TotemBuddyDB.showWaterShield = shown and true or false
    end
    addon.RefreshShieldBar()
    if addon.RefreshShieldConfig then addon.RefreshShieldConfig() end
end

function addon.SetEarthShieldTargetMode(mode)
    TotemBuddyDB.earthShieldTargetMode = mode
    addon.RefreshShieldBar()
end

-- Build the secure cast attribute string for the Earth Shield smart cast.
local function EarthMacroText(name)
    local mode = TotemBuddyDB.earthShieldTargetMode or "smart"
    if mode == "player" then
        return "/cast [@player] " .. name
    elseif mode == "target" then
        return "/cast [@target,help,nodead][@player] " .. name
    elseif mode == "mouseover" then
        return "/cast [@mouseover,help,nodead][@player] " .. name
    else -- smart
        return "/cast [@mouseover,help,nodead][@target,help,nodead][@player] " .. name
    end
end

-- ---- Aura scanning ------------------------------------------------------

-- Scan one unit for a shield buff cast by the player. Matches on the
-- (rank-independent) localized name so every rank is found. Returns
-- count, duration, expiration -- or nil if not present.
local function ScanUnit(unit, name)
    if not UnitExists(unit) then return nil end
    for i = 1, 40 do
        -- TBC Classic UnitBuff: name, rank, icon, count, debuffType, duration,
        -- expirationTime, source, ... , spellId. "PLAYER" filter = only mine.
        local n, _, _, count, _, duration, expiration = UnitBuff(unit, i, "PLAYER")
        if not n then break end
        if n == name then
            return count or 0, duration or 0, expiration or 0
        end
    end
    return nil
end

-- Find MY Lightning Shield (self only).
local function FindLightningShield(name)
    return ScanUnit("player", name)
end

-- Find MY Earth Shield across likely units. Returns count, duration, expiration,
-- and the unit token that has the shield (e.g. "focus", "raid3", "player").
local function FindEarthShield(name)
    local function tryUnit(unit)
        local c, d, e = ScanUnit(unit, name)
        if c then return c, d, e, unit end
    end
    local c, d, e, u
    for _, unit in ipairs({"focus", "target", "mouseover", "player"}) do
        c, d, e, u = tryUnit(unit)
        if c then return c, d, e, u end
    end
    if IsInRaid() then
        for i = 1, 40 do
            c, d, e, u = tryUnit("raid" .. i)
            if c then return c, d, e, u end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            c, d, e, u = tryUnit("party" .. i)
            if c then return c, d, e, u end
        end
    end
    return nil
end

-- Re-scan auras into the cache. Earth Shield's group scan is throttled; pass
-- force=true (e.g. right after you cast it, or a roster/target change) to bypass.
function addon.RescanShields(force)
    for _, def in ipairs(addon.SHIELDS) do
        if IsShieldEnabled(def.key) then
            local name = addon.GetTotemName(def.spellID)
            if name then
                if def.key == "earth" then
                    local now = GetTime()
                    if force or (now - lastEarthScan) >= SCAN_THROTTLE then
                        lastEarthScan = now
                        local c, d, e, u = FindEarthShield(name)
                        shieldState.earth = (c and c > 0) and { count = c, duration = d, expiration = e, targetUnit = u } or nil
                    end
                else
                    local c, d, e = FindLightningShield(name)
                    shieldState[def.key] = (c and c > 0) and { count = c, duration = d, expiration = e } or nil
                end
            end
        else
            shieldState[def.key] = nil
        end
    end
end

-- ---- Display ------------------------------------------------------------

-- Update one button's visuals from its cached state. Called every tick.
local function UpdateShieldButtonDisplay(def, btn)
    local st = shieldState[def.key]
    local now = GetTime()

    -- Earth Shield: show the target's name below the button, class-colored.
    if btn.nameLabel then
        if st and st.targetUnit and UnitExists(st.targetUnit) then
            local uname = UnitName(st.targetUnit) or ""
            local _, class = UnitClass(st.targetUnit)
            local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            btn.nameLabel:SetTextColor(cc and cc.r or 0.9, cc and cc.g or 0.9, cc and cc.b or 0.9)
            btn.nameLabel:SetText(uname)
        else
            btn.nameLabel:SetText("")
        end
    end

    -- Expired? drop the cache so it reads as missing.
    if st and st.expiration and st.expiration > 0 and (st.expiration - now) <= 0 then
        shieldState[def.key] = nil
        st = nil
    end

    if st then
        btn.icon:SetDesaturated(false)
        btn.icon:SetAlpha(1)
        btn.border:SetBackdropBorderColor(def.color.r, def.color.g, def.color.b, 1)

        -- Charges
        local warn = TotemBuddyDB.shieldLowChargeWarn or 0
        local low = warn > 0 and st.count and st.count <= warn and st.count > 0
        btn.countText:SetText((st.count and st.count > 0) and tostring(st.count) or "")
        if low then
            btn.countText:SetTextColor(1, 0.3, 0.3)
        else
            btn.countText:SetTextColor(1, 1, 1)
        end

        -- Duration swipe + time text
        if st.expiration and st.expiration > 0 and st.duration and st.duration > 0 then
            btn.cooldown:SetCooldown(st.expiration - st.duration, st.duration)
            local remaining = st.expiration - now
            btn.timeText:SetText(remaining > 0 and addon.FormatTime(math.floor(remaining + 0.5)) or "")
        else
            btn.cooldown:Clear()
            btn.timeText:SetText("")
        end
    else
        -- Missing: dim + red border, nudging you to (re)cast it.
        btn.icon:SetDesaturated(true)
        btn.icon:SetAlpha(0.5)
        btn.border:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
        btn.countText:SetText("")
        btn.timeText:SetText("")
        btn.cooldown:Clear()
    end
end

-- Public: re-scan (throttled) and refresh all shield buttons. Called from the
-- 0.1s ticker and from shield-related events.
function addon.UpdateShields(force)
    if not shieldBar or not shieldBar:IsShown() then return end
    addon.RescanShields(force)
    for _, def in ipairs(addon.SHIELDS) do
        local btn = shieldButtons[def.key]
        if btn and btn:IsShown() then
            UpdateShieldButtonDisplay(def, btn)
        end
    end
end

-- ---- The bar ------------------------------------------------------------

local function CreateBarFrame()
    if shieldBar then return shieldBar end

    local f = CreateFrame("Frame", "TotemBuddyShieldBar", UIParent, "BackdropTemplate")
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

    local pos = TotemBuddyDB.shieldsPos or { point = "CENTER", x = 0, y = -320 }
    f:SetPoint(pos.point or "CENTER", pos.x or 0, pos.y or -320)
    f:SetScale(TotemBuddyDB.shieldsScale or 1.0)

    -- Unlocked = plain left-drag to move (friendlier than ctrl-drag); locked =
    -- can't be nudged by a stray grab.
    f:SetScript("OnDragStart", function(self)
        if not TotemBuddyDB.shieldsLocked and not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        TotemBuddyDB.shieldsPos = { point = point, x = x, y = y }
    end)

    shieldBar = f
    return f
end

local function EnsureShieldButton(def)
    if shieldButtons[def.key] then return shieldButtons[def.key] end

    local btn = CreateFrame("Button", "TotemBuddyShield_" .. def.key, shieldBar, "SecureActionButtonTemplate")
    btn:SetSize(BTN_SIZE, BTN_SIZE)
    -- AnyDown only (cast on press, once) — see QuickBar for why AnyUp is dropped.
    btn:RegisterForClicks("AnyDown")
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if not TotemBuddyDB.shieldsLocked and not InCombatLockdown() then
            shieldBar:StartMoving()
        end
    end)
    btn:SetScript("OnDragStop", function(self)
        shieldBar:StopMovingOrSizing()
        local point, _, _, x, y = shieldBar:GetPoint()
        TotemBuddyDB.shieldsPos = { point = point, x = x, y = y }
    end)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon:SetTexture(addon.GetTotemIcon(def.spellID))

    btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.border:SetPoint("TOPLEFT", -1, 1)
    btn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    btn.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
    btn.border:SetBackdropBorderColor(def.color.r, def.color.g, def.color.b, 1)
    btn.border:EnableMouse(false)

    -- No CooldownFrameTemplate: the template adds a CooldownFrameCount child with mouse
    -- enabled, which intercepts clicks on the button even when the parent has EnableMouse(false).
    local cd = CreateFrame("Cooldown", nil, btn)
    cd:SetAllPoints(btn.icon)
    cd:SetDrawEdge(false)
    cd:SetHideCountdownNumbers(true)
    cd:EnableMouse(false)
    btn.cooldown = cd

    -- Text overlay above the cooldown swipe so it isn't dimmed
    local overlay = CreateFrame("Frame", nil, btn)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(btn:GetFrameLevel() + 10)

    btn.countText = overlay:CreateFontString(nil, "OVERLAY")
    btn.countText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    btn.countText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    btn.countText:SetTextColor(1, 1, 1)

    btn.timeText = overlay:CreateFontString(nil, "OVERLAY")
    btn.timeText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    btn.timeText:SetPoint("TOP", btn, "TOP", 0, -2)
    btn.timeText:SetTextColor(1, 1, 1)

    -- Earth Shield target name label (rendered below the button within the extended bar)
    if def.key == "earth" then
        btn.nameLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.nameLabel:SetPoint("TOP", btn, "BOTTOM", 0, -2)
        btn.nameLabel:SetWidth(BTN_SIZE + 16)
        btn.nameLabel:SetJustifyH("CENTER")
        btn.nameLabel:SetShadowOffset(1, -1)
        btn.nameLabel:SetShadowColor(0, 0, 0, 1)
    end

    btn:SetScript("OnEnter", function(self)
        self.border:SetBackdropBorderColor(1, 1, 1, 1)
        if TotemBuddyDB.showTooltips ~= false then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(def.spellID)
            GameTooltip:AddLine(" ")
            if def.key == "earth" then
                local st = shieldState[def.key]
                if st and st.targetUnit and UnitExists(st.targetUnit) then
                    GameTooltip:AddLine("On: " .. (UnitName(st.targetUnit) or "?"), 0.9, 0.9, 0.9)
                end
                GameTooltip:AddLine("Cast mode: " .. (TotemBuddyDB.earthShieldTargetMode or "smart"), 0.6, 0.8, 0.6)
            end
            local chord = GetShieldKeybinds()[def.key]
            GameTooltip:AddLine(chord and ("Bound: " .. chord) or "Right-click for keybind options", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        local st = shieldState[def.key]
        if st then
            self.border:SetBackdropBorderColor(def.color.r, def.color.g, def.color.b, 1)
        else
            self.border:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
        end
        GameTooltip:Hide()
    end)

    -- Right-click rebinds (left-click is the secure cast). Mirrors QuickBar.
    btn:HookScript("PostClick", function(self, clickButton)
        if clickButton == "RightButton" and not InCombatLockdown() then
            local name = addon.GetTotemName(def.spellID)
            local chord = GetShieldKeybinds()[def.key]
            addon.ShowKeybindMenu(self, name, chord,
                function()
                    addon.ShowKeybindCapture(self, name, function(newChord)
                        if newChord then
                            addon.WarnKeybindConflict(newChord, "Shield: " .. (name or def.key))
                        end
                        addon.SetShieldKeybind(def.key, newChord)
                    end)
                end,
                function()
                    addon.SetShieldKeybind(def.key, nil)
                end
            )
        end
    end)

    shieldButtons[def.key] = btn
    return btn
end

-- Rebuild the shield bar: secure attributes, layout, keybinds. Deferred in combat.
function addon.RefreshShieldBar()
    if not shieldBar then return end

    if InCombatLockdown() then
        pendingShields = true
        return
    end
    pendingShields = false

    ClearOverrideBindings(shieldOwner)
    shieldBar:SetScale(TotemBuddyDB.shieldsScale or 1.0)

    local keybinds = GetShieldKeybinds()
    local shown = 0
    for _, def in ipairs(addon.SHIELDS) do
        local btn = EnsureShieldButton(def)
        if IsShieldEnabled(def.key) then
            local name = addon.GetTotemName(def.spellID)
            -- Secure cast attributes (type1 keeps right-click free for binding)
            if def.target then
                btn:SetAttribute("type1", "macro")
                btn:SetAttribute("macrotext1", name and EarthMacroText(name) or "")
            else
                btn:SetAttribute("type1", "spell")
                btn:SetAttribute("spell1", name)
            end

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", shieldBar, "TOPLEFT", PAD + shown * (BTN_SIZE + BTN_GAP), -PAD)
            btn:Show()
            shown = shown + 1

            local chord = keybinds[def.key]
            if chord and chord ~= "" then
                SetOverrideBindingClick(shieldOwner, true, chord, btn:GetName(), "LeftButton")
            end
        else
            btn:Hide()
            shieldState[def.key] = nil
        end
    end

    if shown == 0 then
        shieldBar:Hide()
    else
        shieldBar:SetSize(PAD * 2 + shown * BTN_SIZE + (shown - 1) * BTN_GAP, BTN_SIZE + PAD * 2 + NAME_H)
        shieldBar:Show()
    end

    addon.UpdateShields(true)
end

-- Called from PLAYER_REGEN_ENABLED to flush work deferred during combat
function addon.ApplyPendingShields()
    if pendingShields then
        addon.RefreshShieldBar()
    end
end

-- Build the bar (once) and do the first refresh. Called on login.
function addon.CreateShieldBar()
    CreateBarFrame()
    addon.RefreshShieldBar()
end

-- ---- Config window ------------------------------------------------------

local function BuildShieldConfig()
    if addon.UI.shieldConfig then return addon.UI.shieldConfig end

    local frame = CreateFrame("Frame", "TotemBuddyShieldConfig", UIParent, "BackdropTemplate")
    frame:SetSize(340, 270)
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
    title:SetText("Shield Trackers")

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    tinsert(UISpecialFrames, "TotemBuddyShieldConfig")

    frame.rows = {}
    local y = -38
    for _, def in ipairs(addon.SHIELDS) do
        local row = CreateFrame("Frame", nil, frame)
        row:SetPoint("TOPLEFT", 12, y)
        row:SetPoint("TOPRIGHT", -12, y)
        row:SetHeight(26)

        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetPoint("LEFT", 0, 0)
        check:SetSize(22, 22)
        check:SetScript("OnClick", function(self) addon.SetShieldShown(def.key, self:GetChecked()) end)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", check, "RIGHT", 2, 0)
        icon:SetTexture(addon.GetTotemIcon(def.spellID))

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        label:SetWidth(120)
        label:SetJustifyH("LEFT")
        label:SetText(addon.GetTotemName(def.spellID) or def.key)

        local bindBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        bindBtn:SetSize(74, 20)
        bindBtn:SetPoint("RIGHT", row, "RIGHT", -24, 0)
        bindBtn:SetScript("OnClick", function(self)
            self:SetText("press key…")
            addon.CaptureKeybind(self, function(chord)
                if chord then
                    addon.WarnKeybindConflict(chord, "Shield: " .. (addon.GetTotemName(def.spellID) or def.key))
                end
                addon.SetShieldKeybind(def.key, chord)
            end)
        end)

        local clearBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        clearBtn:SetSize(20, 20)
        clearBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        clearBtn:SetText("x")
        clearBtn:SetScript("OnClick", function() addon.SetShieldKeybind(def.key, nil) end)

        row.check = check
        row.bindBtn = bindBtn
        row.key = def.key
        frame.rows[def.key] = row
        y = y - 30
    end

    -- Earth Shield target-mode buttons
    local tmLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tmLabel:SetPoint("TOPLEFT", 12, y - 4)
    tmLabel:SetText("Earth Shield cast on:")
    tmLabel:SetTextColor(1, 0.82, 0)

    local modes = { "smart", "mouseover", "target", "player" }
    local modeBtns = {}
    local prev
    for _, mode in ipairs(modes) do
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(70, 20)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else
            b:SetPoint("TOPLEFT", tmLabel, "BOTTOMLEFT", 0, -4)
        end
        b:SetText(mode)
        b:SetScript("OnClick", function()
            addon.SetEarthShieldTargetMode(mode)
            if addon.RefreshShieldConfig then addon.RefreshShieldConfig() end
        end)
        modeBtns[mode] = b
        prev = b
    end
    frame.modeBtns = modeBtns

    -- Lock + scale
    local lockCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    lockCheck:SetPoint("TOPLEFT", 12, y - 50)
    lockCheck:SetSize(22, 22)
    lockCheck:SetScript("OnClick", function(self)
        TotemBuddyDB.shieldsLocked = self:GetChecked()
    end)
    local lockLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lockLabel:SetPoint("LEFT", lockCheck, "RIGHT", 2, 0)
    lockLabel:SetText("Lock bar (uncheck, then drag the bar to move it)")
    frame.lockCheck = lockCheck

    addon.UI.shieldConfig = frame
    return frame
end

function addon.RefreshShieldConfig()
    local frame = addon.UI.shieldConfig
    if not frame then return end

    for _, def in ipairs(addon.SHIELDS) do
        local row = frame.rows[def.key]
        if row then
            row.check:SetChecked(IsShieldEnabled(def.key))
            row.bindBtn:SetText(GetShieldKeybinds()[def.key] or "Set key")
        end
    end

    local mode = TotemBuddyDB.earthShieldTargetMode or "smart"
    for m, b in pairs(frame.modeBtns) do
        if m == mode then
            b:LockHighlight()
        else
            b:UnlockHighlight()
        end
    end

    frame.lockCheck:SetChecked(TotemBuddyDB.shieldsLocked)
end

function addon.ToggleShieldConfig()
    local frame = BuildShieldConfig()
    if frame:IsShown() then
        frame:Hide()
    else
        addon.RefreshShieldConfig()
        frame:Show()
    end
end
