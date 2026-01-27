-- PrototypeASMR.lua

local f = CreateFrame("Frame")

-- ======================================================
-- HARDCODED: Prototype A.S.M.R. defaults (hidden command)
-- ======================================================
local ASMR_MOUNT_ID = 2507

local ASMR_DEFAULT_SOUNDS = {
    270277, 270278, 270279, 270280, 270281, 270282,
    270283, 270284, 270285, 270286, 270287, 270288,
    270289, 270290, 270291, 270292, 270293, 270294,
}

-- ======================================================
-- SavedVariables
-- ======================================================
-- PrototypeASMRDB = {
--   enabled = true/false,
--   mounts = { [mountID] = { soundIDs... } }
-- }
PrototypeASMRDB = PrototypeASMRDB or nil

-- ======================================================
-- Runtime caches
-- ======================================================
local SpellToMountID = {}       -- spellID -> mountID
local lastMountedMountID = nil  -- last mount detected via spellcast

-- ======================================================
-- Utility
-- ======================================================
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffPrototypeASMR:|r " .. tostring(msg))
end

local function SeedRNG()
    math.randomseed(time())
    math.random(); math.random(); math.random()
end

local function EnsureDB()
    if type(PrototypeASMRDB) ~= "table" then
        PrototypeASMRDB = {}
    end
    if type(PrototypeASMRDB.mounts) ~= "table" then
        PrototypeASMRDB.mounts = {}
    end
    if PrototypeASMRDB.enabled == nil then
        PrototypeASMRDB.enabled = true
    end
end

local function ToNumberSafe(x)
    local n = tonumber(x)
    if not n or n ~= n then return nil end
    return n
end

-- ======================================================
-- Mount Journal cache: spellID -> mountID
-- ======================================================
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

-- ======================================================
-- Sound list helpers (DB-backed)
-- ======================================================
local function GetMountSoundList(mountID)
    EnsureDB()
    local t = PrototypeASMRDB.mounts[mountID]
    if type(t) ~= "table" then return nil end
    return t
end

local function HasSound(mountID, soundID)
    local list = GetMountSoundList(mountID)
    if not list then return false end
    for i = 1, #list do
        if list[i] == soundID then
            return true
        end
    end
    return false
end

local function AddSound(mountID, soundID)
    if not mountID or not soundID then
        Print("Usage: /asmr addsound <MountID|current> <SoundID>")
        return
    end

    EnsureDB()
    if type(PrototypeASMRDB.mounts[mountID]) ~= "table" then
        PrototypeASMRDB.mounts[mountID] = {}
    end

    if HasSound(mountID, soundID) then
        Print("SoundID " .. soundID .. " already exists for MountID " .. mountID)
        return
    end

    table.insert(PrototypeASMRDB.mounts[mountID], soundID)
    Print("Added SoundID " .. soundID .. " to MountID " .. mountID)
end

local function RemoveSound(mountID, soundID)
    if not mountID or not soundID then
        Print("Usage: /asmr removesound <MountID|current> <SoundID>")
        return
    end

    local list = GetMountSoundList(mountID)
    if not list then
        Print("No sounds found for MountID " .. mountID)
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

    Print("SoundID " .. soundID .. " not found for MountID " .. mountID)
end

local function ClearSounds(mountID)
    if not mountID then
        Print("Usage: /asmr clearsounds <MountID|current>")
        return
    end
    EnsureDB()
    PrototypeASMRDB.mounts[mountID] = nil
    Print("Cleared all sounds for MountID " .. mountID)
end

local function ListSoundsForMount(mountID)
    if not mountID then
        Print("Usage: /asmr listsounds <MountID|current>")
        return
    end

    EnsureDB()
    local list = GetMountSoundList(mountID)
    if not list or #list == 0 then
        Print("No sounds configured for MountID " .. mountID)
        return
    end

    local name = "Unknown"
    if C_MountJournal and C_MountJournal.GetMountInfoByID then
        local mountName = C_MountJournal.GetMountInfoByID(mountID)
        if mountName and mountName ~= "" then name = mountName end
    end

    local out = {}
    for i = 1, #list do out[#out+1] = tostring(list[i]) end
    Print("MountID " .. mountID .. " (" .. name .. "): " .. table.concat(out, ", "))
end

