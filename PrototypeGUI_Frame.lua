-- PrototypeGUI_Frame.lua
-- Builds the main frame, tabs, resizing, and slash command

local addonName = ...
PrototypeGUI = PrototypeGUI or {}
local PG = PrototypeGUI

PG.UI = PG.UI or {}
local UI = PG.UI
local C  = PG.C

-- Layout constants
local PAD = 12
local TITLE_Y = 10

-- Tabs row sits UNDER title
local TABS_TOP_Y = 40         -- distance from top edge to the tab row
local CONTENT_TOP_Y = 70      -- where tab content should start (matches your CS/Main usage)

-- Default / resize bounds (bigger so everything fits)
local DEFAULT_W, DEFAULT_H = 760, 640
local MIN_W, MIN_H = 700, 600
local MAX_W, MAX_H = 1200, 1000

local function PersistActiveTab(which)
    PG.EnsureDB()
    PrototypeASMRDB.gui.lastTab = which
end

local function UpdateEnabledToggle(btn)
    if PrototypeASMRDB.enabled then
        btn.txt:SetText("Enabled")
        btn:SetBackdropBorderColor(unpack(C.green))
    else
        btn.txt:SetText("Disabled")
        btn:SetBackdropBorderColor(unpack(C.danger))
    end
end

function PG.SetActiveTab(which)
    UI.activeTab = which
    PersistActiveTab(which)

    local showMain = (which == "main")
    local showIE   = (which == "ie")
    local showML   = (which == "ml")
    local showCS   = (which == "cs")

    if UI.mainPanels then
        for _, p in ipairs(UI.mainPanels) do
            if p then p:SetShown(showMain) end
        end
    end
    if UI.iePanel then UI.iePanel:SetShown(showIE) end
    if UI.mlPanel then UI.mlPanel:SetShown(showML) end
    if UI.csPanel then UI.csPanel:SetShown(showCS) end

    if UI.tabMain then
        UI.tabMain:SetBackdropBorderColor(unpack(showMain and C.accent or C.borderDim))
        UI.tabMain.txt:SetTextColor(unpack(showMain and C.accent or C.text))
    end
    if UI.tabML then
        UI.tabML:SetBackdropBorderColor(unpack(showML and C.accent or C.borderDim))
        UI.tabML.txt:SetTextColor(unpack(showML and C.accent or C.text))
    end
    if UI.tabCS then
        UI.tabCS:SetBackdropBorderColor(unpack(showCS and C.accent or C.borderDim))
        UI.tabCS.txt:SetTextColor(unpack(showCS and C.accent or C.text))
    end
    if UI.tabIE then
        UI.tabIE:SetBackdropBorderColor(unpack(showIE and C.accent or C.borderDim))
        UI.tabIE.txt:SetTextColor(unpack(showIE and C.accent or C.text))
    end

    if showMain then
        if PG.RefreshInfoTexts then PG.RefreshInfoTexts() end
        if PG.RefreshSoundList then PG.RefreshSoundList() end
    elseif showML then
        if PG.RefreshMountListTab then PG.RefreshMountListTab() end
    elseif showCS then
        if UI.RefreshCustomSoundsTab then UI.RefreshCustomSoundsTab() end
    elseif showIE then
        -- no-op
    end
end

local function ReflowPanels(frame)
    if not frame then return end

    local w = frame:GetWidth()
    local h = frame:GetHeight()

    -- MAIN (these are set inside MainTab.lua; here we just make widths react)
    if UI.infoPanel then
        UI.infoPanel:SetWidth(w - (PAD * 2))
    end
    if UI.mountPanel and UI.soundPanel then
        UI.soundPanel:SetWidth(w - (PAD * 2) - UI.mountPanel:GetWidth() - 10)
    end
    if UI.listPanel then
        UI.listPanel:SetWidth(w - (PAD * 2))
    end

    -- IE (panel height should match content region)
    if UI.iePanel then
        UI.iePanel:SetWidth(w - (PAD * 2))
        UI.iePanel:SetHeight(h - CONTENT_TOP_Y - PAD)

        if UI.ieExportBoxFrame and UI.ieExportBoxFrame.editBox then
            UI.ieExportBoxFrame:SetWidth(UI.iePanel:GetWidth() - 20)
            UI.ieExportBoxFrame.editBox:SetWidth(UI.iePanel:GetWidth() - 20 - 40)
        end
        if UI.ieImportBoxFrame and UI.ieImportBoxFrame.editBox then
            UI.ieImportBoxFrame:SetWidth(UI.iePanel:GetWidth() - 20)
            UI.ieImportBoxFrame.editBox:SetWidth(UI.iePanel:GetWidth() - 20 - 40)
        end
    end

    -- CS (your CS panel already anchors to -70, keep height consistent)
    if UI.csPanel then
        UI.csPanel:SetWidth(w - (PAD * 2))
        UI.csPanel:SetHeight(h - CONTENT_TOP_Y - PAD)
        if UI.csPanel:IsShown() and UI.RefreshCustomSoundsTab then
            UI.RefreshCustomSoundsTab()
        end
    end

    -- ML (your ML panel currently anchors at -40 in its file; we still resize it here)
    if UI.mlPanel then
        UI.mlPanel:SetWidth(w - (PAD * 2))
        UI.mlPanel:SetHeight(h - CONTENT_TOP_Y - PAD)
        if UI.mlPanel:IsShown() and PG.RefreshMountListTab then
            PG.RefreshMountListTab()
        end
    end

    if PG.RefreshInfoTexts then PG.RefreshInfoTexts() end
end

