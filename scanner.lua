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

local UNKNOWN_IMAGE = "https://cdn.discordapp.com/attachments/1485284656172630138/1494012668841951303/Z.png"

-- ========== HOP CONFIG ==========
local SCAN_INTERVAL = 2

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

-- ========== MUTATION EMOJIS ==========
local MUTATION_EMOJIS = {
    ["yin yang"]    = "<:mutation_yin_yang:1508171620974460958>",
    ["rainbow"]     = "<:mutation_rainbow:1508149969973022912>",
    ["radioactive"] = "<:mutation_radioactive:1508173695229628567>",
    ["lava"]        = "<:mutation_lava:1508149952449351860>",
    ["gold"]        = "<:mutation_gold:1508149845498794175>",
    ["galaxy"]      = "<:mutation_galaxy:1508149828599677049>",
    ["divine"]      = "<:mutation_divine:1508149639294222479>",
    ["diamond"]     = "<:mutation_diamond:1508148825317969980>",
    ["cyber"]       = "<:mutation_cyber:1508149621728346334>",
    ["cursed"]      = "<:mutation_cursed:1508172985591402597>",
    ["candy"]       = "<:mutation_candy:1508149586223431813>",
    ["bloodrot"]    = "<:mutation_bloodrot:1508149610340679741>",
}

local function getMutationEmoji(mutationText)
    if not mutationText or mutationText == "" or mutationText == "None" then return nil end
    return MUTATION_EMOJIS[mutationText:lower()] or nil
end

-- ========== TRAIT EMOJIS ==========
local TRAIT_EMOJIS = {
    ["26"]              = "<:trait_26:1508166576384245800>",
    ["rip"]             = "<:trait_RIP:1508166712841863300>",
    ["z"]               = "<:trait_Z:1508148423831060662>",
    ["alien invasion"]  = "<:trait_alien_invasion:1508168284346908743>",
    ["balloon blue"]    = "<:trait_balloon_blue:1508152713161212037>",
    ["balloon green"]   = "<:trait_balloon_green:1508152641367048213>",
    ["balloon orange"]  = "<:trait_balloon_orange:1508152823970533538>",
    ["balloon pink"]    = "<:trait_balloon_pink:1508168146954096884>",
    ["balloon rainbow"] = "<:trait_balloon_rainbow:1508168093958930654>",
    ["balloon red"]     = "<:trait_balloon_red:1508152767984963614>",
    ["barmbadiro"]      = "<:trait_barmbadiro:1508150301830545508>",
    ["brazil"]          = "<:trait_brazil:1508150369459372232>",
    ["bubble gum"]      = "<:trait_bubble_gum:1508168362495316099>",
    ["bunny ears"]      = "<:trait_bunny_ears:1508151902649581719>",
    ["chocolate"]       = "<:trait_chocolate:1508151747124662423>",
    ["concert"]         = "<:trait_concert:1508149238754705568>",
    ["crab"]            = "<:trait_crab:1508149830227198116>",
    ["dragon"]          = "<:trait_dragon:1508149304219668550>",
    ["egg four"]        = "<:trait_egg_four:1508167983107932261>",
    ["egg one"]         = "<:trait_egg_one:1508167735534686269>",
    ["egg three"]       = "<:trait_egg_three:1508167912530116629>",
    ["egg two"]         = "<:trait_egg_two:1508167844443984043>",
    ["extinct"]         = "<:trait_extinct:1508153027721166999>",
    ["fire"]            = "<:trait_fire:1508150604579602444>",
    ["firework"]        = "<:trait_firework:1508149149244330055>",
    ["glitch"]          = "<:trait_glitch:1508149788955119756>",
    ["graduation"]      = "<:trait_graduation:1508166817233764559>",
    ["granny"]          = "<:trait_granny:1508150693171822643>",
    ["halo"]            = "<:trait_halo:1508151798110879945>",
    ["indonesia"]       = "<:trait_indonesia:1508150478200897707>",
    ["john pork"]       = "<:trait_john_pork:1508152008593379371>",
    ["lucky"]           = "<:trait_lucky:1508151954881253456>",
    ["matteo"]          = "<:trait_matteo:1508150250290806949>",
    ["meowl"]           = "<:trait_meowl:1508152142202933248>",
    ["meteor"]          = "<:trait_meteor:1508150109978755162>",
    ["mi gattito"]      = "<:trait_mi_gattito:1508166639261323455>",
    ["nyan cat"]        = "<:trait_nyan_cat:1508149102309937382>",
    ["one year"]        = "<:trait_one_year:1508170650718572554>",
    ["paint"]           = "<:trait_paint:1508167100135510159>",
    ["pumpkin"]         = "<:trait_pumpkin:1508151686169104414>",
    ["reindeer"]        = "<:trait_reindeer:1508151836371062855>",
    ["rose"]            = "<:trait_rose:1508149193233924146>",
    ["santa hat"]       = "<:trait_santa_hat:1508166765459279912>",
    ["shark"]           = "<:trait_shark:1508150426342523022>",
    ["skibidi toilet"]  = "<:trait_skibidi_toliet:1508152061840064573>",
    ["snowflake"]       = "<:trait_snowflake:1508150942980116520>",
    ["sombrero"]        = "<:trait_sombrero:1508150564754821262>",
    ["spyder"]          = "<:trait_spyder:1508150196394131486>",
    ["starfall"]        = "<:trait_starfall:1508150986651205736>",
    ["strawberry"]      = "<:trait_strawberry:1508152193398739077>",
    ["taco"]            = "<:trait_taco:1508150749727686737>",
    ["ten billion"]     = "<:trait_ten_billion:1508171806291398867>",
    ["tung"]            = "<:trait_tung:1508149875857166487>",
    ["water"]           = "<:trait_water:1508149057183547482>",
    ["witch hat"]       = "<:trait_witch_hat:1508152931965206599>",
}

