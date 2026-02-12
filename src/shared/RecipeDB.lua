-- RecipeDB.lua
-- Shared recipe database (client reads for UI, server validates)

return {
	StoneAxe = {
		inputs = { {id="Wood", qty=3}, {id="Stone", qty=2} },
		outputs = { {id="StoneAxe", qty=1} },
		time = 0,
	},
	StonePickaxe = {
		inputs = { {id="Wood", qty=2}, {id="Stone", qty=3} },
		outputs = { {id="StonePickaxe", qty=1} },
		time = 0,
	},
	StoneSword = {
		inputs = { {id="Wood", qty=2}, {id="Stone", qty=2} },
		outputs = { {id="StoneSword", qty=1} },
		time = 0,
	},
}
