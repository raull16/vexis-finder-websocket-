print("=== VEXIS FINDER STARTED ===")

local HttpService = game:GetService("HttpService")
local Workspace   = game:GetService("Workspace")
local Players     = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- ==================== YOUR CONFIGURATION ====================
local WS_URL    = "wss://vexisfinder13.onrender.com"
local WS_SECRET = "cabinetdoorpinkponyunicorn_VEXIS_2025"
local WS_SALT   = "VEXIS_ONLY_ADMINS_ULTRA_SECURE"

local CHANNELS = {
    ["LOW"]  = "https://discord.com/api/webhooks/1494112632733437952/BWhEDEjPH5Hnzcob41pLWHuiJ2a7HOrH9ilDENxUXTX5dLtccLppeprHoAqbz7xhAGsy?with_components=true",
    ["HIGH"] = "https://discord.com/api/webhooks/1494112540001697964/dCs_yovsxBeGOarO7JlzNCATsA7C36XPTotjlkZ32qhvlGzWC5Cimk4w_z1LnhGBMNUq?with_components=true",
    ["PEAK"] = "https://discord.com/api/webhooks/1494112447991251006/A2UTkmd26_YwvPBZ6D29cme8jIWlVpsHKPqP-6vJeEgidIBHOTufXrXqNjs6pOuavxGx?with_components=true"
}

local UNKNOWN_IMAGE = "https://cdn.discordapp.com/attachments/1485284656172630138/1494012668841951303/Z.png"

-- ==================== PERSISTENT BLACKLIST ====================
local BLACKLIST_FILE = "blacklisted_jobs.txt"
local blacklistedJobs = {}

local function loadBlacklist()
    local success, data = pcall(function() return readfile(BLACKLIST_FILE) end)
    if success and data then
        for jobId in string.gmatch(data, "[^\n]+") do
            if jobId and jobId ~= "" then blacklistedJobs[jobId] = true end
        end
        local count = 0
        for _ in pairs(blacklistedJobs) do count = count + 1 end
        print(string.format("[BLACKLIST] Loaded %d job IDs", count))
    else
        pcall(function() writefile(BLACKLIST_FILE, "") end)
    end
end

local function saveBlacklist()
    local content = ""
    for jobId, _ in pairs(blacklistedJobs) do content = content .. jobId .. "\n" end
    pcall(function() writefile(BLACKLIST_FILE, content) end)
end

local function addToBlacklist(jobId)
    if not jobId or jobId == "" or blacklistedJobs[jobId] then return end
    blacklistedJobs[jobId] = true
    saveBlacklist()
    print(string.format("[BLACKLIST] Added: %s", string.sub(jobId, 1, 16).."..."))
end

local function isBlacklisted(jobId) return blacklistedJobs[jobId] == true end
loadBlacklist()

-- ==================== TRACK SENT PETS ====================
local sentPets = {}
local function markAsSent(petName, genValue, owner)
    local key = string.lower(petName) .. ":" .. tostring(genValue) .. ":" .. (owner or "")
    sentPets[key] = true
end

local function isAlreadySent(petName, genValue, owner)
    local key = string.lower(petName) .. ":" .. tostring(genValue) .. ":" .. (owner or "")
    return sentPets[key] == true
end

local function clearSentCache() sentPets = {} end

-- ==================== MULTI-LAYER ENCRYPTION (IMPOSSIBLE TO DECRYPT) ====================
-- Layer 1: XOR with dynamic rolling key
-- Layer 2: Reverse string
-- Layer 3: Convert to hex
-- Layer 4: Base64 encode
-- Layer 5: Add fake headers to look like garbage

local encryptionSeed = 0x7F3A9C2E

local function buildKeyStream(length)
    local stream = {}
    local seed = encryptionSeed
    local combined = WS_SECRET .. WS_SALT .. tostring(os.time() % 10000)
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

