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

-- RecipeDB (inline)
local RecipeDB = {
	StoneAxe = {
		inputs = { {id="Wood", qty=3}, {id="Stone", qty=2} },
		outputs = { {id="StoneAxe", qty=1} },
		time = 0,
	},
	StonePickaxe = {
		inputs = { {id="Wood", qty=2}, {id="Stone", qty=3} },
		outputs = { {id="StonePickaxe", qty=1} },
		time = 0,
	},
}

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
		print("[Crafting] canFitOutputs: no slots")
		return false 
	end

	-- Simulate each output: can it fit?
	for _, output in ipairs(recipe.outputs) do
		local itemId = output.id
		local qty = output.qty
		local def = ItemDB[itemId]
		
		if not def then
			print(("[Crafting] canFitOutputs: %s not in ItemDB"):format(itemId))
			return false
		end

		local remaining = qty
		local maxStack = def.MaxStack

		-- 1. Try to fit in existing stacks
		for i=1,30 do
			local s = slots[i]
			if s and s.ItemId == itemId then
				local canAdd = maxStack - s.Qty
				if canAdd > 0 then
					remaining -= math.min(remaining, canAdd)
					if remaining <= 0 then break end
				end
			end
		end

		-- 2. Try to fit in empty slots
		if remaining > 0 then
			local emptyCount = 0
			for i=1,30 do
				if not slots[i] then
					emptyCount += 1
				end
			end
			
			-- Each empty slot can hold maxStack items
			local canFit = emptyCount * maxStack
			remaining -= math.min(remaining, canFit)
		end

		-- If anything left, cannot fit
		if remaining > 0 then
			print(("[Crafting] canFitOutputs: cannot fit %s x%d (remaining=%d)"):format(itemId, qty, remaining))
			return false
		end
	end

	print("[Crafting] canFitOutputs: all outputs fit ✓")
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

	print(("[Crafting] OpenBench player=%s bench=%s"):format(player.Name, benchInstance:GetFullName()))
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
				local dist = (benchPart.Position - hrp.Position).Magnitude
				if dist > 12 then
					return ack(rid, false, Contracts.Error.OUT_OF_RANGE, "too far from bench")
				end
			end
		end
	end

	----- ===== ATOMIC: Validate ALL before consuming =====

	-- 1. Check if player has all required inputs
	for _, input in ipairs(recipe.inputs) do
		local slots = InventoryService.GetSlots(player)
		if not slots then
			return ack(rid, false, Contracts.Error.INTERNAL_ERROR, "no inventory")
		end

		local have = 0
		for i=1,30 do
			local s = slots[i]
			if s and s.ItemId == input.id then
				have += s.Qty
			end
		end

		if have < input.qty then
			print(("[Crafting] insufficient %s: have=%d need=%d"):format(input.id, have, input.qty))
			return ack(rid, false, Contracts.Error.NOT_ENOUGH_ITEMS, ("need %s x%d"):format(input.id, input.qty))
		end
	end

	-- 2. Check if outputs can fit (BEFORE consuming)
	if not canFitOutputs(player, recipe) then
		print(("[Crafting] inventory full, cannot fit outputs"))
		return ack(rid, false, Contracts.Error.INVENTORY_FULL, "inventory_full")
	end

	----- ===== ALL VALIDATED. Now consume & grant =====

	-- Consume inputs (negative qty for InventoryService.AddItem)
	for _, input in ipairs(recipe.inputs) do
		InventoryService.AddItem(player, input.id, -input.qty)
		print(("[Crafting] consume %s x%d"):format(input.id, input.qty))
	end

	-- Grant outputs
	for _, output in ipairs(recipe.outputs) do
		local ok = InventoryService.AddItem(player, output.id, output.qty)
		if not ok then
			print(("[Crafting] WARNING: grant failed for %s x%d (but inputs already consumed)"):format(output.id, output.qty))
		end
		print(("[Crafting] grant %s x%d"):format(output.id, output.qty))
	end

	print(("[Crafting] request recipe=%s x1 by %s"):format(recipeName, player.Name))
	return ack(rid, true, Contracts.Error.OK, nil, { recipe=recipeName })
end

----- ===== Init =====

function CraftingService:Init()
	Net.Register(Contracts.Remotes)

	Net.On("Craft_Request", function(player, payload)
		local res = CraftingService.HandleCraftRequest(player, payload)
		Net.Fire("Craft_Ack", player, res)
	end)

	print("[CraftingService] ready")
end

Players.PlayerRemoving:Connect(function(p)
	lastBenchAt[p.UserId] = nil
end)

return CraftingService
