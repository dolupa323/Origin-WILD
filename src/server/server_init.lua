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

-- === Phase0-7 TEST HARNESS (임시: 테스트 후 삭제 예정) ===
-- 목적: Terrain/지형이 레이를 먼저 맞는 문제를 제거하기 위해,
--       TestInteract를 "플레이어 HRP 기준"으로 근처에 스폰한다.
task.delay(1, function()
	if workspace:FindFirstChild("TestInteract") then return end

	-- 플레이어/캐릭터 준비
	local player = Players:GetPlayers()[1]
	if not player then
		warn("[InteractTest] no players yet")
		return
	end

	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")

	-- 테스트 파트 생성
	local p = Instance.new("Part")
	p.Name = "TestInteract"
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 0.2
	p.Size = Vector3.new(4, 4, 1)

	--  HRP 기준: 정면 8m + 위로 2m (지형/바닥 선행 히트 최소화)
local pos = hrp.Position + Vector3.new(0, 6, 0)
p.CFrame = CFrame.new(pos)


	p.Parent = workspace

	p:SetAttribute("InteractType", "TestBox")
	CollectionService:AddTag(p, "Interactable")

	print("[InteractTest] spawned TestInteract near player at", p.Position)
end)

-- === Phase0-8 TEST HARNESS (임시: 테스트 후 삭제) ===
task.delay(2, function()
	-- 플레이어 HRP 근처에 Wood 드랍 하나 생성
	local Players = game:GetService("Players")
	local p = Players:GetPlayers()[1]
	if not p then return end

	local char = p.Character or p.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")

	local DropService = require(script.Parent.Services.DropService)
	DropService.SpawnDrop(hrp.Position + Vector3.new(0, 0, 6), "Stone", 1, p.UserId)
end)

-- === Phase0-9 TEST HARNESS (임시: 테스트 후 삭제) ===
task.delay(3, function()
	local Players = game:GetService("Players")
	local p = Players:GetPlayers()[1]
	if not p then return end

	local EffectService = require(script.Parent.Services.EffectService)
	EffectService.Apply(p, "Burn", 5, 1) -- 5초, 1스택
end)

-- === Phase0-10 TEST HARNESS (임시: 테스트 후 삭제) ===
task.delay(2, function()
	if workspace:FindFirstChild("TestDummy") then return end

	local player = Players:GetPlayers()[1]
	if not player then
		warn("[CombatTest] no players yet")
		return
	end

	local char = player.Character or player.CharacterAdded:Wait()
	local phrp = char:WaitForChild("HumanoidRootPart")

	-- ✅ Model로 생성 (정석)
	local dummy = Instance.new("Model")
	dummy.Name = "TestDummy"

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Anchored = true
	hrp.CanCollide = false
	hrp.Parent = dummy

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Anchored = true
	head.CanCollide = false
	head.Parent = dummy

	-- ✅ 플레이어 근처에 스폰 (랜덤 스폰 문제 제거)
	hrp.Position = phrp.Position + Vector3.new(0, 0, -8)
	head.Position = hrp.Position + Vector3.new(0, 2, 0)

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 100
	hum.Health = 100
	hum.Parent = dummy

	-- ✅ 태그는 "맞는 파트"에도 붙인다 (hit.Instance가 hrp/head로 올 수 있음)
	CollectionService:AddTag(dummy, "Entity")
	CollectionService:AddTag(hrp, "Entity")
	CollectionService:AddTag(head, "Entity")

	CollectionService:AddTag(dummy, "Damageable")
	CollectionService:AddTag(hrp, "Damageable")
	CollectionService:AddTag(head, "Damageable")

	-- ✅ HP Attribute는 “Damageable로 판정되는 파트”에도 복제(CombatSystem이 어디를 읽을지 모름)
	hrp:SetAttribute("HP", 100)
	hrp:SetAttribute("MaxHP", 100)
	head:SetAttribute("HP", 100)
	head:SetAttribute("MaxHP", 100)

	dummy.Parent = workspace

	print("[CombatTest] spawned TestDummy near player at", hrp.Position)
end)

-- === Phase0-11 TEST HARNESS (AI Framework test) ===
task.delay(5, function()
	if workspace:FindFirstChild("TestAI") then return end

	local player = Players:GetPlayers()[1]
	if not player then
		warn("[AITest] no players yet")
		return
	end

	local char = player.Character or player.CharacterAdded:Wait()
	local phrp = char:WaitForChild("HumanoidRootPart")

	local AIService = require(script.Parent.Services.AIService)

	-- Spawn AI near player (offset)
	local spawnPos = phrp.Position + Vector3.new(0, 0, 12) -- 12 studs ahead
	local aiModel = AIService.SpawnAI(spawnPos, player, {
		Name = "TestAI",
		MaxHP = 50,
		Faction = "Enemy",
	})

	if aiModel then
		print("[AITest] spawned AI, should begin Chase→Attack cycle")
		print("[AITest] watch server logs for:")
		print("  [AI] TestAI Chase: dist=...")
		print("  [AI] TestAI Attack: hit=...")
	end
end)

