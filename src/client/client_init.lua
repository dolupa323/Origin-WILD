-- client_init.lua
-- Phase0: client-side controllers will be loaded here later.
-- return true

-- client_init.client.lua
-- 평소엔 return true
-- EquipService DoD 테스트할 때만 아래 블록을 잠깐 켠다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local function rid()
	return tostring(math.random(100000, 999999)) .. "-" .. tostring(os.clock())
end

-- Ack 출력
Net.On("Equip_Ack", function(payload)
	print("[Equip_Ack]", payload.rid, payload.ok, payload.code, payload.msg)
	if payload.data then
		for k, v in pairs(payload.data) do
			print("  data.", k, v)
		end
	end
end)

-- ✅ 테스트 실행: 접속 후 2초 뒤 자동 실행
task.delay(2, function()
	-- 1) Slots[1]에 Pickaxe가 들어갔다고 가정 (원하는 슬롯 번호로 맞춰도 됨)
	Net.Fire("Equip_Request", {
		rid = rid(),
		t = os.clock(),
		data = {
			fromIdx = 12,          -- ⭐ Pickaxe 들어있는 슬롯 번호로 맞춰
			equipSlot = "Tool",
		}
	})

	task.wait(0.5)

	-- 2) Use 1회
	Net.Fire("Equip_Use", {
		rid = rid(),
		t = os.clock(),
		data = {
			equipSlot = "Tool",
		}
	})

	-- 3) 연타로 COOLDOWN 확인
	for _ = 1, 5 do
		task.wait(0.1)
		Net.Fire("Equip_Use", {
			rid = rid(),
			t = os.clock(),
			data = {
				equipSlot = "Tool",
			}
		})
	end
end)

return true
