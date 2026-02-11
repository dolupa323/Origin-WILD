-- EntityService.lua
-- Phase0-0-3
-- Unified entity layer: HP/Damage/Death/Tags/Attributes

local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tags = require(ReplicatedStorage.Code.Shared.Tags)
local Attr = require(ReplicatedStorage.Code.Shared.Attr)

local EntityService = {}

-- entityId -> instance
local registry: {[string]: Instance} = {}

local function isValidInstance(inst: any): boolean
	return typeof(inst) == "Instance" and inst.Parent ~= nil
end

local function setIfNil(inst: Instance, key: string, value)
	if inst:GetAttribute(key) == nil then
		inst:SetAttribute(key, value)
	end
end

-------------------------------------------------
-- Public API
-------------------------------------------------

-- CreateEntity:
-- inst: Instance (Model/BasePart/Player.Character etc.)
-- opts:
--   OwnerUserId?: number
--   Faction?: string
--   HP?: number
--   MaxHP?: number
--   Tier?: number
function EntityService.CreateEntity(inst: Instance, opts: table?)
	assert(isValidInstance(inst), "[EntityService] CreateEntity: invalid instance")

	opts = opts or {}

	local entityId = inst:GetAttribute(Attr.EntityId)
	if entityId == nil then
		entityId = HttpService:GenerateGUID(false)
		inst:SetAttribute(Attr.EntityId, entityId)
	end

	-- canonical tags
	CollectionService:AddTag(inst, Tags.Entity)

	-- canonical attributes
	setIfNil(inst, Attr.OwnerUserId, opts.OwnerUserId or 0)
	setIfNil(inst, Attr.Faction, opts.Faction or "Neutral")

	local maxHp = opts.MaxHP or inst:GetAttribute(Attr.MaxHP) or 100
	local hp = opts.HP or inst:GetAttribute(Attr.HP) or maxHp

	inst:SetAttribute(Attr.MaxHP, maxHp)
	inst:SetAttribute(Attr.HP, math.clamp(hp, 0, maxHp))

	if opts.Tier ~= nil then inst:SetAttribute(Attr.Tier, opts.Tier) end

	-- damageable tag if has HP
	CollectionService:AddTag(inst, Tags.Damageable)

	registry[entityId] = inst
	return entityId
end

function EntityService.GetInstance(entityId: string): Instance?
	return registry[entityId]
end

function EntityService.GetEntityId(inst: Instance): string?
	return inst:GetAttribute(Attr.EntityId)
end

function EntityService.IsAlive(inst: Instance): boolean
	local hp = inst:GetAttribute(Attr.HP)
	return typeof(hp) == "number" and hp > 0
end

-- Damage returns: ok, newHp, died
function EntityService.Damage(inst: Instance, amount: number, sourceEntityId: string?): (boolean, number?, boolean?)
	if not isValidInstance(inst) then return false end
	if type(amount) ~= "number" or amount <= 0 then return false end
	if not CollectionService:HasTag(inst, Tags.Damageable) then return false end

	local maxHp = inst:GetAttribute(Attr.MaxHP)
	local hp = inst:GetAttribute(Attr.HP)
	if typeof(maxHp) ~= "number" or typeof(hp) ~= "number" then return false end
	if hp <= 0 then return true, 0, true end

	local newHp = math.clamp(hp - amount, 0, maxHp)
	inst:SetAttribute(Attr.HP, newHp)

	if newHp <= 0 then
		EntityService.Kill(inst, sourceEntityId)
		return true, newHp, true
	end

	return true, newHp, false
end

function EntityService.Heal(inst: Instance, amount: number): (boolean, number?)
	if not isValidInstance(inst) then return false end
	if type(amount) ~= "number" or amount <= 0 then return false end
	if not CollectionService:HasTag(inst, Tags.Damageable) then return false end

	local maxHp = inst:GetAttribute(Attr.MaxHP)
	local hp = inst:GetAttribute(Attr.HP)
	if typeof(maxHp) ~= "number" or typeof(hp) ~= "number" then return false end
	if hp <= 0 then return false end

	local newHp = math.clamp(hp + amount, 0, maxHp)
	inst:SetAttribute(Attr.HP, newHp)
	return true, newHp
end

function EntityService.Kill(inst: Instance, killerEntityId: string?)
	if not isValidInstance(inst) then return end
	if inst:GetAttribute(Attr.HP) ~= nil then
		inst:SetAttribute(Attr.HP, 0)
	end

	inst:SetAttribute("KillerEntityId", killerEntityId or "")

	-- Optional: mark dead tag (not in spec but useful)
	-- CollectionService:AddTag(inst, "Dead")

	-- NOTE: actual destruction/removal is handled by owning system (AI, Drop, Resource, etc.)
end

-- Cleanup when instance is destroyed
function EntityService.Unregister(inst: Instance)
	if not isValidInstance(inst) then return end
	local entityId = inst:GetAttribute(Attr.EntityId)
	if entityId and registry[entityId] == inst then
		registry[entityId] = nil
	end
end

-------------------------------------------------
-- Debug / test
-------------------------------------------------
function EntityService.Debug_SpawnAndDestroy(count: number)
	count = count or 100
	local folder = Instance.new("Folder")
	folder.Name = "_EntityServiceTest"
	folder.Parent = workspace

	for i = 1, count do
		local p = Instance.new("Part")
		p.Size = Vector3.new(1,1,1)
		p.Anchored = true
		p.Position = Vector3.new(i * 2, 5, 0)
		p.Parent = folder

		EntityService.CreateEntity(p, { MaxHP = 10, HP = 10, Faction = "Test" })
	end

	task.wait(0.2)
	folder:Destroy()
end

return EntityService
