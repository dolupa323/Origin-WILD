-- InventoryService.lua
-- Phase0-0-5
-- Server authoritative slot inventory

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDB = require(ReplicatedStorage.Code.Shared.ItemDB)

local SaveService = require(script.Parent.SaveService)

local InventoryService = {}

-------------------------------------------------
-- Helpers
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
			if qty <= 0 then return true end
		end
	end

	-- empty slot
	for i=1,30 do
		if not inv[i] then
			local put = math.min(qty, def.MaxStack)
			inv[i] = { ItemId=itemId, Qty=put }
			qty -= put
			if qty <= 0 then return true end
		end
	end

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
			if remaining <= 0 then return true end
		end
	end

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
	return true
end

-------------------------------------------------
-- Debug test
-------------------------------------------------

function InventoryService.DebugTest(player)
  InventoryService.AddItem(player, "Pickaxe", 1)
	InventoryService.AddItem(player, "Wood", 150)
	InventoryService.AddItem(player, "Stone", 50)
  local inv = getInv(player)
  print("[InventoryService] slots_len =", #inv, "slots_type =", typeof(inv))

	local inv = getInv(player)

print("[InventoryService] dump first 30 slots")
for i = 1, 30 do
	local s = inv[i]
	if s then
		print(("slot[%d] = %s x%d"):format(i, s.ItemId, s.Qty))
	else
		print(("slot[%d] = <empty>"):format(i))
	end
end

end

-------------------------------------------------
-- Auto test on join (phase0 only)
-------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	task.wait(1)
	InventoryService.DebugTest(player)
end)

return InventoryService
