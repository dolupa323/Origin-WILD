-- Bootstrap.server.lua
-- Phase0-0-1: engine boot only. No gameplay logic here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Repo mounts under "Code"
local CodeRS = ReplicatedStorage:WaitForChild("Code")
local Shared = CodeRS:WaitForChild("Shared")

local CodeSS = ServerScriptService:WaitForChild("Code")
local Server = CodeSS:WaitForChild("Server")

local function safeRequire(moduleScript: ModuleScript)
	local ok, result = pcall(require, moduleScript)
	if not ok then
		warn("[BOOT][REQUIRE_FAIL]", moduleScript:GetFullName(), result)
		error(result)
	end
	return result
end

print("[BOOT][SERVER] start")

safeRequire(Shared:WaitForChild("shared_init"))
safeRequire(Server:WaitForChild("server_init"))

print("[BOOT][SERVER] ready")
