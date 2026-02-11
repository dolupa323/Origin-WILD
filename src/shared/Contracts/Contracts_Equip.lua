local C = {}

C.Error = {
	OK = "OK",
	VALIDATION_FAILED = "VALIDATION_FAILED",
	OUT_OF_RANGE = "OUT_OF_RANGE",
	COOLDOWN = "COOLDOWN",
	NOT_FOUND = "NOT_FOUND",
	DENIED = "DENIED",
	INTERNAL_ERROR = "INTERNAL_ERROR",
}

C.EquipSlots = {
	Tool = true,
	Weapon = true,
	Armor = true,
	Shield = true,
	PalGear = true,
}

return C
