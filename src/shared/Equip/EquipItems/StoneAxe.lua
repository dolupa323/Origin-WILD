-- StoneAxe.lua
-- Phase1-3-1
-- Server-side tool behavior (Harvest)

local StoneAxe = {}

StoneAxe.Cooldown = 0.5

function StoneAxe.OnEquip(ctx)
	return true, "OK"
end

function StoneAxe.OnUnequip(ctx)
	return true, "OK"
end

function StoneAxe.OnUse(ctx)
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

	-- Raycast from HRP (same as InteractService: 12 studs)
	local origin = hrp.Position + Vector3.new(0, 2, 0) -- chest height
	local dist = 12
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { char }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(origin, aim.dir.Unit * dist, params)
	if not result or not result.Instance then
		return true, "OK", { hit = false }
	end

	local hitInst = result.Instance
	-- Find ResourceNode ancestor
	local target = hitInst:IsA("Model") and hitInst or hitInst:FindFirstAncestorOfClass("Model")
	
	if not target or target:GetAttribute("InteractType") ~= "ResourceNode" then
		return true, "OK", { hit = true, result = "NOT_RESOURCE_NODE" }
	end

	-- Call TryHarvest
	-- Phase1-3-1: Pass tool data
	local toolData = { ToolType="Axe", Power=20 }
	local ok, code = ResourceNodeService.TryHarvest(player, target, toolData)
	if not ok then
		return false, code or "HARVEST_FAIL"
	end

	return true, "OK", { hit = true, harvested = true }
end

return StoneAxe
