-- RecipeDB.lua
-- Phase1-2
-- Recipe database (data-driven crafting)

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
}
