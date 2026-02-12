-- DamageUI.lua
-- Phase 1-6 (UX Improvement)
-- Renders floating damage numbers in 3D space.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local DamageUI = {}

local COLORS = {
	Default = Color3.fromRGB(255, 255, 255),
	Critical = Color3.fromRGB(255, 50, 50),
	Resource = Color3.fromRGB(255, 200, 50),
	Heal = Color3.fromRGB(50, 255, 50)
}

function DamageUI:Init()
	Net.On("Effect_DamageNum", function(payload)
		DamageUI.Create(payload.pos, payload.amount, payload.type)
	end)
	print("[DamageUI] listening for damage events")
end

function DamageUI.Create(position, amount, damageType)
	local folder = workspace:FindFirstChild("VFX") or Instance.new("Folder", workspace)
	folder.Name = "VFX"

	local part = Instance.new("Part")
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.Position = position + Vector3.new(0, 2, 0)
	part.Parent = folder

	local bg = Instance.new("BillboardGui")
	bg.Size = UDim2.new(0, 100, 0, 50)
	bg.Adornee = part
	bg.AlwaysOnTop = true
	bg.Parent = part

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = tostring(math.floor(amount))
	lbl.TextColor3 = COLORS[damageType] or COLORS.Default
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 24
	lbl.TextStrokeTransparency = 0.5
	lbl.Parent = bg

	-- Random drift
	local drift = Vector3.new(math.random(-2, 2), 3, math.random(-2, 2))
	
	-- Animations
	local ti = TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	
	TweenService:Create(part, ti, {
		Position = part.Position + drift
	}):Play()
	
	TweenService:Create(lbl, ti, {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Size = UDim2.new(1.5, 0, 1.5, 0)
	}):Play()

	game:GetService("Debris"):AddItem(part, 1)
end

return DamageUI
