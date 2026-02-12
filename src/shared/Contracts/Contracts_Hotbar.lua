-- Contracts_Hotbar.lua
-- Phase 1-4-0
-- Defines constants and remotes logic for Hotbar system

local Contracts_Hotbar = {}

-- 1. Error Codes
Contracts_Hotbar.ErrorCodes = {
	OK = "OK",
	OUT_OF_RANGE = "OUT_OF_RANGE",
	EMPTY_SLOT = "EMPTY_SLOT",
	BAD_INV_SLOT = "BAD_INV_SLOT",
	INTERNAL_ERROR = "INTERNAL_ERROR",
}

-- 2. Remote Definitions (Naming convention only here, registration in Net.lua)
Contracts_Hotbar.Remotes = {
	Select = "Hotbar_Select", -- Client -> Server: { slotIndex = 1..9 }
	Ack = "Hotbar_Ack",       -- Server -> Client: { ok, code, activeSlot, invSlot, itemId, qty }
}

return Contracts_Hotbar