local function encryptData(plaintext)
    -- Layer 1: XOR encryption
    local stream = buildKeyStream(#plaintext)
    local xorBytes = {}
    for i = 1, #plaintext do
        xorBytes[i] = string.char(bit32.bxor(string.byte(plaintext, i), stream[i]))
    end
    local xorResult = table.concat(xorBytes)
    
    -- Layer 2: Reverse string
    local reversed = string.reverse(xorResult)
    
    -- Layer 3: Convert to hex
    local hex = ""
    for i = 1, #reversed do
        hex = hex .. string.format("%02x", string.byte(reversed, i))
    end
    
    -- Layer 4: Add random garbage prefix and suffix
    local garbagePrefix = string.format("%04x", math.random(0, 65535))
    local garbageSuffix = string.format("%04x", math.random(0, 65535))
    hex = garbagePrefix .. hex .. garbageSuffix
    
    -- Layer 5: Base64 encode
    return HttpService:Base64Encode(hex)
end

-- ==================== TIER LISTS WITH CAPACITIES ====================
local OG_NAMES = {
    ["meowl"] = true, ["love love bear"] = true, ["strawberry elephant"] = true,
    ["skibidi toilet"] = true, ["dragon cannelloni"] = true, ["dragon caneloni"] = true,
    ["hydra dragon cannelloni"] = true, ["hydra dragon caneloni"] = true,
    ["dragon gingerini"] = true, ["dragon gingeriini"] = true,
    ["ginger gerat"] = true, ["cerberus"] = true, ["ketupat bros"] = true,
    ["headless horseman"] = true, ["foxini lanternini"] = true, ["foxini laterini"] = true,
    ["globa steppa"] = true, ["globa stepa"] = true, ["griffin"] = true,
    ["pancake and syrup"] = true, ["pancake syrup"] = true,
    ["signore carapace"] = true, ["signore caprice"] = true,
}

local FARMER_CAPACITIES = {
    ["garama and madundung"] = 200e6, ["garama and madungdung"] = 200e6,
    ["spooky and pumpky"] = 80e6, ["spooky and pumpy"] = 80e6,
    ["cooki and milki"] = 155e6, ["cookie and milki"] = 155e6,
    ["burguro and fryuro"] = 225e6,
    ["fragrama and chocrama"] = 125e6, ["fragrama and chocoroma"] = 125e6,
    ["ketchuru and musturu"] = 600e6,
    ["los bros"] = 500e6, ["los primos"] = 550e6,
    ["la secret combinasion"] = 462e6, ["la ginger sekolah"] = 500e6,
    ["ketupat kepat"] = 500e6, ["tictac sahur"] = 600e6,
    ["popcuru and fizzuru"] = 255e6, ["lavadorito spinito"] = 700e6,
    ["dug dug dug"] = 35e6, ["fortunu cashuru"] = 130e6,
    ["lovin rose"] = 300e6, ["cash or card"] = 100e6,
    ["celuarcini viciosini"] = 435e6, ["cloverat clapat"] = 60e6,
    ["goblino uniciclino"] = 27.5e6, ["jolly jolly sahur"] = 462e6,
    ["la food combination"] = 110e6, ["orcaledon"] = 560e6,
    ["rosetti tualetti"] = 800e6, ["tralaledon"] = 700e6,
    ["tuff toucan"] = 1000e6, ["ventoliero pavonero"] = 500e6,
}

local FARMER_NO_CAP = {
    ["bacuru and egguru"] = true, ["esok sekolah"] = true,
    ["los spooky combinasionas"] = true, ["los candies"] = true,
    ["money money puggy"] = true, ["los mobilis"] = true,
    ["tang tang keletang"] = true, ["los 67"] = true,
    ["la taco combinasion"] = true, ["chillin chili"] = true,
    ["spaghetti tualetti"] = true, ["nuclearo dinossauro"] = true,
    ["w or l"] = true, ["nacho spyder"] = true, ["swaggy bros"] = true,
    ["chicleteira noelteira"] = true, ["gold gold gold"] = true,
    ["los cupids"] = true, ["cilgno fulguro"] = true, ["los sweethearths"] = true,
    ["la sis"] = true, ["chipso n queso"] = true, ["eviledon"] = true,
    ["la extinct grande"] = true, ["la jolly grande"] = true, ["la lucky grande"] = true,
    ["la romantic grande"] = true, ["la spooky grande"] = true, ["los 25"] = true,
    ["los jolly combination"] = true, ["los planitos"] = true, ["los puggies"] = true,
    ["mietetiera bicicleteira"] = true, ["money money reindeer"] = true,
    ["quackini snackini"] = true, ["tacorillo crocodillo"] = true,
    ["tacorita bicicleteira"] = true,
}

local function isOG(name) return OG_NAMES[string.lower(name)] == true end

local function getTierForPet(name, genValue)
    local lowerName = string.lower(name)
    if isOG(name) then return "PEAK" end
    local capacity = FARMER_CAPACITIES[lowerName]
    if capacity then
        if genValue >= capacity then return "HIGH" else return "LOW" end
    end
    if FARMER_NO_CAP[lowerName] then return "LOW" end
    if genValue >= 250000000 then return "HIGH" else return "LOW" end
end

local function getOwnerTier(pets)
    for _, pet in ipairs(pets) do
        if isOG(pet.name) then return "PEAK" end
    end
    for _, pet in ipairs(pets) do
        if getTierForPet(pet.name, pet.genValue) == "HIGH" then return "HIGH" end
    end
    return "LOW"
end

-- ==================== MUTATION & TRAIT EMOJIS ====================
local MUTATION_EMOJIS = {
    ["yin yang"] = "<:1494503377223028766:1512288335488352337>",
    ["rainbow"] = "<:1494503386358485063:1512288245428392177>",
    ["radioactive"] = "<:1494503395212529865:1512288284384952331>",
    ["lava"] = "<:1494503390753849344:1512288054172450877>",
    ["gold"] = "<:1494503399859683330:1512288099881848993>",
    ["galaxy"] = "<:1494503404800704612:1512288130168918077>",
    ["divine"] = "<:1494503408776777778:1512288224708395098>",
    ["diamond"] = "<:1494503413306622083:1512288312923000932>",
    ["cyber"] = "<:1494503422009802792:1512288204772999299>",
    ["cursed"] = "<:1494503426208567407:1512288078038044712>",
    ["candy"] = "<:1494532967706529824:1512288679215894658>",
    ["bloodrot"] = "<:1495208479248613406:1512288182530474187>",
}

local TRAIT_EMOJIS = {
    ["fire"] = "<:trait_fire:1508150604579602444>",
    ["glitch"] = "<:trait_glitch:1508149788955119756>",
    ["water"] = "<:trait_water:1508149057183547482>",
    ["dragon"] = "<:trait_dragon:1508149304219668550>",
    ["halo"] = "<:trait_halo:1508151798110879945>",
    ["skibidi toilet"] = "<:trait_skibidi_toliet:1508152061840064573>",
    ["meowl"] = "<:trait_meowl:1508152142202933248>",
    ["candy"] = "<:trait_candy:1508151747124662423>",
}

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

-- ==================== HELPERS ====================
local MIN_GEN = 10000000
local SCAN_INTERVAL = 2
local ws = nil
local scanCount = 0
local discordSentForServer = false
local lastDiscordSend = 0
local discordCooldown = 12
local isDuelCooldown = false

local function parseGen(text)
    if not text then return 0 end
    text = text:gsub("<[^>]+>", ""):lower()
    local numStr, suffix = text:match("(%d+%.?%d*)%s*([kmbt])")
    local num = tonumber(numStr) or 0
    if suffix == "k" then num = num * 1e3
    elseif suffix == "m" then num = num * 1e6
    elseif suffix == "b" then num = num * 1e9
    elseif suffix == "t" then num = num * 1e12
    else
        num = tonumber(text:match("%d+%.?%d*")) or 0
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
    if not name then return "" end
    name = name:gsub("<[^>]+>", ""):gsub("^[%s⚔️💰✨]+", ""):gsub("[%s]+$", "")
    return name
end

-- ==================== DUEL CHECK ====================
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

-- ==================== TEXTURE DISABLE ====================
spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    for _, obj in ipairs(workspace:GetDescendants()) do
        pcall(function()
            if obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
                obj.Transparency = 1
                obj.Enabled = false
            end
        end)
    end
end)

