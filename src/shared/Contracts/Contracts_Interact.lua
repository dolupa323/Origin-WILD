-- Contracts_Interact.lua
-- Phase 1-5-0
-- Defines constants and remotes logic for Interaction system (Pickup, Open, etc)

local Contracts_Interact = {}

-- 1. Error Codes
Contracts_Interact.ErrorCodes = {
	OK = "OK",
	NOT_FOUND = "NOT_FOUND",
	TOO_FAR = "TOO_FAR",
	INVENTORY_FULL = "INVENTORY_FULL",
	INTERNAL_ERROR = "INTERNAL_ERROR",
}

-- 2. Remote Definitions
Contracts_Interact.Remotes = {
	Request = "Interact_Request", -- Client -> Server: { targetId (instance or guid) }
	Ack = "Interact_Ack",         -- Server -> Client: { ok, code, action, ... }
}

-- 3. Constants
Contracts_Interact.InteractableTag = "Interactable"

return Contracts_Interact
