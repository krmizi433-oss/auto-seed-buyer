-- ══════════════════════════════════════
--           version = 12
-- ══════════════════════════════════════

local PREFIXES = {
    seeds = "{",
    items = "\x7F",
    props = "}",
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Event = ReplicatedStorage.SharedModules.Packet.RemoteEvent


local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

game:GetService("SoundService").DescendantAdded:Connect(function(v)
    if v:IsA("Sound") and v.Name == "TemporarySFX" and v.SoundId == "rbxassetid://550209561" then
        v:Stop()
        v.Volume = 0
        v:Destroy()
    end
end)

local function encode(prefix, name)
    assert(#name <= 255, "item name too long: " .. name)
    return buffer.fromstring(prefix .. "\x00" .. string.char(#name) .. name)
end

local function fireAndNotify(prefix, name)
    Event:FireServer(encode(prefix, name))
end

local Window = Rayfield:CreateWindow({
    Name = "Seed/Item/Prop buyer | discord.gg/JWqf2cBzYC",
    LoadingTitle = "discord.gg/JWqf2cBzYC",
    ConfigurationSaving = { Enabled = false },
})

Rayfield:Notify({
    Title = "Suggestions & Missing Items?",
    Content = "Join the Discord — discord.gg/JWqf2cBzYC",
    Duration = 8,
})

-- ══════════════════════════════════════
--              SEED SHOP
-- ══════════════════════════════════════

local SeedTab = Window:CreateTab("Seed Shop", 4483362458)

local seeds = {
    "Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", "Apple",
    "Bamboo", "Corn", "Cactus", "Pineapple", "Mushroom", "Green Bean",
    "Banana", "Grape", "Coconut", "Mango", "Rocket Pop", "Dragon Fruit", "Acorn",
    "Cherry", "Sunflower", "Fire Fern", "Venus Fly Trap", "Pomegranate", "Poison Apple",
    "Venom Spitter", "Moon Bloom", "Hypno Bloom", "Dragon's Breath",
}

local selectedSeeds = {}
local seedDelay = 0.2
local seedLooping = false
local seedThread = nil
local SeedToggle = nil

SeedTab:CreateDropdown({
    Name = "Select Seeds",
    Options = seeds,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "SelectedSeeds",
    Callback = function(selected)
        selectedSeeds = selected
    end,
})

SeedTab:CreateSlider({
    Name = "Buy Delay (seconds)",
    Range = {0.1, 2.0},
    Increment = 0.05,
    CurrentValue = 0.2,
    Flag = "SeedDelay",
    Callback = function(val)
        seedDelay = val
    end,
})

SeedToggle = SeedTab:CreateToggle({
    Name = "Auto Buy Seeds",
    CurrentValue = false,
    Callback = function(state)
        seedLooping = state
        if seedThread then task.cancel(seedThread) seedThread = nil end
        if state then
            seedThread = task.spawn(function()
                while seedLooping do
                    if #selectedSeeds == 0 then task.wait(0.5) continue end
                    for _, name in ipairs(selectedSeeds) do
                        if not seedLooping then return end
                        fireAndNotify(PREFIXES.seeds, name)
                    end
                    task.wait(seedDelay)
                end
            end)
        end
    end,
})

-- ══════════════════════════════════════
--              ITEM SHOP
-- ══════════════════════════════════════

local ItemTab = Window:CreateTab("Item Shop", 4483362458)

local shopItems = {
    "Common Watering Can", "Common Sprinkler", "Uncommon Sprinkler",
    "Rare Sprinkler", "Trowel", "Jump Mushroom", "Speed Mushroom",
    "Shrink Mushroom", "Supersize Mushroom", "Gnome", "Flashbang",
    "Basic Pot", "Legendary Sprinkler", "Teleporter", "Invisibility Mushroom",
    "Super Watering Can", "Super Sprinkler",
}

local selectedShopItems = {}
local itemDelay = 0.2
local itemLooping = false
local itemThread = nil
local ItemToggle = nil

ItemTab:CreateDropdown({
    Name = "Select Items",
    Options = shopItems,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "SelectedShopItems",
    Callback = function(selected)
        selectedShopItems = selected
    end,
})

ItemTab:CreateSlider({
    Name = "Buy Delay (seconds)",
    Range = {0.1, 2.0},
    Increment = 0.05,
    CurrentValue = 0.2,
    Flag = "ItemDelay",
    Callback = function(val)
        itemDelay = val
    end,
})

ItemToggle = ItemTab:CreateToggle({
    Name = "Auto Buy Items",
    CurrentValue = false,
    Callback = function(state)
        itemLooping = state
        if itemThread then task.cancel(itemThread) itemThread = nil end
        if state then
            itemThread = task.spawn(function()
                while itemLooping do
                    if #selectedShopItems == 0 then task.wait(0.5) continue end
                    for _, name in ipairs(selectedShopItems) do
                        if not itemLooping then return end
                        fireAndNotify(PREFIXES.items, name)
                    end
                    task.wait(itemDelay)
                end
            end)
        end
    end,
})

-- ══════════════════════════════════════
--               PROP SHOP
-- ══════════════════════════════════════

local PropTab = Window:CreateTab("Prop Shop", 4483362458)

local props = {
    "Light Crate", "Ladder Crate", "Bench Crate", "Sign Crate",
    "Arch Crate", "Roleplay Crate", "Picture Frame Crate", "Fourth of July Crate", "Bridge Crate",
    "Spring Crate", "Seesaw Crate", "Conveyor Crate", "Owner Door Crate",
    "Bear Trap Crate", "Boombox Crate", "Fence Crate", "Teleporter Pad Crate",
}

local selectedProps = {}
local propDelay = 0.2
local propLooping = false
local propThread = nil
local PropToggle = nil

PropTab:CreateDropdown({
    Name = "Select Props",
    Options = props,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "SelectedProps",
    Callback = function(selected)
        selectedProps = selected
    end,
})

PropTab:CreateSlider({
    Name = "Buy Delay (seconds)",
    Range = {0.1, 2.0},
    Increment = 0.05,
    CurrentValue = 0.2,
    Flag = "PropDelay",
    Callback = function(val)
        propDelay = val
    end,
})

PropToggle = PropTab:CreateToggle({
    Name = "Auto Buy Props",
    CurrentValue = false,
    Callback = function(state)
        propLooping = state
        if propThread then task.cancel(propThread) propThread = nil end
        if state then
            propThread = task.spawn(function()
                while propLooping do
                    if #selectedProps == 0 then task.wait(0.5) continue end
                    for _, name in ipairs(selectedProps) do
                        if not propLooping then return end
                        fireAndNotify(PREFIXES.props, name)
                    end
                    task.wait(propDelay)
                end
            end)
        end
    end,
})

-- ══════════════════════════════════════
--           SEED PACK COLLECTOR
-- ══════════════════════════════════════

local SeedPackTab = Window:CreateTab("Seed Pack Collector", 4483362458)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local spPlayer = Players.LocalPlayer

local SP_TWEEN_SPEED = 14
local SP_COOLDOWN    = 2

local spRunning = false
local spThread  = nil
local SeedPackToggle = nil

local function spTweenTime(from, to)
    local dist = math.max((from - to).Magnitude, 4)
    return dist / SP_TWEEN_SPEED
end

local function spCollectAll()
    local container = workspace:FindFirstChild("Map")
        and workspace.Map:FindFirstChild("SeedPackSpawnServerLocations")

    if not container then
        warn("[SeedPack] SeedPackSpawnServerLocations not found")
        return
    end

    local parts = {}
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("BasePart") then
            table.insert(parts, child)
        end
    end

    if #parts == 0 then
        warn("[SeedPack] No Parts found")
        return
    end

    for _, part in ipairs(parts) do
        if not spRunning then break end

        local character = spPlayer.Character
        if not character then task.wait(0.5) continue end
        local hrp      = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid then task.wait(0.5) continue end

        local prompt = part:FindFirstChildOfClass("ProximityPrompt")
        if not prompt or not prompt.Enabled then
            task.wait(0.2)
            continue
        end

        local info = TweenInfo.new(
            spTweenTime(hrp.Position, part.Position),
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.InOut
        )

        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0

        local tween = TweenService:Create(hrp, info, { CFrame = CFrame.new(part.Position) })
        tween:Play()
        tween.Completed:Wait()

        task.wait(0.1)

        local ok, err = pcall(function()
            fireproximityprompt(prompt)
        end)
        if not ok then
            warn("[SeedPack] fireproximityprompt failed:", err)
        end

        task.wait(SP_COOLDOWN)

        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
    end

    local character = spPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end

    spRunning = false

    Rayfield:Notify({
        Title = "Seed Pack Collector",
        Content = "All seed packs collected.",
        Duration = 3,
    })
end

SeedPackToggle = SeedPackTab:CreateToggle({
    Name = "Auto Collect Seed Packs",
    CurrentValue = false,
    Callback = function(state)
        spRunning = state
        if spThread then task.cancel(spThread) spThread = nil end
        if state then
            spThread = task.spawn(function()
                while spRunning do
                    spCollectAll()
                    if spRunning then task.wait(5) end
                end
            end)
        else
            local character = spPlayer.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = 16
                    humanoid.JumpPower = 50
                end
            end
        end
    end,
})

SeedPackTab:CreateSlider({
    Name = "Cooldown Between Parts (seconds)",
    Range = {0.5, 5},
    Increment = 0.5,
    CurrentValue = 2,
    Flag = "SeedPackCooldown",
    Callback = function(val)
        SP_COOLDOWN = val
    end,
})

SeedPackTab:CreateSlider({
    Name = "Tween Speed (studs/sec)",
    Range = {5, 50},
    Increment = 1,
    CurrentValue = 14,
    Flag = "SeedPackSpeed",
    Callback = function(val)
        SP_TWEEN_SPEED = val
    end,
})

-- ══════════════════════════════════════
--              SETTINGS
-- ══════════════════════════════════════

local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateParagraph({
    Title = "Suggestions & Missing Items?",
    Content = "Join the Discord for suggestions, bug reports, or missing seeds/items.\ndiscord.gg/JWqf2cBzYC",
})

-- ══════════════════════════════════════
--              ANTI AFK
-- ══════════════════════════════════════

local afkThread = nil
local AfkToggle = nil

local function doJump()
    local character = game.Players.LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

AfkToggle = SettingsTab:CreateToggle({
    Name = "Anti AFK",
    CurrentValue = false,
    Callback = function(state)
        if state then
            if afkThread then task.cancel(afkThread) end
            afkThread = task.spawn(function()
                while true do
                    task.wait(math.random(270, 450))
                    doJump()
                end
            end)
        else
            if afkThread then
                task.cancel(afkThread)
                afkThread = nil
            end
        end
    end,
})

-- ══════════════════════════════════════
--           STOP ALL LOOPS
-- ══════════════════════════════════════

local function stopAll()
    seedLooping = false
    itemLooping = false
    propLooping = false
    spRunning   = false

    if seedThread then task.cancel(seedThread) seedThread = nil end
    if itemThread then task.cancel(itemThread) itemThread = nil end
    if propThread then task.cancel(propThread) propThread = nil end
    if spThread   then task.cancel(spThread)   spThread   = nil end
    if afkThread  then task.cancel(afkThread)  afkThread  = nil end

    -- visually flip every toggle off
    if SeedToggle    then SeedToggle:Set(false)     end
    if ItemToggle    then ItemToggle:Set(false)     end
    if PropToggle    then PropToggle:Set(false)     end
    if SeedPackToggle then SeedPackToggle:Set(false) end
    if AfkToggle     then AfkToggle:Set(false)      end

    -- restore movement in case seed pack was mid-tween
    local character = spPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end
end

SettingsTab:CreateButton({
    Name = "Stop All Loops",
    Callback = function()
        stopAll()
        Rayfield:Notify({
            Title = "Loops Stopped",
            Content = "All loops including Anti AFK have been halted.",
            Duration = 3,
        })
    end,
})

-- ══════════════════════════════════════
--           DESTROY / RESPAWN UI
-- ══════════════════════════════════════

SettingsTab:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        stopAll()
        Rayfield:Destroy()
    end,
})

SettingsTab:CreateButton({
    Name = "Respawn UI",
    Callback = function()
        stopAll()
        Rayfield:Destroy()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/krmizi433-oss/auto-seed-buyer/refs/heads/main/seedbuyer.lua"))()
    end,
})
