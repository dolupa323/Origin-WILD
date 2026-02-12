-- HotbarService.lua
-- Phase 1-4-1
-- Server authoritative Hotbar logic

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Hotbar"))
local Config = require(Shared:WaitForChild("HotbarConfig"))
local InventoryService = require(script.Parent.InventoryService)
local Players = game:GetService("Players")

local HotbarService = {}

-- State per player
-- state[userId] = {
--   activeSlot = 1..9,
--   map = { [1..9] = invSlotIndex or nil } --- Phase 1: Direct 1-1 mapping for simplicity or implementation choice
-- }
-- For Phase 1-4-1 requirement: "map[slot] -> invSlotIndex 조회"
-- However, strict requirement implies we need a way to map hotbar slots to inventory slots.
-- *For this phase*, to keep it simple and testable without UI drag-drop:
-- We will assume Hotbar Slot X maps to Inventory Slot X (1-9).
-- If user wants custom mapping later, we add Hotbar_SetMap.
-- Current Logic: Hotbar Slot i == Inventory Slot i.

local state = {}

local function getState(player)
	local uid = player.UserId
	if not state[uid] then
		state[uid] = {
			activeSlot = Config.DEFAULT_ACTIVE,
		}
	end
	return state[uid]
end

function HotbarService.GetActiveSlot(player)
	return getState(player).activeSlot
end

-- Get item in active hotbar slot
function HotbarService.GetActiveItem(player)
	local s = getState(player)
	local hotbarSlot = s.activeSlot
	
	-- Map hotbar slot to inventory slot (1:1 for now)
	local invSlot = hotbarSlot 
	
	local item = InventoryService.GetSlot(player, invSlot)
	return item, invSlot
end

function HotbarService.Select(player, slotIndex)
	-- 1. Validate
	if type(slotIndex) ~= "number" then
		return false, Contracts.ErrorCodes.INTERNAL_ERROR
	end
	
	if slotIndex < 1 or slotIndex > Config.HOTBAR_SIZE then
		print(("[Hotbar] reject code=%s slot=%s"):format(Contracts.ErrorCodes.OUT_OF_RANGE, tostring(slotIndex)))
		return false, Contracts.ErrorCodes.OUT_OF_RANGE
	end

	-- 2. Update State
	local s = getState(player)
	s.activeSlot = slotIndex
	
	-- 3. Get Inventory Info
	local invSlot = slotIndex -- 1:1 mapping
	local item = InventoryService.GetSlot(player, invSlot)
	
	local itemId = item and item.ItemId
	local qty = item and item.Qty

	-- Log Success
	print(("[Hotbar] select user=%s slot=%d"):format(player.Name, slotIndex))
	if item then
		print(("[Hotbar] active item user=%s invSlot=%d item=%s qty=%d"):format(
			player.Name, invSlot, itemId, qty
		))
	end

	return true, Contracts.ErrorCodes.OK, {
		activeSlot = slotIndex,
		invSlot = invSlot,
		itemId = itemId,
		qty = qty
	}
end

function HotbarService:Init()
	-- Register Remotes
	Net.Register({
		Contracts.Remotes.Select,
		Contracts.Remotes.Ack
	})
	
	Net.On(Contracts.Remotes.Select, function(player, payload)
		local slot = payload.slotIndex
		local ok, code, data = HotbarService.Select(player, slot)
		
		Net.Fire(Contracts.Remotes.Ack, player, {
			ok = ok,
			code = code,
			activeSlot = data and data.activeSlot,
			invSlot = data and data.invSlot,
			itemId = data and data.itemId,
			qty = data and data.qty
		})
	end)

	Players.PlayerRemoving:Connect(function(player)
		state[player.UserId] = nil
	end)

	print("[HotbarService] ready")
end

return HotbarService
