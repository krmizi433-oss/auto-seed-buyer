-- ══════════════════════════════════════
--           VERSION CONFIG
--     Update these when game patches
-- ══════════════════════════════════════

local PREFIXES = {
    seeds = "{",       -- 0x7B
    items = "\x7F",    -- 0x7F
    props = "}",       -- 0x7D
}

-- ══════════════════════════════════════
--              CORE
-- ══════════════════════════════════════

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Event = ReplicatedStorage.SharedModules.Packet.RemoteEvent

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local function encode(prefix, name)
    assert(#name <= 255, "item name too long: " .. name)
    return buffer.fromstring(prefix .. "\x00" .. string.char(#name) .. name)
end

local notifyEnabled = false

local function fireAndNotify(prefix, name)
    Event:FireServer(encode(prefix, name))
    if notifyEnabled then
        Rayfield:Notify({
            Title = "Purchased",
            Content = name,
            Duration = 1.5,
        })
    end
end

-- ══════════════════════════════════════

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
    "Banana", "Grape", "Coconut", "Mango", "Dragon Fruit", "Acorn",
    "Cherry", "Sunflower", "Venus Fly Trap", "Pomegranate", "Poison Apple",
    "Venom Spitter", "Moon Bloom", "Hypno Bloom", "Dragon's Breath",
}

local selectedSeeds = {}
local seedDelay = 0.2
local seedLooping = false
local seedThread = nil

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

SeedTab:CreateToggle({
    Name = "Auto Buy Seeds",
    CurrentValue = false,
    Callback = function(state)
        seedLooping = state
        if seedThread then task.cancel(seedThread) seedThread = nil end
        if state then
            seedThread = task.spawn(function()
                while seedLooping do
                    if #selectedSeeds == 0 then
                        task.wait(0.5)
                        continue
                    end
                    for _, name in ipairs(selectedSeeds) do
                        if not seedLooping then return end
                        fireAndNotify(PREFIXES.seeds, name)
                        task.wait(seedDelay)
                    end
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

ItemTab:CreateToggle({
    Name = "Auto Buy Items",
    CurrentValue = false,
    Callback = function(state)
        itemLooping = state
        if itemThread then task.cancel(itemThread) itemThread = nil end
        if state then
            itemThread = task.spawn(function()
                while itemLooping do
                    if #selectedShopItems == 0 then
                        task.wait(0.5)
                        continue
                    end
                    for _, name in ipairs(selectedShopItems) do
                        if not itemLooping then return end
                        fireAndNotify(PREFIXES.items, name)
                        task.wait(itemDelay)
                    end
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
    "Arch Crate", "Roleplay Crate", "Picture Frame Crate", "Bridge Crate",
    "Spring Crate", "Seesaw Crate", "Conveyor Crate", "Owner Door Crate",
    "Bear Trap Crate", "Fence Crate", "Teleporter Pad Crate",
}

local selectedProps = {}
local propDelay = 0.2
local propLooping = false
local propThread = nil

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

PropTab:CreateToggle({
    Name = "Auto Buy Props",
    CurrentValue = false,
    Callback = function(state)
        propLooping = state
        if propThread then task.cancel(propThread) propThread = nil end
        if state then
            propThread = task.spawn(function()
                while propLooping do
                    if #selectedProps == 0 then
                        task.wait(0.5)
                        continue
                    end
                    for _, name in ipairs(selectedProps) do
                        if not propLooping then return end
                        fireAndNotify(PREFIXES.props, name)
                        task.wait(propDelay)
                    end
                end
            end)
        end
    end,
})

-- ══════════════════════════════════════
--              SETTINGS
-- ══════════════════════════════════════

local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- ══════════════════════════════════════
--              ANTI AFK
-- ══════════════════════════════════════

local afkThread = nil

local function doJump()
    local character = game.Players.LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

SettingsTab:CreateToggle({
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

SettingsTab:CreateButton({
    Name = "Stop All Loops",
    Callback = function()
        seedLooping = false
        itemLooping = false
        propLooping = false
        if seedThread then task.cancel(seedThread) seedThread = nil end
        if itemThread then task.cancel(itemThread) itemThread = nil end
        if propThread then task.cancel(propThread) propThread = nil end
        if afkThread then task.cancel(afkThread) afkThread = nil end
        Rayfield:Notify({
            Title = "Loops Stopped",
            Content = "All loops including Anti AFK have been halted.",
            Duration = 3,
        })
    end,
})

-- ══════════════════════════════════════
--           NOTIFICATION LOG
-- ══════════════════════════════════════

SettingsTab:CreateToggle({
    Name = "Buy Notifications",
    CurrentValue = false,
    Callback = function(state)
        notifyEnabled = state
    end,
})

-- ══════════════════════════════════════
--           DESTROY / RESPAWN UI
-- ══════════════════════════════════════

SettingsTab:CreateButton({
    Name = "⭐ Suggestions & Missing Items — Join Discord",
    Callback = function()
        Rayfield:Notify({
            Title = "Suggestions & Missing Items?",
            Content = "Join the Discord — discord.gg/JWqf2cBzYC",
            Duration = 8,
        })
    end,
})

SettingsTab:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        seedLooping = false
        itemLooping = false
        propLooping = false
        if seedThread then task.cancel(seedThread) seedThread = nil end
        if itemThread then task.cancel(itemThread) itemThread = nil end
        if propThread then task.cancel(propThread) propThread = nil end
        if afkThread then task.cancel(afkThread) afkThread = nil end
        Rayfield:Destroy()
    end,
})

SettingsTab:CreateButton({
    Name = "Respawn UI",
    Callback = function()
        seedLooping = false
        itemLooping = false
        propLooping = false
        if seedThread then task.cancel(seedThread) seedThread = nil end
        if itemThread then task.cancel(itemThread) itemThread = nil end
        if propThread then task.cancel(propThread) propThread = nil end
        if afkThread then task.cancel(afkThread) afkThread = nil end
        Rayfield:Destroy()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/krmizi433-oss/auto-seed-buyer/refs/heads/main/seedbuyer.lua"))()
    end,
})
