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
	local player = ctx.player
	local aim = ctx.aim
	local ResourceNodeService = ctx.ResourceNodeService
	
	if not ResourceNodeService then
		return false, "NO_SERVICE"
	end

	local char = player.Character
	if not char then
		return false, "NO_CHARACTER"
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false, "NO_HRP"
	end

	-- 1. 클라이언트가 보낸 타겟 우선 사용 (parallax fix)
	local target = aim and aim.target
	local hitInst = nil

	if target and target.Parent then
		local targetPos = target.Position
		if (targetPos - hrp.Position).Magnitude > 14 then
			return false, "OUT_OF_RANGE"
		end
		hitInst = target
	else
		if not aim or typeof(aim.dir) ~= "Vector3" then
			return false, "VALIDATION_FAILED"
		end
		local head = char:FindFirstChild("Head")
		local origin = head and head.Position or (hrp.Position + Vector3.new(0, 2, 0))
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { char }
		params.FilterType = Enum.RaycastFilterType.Exclude
		local result = workspace:Raycast(origin, aim.dir.Unit * 14, params)
		if not result or not result.Instance then
			return true, "OK", { hit = false }
		end
		hitInst = result.Instance
	end

	local nodeModel = hitInst:IsA("Model") and hitInst or hitInst:FindFirstAncestorOfClass("Model")

	local CollectionService = game:GetService("CollectionService")
	if nodeModel and CollectionService:HasTag(nodeModel, "ResourceNode") then
		-- OK
	elseif CollectionService:HasTag(hitInst, "ResourceNode") then
		nodeModel = hitInst:FindFirstAncestorOfClass("Model") or hitInst
	else
		return true, "OK", { hit = true, result = "NOT_RESOURCE_NODE" }
	end

	local toolData = { ToolType="Pickaxe", Power=20 }
	local ok, code = ResourceNodeService.TryHarvest(player, nodeModel, toolData)
	if not ok then
		return false, code or "HARVEST_FAIL"
	end

	return true, "OK", { hit = true, harvested = true }
end

return StonePickaxe
