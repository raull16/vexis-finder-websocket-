local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- ========== CONFIGURATION ==========
local WS_URL = "wss://vexisfinder.up.railway.app"
local MIN_GEN = 10000000
local SCAN_INTERVAL = 2

-- Discord Webhooks
local WEBHOOK_OG = "https://discord.com/api/webhooks/1494112447991251006/A2UTkmd26_YwvPBZ6D29cme8jIWlVpsHKPqP-6vJeEgidIBHOTufXrXqNjs6pOuavxGx"
local WEBHOOK_HIGHLIGHT = "https://discord.com/api/webhooks/1494112540001697964/dCs_yovsxBeGOarO7JlzNCATsA7C36XPTotjlkZ32qhvlGzWC5Cimk4w_z1LnhGBMNUq"
local WEBHOOK_LOWLIGHT = "https://discord.com/api/webhooks/1494112632733437952/BWhEDEjPH5Hnzcob41pLWHuiJ2a7HOrH9ilDENxUXTX5dLtccLppeprHoAqbz7xhAGsy"

-- Global blacklist for job IDs (shared across all script instances)
local blacklistedJobIds = {}
local blacklistUrl = "https://vexisfinder.up.railway.app/blacklist" -- Server endpoint

-- ========== ENCRYPTION (Multi-layer: Hex + Base64 + XOR) ==========
local encryptionKey = 0x5A3F9E2C -- Random XOR key

local function encryptData(data)
    local json = HttpService:JSONEncode(data)
    
    -- Layer 1: XOR cipher
    local xorResult = ""
    for i = 1, #json do
        local charCode = string.byte(json, i)
        local keyByte = encryptionKey % 256
        encryptionKey = (encryptionKey * 1103515245 + 12345) % 2^32
        xorResult = xorResult .. string.char(charCode ~ keyByte)
    end
    
    -- Layer 2: Convert to hex
    local hex = ""
    for i = 1, #xorResult do
        hex = hex .. string.format("%02x", string.byte(xorResult, i))
    end
    
    -- Layer 3: Base64 encode the hex
    return HttpService:Base64Encode(hex)
end

-- ========== BLACKLIST MANAGEMENT ==========
local function fetchBlacklist()
    local req = syn and syn.request or request or http_request
    if not req then return end
    
    local success, res = pcall(function()
        return req({
            Url
