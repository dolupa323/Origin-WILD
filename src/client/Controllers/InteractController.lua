-- InteractController.lua
-- Phase 1-5-2
-- Client Interaction Input (E key) -> Interact_Request

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Interact"))

local InteractController = {}

-- Tunables
local INTERACT_KEY = Enum.KeyCode.E
local COOLDOWN = 0.25
local nextRequest = 0

local function newRid()
	return tostring(math.random(10000, 99999)) .. "-" .. tostring(os.clock())
end

function InteractController:Init()
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		
		if input.KeyCode == INTERACT_KEY then
			local t = os.clock()
			if t < nextRequest then return end
			nextRequest = t + COOLDOWN
			
			-- Client-side prediction or aim check (optional but good for UX)
			local camera = workspace.CurrentCamera
			local aimDir = camera.CFrame.LookVector
			
			-- Send Request
			print("[InteractClient] request E key")
			Net.Fire(Contracts.Remotes.Request, {
				rid = newRid(),
				-- We send aim direction, server does raycast from character origin
				data = {
					aim = {
						dir = aimDir
					}
				}
			})
		end
	end)

	Net.On(Contracts.Remotes.Ack, function(payload)
		if payload.ok then
			print(("[InteractClient] Success: %s"):format(tostring(payload.msg or "OK")))
			if payload.data then
				for k,v in pairs(payload.data) do
					print(("  %s = %s"):format(k, tostring(v)))
				end
			end
			
			-- Refresh Hotbar just in case (e.g. picked up ammo or item into active slot)
			local HotbarController = require(script.Parent.HotbarController)
			if HotbarController.Refresh then
				HotbarController.Refresh()
			end
		else
			warn(("[InteractClient] Failed: %s"):format(tostring(payload.code or "Unknown")))
		end
	end)

	print("[InteractController] ready (Press E)")
end

return InteractController
