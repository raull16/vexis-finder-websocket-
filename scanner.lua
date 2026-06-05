local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- ========== CONFIG ==========
local WS_URL = "wss://vexisfinder13.onrender.com"
local MIN_GEN = 10000000
local SCAN_INTERVAL = 2

-- Discord Webhooks
local WEBHOOK_OG = "https://discord.com/api/webhooks/1494112447991251006/A2UTkmd26_YwvPBZ6D29cme8jIWlVpsHKPqP-6vJeEgidIBHOTufXrXqNjs6pOuavxGx"
local WEBHOOK_HIGHLIGHT = "https://discord.com/api/webhooks/1494112540001697964/dCs_yovsxBeGOarO7JlzNCATsA7C36XPTotjlkZ32qhvlGzWC5Cimk4w_z1LnhGBMNUq"
local WEBHOOK_LOWLIGHT = "https://discord.com/api/webhooks/1494112632733437952/BWhEDEjPH5Hnzcob41pLWHuiJ2a7HOrH9ilDENxUXTX5dLtccLppeprHoAqbz7xhAGsy"

-- ========== ENCRYPTION ==========
local encryptionSeed = 0x7F3A9C2E
local function encryptData(data)
    local json = HttpService:JSONEncode(data)
    local seed = encryptionSeed
    local xorBytes = {}
    for i = 1, #json do
        local key = (seed % 255) + 1
        seed = (seed * 1103515245 + 12345) % 2^32
        xorBytes[i] = string.char(string.byte(json, i) ~ key)
    end
    local xorResult = table.concat(xorBytes)
    local hex = string.gsub(xorResult, ".", function(c) return string.format("%02x", string.byte(c)) end)
    return HttpService:Base64Encode(hex)
end

-- ========== WEBSOCKET ==========
local ws, connected = nil, false
local function connectWebSocket()
    local success, sock = pcall(function() return WebSocket.connect(WS_URL) end)
    if success and sock then
        ws, connected = sock, true
        print("[WS] ✅ Connected!")
        ws.OnClose:Connect(function() connected = false; task.wait(5); connectWebSocket() end)
    else
        task.wait(10)
        connectWebSocket()
    end
end
spawn(connectWebSocket)

-- ========== DUEL DETECTION ==========
local function isInDuel(obj, ownerName)
    if ownerName then
        local owner = Players:FindFirstChild(ownerName)
        if owner and owner:GetAttribute("__duels_block_steal") == true then return true end
    end
    local overhead = obj:FindFirstChild("AnimalOverhead")
    if overhead then
        local nameLabel = overhead:FindFirstChild("DisplayName")
        if nameLabel and nameLabel.Text then
            local owner = Players:FindFirstChild(nameLabel.Text)
            if owner and owner:GetAttribute("__duels_block_steal") == true then return true end
        end
    end
    return false
end

-- ========== PARSE MONEY ==========
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
    else return tostring(n)
    end
end

-- ========== GET TRAITS ==========
local function getTraits(overhead)
    local traits = {}
    local traitsFolder = overhead:FindFirstChild("Traits")
    if traitsFolder then
        for _, child in ipairs(traitsFolder:GetChildren()) do
            if child:IsA("StringValue") or child:IsA("TextLabel") then
                local val = child.Value or child.Text
                if val and val ~= "" then table.insert(traits, val) end
            end
        end
    end
    return traits
end

-- ========== GET PET IMAGE ==========
local function getPetImageUrl(petName)
    return string.format("https://tr.rbxcdn.com/%s/420/420/Image/Png", HttpService:GenerateGUID(false))
end

-- ========== GET PET INFO ==========
local function getPetInfo(obj)
    local overhead = obj:FindFirstChild("AnimalOverhead")
    if not overhead then return nil end
    local genLabel = overhead:FindFirstChild("Generation")
    if not genLabel or not genLabel:IsA("TextLabel") then return nil end
    local genValue = parseGen(genLabel.Text)
    if genValue <= MIN_GEN then return nil end
    local nameLabel = overhead:FindFirstChild("DisplayName")
    local mutationLabel = overhead:FindFirstChild("Mutation")
    local ownerName = nameLabel and nameLabel.Text or nil
    return {
        name = nameLabel and nameLabel.Text or obj.Name,
        money = genValue,
        moneyFormatted = formatNumber(genValue),
        mutation = (mutationLabel and mutationLabel.Text ~= "None" and mutationLabel.Text) or nil,
        traits = getTraits(overhead),
        isDuel = isInDuel(obj, ownerName),
        owner = ownerName or "Unknown"
    }
