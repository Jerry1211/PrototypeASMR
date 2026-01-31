-- PrototypeGUI_ImportExportTab.lua
-- Import/Export tab (single box + export options)

local addonName = ...
PrototypeGUI = PrototypeGUI or {}
local PG = PrototypeGUI

local UI = PG.UI
local C  = PG.C

function PG.BuildImportExportTab(frame)
    local ieP = PG.CreatePanel(frame, frame:GetWidth() - 24, frame:GetHeight() - 70 - 12, C.bgLight, C.borderDim)
    ieP:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -70)
    ieP:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    ieP:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.35)
    ieP:Hide()
    UI.iePanel = ieP

    local ieTitle = PG.CreateLabel(ieP, "Import / Export", 12, C.text)
    ieTitle:SetPoint("TOPLEFT", ieP, "TOPLEFT", 10, -10)

    -- =========================
    -- Export options (above box)
    -- =========================
    local optLabel = PG.CreateSmallLabel(ieP, "Export options:")
    optLabel:SetPoint("TOPLEFT", ieP, "TOPLEFT", 10, -34)

    UI.ieOptCustomSettings = PG.CreateCheck(ieP, "Custom Sounds Settings (names + files + channel)")
    UI.ieOptCustomSettings:SetPoint("TOPLEFT", ieP, "TOPLEFT", 10, -54)
    UI.ieOptCustomSettings:SetChecked(true)

    UI.ieOptCustomOnMounts = PG.CreateCheck(ieP, "Custom Sound On Mounts (custom names on mounts)")
    UI.ieOptCustomOnMounts:SetPoint("TOPLEFT", UI.ieOptCustomSettings, "BOTTOMLEFT", 0, -4)
    UI.ieOptCustomOnMounts:SetChecked(true)

    UI.ieOptSoundIDs = PG.CreateCheck(ieP, "Sound IDs (Blizzard SoundKit IDs)")
    UI.ieOptSoundIDs:SetPoint("TOPLEFT", UI.ieOptCustomOnMounts, "BOTTOMLEFT", 0, -4)
    UI.ieOptSoundIDs:SetChecked(true)

    -- =========================
    -- Single payload box
    -- =========================
    local boxFrame, eb = PG.CreateScrollEditBox(ieP, ieP:GetWidth() - 20, 230)
    boxFrame:SetPoint("TOPLEFT", ieP, "TOPLEFT", 10, -130)
    boxFrame:SetPoint("TOPRIGHT", ieP, "TOPRIGHT", -10, -130)
    UI.iePayloadEB = eb
    UI.iePayloadBoxFrame = boxFrame

    -- Import override
    UI.ieOverride = PG.CreateCheck(ieP, "Override (otherwise Merge + Dedupe)")
    UI.ieOverride:SetPoint("TOPLEFT", boxFrame, "BOTTOMLEFT", 2, -6)

    -- Buttons
    local btnExport = PG.CreateButton(ieP, "Export", 90, 22, "green")
    btnExport:SetPoint("TOPLEFT", UI.ieOverride, "BOTTOMLEFT", -2, -10)

    local btnImport = PG.CreateButton(ieP, "Import", 90, 22, "green")
    btnImport:SetPoint("LEFT", btnExport, "RIGHT", 10, 0)

    local btnClear = PG.CreateButton(ieP, "Clear", 90, 22)
    btnClear:SetPoint("LEFT", btnImport, "RIGHT", 10, 0)

    btnExport:SetScript("OnClick", function()
        local mgr = _G["PrototypeASMR_SaveManager"]
        if not (mgr and mgr.Export) then
            PG.Print("Import/Export system not loaded.")
            return
        end

        local opts = {
            exportCustomSettings = UI.ieOptCustomSettings and UI.ieOptCustomSettings:GetChecked() or false,
            exportCustomOnMounts = UI.ieOptCustomOnMounts and UI.ieOptCustomOnMounts:GetChecked() or false,
            exportSoundIDs       = UI.ieOptSoundIDs and UI.ieOptSoundIDs:GetChecked() or false,
            base64 = true, -- always base64 (safe for copy/paste)
        }

        local encoded = mgr:Export(opts)
        if not encoded or encoded == "" then
            PG.Print("Export returned empty.")
            return
        end

        eb:SetText(encoded)
        eb:HighlightText()
        eb:SetFocus()
        PG.Print("Exported.")
    end)

    btnImport:SetScript("OnClick", function()
        local mgr = _G["PrototypeASMR_SaveManager"]
        if not (mgr and mgr.Import) then
            PG.Print("Import/Export system not loaded.")
            return
        end

        local msg = (eb:GetText() or ""):match("^%s*(.-)%s*$")
        if msg == "" then
            PG.Print("Box is empty.")
            return
        end

        local override = UI.ieOverride and UI.ieOverride:GetChecked()
        mgr:Import(msg, override)

        if PG.RefreshSoundList then PG.RefreshSoundList() end
        if UI.RefreshMountListTab then UI.RefreshMountListTab() end
        if UI.RefreshCustomSoundsTab then UI.RefreshCustomSoundsTab() end
        if PG.RefreshInfoTexts then PG.RefreshInfoTexts() end
    end)

    btnClear:SetScript("OnClick", function()
        eb:SetText("")
        eb:ClearFocus()
    end)

    return ieP
end

function PG.ResizeImportExportTab(frame)
    if not UI.iePanel then return end
    UI.iePanel:SetWidth(frame:GetWidth() - 24)
    UI.iePanel:SetHeight(frame:GetHeight() - 70 - 12)

    if UI.iePayloadBoxFrame and UI.iePayloadBoxFrame.editBox then
        UI.iePayloadBoxFrame:SetWidth(UI.iePanel:GetWidth() - 20)
        UI.iePayloadBoxFrame.editBox:SetWidth(UI.iePanel:GetWidth() - 20 - 40)
    end
end
