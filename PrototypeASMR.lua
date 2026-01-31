-- PrototypeASMR.lua
-- Runtime + event handling only (GUI-driven)

local f = CreateFrame("Frame")

-- ======================================================
-- SavedVariables
-- ======================================================
-- PrototypeASMRDB = {
--   enabled = true/false,
--   mounts = { [mountID] = { entries... } }
--   customSoundList = { {file="", name=""}, ... }
--   customSoundMap  = { ["Cat-Meow"]="cat.mp3", ... }
--   channel = "SFX"/"Master"/etc
-- }
PrototypeASMRDB = PrototypeASMRDB or {}

-- ======================================================
-- Runtime caches
-- ======================================================
local SpellToMountID = {}
local lastMountedMountID = nil

-- ======================================================
-- Utility
-- ======================================================
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffPrototypeASMR:|r " .. tostring(msg))
end

local function SeedRNG()
    local m = _G.math
    if not (m and m.random and m.randomseed) then return end
    m.randomseed(time())
    m.random(); m.random(); m.random()
end

local function EnsureDB()
    if type(PrototypeASMRDB) ~= "table" then PrototypeASMRDB = {} end
    if type(PrototypeASMRDB.mounts) ~= "table" then PrototypeASMRDB.mounts = {} end
    if PrototypeASMRDB.enabled == nil then PrototypeASMRDB.enabled = true end
    if type(PrototypeASMRDB.customSoundList) ~= "table" then PrototypeASMRDB.customSoundList = {} end
    if type(PrototypeASMRDB.customSoundMap) ~= "table" then PrototypeASMRDB.customSoundMap = {} end
    if type(PrototypeASMRDB.channel) ~= "string" or PrototypeASMRDB.channel == "" then
        PrototypeASMRDB.channel = "SFX"
    end
end

local function Trim(s)
    return (tostring(s or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

-- ======================================================
-- Custom Sound Map
-- ======================================================
local function RebuildCustomSoundMap()
    EnsureDB()
    PrototypeASMRDB.customSoundMap = {}

    for _, row in ipairs(PrototypeASMRDB.customSoundList) do
        local name = Trim(row.name)
        local file = Trim(row.file)
        if name ~= "" and file ~= "" then
            PrototypeASMRDB.customSoundMap[name] = file
        end
    end
end

-- ======================================================
-- Playback
-- ======================================================
local function PlayEntry(entry)
    EnsureDB()
    local channel = PrototypeASMRDB.channel or "SFX"

    if type(entry) == "number" then
        PlaySound(entry, channel)
        return
    end

    if type(entry) == "string" then
        local n = tonumber(entry)
        if n then
            PlaySound(n, channel)
            return
        end

        local file = PrototypeASMRDB.customSoundMap[entry]
        if file then
            PlaySoundFile("Interface\\CustomSounds\\" .. file, channel)
        end
    end
end

local function PlayRandomForMount(mountID)
    if not PrototypeASMRDB.enabled then return end

    local list = PrototypeASMRDB.mounts[mountID]
    if not list or #list == 0 then return end

    PlayEntry(list[math.random(#list)])
end

-- ======================================================
-- Mount Journal cache
-- ======================================================
local function BuildSpellToMountCache()
    wipe(SpellToMountID)

    if not C_MountJournal then return end
    for _, mountID in ipairs(C_MountJournal.GetMountIDs() or {}) do
        local _, spellID = C_MountJournal.GetMountInfoByID(mountID)
        if spellID then
            SpellToMountID[spellID] = mountID
        end
    end
end

-- ======================================================
-- Slash command: /asmr
-- ======================================================
SLASH_PROTOTYPEASMR1 = "/asmr"
SlashCmdList["PROTOTYPEASMR"] = function(msg)
    EnsureDB()

    msg = Trim(msg or ""):lower()

    -- /asmr on
    if msg == "on" then
        PrototypeASMRDB.enabled = true
        Print("Enabled.")
        return
    end

    -- /asmr off
    if msg == "off" then
        PrototypeASMRDB.enabled = false
        Print("Disabled.")
        return
    end

    -- /asmr  -> open GUI (same as old /asmrgui)
    if SlashCmdList["PROTOTYPEASMRGUI"] then
        SlashCmdList["PROTOTYPEASMRGUI"]()
    else
        Print("GUI not available.")
    end
end


-- ======================================================
-- Events
-- ======================================================
f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        SeedRNG()
        EnsureDB()
        RebuildCustomSoundMap()
        BuildSpellToMountCache()
        Print("Loaded. Type /asmr to open the GUI.")
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        BuildSpellToMountCache()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit ~= "player" then return end

        local mountID = SpellToMountID[spellID]
        if mountID then
            lastMountedMountID = mountID
            PlayRandomForMount(mountID)
        end
    end
end)

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