function PG.CreateGUI()
    PG.EnsureDB()

    local frame = CreateFrame("Frame", "PrototypeASMR_GUI", UIParent, "BackdropTemplate")
    frame:SetSize(DEFAULT_W, DEFAULT_H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    PG.CreateBackdrop(frame, C.bg, C.borderDim)
    PG.SafeClip(frame, true)
    frame:Hide()

    -- Resizable (compat-safe)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    else
        frame.__minW, frame.__minH = MIN_W, MIN_H
        frame.__maxW, frame.__maxH = MAX_W, MAX_H
    end

    UI.frame = frame

    local title = PG.CreateLabel(frame, "ProjectASMR Mount Sound Manager", 14, C.text)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TITLE_Y)

    local close = PG.CreateButton(frame, "X", 22, 22, "danger")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() frame:Hide() end)
	
	local close = PG.CreateButton(frame, "X", 22, 22, "danger")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
	close:SetScript("OnClick", function() frame:Hide() end)

	-- Enabled / Disabled toggle
	local toggle = PG.CreateButton(frame, "", 90, 22)
	toggle:SetPoint("RIGHT", close, "LEFT", -8, 0)

	toggle:SetScript("OnClick", function(self)
		PrototypeASMRDB.enabled = not PrototypeASMRDB.enabled
		UpdateEnabledToggle(self)
	end)

	-- Initial state
	UpdateEnabledToggle(toggle)

	UI.btnEnabledToggle = toggle


    -- Tabs anchor (UNDER title)
    local tabsAnchor = CreateFrame("Frame", nil, frame)
    tabsAnchor:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TABS_TOP_Y)
    tabsAnchor:SetSize(1, 1)

    UI.tabMain = PG.CreateButton(frame, "Main", 70, 22)
    UI.tabMain:SetPoint("TOPLEFT", tabsAnchor, "TOPLEFT", 0, 0)
    UI.tabMain:SetScript("OnClick", function() PG.SetActiveTab("main") end)

    UI.tabML = PG.CreateButton(frame, "Mount List", 110, 22)
    UI.tabML:SetPoint("LEFT", UI.tabMain, "RIGHT", 8, 0)
    UI.tabML:SetScript("OnClick", function() PG.SetActiveTab("ml") end)

    UI.tabCS = PG.CreateButton(frame, "Custom Sounds", 130, 22)
    UI.tabCS:SetPoint("LEFT", UI.tabML, "RIGHT", 8, 0)
    UI.tabCS:SetScript("OnClick", function() PG.SetActiveTab("cs") end)

    UI.tabIE = PG.CreateButton(frame, "Import/Export", 110, 22)
    UI.tabIE:SetPoint("LEFT", UI.tabCS, "RIGHT", 8, 0)
    UI.tabIE:SetScript("OnClick", function() PG.SetActiveTab("ie") end)

    -- Resize grip (bottom-right)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    grip:EnableMouse(true)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    grip:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)

    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        if not frame.SetResizeBounds and frame.__minW then
            local w, h = frame:GetSize()
            local minW, minH = frame.__minW, frame.__minH
            local maxW, maxH = frame.__maxW or w, frame.__maxH or h
            if w < minW then w = minW end
            if h < minH then h = minH end
            if w > maxW then w = maxW end
            if h > maxH then h = maxH end
            frame:SetSize(w, h)
        end
        ReflowPanels(frame)
    end)

    -- Build tabs
    UI.mainPanels = PG.BuildMainTab(frame)
    UI.iePanel = PG.BuildImportExportTab(frame)
    UI.mlPanel = PG.BuildMountListTab(frame)
    UI.csPanel = PG.BuildCustomSoundsTab(frame)

    -- Size-changed reflow
    frame:SetScript("OnSizeChanged", function()
        ReflowPanels(frame)
    end)

    -- Restore persisted state
    local g = PrototypeASMRDB.gui
    if UI.chkUseCurrent then UI.chkUseCurrent:SetChecked(g.mainUseCurrent and true or false) end
    if UI.ebMountID then UI.ebMountID:SetText(g.mainMountIDText or "") end

    PG.mlSelectedMountID = g.mlSelectedMount
    PG.mlSelectedSoundID = nil

    local startTab = g.lastTab or "main"
    if startTab ~= "main" and startTab ~= "ie" and startTab ~= "ml" and startTab ~= "cs" then
        startTab = "main"
    end

    -- Do a first layout pass BEFORE selecting tab
    ReflowPanels(frame)

    PG.SetActiveTab(startTab)

    if PG.RefreshInfoTexts then PG.RefreshInfoTexts() end
    if PG.RefreshSoundList then PG.RefreshSoundList() end

    return frame
end

-- Slash to open GUI
SLASH_PROTOTYPEASMRGUI1 = "/asmrgui"
SlashCmdList["PROTOTYPEASMRGUI"] = function()
    PG.EnsureDB()
    if not UI.frame then
        PG.CreateGUI()
    end
	
		if UI.btnEnabledToggle then
		UpdateEnabledToggle(UI.btnEnabledToggle)
	end

    UI.frame:SetShown(not UI.frame:IsShown())

    if UI.frame:IsShown() then
        -- ensure everything fits after opening
        ReflowPanels(UI.frame)

        if UI.activeTab == "main" then
            if PG.RefreshInfoTexts then PG.RefreshInfoTexts() end
            if PG.RefreshSoundList then PG.RefreshSoundList() end
        elseif UI.activeTab == "ml" and PG.RefreshMountListTab then
            PG.RefreshMountListTab()
        elseif UI.activeTab == "cs" and UI.RefreshCustomSoundsTab then
            UI.RefreshCustomSoundsTab()
        end
    end
end
