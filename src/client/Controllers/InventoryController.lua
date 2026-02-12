-- InventoryController.lua
-- Phase 1-6 (UX Improvement)
-- Manages client-side inventory state and input.

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Inventory"))

local InventoryController = {}

-- State
local isOpen = false
local inventoryData = {} -- [slotIndex] = { ItemId, Qty, ... }

function InventoryController:Init()
	-- Listen for Sync from Server
	Net.On(Contracts.Remotes.Update, function(payload)
		inventoryData = payload.slots
		print("[InventoryController] updated local data")
		
		-- Notify UI
		local InventoryUI = require(script.Parent.Parent.UI.InventoryUI)
		InventoryUI.Refresh(inventoryData)
		
		-- Also update Hotbar if it needs it
		local HotbarUI = require(script.Parent.Parent.UI.HotbarUI)
		if HotbarUI.Refresh then
			HotbarUI.Refresh(inventoryData)
		end
	end)

	-- Input Toggle with ContextActionService
	ContextActionService:BindActionAtPriority(
		"ToggleInventory",
		function(actionName, inputState, inputObject)
			if inputState == Enum.UserInputState.Begin then
				InventoryController.Toggle()
				return Enum.ContextActionResult.Sink -- Prevent default Roblox behavior (e.g. PlayerList)
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Tab,
		Enum.KeyCode.I
	)

	-- Request initial sync
	-- Adding a small delay to ensure UI is ready
	task.delay(1, function()
		Net.Fire(Contracts.Remotes.SyncRequest)
	end)

	print("[InventoryController] ready")
end

function InventoryController.Toggle()
	isOpen = not isOpen
	local InventoryUI = require(script.Parent.Parent.UI.InventoryUI)
	InventoryUI.SetVisible(isOpen)
	
	-- Toggle Mouse
	UserInputService.MouseIconEnabled = isOpen
	if isOpen then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		-- Disable PlayerList to avoid clutter if Tab was used
		pcall(function() game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
	else
		-- Don't force LockCenter, let standard controls or other controllers decide
		-- UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter 
		pcall(function() game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true) end)
	end
end

function InventoryController.RequestSwap(from, to)
	Net.Fire(Contracts.Remotes.SwapRequest, { fromIdx = from, toIdx = to })
end

return InventoryController
