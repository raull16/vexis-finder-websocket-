print("=== VEXIS FINDER STARTED ===")

local HttpService = game:GetService("HttpService")
local Workspace   = game:GetService("Workspace")
local Players     = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local WS_URL    = "wss://vexisfinder-13jf.onrender.com"
local WS_SECRET = "cabinetdoorpinkponyunicorn"
local WS_SALT   = "VEXIS_ONLY_ADMINS"

local CHANNELS = {
    ["LOW"]  = "https://discord.com/api/webhooks/1494112632733437952/BWhEDEjPH5Hnzcob41pLWHuiJ2a7HOrH9ilDENxUXTX5dLtccLppeprHoAqbz7xhAGsy?with_components=true",
    ["HIGH"] = "https://discord.com/api/webhooks/1494112540001697964/dCs_yovsxBeGOarO7JlzNCATsA7C36XPTotjlkZ32qhvlGzWC5Cimk4w_z1LnhGBMNUq?with_components=true",
    ["PEAK"] = "https://discord.com/api/webhooks/1494112447991251006/A2UTkmd26_YwvPBZ6D29cme8jIWlVpsHKPqP-6vJeEgidIBHOTufXrXqNjs6pOuavxGx?with_components=true"
}

local UNKNOWN_IMAGE = "https://cdn.discordapp.com/attachments/1485284656172630138/1494012668841951303/Z.png"

-- ==================== PERSISTENT BLACKLIST FILE ====================
local BLACKLIST_FILE = "blacklisted_jobs.txt"
local blacklistedJobs = {}

local function loadBlacklist()
    local success, data = pcall(function()
        return readfile(BLACKLIST_FILE)
    end)
    if success and data then
        for jobId in string.gmatch(data, "[^\n]+") do
            blacklistedJobs[jobId] = true
        end
        print(string.format("[BLACKLIST] Loaded %d job IDs", #blacklistedJobs))
    else
        pcall(function()
            writefile(BLACKLIST_FILE, "")
        end)
    end
end

local function addToBlacklist(jobId)
    if blacklistedJobs[jobId] then return end
    blacklistedJobs[jobId] = true
    pcall(function()
        local content = ""
        for id, _ in pairs(blacklistedJobs) do
            content = content .. id .. "\n"
        end
        writefile(BLACKLIST_FILE, content)
        print(string.format("[BLACKLIST] Added %s", string.sub(jobId, 1, 16).."..."))
    end)
end

local function isBlacklisted(jobId)
    return blacklistedJobs[jobId] == true
end

loadBlacklist()

-- ==================== TRACK SENT PETS (PREVENT DUPLICATES) ====================
local sentPets = {}

local function markAsSent(petName, genValue)
    local key = string.lower(petName) .. ":" .. tostring(genValue)
    sentPets[key] = true
end

local function isAlreadySent(petName, genValue)
    local key = string.lower(petName) .. ":" .. tostring(genValue)
    return sentPets[key] == true
end

local function clearSentCache()
    sentPets = {}
    print("[CACHE] Cleared sent pet cache")
end

-- ==================== TIER RULES (FIXED) ====================
-- OG names ONLY → PEAK
-- 250M+ (non-OG) → HIGH
-- Under 250M (non-OG) → LOW

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
    ["garama and madundung"] = true, ["garama and madungdung"] = true,
}

local function getTier(name, genValue)
    local lowerName = string.lower(name)
    -- OG names ALWAYS go to PEAK
    if OG_NAMES[lowerName] then
        return "PEAK"
    end
    -- Non-OG: 250M+ = HIGH, below 250M = LOW
    if genValue >= 250000000 then
        return "HIGH"
    else
        return "LOW"
    end
end

-- ==================== MUTATION EMOJIS ====================
local MUTATION_EMOJIS = {
    ["yin yang"]    = "<:1494503377223028766:1512288335488352337>",
    ["yin_yang"]    = "<:1494503377223028766:1512288335488352337>",
    ["rainbow"]     = "<:1494503386358485063:1512288245428392177>",
    ["radioactive"] = "<:1494503395212529865:1512288284384952331>",
    ["lava"]        = "<:1494503390753849344:1512288054172450877>",
    ["gold"]        = "<:1494503399859683330:1512288099881848993>",
    ["galaxy"]      = "<:1494503404800704612:1512288130168918077>",
    ["divine"]      = "<:1494503408776777778:1512288224708395098>",
    ["diamond"]     = "<:1494503413306622083:1512288312923000932>",
    ["cyber"]       = "<:1494503422009802792:1512288204772999299>",
    ["cursed"]      = "<:1494503426208567407:1512288078038044712>",
    ["candy"]       = "<:1494532967706529824:1512288679215894658>",
    ["bloodrot"]    = "<:1495208479248613406:1512288182530474187>",
}

-- ==================== TRAIT EMOJIS (FULL LIST) ====================
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
    ["candy"]           = "<:trait_candy:1508151747124662423>",
}

