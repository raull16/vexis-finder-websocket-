print("=== VEXIS FINDER STARTED ===")

local HttpService = game:GetService("HttpService")
local Workspace   = game:GetService("Workspace")
local Players     = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- ========== CONFIGURATION ==========
local WS_URL    = "wss://vexisfinder13.onrender.com"
local WS_SECRET = "cabinetdoorpinkponyunicorn"
local WS_SALT   = "VEXIS_ONLY_ADMINS"

-- WEBHOOKS (TIER BASED)
local WEBHOOK_PEAK = "https://discord.com/api/webhooks/1494112447991251006/A2UTkmd26_YwvPBZ6D29cme8jIWlVpsHKPqP-6vJeEgidIBHOTufXrXqNjs6pOuavxGx"
local WEBHOOK_HIGH = "https://discord.com/api/webhooks/1494112540001697964/dCs_yovsxBeGOarO7JlzNCATsA7C36XPTotjlkZ32qhvlGzWC5Cimk4w_z1LnhGBMNUq"
local WEBHOOK_LOW  = "https://discord.com/api/webhooks/1494112632733437952/BWhEDEjPH5Hnzcob41pLWHuiJ2a7HOrH9ilDENxUXTX5dLtccLppeprHoAqbz7xhAGsy"

local UNKNOWN_IMAGE = "https://cdn.discordapp.com/attachments/1485284656172630138/1494012668841951303/Z.png"

-- ========== TIER RULES ==========
-- 0-250m = LOWLIGHT
-- 250m-500m = HIGHLIGHT (unless OG)
-- OG (specific names OR >=500m for known OGs) = PEAK

local OG_NAMES = {
    ["meowl"] = true, ["love love bear"] = true, ["strawberry elephant"] = true,
    ["skibidi toilet"] = true, ["dragon cannelloni"] = true, ["dragon caneloni"] = true,
    ["hydra dragon cannelloni"] = true, ["dragon gingerini"] = true,
    ["ginger gerat"] = true, ["cerberus"] = true, ["ketupat bros"] = true,
    ["headless horseman"] = true, ["griffin"] = true, ["signore carapace"] = true,
    ["garama and madundung"] = true,
}

local function getTier(name, genValue)
    local lowerName = string.lower(name)
    -- Check if OG by name
    if OG_NAMES[lowerName] then
        return "PEAK"
    end
    -- Tier by value
    if genValue >= 500000000 then
        return "PEAK"
    elseif genValue >= 250000000 then
        return "HIGH"
    else
        return "LOW"
    end
end

-- ========== GLOBAL BLACKLIST ==========
local blacklistedJobs = {}
local currentJobId = game.JobId

local function fetchBlacklist()
    local req = syn and syn.request or request or http_request
    if not req then return end
    local success, res = pcall(function()
        return req({ Url = "https://vexisfinder13.onrender.com/blacklist", Method = "GET" })
    end)
    if success and res and res.Body then
        local data = HttpService:JSONDecode(res.Body)
        if data and data.blacklisted then
            for _, jobId in ipairs(data.blacklisted) do
                blacklistedJobs[jobId] = true
            end
        end
    end
end

local function addToBlacklist(jobId)
    local req = syn and syn.request or request or http_request
    if not req then return end
    pcall(function()
        req({
            Url = "https://vexisfinder13.onrender.com/blacklist",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ jobId = jobId })
        })
    end)
    blacklistedJobs[jobId] = true
    print("[BLACKLIST] Added: " .. jobId)
end

-- Check blacklist
fetchBlacklist()
if blacklistedJobs[currentJobId] then
    print("[BLACKLIST] Server blacklisted! Teleporting...")
    TeleportService:Teleport(game.PlaceId)
    return
end

