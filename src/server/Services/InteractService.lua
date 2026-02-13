-- InteractService.lua
-- Phase 1-5-0
-- Server authoritative interaction dispatcher (Validate Target instead of blind raycast)
-- Client sends mouse.Target, server validates distance/tag/obstruction

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Interact"))

local InteractService = {}

local MAX_DIST = 15 -- generous distance (3인칭 시점 보정)
local COOLDOWN = 0.25
local cooldowns = {}

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
	local nextOk = cooldowns[userId] or 0
	if t < nextOk then return false end
	cooldowns[userId] = t + COOLDOWN
	return true
end

local function getOrigin(player: Player)
	local char = player.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then return hrp.Position end
	return nil
end

local function findInteractableAncestor(inst)
	local cur = inst
	while cur and cur ~= workspace do
		if CollectionService:HasTag(cur, Contracts.InteractableTag) then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

-- Handlers
local handlers = {}

handlers.Default = function(player, target, hit, distance)
	return true, Contracts.ErrorCodes.OK, nil, {
		target = target:GetFullName(),
		interactType = target:GetAttribute("InteractType"),
	}
end

handlers.ResourceNode = function(player, target, hit, distance)
	-- E키 상호작용은 맨손 채집 불가 → 도구 사용 안내
	return false, Contracts.ErrorCodes.DENIED, "Use tool to harvest"
end

handlers.CraftBench = function(player, target, hit, distance)
	local CraftingService = require(script.Parent.CraftingService)
	local ok, code = CraftingService.OpenBench(player, target)
	return ok, code or Contracts.ErrorCodes.OK, nil, { bench = target:GetFullName() }
end

handlers.WorldDrop = function(player, target, hit, distance)
	local DropService = require(script.Parent.DropService)
	local result = DropService.PickupValues(player, target)
	if result then
		return true, "OK", nil, { itemId = "picked" }
	else
		return false, "FULL", "Inventory Full"
	end
end

local function dispatch(player, target, hit, distance)
	local t = target:GetAttribute("InteractType")
	if type(t) == "string" and handlers[t] then
		return handlers[t](player, target, hit, distance)
	end
	return handlers.Default(player, target, hit, distance)
end

function InteractService:_handleRequest(player, payload)
	if not validateEnvelope(payload) then
		return ack(payload and payload.rid or "?", false, Contracts.ErrorCodes.VALIDATION_FAILED, "bad envelope")
	end

	local rid = payload.rid
	local data = payload.data
	local clientTarget = data.target -- 클라가 보낸 마우스 타겟

	if not passCooldown(player.UserId) then
		return ack(rid, false, Contracts.ErrorCodes.COOLDOWN, "cooldown")
	end

	local origin = getOrigin(player)
	if not origin then
		return ack(rid, false, Contracts.ErrorCodes.INTERNAL_ERROR, "no character origin")
	end

	-- 1. 타겟 유효성 검증 (클라가 보낸 타겟이 실제로 존재하는가)
	if not clientTarget or not clientTarget.Parent then
		return ack(rid, false, Contracts.ErrorCodes.NOT_FOUND, "no target locked")
	end

	-- 2. 거리 검증 (Server Authoritative Check)
	local targetPos
	if clientTarget:IsA("Model") then
		targetPos = clientTarget:GetPivot().Position
	else
		targetPos = clientTarget.Position
	end
	local dist = (targetPos - origin).Magnitude
	if dist > MAX_DIST then
		return ack(rid, false, Contracts.ErrorCodes.OUT_OF_RANGE, "too far")
	end

	-- 3. Interactable 태그 검증
	local interactable = findInteractableAncestor(clientTarget)
	if not interactable then
		return ack(rid, false, Contracts.ErrorCodes.DENIED, "not interactable")
	end

	-- 4. 시야 검증 (벽 뚫기 방지)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	-- 클라 타겟, 플레이어 캐릭터 모두 제외 → 그 사이에 가리는 물체가 있는지만 체크
	local excludeList = { player.Character }
	-- interactable이 Model이면 모든 자식 제외
	if interactable:IsA("Model") then
		table.insert(excludeList, interactable)
	else
		table.insert(excludeList, clientTarget)
	end
	local losParams = RaycastParams.new()
	losParams.FilterType = Enum.RaycastFilterType.Exclude
	losParams.FilterDescendantsInstances = excludeList
	losParams.IgnoreWater = true

	local rayDir = (targetPos - origin)
	local rayResult = workspace:Raycast(origin, rayDir, losParams)
	if rayResult then
		-- 가리는 물체가 있으나, 그 거리가 타겟까지의 거리보다 짧으면 가림
		local blockDist = (rayResult.Position - origin).Magnitude
		local targetDist = rayDir.Magnitude
		if blockDist < targetDist - 1 then
			return ack(rid, false, Contracts.ErrorCodes.DENIED, "obstructed")
		end
	end

	local ok, code, msg, outData = dispatch(player, interactable, clientTarget, dist)
	if ok == false then
		return ack(rid, false, code or Contracts.ErrorCodes.DENIED, msg or "handler denied", outData)
	end

	return ack(rid, true, Contracts.ErrorCodes.OK, nil, outData)
end

function InteractService:Init()
	Net.Register({ Contracts.Remotes.Request, Contracts.Remotes.Ack })

	Net.On(Contracts.Remotes.Request, function(player, payload)
		Net.Fire(Contracts.Remotes.Ack, player, self:_handleRequest(player, payload))
	end)

	print("[InteractService] ready")
end

Players.PlayerRemoving:Connect(function(p)
	cooldowns[p.UserId] = nil
end)

return InteractService
