local Registry = {}
local map = {}

function Registry:Register(itemId, mod)
	map[itemId] = mod
end

function Registry:Get(itemId)
	return map[itemId]
end

-- Equipment registration
Registry:Register("Pickaxe", require(script.Parent.EquipItems.Pickaxe))
Registry:Register("StoneAxe", require(script.Parent.EquipItems.StoneAxe))
Registry:Register("StonePickaxe", require(script.Parent.EquipItems.StonePickaxe))
Registry:Register("StoneSword", require(script.Parent.EquipItems.StoneSword))

return Registry
