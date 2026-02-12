-- Contracts_Use.lua
-- Phase 1-4-0
-- Defines constants and remotes logic for Use system

local Contracts_Use = {}

-- 1. Error Codes
Contracts_Use.ErrorCodes = {
	OK = "OK",
	NO_ACTIVE_ITEM = "NO_ACTIVE_ITEM",
	COOLDOWN = "COOLDOWN",
	VALIDATION_FAILED = "VALIDATION_FAILED",
	INTERNAL_ERROR = "INTERNAL_ERROR",
}

-- 2. Remote Definitions
Contracts_Use.Remotes = {
	Request = "Use_Request", -- Client -> Server: { aim = { dir=Vector3 } }
	Ack = "Use_Ack",         -- Server -> Client: { ok, code, ... }
}

return Contracts_Use
