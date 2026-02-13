-- UseController.lua
-- Phase 1-4-4
-- Client Use Input (Click/Key -> Use_Request)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Use"))
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local UseController = {}

-- Tunables
local MOUSE_COOLDOWN = 0.2
local nextClick = 0

local function newRid()
	return tostring(math.random(10000, 99999)) .. "-" .. tostring(os.clock())
end

function UseController:Init()
	-- Mouse Click
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local t = os.clock()
			if t < nextClick then return end
			nextClick = t + MOUSE_COOLDOWN
			
			local camera = workspace.CurrentCamera
			local mouse = Players.LocalPlayer:GetMouse()
			local target = mouse.Target
			local aimDir = camera.CFrame.LookVector
			
			-- Envelope 통일: { rid, data = { aim = ... } }
			Net.Fire(Contracts.Remotes.Request, {
				rid = newRid(),
				data = {
					aim = {
						dir = aimDir,
						target = target,
					}
				}
			})
		end
	end)
	
	-- Note: Ideally we should listen to Use_Ack to play effects clientside
	Net.On(Contracts.Remotes.Ack, function(payload)
		if payload.ok then
			-- Success
			-- print("[UseClient] Success")
		else
			-- Fail
			-- warn("[UseClient] Failed: " .. tostring(payload.code))
		end
	end)

	print("[UseController] ready")
end

return UseController
