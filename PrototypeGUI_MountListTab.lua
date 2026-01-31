-- PrototypeGUI_MountListTab.lua
-- Mount List tab (all configured mounts -> sounds)

local addonName = ...
PrototypeGUI = PrototypeGUI or {}
local PG = PrototypeGUI

local UI = PG.UI
local C  = PG.C

PG.ML_MOUNT_ROWS = 14
PG.ML_SOUND_ROWS = 14
PG.ML_ROW_H = 18

PG.mlMountButtons = PG.mlMountButtons or {}
PG.mlSoundButtons = PG.mlSoundButtons or {}

PG.mlSelectedMountID = PG.mlSelectedMountID or nil
PG.mlSelectedSoundID = PG.mlSelectedSoundID or nil

-- double-click tracking
PG.mlLastClickTime = PG.mlLastClickTime or 0
PG.mlLastClickMountID = PG.mlLastClickMountID or nil
PG.ML_DBLCLICK_WINDOW = 0.35

local function GetMLFilter()
    PG.EnsureDB()
    local raw = ""
    if UI.mlFilterEB and UI.mlFilterEB.GetText then
        raw = UI.mlFilterEB:GetText() or ""
    else
        raw = (PrototypeASMRDB.gui and PrototypeASMRDB.gui.mlFilter) or ""
    end
    return PG.Trim(raw or "")
end

local function MatchesFilter(mountID)
    local filter = GetMLFilter()
    if filter == "" then return true end

    local f = filter:lower()
    local idStr = tostring(mountID or ""):lower()
    if idStr:find(f, 1, true) then return true end

    local name = tostring(PG.GetMountName(mountID) or "Unknown"):lower()
    if name:find(f, 1, true) then return true end

    return false
end

