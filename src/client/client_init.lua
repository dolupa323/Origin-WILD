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

	-- Test code removed


-- Phase 1-2 & 1-3 Tests removed

-- === Phase1-4 Hotbar/Use Controllers ===
task.spawn(function()
	-- UI First
	local HotbarUI = require(script.Parent.UI.HotbarUI)
	if HotbarUI.Init then
		HotbarUI:Init()
	end

	local HotbarController = require(script.Parent.Controllers.HotbarController)
	if HotbarController.Init then
		HotbarController:Init()
	end
	
	local UseController = require(script.Parent.Controllers.UseController)
	if UseController.Init then
		UseController:Init()
	end
	
	local InteractController = require(script.Parent.Controllers.InteractController)
	if InteractController.Init then
		InteractController:Init()
	end
end)

return true
