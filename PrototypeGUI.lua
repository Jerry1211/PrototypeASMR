-- PrototypeGUI.lua
-- GUI for PrototypeASMR

local addonName = ...
local f = CreateFrame("Frame")

PrototypeASMRDB = PrototypeASMRDB or nil

-- ======================================================
-- Runtime caches
-- ======================================================
local SpellToMountID = {}       -- spellID -> mountID
local lastMountedMountID = nil  -- cached current mountID from spellcasts

-- ======================================================
-- Helpers
-- ======================================================
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffPrototypeGUI:|r " .. tostring(msg))
end

local function EnsureDB()
    if type(PrototypeASMRDB) ~= "table" then PrototypeASMRDB = {} end
    if type(PrototypeASMRDB.mounts) ~= "table" then PrototypeASMRDB.mounts = {} end
    if PrototypeASMRDB.enabled == nil then PrototypeASMRDB.enabled = true end
end

local function ToNumberSafe(x)
    local n = tonumber(x)
    if not n or n ~= n then return nil end
    return n
end

local function Trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function BuildSpellToMountCache()
    wipe(SpellToMountID)

    if not C_MountJournal or not C_MountJournal.GetMountIDs or not C_MountJournal.GetMountInfoByID then
        return
    end

    local ids = C_MountJournal.GetMountIDs()
    if type(ids) ~= "table" then return end

    for _, mountID in ipairs(ids) do
        local _, spellID = C_MountJournal.GetMountInfoByID(mountID)
        if spellID and mountID then
            SpellToMountID[spellID] = mountID
        end
    end
end

local function GetMountName(mountID)
    if C_MountJournal and C_MountJournal.GetMountInfoByID then
        local name = C_MountJournal.GetMountInfoByID(mountID)
        return name or "Unknown"
    end
    return "Unknown"
end

local function GetMountSpellID(mountID)
    if C_MountJournal and C_MountJournal.GetMountInfoByID then
        local _, spellID = C_MountJournal.GetMountInfoByID(mountID)
        return spellID
    end
    return nil
end

local function HasSound(mountID, soundID)
    local list = PrototypeASMRDB.mounts[mountID]
    if type(list) ~= "table" then return false end
    for i = 1, #list do
        if list[i] == soundID then return true end
    end
    return false
end

local function AddSound(mountID, soundID)
    if not mountID or not soundID then
        Print("Missing mountID or soundID.")
        return
    end
    if type(PrototypeASMRDB.mounts[mountID]) ~= "table" then
        PrototypeASMRDB.mounts[mountID] = {}
    end
    if HasSound(mountID, soundID) then
        Print("Sound already exists.")
        return
    end
    table.insert(PrototypeASMRDB.mounts[mountID], soundID)
    Print("Added SoundID " .. soundID .. " to MountID " .. mountID)
end

local function RemoveSound(mountID, soundID)
    local list = PrototypeASMRDB.mounts[mountID]
    if type(list) ~= "table" then
        Print("No sounds for that mount.")
        return
    end
    for i = #list, 1, -1 do
        if list[i] == soundID then
            table.remove(list, i)
            Print("Removed SoundID " .. soundID .. " from MountID " .. mountID)
            if #list == 0 then
                PrototypeASMRDB.mounts[mountID] = nil
            end
            return
        end
    end
    Print("Sound not found on that mount.")
end

local function ClearSounds(mountID)
    PrototypeASMRDB.mounts[mountID] = nil
    Print("Cleared all sounds for MountID " .. mountID)
end

