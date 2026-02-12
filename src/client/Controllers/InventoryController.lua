-- InventoryController.lua
-- Client-side inventory state manager with toggle, swap, drop

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Inventory"))

local InventoryController = {}

-- State
local isOpen = false
local inventoryData = {} -- [slotIndex] = { ItemId, Qty }

function InventoryController:Init()
	-- Listen for Sync from Server
	Net.On(Contracts.Remotes.Update, function(payload)
		inventoryData = payload.slots or {}

		-- Update Inventory UI
		local ok1, InventoryUI = pcall(function()
			return require(script.Parent.Parent.UI.InventoryUI)
		end)
		if ok1 and InventoryUI and InventoryUI.Refresh then
			InventoryUI.Refresh(inventoryData)
		end

		-- Update Hotbar UI (slots 1-9)
		local ok2, HotbarUI = pcall(function()
			return require(script.Parent.Parent.UI.HotbarUI)
		end)
		if ok2 and HotbarUI and HotbarUI.Refresh then
			HotbarUI.Refresh(inventoryData)
		end

		-- Update Crafting UI availability
		local ok3, CraftingUI = pcall(function()
			return require(script.Parent.Parent.UI.CraftingUI)
		end)
		if ok3 and CraftingUI and CraftingUI.UpdateInventory then
			CraftingUI.UpdateInventory(inventoryData)
		end
	end)

	-- Toggle with Tab or I
	ContextActionService:BindActionAtPriority(
		"ToggleInventory",
		function(actionName, inputState, inputObject)
			if inputState == Enum.UserInputState.Begin then
				InventoryController.Toggle()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Tab,
		Enum.KeyCode.I
	)

	-- Request initial sync (with delay to ensure server is ready)
	task.delay(1.5, function()
		Net.Fire(Contracts.Remotes.SyncRequest)
	end)
end

function InventoryController.Toggle()
	isOpen = not isOpen
	local ok, InventoryUI = pcall(function()
		return require(script.Parent.Parent.UI.InventoryUI)
	end)
	if ok and InventoryUI then
		InventoryUI.SetVisible(isOpen)
	end

	if isOpen then
		pcall(function()
			game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
	else
		pcall(function()
			game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
		end)
	end
end

function InventoryController.RequestSwap(fromIdx, toIdx)
	Net.Fire(Contracts.Remotes.SwapRequest, { fromIdx = fromIdx, toIdx = toIdx })
end

function InventoryController.RequestDrop(slotIdx)
	Net.Fire(Contracts.Remotes.DropRequest, { slotIdx = slotIdx })
end

function InventoryController.GetData()
	return inventoryData
end

return InventoryController
