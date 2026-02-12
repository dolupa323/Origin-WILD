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

-- Exposed API for other controllers
function HotbarController.ForceRefresh()
	-- Re-select current active slot to fetch updated state
	-- We need to know current active slot. The server knows, but client tracks it via UI or internal state?
	-- HotbarUI has currentActiveSlot. HotbarController doesn't store state yet.
	-- Let's ask UI for current slot or just store it.
	-- Better: Store client-side active slot here.
	local HotbarUI = require(script.Parent.Parent.UI.HotbarUI) -- Lazy
	-- HotbarUI doesn't expose getters.
	-- We need to store state in Controller.
end

-- State
local currentSlot = Config.DEFAULT_ACTIVE

function HotbarController:Init()
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		
		local slot = KeyMap[input.KeyCode]
		if slot then
			print(("[HotbarClient] key=%d -> select(%d)"):format(slot, slot))
			Net.Fire(Contracts.Remotes.Select, { slotIndex = slot })
			currentSlot = slot
		end
	end)

	Net.On(Contracts.Remotes.Ack, function(payload)
		if payload.ok then
			print(("[HotbarClient] Active: Slot %d (Inv: %d) Item: %s x%s"):format(
				payload.activeSlot, payload.invSlot, tostring(payload.itemId), tostring(payload.qty)
			))
			
			currentSlot = payload.activeSlot -- Sync with server ack
			
			-- Update UI
			local HotbarUI = require(script.Parent.Parent.UI.HotbarUI) -- Lazy require or move up
			if HotbarUI.OnSelect then
				HotbarUI.OnSelect(payload.activeSlot, payload.itemId, payload.qty)
			end
		else
			warn(("[HotbarClient] Select Failed: %s"):format(payload.code))
		end
	end)

	-- Initial Sync Request
	task.delay(1.5, function()
		print("[HotbarController] Requesting initial sync...")
		HotbarController.Refresh()
	end)

	print("[HotbarController] ready")
end

function HotbarController.Refresh()
	Net.Fire(Contracts.Remotes.Select, { slotIndex = currentSlot })
end

return HotbarController
