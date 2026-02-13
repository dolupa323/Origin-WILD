-- CraftingService.lua
-- Phase1-2
-- Server authoritative crafting: recipe validation, inventory consumption/grant
-- ATOMIC: validate all conditions FIRST, then consume & grant

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Crafting"))
local ItemDB = require(Shared:WaitForChild("ItemDB"))

local InventoryService = require(script.Parent.InventoryService)
local RecipeDB = require(Shared:WaitForChild("RecipeDB"))

local CraftingService = {}

-- lastBenchAt[userId] = { bench = Instance, t = number }
local lastBenchAt = {}

local function now()
	return os.clock()
end

local function ack(rid, ok, code, msg, data)
	return { rid=rid, ok=ok, code=code, msg=msg, data=data }
end

-- ===== Core Helper: Check if recipe outputs can fit in inventory =====
local function canFitOutputs(player, recipe)
	local slots = InventoryService.GetSlots(player)
	if not slots then
		return false
	end

	-- Deep copy slots to simulate placement without mutating real inventory
	local simSlots = {}
	for i = 1, 30 do
		if slots[i] then
			simSlots[i] = { ItemId = slots[i].ItemId, Qty = slots[i].Qty }
		end
	end

	-- Simulate each output placement sequentially
	for _, output in ipairs(recipe.outputs) do
		local itemId = output.id
		local qty = output.qty
		local def = ItemDB[itemId]
		
		if not def then
			return false
		end

		local remaining = qty
		local maxStack = def.MaxStack

		-- 1. Try to fit in existing stacks (simulated)
		for i = 1, 30 do
			local s = simSlots[i]
			if s and s.ItemId == itemId and s.Qty < maxStack then
				local canAdd = math.min(remaining, maxStack - s.Qty)
				s.Qty += canAdd
				remaining -= canAdd
				if remaining <= 0 then break end
			end
		end

		-- 2. Try to fill empty slots (simulated, properly decremented)
		if remaining > 0 then
			for i = 1, 30 do
				if not simSlots[i] then
					local put = math.min(remaining, maxStack)
					simSlots[i] = { ItemId = itemId, Qty = put }
					remaining -= put
					if remaining <= 0 then break end
				end
			end
		end

		if remaining > 0 then
			return false
		end
	end

	return true
end

----- ===== Public API =====

function CraftingService.OpenBench(player: Player, benchInstance: Instance): (boolean, string?)
	if not benchInstance or not benchInstance.Parent then
		return false, Contracts.Error.NOT_FOUND
	end

	lastBenchAt[player.UserId] = {
		bench = benchInstance,
		t = now(),
	}

	return true, Contracts.Error.OK
end

function CraftingService.HandleCraftRequest(player: Player, payload: table): table
	if type(payload) ~= "table" or type(payload.rid) ~= "string" or type(payload.data) ~= "table" then
		return ack(payload and payload.rid or "?", false, Contracts.Error.VALIDATION_FAILED, "bad envelope")
	end

	local rid = payload.rid
	local data = payload.data

	-- Validate recipe
	local recipeName = data.recipeName
	if type(recipeName) ~= "string" then
		return ack(rid, false, Contracts.Error.VALIDATION_FAILED, "missing recipeName")
	end

	local recipe = RecipeDB[recipeName]
	if not recipe then
		return ack(rid, false, Contracts.Error.NOT_FOUND, "unknown recipe")
	end

	-- Validate bench context
	local benchContext = lastBenchAt[player.UserId]
	if not benchContext then
		return ack(rid, false, Contracts.Error.DENIED, "no bench context")
	end

	-- Validate bench proximity (5 seconds or still valid)
	local t = now()
	if t - benchContext.t > 5 then
		return ack(rid, false, Contracts.Error.DENIED, "bench context expired")
	end

	-- Validate distance
	local benchPart = benchContext.bench
	if benchPart and benchPart.Parent then
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local benchPos = benchPart:IsA("Model") and benchPart:GetPivot().Position or benchPart.Position
				local dist = (benchPos - hrp.Position).Magnitude
				if dist > 12 then
					return ack(rid, false, Contracts.Error.OUT_OF_RANGE, "too far from bench")
				end
			end
		end
	end

	----- ===== ATOMIC: Validate ALL before consuming =====

	-- 1. Check if player has all required inputs
	local slots = InventoryService.GetSlots(player)
	if not slots then
		return ack(rid, false, Contracts.Error.INTERNAL_ERROR, "no inventory")
	end

	for _, input in ipairs(recipe.inputs) do
		local have = 0
		for i=1,30 do
			local s = slots[i]
			if s and s.ItemId == input.id then
				have += s.Qty
			end
		end

		if have < input.qty then
			return ack(rid, false, Contracts.Error.NOT_ENOUGH_ITEMS, ("need %s x%d"):format(input.id, input.qty))
		end
	end

	-- 2. Check if outputs can fit (BEFORE consuming)
	if not canFitOutputs(player, recipe) then
		return ack(rid, false, Contracts.Error.INVENTORY_FULL, "inventory_full")
	end

	----- ===== ALL VALIDATED. Now consume & grant =====

	-- Consume inputs (negative qty for InventoryService.AddItem)
	for _, input in ipairs(recipe.inputs) do
		InventoryService.AddItem(player, input.id, -input.qty)
	end

	-- Grant outputs
	for _, output in ipairs(recipe.outputs) do
		InventoryService.AddItem(player, output.id, output.qty)
	end

	return ack(rid, true, Contracts.Error.OK, nil, { recipe=recipeName })
end

----- ===== Init =====

function CraftingService:Init()
	Net.Register({ Contracts.Remotes.Request, Contracts.Remotes.Ack })

	Net.On(Contracts.Remotes.Request, function(player, payload)
		local res = CraftingService.HandleCraftRequest(player, payload)
		Net.Fire(Contracts.Remotes.Ack, player, res)
	end)

	print("[CraftingService] ready")
end

Players.PlayerRemoving:Connect(function(p)
	lastBenchAt[p.UserId] = nil
end)

return CraftingService
