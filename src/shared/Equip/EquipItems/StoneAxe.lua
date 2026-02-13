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
		-- 서버 거리 검증
		local targetPos = target.Position
		if (targetPos - hrp.Position).Magnitude > 14 then
			return false, "OUT_OF_RANGE"
		end
		hitInst = target
	else
		-- 백업: 기존 Raycast 로직 (Head 기준)
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

	-- Find ResourceNode ancestor
	local nodeModel = hitInst:IsA("Model") and hitInst or hitInst:FindFirstAncestorOfClass("Model")

	local CollectionService = game:GetService("CollectionService")
	if nodeModel and CollectionService:HasTag(nodeModel, "ResourceNode") then
		-- OK
	elseif CollectionService:HasTag(hitInst, "ResourceNode") then
		nodeModel = hitInst:FindFirstAncestorOfClass("Model") or hitInst
	else
		return true, "OK", { hit = true, result = "NOT_RESOURCE_NODE" }
	end

	-- Call TryHarvest
	local toolData = { ToolType="Axe", Power=20 }
	local ok, code = ResourceNodeService.TryHarvest(player, nodeModel, toolData)
	if not ok then
		return false, code or "HARVEST_FAIL"
	end

	return true, "OK", { hit = true, harvested = true }
end

return StoneAxe
