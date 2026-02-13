-- InteractController.lua
-- Client Interaction Input (E key) -> Interact_Request
-- Sends mouse target + hitPos for server-side validation (parallax fix)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Interact"))

local InteractController = {}

-- Pre-cache modules (avoid repeated require in event handlers)
local CraftingUI = require(script.Parent.Parent.UI.CraftingUI)
local HotbarController = require(script.Parent.HotbarController)

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

			-- Send actual mouse target instead of camera direction (parallax fix)
			local mouse = Players.LocalPlayer:GetMouse()
			local target = mouse.Target
			local hitPos = mouse.Hit.Position
			local camera = workspace.CurrentCamera
			local aimDir = camera.CFrame.LookVector

			Net.Fire(Contracts.Remotes.Request, {
				rid = newRid(),
				data = {
					aim = { dir = aimDir },
					target = target,
					hitPos = hitPos,
				},
			})
		end
	end)

	Net.On(Contracts.Remotes.Ack, function(payload)
		if payload.ok then
			-- Check if CraftBench was opened
			if payload.data and payload.data.bench then
				if CraftingUI then
					CraftingUI.SetVisible(true)
				end
			end

			-- Refresh Hotbar (item might have changed)
			if HotbarController and HotbarController.Refresh then
				HotbarController.Refresh()
			end
		end
	end)
end

return InteractController
