local Pickaxe = {}

Pickaxe.Cooldown = 0.4

function Pickaxe.OnEquip(ctx)
	print("[Pickaxe] OnEquip", ctx.player)
	return true, "OK"
end

function Pickaxe.OnUnequip(ctx)
	print("[Pickaxe] OnUnequip", ctx.player)
	return true, "OK"
end

function Pickaxe.OnUse(ctx)
	print("[Pickaxe] OnUse", ctx.player)
	return true, "OK", { used = true }
end

return Pickaxe
