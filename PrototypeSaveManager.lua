-- PrototypeSaveManager.lua
-- Import/Export for PrototypeASMRDB:
--  - Custom Sound Settings (customSoundList + channel)
--  - Mount sounds: numeric SoundKit IDs and/or custom-name strings
--  - Self-contained (no Ace libs)
--  - Optional base64 wrapper (PA3B64:)

local addonName = ...

PrototypeASMR_SaveManager = PrototypeASMR_SaveManager or {}
local M = PrototypeASMR_SaveManager

-- =========================
-- Utilities
-- =========================
local function ToNumberSafe(x)
    local n = tonumber(x)
    if not n or n ~= n then return nil end
    return n
end

local function Trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function EnsureDB()
    if type(PrototypeASMRDB) ~= "table" then PrototypeASMRDB = {} end
    if type(PrototypeASMRDB.mounts) ~= "table" then PrototypeASMRDB.mounts = {} end
    if type(PrototypeASMRDB.customSoundList) ~= "table" then PrototypeASMRDB.customSoundList = {} end
    if type(PrototypeASMRDB.customSoundMap) ~= "table" then PrototypeASMRDB.customSoundMap = {} end
    if type(PrototypeASMRDB.channel) ~= "string" or PrototypeASMRDB.channel == "" then
        PrototypeASMRDB.channel = "SFX"
    end
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffPrototypeGUI:|r " .. tostring(msg))
end

-- Percent encode for safe inline payloads
local function PercentEncode(s)
    s = tostring(s or "")
    s = s:gsub("%%", "%%25")
    s = s:gsub("%|", "%%7C")
    s = s:gsub(";", "%%3B")
    s = s:gsub(",", "%%2C")
    s = s:gsub("=", "%%3D")
    s = s:gsub(":", "%%3A")
    return s
end

local function PercentDecode(s)
    s = tostring(s or "")
    s = s:gsub("%%3A", ":")
    s = s:gsub("%%3D", "=")
    s = s:gsub("%%2C", ",")
    s = s:gsub("%%3B", ";")
    s = s:gsub("%%7C", "|")
    s = s:gsub("%%25", "%%")
    return s
end

-- Entry encoding:
--  number -> "123"
--  string -> "@<percent-encoded>"
local function EncodeEntry(v)
    if type(v) == "number" then
        return tostring(v)
    elseif type(v) == "string" then
        return "@" .. PercentEncode(v)
    end
    return ""
end

local function DecodeEntry(token)
    token = Trim(token)
    if token == "" then return nil end
    if token:sub(1, 1) == "@" then
        return PercentDecode(token:sub(2))
    end
    local n = ToNumberSafe(token)
    if n then return n end
    -- allow raw names
    return token
end

local function IsCustomName(v) return type(v) == "string" end
local function IsSoundID(v) return type(v) == "number" end