local function PlayRandomForMount(mountID)
    if not PrototypeASMRDB.enabled then
        Print("Addon is OFF.")
        return
    end
    local list = PrototypeASMRDB.mounts[mountID]
    if type(list) ~= "table" or #list == 0 then
        Print("No sounds configured for that mount.")
        return
    end
    PlaySound(list[math.random(#list)], "SFX")
end

local function ResolveTargetMount(mountIDText, useCurrent)
    if useCurrent then
        if lastMountedMountID and lastMountedMountID > 0 then
            return lastMountedMountID
        end
        return nil
    end

    local mid = ToNumberSafe(Trim(mountIDText))
    if not mid then
        return nil
    end
    return mid
end

-- ======================================================
-- Skin helpers (dark slate + mint accent)
-- ======================================================
local UI = {}

local C = {
    bg        = {0.067, 0.094, 0.153, 0.97},
    bgLight   = {0.122, 0.161, 0.216, 1.0},
    bgDark    = {0.04,  0.06,  0.10,  1.0},
    borderDim = {0.17,  0.22,  0.30,  0.9},
    text      = {0.92,  0.95,  1.0,   1.0},
    textDim   = {0.75,  0.80,  0.88,  1.0},
    accent    = {0.204, 0.827, 0.6,   1.0},
    danger    = {0.95,  0.33,  0.33,  1.0},
	green     = {0.204, 0.827, 0.6,   1.0},

}

local function SafeClip(frame, on)
    if frame and frame.SetClipsChildren then
        frame:SetClipsChildren(on and true or false)
    end
end

local function CreateBackdrop(frame, bgColor, borderColor)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(bgColor or C.bg))
    frame:SetBackdropBorderColor(unpack(borderColor or C.borderDim))
end

local function SetBoundText(fs, parentPanel, padL, padR, text)
    if not fs or not parentPanel then return end
    padL = padL or 0
    padR = padR or 0

    local maxW = (parentPanel:GetWidth() or 300) - padL - padR
    if maxW < 20 then maxW = 20 end

    fs:SetWidth(maxW)
    fs:SetWordWrap(false)
    fs:SetMaxLines(1)

    local full = tostring(text or "")
    fs:SetText(full)

    if fs:GetStringWidth() <= maxW then
        return
    end

    local suffix = "..."
    local lo, hi = 0, #full
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        fs:SetText(full:sub(1, mid) .. suffix)
        if fs:GetStringWidth() <= maxW then
            lo = mid
        else
            hi = mid - 1
        end
    end
    fs:SetText(full:sub(1, lo) .. suffix)
end

local function CreatePanel(parent, w, h, bg, border)
    local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    p:SetSize(w, h)
    CreateBackdrop(p, bg or C.bgLight, border or C.borderDim)
    SafeClip(p, true)
    return p
end

local function CreateLabel(parent, text, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text or "")
    fs:SetTextColor(unpack(color or C.text))
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetMaxLines(1)
    if size then
        local font, _, flags = fs:GetFont()
        fs:SetFont(font, size, flags)
    end
    return fs
end

local function CreateSmallLabel(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetText(text or "")
    fs:SetTextColor(unpack(C.textDim))
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetMaxLines(1)
    return fs
end

local function CreateButton(parent, text, w, h, kind)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)

    local borderColor =
        (kind == "danger") and C.danger or
        (kind == "green")  and C.green  or
        C.borderDim

    CreateBackdrop(b, C.bgDark, borderColor)

    b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.txt:SetPoint("CENTER")
    b.txt:SetText(text or "")
    b.txt:SetTextColor(unpack(C.text))

    b:SetScript("OnEnter", function(self)
        local hoverColor =
            (kind == "danger") and C.danger or
            (kind == "green")  and C.green  or
            C.accent
        self:SetBackdropBorderColor(unpack(hoverColor))
    end)

    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(borderColor))
    end)

    return b
end


local function CreateEditBox(parent, w, h, placeholder)
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    eb:SetAutoFocus(false)
    eb:SetSize(w, h)
    CreateBackdrop(eb, C.bgDark, C.borderDim)
    eb:SetTextInsets(8, 8, 0, 0)

    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetTextColor(unpack(C.text))

    if placeholder then
        eb.placeholder = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        eb.placeholder:SetPoint("LEFT", eb, "LEFT", 8, 0)
        eb.placeholder:SetText(placeholder)
        eb.placeholder:SetTextColor(0.55, 0.6, 0.7, 1)
        eb:SetScript("OnTextChanged", function(self)
            eb.placeholder:SetShown(self:GetText() == "")
        end)
        eb.placeholder:SetShown(true)
    end

    eb:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(unpack(C.accent))
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(unpack(C.borderDim))
    end)

    return eb
end

local function CreateCheck(parent, text, onClick)
    local c = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    c.Text:SetText(text or "")
    c.Text:SetTextColor(unpack(C.text))
    if onClick then c:SetScript("OnClick", onClick) end
    return c
end

-- ======================================================
-- Sound list
-- ======================================================
local SOUND_ROWS = 10
local ROW_H = 18
local soundRowButtons = {}
local selectedSoundID = nil

local function GetSelectedMountFromUI()
    local useCurrent = UI.chkUseCurrent and UI.chkUseCurrent:GetChecked()
    local mountIDText = UI.ebMountID and UI.ebMountID:GetText() or ""
    return ResolveTargetMount(mountIDText, useCurrent)
end

local function GetSoundIDFromUI()
    local raw = UI.ebSoundID and UI.ebSoundID:GetText() or ""
    raw = Trim(raw)
    local sid = ToNumberSafe(raw)
    if sid then return sid end
    if selectedSoundID and type(selectedSoundID) == "number" then
        return selectedSoundID
    end
    return nil
