-- DropService.lua
-- Phase0-0-8
-- Server authoritative world drops (spawn / pickup / ttl / ownership protect)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ItemDB = require(Shared:WaitForChild("ItemDB"))
local InventoryService = require(script.Parent.InventoryService)

local DropService = {}

-- ===== Tunables =====
local DROP_TAG = "WorldDrop"        -- tag for search/filter
local PICKUP_RADIUS = 10            -- studs
local TTL_SECONDS = 60              -- seconds until auto delete
local OWNER_PROTECT_SECONDS = 3     -- only owner can pickup during this window
local PICKUP_COOLDOWN = 0.25        -- per-player spam control

-- cooldowns[userId] = nextAllowedTime
local cooldowns = {}

-- simple ID for debug
local dropSeq = 0

local function now()
	return os.clock()
end

local function ack(rid, ok, code, msg, data)
	return { rid=rid, ok=ok, code=code, msg=msg, data=data }
end

local function validateEnvelope(p)
	return type(p) == "table" and type(p.rid) == "string" and type(p.data) == "table"
end

local function passCooldown(userId)
	local t = now()
	local n = cooldowns[userId] or 0
	if t < n then return false end
	cooldowns[userId] = t + PICKUP_COOLDOWN
	return true
end

local function getOrigin(player: Player): Vector3?
	local char = player.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position
	end
	local head = char:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return nil
end

local function isDropPart(inst: Instance): boolean
	return inst and inst:IsA("BasePart") and CollectionService:HasTag(inst, DROP_TAG)
end

local function readDrop(inst: BasePart)
	-- attributes are source of truth for pickup
	return {
		DropId = inst:GetAttribute("DropId"),
		ItemId = inst:GetAttribute("ItemId"),
		Qty = inst:GetAttribute("Qty"),
		OwnerUserId = inst:GetAttribute("OwnerUserId"),
		SpawnTime = inst:GetAttribute("SpawnTime"),
	}
end

local function distance(a: Vector3, b: Vector3)
	return (a - b).Magnitude
end

-- Find nearest world drop within radius
local function findNearestDrop(origin: Vector3, radius: number): BasePart?
	local nearest: BasePart? = nil
	local best = radius

	for _, inst in ipairs(CollectionService:GetTagged(DROP_TAG)) do
		if inst:IsA("BasePart") and inst.Parent then
			local d = distance(origin, inst.Position)
			if d <= best then
				best = d
				nearest = inst
			end
		end
	end

	return nearest
end

-- ===== Core API =====

function DropService.PickupValues(player, dropPart)
	if not dropPart or not dropPart.Parent then return end
	
	local itemId = dropPart:GetAttribute("ItemId")
	local qty = dropPart:GetAttribute("Qty")
	
	if not itemId or not qty then return end
	
	-- Add to inventory
	local ok = InventoryService.AddItem(player, itemId, qty)
	if ok then
		dropPart:Destroy()
		Net.Fire("Loot_Ack", player, { ok = true, msg = "picked up", data = { itemId = itemId, qty = qty } })
	else
		Net.Fire("Loot_Ack", player, { ok = false, msg = "full" })
	end
end

function DropService.SpawnDrop(position: Vector3, itemId: string, qty: number, ownerUserId: number?)
	local def = ItemDB[itemId]
	if not def then
		warn("[DropService] SpawnDrop invalid itemId", itemId)
		return nil
	end
	if type(qty) ~= "number" or qty <= 0 then
		warn("[DropService] SpawnDrop invalid qty", qty)
		return nil
	end

	dropSeq += 1
	local dropId = "D" .. tostring(dropSeq) .. "-" .. tostring(math.floor(now() * 1000))

	-- Create a simple part for Phase0 (visual later)
	local p = Instance.new("Part")
	p.Name = "WorldDrop_" .. itemId
	p.Size = Vector3.new(1, 1, 1)
	p.Anchored = true
	p.CanCollide = false
	p.Position = position + Vector3.new(0, 1.5, 0)
	p.Parent = workspace

	p:SetAttribute("DropId", dropId)
	p:SetAttribute("ItemId", itemId)
	p:SetAttribute("Qty", qty)
	p:SetAttribute("OwnerUserId", ownerUserId or 0)
	p:SetAttribute("SpawnTime", now())
	
	-- ProximityPrompt for Interaction
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pickup " .. itemId
	prompt.ObjectText = "Drop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = p
	
	prompt.Triggered:Connect(function(player)
		DropService.PickupValues(player, p)
	end)

	CollectionService:AddTag(p, DROP_TAG)
	-- CollectionService:AddTag(p, "Interactable") -- Removed in favor of ProximityPrompt

	print(("[Drop] spawned %s x%d id=%s owner=%d"):format(itemId, qty, dropId, ownerUserId or 0))

	-- TTL cleanup
	task.delay(TTL_SECONDS, function()
		if p and p.Parent then
			print(("[Drop] ttl expired id=%s"):format(dropId))
			p:Destroy()
		end
	end)

	return p
end

function DropService.TryPickup(player: Player, rid: string)
	if not passCooldown(player.UserId) then
		return ack(rid, false, "COOLDOWN", "cooldown")
	end

	local origin = getOrigin(player)
	if not origin then
		return ack(rid, false, "INTERNAL_ERROR", "no origin")
	end

	local drop = findNearestDrop(origin, PICKUP_RADIUS)
	if not drop then
		return ack(rid, false, "NOT_FOUND", "no drop nearby")
	end

	local info = readDrop(drop)
	local itemId = info.ItemId
	local qty = info.Qty
	local ownerUserId = info.OwnerUserId or 0
	local spawnTime = info.SpawnTime or 0

	if type(itemId) ~= "string" or type(qty) ~= "number" or qty <= 0 then
		return ack(rid, false, "INTERNAL_ERROR", "bad drop attributes", { hit = drop:GetFullName() })
	end

	-- ownership protect window
	if ownerUserId ~= 0 and ownerUserId ~= player.UserId then
		if now() - spawnTime < OWNER_PROTECT_SECONDS then
			return ack(rid, false, "NOT_OWNER", "protected", {
				itemId = itemId, qty = qty, ownerUserId = ownerUserId,
			})
		end
	end

	-- attempt to add item (InventoryService handles stacking)
	local ok = InventoryService.AddItem(player, itemId, qty)
	if not ok then
		return ack(rid, false, "INVENTORY_FULL", "cannot add item", { itemId=itemId, qty=qty })
	end

	print(("[Drop] picked up by %s: %s x%d (id=%s)"):format(player.Name, itemId, qty, tostring(info.DropId)))
	drop:Destroy()

	return ack(rid, true, "OK", nil, { itemId=itemId, qty=qty })
end

-- ===== Net binding =====

function DropService:Init()
	Net.Register({ "Loot_TryPickup", "Loot_Ack" })

	Net.On("Loot_TryPickup", function(player, payload)
		if not validateEnvelope(payload) then
			Net.Fire("Loot_Ack", player, ack(payload and payload.rid or "?", false, "VALIDATION_FAILED", "bad envelope"))
			return
		end
		Net.Fire("Loot_Ack", player, DropService.TryPickup(player, payload.rid))
	end)

	print("[DropService] ready")
end

Players.PlayerRemoving:Connect(function(p)
	cooldowns[p.UserId] = nil
end)

return DropService
