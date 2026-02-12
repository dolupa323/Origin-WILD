-- FeedbackService.lua
-- Phase 1-6 (UX Improvement)
-- Server-side service to broadcast visual feedback (Damage numbers, etc) to clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local FeedbackService = {}

function FeedbackService.ShowDamage(position: Vector3, amount: number, damageType: string?)
	Net.Broadcast("Effect_DamageNum", {
		pos = position,
		amount = amount,
		type = damageType or "Default"
	})
end

function FeedbackService:Init()
	Net.Register({ "Effect_DamageNum" })
	print("[FeedbackService] ready")
end

return FeedbackService
