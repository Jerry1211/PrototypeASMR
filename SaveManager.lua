-- SaveManager.lua
-- Import / Export core for PrototypeASMR + DEBUG
-- No separate GUI (PrototypeGUI hosts the Import/Export tab)
-- Requires: LibSerialize, LibDeflate

local SM = CreateFrame("Frame", "PrototypeASMR_SaveManager")

local LibSerialize = LibStub("LibSerialize")
local LibDeflate   = LibStub("LibDeflate")

local DEBUG = false

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffPrototypeASMR:|r " .. tostring(msg))
end

local function DPrint(msg)
    if DEBUG then
        Print("|cffffcc00[DEBUG]|r " .. tostring(msg))
    end
end

local function EnsureDB()
    PrototypeASMRDB = PrototypeASMRDB or {}
    PrototypeASMRDB.mounts = PrototypeASMRDB.mounts or {}
    if PrototypeASMRDB.enabled == nil then PrototypeASMRDB.enabled = true end
end

local function DeepCopy(tbl)
    if type(tbl) ~= "table" then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

local function CountMountsAndSounds()
    local mounts = PrototypeASMRDB and PrototypeASMRDB.mounts
    if type(mounts) ~= "table" then return 0, 0 end
    local mCount, sCount = 0, 0
    for _, sounds in pairs(mounts) do
        mCount = mCount + 1
        if type(sounds) == "table" then
            for _ in ipairs(sounds) do
                sCount = sCount + 1
            end
        end
    end
    return mCount, sCount
end

local function SafeCall(label, fn)
    local ok, a, b, c = pcall(fn)
    if not ok then
        Print("|cffff3333ERROR|r " .. label .. " failed: " .. tostring(a))
        return nil
    end
    return a, b, c
end

-- ======================================================
-- Export / Import
-- ======================================================
function SM:Export()
    EnsureDB()

    local mCount, sCount = CountMountsAndSounds()
    DPrint("Export: enabled=" .. tostring(PrototypeASMRDB.enabled) .. " mounts=" .. mCount .. " sounds=" .. sCount)

    local payload = {
        enabled = PrototypeASMRDB.enabled,
        mounts  = PrototypeASMRDB.mounts,
    }

    local serialized = SafeCall("Serialize", function()
        return LibSerialize:Serialize(payload)
    end)
    if not serialized or serialized == "" then
        Print("Export failed: Serialize returned empty.")
        return nil
    end
    DPrint("Serialize length: " .. #serialized)

    local compressed = SafeCall("CompressDeflate", function()
        return LibDeflate:CompressDeflate(serialized)
    end)
    if not compressed then
        Print("Export failed: CompressDeflate returned nil.")
        return nil
    end
    DPrint("Compressed length: " .. #compressed)

    local encoded = SafeCall("EncodeForPrint", function()
        return LibDeflate:EncodeForPrint(compressed)
    end)
    if not encoded or encoded == "" then
        Print("Export failed: EncodeForPrint returned empty.")
        return nil
    end
    DPrint("Encoded length: " .. #encoded)

    return encoded
end

function SM:Import(encodedString, override)
    EnsureDB()

    if type(encodedString) ~= "string" or encodedString == "" then
        Print("Import failed: empty string.")
        return
    end

    DPrint("Import string length: " .. #encodedString)

    local decoded = SafeCall("DecodeForPrint", function()
        return LibDeflate:DecodeForPrint(encodedString)
    end)
    if not decoded then
        Print("Import failed: DecodeForPrint returned nil.")
        return
    end
    DPrint("Decoded length: " .. #decoded)

    local inflated = SafeCall("DecompressDeflate", function()
        return LibDeflate:DecompressDeflate(decoded)
    end)
    if not inflated then
        Print("Import failed: DecompressDeflate returned nil.")
        return
    end
    DPrint("Inflated length: " .. #inflated)

    local ok, data = SafeCall("Deserialize", function()
        return LibSerialize:Deserialize(inflated)
    end)
    if not ok or type(data) ~= "table" then
        Print("Import failed: Deserialize not ok or not table.")
        return
    end

    DPrint("Import parsed: enabled=" .. tostring(data.enabled) .. " mounts=" .. tostring(type(data.mounts)))

    if override then
        PrototypeASMRDB.enabled = data.enabled ~= false
        PrototypeASMRDB.mounts  = DeepCopy(data.mounts or {})
        Print("Imported (override).")
        return
    end

    -- merge (dedupe)
    if type(data.mounts) == "table" then
        for mountID, sounds in pairs(data.mounts) do
            mountID = tonumber(mountID)
            if mountID then
                PrototypeASMRDB.mounts[mountID] = PrototypeASMRDB.mounts[mountID] or {}

                local existing = {}
                for _, sid in ipairs(PrototypeASMRDB.mounts[mountID]) do
                    existing[sid] = true
                end

                if type(sounds) == "table" then
                    for _, sid in ipairs(sounds) do
                        if not existing[sid] then
                            table.insert(PrototypeASMRDB.mounts[mountID], sid)
                            existing[sid] = true
                        end
                    end
                end
            end
        end
    end

    Print("Imported (merge).")
end

-- ======================================================
-- Chat export (split so it won't truncate)
-- ======================================================
local function PrintLongToChat(prefix, str)
    if type(str) ~= "string" or str == "" then return end
    local chunkSize = 230
    local i = 1
    local n = #str
    local part = 1
    while i <= n do
        local chunk = str:sub(i, i + chunkSize - 1)
        DEFAULT_CHAT_FRAME:AddMessage(
            ("|cff66ccffPrototypeASMR:|r %s (%d) %s"):format(prefix, part, chunk)
        )
        i = i + chunkSize
        part = part + 1
    end
end

-- ======================================================
-- Slash commands
-- ======================================================
SLASH_PROTOTYPEASMR_EXPORT1 = "/asmrexport"
SlashCmdList["PROTOTYPEASMR_EXPORT"] = function()
    local encoded = SM:Export()
    if not encoded or encoded == "" then
        Print("Export returned empty.")
        return
    end
    Print("Export string (split):")
    PrintLongToChat("EXPORT", encoded)
end

SLASH_PROTOTYPEASMR_IMPORT1 = "/asmrimport"
SlashCmdList["PROTOTYPEASMR_IMPORT"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    if msg == "" then
        Print("Usage: /asmrimport <string>")
        return
    end
    SM:Import(msg, false) -- default merge
end

SLASH_PROTOTYPEASMR_DEBUG1 = "/asmrdebug"
SlashCmdList["PROTOTYPEASMR_DEBUG"] = function()
    DEBUG = not DEBUG
    Print("Debug " .. (DEBUG and "ON" or "OFF"))
end
