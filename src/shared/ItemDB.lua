-- ItemDB.lua
-- Minimal DB for phase0

return {
	Wood = {
		MaxStack = 100,
		Type = "Resource",
	},

	Stone = {
		MaxStack = 100,
		Type = "Resource",
	},

	Pickaxe = {
		MaxStack = 1,
		Type = "Equipment",
	},

	StoneAxe = {
		MaxStack = 1,
		Type = "Equipment",
		EquipType = "Tool",
		Use = "Harvest",
		NodeTags = {"ResourceNode"},
		-- Validation specs
		ToolType = "Axe",
		Power = 20,
	},

	StonePickaxe = {
		MaxStack = 1,
		Type = "Equipment",
		EquipType = "Tool",
		Use = "Harvest",
		NodeTags = {"ResourceNode"},
		-- Validation specs
		ToolType = "Pickaxe",
		Power = 20,
	},

	StoneSword = {
		MaxStack = 1,
		Type = "Equipment",
		EquipType = "Weapon",
		Use = "Melee",
	},
}