-- === Phase1-1 TEST HARNESS (ResourceNode test) ===
task.delay(6, function()
	if workspace:FindFirstChild("TestTree") then return end

	local player = Players:GetPlayers()[1]
	if not player then
		warn("[ResourceNodeTest] no players yet")
		return
	end

	local char = player.Character or player.CharacterAdded:Wait()
	local phrp = char:WaitForChild("HumanoidRootPart")

	local ResourceNodeService = require(script.Parent.Services.ResourceNodeService)

	-- Spawn Tree near player
	local treePos = phrp.Position + Vector3.new(5, 0, 0)
	local tree = ResourceNodeService.SpawnResourceNode(treePos, "Tree", {})

	-- Spawn Stone
	local stonePos = phrp.Position + Vector3.new(-5, 0, 0)
	local stone = ResourceNodeService.SpawnResourceNode(stonePos, "Stone", {})

	if tree and stone then
		print("[ResourceNodeTest] spawned Tree and Stone")
		print("[ResourceNodeTest] interact with E key to harvest")
		print("[ResourceNodeTest] watch for:")
		print("  [ResourceNode] hit Tree hp ...")
		print("  [ResourceNode] depleted Tree")
		print("  [Drop] spawned Wood ...")
	end
end)

-- === Phase1-2 TEST HARNESS (Crafting test) ===
task.delay(7, function()
	if workspace:FindFirstChild("TestCraftBench") then return end

	local player = Players:GetPlayers()[1]
	if not player then
		warn("[CraftBenchTest] no players yet")
		return
	end

	local char = player.Character or player.CharacterAdded:Wait()
	local phrp = char:WaitForChild("HumanoidRootPart")

	-- 1. Add minimal initial inventory items for testing (with empty slot for output)
	local InventoryService = require(script.Parent.Services.InventoryService)
	-- Only add what's needed for crafting, leave slots empty for output
	local SaveService = require(script.Parent.Services.SaveService)
	local inv = SaveService.Get(player).Inventory.Slots
	
	-- Clear any existing items
	for i=1,30 do inv[i] = nil end
	
	-- Add exact amounts needed for test
	InventoryService.AddItem(player, "Wood", 3)
	InventoryService.AddItem(player, "Stone", 2)
	print("[CraftBenchTest] cleared inventory and added Wood x3, Stone x2 (empty slots available)")

	-- 2. Create TestCraftBench part
	local bench = Instance.new("Part")
	bench.Name = "TestCraftBench"
	bench.Size = Vector3.new(4, 1, 4)
	bench.Anchored = true
	bench.CanCollide = false
	bench.BrickColor = BrickColor.new("Dark stone grey")
	bench.Position = phrp.Position + Vector3.new(0, 0, 8)
	bench:SetAttribute("InteractType", "CraftBench")
	CollectionService:AddTag(bench, "Interactable")
	bench.Parent = workspace

	print("[CraftBenchTest] spawned bench near player at", bench.Position)
	print("[CraftBenchTest] interact with E key to open bench")
	print("[CraftBenchTest] then client sends Craft_Request")
end)

-- === Phase1-3 TEST HARNESS (Tool/Weapon test) ===
task.delay(8, function()
	if workspace:FindFirstChild("Phase1-3Test") then return end

	local player = Players:GetPlayers()[1]
	if not player then
		warn("[Phase1-3Test] no players yet")
		return
	end

	local char = player.Character or player.CharacterAdded:Wait()
	local phrp = char:WaitForChild("HumanoidRootPart")

	-- 1. Clear and equip tools
	local InventoryService = require(script.Parent.Services.InventoryService)
	local EquipService = require(script.Parent.Services.EquipService)
	local SaveService = require(script.Parent.Services.SaveService)
	local save = SaveService.Get(player)
	local inv = save.Inventory.Slots
	local equip = save.Inventory.Equip

	-- Clear inventory
	for i=1,30 do inv[i] = nil end
	for k,v in pairs(equip) do equip[k] = nil end

	-- Add tools: StoneAxe, StonePickaxe, StoneSword
	InventoryService.AddItem(player, "StoneAxe", 1)
	InventoryService.AddItem(player, "StonePickaxe", 1)
	InventoryService.AddItem(player, "StoneSword", 1)
	print("[Phase1-3Test] added StoneAxe, StonePickaxe, StoneSword to inventory")

	-- Auto-equip StoneSword to Weapon slot for testing
	equip["Weapon"] = { ItemId="StoneSword", Qty=1 }
	print("[Phase1-3Test] auto-equipped StoneSword to Weapon slot")

	-- 2. Spawn ResourceNode (for Axe/Pickaxe test)
	local resourceNodeService = require(script.Parent.Services.ResourceNodeService)
	local nodeSpawn = phrp.Position + Vector3.new(0, 0, -5)
	local testNode = resourceNodeService.SpawnResourceNode(nodeSpawn, "Stone")
	if testNode then
		print("[Phase1-3Test] spawned ResourceNode at", testNode:GetPrimaryPartCFrame().Position)
	end

	-- 3. Mark this test session
	local marker = Instance.new("BoolValue")
	marker.Name = "Phase1-3Test"
	marker.Parent = workspace
	game:GetService("Debris"):AddItem(marker, 120) -- Remove after 2 minutes

	print("[Phase1-3Test] setup complete")
	print("[Phase1-3Test] Test instructions:")
	print("  1. Equip StoneAxe and use (E+Click) on stone node")
	print("  2. Equip StonePickaxe and use on stone node")
	print("  3. Equip StoneSword and use (E+Click) on dummy")
	print("  Expected: [ResourceNode] hit/depleted, [Combat] hit logs")
end)

return true
