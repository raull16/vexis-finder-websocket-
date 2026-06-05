print("=== VEXIS FINDER STARTED ===")

local HttpService = game:GetService("HttpService")
local Workspace   = game:GetService("Workspace")
local Players     = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- ========== CONFIGURATION ==========
local WS_URL    = "wss://vexisfinder13.onrender.com"
local WS_SECRET = "cabinetdoorpinkponyunicorn"
local WS_SALT   = "VEXIS_ONLY_ADMINS"

-- WEBHOOKS
local WEBHOOK_PEAK = "https://discord.com/api/webhooks/1494112447991251006/A2UTkmd26_YwvPBZ6D29cme8jIWlVpsHKPqP-6vJeEgidIBHOTufXrXqNjs6pOuavxGx"
local WEBHOOK_HIGH = "https://discord.com/api/webhooks/1494112540001697964/dCs_yovsxBeGOarO7JlzNCATsA7C36XPTotjlkZ32qhvlGzWC5Cimk4w_z1LnhGBMNUq"
local WEBHOOK_LOW  = "https://discord.com/api/webhooks/1494112632733437952/BWhEDEjPH5Hnzcob41pLWHuiJ2a7HOrH9ilDENxUXTX5dLtccLppeprHoAqbz7xhAGsy"

-- ========== TIER RULES ==========
local OG_NAMES = {
    ["meowl"] = true, ["love love bear"] = true, ["strawberry elephant"] = true,
    ["skibidi toilet"] = true, ["dragon cannelloni"] = true,
    ["hydra dragon cannelloni"] = true, ["dragon gingerini"] = true,
    ["ginger gerat"] = true, ["cerberus"] = true, ["ketupat bros"] = true,
    ["headless horseman"] = true, ["griffin"] = true,
}

local function getTier(name, genValue)
    local lowerName = string.lower(name)
    if OG_NAMES[lowerName] then return "PEAK" end
    if genValue >= 500000000 then return "PEAK"
    elseif genValue >= 250000000 then return "HIGH"
    else return "LOW" end
end

-- ========== BLACKLIST (WITH ERROR HANDLING) ==========
local blacklistedJobs = {}
local currentJobId = game.JobId

