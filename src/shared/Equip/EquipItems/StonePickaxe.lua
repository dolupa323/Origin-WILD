-- StonePickaxe.lua
-- Phase 1-3
-- Tool for harvesting (same behavior as StoneAxe)

local StonePickaxe = {}

StonePickaxe.Cooldown = 0.5

function StonePickaxe.OnEquip(ctx)
	return true, "OK"
end

function StonePickaxe.OnUnequip(ctx)
	return true, "OK"
end

function StonePickaxe.OnUse(ctx)
	-- ctx: { player, aim, ResourceNodeService, ... } (주입됨)
	local player = ctx.player
	local aim = ctx.aim
	local ResourceNodeService = ctx.ResourceNodeService
	
	if not ResourceNodeService then
		return false, "NO_SERVICE"
	end
	
	if not aim or typeof(aim.dir) ~= "Vector3" then
		return false, "VALIDATION_FAILED"
	end

	local char = player.Character
	if not char then
		return false, "NO_CHARACTER"
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false, "NO_HRP"
	end

	local origin = hrp.Position + Vector3.new(0, 2, 0)
	local dist = 12
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { char }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(origin, aim.dir.Unit * dist, params)
	if not result or not result.Instance then
		return true, "OK", { hit = false }
	end

	-- Find ResourceNode ancestor
	local hitInst = result.Instance
	local target = hitInst:IsA("Model") and hitInst or hitInst:FindFirstAncestorOfClass("Model")
	
	local CollectionService = game:GetService("CollectionService")
	if not target or (not CollectionService:HasTag(target, "ResourceNode") and not CollectionService:HasTag(target.PrimaryPart, "ResourceNode")) then
		return true, "OK", { hit = true, result = "NOT_RESOURCE_NODE" }
	end

	-- Call TryHarvest
	-- Phase 1-3: Pass tool data
	local toolData = { ToolType="Pickaxe", Power=20 }
	local ok, code = ResourceNodeService.TryHarvest(player, target, toolData)
	if not ok then
		return false, code or "HARVEST_FAIL"
	end

	return true, "OK", { hit = true, harvested = true }
end

return StonePickaxe
