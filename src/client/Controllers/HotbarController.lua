-- HotbarController.lua
-- Phase 1-4-3
-- Client Hotbar Input (1..9 key press)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Hotbar"))
local Config = require(Shared:WaitForChild("HotbarConfig"))
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local HotbarController = {}

-- Pre-cache UI module (avoid repeated require in event handlers)
local HotbarUI = require(script.Parent.Parent.UI.HotbarUI)

-- Key mapping
local KeyMap = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

-- State
local currentSlot = Config.DEFAULT_ACTIVE

function HotbarController:Init()
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		
		local slot = KeyMap[input.KeyCode]
		if slot then
			Net.Fire(Contracts.Remotes.Select, { slotIndex = slot })
			currentSlot = slot
		end
	end)

	Net.On(Contracts.Remotes.Ack, function(payload)
		if payload.ok then
			currentSlot = payload.activeSlot -- Sync with server ack
			
			-- Update UI
			if HotbarUI and HotbarUI.OnSelect then
				HotbarUI.OnSelect(payload.activeSlot, payload.itemId, payload.qty)
			end
		else
			warn(("[HotbarClient] Select Failed: %s"):format(payload.code))
		end
	end)

	-- Initial Sync Request
	task.delay(1.5, function()
		HotbarController.Refresh()
	end)
end

function HotbarController.Refresh()
	Net.Fire(Contracts.Remotes.Select, { slotIndex = currentSlot })
end

return HotbarController
