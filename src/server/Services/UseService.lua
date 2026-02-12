-- UseService.lua
-- Phase 1-4-2
-- Server authoritative Use logic (Consumes HotbarService / Delegates to EquipItems)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Use"))
local HotbarService = require(script.Parent.HotbarService)
local EquipService = require(script.Parent.EquipService)
local ResourceNodeService = require(script.Parent.ResourceNodeService)
local CombatSystem = require(script.Parent.CombatSystem)

local UseService = {}

-- Tunables
local GLOBAL_COOLDOWN = 0.2
local nextGlobalUse = {} -- [userId] = time

local function now()
	return os.clock()
end

function UseService.UseRequest(player, aim)
	-- 1. Global Cooldown Check
	local t = now()
	if nextGlobalUse[player.UserId] and t < nextGlobalUse[player.UserId] then
		print(("[Use] reject code=%s"):format(Contracts.ErrorCodes.COOLDOWN))
		return false, Contracts.ErrorCodes.COOLDOWN
	end
	nextGlobalUse[player.UserId] = t + GLOBAL_COOLDOWN

	-- 2. Get Active Item from Hotbar
	local item, invSlot = HotbarService.GetActiveItem(player)
	if not item then
		print(("[Use] reject code=%s"):format(Contracts.ErrorCodes.NO_ACTIVE_ITEM))
		return false, Contracts.ErrorCodes.NO_ACTIVE_ITEM
	end

	local itemId = item.ItemId
	print(("[Use] request user=%s"):format(player.Name))
	print(("[Use] active item=%s invSlot=%d"):format(itemId, invSlot))

	-- 3. Delegate to EquipService (which loads Item script)
	-- We need to manually construct the context because EquipService doesn't have a standardized "Use" entry point for hotbar items yet
	-- in the previous EquipService implementation.
	-- However, EquipRegistry is inside EquipService. Let's rely on EquipService to dispatch.
	-- *Check EquipService implementation*: It usually handles "Equip/Unequip".
	-- We need to call the Item Module's OnUse directly.
	
	-- Loading Item Module logic (duplicated from EquipService, or exposed by it)
	-- Ideally EquipService should expose `GetItemModule(itemId)`.
	-- Since we don't have that handy, let's require it directly using the same pattern, or ask EquipService.
	
	-- Refactor Note: Ideally EquipService should handle this dispatch.
	-- For Phase 1-4-2, strict DoD: "EquipRegistry.OnUse(player, itemId)"
	-- Let's check if EquipService has `OnUse`.
	
	-- Creating Context for Item.OnUse
	local ctx = {
		player = player,
		aim = aim,
		ResourceNodeService = ResourceNodeService,
		CombatSystem = CombatSystem,
		-- In future: InventoryService, etc.
	}
	
	local ok, code, data = EquipService.DispatchUse(itemId, ctx)
	
	if ok then
		print(("[Use] dispatch handler=%s"):format(data and data.handler or "Unknown"))
	else
		-- If item has no Use handler, maybe it's just a resource?
		-- For now, if dispatch fails (no OnUse), we return OK but do nothing?
		-- Or return FAIL?
		-- If DispatchUse returns false (e.g. no module), fail.
		print(("[Use] dispatch failed code=%s"):format(tostring(code)))
	end

	return ok, code, data
end

function UseService:Init()
	Net.On(Contracts.Remotes.Request, function(player, payload)
		local aim = payload.aim
		local ok, code, data = UseService.UseRequest(player, aim)
		
		Net.Fire(Contracts.Remotes.Ack, player, {
			ok = ok,
			code = code,
			data = data
		})
	end)
	
	print("[UseService] ready")
end

return UseService
