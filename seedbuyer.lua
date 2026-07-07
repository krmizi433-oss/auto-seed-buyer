-- ══════════════════════════════════════
--           Garden Bot v1.0
--   Buyer + Planter + Harvester
-- ══════════════════════════════════════

local PREFIXES = {
    seeds = "{",
    items = "\x7F",
    props = "}",
}

local Players       = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local HttpService   = game:GetService("HttpService")

local Event = ReplicatedStorage.SharedModules.Packet.RemoteEvent
local lp    = Players.LocalPlayer

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ══════════════════════════════════════
--              CONFIG LAYER
-- ══════════════════════════════════════

local CONFIG_FILE = "gardenbot_config.json"

local defaultConfig = {
    selectedSeeds      = {},
    selectedShopItems  = {},
    selectedProps      = {},
    seedDelay          = 0.2,
    itemDelay          = 0.2,
    propDelay          = 0.2,
    seedPackCooldown   = 2,
    seedPackSpeed      = 14,
}

local function loadConfig()
    if isfile(CONFIG_FILE) then
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end)
        if ok and type(decoded) == "table" then
            for k, v in pairs(defaultConfig) do
                if decoded[k] == nil then decoded[k] = v end
            end
            return decoded
        end
    end
    return defaultConfig
end

local function saveConfig(cfg)
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(cfg)
    end)
    if ok then writefile(CONFIG_FILE, encoded) end
end

local cfg = loadConfig()

-- ══════════════════════════════════════
--              PACKET LAYER
-- ══════════════════════════════════════

-- suppress the seed-buy sound
game:GetService("SoundService").DescendantAdded:Connect(function(v)
    if v:IsA("Sound") and v.Name == "TemporarySFX" and v.SoundId == "rbxassetid://550209561" then
        v:Stop(); v.Volume = 0; v:Destroy()
    end
end)

