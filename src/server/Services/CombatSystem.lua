-- CombatSystem.lua
-- Phase0-0-10
-- Server authoritative combat resolver (raycast validate / damage / result)
-- DoD: client request -> server raycast -> humanoid damage -> result -> optional burn effect

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local EffectService = require(script.Parent.EffectService)
local FeedbackService = require(script.Parent.FeedbackService)

local CombatSystem = {}

-- ===== Tunables =====
local MELEE_RANGE = 10
local MELEE_DAMAGE = 15
local ATTACK_COOLDOWN = 0.4
local APPLY_BURN = true
local BURN_DURATION = 3

local nextAttackAt = {} -- [userId] = time

local function now()
	return os.clock()
end

local function ack(rid, ok, code, msg, data)
	return { rid=rid, ok=ok, code=code, msg=msg, data=data }
end

local function validateEnvelope(p)
	return type(p) == "table"
		and type(p.rid) == "string"
		and type(p.data) == "table"
end

local function getOrigin(player: Player): (Vector3?, Instance?)
	local char = player.Character
	if not char then return nil, nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position, char
	end
	local head = char:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position, char
	end
	return nil, char
end

local function canAttack(player: Player)
	local t = now()
	local n = nextAttackAt[player.UserId] or 0
	if t < n then return false end
	nextAttackAt[player.UserId] = t + ATTACK_COOLDOWN
	return true
end

local function raycastFromPlayer(player: Player, dir: Vector3, range: number)
	local origin, char = getOrigin(player)
	if not origin then return nil, origin end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, dir.Unit * range, params)
	return result, origin
end

local function findHumanoidFromHit(inst: Instance): (Humanoid?, Model?)
	if not inst then return nil, nil end
	local m = inst:FindFirstAncestorOfClass("Model")
	if not m then return nil, nil end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hum then return nil, nil end
	return hum, m
end

-- ===== Core =====

function CombatSystem.AttackRequest(player: Player, rid: string, data: table)
	if not canAttack(player) then
		return ack(rid, false, "COOLDOWN", "cooldown")
	end

	local aim = data.aim
	if type(aim) ~= "table" or typeof(aim.dir) ~= "Vector3" then
		return ack(rid, false, "VALIDATION_FAILED", "bad aim")
	end

	local dir = aim.dir
	-- sanity: prevent NaN / zero
	if dir.Magnitude < 0.001 then
		return ack(rid, false, "VALIDATION_FAILED", "dir too small")
	end

	local hit, origin = raycastFromPlayer(player, dir, MELEE_RANGE)
	if not hit then
		return ack(rid, true, "OK", "no hit", { hit=false })
	end

	local hum, model = findHumanoidFromHit(hit.Instance)
	if not hum then
		return ack(rid, true, "OK", "hit non-humanoid", {
			hit=true,
			hitInstance=hit.Instance:GetFullName(),
			pos=hit.Position,
		})
	end

	-- apply damage on server
	local before = hum.Health
	hum:TakeDamage(MELEE_DAMAGE)
	local after = hum.Health
	
	FeedbackService.ShowDamage(hit.Position, MELEE_DAMAGE, "Default")

	-- optional: apply burn to attacker (Phase0 test), or to victim player if it is a Player
	-- For Phase0, simplest: apply to attacker to prove pipeline works,
	-- but more correct: apply to victim if victim is a Player.
	if APPLY_BURN then
		-- if victim is a player, apply to that player, else skip
		local victimPlayer = Players:GetPlayerFromCharacter(model)
		if victimPlayer then
			EffectService.Apply(victimPlayer, "Burn", BURN_DURATION, 1)
		end
	end

	-- print(("[Combat] %s hit=%s dmg=%d hp %.1f->%.1f"):format(player.Name, model:GetFullName(), MELEE_DAMAGE, before, after))

	return ack(rid, true, "OK", nil, {
		hit=true,
		target=model:GetFullName(),
		damage=MELEE_DAMAGE,
		hpBefore=before,
		hpAfter=after,
		hitPos=hit.Position,
	})
end

-- ===== Net binding =====

function CombatSystem:Init()
	Net.Register({ "Combat_AttackRequest", "Combat_Result" })

	Net.On("Combat_AttackRequest", function(player, payload)
		if not validateEnvelope(payload) then
			Net.Fire("Combat_Result", player, ack(payload and payload.rid or "?", false, "VALIDATION_FAILED", "bad envelope"))
			return
		end

		local res = CombatSystem.AttackRequest(player, payload.rid, payload.data)
		Net.Fire("Combat_Result", player, res)
	end)

	print("[CombatSystem] ready")
end

Players.PlayerRemoving:Connect(function(p)
	nextAttackAt[p.UserId] = nil
end)

return CombatSystem