local function PlayRandomForMount(mountID)
    if not PrototypeASMRDB.enabled then return end
    local list = GetMountSoundList(mountID)
    if not list or #list == 0 then return end
    local soundID = list[math.random(#list)]
    PlaySound(soundID, "SFX")
end

local function PlaySoundByID(soundID)
    if not soundID then
        Print("Usage: /asmr playsound <SoundID>")
        return
    end
    Print("Playing SoundID " .. soundID)
    PlaySound(soundID, "SFX")
end

-- ======================================================
-- Hidden: /asmr prototypeasmr (seed defaults into DB)
-- ======================================================
local function AddPrototypeASMRDefaults()
    EnsureDB()

    if type(PrototypeASMRDB.mounts[ASMR_MOUNT_ID]) ~= "table" then
        PrototypeASMRDB.mounts[ASMR_MOUNT_ID] = {}
    end

    local existing = {}
    for _, sid in ipairs(PrototypeASMRDB.mounts[ASMR_MOUNT_ID]) do
        existing[sid] = true
    end

    local added = 0
    for _, sid in ipairs(ASMR_DEFAULT_SOUNDS) do
        if not existing[sid] then
            table.insert(PrototypeASMRDB.mounts[ASMR_MOUNT_ID], sid)
            existing[sid] = true
            added = added + 1
        end
    end

    Print("Prototype A.S.M.R. defaults applied (added " .. added .. ").")
end

-- ======================================================
-- "current" mount resolution
-- Uses lastMountedMountID set when mount spell succeeds.
-- Fallback: if currently mounted and our cache is built, attempt aura-less mapping via mount spell not available,
-- so we keep it simple: if lastMountedMountID nil, tell user to mount once.
-- ======================================================
local function GetCurrentMountIDForCommands()
    if lastMountedMountID and lastMountedMountID > 0 then
        return lastMountedMountID
    end
    if IsMounted and IsMounted() then
        Print("Mount detected but mount ID not cached yet. Mount once to register it, then try again.")
    else
        Print("You are not mounted.")
    end
    return nil
end

-- ======================================================
-- Help
-- ======================================================
local function ShowHelp()
    Print("Commands:")
    Print("/asmr on | off")
    Print("/asmr getid  (prints currently mounted mount ID)")
    Print("/asmr playsound <SoundID>")
    Print("/asmr testsound")
    Print("/asmr addsound <MountID> <SoundID>")
    Print("/asmr removesound <MountID> <SoundID>")
    Print("/asmr clearsounds <MountID|current>")
    Print("/asmr listsounds <MountID|current>")
    Print("/asmr addsound current <SoundID>")
    Print("/asmr removesound current <SoundID>")
end

-- ======================================================
-- Slash commands
-- ======================================================
SLASH_PROTOTYPEASMR1 = "/asmr"
SlashCmdList["PROTOTYPEASMR"] = function(msg)
    EnsureDB()

    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    if not cmd then ShowHelp() return end
    cmd = (cmd or ""):lower()
    rest = rest or ""

    if cmd == "on" then
        PrototypeASMRDB.enabled = true
        Print("Enabled.")
        return

    elseif cmd == "off" then
        PrototypeASMRDB.enabled = false
        Print("Disabled.")
        return

    elseif cmd == "getid" then
        local mid = GetCurrentMountIDForCommands()
        if not mid then return end
        local name, spellID = nil, nil
        if C_MountJournal and C_MountJournal.GetMountInfoByID then
            name, spellID = C_MountJournal.GetMountInfoByID(mid)
        end
        Print("Mounted: " .. (name or "Unknown") .. " | MountID " .. mid .. " | SpellID " .. (spellID or "nil"))
        return

    elseif cmd == "playsound" then
        PlaySoundByID(ToNumberSafe(rest))
        return

    elseif cmd == "testsound" then
        local mid = GetCurrentMountIDForCommands()
        if not mid then return end
        local list = GetMountSoundList(mid)
        if not list or #list == 0 then
            Print("No sounds configured for MountID " .. mid)
            return
        end
        PlayRandomForMount(mid)
        return

    elseif cmd == "listsounds" then
        if rest:lower() == "current" then
            local mid = GetCurrentMountIDForCommands()
            if not mid then return end
            ListSoundsForMount(mid)
        else
            ListSoundsForMount(ToNumberSafe(rest))
        end
        return

    elseif cmd == "clearsounds" then
        if rest:lower() == "current" then
            local mid = GetCurrentMountIDForCommands()
            if not mid then return end
            ClearSounds(mid)
        else
            ClearSounds(ToNumberSafe(rest))
        end
        return

    elseif cmd == "addsound" then
        local a, b = rest:match("^(%S+)%s+(%S+)$")
        if not a then
            Print("Usage: /asmr addsound <MountID|current> <SoundID>")
            return
        end

        if a:lower() == "current" then
            local mid = GetCurrentMountIDForCommands()
            if not mid then return end
            AddSound(mid, ToNumberSafe(b))
        else
            AddSound(ToNumberSafe(a), ToNumberSafe(b))
        end
        return

    elseif cmd == "removesound" then
        local a, b = rest:match("^(%S+)%s+(%S+)$")
        if not a then
            Print("Usage: /asmr removesound <MountID|current> <SoundID>")
            return
        end

        if a:lower() == "current" then
            local mid = GetCurrentMountIDForCommands()
            if not mid then return end
            RemoveSound(mid, ToNumberSafe(b))
        else
            RemoveSound(ToNumberSafe(a), ToNumberSafe(b))
        end
        return

    elseif cmd == "prototypeasmr" then
        AddPrototypeASMRDefaults()
        return

    else
        ShowHelp()
        return
    end
end

-- ======================================================
-- Events
-- ======================================================
f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        SeedRNG()
        EnsureDB()
        BuildSpellToMountCache()
        Print("Loaded. " .. (PrototypeASMRDB.enabled and "Enabled" or "Disabled") .. ". Type /asmr for help.")
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- Safe refresh in case MountJournal data wasn't ready at login
        BuildSpellToMountCache()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...

        if unit ~= "player" then return end
        if not spellID then return end

        -- Translate mount spell -> mountID (this is the reliable "mount happened" trigger)
        local mountID = SpellToMountID[spellID]
        if mountID then
            lastMountedMountID = mountID
            if PrototypeASMRDB.enabled then
                PlayRandomForMount(mountID)
            end
        end
    end
end)

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
