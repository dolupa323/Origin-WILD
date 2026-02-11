local Registry = {}
local map = {}

function Registry:Register(itemId, mod)
	map[itemId] = mod
end

function Registry:Get(itemId)
	return map[itemId]
end

-- 샘플 등록
-- Registry:Register("Pickaxe", require(script.EquipItems.Pickaxe))
Registry:Register("Pickaxe", require(script.Parent.EquipItems.Pickaxe))


return Registry
