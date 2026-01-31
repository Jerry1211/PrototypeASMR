-- PrototypeGUI_Core.lua
-- Shared core for ProjectASMR Mount Sound Manager (Midnight)

local addonName = ...

-- Shared namespace for all GUI modules
PrototypeGUI = PrototypeGUI or {}
local PG = PrototypeGUI

-- SavedVariables root
PrototypeASMRDB = PrototypeASMRDB or {}

-- Runtime caches
PG.SpellToMountID = PG.SpellToMountID or {}       -- spellID -> mountID
PG.lastMountedMountID = PG.lastMountedMountID or nil

-- UI state container (created in Frame module)
PG.UI = PG.UI or {}

-- Theme (dark slate + mint accent)
PG.C = PG.C or {
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

-- ======================================================
-- Helpers / DB
-- ======================================================
function PG.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffPrototypeGUI:|r " .. tostring(msg))
end

function PG.EnsureDB()
    if type(PrototypeASMRDB) ~= "table" then PrototypeASMRDB = {} end
    if type(PrototypeASMRDB.mounts) ~= "table" then PrototypeASMRDB.mounts = {} end
    if PrototypeASMRDB.enabled == nil then PrototypeASMRDB.enabled = true end

    -- persistent GUI state
    PrototypeASMRDB.gui = PrototypeASMRDB.gui or {}
    local g = PrototypeASMRDB.gui
    if g.lastTab == nil then g.lastTab = "main" end
    if g.mlSelectedMount == nil then g.mlSelectedMount = nil end
    if g.mlFilter == nil then g.mlFilter = "" end
    if g.mainUseCurrent == nil then g.mainUseCurrent = true end
    if g.mainMountIDText == nil then g.mainMountIDText = "" end

    -- Custom Sounds (Custom Name -> filename)
    if type(PrototypeASMRDB.customSoundList) ~= "table" then PrototypeASMRDB.customSoundList = {} end
    if type(PrototypeASMRDB.customSoundMap) ~= "table" then PrototypeASMRDB.customSoundMap = {} end
end

function PG.ToNumberSafe(x)
    local n = tonumber(x)
    if not n or n ~= n then return nil end
    return n
end

function PG.Trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

-- ======================================================
-- Mount cache helpers
-- ======================================================
function PG.BuildSpellToMountCache()
    wipe(PG.SpellToMountID)

    if not C_MountJournal or not C_MountJournal.GetMountIDs or not C_MountJournal.GetMountInfoByID then
        return
    end

    local ids = C_MountJournal.GetMountIDs()
    if type(ids) ~= "table" then return end

    for _, mountID in ipairs(ids) do
        local _, spellID = C_MountJournal.GetMountInfoByID(mountID)
        if spellID and mountID then
            PG.SpellToMountID[spellID] = mountID
        end
    end
end

function PG.GetMountName(mountID)
    if C_MountJournal and C_MountJournal.GetMountInfoByID then
        local name = C_MountJournal.GetMountInfoByID(mountID)
        return name or "Unknown"
    end
    return "Unknown"
end

function PG.GetMountSpellID(mountID)
    if C_MountJournal and C_MountJournal.GetMountInfoByID then
        local _, spellID = C_MountJournal.GetMountInfoByID(mountID)
        return spellID
    end
    return nil
end

-- ======================================================
-- Mount -> Sound DB utilities
-- ======================================================
function PG.HasSound(mountID, soundID)
    local list = PrototypeASMRDB.mounts[mountID]
    if type(list) ~= "table" then return false end
    for i = 1, #list do
        if list[i] == soundID then return true end
    end
    return false
end

function PG.ParseSoundIDs(input)
    -- Returns a list of entries where each entry is either:
    --  * number (SoundKit ID)
    --  * string (Custom Sound Name key)
    local entries = {}
    local invalid = 0

    local raw = PG.Trim(tostring(input or ""))
    if raw == "" then
        return entries, invalid
    end

    for token in raw:gmatch("[^,]+") do
        token = PG.Trim(token)
        if token ~= "" then
            local sid = PG.ToNumberSafe(token)
            if sid then
                entries[#entries + 1] = sid
            else
                -- Allow custom names like "Cat-Meow"
                entries[#entries + 1] = token
            end
        else
            invalid = invalid + 1
        end
    end

    return entries, invalid
end

function PG.RebuildCustomSoundMap()
    PG.EnsureDB()
    PrototypeASMRDB.customSoundMap = {}

    local list = PrototypeASMRDB.customSoundList or {}
    for i = 1, #list do
        local row = list[i]
        local name = row and PG.Trim(row.name or "") or ""
        local file = row and PG.Trim(row.file or "") or ""
        if name ~= "" and file ~= "" then
            PrototypeASMRDB.customSoundMap[name] = file
        end
    end
end

function PG.AddSoundsFromInput(mountID, input)
    if not mountID then
        PG.Print("Missing mountID.")
        return
    end

    PG.EnsureDB()
    if type(PrototypeASMRDB.mounts[mountID]) ~= "table" then
        PrototypeASMRDB.mounts[mountID] = {}
    end

    local entries, invalid = PG.ParseSoundIDs(input)
    if #entries == 0 then
        PG.Print("Invalid entry.")
        return
    end

    local added, skipped = 0, 0
    for _, entry in ipairs(entries) do
        if PG.HasSound(mountID, entry) then
            skipped = skipped + 1
        else
            table.insert(PrototypeASMRDB.mounts[mountID], entry)
            added = added + 1
        end
    end

    if added > 0 then
        PG.Print("Added " .. added .. " sound(s) to MountID " .. mountID)
    end
    if skipped > 0 then
        PG.Print(skipped .. " sound(s) already existed and were skipped")
    end
    if invalid > 0 then
        PG.Print(invalid .. " invalid entr" .. (invalid == 1 and "y" or "ies") .. " ignored")
    end
end

function PG.RemoveSound(mountID, entry)
    local list = PrototypeASMRDB.mounts[mountID]
    if type(list) ~= "table" then
        PG.Print("No sounds for that mount.")
        return
    end
    for i = #list, 1, -1 do
        if list[i] == entry then
            table.remove(list, i)
            PG.Print("Removed " .. tostring(entry) .. " from MountID " .. mountID)
            if #list == 0 then
                PrototypeASMRDB.mounts[mountID] = nil
            end
            return
        end
    end
    PG.Print("Sound not found on that mount.")
end

function PG.ClearSounds(mountID)
    PrototypeASMRDB.mounts[mountID] = nil
    PG.Print("Cleared all sounds for MountID " .. mountID)
end

function PG.PlayEntry(entry)
    if entry == nil then return end

    PG.EnsureDB()
    PrototypeASMRDB.customSoundMap = PrototypeASMRDB.customSoundMap or {}
    local channel = (PrototypeASMRDB.channel or "SFX")

    -- numeric SoundKit ID
    if type(entry) == "number" then
        local willPlay = PlaySound(entry, channel)
        if willPlay == false then
            PG.Print("PlaySound failed for SoundKitID: " .. tostring(entry))
        end
        return
    end

    -- string (either "12345" or "Cat-Meow")
    if type(entry) == "string" then
        local trimmed = PG.Trim(entry)

        local asNum = tonumber(trimmed)
        if asNum then
            local willPlay = PlaySound(asNum, channel)
            if willPlay == false then
                PG.Print("PlaySound failed for SoundKitID: " .. tostring(asNum))
            end
            return
        end

        local file = PrototypeASMRDB.customSoundMap[trimmed]
        if not file or file == "" then
            PG.Print("Custom sound not found for: " .. trimmed .. " (add it in Custom Sounds tab)")
            return
        end

        -- ✅ Correct folder name (most reliable)
        local path = "Interface\\CustomSounds\\" .. file

        local willPlay, handle = PlaySoundFile(path, channel)
        if willPlay == false then
            PG.Print("PlaySoundFile failed: " .. path .. " (try .ogg, and confirm folder is Interface\\CustomSounds\\)")
        end
        return
    end
end

function PG.PlayRandomForMount(mountID)
    if not PrototypeASMRDB.enabled then
        PG.Print("Addon is OFF.")
        return
    end
    local list = PrototypeASMRDB.mounts[mountID]
    if type(list) ~= "table" or #list == 0 then
        PG.Print("No sounds configured for that mount.")
        return
    end
    PG.PlayEntry(list[math.random(#list)])
end

function PG.ResolveTargetMount(mountIDText, useCurrent)
    if useCurrent then
        if PG.lastMountedMountID and PG.lastMountedMountID > 0 then
            return PG.lastMountedMountID
        end
        return nil
    end

    local mid = PG.ToNumberSafe(PG.Trim(mountIDText))
    if not mid then
        return nil
    end
    return mid
end

-- ======================================================
-- Skin helpers
-- ======================================================
function PG.SafeClip(frame, on)
    if frame and frame.SetClipsChildren then
        frame:SetClipsChildren(on and true or false)
    end
end

function PG.CreateBackdrop(frame, bgColor, borderColor)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(bgColor or PG.C.bg))
    frame:SetBackdropBorderColor(unpack(borderColor or PG.C.borderDim))
end

function PG.SetBoundText(fs, parentPanel, padL, padR, text)
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

function PG.CreatePanel(parent, w, h, bg, border)
    local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    p:SetSize(w, h)
    PG.CreateBackdrop(p, bg or PG.C.bgLight, border or PG.C.borderDim)
    PG.SafeClip(p, true)
    return p
end

function PG.CreateLabel(parent, text, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text or "")
    fs:SetTextColor(unpack(color or PG.C.text))
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetMaxLines(1)
    if size then
        local font, _, flags = fs:GetFont()
        fs:SetFont(font, size, flags)
    end
    return fs
end

function PG.CreateSmallLabel(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetText(text or "")
    fs:SetTextColor(unpack(PG.C.textDim))
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetMaxLines(1)
    return fs
end

function PG.CreateButton(parent, text, w, h, kind)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)

    local borderColor =
        (kind == "danger") and PG.C.danger or
        (kind == "green")  and PG.C.green  or
        PG.C.borderDim

    PG.CreateBackdrop(b, PG.C.bgDark, borderColor)

    b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.txt:SetPoint("CENTER")
    b.txt:SetText(text or "")
    b.txt:SetTextColor(unpack(PG.C.text))

    b:SetScript("OnEnter", function(self)
        local hoverColor =
            (kind == "danger") and PG.C.danger or
            (kind == "green")  and PG.C.green  or
            PG.C.accent
        self:SetBackdropBorderColor(unpack(hoverColor))
    end)

    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(borderColor))
    end)

    return b
end

function PG.CreateEditBox(parent, w, h, placeholder)
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    eb:SetAutoFocus(false)
    eb:SetSize(w, h)
    PG.CreateBackdrop(eb, PG.C.bgDark, PG.C.borderDim)
    eb:SetTextInsets(8, 8, 0, 0)

    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetTextColor(unpack(PG.C.text))

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
        self:SetBackdropBorderColor(unpack(PG.C.accent))
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(unpack(PG.C.borderDim))
    end)

    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    return eb
end

function PG.CreateCheck(parent, text, onClick)
    local c = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    c.Text:SetText(text or "")
    c.Text:SetTextColor(unpack(PG.C.text))
    if onClick then c:SetScript("OnClick", onClick) end
    return c
end

function PG.CreateScrollEditBox(parent, w, h)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(w, h)
    PG.CreateBackdrop(box, PG.C.bgDark, PG.C.borderDim)
    PG.SafeClip(box, true)

    local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 6)

    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetTextColor(unpack(PG.C.text))
    eb:SetWidth(w - 40)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetTextInsets(8, 8, 8, 8)

    eb:SetScript("OnEditFocusGained", function()
        box:SetBackdropBorderColor(unpack(PG.C.accent))
    end)
    eb:SetScript("OnEditFocusLost", function()
        box:SetBackdropBorderColor(unpack(PG.C.borderDim))
    end)

    sf:SetScrollChild(eb)

    box.editBox = eb
    box.scrollFrame = sf

    return box, eb
end

-- ======================================================
-- Context menu helper
-- ======================================================
function PG.OpenContextMenu(anchorBtn, menuTable)
    if not anchorBtn or not menuTable then return end

    -- Preferred legacy path: EasyMenu (requires Blizzard_Deprecated in modern clients)
    if not EasyMenu then
        pcall(function() UIParentLoadAddOn("Blizzard_Deprecated") end)
    end

    if EasyMenu then
        if not _G["PrototypeASMR_ContextMenu"] then
            CreateFrame("Frame", "PrototypeASMR_ContextMenu", UIParent, "UIDropDownMenuTemplate")
        end
        local menuFrame = _G["PrototypeASMR_ContextMenu"]
        EasyMenu(menuTable, menuFrame, anchorBtn, 0, 0, "MENU", 2)
        return
    end

    -- Modern fallback (if available): MenuUtil
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchorBtn, function(owner, root)
            for _, item in ipairs(menuTable) do
                if item.isTitle then
                    root:CreateTitle(item.text or "")
                elseif item.func then
                    root:CreateButton(item.text or "Item", item.func)
                end
            end
        end)
        return
    end

    PG.Print("Context menu unavailable (EasyMenu/MenuUtil missing).")
end