local function encodeBuy(prefix, name)
    assert(#name <= 255, "item name too long: " .. name)
    return buffer.fromstring(prefix .. "\x00" .. string.char(#name) .. name)
end

local function fireBuy(prefix, name)
    Event:FireServer(encodeBuy(prefix, name))
end

-- sell all crops
local function fireSell()
    Event:FireServer(buffer.fromstring("\xB3\x00'"))
end

-- inventory capacity helpers
local function getFruitCount()
    return lp:GetAttribute("FruitCount") or 0
end

local function getMaxFruitCapacity()
    return lp:GetAttribute("MaxFruitCapacity") or 100
end

local function inventoryFull()
    return getFruitCount() >= getMaxFruitCapacity()
end

-- planter packet helpers
local function f32le(n)
    return string.pack("<f", n)
end

local function buildPlantTag(seedName)
    return string.char(#seedName) .. seedName
end

-- ══════════════════════════════════════
--              PLOT HELPERS
-- ══════════════════════════════════════

local function getMyPlots()
    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then return {} end
    local myPlots = {}
    for _, plot in ipairs(gardens:GetChildren()) do
        local owner = plot:GetAttribute("OwnerUserId")
        if owner == lp.UserId then
            table.insert(myPlots, plot)
        end
    end
    return myPlots
end

local function getPlotArea(plot)
    local visual = plot:FindFirstChild("Visual")
    if not visual then return nil, nil end
    local area = visual:FindFirstChild("GardenTotalArea")
    if not area then return nil, nil end
    return area.Position, area.Size
end

local function randomInPlot(center, size)
    local halfX = (size.X / 2) * 0.9
    local halfZ = (size.Z / 2) * 0.9
    local x = center.X + math.random() * halfX * 2 - halfX
    local z = center.Z + math.random() * halfZ * 2 - halfZ
    return x, z
end

-- ══════════════════════════════════════
--              PLANTER LOGIC
-- ══════════════════════════════════════

local PlantSeeds = {
    "Carrot", "Strawberry", "Blueberry", "Tulip", "Baby Cactus", "Tomato", "Apple",
    "Bamboo", "Corn", "Horned Melon", "Cactus", "Pineapple", "Mushroom", "Green Bean",
    "Banana", "Grape", "Coconut", "Glow Mushroom", "Mango", "Rocket Pop", "Dragon Fruit", "Acorn",
    "Cherry", "Sunflower", "Ghost Pepper", "Fire Fern", "Poison Ivy", "Venus Fly Trap", "Pomegranate", "Poison Apple",
    "Venom Spitter", "Moon Bloom", "Hypno Bloom", "Dragon's Breath", "Mega", "Gold", "Rainbow",
}

local seedQueue    = {}
local plantCount   = 0
local autoPlanting = false
local plantDelay   = 1.5
local plantThread  = nil

local function plantSeed(x, z, seedName)
    local seedInstance = lp.Backpack:FindFirstChild(seedName)
    if not seedInstance then return false, seedName .. " not found in backpack" end

    local payload = buffer.fromstring(
        "\x0A\x00" ..
        f32le(x) ..
        f32le(142.40) ..
        f32le(z) ..
        buildPlantTag(seedName)
    )

    Event:FireServer(payload, { seedInstance })
    return true, string.format("Planted %s at (%.2f, %.2f)", seedName, x, z)
end

local function getActiveSeed()
    for _, name in ipairs(seedQueue) do
        if lp.Backpack:FindFirstChild(name) then return name end
    end
    return nil
end

-- ══════════════════════════════════════
--              HARVESTER LOGIC
-- ══════════════════════════════════════

local harvestCount   = 0
local harvesting     = false
local harvestRunning = false
local harvestDelay   = 0.15

local function getPlantModels(plots)
    local models = {}
    for _, plot in ipairs(plots) do
        local plants = plot:FindFirstChild("Plants")
        if plants then
            for _, child in ipairs(plants:GetChildren()) do
                if child:IsA("Model") then table.insert(models, child) end
            end
        end
    end
    return models
end

local autoSellEnabled = false

local function runHarvestLoop(statusLbl, countLbl, inventoryLbl)
    if harvestRunning then return end
    harvestRunning = true
    local cachedPlots = getMyPlots()

    local function updateInventory()
        local cur = getFruitCount()
        local max = getMaxFruitCapacity()
        inventoryLbl:Set(string.format("Inventory: %d / %d", cur, max))
    end

    while harvesting do
        updateInventory()

        if inventoryFull() then
            if autoSellEnabled then
                fireSell()
                statusLbl:Set("Harvest: full — sold, waiting...")
                Rayfield:Notify({ Title = "Auto Sold", Content = string.format("Inventory full (%d/%d) — sold crops.", getFruitCount(), getMaxFruitCapacity()), Duration = 3, Image = "coins" })
            else
                statusLbl:Set("Harvest: full — waiting for sell...")
            end

            while harvesting and inventoryFull() do
                task.wait(1)
                updateInventory()
                if autoSellEnabled and inventoryFull() then
                    fireSell()
                end
            end

            if not harvesting then break end
            statusLbl:Set("Harvest: space available — resuming")
        end

        if #cachedPlots == 0 then
            cachedPlots = getMyPlots()
            if #cachedPlots == 0 then
                statusLbl:Set("Harvest: no plots — retrying")
                task.wait(2)
                continue
            end
        end

        local models = getPlantModels(cachedPlots)
        if #models == 0 then
            statusLbl:Set("Harvest: no plants found")
            task.wait(2)
        else
            for _, model in ipairs(models) do
                if not harvesting then break end
                if inventoryFull() then break end

                local harvestPart = model:FindFirstChild("HarvestPart", true)
                if harvestPart then
                    local prompt = harvestPart:FindFirstChildOfClass("ProximityPrompt")
                    if prompt then
                        fireproximityprompt(prompt)
                        harvestCount = harvestCount + 1
                        countLbl:Set("Harvested: " .. harvestCount)
                        statusLbl:Set("Harvest: fired " .. model.Name)
                        updateInventory()
                        task.wait(harvestDelay)
                    end
                end
                task.wait()
            end
        end
        task.wait(0.5)
    end

    statusLbl:Set("Harvest: stopped")
    harvestRunning = false
end

-- ══════════════════════════════════════
--              SEED PACK LOGIC
-- ══════════════════════════════════════

local SP_TWEEN_SPEED = cfg.seedPackSpeed
local SP_COOLDOWN    = cfg.seedPackCooldown
local spRunning      = false
local spThread       = nil

local function spTweenTime(from, to)
    local dist = math.max((from - to).Magnitude, 4)
    return dist / SP_TWEEN_SPEED
end

local function spCollectAll()
    local container = workspace:FindFirstChild("Map")
        and workspace.Map:FindFirstChild("SeedPackSpawnServerLocations")
    if not container then warn("[SeedPack] SeedPackSpawnServerLocations not found") return end

    local parts = {}
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("BasePart") then table.insert(parts, child) end
    end
    if #parts == 0 then return end

    for _, part in ipairs(parts) do
        if not spRunning then break end

        local character = lp.Character
        if not character then task.wait(0.5) continue end
        local hrp      = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid then task.wait(0.5) continue end

        local prompt = part:FindFirstChildOfClass("ProximityPrompt")
        if not prompt or not prompt.Enabled then task.wait(0.2) continue end

        local info = TweenInfo.new(spTweenTime(hrp.Position, part.Position), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0

        local tween = TweenService:Create(hrp, info, { CFrame = CFrame.new(part.Position) })
        tween:Play()
        tween.Completed:Wait()
        task.wait(0.1)

        local ok, err = pcall(function() fireproximityprompt(prompt) end)
        if not ok then warn("[SeedPack] fireproximityprompt failed:", err) end

        task.wait(SP_COOLDOWN)
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
    end

    local character = lp.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.WalkSpeed = 16; humanoid.JumpPower = 50 end
    end

    spRunning = false
    Rayfield:Notify({ Title = "Seed Pack Collector", Content = "All seed packs collected.", Duration = 3 })
end

-- ══════════════════════════════════════
--              ANTI AFK
-- ══════════════════════════════════════

local afkThread = nil

local function doJump()
    local character = lp.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
end

-- ══════════════════════════════════════
--              STOP ALL
-- ══════════════════════════════════════

local AllToggles = {}  -- filled after UI is built

local function stopAll()
    seedLooping    = false
    itemLooping    = false
    propLooping    = false
    spRunning      = false
    autoPlanting   = false
    harvesting     = false

    for _, t in ipairs({ seedThread, itemThread, propThread, spThread, plantThread, afkThread }) do
        if t then task.cancel(t) end
    end
    seedThread = nil; itemThread = nil; propThread = nil
    spThread   = nil; plantThread = nil; afkThread = nil

    for _, toggle in ipairs(AllToggles) do
        if toggle then pcall(function() toggle:Set(false) end) end
    end

    local character = lp.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.WalkSpeed = 16; humanoid.JumpPower = 50 end
    end
end

-- ══════════════════════════════════════
--                  UI
-- ══════════════════════════════════════

local Window = Rayfield:CreateWindow({
    Name            = "Garden Bot",
    LoadingTitle    = "Garden Bot",
    LoadingSubtitle = "Buy • Plant • Harvest",
    ConfigurationSaving = { Enabled = false },
    Discord         = { Enabled = false },
    KeySystem       = false,
})

Rayfield:Notify({ Title = "Config Loaded", Content = "Last selections restored.", Duration = 4 })

-- ── Seed Shop ──────────────────────────────────────────────────────────────

local SeedTab = Window:CreateTab("Seed Shop", 4483362458)

local buySeeds      = {
    "Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", "Apple",
    "Bamboo", "Corn", "Cactus", "Pineapple", "Mushroom", "Green Bean",
    "Banana", "Grape", "Coconut", "Mango", "Rocket Pop", "Dragon Fruit", "Acorn",
    "Cherry", "Sunflower", "Fire Fern", "Venus Fly Trap", "Pomegranate", "Poison Apple",
    "Venom Spitter", "Moon Bloom", "Hypno Bloom", "Dragon's Breath",
}
local selectedSeeds = cfg.selectedSeeds
local seedDelay     = cfg.seedDelay
local seedLooping   = false
local seedThread    = nil
local SeedToggle    = nil

local SeedDropdown = SeedTab:CreateDropdown({
    Name = "Select Seeds", Options = buySeeds, CurrentOption = selectedSeeds,
    MultipleOptions = true, Flag = "SelectedSeeds",
    Callback = function(selected) selectedSeeds = selected; cfg.selectedSeeds = selected; saveConfig(cfg) end,
})

SeedTab:CreateButton({
    Name = "Select All Seeds",
    Callback = function()
        selectedSeeds = buySeeds
        cfg.selectedSeeds = buySeeds
        saveConfig(cfg)
        SeedDropdown:Set(buySeeds)
    end,
})

SeedTab:CreateButton({
    Name = "Deselect All Seeds",
    Callback = function()
        selectedSeeds = {}
        cfg.selectedSeeds = {}
        saveConfig(cfg)
        SeedDropdown:Set({})
    end,
})

SeedTab:CreateSlider({
    Name = "Buy Delay (seconds)", Range = {0.1, 2.0}, Increment = 0.05,
    CurrentValue = seedDelay, Flag = "SeedDelay",
    Callback = function(val) seedDelay = val; cfg.seedDelay = val; saveConfig(cfg) end,
})

SeedToggle = SeedTab:CreateToggle({
    Name = "Auto Buy Seeds", CurrentValue = false,
    Callback = function(state)
        seedLooping = state
        if seedThread then task.cancel(seedThread); seedThread = nil end
        if state then
            seedThread = task.spawn(function()
                while seedLooping do
                    if #selectedSeeds == 0 then task.wait(0.5); continue end
                    for _, name in ipairs(selectedSeeds) do
                        if not seedLooping then return end
                        fireBuy(PREFIXES.seeds, name)
                    end
                    task.wait(seedDelay)
                end
            end)
        end
    end,
})

-- ── Item Shop ──────────────────────────────────────────────────────────────

local ItemTab = Window:CreateTab("Item Shop", 4483362458)

local shopItems = {
    "Common Watering Can", "Common Sprinkler", "Uncommon Sprinkler",
    "Rare Sprinkler", "Trowel", "Jump Mushroom", "Speed Mushroom",
    "Shrink Mushroom", "Supersize Mushroom", "Gnome", "Flashbang",
    "Basic Pot", "Legendary Sprinkler", "Teleporter", "Invisibility Mushroom",
    "Super Watering Can", "Super Sprinkler",
}
local selectedShopItems = cfg.selectedShopItems
local itemDelay         = cfg.itemDelay
local itemLooping       = false
local itemThread        = nil
local ItemToggle        = nil

local ItemDropdown = ItemTab:CreateDropdown({
    Name = "Select Items", Options = shopItems, CurrentOption = selectedShopItems,
    MultipleOptions = true, Flag = "SelectedShopItems",
    Callback = function(selected) selectedShopItems = selected; cfg.selectedShopItems = selected; saveConfig(cfg) end,
})

ItemTab:CreateButton({
    Name = "Select All Items",
    Callback = function()
        selectedShopItems = shopItems
        cfg.selectedShopItems = shopItems
        saveConfig(cfg)
        ItemDropdown:Set(shopItems)
    end,
})

ItemTab:CreateButton({
    Name = "Deselect All Items",
    Callback = function()
        selectedShopItems = {}
        cfg.selectedShopItems = {}
        saveConfig(cfg)
        ItemDropdown:Set({})
    end,
})

ItemTab:CreateSlider({
    Name = "Buy Delay (seconds)", Range = {0.1, 2.0}, Increment = 0.05,
    CurrentValue = itemDelay, Flag = "ItemDelay",
    Callback = function(val) itemDelay = val; cfg.itemDelay = val; saveConfig(cfg) end,
})

ItemToggle = ItemTab:CreateToggle({
    Name = "Auto Buy Items", CurrentValue = false,
    Callback = function(state)
        itemLooping = state
        if itemThread then task.cancel(itemThread); itemThread = nil end
        if state then
            itemThread = task.spawn(function()
                while itemLooping do
                    if #selectedShopItems == 0 then task.wait(0.5); continue end
                    for _, name in ipairs(selectedShopItems) do
                        if not itemLooping then return end
                        fireBuy(PREFIXES.items, name)
                    end
                    task.wait(itemDelay)
                end
            end)
        end
    end,
})

-- ── Prop Shop ──────────────────────────────────────────────────────────────

local PropTab = Window:CreateTab("Prop Shop", 4483362458)

local props = {
    "Light Crate", "Ladder Crate", "Bench Crate", "Sign Crate",
    "Arch Crate", "Roleplay Crate", "Picture Frame Crate", "Fourth of July Crate", "Bridge Crate",
    "Spring Crate", "Seesaw Crate", "Conveyor Crate", "Owner Door Crate",
    "Bear Trap Crate", "Boombox Crate", "Fence Crate", "Teleporter Pad Crate",
}
local selectedProps = cfg.selectedProps
local propDelay     = cfg.propDelay
local propLooping   = false
local propThread    = nil
local PropToggle    = nil

local PropDropdown = PropTab:CreateDropdown({
    Name = "Select Props", Options = props, CurrentOption = selectedProps,
    MultipleOptions = true, Flag = "SelectedProps",
    Callback = function(selected) selectedProps = selected; cfg.selectedProps = selected; saveConfig(cfg) end,
})

PropTab:CreateButton({
    Name = "Select All Props",
    Callback = function()
        selectedProps = props
        cfg.selectedProps = props
        saveConfig(cfg)
        PropDropdown:Set(props)
    end,
})

PropTab:CreateButton({
    Name = "Deselect All Props",
    Callback = function()
        selectedProps = {}
        cfg.selectedProps = {}
        saveConfig(cfg)
        PropDropdown:Set({})
    end,
})

PropTab:CreateSlider({
    Name = "Buy Delay (seconds)", Range = {0.1, 2.0}, Increment = 0.05,
    CurrentValue = propDelay, Flag = "PropDelay",
    Callback = function(val) propDelay = val; cfg.propDelay = val; saveConfig(cfg) end,
})

PropToggle = PropTab:CreateToggle({
    Name = "Auto Buy Props", CurrentValue = false,
    Callback = function(state)
        propLooping = state
        if propThread then task.cancel(propThread); propThread = nil end
        if state then
            propThread = task.spawn(function()
                while propLooping do
                    if #selectedProps == 0 then task.wait(0.5); continue end
                    for _, name in ipairs(selectedProps) do
                        if not propLooping then return end
                        fireBuy(PREFIXES.props, name)
                    end
                    task.wait(propDelay)
                end
            end)
        end
    end,
})

-- ── Seed Pack Collector ────────────────────────────────────────────────────

local SeedPackTab    = Window:CreateTab("Seed Pack Collector", 4483362458)
local SeedPackToggle = nil

SeedPackToggle = SeedPackTab:CreateToggle({
    Name = "Auto Collect Seed Packs", CurrentValue = false,
    Callback = function(state)
        spRunning = state
        if spThread then task.cancel(spThread); spThread = nil end
        if state then
            spThread = task.spawn(function()
                while spRunning do
                    spCollectAll()
                    if spRunning then task.wait(0.1) end
                end
            end)
        else
            local character = lp.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid.WalkSpeed = 16; humanoid.JumpPower = 50 end
            end
        end
    end,
})

SeedPackTab:CreateSlider({
    Name = "Cooldown Between Parts (seconds)", Range = {0.5, 5}, Increment = 0.5,
    CurrentValue = SP_COOLDOWN, Flag = "SeedPackCooldown",
    Callback = function(val) SP_COOLDOWN = val; cfg.seedPackCooldown = val; saveConfig(cfg) end,
})

SeedPackTab:CreateSlider({
    Name = "Tween Speed (studs/sec)", Range = {5, 50}, Increment = 1,
    CurrentValue = SP_TWEEN_SPEED, Flag = "SeedPackSpeed",
    Callback = function(val) SP_TWEEN_SPEED = val; cfg.seedPackSpeed = val; saveConfig(cfg) end,
})

-- ── Planter ────────────────────────────────────────────────────────────────

local PlantTab = Window:CreateTab("Planter", "shovel")

local plantStatusLabel, coordLabel, plantCountLabel

PlantTab:CreateSection("Seed Queue")

PlantTab:CreateDropdown({
    Name = "Select Seeds (priority order)", Options = PlantSeeds,
    CurrentOption = {}, MultipleOptions = true,
    Callback = function(selected)
        seedQueue = type(selected) == "table" and selected or { selected }

    end,
})

PlantTab:CreateSection("Manual Plant")

plantStatusLabel = PlantTab:CreateLabel("Status: idle")
coordLabel       = PlantTab:CreateLabel("Last coords: —")

PlantTab:CreateButton({
    Name = "Plant Next Seed in Queue",
    Callback = function()
        if #seedQueue == 0 then
            Rayfield:Notify({ Title = "No Seeds", Content = "Select seeds from the dropdown first", Duration = 4, Image = "alert-triangle" })
            return
        end
        local seedName = getActiveSeed()
        if not seedName then
            Rayfield:Notify({ Title = "Queue Empty", Content = "None of the selected seeds are in your backpack", Duration = 4, Image = "alert-triangle" })
            plantStatusLabel:Set("Status: backpack empty for all selected seeds")
            return
        end
        local plots = getMyPlots()
        local plot  = plots[1]
        if not plot then
            Rayfield:Notify({ Title = "Error", Content = "Plot not found", Duration = 4, Image = "alert-triangle" })
            plantStatusLabel:Set("Status: plot not found")
            return
        end
        local center, size = getPlotArea(plot)
        if not center then
            Rayfield:Notify({ Title = "Error", Content = "GardenTotalArea missing", Duration = 4, Image = "alert-triangle" })
            return
        end
        local x, z    = randomInPlot(center, size)
        local ok, msg = plantSeed(x, z, seedName)
        if ok then
            plantCount = plantCount + 1
            plantStatusLabel:Set("Status: planted " .. seedName .. " ✓")
            coordLabel:Set(string.format("Last coords: %.2f, %.2f", x, z))
            if plantCountLabel then plantCountLabel:Set("Planted: " .. plantCount) end
            Rayfield:Notify({ Title = "Planted", Content = msg, Duration = 2, Image = "check" })
        else
            plantStatusLabel:Set("Status: failed — " .. msg)
            Rayfield:Notify({ Title = "Failed", Content = msg, Duration = 4, Image = "x" })
        end
    end,
})

PlantTab:CreateSection("Auto Plant")

local PlantToggle = nil

PlantTab:CreateSlider({
    Name = "Delay between plants (seconds)", Range = {0.5, 10}, Increment = 0.5,
    CurrentValue = plantDelay,
    Callback = function(val) plantDelay = val end,
})

PlantToggle = PlantTab:CreateToggle({
    Name = "Auto Plant", CurrentValue = false,
    Callback = function(state)
        autoPlanting = state
        if state then
            if #seedQueue == 0 then
                Rayfield:Notify({ Title = "No Seeds", Content = "Select seeds from the dropdown first", Duration = 4, Image = "alert-triangle" })
                autoPlanting = false
                return
            end
            plantStatusLabel:Set("Status: auto-planting...")
            plantThread = task.spawn(function()
                while autoPlanting do
                    local seedName = getActiveSeed()
                    if not seedName then
                        plantStatusLabel:Set("Status: all seeds exhausted — stopped")
                        Rayfield:Notify({ Title = "Queue Exhausted", Content = "No selected seeds remain in backpack", Duration = 5, Image = "check" })
                        autoPlanting = false
                        break
                    end
                    local plots = getMyPlots()
                    local plot  = plots[1]
                    if not plot then
                        plantStatusLabel:Set("Status: plot not found — stopped")
                        autoPlanting = false
                        break
                    end
                    local center, size = getPlotArea(plot)
                    if not center then
                        plantStatusLabel:Set("Status: area missing — stopped")
                        autoPlanting = false
                        break
                    end
                    local x, z    = randomInPlot(center, size)
                    local ok, msg = plantSeed(x, z, seedName)
                    if ok then
                        plantCount = plantCount + 1
                        plantStatusLabel:Set("Status: planting " .. seedName .. " ✓")
                        coordLabel:Set(string.format("Last coords: %.2f, %.2f", x, z))
                        if plantCountLabel then plantCountLabel:Set("Planted: " .. plantCount) end
                    else
                        plantStatusLabel:Set("Status: " .. msg .. " — trying next")
                    end
                    task.wait(plantDelay)
                end
                plantStatusLabel:Set("Status: stopped")
            end)
        else
            if plantThread then task.cancel(plantThread); plantThread = nil end
            plantStatusLabel:Set("Status: idle")
        end
    end,
})

-- ── Harvester ──────────────────────────────────────────────────────────────

local HarvestTab = Window:CreateTab("Harvester", "scissors")
local HarvestToggle = nil
local harvestStatusLabel, harvestCountLabel

HarvestTab:CreateSection("Auto Harvest")

harvestStatusLabel  = HarvestTab:CreateLabel("Harvest: idle")
local inventoryLabel = HarvestTab:CreateLabel("Inventory: —")

HarvestTab:CreateSlider({
    Name = "Delay between harvests (seconds)", Range = {0.05, 2}, Increment = 0.05,
    CurrentValue = harvestDelay,
    Callback = function(val) harvestDelay = val end,
})

HarvestTab:CreateToggle({
    Name = "Auto Sell When Full", CurrentValue = false,
    Callback = function(state) autoSellEnabled = state end,
})

HarvestTab:CreateButton({
    Name = "Sell Now",
    Callback = function()
        fireSell()
        Rayfield:Notify({ Title = "Sold", Content = string.format("Fired sell. Inventory was %d/%d.", getFruitCount(), getMaxFruitCapacity()), Duration = 3, Image = "coins" })
    end,
})

HarvestToggle = HarvestTab:CreateToggle({
    Name = "Auto Harvest", CurrentValue = false,
    Callback = function(state)
        harvesting = state
        if harvesting then
            harvestStatusLabel:Set("Harvest: running...")
            task.spawn(function()
                runHarvestLoop(harvestStatusLabel, harvestCountLabel or harvestStatusLabel, inventoryLabel)
            end)
        else
            harvestStatusLabel:Set("Harvest: stopping...")
        end
    end,
})

-- ── Stats ──────────────────────────────────────────────────────────────────

local StatsTab = Window:CreateTab("Stats", "heart")

StatsTab:CreateSection("Session Stats")

plantCountLabel   = StatsTab:CreateLabel("Planted: 0")
harvestCountLabel = StatsTab:CreateLabel("Harvested: 0")

StatsTab:CreateButton({
    Name = "Reset counters",
    Callback = function()
        plantCount = 0; harvestCount = 0
        plantCountLabel:Set("Planted: 0")
        harvestCountLabel:Set("Harvested: 0")
        Rayfield:Notify({ Title = "Counters reset", Content = "Both counts cleared", Duration = 2, Image = "refresh-cw" })
    end,
})

StatsTab:CreateSection("Plot Info")

StatsTab:CreateButton({
    Name = "Inspect my plot",
    Callback = function()
        local plots = getMyPlots()
        if #plots == 0 then
            Rayfield:Notify({ Title = "No plot found", Content = "OwnerUserId not matched in Gardens", Duration = 4, Image = "alert-triangle" })
            return
        end
        local plot = plots[1]
        local center, size = getPlotArea(plot)
        if not center then
            Rayfield:Notify({ Title = "Missing area part", Content = "GardenTotalArea not found", Duration = 4, Image = "alert-triangle" })
            return
        end
        Rayfield:Notify({
            Title   = "Plot: " .. plot.Name,
            Content = string.format("Center: %.1f, %.1f, %.1f\nSize: %.1f x %.1f", center.X, center.Y, center.Z, size.X, size.Z),
            Duration = 6, Image = "map-pin",
        })
    end,
})

-- ── Settings ───────────────────────────────────────────────────────────────

local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateParagraph({
    Title = "Garden Bot",
    Content = "Buy • Plant • Harvest — all in one script.",
})

local AfkToggle = SettingsTab:CreateToggle({
    Name = "Anti AFK", CurrentValue = false,
    Callback = function(state)
        if state then
            if afkThread then task.cancel(afkThread) end
            afkThread = task.spawn(function()
                while true do task.wait(180); doJump() end
            end)
        else
            if afkThread then task.cancel(afkThread); afkThread = nil end
        end
    end,
})

SettingsTab:CreateButton({
    Name = "Reset Config to Defaults",
    Callback = function()
        cfg = {
            selectedSeeds = {}, selectedShopItems = {}, selectedProps = {},
            seedDelay = 0.2, itemDelay = 0.2, propDelay = 0.2,
            seedPackCooldown = 2, seedPackSpeed = 14,
        }
        saveConfig(cfg)
        Rayfield:Notify({ Title = "Config Reset", Content = "Defaults written. Rejoin to apply.", Duration = 4 })
    end,
})

-- register all toggles for stopAll
AllToggles = { SeedToggle, ItemToggle, PropToggle, SeedPackToggle, PlantToggle, HarvestToggle, AfkToggle }

SettingsTab:CreateButton({
    Name = "Stop All Loops",
    Callback = function()
        stopAll()
        Rayfield:Notify({ Title = "Loops Stopped", Content = "All loops halted.", Duration = 3 })
    end,
})

SettingsTab:CreateButton({
    Name = "Destroy UI",
    Callback = function() stopAll(); Rayfield:Destroy() end,
})

Rayfield:LoadConfiguration()