-- ==================== TRAIT READING ====================
local function readTraits(overhead)
    local traits = {}
    local traitsFolder = overhead:FindFirstChild("Traits")
    if traitsFolder then
        for _, child in ipairs(traitsFolder:GetChildren()) do
            if child:IsA("StringValue") then
                local val = child.Value
                if val and val ~= "" and val ~= "None" then
                    table.insert(traits, val)
                end
            end
        end
    end
    return traits
end

-- ==================== BRAINROT INFO ====================
local function getBrainrotInfo(obj)
    local overhead = obj:FindFirstChild("AnimalOverhead")
    if not overhead then return nil end
    
    local priceLabel = overhead:FindFirstChild("Price")
    if not priceLabel or not priceLabel.Visible then return nil end
    
    local genLabel = overhead:FindFirstChild("Generation")
    if not genLabel or not genLabel:IsA("TextLabel") then return nil end
    
    local genValue = parseGen(genLabel.Text)
    if genValue <= MIN_GEN then return nil end
    
    local nameLabel = overhead:FindFirstChild("DisplayName")
    local mutationLabel = overhead:FindFirstChild("Mutation")
    local ownerName = nameLabel and nameLabel.Text or nil
    local imageAssetId = nil
    
    for _, child in ipairs(overhead:GetChildren()) do
        if child:IsA("ImageLabel") then
            imageAssetId = tonumber(child.Image:match("%d+"))
            if imageAssetId then break end
        end
    end
    
    local rawName = (nameLabel and nameLabel.Text or obj.Name):gsub("<[^>]+>", "")
    local rawMutation = (mutationLabel and mutationLabel.Text or "None"):gsub("<[^>]+>", "")
    
    return {
        name = rawName,
        owner = normalizeName(ownerName) or "Unknown",
        genValue = genValue,
        mutation = rawMutation,
        traits = readTraits(overhead),
        imageAssetId = imageAssetId,
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

-- ==================== GROUP PETS BY OWNER ====================
local function groupAndCountPets(pets)
    local ownerGroups = {}
    for _, pet in ipairs(pets) do
        local owner = pet.owner or "Unknown"
        if not ownerGroups[owner] then ownerGroups[owner] = {} end
        
        local sortedTraits = {}
        for _, t in ipairs(pet.traits or {}) do table.insert(sortedTraits, t:lower()) end
        table.sort(sortedTraits)
        local matchKey = string.lower(pet.name) .. "|" .. (pet.mutation:lower()) .. "|" .. table.concat(sortedTraits, ",")
        
        local found = false
        for _, existing in ipairs(ownerGroups[owner]) do
            if existing.matchKey == matchKey then
                existing.count = existing.count + 1
                found = true
                break
            end
        end
        if not found then
            table.insert(ownerGroups[owner], {
                name = pet.name, mutation = pet.mutation, genValue = pet.genValue,
                traits = pet.traits, imageAssetId = pet.imageAssetId, isDuel = pet.isDuel,
                count = 1, matchKey = matchKey
            })
        end
    end
    return ownerGroups
end

-- ==================== WEBSOCKET ====================
local function connectWS()
    while true do
        print("[WS] Connecting...")
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
            warn("[WS] Failed: " .. tostring(result))
            task.wait(5)
        end
    end
end
spawn(connectWS)

local function sendToWS(jobId, playerCount, petName, moneyPerSecond, inDuel)
    if not ws then return end
    local payload = {
        jobid = jobId,
        players = playerCount,
        petName = petName,
        money = moneyPerSecond,
        inDuel = inDuel
    }
    local json = HttpService:JSONEncode(payload)
    local encrypted = encryptData(json)
    pcall(function() ws:Send(encrypted) end)
end

-- ==================== DISCORD WEBHOOK ====================
local TIER_LABELS = { PEAK = "Peaklight", HIGH = "Highlight", LOW = "Lowlight" }

local function toTitleCase(str)
    return str:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

local function buildPetLine(pet)
    local mutEmoji = getMutationEmoji(pet.mutation) or ""
    local traitStr = getTraitEmojis(pet.traits or {})
    local nameStr = toTitleCase(normalizeName(pet.name))
    local genStr = "$" .. formatNumber(pet.genValue) .. "/s"
    local parts = { pet.count .. "x" }
    if mutEmoji ~= "" then table.insert(parts, mutEmoji) end
    table.insert(parts, nameStr)
    if traitStr ~= "" then table.insert(parts, traitStr) end
    table.insert(parts, "(" .. genStr .. ")")
    return table.concat(parts, " ")
end

local function sendOwnerEmbed(owner, pets, tier, isGlobalDuel)
    local currentTime = os.time()
    local hasDuel = false
    for _, pet in ipairs(pets) do if pet.isDuel then hasDuel = true break end end
    local statusIcon = (isGlobalDuel or hasDuel) and "⚔️" or "💰"
    table.sort(pets, function(a, b) return a.genValue > b.genValue end)
    local bestPet = pets[1]
    local thumbnailUrl = bestPet.imageAssetId and ("https://www.roblox.com/asset-thumbnail/image?assetId=" .. bestPet.imageAssetId .. "&width=420&height=420&format=png") or UNKNOWN_IMAGE
    local bestLine = buildPetLine(bestPet)
    local otherLines = {}
    for i = 2, #pets do table.insert(otherLines, buildPetLine(pets[i])) end
    local othersText = (#otherLines > 0) and table.concat(otherLines, "\n") or "No other brainrots"
    local embedContent = string.format(
        "## Vexis Finder | %s <:vexis_v_logo:1500538391836622999>\n### 👤 %s\n# %s\n\n**Others**\n%s\n\n-# discord.gg/vexis • %s • <t:%d:f>",
        TIER_LABELS[tier], owner, bestLine, othersText, statusIcon, currentTime
    )
    return { color = 0x000000, description = embedContent, thumbnail = { url = thumbnailUrl } }
end

local function sendToDiscord(ownerGroups, globalDuel)
    local req = request or http_request or (syn and syn.request)
    if not req then return end
    local now = tick()
    if discordSentForServer and now - lastDiscordSend < discordCooldown then return end
    for owner, pets in pairs(ownerGroups) do
        local ownerTier = getOwnerTier(pets)
        local embed = sendOwnerEmbed(owner, pets, ownerTier, globalDuel)
        pcall(function()
            req({ Url = CHANNELS[ownerTier], Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode({ embeds = { embed } }) })
        end)
    end
    discordSentForServer = true
    lastDiscordSend = now
end

-- ==================== SERVER HOP ====================
local function hopToNewServer()
    print("[HOP] Moving to brand new server...")
    task.wait(1)
    addToBlacklist(game.JobId)
    clearSentCache()
    pcall(function() TeleportService:Teleport(game.PlaceId) end)
end

-- ==================== MAIN LOOP ====================
print("[Scanner] Started")
print("[Scanner] WS: " .. WS_URL)
print("[Scanner] Rules: OG only = PEAK | Capacities = HIGH if above threshold")
if isBlacklisted(game.JobId) then print("[BLACKLIST] Current server blacklisted, hopping..."); hopToNewServer() end

while true do
    task.wait(SCAN_INTERVAL)
    scanCount = scanCount + 1
    updateDuelStatus()
    local found = scanDebris()
    if #found > 0 then
        local ownerGroups = groupAndCountPets(found)
        local bestPet = found[1]
        for _, pet in ipairs(found) do if pet.genValue > bestPet.genValue then bestPet = pet end end
        local tier = getTierForPet(bestPet.name, bestPet.genValue)
        local effectiveDuel = isDuelCooldown or bestPet.isDuel
        print(string.format("\n[SCAN #%d] JobID: %s", scanCount, string.sub(game.JobId, 1, 16).."..."))
        print(string.format("[DATA] Players: %d | Owners: %d", #Players:GetPlayers(), #ownerGroups))
        print(string.format("[BEST] %s %s | $%s/s | Tier: %s | InDuel: %s", effectiveDuel and "⚔️" or "💰", bestPet.name, formatNumber(bestPet.genValue), tier, tostring(effectiveDuel)))
        sendToWS(game.JobId, #Players:GetPlayers(), bestPet.name, formatNumber(bestPet.genValue), effectiveDuel)
        sendToDiscord(ownerGroups, isDuelCooldown)
    end
    hopToNewServer()
end
