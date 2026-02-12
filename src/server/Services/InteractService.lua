local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Interact"))

local InteractService = {}

-- ===== Tunables (Phase0) =====
local MAX_DIST = 12
local COOLDOWN = 0.25

-- cooldowns[userId] = nextAllowedTime
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

local function sanitizeDir(v)
	if typeof(v) ~= "Vector3" then return nil end
	local m = v.Magnitude
	if m < 0.1 then return nil end
	return v / m
end

local function findInteractableAncestor(inst: Instance): Instance?
	local cur = inst
	while cur and cur ~= workspace do
		if CollectionService:HasTag(cur, Contracts.InteractableTag) then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

-- handlers[InteractType] = function(player, target, hit, distance) -> (ok, code, msg, data)
local handlers = {}

-- Phase0 기본 핸들러 (콘텐츠 없음 -> 로그로만 검증)
handlers.Default = function(player, target, hit, distance)
	-- ...existing code...
	return true, Contracts.Error.OK, nil, {
		target = target:GetFullName(),
		hit = hit:GetFullName(),
		distance = distance,
		interactType = target:GetAttribute("InteractType") or target.Name,
	}
end

-- Phase1-1 자원 노드 핸들러 (E키 수확)
handlers.ResourceNode = function(player, target, hit, distance)
	local ResourceNodeService = require(script.Parent.ResourceNodeService)
	local nodeModel = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
	if not nodeModel then
		return false, Contracts.Error.INTERNAL_ERROR, "no model"
	end
	local ok, code = ResourceNodeService.TryHarvest(player, nodeModel)
	return ok, code or Contracts.Error.OK, nil, { resourceNode = target:GetFullName() }
end

-- Phase1-2 공작대 핸들러 (E키 오픈)
handlers.CraftBench = function(player, target, hit, distance)
	local CraftingService = require(script.Parent.CraftingService)
	local ok, code = CraftingService.OpenBench(player, target)
	return ok, code or Contracts.Error.OK, nil, { bench = target:GetFullName() }
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
		return ack(payload and payload.rid or "?", false, Contracts.Error.VALIDATION_FAILED, "bad envelope")
	end

	local rid = payload.rid
	local data = payload.data

	if not passCooldown(player.UserId) then
		return ack(rid, false, Contracts.Error.COOLDOWN, "cooldown")
	end

	-- 클라 origin은 신뢰하지 않음. 서버 origin 사용.
	local origin = getOrigin(player)
	if not origin then
		return ack(rid, false, Contracts.Error.INTERNAL_ERROR, "no character origin")
	end

	local aim = data.aim
	if type(aim) ~= "table" then
		return ack(rid, false, Contracts.Error.VALIDATION_FAILED, "missing aim")
	end

	local dir = sanitizeDir(aim.dir)
	if not dir then
		return ack(rid, false, Contracts.Error.VALIDATION_FAILED, "bad aim.dir")
	end

	-- Raycast
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	-- 자기 캐릭터는 제외
	if player.Character then
		params.FilterDescendantsInstances = { player.Character }
	else
		params.FilterDescendantsInstances = {}
	end

	local rayDist = MAX_DIST
	local result = workspace:Raycast(origin, dir * rayDist, params)
	if not result or not result.Instance then
		return ack(rid, false, Contracts.Error.NOT_FOUND, "no hit")
	end

	local hit = result.Instance
	local target = findInteractableAncestor(hit)
	if not target then
	return ack(rid, false, Contracts.Error.DENIED, "hit not interactable", {
		hit = hit:GetFullName(),
	})
end


	local distance = (result.Position - origin).Magnitude
	if distance > MAX_DIST + 0.01 then
		return ack(rid, false, Contracts.Error.OUT_OF_RANGE, "too far")
	end

	local ok, code, msg, outData = dispatch(player, target, hit, distance)
	if ok == false then
		return ack(rid, false, code or Contracts.Error.DENIED, msg or "handler denied", outData)
	end

	return ack(rid, true, Contracts.Error.OK, nil, outData)
end

function InteractService:Init()
	Net.Register({ "Interact_Request", "Interact_Ack" })

	Net.On("Interact_Request", function(player, payload)
		Net.Fire("Interact_Ack", player, self:_handleRequest(player, payload))
	end)

	print("[InteractService] ready")
end

Players.PlayerRemoving:Connect(function(p)
	cooldowns[p.UserId] = nil
end)

return InteractService