-- ========== MUTATION EMOJIS ==========
local MUTATION_EMOJIS = {
    ["yin yang"] = "<:mutation_yin_yang:1508171620974460958>",
    ["rainbow"] = "<:mutation_rainbow:1508149969973022912>",
    ["radioactive"] = "<:mutation_radioactive:1508173695229628567>",
    ["lava"] = "<:mutation_lava:1508149952449351860>",
    ["gold"] = "<:mutation_gold:1508149845498794175>",
    ["galaxy"] = "<:mutation_galaxy:1508149828599677049>",
    ["divine"] = "<:mutation_divine:1508149639294222479>",
    ["diamond"] = "<:mutation_diamond:1508148825317969980>",
    ["cyber"] = "<:mutation_cyber:1508149621728346334>",
    ["cursed"] = "<:mutation_cursed:1508172985591402597>",
    ["candy"] = "<:mutation_candy:1508149586223431813>",
    ["bloodrot"] = "<:mutation_bloodrot:1508149610340679741>",
}

-- ========== TRAIT EMOJIS (SIMPLIFIED) ==========
local TRAIT_EMOJIS = {
    ["glitch"] = "<:trait_glitch:1508149788955119756>",
    ["fire"] = "<:trait_fire:1508150604579602444>",
    ["water"] = "<:trait_water:1508149057183547482>",
    ["dragon"] = "<:trait_dragon:1508149304219668550>",
    ["halo"] = "<:trait_halo:1508151798110879945>",
    ["skibidi toilet"] = "<:trait_skibidi_toliet:1508152061840064573>",
    ["meowl"] = "<:trait_meowl:1508152142202933248>",
    ["shark"] = "<:trait_shark:1508150426342523022>",
    ["nyan cat"] = "<:trait_nyan_cat:1508149102309937382>",
}

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
        table.insert(result, string.format("%02x", bit32.bxor(string.byte(plaintext, i), stream[i])))
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
local highestValueSeen = 0
local discordSentForServer = false
local lastDiscordSend = 0
local isDuelCooldown = false

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

local function normalizeName(name)
    return name:gsub("^[%s⚔️💰]+", ""):gsub("[%s]+$", "")
end

local function getMutationEmoji(mut)
    if not mut or mut == "" or mut == "None" then return nil end
    return MUTATION_EMOJIS[mut:lower()] or nil
end

local function getTraitEmojis(traits)
    if not traits or #traits == 0 then return "" end
    local emojis = {}
    for _, trait in ipairs(traits) do
        local emoji = TRAIT_EMOJIS[trait:lower()]
        if emoji then table.insert(emojis, emoji) end
    end
    return table.concat(emojis, " ")
end

-- ========== DUEL CHECK ==========
local function isDuelBrainrot(obj)
    if not obj then return false end
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
local function readTraits(overhead)
    local traits = {}
    local traitsFolder = overhead:FindFirstChild("Traits")
    if traitsFolder then
        for _, child in ipairs(traitsFolder:GetChildren()) do
            if child:IsA("StringValue") then
                local val = child.Value
                if val and val ~= "" then
                    table.insert(traits, val:lower())
                end
            end
        end
    end
    return traits
end

-- ========== BRAINROT INFO ==========
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
        traits = readTraits(overhead),
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
        if info then table.insert(found, info) end
    end
    return found
end

