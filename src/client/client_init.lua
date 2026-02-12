local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local function rid()
	return tostring(math.random(100000, 999999)) .. "-" .. tostring(os.clock())
end

Net.On("Combat_Result", function(payload)
	print("[Combat_Result]", payload.rid, payload.ok, payload.code, payload.msg)
	if payload.data then
		for k,v in pairs(payload.data) do
			print("  data.", k, v)
		end
	end
end)

task.delay(4, function()
	print("--- [TEST] Combat_AttackRequest ---")

	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")

	local dummy = workspace:WaitForChild("TestDummy")
	local targetPos = dummy:WaitForChild("HumanoidRootPart").Position

	local dir = (targetPos - hrp.Position).Unit

	Net.Fire("Combat_AttackRequest", {
		rid = rid(),
		t = os.clock(),
		data = {
			kind = "Melee",
			aim = { dir = dir },
		}
	})

	-- 연타 -> cooldown 확인
	for _=1,6 do
		task.wait(0.1)
		Net.Fire("Combat_AttackRequest", {
			rid = rid(),
			t = os.clock(),
			data = { kind="Melee", aim={ dir=Vector3.new(0,0,-1) } }
		})
	end
end)

-- === Phase1-2 Crafting Test (토글) ===
local folder = script.Parent
local m = folder:FindFirstChild("crafting_test")
	or folder:FindFirstChild("crafting_test.client")
	or folder:FindFirstChild("crafting_test.client.lua")

if m then
	require(m)
else
	warn("[client_init] crafting_test module not found")
end

return true