end

-- ========== SCAN ==========
local function scanDebris()
    local debris = Workspace:FindFirstChild("Debris")
    if not debris then return {} end
    local found = {}
    for _, obj in ipairs(debris:GetChildren()) do
        local info = getPetInfo(obj)
        if info then table.insert(found, info) end
        task.wait()
    end
    return found
end

-- ========== SEND TO WEBSOCKET ==========
local function sendToWebSocket(pet)
    if not connected or not ws then return false end
    local data = {
        petName = pet.name,
        moneyPerSecond = pet.money,
        moneyFormatted = pet.moneyFormatted,
        mutation = pet.mutation or "None",
        traits = pet.traits,
        isDuel = pet.isDuel,
        owner = pet.owner,
        jobId = game.JobId,
        playerCount = #Players:GetPlayers(),
        duelIcon = pet.isDuel and "⚔️" or "💰"
    }
    local success = pcall(function() ws:Send(encryptData(data)) end)
    if success then print(string.format("[WS] Sent: %s %s/s %s", pet.name, pet.moneyFormatted, pet.isDuel and "⚔️" or "")) end
    return success
end

-- ========== SEND TO DISCORD ==========
local function sendToDiscord(webhookUrl, pet, tier)
    local req = syn and syn.request or request or http_request
    if not req then return end
    local traitText = (#pet.traits > 0) and table.concat(pet.traits, ", ") or "None"
    local embed = {
        title = string.format("%s %s | %s/s", pet.isDuel and "⚔️" or "💰", pet.name, pet.moneyFormatted),
        description = string.format("**Mutation:** %s\n**Traits:** %s\n**Owner:** %s\n**Job ID:** `%s`\n**Players:** %d",
            pet.mutation or "None", traitText, pet.owner, string.sub(game.JobId, 1, 16).."...", #Players:GetPlayers()),
        color = (tier == "OG" and 0xFF4500) or (tier == "HIGHLIGHT" and 0xFFA500) or 0x888888,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
        footer = { text = string.format("Tier: %s | %s", tier, pet.isDuel and "IN DUEL" : "STEALABLE") }
    }
    pcall(function()
        req({ Url = webhookUrl, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({embeds = {embed}}) })
    end)
end

-- ========== GET TIER ==========
local function getTier(money)
    if money >= 300000000 then return "OG", WEBHOOK_OG
    elseif money >= 100000000 then return "HIGHLIGHT", WEBHOOK_HIGHLIGHT
    else return "LOWLIGHT", WEBHOOK_LOWLIGHT
    end
end

-- ========== BLACKLIST ==========
local blacklistedJobs = {}
local function checkBlacklist()
    local req = syn and syn.request or request or http_request
    if req then
        local success, res = pcall(function() return req({ Url = "https://vexisfinder13.onrender.com/blacklist", Method = "GET" }) end)
        if success and res and res.Body then
            local data = HttpService:JSONDecode(res.Body)
            if data and data.blacklisted then
                for _, jobId in ipairs(data.blacklisted) do blacklistedJobs[jobId] = true end
            end
        end
    end
    if blacklistedJobs[game.JobId] then
        print("[BLACKLIST] Server blacklisted! Teleporting...")
        game:GetService("TeleportService"):Teleport(game.PlaceId)
        return true
    end
    return false
end

-- ========== MAIN ==========
print("[SCANNER] Started | WS: " .. WS_URL)
if checkBlacklist() then return end

while true do
    task.wait(SCAN_INTERVAL)
    local found = scanDebris()
    if #found > 0 then
        local best = found[1]
        for _, pet in ipairs(found) do
            if pet.money > best.money then best = pet end
        end
        local tier, webhook = getTier(best.money)
        print(string.format("🔍 Found %d pets | Best: %s %s %s/s [%s]", #found, best.isDuel and "⚔️" or "💰", best.name, best.moneyFormatted, tier))
        if connected then sendToWebSocket(best) end
        sendToDiscord(webhook, best, tier)
        if tier == "OG" then
            local req = syn and syn.request or request or http_request
            if req then pcall(function() req({ Url = "https://vexisfinder13.onrender.com/blacklist", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({jobId = game.JobId}) }) end) end
        end
    end
end