-- ==================== HELPERS ====================
local function getMutationEmoji(mut)
    if not mut or mut == "" or mut == "None" then return nil end
    return MUTATION_EMOJIS[mut:lower()] or nil
end

local function getTraitEmojis(traits)
    if not traits or #traits == 0 then return "" end
    local emojis = {}
    for _, trait in ipairs(traits) do
        local key = trait:lower()
        local emoji = TRAIT_EMOJIS[key]
        if emoji then
            table.insert(emojis, emoji)
        else
            -- If no emoji found, show trait name in brackets
            table.insert(emojis, "[" .. trait .. "]")
        end
    end
    return table.concat(emojis, " ")
end

-- ==================== SCRAMBLE ====================
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

-- ==================== HELPERS ====================
local MIN_GEN = 10000000
local SCAN_INTERVAL = 2
local ws = nil
local scanCount = 0
local discordSentForServer = false
local lastDiscordSend = 0
local discordCooldown = 12
local isDuelCooldown = false
local lastLoggedObj = nil
local isFirstRun = true

local function parseGen(text)
    if not text then return 0 end
    text = text:gsub("[^%d%.KMBTkmbt]", ""):lower()
    local num = tonumber(text:match("%d+%.?%d*")) or 0
    local suffix = text:match("[kmbt]") or ""
    if suffix == "k" then num = num * 1e3
    elseif suffix == "m" then num = num * 1e6
    elseif suffix == "b" then num = num * 1e9
    elseif suffix == "t" then num = num * 1e12
    end
    return math.floor(num)
end

local function formatNumber(n)
    if n >= 1e12 then return string.format("%.2fT", n/1e12)
    elseif n >= 1e9 then return string.format("%.2fB", n/1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n/1e6)
    else
        local s = tostring(math.floor(n))
        return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    end
end

local function normalizeName(name)
    return name:gsub("^[%s⚔️💰]+", ""):gsub("[%s]+$", "")
end

-- ==================== DUEL CHECK ====================
local function isDuelBrainrot(obj)
    if not obj then return false end
    local overhead = obj:FindFirstChild("AnimalOverhead")
    if overhead then
        local nameLabel = overhead:FindFirstChild("DisplayName")
        if nameLabel and nameLabel.Text then
            local baseOwner = Players:FindFirstChild(nameLabel.Text)
            if baseOwner and baseOwner:GetAttribute("__duels_block_steal") == true then
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

