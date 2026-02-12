-- FeedbackService.lua
-- Phase 1-6 (UX Improvement)
-- Server-side service to broadcast visual feedback (Damage numbers, etc) to clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local FeedbackService = {}

function FeedbackService.ShowDamage(position: Vector3, amount: number, damageType: string?)
	-- Broadcast to all clients (Simple for Phase 1)
	-- In production, you'd only send to players within range.
	Net.Fire("Effect_DamageNum", nil, {
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
