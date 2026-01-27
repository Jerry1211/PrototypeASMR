-- PrototypeASMR.lua

local f = CreateFrame("Frame")

-- Prototype A.S.M.R. MountJournal mountID
local ASMR_MOUNT_ID = 2507

local soundIDs = {
    270277, 270278, 270279, 270280, 270281, 270282,
    270283, 270284, 270285, 270286, 270287, 270288,
    270289, 270290, 270291, 270292, 270293, 270294,
}

local asmrSpellID = nil

local function SeedRNG()
    math.randomseed(time())
    math.random(); math.random(); math.random()
end

local function CacheASMRSpellID()
    if not C_MountJournal or not C_MountJournal.GetMountInfoByID then return end
    local _, spellID = C_MountJournal.GetMountInfoByID(ASMR_MOUNT_ID)
    asmrSpellID = spellID
end

local function PlayRandomASMR()
    local soundID = soundIDs[math.random(#soundIDs)]
    PlaySound(soundID, "SFX")
end

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        SeedRNG()
        CacheASMRSpellID()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...

        if unit ~= "player" then return end
        if not asmrSpellID then
            CacheASMRSpellID()
            if not asmrSpellID then return end
        end

        -- Fires every time you mount Prototype A.S.M.R.
        if spellID == asmrSpellID then
            PlayRandomASMR()
        end
    end
end)

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