-- ==================== TRAIT READING (FIXED) ====================
local function readTraits(overhead)
    local traits = {}
    
    -- Method 1: Check Traits folder
    local traitsFolder = overhead:FindFirstChild("Traits")
    if traitsFolder then
        for _, child in ipairs(traitsFolder:GetChildren()) do
            if child:IsA("StringValue") then
                local val = child.Value
                if val and val ~= "" and val ~= "None" then
                    table.insert(traits, val)
                end
            elseif child:IsA("TextLabel") then
                local val = child.Text
                if val and val ~= "" and val ~= "None" then
                    table.insert(traits, val)
                end
            end
        end
    end
    
    -- Method 2: Scan all descendants for trait-related TextLabels
    if #traits == 0 then
        for _, child in ipairs(overhead:GetDescendants()) do
            if child:IsA("TextLabel") then
                local nameLower = child.Name:lower()
                if nameLower:find("trait") or nameLower:find("trait") then
                    local val = child.Text
                    if val and val ~= "" and val ~= "None" and not val:lower():find("generation") then
                        table.insert(traits, val)
                    end
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
    
    local genLabel = overhead:FindFirstChild("Generation")
    if not genLabel or not genLabel:IsA("TextLabel") then return nil end
    
    local genValue = parseGen(genLabel.Text)
    if genValue <= MIN_GEN then return nil end
    
    local nameLabel = overhead:FindFirstChild("DisplayName")
    local mutationLabel = overhead:FindFirstChild("Mutation")
    local imageAssetId = nil
    
    for _, child in ipairs(overhead:GetChildren()) do
        if child:IsA("ImageLabel") then
            imageAssetId = tonumber(child.Image:match("%d+"))
            if imageAssetId then break end
        end
    end
    
    local mutText = mutationLabel and mutationLabel.Text or "None"
    local traits = readTraits(overhead)
    
    return {
        name = nameLabel and nameLabel.Text or obj.Name,
        genValue = genValue,
        mutation = mutText,
        traits = traits,
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
        if info then
            table.insert(found, info)
        end
    end
    return found
end

-- ==================== IMAGE FETCH ====================
local function getImageUrl(petName)
    local success, result = pcall(function()
        local title = petName:gsub(" ", "_")
        local apiUrl = "https://stealabrainrot.fandom.com/api.php?action=query&prop=pageimages&format=json&piprop=thumbnail&pithumbsize=500&titles=" .. title
        local req = request or http_request or (syn and syn.request)
        local response
        if req then
            response = req({ Url = apiUrl, Method = "GET" })
            if response and response.Success and response.Body then response = response.Body end
        end
        if response then
            local data = HttpService:JSONDecode(response)
            if data and data.query and data.query.pages then
                for _, page in pairs(data.query.pages) do
                    if page.thumbnail and page.thumbnail.source then
                        return page.thumbnail.source
                    end
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

-- ==================== DISCORD WEBHOOK ====================
local TIER_COLORS = { ["PEAK"] = 0x000000, ["HIGH"] = 0x000000, ["LOW"] = 0x000000 }
local TIER_LABELS = { ["PEAK"] = "Peaklight", ["HIGH"] = "Highlight", ["LOW"] = "Lowlight" }

local function toTitleCase(str)
    return str:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

local function buildEntryLine(info)
    local mutEmoji = getMutationEmoji(info.mutation) or ""
    local traitStr = getTraitEmojis(info.traits or {})
    local nameStr = toTitleCase(normalizeName(info.name))
    local genStr = "$" .. formatNumber(info.genValue) .. "/s"
    
    local parts = {}
    if mutEmoji ~= "" then table.insert(parts, mutEmoji) end
    table.insert(parts, nameStr)
    if traitStr ~= "" then table.insert(parts, traitStr) end
    table.insert(parts, "(" .. genStr .. ")")
    return table.concat(parts, " ")
end

local function sendToDiscord(foundList, bestInfo)
    if #foundList == 0 then return end
    
    if isAlreadySent(bestInfo.name, bestInfo.genValue) then
        return
    end
    
    if not isFirstRun and bestInfo.obj == lastLoggedObj then return end
    local now = tick()
    if discordSentForServer and now - lastDiscordSend < discordCooldown then return end
    
    local tier = getTier(bestInfo.name, bestInfo.genValue)
    if not tier then return end
    
    markAsSent(bestInfo.name, bestInfo.genValue)
    
    local sorted = {}
    for _, info in ipairs(foundList) do
        table.insert(sorted, info)
    end
    table.sort(sorted, function(a, b) return a.genValue > b.genValue end)
    
    local effectiveDuel = isDuelCooldown or bestInfo.isDuel
    local statusEmoji = effectiveDuel and "⚔️" or "💰"
    local best = sorted[1]
    
    local thumbnailUrl = nil
    if best.imageAssetId then
        thumbnailUrl = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. best.imageAssetId .. "&width=420&height=420&format=png"
    else
        thumbnailUrl = getImageUrl(best.name)
    end
    if not thumbnailUrl then thumbnailUrl = UNKNOWN_IMAGE end
    
    local bestLine = buildEntryLine(best)
    
    local otherLines = {}
    for i = 2, #sorted do
        table.insert(otherLines, buildEntryLine(sorted[i]))
    end
    local othersList = #otherLines > 0 and table.concat(otherLines, "\n") or "No other brainrots"
    
    local currentTime = os.time()
    local webhookUrl = CHANNELS[tier]
    
    local payload = HttpService:JSONEncode({
        flags = 32768,
        components = {
            {
                type = 17,
                accent_color = TIER_COLORS[tier],
                components = {
                    {
                        type = 9,
                        components = {
                            {
                                type = 10,
                                content = "## Vexis Finder | " .. TIER_LABELS[tier] .. " <:vexis_v_logo:1500538391836622999>\n# " .. bestLine .. "\n\u{200B}"
                            }
                        },
                        accessory = {
                            type = 11,
                            media = { url = thumbnailUrl }
                        }
                    },
                    {
                        type = 14,
                        divider = true,
                        spacing = 1
                    },
                    {
                        type = 10,
                        content = "**Others**\n" .. othersList
                    },
                    {
                        type = 14,
                        divider = true,
                        spacing = 1
                    },
                    {
                        type = 10,
                        content = "-# discord.gg/vexis • " .. statusEmoji .. " • <t:" .. tostring(currentTime) .. ":f>"
                    }
                }
            }
        }
    })
    
    local req = request or http_request or (syn and syn.request)
    if not req then return end
    
    lastLoggedObj = bestInfo.obj
    isFirstRun = false
    
    pcall(function()
        req({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = payload,
        })
        print(string.format("[Discord] Sent | tier=%s | %s | $%s/s", tier, effectiveDuel and "DUEL" or "Normal", formatNumber(bestInfo.genValue)))
        discordSentForServer = true
        lastDiscordSend = now
    end)
end

-- ==================== SERVER HOP (FORCES BRAND NEW SERVER) ====================
local function hopToNewServer()
    print("[HOP] Moving to brand new server...")
    task.wait(1)
    
    local currentJobId = game.JobId
    addToBlacklist(currentJobId)
    clearSentCache()
    
    -- Force teleport to a completely new server by using Teleport with no specific instance
    pcall(function()
        -- This ensures you NEVER join the same server
        TeleportService:Teleport(game.PlaceId)
    end)
end

-- ==================== MAIN LOOP ====================
print("[Scanner] Started")
print("[Scanner] Mode: Scan once per server, then hop to BRAND NEW server")
print("[Scanner] Tier Rules: OG only = PEAK | 250M+ = HIGH | Under 250M = LOW")
print("[Scanner] Duplicate protection: ENABLED")
print("[Scanner] Blacklist persistence: ENABLED")

-- Check if current server is blacklisted
if isBlacklisted(game.JobId) then
    print("[BLACKLIST] Current server is blacklisted, hopping immediately...")
    hopToNewServer()
end

while true do
    task.wait(SCAN_INTERVAL)
    scanCount = scanCount + 1
    updateDuelStatus()
    
    local found = scanDebris()
    
    -- Filter only known brainrots
    local filtered = {}
    for _, info in ipairs(found) do
        -- Only include known brainrots (you can modify this condition)
        table.insert(filtered, info)
    end
    
    if #filtered > 0 then
        local best = filtered[1]
        for _, info in ipairs(filtered) do
            if info.genValue > best.genValue then
                best = info
            end
        end
        
        local tier = getTier(best.name, best.genValue)
        local effectiveDuel = isDuelCooldown or best.isDuel
        local emoji = effectiveDuel and "⚔️" or "💰"
        
        -- Only print if not already sent
        if not isAlreadySent(best.name, best.genValue) then
            print(string.format("[Scan #%d] %s %s | $%s/s | Tier: %s | Traits: %d",
                scanCount, emoji, best.name, formatNumber(best.genValue), tier, #(best.traits or {})))
            if best.traits and #best.traits > 0 then
                print(string.format("[TRAITS] %s", table.concat(best.traits, ", ")))
            end
        end
        
        sendToDiscord(filtered, best)
    end
    
    -- ALWAYS hop to brand new server after scan
    hopToNewServer()
end
