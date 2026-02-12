-- Contracts_Inventory.lua
-- Phase 1-6 (UX Improvement)
-- Inventory synchronization and management.

local Contracts_Inventory = {}

Contracts_Inventory.Remotes = {
	SyncRequest = "Inventory_SyncRequest", -- Client -> Server: {}
	Update = "Inventory_Update",           -- Server -> Client: { slots = {} }
	SwapRequest = "Inventory_SwapRequest", -- Client -> Server: { fromIdx, toIdx }
}

return Contracts_Inventory
