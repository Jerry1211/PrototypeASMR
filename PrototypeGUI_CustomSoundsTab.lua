-- PrototypeGUI_CustomSoundsTab.lua
-- Custom Sounds tab:
--  - Map Custom Name -> filename in Interface\CustomSounds\
--  - Channel selector (SFX / Master / etc)
--  - Per-row Play + Delete

local addonName = ...
PrototypeGUI = PrototypeGUI or {}
local PG = PrototypeGUI

PG.UI = PG.UI or {}
local UI = PG.UI
local C  = PG.C

function PG.BuildCustomSoundsTab(frame)
    PG.EnsureDB()

    local csP = PG.CreatePanel(frame, frame:GetWidth() - 24, frame:GetHeight() - 70 - 12, C.bgLight, C.borderDim)
    csP:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -70)
    csP:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    csP:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.35)
    csP:Hide()
    UI.csPanel = csP

    -- Ensure dropdown API exists (Blizzard_Deprecated in modern clients)
    if not UIDropDownMenu_Initialize then
        pcall(function() UIParentLoadAddOn("Blizzard_Deprecated") end)
    end

    --------------------------------------------------
    -- Header
    --------------------------------------------------
    local title = PG.CreateLabel(csP, "Custom Sounds", 13, C.text)
    title:SetPoint("TOPLEFT", csP, "TOPLEFT", 10, -10)

    local hint = PG.CreateSmallLabel(csP, "Place .MP3 / .WAV / .OGG sounds into Interface\\CustomSounds\\")
    hint:SetPoint("TOPLEFT", csP, "TOPLEFT", 10, -30)

    local warn = PG.CreateSmallLabel(csP, "MAKE SURE TO RESTART THE GAME")
    warn:SetTextColor(0.95, 0.33, 0.33, 1)
    warn:SetPoint("LEFT", hint, "RIGHT", 8, 0)

    --------------------------------------------------
    -- Channel dropdown (top-right) + Add Row under it
    --------------------------------------------------
    local channelLabel = PG.CreateSmallLabel(csP, "Channel:")
    channelLabel:SetPoint("TOPRIGHT", csP, "TOPRIGHT", -140, -12)

    local ddChannel = CreateFrame("Frame", "PrototypeASMR_ChannelDropDown", csP, "UIDropDownMenuTemplate")
    ddChannel:SetPoint("LEFT", channelLabel, "RIGHT", -8, -3)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(ddChannel, 110)
    end

    local channels = { "SFX", "Master", "Music", "Ambience", "Dialog" }

    local function SetChannel(ch)
        PG.EnsureDB()
        PrototypeASMRDB.channel = ch
        if UIDropDownMenu_SetText then
            UIDropDownMenu_SetText(ddChannel, ch)
        end
    end

    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(ddChannel, function(self, level)
            local info = UIDropDownMenu_CreateInfo()
            for _, ch in ipairs(channels) do
                info.text = ch
                info.checked = (PrototypeASMRDB.channel == ch)
                info.func = function() SetChannel(ch) end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    end

    PrototypeASMRDB.channel = PrototypeASMRDB.channel or "Master"
    if UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(ddChannel, PrototypeASMRDB.channel)
    end

    -- Add Row button: under Channel dropdown, same column
    local addBtn = PG.CreateButton(csP, "Add Row", 90, 22, "green")
    addBtn:SetPoint("TOPRIGHT", csP, "TOPRIGHT", -10, -48)

    --------------------------------------------------
    -- Column headers
    --------------------------------------------------
    local colFile = PG.CreateSmallLabel(csP, "Filename (e.g. Pedro.wav)")
    colFile:SetPoint("TOPLEFT", csP, "TOPLEFT", 10, -54)

    local colName = PG.CreateSmallLabel(csP, "Custom Sound Name (e.g. Pedro)")
    colName:SetPoint("LEFT", colFile, "RIGHT", 240, 0)

    --------------------------------------------------
    -- Scroll area
    --------------------------------------------------
    local box = CreateFrame("Frame", nil, csP, "BackdropTemplate")
    box:SetPoint("TOPLEFT", csP, "TOPLEFT", 10, -74)
    box:SetPoint("BOTTOMRIGHT", csP, "BOTTOMRIGHT", -10, 10)
    PG.CreateBackdrop(box, C.bgDark, C.borderDim)
    PG.SafeClip(box, true)

    local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 6)

    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(1, 1)
    sf:SetScrollChild(content)

    UI._cs = UI._cs or {}
    UI._cs.rows = UI._cs.rows or {}
    UI._cs.content = content
    UI._cs.box = box
    UI._cs.scroll = sf

    --------------------------------------------------
    -- Row builder
    --------------------------------------------------
    local function EnsureRow(i)
        if UI._cs.rows[i] then return UI._cs.rows[i] end

        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(26)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * 28)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * 28)

        -- File box
        row.ebFile = PG.CreateEditBox(row, 220, 22)
        row.ebFile:SetPoint("LEFT", row, "LEFT", 0, 0)

        -- Name box (SHORTER like you asked)
        row.ebName = PG.CreateEditBox(row, 130, 22)
        row.ebName:SetPoint("LEFT", row.ebFile, "RIGHT", 10, 0)

        -- Play
        row.btnPlay = PG.CreateButton(row, "Play", 60, 22, "green")
        row.btnPlay:SetPoint("LEFT", row.ebName, "RIGHT", 10, 0)

        -- Delete (danger X button)
        row.btnDel = PG.CreateButton(row, "X", 22, 22, "danger")
        row.btnDel:SetPoint("LEFT", row.btnPlay, "RIGHT", 6, 0)

        -- Save handler (NOTE: uses current row index at time of save)
        local function Save()
            PG.EnsureDB()
            PrototypeASMRDB.customSoundList = PrototypeASMRDB.customSoundList or {}

            PrototypeASMRDB.customSoundList[i] = PrototypeASMRDB.customSoundList[i] or {}
            PrototypeASMRDB.customSoundList[i].file = PG.Trim(row.ebFile:GetText() or "")
            PrototypeASMRDB.customSoundList[i].name = PG.Trim(row.ebName:GetText() or "")

            if PG.RebuildCustomSoundMap then
                PG.RebuildCustomSoundMap()
            end
        end

        row.ebFile:SetScript("OnEditFocusLost", Save)
        row.ebName:SetScript("OnEditFocusLost", Save)
        row.ebFile:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        row.ebName:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

        row.btnPlay:SetScript("OnClick", function()
            local name = PG.Trim(row.ebName:GetText() or "")
            if name ~= "" then
                if PG.PlayEntry then
                    PG.PlayEntry(name)
                end
            end
        end)

        row.btnDel:SetScript("OnClick", function()
            PG.EnsureDB()
            PrototypeASMRDB.customSoundList = PrototypeASMRDB.customSoundList or {}

            -- delete row i and refresh
            table.remove(PrototypeASMRDB.customSoundList, i)

            if PG.RebuildCustomSoundMap then
                PG.RebuildCustomSoundMap()
            end

            if UI.RefreshCustomSoundsTab then
                UI.RefreshCustomSoundsTab()
            end
        end)

        UI._cs.rows[i] = row
        return row
    end

    --------------------------------------------------
    -- Refresh
    --------------------------------------------------
    function UI.RefreshCustomSoundsTab()
        PG.EnsureDB()
        PrototypeASMRDB.customSoundList = PrototypeASMRDB.customSoundList or {}

        if #PrototypeASMRDB.customSoundList == 0 then
            PrototypeASMRDB.customSoundList[1] = { file = "", name = "" }
        end

        -- keep dropdown text synced
        if UIDropDownMenu_SetText and ddChannel then
            UIDropDownMenu_SetText(ddChannel, PrototypeASMRDB.channel or "Master")
        end

        for i = 1, #PrototypeASMRDB.customSoundList do
            local row = EnsureRow(i)
            row:Show()

            local data = PrototypeASMRDB.customSoundList[i] or {}
            row.ebFile:SetText(data.file or "")
            row.ebName:SetText(data.name or "")
        end

        for i = #PrototypeASMRDB.customSoundList + 1, #UI._cs.rows do
            if UI._cs.rows[i] then
                UI._cs.rows[i]:Hide()
            end
        end

        content:SetHeight(#PrototypeASMRDB.customSoundList * 28)

        if PG.RebuildCustomSoundMap then
            PG.RebuildCustomSoundMap()
        end
    end

    addBtn:SetScript("OnClick", function()
        PG.EnsureDB()
        PrototypeASMRDB.customSoundList = PrototypeASMRDB.customSoundList or {}

        table.insert(PrototypeASMRDB.customSoundList, { file = "", name = "" })

        if UI.RefreshCustomSoundsTab then
            UI.RefreshCustomSoundsTab()
        end
    end)

    UI.RefreshCustomSoundsTab()
    return csP
end
