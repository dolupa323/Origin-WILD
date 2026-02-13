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
		return false, Contracts.ErrorCodes.COOLDOWN
	end
	nextGlobalUse[player.UserId] = t + GLOBAL_COOLDOWN

	-- 2. Get Active Item from Hotbar
	local item, invSlot = HotbarService.GetActiveItem(player)
	if not item then
		return false, Contracts.ErrorCodes.NO_ACTIVE_ITEM
	end

	local itemId = item.ItemId

	-- 3. Delegate to EquipService.DispatchUse
	local ctx = {
		player = player,
		aim = aim,
		ResourceNodeService = ResourceNodeService,
		CombatSystem = CombatSystem,
	}
	
	local ok, code, data = EquipService.DispatchUse(itemId, ctx)
	return ok, code, data
end

function UseService:Init()
	-- Register Remotes
	Net.Register({
		Contracts.Remotes.Request,
		Contracts.Remotes.Ack
	})
	
	Net.On(Contracts.Remotes.Request, function(player, payload)
		-- Envelope 검증
		if type(payload) ~= "table" or type(payload.data) ~= "table" then
			Net.Fire(Contracts.Remotes.Ack, player, {
				ok = false,
				code = Contracts.ErrorCodes.VALIDATION_FAILED,
			})
			return
		end

		local aim = payload.data.aim
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
