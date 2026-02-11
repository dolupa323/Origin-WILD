-- Types.lua
local Types = {}

local function newSlots(n)
	local t = {}
	for i = 1, n do
		t[i] = nil
	end
	return t
end

Types.NewPlayerSave = function()
	local save = {
		Version = 1,

		Player = {
			Level = 1,
			Exp = 0,
			Stats = { HP=100, MaxHP=100, Stamina=100, Hunger=100, Temp=0 }
		},

		Inventory = {
			Slots = newSlots(30),
			Hotbar = newSlots(10),
			Equip = {},
		},

		Entitlements = {},
		Currency = { Gold = 0 },

		Pals = { Owned={}, Party={}, Palbox={} },
		Base = { Claims={}, Structures={} },
	}

	print("[Types] NewPlayerSave SlotsLen =", #save.Inventory.Slots)
	return save
end

return Types