-- ========== WEBSOCKET ==========
local function connectWS()
    while true do
        print("[WS] Connecting to " .. WS_URL)
        local success, result = pcall(function() return WebSocket.connect(WS_URL) end)
        if success and result then
            ws = result
            print("[WS] Connected!")
            ws.OnClose:Connect(function()
                print("[WS] Closed. Reconnecting...")
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
    local jobId = game.JobId
    if jobId == "" then return end
    local emoji = (isDuelCooldown or best.isDuel) and "⚔️" or "💰"
    local displayName = emoji .. " " .. best.name
    local ts = os.time()
    local sig = signMessage(ts, jobId)
    local payload = {
        jobid = jobId,
        money = best.genValue,
        name = displayName,
        players = #Players:GetPlayers(),
        maxplayers = Players.MaxPlayers,
        ts = ts,
        sig = sig,
        salt = WS_SALT,
    }
    local json = HttpService:JSONEncode(payload)
    local scrambled = scramble(json)
    pcall(function() ws:Send(scrambled) end)
end

-- ========== DISCORD WEBHOOK (FIXED FOR DELTA) ==========
local TIER_COLORS = { PEAK = 0xFF4500, HIGH = 0xFFA500, LOW = 0x888888 }
local TIER_WEBHOOKS = { PEAK = WEBHOOK_PEAK, HIGH = WEBHOOK_HIGH, LOW = WEBHOOK_LOW }

local function sendToDiscord(bestInfo, tier)
    local now = tick()
    if discordSentForServer and now - lastDiscordSend < 10 then return end
    
    local effectiveDuel = isDuelCooldown or bestInfo.isDuel
    local duelIcon = effectiveDuel and "⚔️ IN DUEL ⚔️" or "💰 STEALABLE 💰"
    local mutEmoji = getMutationEmoji(bestInfo.mutation) or ""
    local traitStr = getTraitEmojis(bestInfo.traits or {})
    local mutationText = bestInfo.mutation or "None"
    local traitCount = #(bestInfo.traits or {})
    
    local embed = {
        title = string.format("%s %s | %s/s", effectiveDuel and "⚔️" or "💰", bestInfo.name, formatNumber(bestInfo.genValue)),
        description = string.format("**Mutation:** %s %s\n**Traits:** %s\n**Job ID:** `%s`\n**Players:** %d\n\n**Status:** %s",
            mutEmoji, mutationText, traitStr ~= "" and traitStr or "None", 
            string.sub(game.JobId, 1, 16) .. "...", #Players:GetPlayers(), duelIcon),
        color = TIER_COLORS[tier],
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
        footer = { text = string.format("Tier: %s | Traits: %d", tier == "PEAK" and "PEAKLIGHT" or (tier == "HIGH" and "HIGHLIGHT" or "LOWLIGHT"), traitCount) }
    }
    
    -- Try multiple request methods for Delta
    local sent = false
    local req = syn and syn.request
    if not req then req = request end
    if not req then req = http_request end
    
    if req then
        local success, err = pcall(function()
            local response = req({
                Url = TIER_WEBHOOKS[tier],
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ embeds = { embed } })
            })
            if response and response.StatusCode == 204 or response.StatusCode == 200 then
                sent = true
            end
        end)
        if success and sent then
            print(string.format("[Discord] ✅ Sent %s | %s/s [%s]", bestInfo.name, formatNumber(bestInfo.genValue), tier))
            discordSentForServer = true
            lastDiscordSend = now
        else
            print("[Discord] ❌ Failed: " .. tostring(err))
        end
    else
        print("[Discord] ❌ No HTTP request function available")
    end
end

-- ========== MAIN LOOP ==========
print("[Scanner] Started | WS: " .. WS_URL)
print("[Scanner] Job ID: " .. currentJobId)
print("[Scanner] TIER RULES: 0-250m=LOW | 250m-500m=HIGH | 500m+=PEAK | OG names=PEAK")

-- Disable textures for performance
spawn(function()
    task.wait(3)
    for _, obj in ipairs(workspace:GetDescendants()) do
        pcall(function()
            if obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
                obj.Transparency = 1
                obj.Enabled = false
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
        local effectiveDuel = isDuelCooldown or best.isDuel
        local emoji = effectiveDuel and "⚔️" or "💰"
        
        print(string.format("[Scan #%d] %s %s | $%s/s | %s", scanCount, emoji, best.name, formatNumber(best.genValue), tier))
        
        -- Send to WebSocket
        sendToWS(best)
        
        -- Send to Discord
        sendToDiscord(best, tier)
        
        -- Blacklist PEAK servers
        if tier == "PEAK" then
            addToBlacklist(currentJobId)
            print("[BLACKLIST] PEAK found! Server blacklisted")
        end
    elseif scanCount % 10 == 0 then
        print("[Scan #" .. scanCount .. "] Nothing found")
    end
end
