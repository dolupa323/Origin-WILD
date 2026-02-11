-- ClientBootstrap.client.lua
-- Phase0-0-1: client boot only. No UI gameplay yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Repo mounts under "Code"
local CodeRS = ReplicatedStorage:WaitForChild("Code")
local Shared = CodeRS:WaitForChild("Shared")

-- Deterministic path (matches Explorer): StarterPlayerScripts/Code/Client
local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local CodeSP = StarterPlayerScripts:WaitForChild("Code")
local Client = CodeSP:WaitForChild("Client")

local function safeRequire(moduleScript: ModuleScript)
	local ok, result = pcall(require, moduleScript)
	if not ok then
		warn("[BOOT][REQUIRE_FAIL]", moduleScript:GetFullName(), result)
		error(result)
	end
	return result
end

print("[BOOT][CLIENT] start")

safeRequire(Shared:WaitForChild("shared_init"))
safeRequire(Client:WaitForChild("client_init"))

print("[BOOT][CLIENT] ready")
