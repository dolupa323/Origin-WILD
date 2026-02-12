-- server_init.server.lua
-- Phase0: services/systems will be loaded here in strict order.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- 1. Base Services
require(script.Parent.Services.SaveService)
require(script.Parent.Services.InventoryService)
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

	-- Base Position (offset from player spawn)
	local origin = hrp.Position + Vector3.new(0, 0, -20)
	
	-- 1. Equipment Station
	local equipZone = Instance.new("Part")
	equipZone.Name = "Zone_Equip"
	equipZone.Size = Vector3.new(10, 1, 10)
	equipZone.Position = origin + Vector3.new(0, -1, 0)
	equipZone.Anchored = true
	equipZone.Color = Color3.fromRGB(50, 50, 50)
	equipZone.Parent = workspace
	createLabel(equipZone, "Equipment (Check Hotbar)", Color3.new(1, 0.8, 0))
	
	-- Give Items
	InventoryService.AddItem(player, "StoneAxe", 1)
	InventoryService.AddItem(player, "StonePickaxe", 1)
	InventoryService.AddItem(player, "StoneSword", 1)
	HotbarService.Select(player, 1) -- Auto select Axe
	
	-- 2. Tree Zone (Left)
	local treeZonePos = origin + Vector3.new(-15, 0, 0)
	for i = 1, 3 do
		local pos = treeZonePos + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
		local tree = ResourceNodeService.SpawnResourceNode(pos, "Tree")
		if tree then
			local labelPart = tree.PrimaryPart:Clone()
			labelPart.Size = Vector3.new(4, 0.1, 4)
			labelPart.Position = tree.PrimaryPart.Position + Vector3.new(0, 3, 0)
			labelPart.Transparency = 1
			labelPart.CanCollide = false
			labelPart.Parent = tree
			createLabel(labelPart, "Tree (HP:50)", Color3.new(0, 1, 0))
		end
	end
	
	-- 3. Stone Zone (Right)
	local stoneZonePos = origin + Vector3.new(15, 0, 0)
	for i = 1, 3 do
		local pos = stoneZonePos + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
		local stone = ResourceNodeService.SpawnResourceNode(pos, "Stone")
		if stone then
			local labelPart = stone.PrimaryPart:Clone()
			labelPart.Size = Vector3.new(4, 0.1, 4)
			labelPart.Position = stone.PrimaryPart.Position + Vector3.new(0, 3, 0)
			labelPart.Transparency = 1
			labelPart.CanCollide = false
			labelPart.Parent = stone
			createLabel(labelPart, "Stone (HP:40)", Color3.new(0.5, 0.5, 0.5))
		end
	end
	
	-- 4. Combat Zone (Forward)
	local combatZonePos = origin + Vector3.new(0, 0, -20)
	
	-- Dummy
	local dummy = Instance.new("Model")
	dummy.Name = "TestDummy"
	local dPart = Instance.new("Part")
	dPart.Name = "HumanoidRootPart"
	dPart.Size = Vector3.new(2, 5, 2)
	dPart.Position = combatZonePos
	dPart.Anchored = true
	dPart.Color = Color3.new(1, 0, 0)
	dPart.Parent = dummy
	-- Assuming EntityService is available or needs to be required
	local EntityService = require(script.Parent.Services.EntityService) -- Added this line, assuming it's needed
	EntityService.CreateEntity(dummy, { HP = 100, MaxHP = 100, Faction = "Enemy" })
	CollectionService:AddTag(dummy, "Damageable")
	CollectionService:AddTag(dPart, "Damageable")
	dummy.Parent = workspace
	createLabel(dPart, "Dummy (HP:100)", Color3.new(1, 0, 0))
	
	-- AI (Active)
	local AIService = require(script.Parent.Services.AIService)
	local ai = AIService.SpawnAI(combatZonePos + Vector3.new(10, 0, 0), "TestAI")
	if ai then
		createLabel(ai.PrimaryPart, "AI Attacker", Color3.new(1, 0, 0))
	end
	
	-- 5. Loot & Craft Zone (Back)
	local lootPos = origin + Vector3.new(0, 0, 10)
	DropService.SpawnDrop(lootPos + Vector3.new(-2, 0, 0), "Wood", 5)
	DropService.SpawnDrop(lootPos + Vector3.new(2, 0, 0), "Stone", 5)
	
	local lootZone = Instance.new("Part")
	lootZone.Name = "Zone_Loot"
	lootZone.Size = Vector3.new(8, 0.1, 4)
	lootZone.Position = lootPos
	lootZone.Anchored = true
	lootZone.Transparency = 1
	lootZone.CanCollide = false
	lootZone.Parent = workspace
	createLabel(lootZone, "Loot (Press E)", Color3.new(0, 1, 1))
	
	-- Craft Bench
	local bench = Instance.new("Part")
	bench.Name = "CraftBench"
	bench.Size = Vector3.new(4, 2, 2)
	bench.Position = lootPos + Vector3.new(0, 1, 5)
	bench.Anchored = true
	bench.Color = Color3.fromRGB(139, 69, 19)
	bench.Parent = workspace
	bench:SetAttribute("InteractType", "CraftBench")
	CollectionService:AddTag(bench, "Interactable")
	createLabel(bench, "Craft Bench (Press E)", Color3.new(1, 1, 1))

	print("[Playground] Setup Complete!")
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		SetupTestPlayground(player)
	end)
end)

return true
