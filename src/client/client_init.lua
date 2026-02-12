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
	local UI = script.Parent:WaitForChild("UI")
	local Controllers = script.Parent:WaitForChild("Controllers")

	-- UI First
	local HotbarUI = require(UI:WaitForChild("HotbarUI"))
	if HotbarUI.Init then HotbarUI:Init() end

	local InteractionUI = require(UI:WaitForChild("InteractionUI"))
	if InteractionUI.Init then InteractionUI:Init() end

	local DamageUI = require(UI:WaitForChild("DamageUI"))
	if DamageUI.Init then DamageUI:Init() end
	
	local InventoryUI = require(UI:WaitForChild("InventoryUI"))
	if InventoryUI.Init then InventoryUI:Init() end

	-- Controllers
	local InventoryController = require(Controllers:WaitForChild("InventoryController"))
	if InventoryController.Init then InventoryController:Init() end

	local HotbarController = require(Controllers:WaitForChild("HotbarController"))
	if HotbarController.Init then HotbarController:Init() end
	
	local UseController = require(Controllers:WaitForChild("UseController"))
	if UseController.Init then UseController:Init() end
	
	local InteractController = require(Controllers:WaitForChild("InteractController"))
	if InteractController.Init then InteractController:Init() end
end)

return true
