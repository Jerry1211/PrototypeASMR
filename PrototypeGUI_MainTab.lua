-- PrototypeGUI_MainTab.lua
-- Main tab (single mount management) + supports numeric SoundKit IDs AND custom name keys (e.g. Cat-Meow)

local addonName = ...
PrototypeGUI = PrototypeGUI or {}
local PG = PrototypeGUI

PG.UI = PG.UI or {}
local UI = PG.UI
local C  = PG.C

-- ======================================================
-- MAIN tab sound list
-- ======================================================
PG.SOUND_ROWS = 10
PG.ROW_H = 18
PG.soundRowButtons = PG.soundRowButtons or {}
PG.selectedSoundID = nil

local function GetSelectedMountFromUI()
    local useCurrent = UI.chkUseCurrent and UI.chkUseCurrent:GetChecked()
    local mountIDText = UI.ebMountID and UI.ebMountID:GetText() or ""
    return PG.ResolveTargetMount(mountIDText, useCurrent)
end

-- Accepts:
-- - number (SoundKit ID)
-- - string key (custom name like Cat-Meow)
local function GetSoundIDFromUI()
    local raw = UI.ebSoundID and UI.ebSoundID:GetText() or ""
    raw = PG.Trim(raw)

    if raw ~= "" then
        local sid = PG.ToNumberSafe(raw)
        if sid then return sid end
        return raw -- custom name key
    end

    if PG.selectedSoundID ~= nil then
        return PG.selectedSoundID
    end

    return nil
end

function PG.RefreshInfoTexts()
    if not (UI.infoPanel and UI.txtCurrent and UI.txtSelectedMount) then return end

    local mountID = GetSelectedMountFromUI()

    if PG.lastMountedMountID and PG.lastMountedMountID > 0 then
        local name = PG.GetMountName(PG.lastMountedMountID)
        local spellID = PG.GetMountSpellID(PG.lastMountedMountID)
        local s = ("Current (cached): %s | MountID %d | SpellID %s")
            :format(name, PG.lastMountedMountID, tostring(spellID))
        PG.SetBoundText(UI.txtCurrent, UI.infoPanel, 14, 14, s)
    else
        PG.SetBoundText(UI.txtCurrent, UI.infoPanel, 14, 14, "Current (cached): none (mount once to cache)")
    end

    if mountID then
        local s2 = ("Selected mount: %s (MountID %d)")
            :format(PG.GetMountName(mountID), mountID)
        PG.SetBoundText(UI.txtSelectedMount, UI.infoPanel, 14, 14, s2)
    else
        PG.SetBoundText(UI.txtSelectedMount, UI.infoPanel, 14, 14, "Selected mount: (none)")
    end
end