end

local function RefreshInfoTexts()
    if not (UI.infoPanel and UI.txtCurrent and UI.txtSelectedMount) then return end

    local mountID = GetSelectedMountFromUI()

    if lastMountedMountID and lastMountedMountID > 0 then
        local name = GetMountName(lastMountedMountID)
        local spellID = GetMountSpellID(lastMountedMountID)
        local s = ("Current (cached): %s | MountID %d | SpellID %s")
            :format(name, lastMountedMountID, tostring(spellID))
        SetBoundText(UI.txtCurrent, UI.infoPanel, 14, 14, s)
    else
        SetBoundText(UI.txtCurrent, UI.infoPanel, 14, 14, "Current (cached): none (mount once to cache)")
    end

    if mountID then
        local s2 = ("Selected mount: %s (MountID %d)")
            :format(GetMountName(mountID), mountID)
        SetBoundText(UI.txtSelectedMount, UI.infoPanel, 14, 14, s2)
    else
        SetBoundText(UI.txtSelectedMount, UI.infoPanel, 14, 14, "Selected mount: (none)")
    end
end

local function RefreshSoundList()
    if not UI.scrollFrame then return end

    selectedSoundID = nil
    if UI.ebSoundID then UI.ebSoundID:SetText("") end

    local mountID = GetSelectedMountFromUI()
    local list = (mountID and PrototypeASMRDB.mounts[mountID]) or nil
    if type(list) ~= "table" then list = {} end

    local display = {}
    for i = 1, #list do display[i] = list[i] end
    table.sort(display)
    UI._displaySounds = display

    FauxScrollFrame_Update(UI.scrollFrame, #display, SOUND_ROWS, ROW_H)
    local offset = FauxScrollFrame_GetOffset(UI.scrollFrame)

    for i = 1, SOUND_ROWS do
        local idx = i + offset
        local btn = soundRowButtons[i]
        local sid = display[idx]
        if sid then
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

    RefreshInfoTexts()
end

local function SelectSoundRow(btn)
    if not btn or type(btn.soundID) ~= "number" then return end
    selectedSoundID = btn.soundID

    for i = 1, #soundRowButtons do
        local b = soundRowButtons[i]
        if b.soundID == selectedSoundID then
            b:SetBackdropBorderColor(unpack(C.accent))
            b.txt:SetTextColor(unpack(C.accent))
        else
            b:SetBackdropBorderColor(unpack(C.borderDim))
            b.txt:SetTextColor(unpack(C.text))
        end
    end

    if UI.ebSoundID then
        UI.ebSoundID:SetText(tostring(selectedSoundID))
        UI.ebSoundID:ClearFocus()
        UI.ebSoundID:SetCursorPosition(0)
    end
end

-- ======================================================
-- Confirm popup
-- ======================================================
StaticPopupDialogs["PROTOTYPEASMR_GUI_CLEAR_ALL"] = {
    text = "Clear ALL sounds for this mount?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        if UI._pendingClearMountID then
            ClearSounds(UI._pendingClearMountID)
            UI._pendingClearMountID = nil
            RefreshSoundList()
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
        if UI._pendingRemoveMountID and UI._pendingRemoveSoundID then
            RemoveSound(UI._pendingRemoveMountID, UI._pendingRemoveSoundID)
            UI._pendingRemoveMountID = nil
            UI._pendingRemoveSoundID = nil
            RefreshSoundList()
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
-- Main GUI
-- ======================================================
local function CreateGUI()
    EnsureDB()

    local frame = CreateFrame("Frame", "PrototypeASMR_GUI", UIParent, "BackdropTemplate")
    frame:SetSize(560, 460)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    CreateBackdrop(frame, C.bg, C.borderDim)
    SafeClip(frame, true)
    frame:Hide()

    UI.frame = frame

    local title = CreateLabel(frame, "PrototypeASMR GUI", 14, C.text)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)

    local close = CreateButton(frame, "X", 22, 22, "danger")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() frame:Hide() end)

    -- Info panel
    local info = CreatePanel(frame, frame:GetWidth() - 24, 94, C.bgLight, C.borderDim)
    info:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
    info:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.6)
    UI.infoPanel = info

    UI.chkEnabled = CreateCheck(info, "Enabled", function(self)
        PrototypeASMRDB.enabled = self:GetChecked() and true or false
    end)
    UI.chkEnabled:SetPoint("TOPLEFT", info, "TOPLEFT", 10, -10)
    UI.chkEnabled:SetChecked(PrototypeASMRDB.enabled and true or false)

    UI.txtCurrent = CreateSmallLabel(info, "")
    UI.txtCurrent:SetPoint("TOPLEFT", info, "TOPLEFT", 10, -32)

    UI.txtSelectedMount = CreateSmallLabel(info, "")
    UI.txtSelectedMount:SetPoint("TOPLEFT", info, "TOPLEFT", 10, -52)

    -- Mount panel
    local mountP = CreatePanel(frame, 270, 120, C.bgLight, C.borderDim)
    mountP:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -12)
    mountP:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.45)

    local mTitle = CreateLabel(mountP, "Mount target", 12, C.text)
    mTitle:SetPoint("TOPLEFT", mountP, "TOPLEFT", 10, -10)

    UI.chkUseCurrent = CreateCheck(mountP, "Use current", function()
        RefreshSoundList()
        RefreshInfoTexts()
    end)
    UI.chkUseCurrent:SetPoint("TOPLEFT", mountP, "TOPLEFT", 10, -32)
    UI.chkUseCurrent:SetChecked(true)

    UI.ebMountID = CreateEditBox(mountP, 110, 22, "MountID")
    UI.ebMountID:SetPoint("TOPLEFT", mountP, "TOPLEFT", 130, -30)
    UI.ebMountID:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        RefreshSoundList()
        RefreshInfoTexts()
    end)

    UI.btnGetID = CreateButton(mountP, "GetID (mounted)", 140, 22)
    UI.btnGetID:SetPoint("TOPLEFT", mountP, "TOPLEFT", 10, -64)
    UI.btnGetID:SetScript("OnClick", function()
        if lastMountedMountID and lastMountedMountID > 0 then
            UI.ebMountID:SetText(tostring(lastMountedMountID))
            UI.ebMountID:SetCursorPosition(0)
            UI.chkUseCurrent:SetChecked(false)
            RefreshSoundList()
        else
            Print("No current mount cached yet. Mount once to cache.")
        end
        RefreshInfoTexts()
    end)

    -- Sound panel
    local soundP = CreatePanel(frame, frame:GetWidth() - 24 - mountP:GetWidth() - 10, 120, C.bgLight, C.borderDim)
    soundP:SetPoint("TOPLEFT", mountP, "TOPRIGHT", 10, 0)
    soundP:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.45)

    local sTitle = CreateLabel(soundP, "Sound ID", 12, C.text)
    sTitle:SetPoint("TOPLEFT", soundP, "TOPLEFT", 10, -10)

    UI.ebSoundID = CreateEditBox(soundP, 140, 22, "SoundID")
    UI.ebSoundID:SetPoint("TOPLEFT", soundP, "TOPLEFT", 10, -32)
    UI.ebSoundID:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    UI.btnPlaySound = CreateButton(soundP, "Play Sound", 120, 22)
    UI.btnPlaySound:SetPoint("LEFT", UI.ebSoundID, "TOPLEFT", 0, -35)
    UI.btnPlaySound:SetScript("OnClick", function()
        local sid = GetSoundIDFromUI()
        if not sid then Print("Invalid SoundID.") return end
        PlaySound(sid, "SFX")
    end)

    -- List panel
    local listP = CreatePanel(frame, frame:GetWidth() - 24, 170, C.bgLight, C.borderDim)
    listP:SetPoint("TOPLEFT", mountP, "BOTTOMLEFT", 0, -12)
    listP:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.35)
    UI.listPanel = listP

    local listTitle = CreateLabel(listP, "Sounds on selected mount (click to select)", 12, C.text)
    listTitle:SetPoint("TOPLEFT", listP, "TOPLEFT", 10, -10)

    -- Left list box
    local listBox = CreateFrame("Frame", nil, listP, "BackdropTemplate")
    listBox:SetPoint("TOPLEFT", listP, "TOPLEFT", 10, -32)
    listBox:SetPoint("BOTTOMLEFT", listP, "BOTTOMLEFT", 10, 10)
    listBox:SetWidth(300)
    CreateBackdrop(listBox, C.bgDark, C.borderDim)
    SafeClip(listBox, true)
    UI.listBox = listBox

    local scrollFrame = CreateFrame("ScrollFrame", "PrototypeASMR_SoundScroll", listBox, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listBox, "TOPLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", listBox, "BOTTOMRIGHT", -26, 2)
    UI.scrollFrame = scrollFrame

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, RefreshSoundList)
    end)

    for i = 1, SOUND_ROWS do
        local row = CreateFrame("Button", nil, listBox, "BackdropTemplate")
        row:SetSize(260, ROW_H)
        row:SetPoint("TOPLEFT", listBox, "TOPLEFT", 10, -10 - (i - 1) * ROW_H)
        CreateBackdrop(row, {0, 0, 0, 0}, C.borderDim)

        row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.txt:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.txt:SetTextColor(unpack(C.text))
        row.txt:SetText("")

        row:SetScript("OnEnter", function(self)
            if self.soundID == selectedSoundID then return end
            self:SetBackdropBorderColor(unpack(C.accent))
        end)
        row:SetScript("OnLeave", function(self)
            if self.soundID == selectedSoundID then return end
            self:SetBackdropBorderColor(unpack(C.borderDim))
        end)

        row:SetScript("OnClick", function(self) SelectSoundRow(self) end)

        soundRowButtons[i] = row
    end

    -- RIGHT SIDE actions panel inside list panel
    local actions = CreatePanel(listP, listP:GetWidth() - 320, 128, C.bgDark, C.borderDim)
    actions:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 12, 0)
    actions:SetPoint("BOTTOMRIGHT", listP, "BOTTOMRIGHT", -10, 10)
    actions:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 0.35)
    UI.actionsPanel = actions

    UI.btnAdd = CreateButton(actions, "Add", 90, 22, "green")
    UI.btnAdd:SetPoint("TOPLEFT", actions, "TOPLEFT", 10, -10)
    UI.btnAdd:SetScript("OnClick", function()
        local mountID = GetSelectedMountFromUI()
        if not mountID then Print("Select a mount first.") return end
        local sid = GetSoundIDFromUI()
        if not sid then Print("Invalid SoundID.") return end
        AddSound(mountID, sid)
        RefreshSoundList()
    end)

