-- server_init.server.lua
-- Phase0: services/systems will be loaded here in strict order.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- 1. Base Services
local SaveService = require(script.Parent.Services.SaveService)
local InventoryService = require(script.Parent.Services.InventoryService)
print("[InventoryService] ready")

-- 2. EquipService
local EquipService = require(script.Parent.Services.EquipService)
if EquipService.Init then
	EquipService:Init()
else
	warn("[EquipService] missing Init()")
end
print("[EquipService] ready")

-- 3. InteractService (Phase 0-7)
local InteractService = require(script.Parent.Services.InteractService)
if InteractService.Init then
	InteractService:Init()
else
	warn("[InteractService] missing Init()")
end
print("[InteractService] ready")

-- 4. DropService (Phase 0-8)
local DropService = require(script.Parent.Services.DropService)
if DropService.Init then
	DropService:Init()
else
	warn("[DropService] missing Init()")
end
print("[DropService] ready")

-- 5. EffectService (Phase 0-9)
local EffectService = require(script.Parent.Services.EffectService)
if EffectService.Init then
	EffectService:Init()
else
	warn("[EffectService] missing Init()")
end
print("[EffectService] ready")

-- 6. CombatSystem (Phase 0-10)
local CombatSystem = require(script.Parent.Services.CombatSystem)
if CombatSystem.Init then
	CombatSystem:Init()
else
	warn("[CombatSystem] missing Init()")
end
print("[CombatSystem] ready")

-- 7. AIService (Phase 0-11)
local AIService = require(script.Parent.Services.AIService)
if AIService.Init then
	AIService:Init()
else
	warn("[AIService] missing Init()")
end
print("[AIService] ready")

-- 8. ResourceNodeService (Phase 1-1)
local ResourceNodeService = require(script.Parent.Services.ResourceNodeService)
if ResourceNodeService.Init then
	ResourceNodeService:Init()
else
	warn("[ResourceNodeService] missing Init()")
end
print("[ResourceNodeService] ready")

-- 9. CraftingService (Phase 1-2)
local CraftingService = require(script.Parent.Services.CraftingService)
if CraftingService.Init then
	CraftingService:Init()
else
	warn("[CraftingService] missing Init()")
end
print("[CraftingService] ready")

-- 10. HotbarService (Phase 1-4-1)
local HotbarService = require(script.Parent.Services.HotbarService)
if HotbarService.Init then
	HotbarService:Init()
else
	warn("[HotbarService] missing Init()")
end
print("[HotbarService] ready")

-- 11. UseService (Phase 1-4-2)
local UseService = require(script.Parent.Services.UseService)
if UseService.Init then
	UseService:Init()
else
	warn("[UseService] missing Init()")
end
print("[UseService] ready")

-- === Phase 1 Test Playground ===
local function createLabel(parent, text, color)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.CanvasSize = Vector2.new(200, 50)
	sg.Parent = parent
	
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or Color3.new(1, 1, 1)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.FredokaOne
	lbl.Parent = sg
	return sg
end

local function SetupTestPlayground(player)
	print("[Playground] Setting up Phase 1 Test Area for " .. player.Name)
	
	-- Wait for Character
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")
	task.wait(1)

	-- Base Position (Facing direction of player, at player's foot level)
	local spawnCFrame = hrp.CFrame * CFrame.new(0, -3, -20) -- 20 studs in front, 3 studs down (feet)
	local origin = spawnCFrame.Position
	
	-- 1. Equipment Station (Platform) - Make it big and bright so it's visible
	local equipZone = Instance.new("Part")
	equipZone.Name = "Zone_Equip"
	equipZone.Size = Vector3.new(40, 1, 40)
	equipZone.CFrame = spawnCFrame * CFrame.new(0, -0.5, 0)
	equipZone.Anchored = true
	equipZone.Color = Color3.fromRGB(60, 60, 70)
	equipZone.Material = Enum.Material.Concrete
	equipZone.Parent = workspace
	createLabel(equipZone, "--- PHASE 1 TEST SANDBOX ---", Color3.new(1, 1, 0))
	
	print("[Playground] Spawned at: " .. tostring(origin))
	
	-- Give Items
	InventoryService.AddItem(player, "StoneAxe", 1)
	InventoryService.AddItem(player, "StonePickaxe", 1)
	InventoryService.AddItem(player, "StoneSword", 1)
	HotbarService.Select(player, 1)
	
	-- 2. Tree Zone (Left)
	local treeZonePos = origin + (spawnCFrame.RightVector * -15)
	for i = 1, 3 do
		local pos = treeZonePos + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
		local tree = ResourceNodeService.SpawnResourceNode(pos, "Tree")
		if tree and tree.PrimaryPart then
			createLabel(tree.PrimaryPart, "🌲 Tree", Color3.new(0, 1, 0))
		end
	end
	
	-- 3. Stone Zone (Right)
	local stoneZonePos = origin + (spawnCFrame.RightVector * 15)
	for i = 1, 3 do
		local pos = stoneZonePos + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
		local stone = ResourceNodeService.SpawnResourceNode(pos, "Stone")
		if stone and stone.PrimaryPart then
			createLabel(stone.PrimaryPart, "🪨 Stone", Color3.new(0.6, 0.6, 0.6))
		end
	end
	
	-- 4. Combat Zone (Forward)
	local combatZonePos = origin + (spawnCFrame.LookVector * 10)
	
	-- Dummy
	local dummy = Instance.new("Model")
	dummy.Name = "TestDummy"
	local dPart = Instance.new("Part")
	dPart.Name = "HumanoidRootPart"
	dPart.Size = Vector3.new(2, 6, 2)
	dPart.Position = combatZonePos + Vector3.new(0, 3, 0)
	dPart.Anchored = true
	dPart.Color = Color3.new(0.8, 0.2, 0.2)
	dPart.Parent = dummy
	dummy.Parent = workspace
	
	local EntityService = require(script.Parent.Services.EntityService)
	EntityService.CreateEntity(dummy, { HP = 100, MaxHP = 100, Faction = "Enemy" })
	CollectionService:AddTag(dummy, "Damageable")
	CollectionService:AddTag(dPart, "Damageable")
	createLabel(dPart, "🎯 Target Dummy", Color3.new(1, 0, 0))
	
	-- AI (Active)
	local AIService = require(script.Parent.Services.AIService)
	local ai = AIService.SpawnAI(combatZonePos + (spawnCFrame.RightVector * 8), player, { Name = "OrcAI" })
	if ai then
		createLabel(ai.PrimaryPart, "👹 Aggressive AI", Color3.new(1, 0.2, 0.2))
	end
	
	-- 5. Loot & Craft Zone (Near)
	local lootPos = origin + (spawnCFrame.LookVector * -5)
	DropService.SpawnDrop(lootPos + (spawnCFrame.RightVector * -3), "Wood", 10)
	DropService.SpawnDrop(lootPos + (spawnCFrame.RightVector * 3), "Stone", 10)
	
	-- Craft Bench
	local bench = Instance.new("Part")
	bench.Name = "CraftBench"
	bench.Size = Vector3.new(6, 3, 3)
	bench.Position = lootPos + (spawnCFrame.LookVector * -5)
	bench.Anchored = true
	bench.Color = Color3.fromRGB(120, 80, 50)
	bench.Parent = workspace
	bench:SetAttribute("InteractType", "CraftBench")
	CollectionService:AddTag(bench, "Interactable")
	createLabel(bench, "🔨 Crafting Bench", Color3.new(1, 1, 1))

	print("[Playground] Setup Complete in front of player!")
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		SetupTestPlayground(player)
	end)
end)

return true
