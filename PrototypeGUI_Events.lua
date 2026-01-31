-- PrototypeGUI_Events.lua
-- Tracks current mounted mountID based on spellcasts

local addonName = ...
PrototypeGUI = PrototypeGUI or {}
local PG = PrototypeGUI

local f = CreateFrame("Frame")

f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        PG.EnsureDB()
        PG.BuildSpellToMountCache()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        PG.BuildSpellToMountCache()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit ~= "player" then return end
        if not spellID then return end

        local mountID = PG.SpellToMountID[spellID]
        if mountID then
            PG.lastMountedMountID = mountID

            if PG.UI.frame and PG.UI.frame:IsShown() then
                if PG.RefreshInfoTexts then PG.RefreshInfoTexts() end

                if PG.UI.chkUseCurrent and PG.UI.chkUseCurrent:GetChecked() then
                    if PG.RefreshSoundList then PG.RefreshSoundList() end
                end

                if PG.UI.activeTab == "ml" and PG.RefreshMountListTab then
                    PG.RefreshMountListTab()
                end
            end
        end
    end
end)

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
