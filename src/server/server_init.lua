-- server_init.server.lua
-- Phase0: services/systems will be loaded here in strict order.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- 1. Base Services
local SaveService = require(script.Parent.Services.SaveService)
local InventoryService = require(script.Parent.Services.InventoryService)
if InventoryService.Init then
	InventoryService:Init()
end
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
end
print("[UseService] ready")

-- 12. FeedbackService (UX)
local FeedbackService = require(script.Parent.Services.FeedbackService)
if FeedbackService.Init then
	FeedbackService:Init()
end
print("[FeedbackService] ready")

-- 13. CaptureService (Palworld)
local CaptureService = require(script.Parent.Services.CaptureService)
if CaptureService.Init then
	CaptureService:Init()
end
print("[CaptureService] ready")

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

	-- Wait for Data Load (Fixes Race Condition)
	if not SaveService.WaitForData(player) then
		warn("[Playground] Data load timeout for " .. player.Name)
		return
	end

	-- Clear Inventory for fresh test
	local save = SaveService.Get(player)
	if save and save.Inventory and save.Inventory.Slots then
		for i = 1, 30 do
			save.Inventory.Slots[i] = nil
		end
		print("[Playground] Cleared inventory for " .. player.Name)
	end

	-- Base Position (Facing direction of player, at player's foot level)
	local spawnCFrame = hrp.CFrame * CFrame.new(0, -3, -15) 
	local origin = spawnCFrame.Position
	
	-- 1. Equipment Station (Platform) - MASSIVE floor for distance
	local equipZone = Instance.new("Part")
	equipZone.Name = "Zone_Equip"
	equipZone.Size = Vector3.new(120, 1, 120)
	equipZone.CFrame = spawnCFrame * CFrame.new(0, -0.5, -20) -- Center set ahead
	equipZone.Anchored = true
	equipZone.Color = Color3.fromRGB(45, 45, 50)
	equipZone.Material = Enum.Material.Slate
	equipZone.Parent = workspace
	createLabel(equipZone, "--- PHASE 1 TEST SANDBOX (Distance Corrected) ---", Color3.new(1, 1, 0))
	
	-- 2. Safe Zone: Left (Trees)
	local treeZonePos = origin + (spawnCFrame.RightVector * -20)
	for i = 1, 3 do
		local pos = treeZonePos + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
		local tree = ResourceNodeService.SpawnResourceNode(pos, "Tree")
		if tree and tree.PrimaryPart then
			createLabel(tree.PrimaryPart, "🌲 Tree", Color3.new(0, 1, 0))
		end
	end
	
	-- 3. Safe Zone: Right (Stones)
	local stoneZonePos = origin + (spawnCFrame.RightVector * 20)
	for i = 1, 3 do
		local pos = stoneZonePos + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
		local stone = ResourceNodeService.SpawnResourceNode(pos, "Stone")
		if stone and stone.PrimaryPart then
			createLabel(stone.PrimaryPart, "🪨 Stone", Color3.new(0.6, 0.6, 0.6))
		end
	end
	
	-- 4. Passive Combat Zone: Forward (Dummy)
	local dummyPos = origin + (spawnCFrame.LookVector * 15)
	local dummy = Instance.new("Model")
	dummy.Name = "TestDummy"
	local dPart = Instance.new("Part")
	dPart.Name = "HumanoidRootPart"
	dPart.Size = Vector3.new(2, 6, 2)
	dPart.Position = dummyPos + Vector3.new(0, 3, 0)
	dPart.Anchored = true
	dPart.Color = Color3.new(0.8, 0.2, 0.2)
	dPart.Parent = dummy
	dummy.Parent = workspace
	
	local EntityService = require(script.Parent.Services.EntityService)
	EntityService.CreateEntity(dummy, { HP = 100, MaxHP = 100, Faction = "Neutral" })
	CollectionService:AddTag(dummy, "Damageable")
	CollectionService:AddTag(dPart, "Damageable")
	createLabel(dPart, "🎯 Training Dummy (Passive)", Color3.new(1, 1, 1))

	-- 5. DANGER ZONE: FAR Forward (Orc AI)
	-- Moved 50 studs away to avoid detection (Detection Range=30)
	local dangerZonePos = origin + (spawnCFrame.LookVector * 50)
	
	-- Warning Sign
	local warningPart = Instance.new("Part")
	warningPart.Size = Vector3.new(10, 0.1, 4)
	warningPart.Position = dangerZonePos + (spawnCFrame.LookVector * -10)
	warningPart.Anchored = true
	warningPart.CanCollide = false
	warningPart.Transparency = 1
	warningPart.Parent = workspace
	createLabel(warningPart, "⚠️ DANGER: HOSTILE AI AHEAD ⚠️", Color3.new(1, 0, 0))

	local AIService = require(script.Parent.Services.AIService)
	local ai = AIService.SpawnAI(dangerZonePos, player, { Name = "OrcAI" })
	if ai then
		createLabel(ai.PrimaryPart, "👹 Aggressive AI (Level 1)", Color3.new(1, 0, 0))
	end
	
	-- 6. Loot & Craft Zone (Spawn Area)
	local lootPos = origin + (spawnCFrame.LookVector * -8)
	DropService.SpawnDrop(lootPos + (spawnCFrame.RightVector * -4), "Wood", 10)
	DropService.SpawnDrop(lootPos + (spawnCFrame.RightVector * 4), "Stone", 10)
	
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

	-- Give Items
	InventoryService.AddItem(player, "StoneAxe", 1)
	InventoryService.AddItem(player, "StonePickaxe", 1)
	InventoryService.AddItem(player, "StoneSword", 1)
	InventoryService.AddItem(player, "WildSphere", 10)
	HotbarService.Select(player, 1)

	print("[Playground] Setup Complete. Danger zone is 50 studs away!")
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		SetupTestPlayground(player)
	end)
end)

return true