local function getTraitEmojis(traits)
    if not traits or #traits == 0 then return "" end
    local emojis = {}
    for _, trait in ipairs(traits) do
        local emoji = TRAIT_EMOJIS[trait:lower()]
        if emoji then table.insert(emojis, emoji) end
    end
    return table.concat(emojis, "")
end

-- ========== PET IMAGE EXTRACTION ==========
local function getPetImageFromOverhead(overhead)
    for _, child in ipairs(overhead:GetChildren()) do
        if child:IsA("ImageLabel") then
            local assetId = tonumber(child.Image:match("%d+"))
            if assetId then
                return "https://www.roblox.com/asset-thumbnail/image?assetId=" .. assetId .. "&width=420&height=420&format=png"
            end
        end
    end
    return nil
end

local function getPetImage(animalOverhead, petName)
    local image = getPetImageFromOverhead(animalOverhead)
    if image then return image end
    return UNKNOWN_IMAGE
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
    if #traits == 0 then
        for _, child in ipairs(overhead:GetDescendants()) do
            if child:IsA("TextLabel") and child.Name:lower():find("trait") then
                local val = child.Text
                if val and val ~= "" then
                    table.insert(traits, val:lower())
                end
            end
        end
    end
    return traits
end

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

-- ========== HELPERS ==========
local MIN_GEN = 10000000
local ws = nil
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
    local petName = nameLabel and nameLabel.Text or obj.Name
    local mutationText = (mutationLabel and mutationLabel.Text ~= "None" and mutationLabel.Text) or nil
    
    -- Get owner name for grouping
    local ownerName = nil
    if nameLabel and nameLabel.Text then
        ownerName = nameLabel.Text
    end
    
    local traits = readTraits(overhead)
    local imageUrl = getPetImage(overhead, petName)
    local mutationEmoji = getMutationEmoji(mutationText)
    local traitEmojis = getTraitEmojis(traits)
    
    return {
        name = petName,
        owner = ownerName,
        genValue = genValue,
        mutation = mutationText,
        mutationEmoji = mutationEmoji,
        traits = traits,
        traitEmojis = traitEmojis,
        imageUrl = imageUrl,
        isDuel = isDuelBrainrot(obj)
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

-- ========== GROUP PETS BY OWNER ==========
local function groupPetsByOwner(pets)
    local ownerGroups = {}
    
    for _, pet in ipairs(pets) do
        local ownerKey = pet.owner or "Unknown"
        if not ownerGroups[ownerKey] then
            ownerGroups[ownerKey] = {}
        end
        
        -- Find if same pet name + mutation + traits already exists
        local found = false
        for _, existing in ipairs(ownerGroups[ownerKey]) do
            if existing.name == pet.name and 
               existing.mutation == pet.mutation and
               table.concat(existing.traits or {}, ",") == table.concat(pet.traits or {}, ",") then
                existing.count = existing.count + 1
                found = true
                break
            end
        end
        
        if not found then
            table.insert(ownerGroups[ownerKey], {
                name = pet.name,
                mutation = pet.mutation,
                mutationEmoji = pet.mutationEmoji,
                traits = pet.traits,
                traitEmojis = pet.traitEmojis,
                genValue = pet.genValue,
                count = 1,
                imageUrl = pet.imageUrl,
                isDuel = pet.isDuel
            })
        end
    end
    
    return ownerGroups
end

-- ========== WEBSOCKET ==========
local function connectWS()
    while true do
        local success, result = pcall(function() return WebSocket.connect(WS_URL) end)
        if success and result then
            ws = result
            print("[WS] Connected!")
            ws.OnClose:Connect(function()
                ws = nil
                task.wait(5)
                connectWS()
            end)
            break
        else
            task.wait(5)
        end
    end
end
spawn(connectWS)

local function sendToWS(data)
    if not ws then return end
    local payload = {
        jobid = data.jobId,
        players = data.playerCount,
        petName = data.petName,
        money = data.moneyPerSecond,
        inDuel = data.inDuel,
        mutation = data.mutation,
        traits = data.traits
    }
    local json = HttpService:JSONEncode(payload)
    local encrypted = scramble(json)
    pcall(function() ws:Send(encrypted) end)
end

-- ========== DISCORD WEBHOOK WITH PER-OWNER EMBEDS ==========
local TIER_WEBHOOKS = { PEAK = WEBHOOK_PEAK, HIGH = WEBHOOK_HIGH, LOW = WEBHOOK_LOW }
local TIER_NAMES = { PEAK = "Peaklight", HIGH = "Highlight", LOW = "Lowlight" }

local function buildPetLine(pet)
    local parts = {}
    table.insert(parts, pet.count .. "x")
    if pet.mutationEmoji then
        table.insert(parts, pet.mutationEmoji)
    end
    table.insert(parts, pet.name)
    if pet.traitEmojis and pet.traitEmojis ~= "" then
        table.insert(parts, pet.traitEmojis)
    end
    table.insert(parts, "($" .. formatNumber(pet.genValue) .. "/s)")
    return table.concat(parts, " ")
end

local function sendOwnerEmbed(owner, pets, tier, effectiveDuel, playerCount, jobId, isGlobalDuel)
    local currentTime = os.time()
    local statusIcon = (isGlobalDuel or effectiveDuel) and "✖️" or "✔️"
    
    -- Sort pets by gen value
    table.sort(pets, function(a, b) return a.genValue > b.genValue end)
    
    -- Build best line
    local bestLine = buildPetLine(pets[1])
    
    -- Build others lines
    local otherLines = {}
    for i = 2, #pets do
        table.insert(otherLines, buildPetLine(pets[i]))
    end
    local othersText = (#otherLines > 0) and table.concat(otherLines, "\n") or "No other brainrots"
    
    -- Get thumbnail from best pet
    local thumbnailUrl = pets[1].imageUrl or UNKNOWN_IMAGE
    
    local embedContent = string.format(
        "## Vexis Finder | %s <:vexis_v_logo:1500538391836622999>\n" ..
        "### 👤 %s\n" ..
        "# %s\n" ..
        "\n" ..
        "**Others**\n" ..
        "%s\n" ..
        "\n" ..
        "-# discord.gg/vexis • %s • <t:%d:f>",
        TIER_NAMES[tier],
        owner,
        bestLine,
        othersText,
        statusIcon,
        currentTime
    )
    
    local embed = {
        color = 0x000000,
        description = embedContent,
        thumbnail = { url = thumbnailUrl }
    }
    
    return embed
end

local function sendToDiscord(ownerGroups, tier, playerCount, jobId, isGlobalDuel)
    local req = syn and syn.request or request or http_request
    if not req then return end
    
    -- Send one embed per owner
    for owner, pets in pairs(ownerGroups) do
        -- Check if any pet in this group is in duel
        local hasDuel = false
        for _, pet in ipairs(pets) do
            if pet.isDuel then
                hasDuel = true
                break
            end
        end
        
        local embed = sendOwnerEmbed(owner, pets, tier, hasDuel, playerCount, jobId, isGlobalDuel)
        
        pcall(function()
            req({
                Url = TIER_WEBHOOKS[tier],
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ embeds = { embed } })
            })
        end)
    end
    
    print(string.format("[Discord] Sent %d owner embeds [%s]", #ownerGroups, tier))
end

-- ========== SERVER HOP ==========
local function hopToNewServer()
    print("[HOP] Moving to new server...")
    task.wait(1)
    local placeId = game.PlaceId
    pcall(function()
        TeleportService:Teleport(placeId)
    end)
end

-- ========== MAIN LOOP ==========
print("[Scanner] Started!")
print("[Scanner] Mode: Scan once per server, then hop (per-owner grouping)")
print("[Scanner] WS: " .. WS_URL)

-- Disable textures
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

local serversScanned = 0

while true do
    serversScanned = serversScanned + 1
    local currentJobId = game.JobId
    
    -- Wait for game to load
    if not game:IsLoaded() then game.Loaded:Wait() end
    repeat task.wait() until Players.LocalPlayer
    
    task.wait(SCAN_INTERVAL)
    updateDuelStatus()
    
    local found = scanDebris()
    local playerCount = #Players:GetPlayers()
    
    if #found > 0 then
        -- Group by owner
        local ownerGroups = groupPetsByOwner(found)
        
        -- Find the best pet overall for tier calculation
        local bestPet = found[1]
        for _, pet in ipairs(found) do
            if pet.genValue > bestPet.genValue then
                bestPet = pet
            end
        end
        
        local tier = getTier(bestPet.name, bestPet.genValue)
        
        -- Console log
        print(string.format("[DATA] JobID: %s | Players: %d | Owners: %d | Best: %s | %s/s | InDuel: %s",
            currentJobId, playerCount, #ownerGroups, bestPet.name, formatNumber(bestPet.genValue), 
            tostring(isDuelCooldown or bestPet.isDuel)))
        
        -- Send to WebSocket
        sendToWS({
            jobId = currentJobId,
            playerCount = playerCount,
            petName = bestPet.name,
            moneyPerSecond = formatNumber(bestPet.genValue),
            inDuel = isDuelCooldown or bestPet.isDuel,
            mutation = bestPet.mutation or "None",
            traits = (#(bestPet.traits or {}) > 0) and table.concat(bestPet.traits, ",") or "None"
        })
        
        -- Send to Discord (one embed per owner)
        sendToDiscord(ownerGroups, tier, playerCount, currentJobId, isDuelCooldown)
    else
        print(string.format("[DATA] JobID: %s | Players: %d | No pets found", currentJobId, playerCount))
    end
    
    -- Hop to new server
    hopToNewServer()
end
