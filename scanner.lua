-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║   VEXIS SCANNER  |  WS SYSTEM  |  INSANE ENCRYPTION v3.0                    ║
-- ║   Theme: Black & Yellow                                                     ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

print("=== VEXIS SCANNER STARTED ===")

local HttpService = game:GetService("HttpService")
local Workspace   = game:GetService("Workspace")
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")

local WS_URL = "wss://vexisfinder.up.railway.app"

-- ==================== INSANE ENCRYPTION v3 ====================
local WS_SECRET = "cabinetdoorpinkponyunicorn"
local SALT = "VEXIS_ONLY_ADMINS"

-- Multi-layer XOR + AES-like substitution
local function generateKeyStream(length, seed_offset)
    local stream = {}
    local seed = 0
    for i = 1, #WS_SECRET do
        seed = (seed * 31 + string.byte(WS_SECRET, i)) % 2147483647
    end
    seed = (seed + seed_offset) % 4294967296
    
    local a, b, c = seed, seed * 1664525 + 1013904223, seed * 1103515245 + 12345
    for i = 1, length do
        a = (a * 1664525 + 1013904223) % 4294967296
        b = (b * 1103515245 + 12345) % 4294967296
        c = (c * 134775813 + 1) % 4294967296
        local val = bit32.bxor(a % 256, b % 256, c % 256)
        table.insert(stream, val)
    end
    return stream
end

local function chaoticShuffle(data)
    local bytes = {}
    for i = 1, #data do bytes[i] = string.byte(data, i) end
    local seed = 0
    for i = 1, #SALT do seed = (seed * 31 + string.byte(SALT, i)) % 2147483647 end
    for i = #bytes, 2, -1 do
        seed = (seed * 1664525 + 1013904223) % 4294967296
        local j = (seed % i) + 1
        bytes[i], bytes[j] = bytes[j], bytes[i]
    end
    return string.char(table.unpack(bytes))
end

local function reverseShuffle(data)
    local bytes = {}
    for i = 1, #data do bytes[i] = string.byte(data, i) end
    local seed = 0
    for i = 1, #SALT do seed = (seed * 31 + string.byte(SALT, i)) % 2147483647 end
    local swaps = {}
    for i = #bytes, 2, -1 do
        seed = (seed * 1664525 + 1013904223) % 4294967296
        local j = (seed % i) + 1
        table.insert(swaps, {i, j})
    end
    for k = #swaps, 1, -1 do
        local i, j = swaps[k][1], swaps[k][2]
        bytes[i], bytes[j] = bytes[j], bytes[i]
    end
    return string.char(table.unpack(bytes))
end