UI.btnRemove = CreateButton(actions, "Remove", 80, 24, "danger")
UI.btnRemove:SetPoint("LEFT", UI.btnAdd, "RIGHT", 10, 0)
UI.btnRemove:SetScript("OnClick", function()
    local mountID = GetSelectedMountFromUI()
    if not mountID then
        Print("Select a mount first.")
        return
    end

    local sid = GetSoundIDFromUI()
    if not sid then
        Print("Invalid SoundID.")
        return
    end

    UI._pendingRemoveMountID = mountID
    UI._pendingRemoveSoundID = sid
    StaticPopup_Show("PROTOTYPEASMR_GUI_REMOVE_SOUND")
end)


    UI.btnClearAll = CreateButton(actions, "Clear All", 84, 24, "danger")
    UI.btnClearAll:SetPoint("TOPLEFT", UI.btnAdd, "BOTTOMLEFT", 0, -10)
    UI.btnClearAll:SetScript("OnClick", function()
        local mountID = GetSelectedMountFromUI()
        if not mountID then Print("Select a mount first.") return end
        UI._pendingClearMountID = mountID
        StaticPopup_Show("PROTOTYPEASMR_GUI_CLEAR_ALL")
    end)

    UI.btnPlayRandom = CreateButton(actions, "Play Random Sound", 190, 22)
    UI.btnPlayRandom:SetPoint("TOPLEFT", UI.btnClearAll, "BOTTOMLEFT", 0, -10)
    UI.btnPlayRandom:SetScript("OnClick", function()
        local mountID = GetSelectedMountFromUI()
        if not mountID then Print("Select a mount first.") return end
        PlayRandomForMount(mountID)
    end)

    info:SetScript("OnSizeChanged", function()
        RefreshInfoTexts()
    end)

    RefreshInfoTexts()
    RefreshSoundList()
end

-- Slash to open GUI
SLASH_PROTOTYPEASMRGUI1 = "/asmrgui"
SlashCmdList["PROTOTYPEASMRGUI"] = function()
    EnsureDB()
    if not UI.frame then
        CreateGUI()
    end
    UI.frame:SetShown(not UI.frame:IsShown())
    if UI.frame:IsShown() then
        RefreshInfoTexts()
        RefreshSoundList()
    end
end

-- ======================================================
-- Events (track current mount)
-- ======================================================
f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        BuildSpellToMountCache()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        BuildSpellToMountCache()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit ~= "player" then return end
        if not spellID then return end

        local mountID = SpellToMountID[spellID]
        if mountID then
            lastMountedMountID = mountID

            if UI.frame and UI.frame:IsShown() then
                RefreshInfoTexts()
                if UI.chkUseCurrent and UI.chkUseCurrent:GetChecked() then
                    RefreshSoundList()
                end
            end
        end
    end
end)

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
