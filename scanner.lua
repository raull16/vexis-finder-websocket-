-- WEBSOCKET SCANNER - VexisFinder13 Bridge
local WebSocketURL = "wss://vexisfinder13.onrender.com"

-- =========================
-- CONFIG
-- =========================
local VPS_NAME = "76"
local SCAN_INTERVAL = 0.5
local MIN_GEN = 10000000

-- =========================
-- SERVICES
-- =========================
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

-- =========================
-- ENCRYPTION (Hex + Base64)
-- =========================
local function encryptData(data)
    local json = HttpService:JSONEncode(data)
    local hex = ""
    for i = 1, #json do
        hex = hex .. string.format("%02x", string.byte(json, i))
    end
    return HttpService:Base64Encode(hex)
end

-- =========================
-- WEBSOCKET CONNECTION
-- =========================
local ws = nil
local connected = false
local messageQueue = {}

local function flushQueue()
    while #messageQueue > 0 and connected do
        local msg = table.remove(messageQueue, 1)
        pcall(function() ws:Send(msg) end)
        task.wait(0.1)
    end
end

local function sendToWebsocket(data)
    local encrypted = encryptData(data)
    if connected and ws then
        pcall(function() ws:Send(encrypted) end)
    else
        table.insert(messageQueue, encrypted)
    end
end

local function connectWebSocket()
    local success, socket = pcall(function()
        return WebSocket.connect(WebSocketURL)
    end)
    if success and socket then
        ws = socket
        connected = true
        print("[WS] Connected to " .. WebSocketURL)
        flushQueue()
        ws.OnClose:Connect(function()
            connected = false
            print("[WS] Disconnected, reconnecting in 3s...")
            task.wait(3)
            connectWebSocket()
        end)
        ws.OnMessage:Connect(function(msg)
            -- Optional: handle server responses
        end)
    else
        print("[WS] Failed to connect, retrying in 3s...")
        task.wait(3)
        connectWebSocket()
    end
end

-- =========================
-- DUEL DETECTION
-- =========================
local function cameBackFromDuel(player)
    for _, child in ipairs(player:GetChildren()) do
        if child.Name:lower():find("duel") then
            return true
        end
    end
    local ok, attrs = pcall(function() return player:GetAttributes() end)
    if ok and attrs then
        for key, val in pairs(attrs) do
            if key:lower():find("duel") and (val == true or val == 1) then
                return true
            end
        end
    end
    return false
end

local function getDuelPlayersMap()
    local duelMap = {}
    for _, player in ipairs(Players:GetPlayers()) do
        duelMap[player.Name] = cameBackFromDuel(player)
    end
    return duelMap
end

-- =========================
-- BRAINROT BYPASS LIST (abbreviated)
-- =========================
local BRAINROT_BYPASSES = {
    ["Skibidi Toilet"] = 0, ["Strawberry Elephant"] = 0, ["Meowl"] = 0,
    ["Ketupat Bros"] = 1e8, ["Nuclearo Dinossauro"] = 5e7,
    ["La Taco Combinasion"] = 3e8, ["Spaghetti Tualetti"] = 3e8,
}

local function shouldScan(name, value)
    local threshold = BRAINROT_BYPASSES[name]
    if threshold then return value >= threshold end
    return value >= 3e8
end

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

local function formatGenNumber(n)
    if n >= 1e9 then return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
    else return tostring(math.floor(n))
    end
end

-- =========================
-- SCANNER
-- =========================
local function scanAll()
    local results = {}
    local debris = Workspace:FindFirstChild("Debris")
    if not debris then return results end
    
    local duelMap = getDuelPlayersMap()
    local currentPlayers = #Players:GetPlayers()
    local jobId = game.JobId
    
    -- Encrypt jobId separately as gibberish hex base64
    local encryptedJobId = encryptData({ job = jobId })
    
    for _, obj in ipairs(debris:GetChildren()) do
        local overhead = obj:FindFirstChild("AnimalOverhead")
        if overhead then
            local genLabel = overhead:FindFirstChild("Generation")
            if genLabel and genLabel:IsA("TextLabel") then
                local genValue = parseGen(genLabel.Text)
                if genValue > MIN_GEN then
                    local nameLabel = overhead:FindFirstChild("DisplayName")
                    local petName = nameLabel and nameLabel.Text or obj.Name
                    
                    if shouldScan(petName, genValue) then
                        local inDuel = duelMap[petName] or false
                        local genText = "$" .. formatGenNumber(genValue) .. "/s"
                        
                        table.insert(results, {
                            petName = petName,
                            genValue = genText,
                            inDuel = inDuel
                        })
                    end
                end
            end
        end
        task.wait() -- Prevent lag
    end
    
    -- Build final payload
    local payload = {
        jobId = encryptedJobId,
        playerCount = currentPlayers,
        pets = results,
        timestamp = os.time()
    }
    
    return payload
end

-- =========================
-- MAIN LOOP
-- =========================
local function main()
    -- Wait for game load
    if not game:IsLoaded() then game.Loaded:Wait() end
    repeat task.wait() until Players.LocalPlayer
    
    -- Connect websocket
    connectWebSocket()
    
    print("[SCANNER] Starting continuous scan...")
    
    while true do
        local payload = scanAll()
        if payload and #payload.pets > 0 then
            sendToWebsocket(payload)
            print(string.format("[SCAN] Found %d pets | Players: %d", 
                #payload.pets, payload.playerCount))
        end
        task.wait(SCAN_INTERVAL)
    end
end

-- Start
pcall(main)