local function tripleEncrypt(plaintext)
    local timestamp = os.time()
    local ts_bytes = string.pack("I4", timestamp)
    -- Layer 1: XOR with timestamp-based key
    local stream1 = generateKeyStream(#plaintext, timestamp % 1000000)
    local layer1 = {}
    for i = 1, #plaintext do
        layer1[i] = bit32.bxor(string.byte(plaintext, i), stream1[i])
    end
    layer1 = string.char(table.unpack(layer1))
    -- Layer 2: Chaotic shuffle
    local layer2 = chaoticShuffle(layer1)
    -- Layer 3: XOR with secondary key stream
    local stream3 = generateKeyStream(#layer2, timestamp // 1000000)
    local layer3 = {}
    for i = 1, #layer2 do
        layer3[i] = bit32.bxor(string.byte(layer2, i), stream3[i])
    end
    layer3 = string.char(table.unpack(layer3))
    -- Add timestamp header
    return ts_bytes .. layer3
end

local function signMessage(ts, jobId)
    local raw = WS_SECRET .. tostring(ts) .. tostring(jobId)
    local h   = 5381
    for i = 1, #raw do
        h = (h * 33 + string.byte(raw, i)) % 2147483647
    end
    local h2 = 52711
    for i = #raw, 1, -1 do
        h2 = (h2 * 31 + string.byte(raw, i)) % 2147483647
    end
    return string.format("%x%x", h, h2)
end

-- ==================== WEBHOOKS ====================
local PEAK_WEBHOOK  = "https://discord.com/api/webhooks/1494112447991251006/A2UTkmd26_YwvPBZ6D29cme8jIWlVpsHKPqP-6vJeEgidIBHOTufXrXqNjs6pOuavxGx"
local HIGHLIGHT_WEBHOOK = "https://discord.com/api/webhooks/1494112540001697964/dCs_yovsxBeGOarO7JlzNCATsA7C36XPTotjlkZ32qhvlGzWC5Cimk4w_z1LnhGBMNUq"
local LOW_WEBHOOK = "https://discord.com/api/webhooks/1494112632733437952/BWhEDEjPH5Hnzcob41pLWHuiJ2a7HOrH9ilDENxUXTX5dLtccLppeprHoAqbz7xhAGsy"

local MIN_GEN                     = 10000000
local SCAN_INTERVAL               = 2
local VALUE_IMPROVEMENT_THRESHOLD = 10000000

local ws                   = nil
local scanCount            = 0
local discordSentForServer = false
local highestValueSeen     = 0
local lastDiscordSend      = 0
local discordCooldown      = 12
local isDuelCooldown       = false

-- ==================== NAME CLEANING ====================
local function cleanRichText(name)
    if not name then return "" end
    name = name:gsub("<[^>]+>", "")
    name = name:gsub("%s+", " ")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name
end

local function normalizeName(name)
    name = cleanRichText(name)
    name = name:gsub("^[%s⚔️💰]+", ""):gsub("[%s]+$", "")
    return name
end

-- ==================== VIP / TIER ROUTING ====================

local VIP_ALWAYS_PEAK = {
    ["Hydra Dragon Cannelloni"] = true,
    ["Dragon Cannelloni"]       = true,
    ["Ketupat Bros"]            = true,
    ["Antonio"]                 = true,
    ["Meowl"]                   = true,
    ["Skibidi Toilet"]          = true,
    ["Strawberry Elephant"]     = true,
    ["Dragon Gingerini"]        = true,
    ["Headless Horseman"]       = true,
    ["Signore Carapace"]        = true,
    ["Griffin"]                 = true,
    ["Ginger Gerat"]            = true,
    ["Love Love Bear"]          = true,
    ["Foxini Lanternini"]       = true,
    ["Globa Steppa"]            = true,
    ["Pancake and Syrup"]       = true,
}

local VIP_THRESHOLD_PEAK = {
    ["Cerberus"]             = 1700e6,
    ["Garama and Madundung"] = 1500e6,
}

local NO_CAP_BRAINROTS = {
    ["Bacuru and Egguru"]        = true,
    ["Esok Sekolah"]             = true,
    ["Los Spooky Combinasionas"] = true,
    ["Los Candies"]              = true,
    ["Money Money Puggy"]        = true,
    ["Los Mobilis"]              = true,
    ["Tang Tang Keletang"]       = true,
    ["Los 67"]                   = true,
    ["La Taco Combinasion"]      = true,
    ["Chillin Chili"]            = true,
    ["Spaghetti Tualetti"]       = true,
    ["Nuclearo Dinossauro"]      = true,
    ["W or L"]                   = true,
    ["Nacho Spyder"]             = true,
    ["Swaggy Bros"]              = true,
    ["Chicleteira Noelteira"]    = true,
    ["Gold Gold Gold"]           = true,
    ["Los Cupids"]               = true,
    ["Cilgno Fulguro"]           = true,
    ["Los SweetHearths"]         = true,
    ["La Sis"]                   = true,
    ["Chipso n Queso"]           = true,
    ["Eviledon"]                 = true,
    ["La Extinct Grande"]        = true,
    ["La Jolly Grande"]          = true,
    ["La Lucky Grande"]          = true,
    ["La Romantic Grande"]       = true,
    ["La Spooky Grande"]         = true,
    ["Los 25"]                   = true,
    ["Los Jolly Combination"]    = true,
    ["Los Planitos"]             = true,
    ["Los Puggies"]              = true,
    ["Mieteteira Bicicleteira"]  = true,
    ["Money Money Reindeer"]     = true,
    ["Quackini Snackini"]        = true,
    ["Tacorillo Crocodillo"]     = true,
    ["Tacorita Bicicleteira"]    = true,
}

local HIGHLIGHT_THRESHOLDS = {
    ["Garama and Madundung"]  = 200e6,
    ["Spooky and Pumpky"]     = 80e6,
    ["Cooki and Milki"]       = 155e6,
    ["Burguro And Fryuro"]    = 225e6,
    ["Fragrama and Chocrama"] = 125e6,
    ["Ketchuru and Musturu"]  = 600e6,
    ["Los Bros"]              = 500e6,
    ["Los Primos"]            = 550e6,
    ["La Secret Combinasion"] = 462e6,
    ["La Ginger Sekolah"]     = 500e6,
    ["Ketupat Kepat"]         = 500e6,
    ["Tictac Sahur"]          = 600e6,
    ["Popcuru and Fizzuru"]   = 255e6,
    ["Lavadorito Spinito"]    = 700e6,
    ["Dug Dug Dug"]           = 35e6,
    ["Fortunu Cashuru"]       = 130e6,
    ["Lovin Rose"]            = 300e6,
    ["Cash or Card"]          = 100e6,
    ["Celularcini Viciosini"]  = 435e6,
    ["Cloverat Clapat"]       = 60e6,
    ["Goblino Uniciclino"]    = 27.5e6,
    ["Jolly Jolly Sahur"]     = 462e6,
    ["La Food Combination"]   = 110e6,
    ["Orcaledon"]             = 560e6,
    ["Rosetti Tualetti"]      = 800e6,
    ["Tralaledon"]            = 700e6,
    ["Tuff Toucan"]           = 1000e6,
    ["Ventoliero Pavonero"]   = 500e6,
}

local function getWebhookTier(brainrotName, genValue)
    local name      = normalizeName(brainrotName)
    local nameLower = name:lower()

    for nocapName in pairs(NO_CAP_BRAINROTS) do
        if nameLower == nocapName:lower() then
            return "low", false
        end
    end

    for vipName in pairs(VIP_ALWAYS_PEAK) do
        if nameLower == vipName:lower() then
            return "peak", true
        end
    end

    for vipName, threshold in pairs(VIP_THRESHOLD_PEAK) do
        if nameLower == vipName:lower() then
            if genValue >= threshold then return "peak", true end
            break
        end
    end

    for threshName, threshold in pairs(HIGHLIGHT_THRESHOLDS) do
        if nameLower == threshName:lower() then
            return genValue >= threshold and "highlight" or "low", false
        end
    end

    if genValue >= 500e6     then return "peak", false
    elseif genValue >= 100e6 then return "highlight", false
    else                          return "low", false end
end

-- ==================== DUEL CHECK ====================
local function isDuelBrainrot(obj)
    if not obj then return false end
    local overhead = obj:FindFirstChild("AnimalOverhead")
    if overhead then
        local nameLabel = overhead:FindFirstChild("DisplayName")
        if nameLabel and nameLabel.Text then
            local baseOwner = Players:FindFirstChild(nameLabel.Text)
            if baseOwner and baseOwner:GetAttribute("__duels_block_steal") == true then return true end
        end
    end
    local slotData = obj:FindFirstChild("SlotData")
        or (obj.Parent and obj.Parent:FindFirstChild("SlotData"))
        or (obj:FindFirstAncestorWhichIsA("Model") and obj:FindFirstAncestorWhichIsA("Model"):FindFirstChild("SlotData"))
    if slotData and slotData:FindFirstChild("Machine") then
        local machine = slotData.Machine
        if machine and machine.Active and machine:FindFirstChild("Type") then
            if machine.Type.Value == "Duel" or machine.Type == "Duel" then return true end
        end
    end
    return false
end

local function updateDuelStatus()
    local wasDuel  = isDuelCooldown
    isDuelCooldown = false
    for _, player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("__duels_block_steal") == true then
            isDuelCooldown = true
            break
        end
    end
    if isDuelCooldown and not wasDuel     then print("[Status] ⚔️ Duel cooldown ACTIVE")
    elseif not isDuelCooldown and wasDuel then print("[Status] 💰 Duel cooldown ended") end
end

-- ==================== PERFORMANCE ====================
spawn(function()
    print("[PERF] Disabling textures...")
    if not game:IsLoaded() then game.Loaded:Wait() end
    for _, obj in ipairs(workspace:GetDescendants()) do
        pcall(function()
            if obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
                obj.Transparency = 1
                obj.Enabled      = false
            end
        end)
    end
    print("[PERF] Textures disabled")
end)

-- ==================== HELPERS ====================
local function parseGen(text)
    if not text then return 0 end
    text = text:gsub("[^%d%.KMBTkmbt]", ""):lower()
    local num    = tonumber(text:match("%d+%.?%d*")) or 0
    local suffix = text:match("[kmbt]") or ""
    if suffix == "k" then num *= 1e3
    elseif suffix == "m" then num *= 1e6
    elseif suffix == "b" then num *= 1e9
    elseif suffix == "t" then num *= 1e12 end
    return math.floor(num)
end

local function formatNumber(n)
    if n >= 1e12      then return string.format("%.2fT", n/1e12)
    elseif n >= 1e9   then return string.format("%.2fB", n/1e9)
    elseif n >= 1e6   then return string.format("%.2fM", n/1e6)
    else
        local s = tostring(math.floor(n))
        return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    end
end

-- ==================== BRAINROT INFO ====================
local function getBrainrotInfo(obj)
    local overhead = obj:FindFirstChild("AnimalOverhead")
    if not overhead then return nil end
    local genLabel = overhead:FindFirstChild("Generation")
    if not genLabel or not genLabel:IsA("TextLabel") then return nil end
    local genValue = parseGen(genLabel.Text)
    if genValue <= MIN_GEN then return nil end

    local nameLabel     = overhead:FindFirstChild("DisplayName")
    local mutationLabel = overhead:FindFirstChild("Mutation")
    local imageAssetId  = nil

    for _, child in ipairs(overhead:GetChildren()) do
        if child:IsA("ImageLabel") then
            imageAssetId = tonumber(child.Image:match("%d+"))
            if imageAssetId then break end
        end
    end

    return {
        name         = cleanRichText(nameLabel and nameLabel.Text or obj.Name),
        genValue     = genValue,
        mutation     = cleanRichText(mutationLabel and mutationLabel.Text or "None"),
        imageAssetId = imageAssetId,
        isDuel       = isDuelBrainrot(obj),
        obj          = obj,
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

-- ==================== IMAGE FETCH ====================
local function getImageUrl(petName)
    local success, result = pcall(function()
        local title  = petName:gsub(" ", "_")
        local apiUrl = "https://stealabrainrot.fandom.com/api.php?action=query&prop=pageimages&format=json&piprop=thumbnail&pithumbsize=500&titles=" .. title
        local req    = request or http_request or (syn and syn.request)
        local response
        if req then
            response = req({Url = apiUrl, Method = "GET"})
            if response and response.Success and response.Body then response = response.Body end
        else
            response = HttpService:GetAsync(apiUrl)
        end
        if response then
            local data = HttpService:JSONDecode(response)
            if data and data.query and data.query.pages then
                for _, page in pairs(data.query.pages) do
                    if page.thumbnail and page.thumbnail.source then return page.thumbnail.source end
                end
            end
        end
        return nil
    end)
    return success and result or nil
end

-- ==================== WEBSOCKET ====================
local function connectWS()
    while true do
        print("[WS] Connecting...")
        local success, result = pcall(function() return WebSocket.connect(WS_URL) end)
        if success and result then
            ws = result
            print("[WS] ✅ Connected!")
            ws.OnClose:Connect(function()
                print("[WS] Connection closed. Reconnecting...")
                ws = nil
            end)
            break
        else
            warn("[WS] Failed: " .. tostring(result))
            task.wait(5)
        end
    end
end
spawn(connectWS)

local function sendToWS(best)
    if not ws then return end
    local jobId = game.JobId
    if jobId == "" then return end
    local shouldSend = (highestValueSeen == 0) or (best.genValue > highestValueSeen + VALUE_IMPROVEMENT_THRESHOLD)
    if not shouldSend then return end

    local emoji       = (isDuelCooldown or best.isDuel) and "⚔️" or "💰"
    local displayName = emoji .. " " .. normalizeName(best.name)
    local ts          = os.time()
    local sig         = signMessage(ts, jobId)

    local payload = {
        jobid      = jobId,
        money      = best.genValue,
        name       = displayName,
        players    = #Players:GetPlayers(),
        maxplayers = Players.MaxPlayers,
        ts         = ts,
        sig        = sig,
    }

    local json      = HttpService:JSONEncode(payload)
    local encrypted = tripleEncrypt(json)

    pcall(function()
        ws:Send(encrypted)
        print(string.format("[WS] SENT → %s | %s/s", displayName, formatNumber(best.genValue)))
    end)

    highestValueSeen = best.genValue
end

-- ==================== DISCORD ====================
local function sendToDiscord(foundList, bestInfo)
    if #foundList == 0 then return end
    local now = tick()
    if discordSentForServer and now - lastDiscordSend < discordCooldown then return end

    local tier, pingEveryone = getWebhookTier(bestInfo.name, bestInfo.genValue)
    local webhookUrl
    local tierName
    
    if tier == "peak" then
        webhookUrl = PEAK_WEBHOOK
        tierName = "PEAK"
        print("[Discord] PEAK webhook")
    elseif tier == "highlight" then
        webhookUrl = HIGHLIGHT_WEBHOOK
        tierName = "HIGHLIGHT"
        print("[Discord] HIGHLIGHT webhook")
    else
        webhookUrl = LOW_WEBHOOK
        tierName = "LOW"
        print("[Discord] LOW webhook")
    end

    local groups     = {}
    local groupOrder = {}
    for _, info in ipairs(foundList) do
        local cleanName = normalizeName(info.name)
        local cleanMut  = info.mutation ~= "None" and cleanRichText(info.mutation) or "None"
        local key = cleanName .. "|" .. cleanMut
        if not groups[key] then
            groups[key] = {
                name         = cleanName,
                mutation     = cleanMut,
                count        = 0,
                maxGen       = 0,
                imageAssetId = info.imageAssetId,
            }
            table.insert(groupOrder, key)
        end
        groups[key].count += 1
        if info.genValue > groups[key].maxGen then
            groups[key].maxGen = info.genValue
        end
        if info.imageAssetId and not groups[key].imageAssetId then
            groups[key].imageAssetId = info.imageAssetId
        end
    end

    local aggregated = {}
    for _, key in ipairs(groupOrder) do
        table.insert(aggregated, groups[key])
    end
    table.sort(aggregated, function(a, b) return a.maxGen > b.maxGen end)

    local effectiveDuel = isDuelCooldown or bestInfo.isDuel
    local footerEmoji   = effectiveDuel and "⚔️" or "💰"
    local best          = aggregated[1]

    local bestMutDisplay = best.mutation ~= "None" and "[" .. best.mutation .. "] " or ""
    local descLines = {
        string.format("## %s%s $%s/s", bestMutDisplay, best.name, formatNumber(best.maxGen))
    }

    if #aggregated > 1 then
        local otherLines = {}
        for i = 2, #aggregated do
            local g   = aggregated[i]
            local mut = g.mutation ~= "None" and "[" .. g.mutation .. "] " or ""
            table.insert(otherLines,
                string.format("%dx %s%s ($%s/s)", g.count, mut, g.name, formatNumber(g.maxGen))
            )
        end
        table.insert(descLines, "\n**Others**")
        table.insert(descLines, "```\n" .. table.concat(otherLines, "\n") .. "\n```")
    end

    table.insert(descLines, string.format("**Players:** %d/%d", #Players:GetPlayers(), Players.MaxPlayers))

    local description = table.concat(descLines, "\n")
    local embedColor = 0x000000

    local thumbnailUrl = nil
    if best.imageAssetId then
        thumbnailUrl = "https://www.roblox.com/asset-thumbnail/image?assetId="
            .. best.imageAssetId .. "&width=420&height=420&format=png"
    else
        thumbnailUrl = getImageUrl(best.name)
    end

    local footerText = "discord.gg/vexis •" .. footerEmoji .. " • " .. tierName

    local embed = {
        title       = "Vexis Finder | " .. tierName,
        description = description,
        color       = embedColor,
        footer      = { text = footerText },
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    if thumbnailUrl then embed.thumbnail = { url = thumbnailUrl } end

    local content = pingEveryone and "@everyone" or ""
    local json    = HttpService:JSONEncode({ content = content, embeds = { embed } })
    local req     = request or http_request or (syn and syn.request)
    if req then
        pcall(function()
            req({
                Url     = webhookUrl,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = json,
            })
            print("[Discord] ✅ Sent | "
                .. formatNumber(bestInfo.genValue)
                .. " | tier=" .. tier
                .. (pingEveryone and " | @everyone" or ""))
            discordSentForServer = true
            lastDiscordSend      = now
        end)
    end
end

-- ==================== MAIN LOOP ====================
print("[Scanner] Main loop started")

while true do
    task.wait(SCAN_INTERVAL)
    scanCount += 1
    print(string.format("[Scan #%d]", scanCount))
    updateDuelStatus()

    local found = scanDebris()
    if #found > 0 then
        local best = found[1]
        for _, info in ipairs(found) do
            if info.genValue > best.genValue then best = info end
        end

        local effectiveDuel = isDuelCooldown or best.isDuel
        local emoji         = effectiveDuel and "⚔️" or "💰"

        print(string.format("   → Found %d brainrot(s) | %s %s (%s/s) %s",
            #found, emoji, normalizeName(best.name),
            formatNumber(best.genValue), effectiveDuel and "[DUEL]" or ""))

        sendToWS(best)

        if not discordSentForServer or best.genValue >= highestValueSeen + VALUE_IMPROVEMENT_THRESHOLD then
            sendToDiscord(found, best)
        end
    else
        print("   → No high-value brainrot found")
    end
end