local function DedupePreserveSorted(list)
    if type(list) ~= "table" then return {} end
    local seen, out = {}, {}
    for i = 1, #list do
        local v = list[i]
        local key = type(v) .. ":" .. tostring(v)
        if v ~= nil and not seen[key] then
            seen[key] = true
            out[#out + 1] = v
        end
    end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
end

-- =========================
-- Base64 (self-contained)
-- =========================
local _b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function Base64Encode(data)
    data = tostring(data or "")
    local bytes = { data:byte(1, #data) }
    local out = {}

    local i = 1
    while i <= #bytes do
        local b1 = bytes[i] or 0
        local b2 = bytes[i + 1] or 0
        local b3 = bytes[i + 2] or 0

        local pad = 0
        if i + 1 > #bytes then pad = 2
        elseif i + 2 > #bytes then pad = 1 end

        local n = b1 * 65536 + b2 * 256 + b3

        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64

        out[#out + 1] = _b64chars:sub(c1 + 1, c1 + 1)
        out[#out + 1] = _b64chars:sub(c2 + 1, c2 + 1)

        if pad == 2 then
            out[#out + 1] = "="
            out[#out + 1] = "="
        elseif pad == 1 then
            out[#out + 1] = _b64chars:sub(c3 + 1, c3 + 1)
            out[#out + 1] = "="
        else
            out[#out + 1] = _b64chars:sub(c3 + 1, c3 + 1)
            out[#out + 1] = _b64chars:sub(c4 + 1, c4 + 1)
        end

        i = i + 3
    end

    return table.concat(out)
end

local function Base64Decode(b64)
    b64 = tostring(b64 or ""):gsub("%s+", "")
    local inv = {}
    for i = 1, #_b64chars do
        inv[_b64chars:sub(i, i)] = i - 1
    end

    local out = {}
    local i = 1
    while i <= #b64 do
        local c1 = b64:sub(i, i); i = i + 1
        local c2 = b64:sub(i, i); i = i + 1
        local c3 = b64:sub(i, i); i = i + 1
        local c4 = b64:sub(i, i); i = i + 1

        if c1 == "" or c2 == "" then break end

        local v1 = inv[c1]; local v2 = inv[c2]
        local v3 = (c3 == "=") and nil or inv[c3]
        local v4 = (c4 == "=") and nil or inv[c4]

        if v1 == nil or v2 == nil then break end

        local n = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)

        local b1 = math.floor(n / 65536) % 256
        local b2 = math.floor(n / 256) % 256
        local b3 = n % 256

        out[#out + 1] = string.char(b1)
        if c3 ~= "=" then out[#out + 1] = string.char(b2) end
        if c4 ~= "=" then out[#out + 1] = string.char(b3) end
    end

    return table.concat(out)
end

-- =========================
-- Encoding format (raw, before optional b64 wrapper)
-- =========================
-- PA3:ch=<channel>|cs=<name=file;name=file>|m=<mid=entry,entry;mid=entry,entry>
-- entry: number or @encodedString

local function EncodeCustomSoundList(list)
    list = list or {}
    local parts = {}
    for i = 1, #list do
        local row = list[i]
        local name = row and Trim(row.name or "") or ""
        local file = row and Trim(row.file or "") or ""
        if name ~= "" and file ~= "" then
            parts[#parts + 1] = PercentEncode(name) .. "=" .. PercentEncode(file)
        end
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

local function DecodeCustomSoundList(csStr)
    csStr = Trim(csStr or "")
    local out = {}
    if csStr == "" then return out end

    for pair in csStr:gmatch("[^;]+") do
        local nEnc, fEnc = pair:match("^(.-)%=(.-)$")
        if nEnc and fEnc then
            local n = Trim(PercentDecode(nEnc))
            local f = Trim(PercentDecode(fEnc))
            if n ~= "" and f ~= "" then
                out[#out + 1] = { name = n, file = f }
            end
        end
    end

    table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return out
end

local function BuildMountsPayload(opts)
    opts = opts or {}
    local exportSoundIDs = (opts.exportSoundIDs ~= false)         -- default true
    local exportCustomOnMounts = (opts.exportCustomOnMounts ~= false) -- default true

    local parts = {}

    for mountID, sounds in pairs(PrototypeASMRDB.mounts or {}) do
        local mid = ToNumberSafe(mountID)
        if mid and type(sounds) == "table" and #sounds > 0 then
            local filtered = {}
            for i = 1, #sounds do
                local v = sounds[i]
                if (exportSoundIDs and IsSoundID(v)) or (exportCustomOnMounts and IsCustomName(v)) then
                    filtered[#filtered + 1] = v
                end
            end

            filtered = DedupePreserveSorted(filtered)
            if #filtered > 0 then
                local enc = {}
                for i = 1, #filtered do
                    enc[#enc + 1] = EncodeEntry(filtered[i])
                end
                parts[#parts + 1] = tostring(mid) .. "=" .. table.concat(enc, ",")
            end
        end
    end

    table.sort(parts)
    return table.concat(parts, ";")
end

local function ParseRawPA3(raw)
    raw = Trim(raw or "")
    raw = raw:gsub("%s+", "")

    if raw:sub(1, 4) ~= "PA3:" then
        return nil, "Invalid payload (missing PA3: prefix)."
    end

    local body = raw:sub(5)
    local map = {}
    for chunk in body:gmatch("[^|]+") do
        local k, v = chunk:match("^(.-)%=(.*)$")
        if k and v then map[k] = v end
    end

    -- channel
    local ch = map["ch"] and PercentDecode(map["ch"]) or nil

    -- custom sound list
    local csList = nil
    if map["cs"] then csList = DecodeCustomSoundList(map["cs"]) end

    -- mounts
    local mounts = {}
    if map["m"] and map["m"] ~= "" then
        for pair in map["m"]:gmatch("[^;]+") do
            local midStr, entriesStr = pair:match("^(%d+)%=(.+)$")
            if midStr and entriesStr then
                local mid = ToNumberSafe(midStr)
                if mid then
                    local entries = {}
                    for token in entriesStr:gmatch("[^,]+") do
                        local entry = DecodeEntry(token)
                        if entry ~= nil then entries[#entries + 1] = entry end
                    end
                    mounts[mid] = DedupePreserveSorted(entries)
                end
            end
        end
    end

    return {
        channel = ch,
        customSoundList = csList,
        mounts = mounts,
    }
end

-- =========================
-- Public API
-- =========================

-- opts:
--  exportCustomSettings (customSoundList + channel) default true
--  exportCustomOnMounts default true
--  exportSoundIDs default true
--  base64 default true (exports PA3B64:)
function M:Export(opts)
    EnsureDB()
    opts = opts or {}

    local exportCustomSettings = (opts.exportCustomSettings ~= false)
    local base64 = (opts.base64 ~= false)

    local chPart = ""
    local csPart = ""

    if exportCustomSettings then
        chPart = "ch=" .. PercentEncode(PrototypeASMRDB.channel or "SFX")
        csPart = "cs=" .. EncodeCustomSoundList(PrototypeASMRDB.customSoundList or {})
    else
        -- still include placeholders so import parser is stable
        chPart = "ch="
        csPart = "cs="
    end

    local mPart = "m=" .. BuildMountsPayload(opts)

    local raw = "PA3:" .. chPart .. "|" .. csPart .. "|" .. mPart

    if base64 then
        return "PA3B64:" .. Base64Encode(raw)
    end
    return raw
end

-- override: if true, replace mounts/customSoundList/channel depending on what payload contains
function M:Import(payload, override)
    EnsureDB()

    payload = Trim(payload or "")
    if payload == "" then
        Print("Import failed: empty payload.")
        return false
    end

    local raw = payload
    if payload:sub(1, 7) == "PA3B64:" then
        local b64 = payload:sub(8)
        raw = Base64Decode(b64 or "")
        raw = Trim(raw or "")
        if raw == "" then
            Print("Import failed: bad base64 payload.")
            return false
        end
    end

    local parsed, err = ParseRawPA3(raw)
    if not parsed then
        Print(err or "Import failed.")
        return false
    end

    if override then
        if parsed.mounts then PrototypeASMRDB.mounts = {} end
        if parsed.customSoundList then PrototypeASMRDB.customSoundList = {} end
    end

    -- Channel + CustomSoundList
    if parsed.channel and parsed.channel ~= "" then
        PrototypeASMRDB.channel = parsed.channel
    end

    if type(parsed.customSoundList) == "table" then
        if override then
            PrototypeASMRDB.customSoundList = parsed.customSoundList
        else
            -- merge by name
            local byName = {}
            PrototypeASMRDB.customSoundList = PrototypeASMRDB.customSoundList or {}
            for _, row in ipairs(PrototypeASMRDB.customSoundList) do
                local n = Trim(row.name or "")
                local f = Trim(row.file or "")
                if n ~= "" and f ~= "" then byName[n] = f end
            end
            for _, row in ipairs(parsed.customSoundList) do
                local n = Trim(row.name or "")
                local f = Trim(row.file or "")
                if n ~= "" and f ~= "" then byName[n] = f end
            end
            local merged = {}
            for n, f in pairs(byName) do
                merged[#merged + 1] = { name = n, file = f }
            end
            table.sort(merged, function(a, b) return tostring(a.name) < tostring(b.name) end)
            PrototypeASMRDB.customSoundList = merged
        end
    end

    -- Mounts merge
    if type(parsed.mounts) == "table" then
        for mid, sounds in pairs(parsed.mounts) do
            if type(sounds) == "table" and #sounds > 0 then
                if type(PrototypeASMRDB.mounts[mid]) ~= "table" then
                    PrototypeASMRDB.mounts[mid] = {}
                end
                local merged = {}
                for _, v in ipairs(PrototypeASMRDB.mounts[mid]) do
                    if v ~= nil then merged[#merged + 1] = v end
                end
                for _, v in ipairs(sounds) do
                    if v ~= nil then merged[#merged + 1] = v end
                end
                PrototypeASMRDB.mounts[mid] = DedupePreserveSorted(merged)
            end
        end
    end

    -- Rebuild map if GUI core exists
    if _G.PrototypeGUI and _G.PrototypeGUI.RebuildCustomSoundMap then
        _G.PrototypeGUI.RebuildCustomSoundMap()
    end

    Print("Import complete.")
    return true
end
