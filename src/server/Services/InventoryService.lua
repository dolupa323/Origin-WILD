-- InventoryService.lua
-- Phase0-0-5
-- Server authoritative slot inventory

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local ItemDB = require(Shared.ItemDB)
local Net = require(Shared.Net)
local Contracts = require(Shared.Contracts.Contracts_Inventory)

local SaveService = require(script.Parent.SaveService)

local InventoryService = {}

-------------------------------------------------
-- Helpers (MUST BE AT TOP)
-------------------------------------------------

local function getInv(player)
	return SaveService.Get(player).Inventory.Slots
end

local function cloneSlot(s)
	if not s then return nil end
	return {
		ItemId = s.ItemId,
		Qty = s.Qty,
		Durability = s.Durability,
		Meta = s.Meta,
	}
end

-------------------------------------------------
-- Networking
-------------------------------------------------

function InventoryService.Sync(player)
	local slots = getInv(player)
	Net.Fire(Contracts.Remotes.Update, player, { slots = slots })
end

function InventoryService:Init()
	Net.Register(Contracts.Remotes)
	
	Net.On(Contracts.Remotes.SyncRequest, function(player)
		InventoryService.Sync(player)
	end)
	
	Net.On(Contracts.Remotes.SwapRequest, function(player, payload)
		local from = payload.fromIdx
		local to = payload.toIdx
		if from and to then
			InventoryService.Move(player, from, to)
			InventoryService.Sync(player)
		end
	end)
	
	print("[InventoryService] initialized")
end

-------------------------------------------------
-- Core
-------------------------------------------------

function InventoryService.GetSlots(player)
	return getInv(player)
end

function InventoryService.AddItem(player, itemId, qty)
	local inv = getInv(player)
	local def = ItemDB[itemId]
	if not def then return false end

	-- Handle negative qty (removal)
	if qty < 0 then
		return InventoryService.RemoveItem(player, itemId, -qty)
	end

	-- stack first
	for i=1,30 do
		local s = inv[i]
		if s and s.ItemId == itemId and s.Qty < def.MaxStack then
			local can = math.min(qty, def.MaxStack - s.Qty)
			s.Qty += can
			qty -= can
			if qty <= 0 then 
				InventoryService.Sync(player)
				return true 
			end
		end
	end

	-- empty slot
	for i = 1, 30 do
		if not inv[i] then
			local put = math.min(qty, def.MaxStack)
			inv[i] = { ItemId = itemId, Qty = put }
			qty -= put
			if qty <= 0 then 
				InventoryService.Sync(player)
				return true 
			end
		end
	end

	InventoryService.Sync(player)
	return false
end

function InventoryService.RemoveItem(player, itemId, qty)
	local inv = getInv(player)
	local def = ItemDB[itemId]
	if not def then return false end

	-- Try to remove qty from existing stacks
	local remaining = qty
	for i=1,30 do
		local s = inv[i]
		if s and s.ItemId == itemId then
			local remove = math.min(remaining, s.Qty)
			s.Qty -= remove
			remaining -= remove
			if s.Qty <= 0 then
				inv[i] = nil
			end
			if remaining <= 0 then 
				InventoryService.Sync(player)
				return true 
			end
		end
	end

	InventoryService.Sync(player)
	return false
end

function InventoryService.Move(player, fromIdx, toIdx, qty)
	local inv = getInv(player)

	local a = inv[fromIdx]
	local b = inv[toIdx]

  if fromIdx < 1 or fromIdx > 30 then return false end
  if toIdx < 1 or toIdx > 30 then return false end

	if not a then return false end

	qty = qty or a.Qty
	qty = math.clamp(qty, 1, a.Qty)

	if not b then
		-- move
		inv[toIdx] = { ItemId=a.ItemId, Qty=qty }
		a.Qty -= qty
		if a.Qty <= 0 then inv[fromIdx] = nil end
		return true
	end

	if a.ItemId == b.ItemId then
		local max = ItemDB[a.ItemId].MaxStack
		local can = math.min(qty, max - b.Qty)
		if can <= 0 then return false end

		b.Qty += can
		a.Qty -= can
		if a.Qty <= 0 then inv[fromIdx] = nil end
		return true
	end

	-- swap
	inv[fromIdx], inv[toIdx] = cloneSlot(b), cloneSlot(a)
	InventoryService.Sync(player)
	return true
end

-------------------------------------------------
-- Debug test
-------------------------------------------------

function InventoryService.DebugTest(player)
  InventoryService.AddItem(player, "Pickaxe", 1)
	InventoryService.AddItem(player, "Wood", 150)
	InventoryService.AddItem(player, "Stone", 50)
  local slots = getInv(player)
  print("[InventoryService] slots_len =", #slots, "slots_type =", typeof(slots))

	local inv = getInv(player)
	print(("[InventoryService] loaded slots_len=%d"):format(#slots))
end

-------------------------------------------------
-- Accessors (Phase 1-4-0)
-------------------------------------------------

function InventoryService.GetSlot(player, slotIndex)
	local inv = getInv(player)
	if not inv then return nil end
	local s = inv[slotIndex]
	if not s then return nil end
	
	-- Return clean copy or direct ref? 
	-- For read-only purpose, return simplified structure
	return {
		ItemId = s.ItemId,
		Qty = s.Qty,
		Meta = s.Meta
	}
end

return InventoryService
