-- WildSphere.lua
-- Phase 1-6 (Palworld Mechanics)
-- Logic for throwing spheres to capture AI.

local WildSphere = {}

WildSphere.Cooldown = 0.5

function WildSphere.OnUse(ctx)
	local player = ctx.player
	local aim = ctx.aim
	
	if not aim or not aim.dir then
		return false, "MISSING_AIM"
	end
	
	-- 1. Raycast to find target
	local char = player.Character
	if not char then return false, "NO_CHAR" end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false, "NO_HRP" end
	
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { char }
	
	local hitResult = workspace:Raycast(hrp.Position, aim.dir.Unit * 30, rayParams)
	if not hitResult then
		return true, "MISS", { hit = false }
	end
	
	local hitInst = hitResult.Instance
	local monster = hitInst:FindFirstAncestorOfClass("Model")
	
	if not monster then
		return true, "MISS", { hit = false }
	end
	
	-- 2. Consume Item (Sphere is one-time use)
	-- *Note*: UseService calls this. We should tell UseService to consume.
	-- Or we call InventoryService.AddItem(player, itemId, -1)
	
	local InventoryService = require(game:GetService("ServerScriptService").Code.Server.Services.InventoryService)
	InventoryService.AddItem(player, "WildSphere", -1)
	
	-- 3. Trigger Capture Logic
	local CaptureService = require(game:GetService("ServerScriptService").Code.Server.Services.CaptureService)
	local ok, code = CaptureService.TryCapture(player, monster)
	
	return true, code, { success = (code == "SUCCESS") }
end

return WildSphere
