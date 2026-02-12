-- ResourceNodeService.lua
-- Phase1-1
-- Server authoritative resource node (HP-based, E-key interact, auto-drop)

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Tags = require(Shared:WaitForChild("Tags"))
local Attr = require(Shared:WaitForChild("Attr"))
local ItemDB = require(Shared:WaitForChild("ItemDB"))

local EntityService = require(script.Parent.EntityService)
local DropService = require(script.Parent.DropService)
local FeedbackService = require(script.Parent.FeedbackService)

local ResourceNodeService = {}

-- nodeId -> nodeState
local nodeRegistry = {}

local function now()
	return os.clock()
end

local function createNodeState(nodeModel, nodeType)
	return {
		nodeId = nodeModel:GetAttribute(Attr.EntityId),
		nodeModel = nodeModel,
		nodeType = nodeType,
		createdAt = now(),
	}
end

----- ===== Type Defaults =====

local TypeDefaults = {
	Tree = { hp = 50, itemId = "Wood", qty = 3 },
	Stone = { hp = 40, itemId = "Stone", qty = 2 },
}

----- ===== Core API =====

function ResourceNodeService.SpawnResourceNode(position: Vector3, nodeType: string, opts: table?): Model?
	opts = opts or {}

	-- Validate type
	if not TypeDefaults[nodeType] then
		warn("[ResourceNodeService] Invalid nodeType:", nodeType)
		return nil
	end

	local typeDefaults = TypeDefaults[nodeType]

	-- Create Model
	local nodeModel = Instance.new("Model")
	nodeModel.Name = "ResourceNode_" .. nodeType

	-- Create single part as visual
	local part = Instance.new("Part")
	part.Name = nodeType
	part.Size = Vector3.new(4, 4, 4)
	part.Anchored = true
	part.CanCollide = true
	part.BrickColor = nodeType == "Tree" and BrickColor.new("Dark green") or BrickColor.new("Medium stone grey")
	part.Parent = nodeModel

	-- Position
	part.Position = position
	nodeModel.PrimaryPart = part
	nodeModel:SetPrimaryPartCFrame(CFrame.new(position))

	-- Parent to workspace
	nodeModel.Parent = workspace

	-- Set attributes
	local hp = opts.HP or typeDefaults.hp
	local itemId = opts.ItemId or typeDefaults.itemId
	local qty = opts.Qty or typeDefaults.qty

	part:SetAttribute("HP", hp)
	part:SetAttribute("MaxHP", hp)
	part:SetAttribute("ItemId", itemId)
	part:SetAttribute("Qty", qty)
	-- Palworld-like: Node type for tool checking
	part:SetAttribute("NodeType", nodeType) -- "Tree", "Stone"

	-- Register as entity
	EntityService.CreateEntity(nodeModel, {
		HP = hp,
		MaxHP = hp,
		Faction = "Neutral",
	})

	-- Tags
	CollectionService:AddTag(nodeModel, Tags.Entity)
	CollectionService:AddTag(nodeModel, Tags.Damageable)
	CollectionService:AddTag(nodeModel, Tags.ResourceNode)
	CollectionService:AddTag(part, Tags.Entity)
	CollectionService:AddTag(part, Tags.Damageable)

	-- Palworld style: You hit trees/stones. You don't "Interact" with E unless it's a loose item.
	-- Removing Interactable tag so no "E" prompt appears on big nodes.
	-- part:SetAttribute("InteractType", "ResourceNode")
	-- CollectionService:AddTag(part, "Interactable")

	-- Register in local registry
	local entityId = nodeModel:GetAttribute(Attr.EntityId)
	nodeRegistry[entityId] = createNodeState(nodeModel, nodeType)

	print(("[ResourceNodeService] Spawned %s at %s (hp=%d, itemId=%s, qty=%d)"):format(
		nodeType, tostring(position), hp, itemId, qty
	))

	return nodeModel
end

function ResourceNodeService.TryHarvest(player: Player, nodeModel: Model, toolData: table?): (boolean, string?)
	if not nodeModel or not nodeModel.Parent then
		return false, "MISSING"
	end

	-- Find harvestable part
	local part = nodeModel:FindFirstChildOfClass("BasePart")
	if not part then
		return false, "NO_PART"
	end

	local hp = part:GetAttribute("HP")
	local maxHp = part:GetAttribute("MaxHP")
	local itemId = part:GetAttribute("ItemId")
	local qty = part:GetAttribute("Qty")

	if not hp or not maxHp then
		return false, "NO_HP"
	end

	if hp <= 0 then
		return false, "DEPLETED"
	end

	local nodeType = part:GetAttribute("NodeType") -- "Tree", "Stone"

	-- Calculate Damage based on Tool Logic
	local baseDmg = 1
	local toolType = toolData and toolData.ToolType or "None"
	local toolPower = toolData and toolData.Power or 5

	-- Effectiveness Multiplier
	local multiplier = 0.2 -- Default weak (20%)

	if nodeType == "Tree" then
		if toolType == "Axe" then multiplier = 1.0 end
	elseif nodeType == "Stone" then
		if toolType == "Pickaxe" then multiplier = 1.0 end
	end

	local finalDmg = math.floor(toolPower * multiplier)
	if finalDmg < 1 then finalDmg = 1 end

	local newHp = math.max(0, hp - finalDmg)
	part:SetAttribute("HP", newHp)
	
	FeedbackService.ShowDamage(part.Position + Vector3.new(math.random(-1,1), 2, math.random(-1,1)), finalDmg, "Resource")

	print(("[ResourceNode] %s used %s(pow=%d) on %s -> dmg %d (eff: %.1f)"):format(
		player.Name, toolType, toolPower, part.Name, finalDmg, multiplier
	))

	-- Check if depleted
	if newHp <= 0 then
		print(("[ResourceNode] depleted %s"):format(part.Name))

		-- Spawn drop
		if itemId and qty and qty > 0 then
			DropService.SpawnDrop(part.Position + Vector3.new(0, 3, 0), itemId, qty, player.UserId)
		end

		-- Destroy node
		task.delay(0.5, function()
			if nodeModel and nodeModel.Parent then
				nodeModel:Destroy()
			end
			local entityId = nodeModel:GetAttribute(Attr.EntityId)
			if entityId then
				nodeRegistry[entityId] = nil
			end
		end)

		return true, "DEPLETED"
	end

	return true, "OK"
end

function ResourceNodeService.GetActive()
	local active = {}
	for entityId, nodeState in pairs(nodeRegistry) do
		if nodeState.nodeModel and nodeState.nodeModel.Parent then
			table.insert(active, nodeState)
		else
			nodeRegistry[entityId] = nil
		end
	end
	return active
end

function ResourceNodeService:Init()
	-- Nothing to initialize for Phase1
	print("[ResourceNodeService] ready")
end

return ResourceNodeService
