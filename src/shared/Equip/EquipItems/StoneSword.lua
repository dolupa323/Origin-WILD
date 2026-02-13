-- StoneSword.lua
-- Phase 1-3
-- Weapon for melee combat (reuses CombatSystem)

local StoneSword = {}

StoneSword.Cooldown = 0.4

function StoneSword.OnEquip(ctx)
	return true, "OK"
end

function StoneSword.OnUnequip(ctx)
	return true, "OK"
end

function StoneSword.OnUse(ctx)
	local player = ctx.player
	local aim = ctx.aim
	local CombatSystem = ctx.CombatSystem
	
	if not CombatSystem then
		return false, "NO_SERVICE"
	end
	
	if not aim or typeof(aim.dir) ~= "Vector3" then
		return false, "VALIDATION_FAILED"
	end

	-- Generate request ID
	local rid = tostring(math.random(100000, 999999)) .. "-" .. tostring(os.clock())

	-- Call CombatSystem.AttackRequest (pass target along)
	local ack = CombatSystem.AttackRequest(player, rid, {
		kind = "Melee",
		aim = {
			dir = aim.dir,
			target = aim.target,
		}
	})

	if ack.ok then
		return true, ack.code or "OK", ack.data
	else
		return false, ack.code or "ATTACK_FAILED", ack.data
	end
end

return StoneSword