local function BuildConfiguredMountIDs()
    local ids = {}
    if type(PrototypeASMRDB) ~= "table" or type(PrototypeASMRDB.mounts) ~= "table" then
        return ids
    end

    for mountID, sounds in pairs(PrototypeASMRDB.mounts) do
        local mid = tonumber(mountID)
        if mid and type(sounds) == "table" and #sounds > 0 then
            if MatchesFilter(mid) then
                ids[#ids + 1] = mid
            end
        end
    end

    table.sort(ids)
    return ids
end

local function BuildSoundsForMount(mountID)
    local out = {}
    if not mountID then return out end
    local list = PrototypeASMRDB.mounts[mountID]
    if type(list) ~= "table" then return out end

    for i = 1, #list do
        out[#out + 1] = list[i]
    end

    -- ✅ Safe sort for mixed number/string entries
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)

    return out
end

local function ML_SaveSelectedMount(mid)
    PG.EnsureDB()
    PrototypeASMRDB.gui.mlSelectedMount = mid
end

local function ML_SelectMount(mid)
    PG.mlSelectedMountID = mid
    PG.mlSelectedSoundID = nil
    ML_SaveSelectedMount(mid)

    for i = 1, #PG.mlMountButtons do
        local b = PG.mlMountButtons[i]
        if b.mountID and b.mountID == mid then
            b:SetBackdropBorderColor(unpack(C.accent))
            b.txt:SetTextColor(unpack(C.accent))
        else
            b:SetBackdropBorderColor(unpack(C.borderDim))
            b.txt:SetTextColor(unpack(C.text))
        end
    end

    for i = 1, #PG.mlSoundButtons do
        local b = PG.mlSoundButtons[i]
        b:SetBackdropBorderColor(unpack(C.borderDim))
        b.txt:SetTextColor(unpack(C.text))
    end

    if UI.mlSoundScroll then FauxScrollFrame_SetOffset(UI.mlSoundScroll, 0) end
    if PG.RefreshMountListTab then PG.RefreshMountListTab() end
end

local function ML_SelectSound(sid)
    PG.mlSelectedSoundID = sid

    for i = 1, #PG.mlSoundButtons do
        local b = PG.mlSoundButtons[i]
        if b.soundID and b.soundID == sid then
            b:SetBackdropBorderColor(unpack(C.accent))
            b.txt:SetTextColor(unpack(C.accent))
        else
            b:SetBackdropBorderColor(unpack(C.borderDim))
            b.txt:SetTextColor(unpack(C.text))
        end
    end
end

local function JumpToMainWithMount(mid)
    if not (UI.frame and UI.frame:IsShown()) then return end
    if not (UI.ebMountID and UI.chkUseCurrent) then return end

    UI.ebMountID:SetText(tostring(mid))
    UI.ebMountID:SetCursorPosition(0)
    UI.chkUseCurrent:SetChecked(false)

    PG.EnsureDB()
    PrototypeASMRDB.gui.mainUseCurrent = false
    PrototypeASMRDB.gui.mainMountIDText = tostring(mid)

    if PG.SetActiveTab then
        PG.SetActiveTab("main")
    end
    if PG.RefreshInfoTexts then PG.RefreshInfoTexts() end
    if PG.RefreshSoundList then PG.RefreshSoundList() end
end

local function ShowSoundContextMenu(anchorBtn, mountID, soundID)
    if not (mountID and soundID ~= nil) then return end

    local menu = {
        { text = "Sound " .. tostring(soundID), isTitle = true, notCheckable = true },
        {
            text = "Play",
            notCheckable = true,
            func = function()
                -- ✅ Use PlayEntry so strings (custom names) work
                if PG.PlayEntry then
                    PG.PlayEntry(soundID)
                else
                    -- fallback: try numeric
                    local n = tonumber(soundID)
                    if n then PlaySound(n, (PrototypeASMRDB and PrototypeASMRDB.channel) or "SFX") end
                end
            end
        },
        {
            text = "Remove",
            notCheckable = true,
            func = function()
                PG.RemoveSound(mountID, soundID)
                PG.mlSelectedSoundID = nil
                if PG.RefreshMountListTab then PG.RefreshMountListTab() end
                if UI.activeTab == "main" and PG.RefreshSoundList and PG.RefreshInfoTexts then
                    PG.RefreshSoundList()
                    PG.RefreshInfoTexts()
                end
            end
        },
        { text = "Cancel", notCheckable = true }
    }

    if PG.OpenContextMenu then
        PG.OpenContextMenu(anchorBtn, menu)
    end
end

function PG.RefreshMountListTab()
    if not (UI.mlPanel and UI.mlPanel:IsShown() and UI.mlMountScroll and UI.mlSoundScroll) then
        return
    end

    local mountIDs = BuildConfiguredMountIDs()
    UI._mlMountIDs = mountIDs

    FauxScrollFrame_Update(UI.mlMountScroll, #mountIDs, PG.ML_MOUNT_ROWS, PG.ML_ROW_H)
    local moffset = FauxScrollFrame_GetOffset(UI.mlMountScroll)

    for i = 1, PG.ML_MOUNT_ROWS do
        local idx = i + moffset
        local btn = PG.mlMountButtons[i]
        local mid = mountIDs[idx]
        if mid then
            btn:Show()
            btn.mountID = mid

            local name = PG.GetMountName(mid)
            local count = (type(PrototypeASMRDB.mounts[mid]) == "table") and #PrototypeASMRDB.mounts[mid] or 0
            btn.txt:SetText(("%s | %d (%d)"):format(name, mid, count))

            if PG.mlSelectedMountID == mid then
                btn:SetBackdropBorderColor(unpack(C.accent))
                btn.txt:SetTextColor(unpack(C.accent))
            else
                btn:SetBackdropBorderColor(unpack(C.borderDim))
                btn.txt:SetTextColor(unpack(C.text))
            end
        else
            btn:Hide()
            btn.mountID = nil
            btn.txt:SetText("")
        end
    end

    -- keep selection valid
    if PG.mlSelectedMountID and #mountIDs > 0 then
        local stillExists = false
        for i = 1, #mountIDs do
            if mountIDs[i] == PG.mlSelectedMountID then stillExists = true break end
        end
        if not stillExists then
            PG.mlSelectedMountID = mountIDs[1]
            ML_SaveSelectedMount(PG.mlSelectedMountID)
        end
    elseif not PG.mlSelectedMountID and #mountIDs > 0 then
        PG.mlSelectedMountID = mountIDs[1]
        ML_SaveSelectedMount(PG.mlSelectedMountID)
    end

    local sounds = BuildSoundsForMount(PG.mlSelectedMountID)
    UI._mlSounds = sounds

    FauxScrollFrame_Update(UI.mlSoundScroll, #sounds, PG.ML_SOUND_ROWS, PG.ML_ROW_H)
    local soffset = FauxScrollFrame_GetOffset(UI.mlSoundScroll)

    for i = 1, PG.ML_SOUND_ROWS do
        local idx = i + soffset
        local btn = PG.mlSoundButtons[i]
        local sid = sounds[idx]
        if sid ~= nil then
            btn:Show()
            btn.soundID = sid
            btn.mountID = PG.mlSelectedMountID
            btn.txt:SetText(tostring(sid))

            if PG.mlSelectedSoundID == sid then
                btn:SetBackdropBorderColor(unpack(C.accent))
                btn.txt:SetTextColor(unpack(C.accent))
            else
                btn:SetBackdropBorderColor(unpack(C.borderDim))
                btn.txt:SetTextColor(unpack(C.text))
            end
        else
            btn:Hide()
            btn.soundID = nil
            btn.mountID = nil
            btn.txt:SetText("")
        end
    end
end

function PG.BuildMountListTab(frame)
    local mlP = PG.CreatePanel(frame, frame:GetWidth() - 24, frame:GetHeight() - 40 - 12, C.bgLight, C.borderDim)
    mlP:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -70)
    mlP:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    mlP:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.35)
    mlP:Hide()
    UI.mlPanel = mlP

    local mlTitle = PG.CreateLabel(mlP, "Mounts with Sounds", 12, C.text)
    mlTitle:SetPoint("TOPLEFT", mlP, "TOPLEFT", 10, -10)

    UI.mlBtnPlay = PG.CreateButton(mlP, "Play Sound", 110, 22, "green")
    UI.mlBtnPlay:SetPoint("TOPRIGHT", mlP, "TOPRIGHT", -10, -10)
    UI.mlBtnPlay:SetScript("OnClick", function()
        if PG.mlSelectedSoundID == nil then
            PG.Print("Select a sound first.")
            return
        end
        -- ✅ Use PlayEntry so custom names work
        if PG.PlayEntry then
            PG.PlayEntry(PG.mlSelectedSoundID)
        else
            PG.Print("PlayEntry missing.")
        end
    end)

    UI.mlBtnRemove = PG.CreateButton(mlP, "Remove", 90, 22, "danger")
    UI.mlBtnRemove:SetPoint("RIGHT", UI.mlBtnPlay, "LEFT", -10, 0)
    UI.mlBtnRemove:SetScript("OnClick", function()
        if not PG.mlSelectedMountID then
            PG.Print("Select a mount first.")
            return
        end
        if PG.mlSelectedSoundID == nil then
            PG.Print("Select a sound first.")
            return
        end

        PG.RemoveSound(PG.mlSelectedMountID, PG.mlSelectedSoundID)
        PG.mlSelectedSoundID = nil

        PG.RefreshMountListTab()

        if UI.activeTab == "main" and PG.RefreshSoundList and PG.RefreshInfoTexts then
            PG.RefreshSoundList()
            PG.RefreshInfoTexts()
        end
    end)

    local filterLbl = PG.CreateSmallLabel(mlP, "Filter")
    filterLbl:SetPoint("TOPLEFT", mlP, "TOPLEFT", 10, -34)

    UI.mlFilterEB = PG.CreateEditBox(mlP, 220, 22, "name or mountID")
    UI.mlFilterEB:SetPoint("LEFT", filterLbl, "RIGHT", 10, 0)

    -- restore filter text
    PG.EnsureDB()
    UI.mlFilterEB:SetText(PrototypeASMRDB.gui.mlFilter or "")
    UI.mlFilterEB:SetScript("OnTextChanged", function(self)
        PG.EnsureDB()
        PrototypeASMRDB.gui.mlFilter = self:GetText() or ""

        if UI.mlMountScroll then FauxScrollFrame_SetOffset(UI.mlMountScroll, 0) end
        if UI.mlSoundScroll then FauxScrollFrame_SetOffset(UI.mlSoundScroll, 0) end

        PG.RefreshMountListTab()
    end)
    UI.mlFilterEB:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    UI.mlFilterEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local leftBox = CreateFrame("Frame", nil, mlP, "BackdropTemplate")
    leftBox:SetPoint("TOPLEFT", mlP, "TOPLEFT", 10, -64)
    leftBox:SetPoint("BOTTOMLEFT", mlP, "BOTTOMLEFT", 10, 10)
    leftBox:SetPoint("RIGHT", mlP, "CENTER", -5, 0)
    PG.CreateBackdrop(leftBox, C.bgDark, C.borderDim)
    PG.SafeClip(leftBox, true)

    local rightBox = CreateFrame("Frame", nil, mlP, "BackdropTemplate")
    -- top anchored so it matches left box height
    rightBox:SetPoint("TOPLEFT", mlP, "TOP", 5, -64)
    rightBox:SetPoint("TOPRIGHT", mlP, "TOPRIGHT", -10, -64)
    rightBox:SetPoint("BOTTOMRIGHT", mlP, "BOTTOMRIGHT", -10, 10)
    PG.CreateBackdrop(rightBox, C.bgDark, C.borderDim)
    PG.SafeClip(rightBox, true)

    local leftLabel = PG.CreateSmallLabel(mlP, "Mounts")
    leftLabel:SetPoint("BOTTOMLEFT", leftBox, "TOPLEFT", 2, 6)

    local rightLabel = PG.CreateSmallLabel(mlP, "Sounds")
    rightLabel:SetPoint("BOTTOMLEFT", rightBox, "TOPLEFT", 2, 6)

    local mlMountScroll = CreateFrame("ScrollFrame", "PrototypeASMR_ML_MountScroll", leftBox, "FauxScrollFrameTemplate")
    mlMountScroll:SetPoint("TOPLEFT", leftBox, "TOPLEFT", 0, -2)
    mlMountScroll:SetPoint("BOTTOMRIGHT", leftBox, "BOTTOMRIGHT", -26, 2)
    UI.mlMountScroll = mlMountScroll

    mlMountScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, PG.ML_ROW_H, PG.RefreshMountListTab)
    end)

    local mlSoundScroll = CreateFrame("ScrollFrame", "PrototypeASMR_ML_SoundScroll", rightBox, "FauxScrollFrameTemplate")
    mlSoundScroll:SetPoint("TOPLEFT", rightBox, "TOPLEFT", 0, -2)
    mlSoundScroll:SetPoint("BOTTOMRIGHT", rightBox, "BOTTOMRIGHT", -26, 2)
    UI.mlSoundScroll = mlSoundScroll

    mlSoundScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, PG.ML_ROW_H, PG.RefreshMountListTab)
    end)

    -- mount rows
    for i = 1, PG.ML_MOUNT_ROWS do
        local row = CreateFrame("Button", nil, leftBox, "BackdropTemplate")
        row:SetHeight(PG.ML_ROW_H)
        row:SetPoint("TOPLEFT", leftBox, "TOPLEFT", 10, -10 - (i - 1) * PG.ML_ROW_H)
        row:SetPoint("TOPRIGHT", leftBox, "TOPRIGHT", -10, -10 - (i - 1) * PG.ML_ROW_H)
        PG.CreateBackdrop(row, {0, 0, 0, 0}, C.borderDim)

        row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.txt:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.txt:SetTextColor(unpack(C.text))
        row.txt:SetText("")

        row:SetScript("OnEnter", function(self)
            if self.mountID == PG.mlSelectedMountID then return end
            self:SetBackdropBorderColor(unpack(C.accent))
        end)
        row:SetScript("OnLeave", function(self)
            if self.mountID == PG.mlSelectedMountID then return end
            self:SetBackdropBorderColor(unpack(C.borderDim))
        end)

        row:SetScript("OnClick", function(self)
            if not self.mountID then return end

            local now = GetTime()
            local isDouble = (PG.mlLastClickMountID == self.mountID) and ((now - PG.mlLastClickTime) <= PG.ML_DBLCLICK_WINDOW)

            PG.mlLastClickTime = now
            PG.mlLastClickMountID = self.mountID

            if isDouble then
                ML_SelectMount(self.mountID)
                JumpToMainWithMount(self.mountID)
                return
            end

            ML_SelectMount(self.mountID)
        end)

        PG.mlMountButtons[i] = row
    end

    -- sound rows
    for i = 1, PG.ML_SOUND_ROWS do
        local row = CreateFrame("Button", nil, rightBox, "BackdropTemplate")
        row:SetHeight(PG.ML_ROW_H)
        row:SetPoint("TOPLEFT", rightBox, "TOPLEFT", 10, -10 - (i - 1) * PG.ML_ROW_H)
        row:SetPoint("TOPRIGHT", rightBox, "TOPRIGHT", -10, -10 - (i - 1) * PG.ML_ROW_H)
        PG.CreateBackdrop(row, {0, 0, 0, 0}, C.borderDim)

        row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.txt:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.txt:SetTextColor(unpack(C.text))
        row.txt:SetText("")

        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        row:SetScript("OnEnter", function(self)
            if self.soundID == PG.mlSelectedSoundID then return end
            self:SetBackdropBorderColor(unpack(C.accent))
        end)
        row:SetScript("OnLeave", function(self)
            if self.soundID == PG.mlSelectedSoundID then return end
            self:SetBackdropBorderColor(unpack(C.borderDim))
        end)

        row:SetScript("OnClick", function(self, button)
            if self.soundID == nil then return end
            ML_SelectSound(self.soundID)

            if button == "RightButton" then
                ShowSoundContextMenu(self, self.mountID, self.soundID)
            end
        end)

        PG.mlSoundButtons[i] = row
    end

    return mlP
end
