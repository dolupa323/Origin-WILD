-- CraftingController.lua
-- Handles crafting request/ack from CraftingUI

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Crafting"))

local CraftingController = {}

local function newRid()
	return tostring(math.random(10000, 99999)) .. "-" .. tostring(os.clock())
end

function CraftingController:Init()
	Net.On(Contracts.Remotes.Ack, function(payload)
		if payload.ok then
			-- Inventory auto-syncs via InventoryService.Sync
			-- CraftingUI availability auto-updates on inventory change
		else
			warn("[Craft] Failed: " .. tostring(payload.code) .. " " .. tostring(payload.msg))
		end
	end)
end

function CraftingController.RequestCraft(recipeName)
	Net.Fire(Contracts.Remotes.Request, {
		rid = newRid(),
		data = {
			recipeName = recipeName,
		},
	})
end

return CraftingController
