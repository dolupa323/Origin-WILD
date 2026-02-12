-- EffectService.lua
-- Phase0-0-9
-- Server authoritative effects: Apply/Remove/Tick/Stacks (MVP)
-- DoD: Burn(5s) DOT tick damages entity/player every 1s then auto-remove

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

-- Optional: EntityService가 이미 있다면 Damage 호출에 사용
local EntityService = require(script.Parent.EntityService)

local EffectService = {}

-- ===== Tunables =====
local TICK_DT = 0.2          -- internal update rate
local DOT_INTERVAL = 1.0     -- burn applies every 1s

-- effectsByEntity[entityKey][effectId] = effectState
-- entityKey: Instance (Model/Part) or Player or string id. Phase0: Player 중심.
local effectsByKey = {}

-- effect definitions (data-driven later; hardcode only for Phase0 test)
local EffectDefs = {
	Burn = {
		MaxStacks = 3,
		DotDamage = 5,       -- per tick interval per stack
	},
}

local function now()
	return os.clock()
end

local function keyOf(target)
	-- Phase0: accept Player or Instance
	if typeof(target) == "Instance" then return target end
	if typeof(target) == "Player" then return target end
	return nil
end

local function ensureBucket(k)
	local b = effectsByKey[k]
	if not b then
		b = {}
		effectsByKey[k] = b
	end
	return b
end

local function emitApplied(k, effectId, st)
	-- Phase0: only to the owning player if target is player, else broadcast optional
	if typeof(k) == "Player" then
		Net.Fire("Effect_Applied", k, {
			effectId = effectId,
			duration = math.max(0, st.expiresAt - now()),
			stacks = st.stacks,
		})
	end
end

local function emitRemoved(k, effectId)
	if typeof(k) == "Player" then
		Net.Fire("Effect_Removed", k, { effectId = effectId })
	end
end

-- ===== Public API =====

-- Apply(target, effectId, durationSeconds, stacksDelta?)
function EffectService.Apply(target, effectId: string, duration: number, stacksDelta: number?)
	local k = keyOf(target)
	if not k then return false, "INVALID_TARGET" end
	if type(effectId) ~= "string" then return false, "INVALID_EFFECT" end
	if type(duration) ~= "number" or duration <= 0 then return false, "INVALID_DURATION" end

	local def = EffectDefs[effectId]
	if not def then return false, "UNKNOWN_EFFECT" end

	local bucket = ensureBucket(k)
	local st = bucket[effectId]

	local addStacks = stacksDelta or 1
	addStacks = math.clamp(addStacks, 1, def.MaxStacks or 99)

	if not st then
		st = {
			effectId = effectId,
			stacks = addStacks,
			appliedAt = now(),
			expiresAt = now() + duration,
			nextDotAt = now() + DOT_INTERVAL,
		}
		bucket[effectId] = st
	else
		-- refresh duration & add stacks (cap)
		st.stacks = math.clamp(st.stacks + addStacks, 1, def.MaxStacks or 99)
		st.expiresAt = math.max(st.expiresAt, now() + duration)
	end

	-- print(("[Effect] Apply %s stacks=%d dur=%.2f target=%s"):format(effectId, st.stacks, (st.expiresAt - now()), typeof(k) == "Player" and k.Name or k:GetFullName()))

	emitApplied(k, effectId, st)
	return true, "OK"
end

function EffectService.Remove(target, effectId: string, reason: string?)
	local k = keyOf(target)
	if not k then return false, "INVALID_TARGET" end
	local bucket = effectsByKey[k]
	if not bucket or not bucket[effectId] then
		return false, "NOT_FOUND"
	end

	bucket[effectId] = nil
	if next(bucket) == nil then
		effectsByKey[k] = nil
	end

	-- print(("[Effect] Remove %s reason=%s target=%s"):format(effectId, reason or "manual", typeof(k) == "Player" and k.Name or k:GetFullName()))

	emitRemoved(k, effectId)
	return true, "OK"
end

function EffectService.GetActive(target)
	local k = keyOf(target)
	if not k then return {} end
	local bucket = effectsByKey[k]
	if not bucket then return {} end
	return bucket
end

-- ===== Internal ticking =====

local function applyBurnTick(targetKey, st)
	local def = EffectDefs.Burn
	local dmg = (def.DotDamage or 0) * (st.stacks or 1)

	-- Phase0: Player면 Humanoid에 직접 데미지 (EntityService로 통합 가능)
	if typeof(targetKey) == "Player" then
		local char = targetKey.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum:TakeDamage(dmg)
			-- print(("[Effect][Burn] tick %s dmg=%d stacks=%d hp=%.1f"):format(targetKey.Name, dmg, st.stacks, hum.Health))
		end
	else
		-- EntityService가 HP 기반 엔티티를 관리한다면 그쪽으로 Damage
		-- (Phase0에서는 테스트 편의상 Player 위주)
		-- EntityService.Damage(targetKey, dmg, { effect="Burn" })
	end
end

local function stepTick()
	local t = now()

	for k, bucket in pairs(effectsByKey) do
		for effectId, st in pairs(bucket) do
			-- expire
			if t >= st.expiresAt then
				EffectService.Remove(k, effectId, "expired")
			else
				-- per-effect ticking
				if effectId == "Burn" then
					if t >= st.nextDotAt then
						applyBurnTick(k, st)
						st.nextDotAt = t + DOT_INTERVAL
					end
				end
			end
		end
	end
end

local tickConn = nil
local accum = 0

function EffectService:Init()
	-- UI 표시용 Remote (Phase0: player only)
	Net.Register({ "Effect_Applied", "Effect_Removed" })

	if tickConn then tickConn:Disconnect() end
	tickConn = RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum >= TICK_DT then
			accum = 0
			stepTick()
		end
	end)

	print("[EffectService] ready")
end

Players.PlayerRemoving:Connect(function(p)
	effectsByKey[p] = nil
end)

return EffectService