local function fetchBlacklist()
    local req = syn and syn.request or request or http_request
    if not req then 
        print("[BLACKLIST] No HTTP request function, skipping")
        return 
    end
    
    local success, res = pcall(function()
        return req({
            Url = "https://vexisfinder13.onrender.com/blacklist",
            Method = "GET",
            Timeout = 5
        })
    end)
    
    if success and res and res.Body then
        local body = res.Body
        -- Check if response is valid JSON (starts with { or [)
        if string.sub(body, 1, 1) == "{" or string.sub(body, 1, 1) == "[" then
            local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
            if ok and data and data.blacklisted then
                for _, jobId in ipairs(data.blacklisted) do
                    blacklistedJobs[jobId] = true
                end
                print("[BLACKLIST] Loaded " .. #data.blacklisted .. " jobs")
            end
        else
            print("[BLACKLIST] Server returned non-JSON, skipping blacklist")
        end
    else
        print("[BLACKLIST] Could not fetch, continuing anyway")
    end
end

-- Run blacklist check (non-critical, continue even if fails)
pcall(fetchBlacklist)

-- ========== WEBSOCKET ENCRYPTION ==========
local function buildKeyStream(length)
    local stream = {}
    local seed = 0
    local combined = WS_SECRET .. WS_SALT
    for i = 1, #combined do
        seed = (seed * 31 + string.byte(combined, i)) % 2147483647
    end
    local a = seed
    for i = 1, length do
        a = (a * 1664525 + 1013904223) % 4294967296
        table.insert(stream, a % 256)
    end
    return stream
end

local function scramble(plaintext)
    local stream = buildKeyStream(#plaintext)
    local result = {}
    for i = 1, #plaintext do
        local xorResult = bit32.bxor(string.byte(plaintext, i), stream[i])
        table.insert(result, string.format("%02x", xorResult))
    end
    return table.concat(result)
end

local function signMessage(ts, jobId)
    local raw = WS_SECRET .. WS_SALT .. tostring(ts) .. tostring(jobId)
    local h = 5381
    for i = 1, #raw do
        h = (h * 33 + string.byte(raw, i)) % 2147483647
    end
    local h2 = 52711
    for i = #raw, 1, -1 do
        h2 = (h2 * 31 + string.byte(raw, i)) % 2147483647
    end
    return string.format("%x%x", h, h2)
end

-- ========== HELPERS ==========
local MIN_GEN = 10000000
local SCAN_INTERVAL = 2
local ws = nil
local isDuelCooldown = false
local lastDiscordSend = 0

local function parseGen(text)
    if not text then return 0 end
    text = text:gsub("[^%d%.KMBTkmbt]", ""):lower()
    local num = tonumber(text:match("%d+%.?%d*")) or 0
    local suffix = text:match("[kmbt]") or ""
    if suffix == "k" then num = num * 1e3
    elseif suffix == "m" then num = num * 1e6
    elseif suffix == "b" then num = num * 1e9
    end
    return math.floor(num)
end

local function formatNumber(n)
    if n >= 1e9 then return string.format("%.2fB", n/1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    else return tostring(n)
    end
end

-- ========== DUEL CHECK ==========
local function isDuelBrainrot(obj)
    local overhead = obj:FindFirstChild("AnimalOverhead")
    if overhead then
        local nameLabel = overhead:FindFirstChild("DisplayName")
        if nameLabel and nameLabel.Text then
            local owner = Players:FindFirstChild(nameLabel.Text)
            if owner and owner:GetAttribute("__duels_block_steal") == true then
                return true
            end
        end
    end
    return false
end

local function updateDuelStatus()
    isDuelCooldown = false
    for _, player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("__duels_block_steal") == true then
            isDuelCooldown = true
            break
        end
    end
end

-- ========== TRAIT READING ==========
local function getTraits(overhead)
    local traits = {}
    local traitsFolder = overhead:FindFirstChild("Traits")
    if traitsFolder then
        for _, child in ipairs(traitsFolder:GetChildren()) do
            if child:IsA("StringValue") then
                local val = child.Value
                if val and val ~= "" then
                    table.insert(traits, val)
                end
            end
        end
    end
    return traits
end

-- ========== SCANNER ==========
local function getBrainrotInfo(obj)
    local overhead = obj:FindFirstChild("AnimalOverhead")
    if not overhead then return nil end
    
    local genLabel = overhead:FindFirstChild("Generation")
    if not genLabel or not genLabel:IsA("TextLabel") then return nil end
    
    local genValue = parseGen(genLabel.Text)
    if genValue <= MIN_GEN then return nil end
    
    local nameLabel = overhead:FindFirstChild("DisplayName")
    local mutationLabel = overhead:FindFirstChild("Mutation")
    
    return {
        name = nameLabel and nameLabel.Text or obj.Name,
        genValue = genValue,
        mutation = (mutationLabel and mutationLabel.Text ~= "None" and mutationLabel.Text) or nil,
        traits = getTraits(overhead),
        isDuel = isDuelBrainrot(obj),
        obj = obj
    }
end

local function scanDebris()
    local debris = Workspace:FindFirstChild("Debris")
    if not debris then return {} end
    
    local found = {}
    for _, obj in ipairs(debris:GetChildren()) do
        local info = getBrainrotInfo(obj)
        if info then
            table.insert(found, info)
        end
    end
    return found
end

-- ========== WEBSOCKET ==========
local function connectWS()
    while true do
        print("[WS] Connecting to " .. WS_URL)
        local success, result = pcall(function() 
            return WebSocket.connect(WS_URL) 
        end)
        if success and result then
            ws = result
            print("[WS] Connected!")
            ws.OnClose:Connect(function()
                print("[WS] Closed, reconnecting...")
                ws = nil
                task.wait(5)
                connectWS()
            end)
            break
        else
            print("[WS] Failed: " .. tostring(result))
            task.wait(5)
        end
    end
end
spawn(connectWS)

local function sendToWS(best)
    if not ws then return end
    local emoji = (isDuelCooldown or best.isDuel) and "⚔️" or "💰"
    local payload = {
        jobid = game.JobId,
        money = best.genValue,
        name = emoji .. " " .. best.name,
        players = #Players:GetPlayers(),
        ts = os.time(),
    }
    local json = HttpService:JSONEncode(payload)
    local scrambled = scramble(json)
    pcall(function() ws:Send(scrambled) end)
end

-- ========== DISCORD WEBHOOK ==========
local TIER_COLORS = { PEAK = 0xFF4500, HIGH = 0xFFA500, LOW = 0x888888 }
local TIER_WEBHOOKS = { PEAK = WEBHOOK_PEAK, HIGH = WEBHOOK_HIGH, LOW = WEBHOOK_LOW }

local function sendToDiscord(best, tier)
    local now = tick()
    if now - lastDiscordSend < 10 then return end
    
    local effectiveDuel = isDuelCooldown or best.isDuel
    local mutationText = best.mutation or "None"
    local traitCount = #(best.traits or {})
    
    local embed = {
        title = string.format("%s %s | %s/s", effectiveDuel and "⚔️" or "💰", best.name, formatNumber(best.genValue)),
        description = string.format("**Mutation:** %s\n**Traits:** %d\n**Players:** %d\n**Duel:** %s",
            mutationText, traitCount, #Players:GetPlayers(), effectiveDuel and "YES ⚔️" or "NO"),
        color = TIER_COLORS[tier],
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
        footer = { text = string.format("Tier: %s | Job: %s", tier, string.sub(game.JobId, 1, 12)) }
    }
    
    local req = syn and syn.request or request or http_request
    if req then
        pcall(function()
            req({
                Url = TIER_WEBHOOKS[tier],
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ embeds = { embed } })
            })
            print(string.format("[Discord] Sent %s [%s]", best.name, tier))
            lastDiscordSend = now
        end)
    end
end

-- ========== MAIN LOOP ==========
print("[Scanner] Started!")
print("[Scanner] WS: " .. WS_URL)
print("[Scanner] Rules: 0-250m=LOW | 250-500m=HIGH | 500m+=PEAK")

-- Disable textures for performance
spawn(function()
    task.wait(2)
    for _, obj in ipairs(workspace:GetDescendants()) do
        pcall(function()
            if obj:IsA("Texture") then
                obj.Transparency = 1
            end
        end)
    end
end)

local scanCount = 0
while true do
    task.wait(SCAN_INTERVAL)
    scanCount = scanCount + 1
    updateDuelStatus()
    
    local found = scanDebris()
    if #found > 0 then
        local best = found[1]
        for _, info in ipairs(found) do
            if info.genValue > best.genValue then
                best = info
            end
        end
        
        local tier = getTier(best.name, best.genValue)
        local duelIcon = (isDuelCooldown or best.isDuel) and "⚔️" or "💰"
        
        print(string.format("[%d] %s %s | %s/s [%s]", scanCount, duelIcon, best.name, formatNumber(best.genValue), tier))
        
        sendToWS(best)
        sendToDiscord(best, tier)
    elseif scanCount % 15 == 0 then
        print("[Scan " .. scanCount .. "] Waiting for pets...")
    end
end
