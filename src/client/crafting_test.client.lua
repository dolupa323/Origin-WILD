-- crafting_test.client.lua
-- Phase1-2
-- Test harness for Crafting system (run from client_init)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local function rid()
	return tostring(math.random(100000, 999999)) .. "-" .. tostring(os.clock())
end

print("[CraftingTest] client ready")

-- Listen for Ack
Net.On("Craft_Ack", function(payload)
	print("[Craft_Ack]", "ok="..tostring(payload.ok), "code="..tostring(payload.code), "msg="..tostring(payload.msg))
	if payload.data then
		for k, v in pairs(payload.data) do
			print("  data."..k, v)
		end
	end
end)

-- Test sequence
task.delay(8, function()
	print("--- [TEST] Crafting: StoneAxe ---")

	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")

	-- 1. Interact with bench first (E key simulation)
	local bench = workspace:WaitForChild("TestCraftBench")
	local benchDir = (bench.Position - hrp.Position).Unit

	print("[CraftingTest] step 1: Interact with bench (E key)")
	Net.Fire("Interact_Request", {
		rid = rid(),
		t = os.clock(),
		data = { aim = { dir = benchDir } }
	})

	-- 2. Wait for bench context to be established
	task.wait(0.5)

	-- 3. Send Craft_Request for StoneAxe
	print("[CraftingTest] step 2: Craft_Request StoneAxe x1")
	Net.Fire("Craft_Request", {
		rid = rid(),
		t = os.clock(),
		data = {
			recipeName = "StoneAxe",
		}
	})

	-- 4. Another test: insufficient items
	task.wait(1)
	print("[CraftingTest] step 3: test insufficient items (no materials again)")
	Net.Fire("Craft_Request", {
		rid = rid(),
		t = os.clock(),
		data = {
			recipeName = "StoneAxe",
		}
	})
end)

return true