function PG.RefreshSoundList()
    if not UI.scrollFrame then return end

    PG.selectedSoundID = nil
    if UI.ebSoundID then UI.ebSoundID:SetText("") end

    local mountID = GetSelectedMountFromUI()
    local list = (mountID and PrototypeASMRDB.mounts[mountID]) or nil
    if type(list) ~= "table" then list = {} end

    -- display copy
    local display = {}
    for i = 1, #list do display[i] = list[i] end

    -- sort by tostring so numbers + strings behave consistently
    table.sort(display, function(a, b) return tostring(a) < tostring(b) end)
    UI._displaySounds = display

    FauxScrollFrame_Update(UI.scrollFrame, #display, PG.SOUND_ROWS, PG.ROW_H)
    local offset = FauxScrollFrame_GetOffset(UI.scrollFrame)

    for i = 1, PG.SOUND_ROWS do
        local idx = i + offset
        local btn = PG.soundRowButtons[i]
        local sid = display[idx]

        if sid ~= nil then
            btn:Show()
            btn.soundID = sid
            btn.txt:SetText(tostring(sid))
            btn.txt:SetTextColor(unpack(C.text))
            btn:SetBackdropBorderColor(unpack(C.borderDim))
        else
            btn:Hide()
            btn.soundID = nil
            btn.txt:SetText("")
        end
    end

    PG.RefreshInfoTexts()
end

-- Now allows selecting string rows too
function PG.SelectSoundRow(btn)
    if not btn or btn.soundID == nil then return end
    PG.selectedSoundID = btn.soundID

    for i = 1, #PG.soundRowButtons do
        local b = PG.soundRowButtons[i]
        if b.soundID == PG.selectedSoundID then
            b:SetBackdropBorderColor(unpack(C.accent))
            b.txt:SetTextColor(unpack(C.accent))
        else
            b:SetBackdropBorderColor(unpack(C.borderDim))
            b.txt:SetTextColor(unpack(C.text))
        end
    end

    if UI.ebSoundID then
        UI.ebSoundID:SetText(tostring(PG.selectedSoundID))
        UI.ebSoundID:ClearFocus()
        UI.ebSoundID:SetCursorPosition(0)
    end
end

-- Expose helpers used by other modules
PG.Main_GetSelectedMount = GetSelectedMountFromUI
PG.Main_GetSoundID = GetSoundIDFromUI

-- ======================================================
-- Confirm popups
-- ======================================================
StaticPopupDialogs["PROTOTYPEASMR_GUI_CLEAR_ALL"] = {
    text = "Clear ALL sounds for this mount?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        if UI._pendingClearMountID then
            PG.ClearSounds(UI._pendingClearMountID)
            UI._pendingClearMountID = nil
            PG.RefreshSoundList()
            if PG.RefreshMountListTab then PG.RefreshMountListTab() end
        end
    end,
    OnCancel = function() UI._pendingClearMountID = nil end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["PROTOTYPEASMR_GUI_REMOVE_SOUND"] = {
    text = "Remove this sound from the selected mount?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        if UI._pendingRemoveMountID and UI._pendingRemoveSoundID ~= nil then
            PG.RemoveSound(UI._pendingRemoveMountID, UI._pendingRemoveSoundID)
            UI._pendingRemoveMountID = nil
            UI._pendingRemoveSoundID = nil
            PG.RefreshSoundList()
            if PG.RefreshMountListTab then PG.RefreshMountListTab() end
        end
    end,
    OnCancel = function()
        UI._pendingRemoveMountID = nil
        UI._pendingRemoveSoundID = nil
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ======================================================
-- Builder
-- ======================================================
function PG.BuildMainTab(frame)
    PG.EnsureDB()

    -- Info panel
    local info = PG.CreatePanel(frame, frame:GetWidth() - 24, 94, C.bgLight, C.borderDim)
    info:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -70)
    info:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.6)
    UI.infoPanel = info

    UI.chkEnabled = PG.CreateCheck(info, "Enabled", function(self)
        PrototypeASMRDB.enabled = self:GetChecked() and true or false
    end)
    UI.chkEnabled:SetPoint("TOPLEFT", info, "TOPLEFT", 10, -10)
    UI.chkEnabled:SetChecked(PrototypeASMRDB.enabled and true or false)

    UI.txtCurrent = PG.CreateSmallLabel(info, "")
    UI.txtCurrent:SetPoint("TOPLEFT", info, "TOPLEFT", 10, -32)

    UI.txtSelectedMount = PG.CreateSmallLabel(info, "")
    UI.txtSelectedMount:SetPoint("TOPLEFT", info, "TOPLEFT", 10, -52)

    -- Mount panel
    local mountP = PG.CreatePanel(frame, 270, 120, C.bgLight, C.borderDim)
    mountP:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -12)
    mountP:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.45)
    UI.mountPanel = mountP

    local mTitle = PG.CreateLabel(mountP, "Mount target", 12, C.text)
    mTitle:SetPoint("TOPLEFT", mountP, "TOPLEFT", 10, -10)

    UI.chkUseCurrent = PG.CreateCheck(mountP, "Use current", function(self)
        PG.EnsureDB()
        PrototypeASMRDB.gui.mainUseCurrent = self:GetChecked() and true or false
        PG.RefreshSoundList()
        PG.RefreshInfoTexts()
    end)
    UI.chkUseCurrent:SetPoint("TOPLEFT", mountP, "TOPLEFT", 10, -32)

    UI.ebMountID = PG.CreateEditBox(mountP, 110, 22, "MountID")
    UI.ebMountID:SetPoint("TOPLEFT", mountP, "TOPLEFT", 130, -30)
    UI.ebMountID:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        PG.EnsureDB()
        PrototypeASMRDB.gui.mainMountIDText = self:GetText() or ""
        PG.RefreshSoundList()
        PG.RefreshInfoTexts()
    end)

    UI.btnGetID = PG.CreateButton(mountP, "GetID (mounted)", 140, 22)
    UI.btnGetID:SetPoint("TOPLEFT", mountP, "TOPLEFT", 10, -64)
    UI.btnGetID:SetScript("OnClick", function()
        if PG.lastMountedMountID and PG.lastMountedMountID > 0 then
            UI.ebMountID:SetText(tostring(PG.lastMountedMountID))
            UI.ebMountID:SetCursorPosition(0)
            UI.chkUseCurrent:SetChecked(false)

            PG.EnsureDB()
            PrototypeASMRDB.gui.mainUseCurrent = false
            PrototypeASMRDB.gui.mainMountIDText = tostring(PG.lastMountedMountID)

            PG.RefreshSoundList()
        else
            PG.Print("No current mount cached yet. Mount once to cache.")
        end
        PG.RefreshInfoTexts()
    end)

    -- Sound panel (same height as mount panel)
    local soundP = PG.CreatePanel(frame, frame:GetWidth() - 24 - mountP:GetWidth() - 10, 120, C.bgLight, C.borderDim)
    soundP:SetPoint("TOPLEFT", mountP, "TOPRIGHT", 10, 0)
    soundP:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.45)
    UI.soundPanel = soundP

    local sTitle = PG.CreateLabel(soundP, "Sound Entry", 12, C.text)
    sTitle:SetPoint("TOPLEFT", soundP, "TOPLEFT", 10, -10)

    UI.ebSoundID = PG.CreateEditBox(soundP, 240, 22, "SoundID or Custom Name (e.g. 270277 or Cat-Meow)")
    UI.ebSoundID:SetPoint("TOPLEFT", soundP, "TOPLEFT", 10, -32)
    UI.ebSoundID:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    UI.btnPlaySound = PG.CreateButton(soundP, "Play Sound", 120, 22)
    UI.btnPlaySound:SetPoint("TOPLEFT", UI.ebSoundID, "BOTTOMLEFT", 0, -10)
    UI.btnPlaySound:SetScript("OnClick", function()
        local entry = GetSoundIDFromUI()
        if entry == nil or entry == "" then PG.Print("Invalid entry.") return end
        PG.PlayEntry(entry)
    end)

    -- List panel
    local listP = PG.CreatePanel(frame, frame:GetWidth() - 24, 170, C.bgLight, C.borderDim)
    listP:SetPoint("TOPLEFT", mountP, "BOTTOMLEFT", 0, -12)
    listP:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.35)
    UI.listPanel = listP

    local listTitle = PG.CreateLabel(listP, "Sounds on selected mount (click to select)", 12, C.text)
    listTitle:SetPoint("TOPLEFT", listP, "TOPLEFT", 10, -10)

    -- Left list box
    local listBox = CreateFrame("Frame", nil, listP, "BackdropTemplate")
    listBox:SetPoint("TOPLEFT", listP, "TOPLEFT", 10, -32)
    listBox:SetPoint("BOTTOMLEFT", listP, "BOTTOMLEFT", 10, 10)
    listBox:SetWidth(300)
    PG.CreateBackdrop(listBox, C.bgDark, C.borderDim)
    PG.SafeClip(listBox, true)
    UI.listBox = listBox

    local scrollFrame = CreateFrame("ScrollFrame", "PrototypeASMR_SoundScroll", listBox, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listBox, "TOPLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", listBox, "BOTTOMRIGHT", -26, 2)
    UI.scrollFrame = scrollFrame

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, PG.ROW_H, PG.RefreshSoundList)
    end)

    for i = 1, PG.SOUND_ROWS do
        local row = CreateFrame("Button", nil, listBox, "BackdropTemplate")
        row:SetSize(260, PG.ROW_H)
        row:SetPoint("TOPLEFT", listBox, "TOPLEFT", 10, -10 - (i - 1) * PG.ROW_H)
        PG.CreateBackdrop(row, {0, 0, 0, 0}, C.borderDim)

        row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.txt:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.txt:SetTextColor(unpack(C.text))
        row.txt:SetText("")

        row:SetScript("OnEnter", function(self)
            if self.soundID == PG.selectedSoundID then return end
            self:SetBackdropBorderColor(unpack(C.accent))
        end)
        row:SetScript("OnLeave", function(self)
            if self.soundID == PG.selectedSoundID then return end
            self:SetBackdropBorderColor(unpack(C.borderDim))
        end)

        row:SetScript("OnClick", function(self) PG.SelectSoundRow(self) end)

        PG.soundRowButtons[i] = row
    end

    -- RIGHT SIDE actions panel inside list panel
    local actions = PG.CreatePanel(listP, listP:GetWidth() - 320, 128, C.bgDark, C.borderDim)
    actions:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 12, 0)
    actions:SetPoint("BOTTOMRIGHT", listP, "BOTTOMRIGHT", -10, 10)
    actions:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 0.35)
    UI.actionsPanel = actions

    UI.btnAdd = PG.CreateButton(actions, "Add", 90, 22, "green")
    UI.btnAdd:SetPoint("TOPLEFT", actions, "TOPLEFT", 10, -10)
    UI.btnAdd:SetScript("OnClick", function()
        local mountID = GetSelectedMountFromUI()
        if not mountID then PG.Print("Select a mount first.") return end

        local raw = UI.ebSoundID and UI.ebSoundID:GetText() or ""
        raw = PG.Trim(raw)
        if raw == "" then PG.Print("Invalid entry.") return end

        PG.AddSoundsFromInput(mountID, raw)
        PG.RefreshSoundList()
        if PG.RefreshMountListTab then PG.RefreshMountListTab() end
    end)

    UI.btnRemove = PG.CreateButton(actions, "Remove", 80, 24, "danger")
    UI.btnRemove:SetPoint("LEFT", UI.btnAdd, "RIGHT", 10, 0)
    UI.btnRemove:SetScript("OnClick", function()
        local mountID = GetSelectedMountFromUI()
        if not mountID then
            PG.Print("Select a mount first.")
            return
        end

        local entry = GetSoundIDFromUI()
        if entry == nil or entry == "" then
            PG.Print("Invalid entry.")
            return
        end

        UI._pendingRemoveMountID = mountID
        UI._pendingRemoveSoundID = entry
        StaticPopup_Show("PROTOTYPEASMR_GUI_REMOVE_SOUND")
    end)

    UI.btnClearAll = PG.CreateButton(actions, "Clear All", 84, 24, "danger")
    UI.btnClearAll:SetPoint("TOPLEFT", UI.btnAdd, "BOTTOMLEFT", 0, -10)
    UI.btnClearAll:SetScript("OnClick", function()
        local mountID = GetSelectedMountFromUI()
        if not mountID then PG.Print("Select a mount first.") return end
        UI._pendingClearMountID = mountID
        StaticPopup_Show("PROTOTYPEASMR_GUI_CLEAR_ALL")
    end)

    UI.btnPlayRandom = PG.CreateButton(actions, "Play Random Sound", 190, 22)
    UI.btnPlayRandom:SetPoint("TOPLEFT", UI.btnClearAll, "BOTTOMLEFT", 0, -10)
    UI.btnPlayRandom:SetScript("OnClick", function()
        local mountID = GetSelectedMountFromUI()
        if not mountID then PG.Print("Select a mount first.") return end
        PG.PlayRandomForMount(mountID)
    end)

    -- Track main panels for tab switching
    UI.mainPanels = { info, mountP, soundP, listP }

    return UI.mainPanels
end
