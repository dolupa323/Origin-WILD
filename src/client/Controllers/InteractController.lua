-- InteractController.lua
-- Client Interaction Input (E key) -> Interact_Request
-- Detects CraftBench response and opens CraftingUI

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Interact"))

local InteractController = {}

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

			local camera = workspace.CurrentCamera
			local aimDir = camera.CFrame.LookVector

			Net.Fire(Contracts.Remotes.Request, {
				rid = newRid(),
				data = {
					aim = { dir = aimDir },
				},
			})
		end
	end)

	Net.On(Contracts.Remotes.Ack, function(payload)
		if payload.ok then
			-- Check if CraftBench was opened
			if payload.data and payload.data.bench then
				local ok, CraftingUI = pcall(function()
					return require(script.Parent.Parent.UI.CraftingUI)
				end)
				if ok and CraftingUI then
					CraftingUI.SetVisible(true)
				end
			end

			-- Refresh Hotbar (item might have changed)
			local ok2, HotbarController = pcall(function()
				return require(script.Parent.HotbarController)
			end)
			if ok2 and HotbarController and HotbarController.Refresh then
				HotbarController.Refresh()
			end
		end
	end)
end

return InteractController
