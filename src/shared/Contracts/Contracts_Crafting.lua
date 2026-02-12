-- Contracts_Crafting.lua
-- Phase1-2
-- Crafting system contracts

local C = {}

C.Error = {
	OK = "OK",
	VALIDATION_FAILED = "VALIDATION_FAILED",
	OUT_OF_RANGE = "OUT_OF_RANGE",
	COOLDOWN = "COOLDOWN",
	NOT_ENOUGH_ITEMS = "NOT_ENOUGH_ITEMS",
	INVENTORY_FULL = "INVENTORY_FULL",
	DENIED = "DENIED",
	NOT_FOUND = "NOT_FOUND",
	INTERNAL_ERROR = "INTERNAL_ERROR",
}

C.Remotes = {
	"Craft_Request",
	"Craft_Ack",
}

return C
