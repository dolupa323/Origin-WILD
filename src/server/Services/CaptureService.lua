-- CaptureService.lua
-- Phase 1-6 (Palworld Mechanics)
-- Logic for capturing AI entities into the player's Palbox.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Attr = require(Shared:WaitForChild("Attr"))
local SaveService = require(script.Parent.SaveService)
local FeedbackService = require(script.Parent.FeedbackService)

local CaptureService = {}

function CaptureService.TryCapture(player, targetModel)
	if not targetModel or not targetModel.Parent then return false, "INVALID_TARGET" end
	
	-- Verify if it's an AI and not a player
	if Players:GetPlayerFromCharacter(targetModel) then return false, "CANNOT_CAPTURE_PLAYER" end
	
	local hum = targetModel:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false, "TARGET_DEAD" end
	
	-- Calculate Chance (Palworld style: lower HP = higher chance)
	local hpRatio = hum.Health / hum.MaxHealth
	local baseChance = 0.3 -- 30% base
	local chance = baseChance + (1 - hpRatio) * 0.6 -- Up to 90% at low HP
	
	local roll = math.random()
	-- print(("[Capture] Player %s roll ..."):format(player.Name))
	
	if roll <= chance then
		-- SUCCESS
		CaptureService.OnSuccess(player, targetModel)
		return true, "SUCCESS"
	else
		-- FAIL
		FeedbackService.ShowDamage(targetModel:GetPivot().Position, 0, "Default") -- Show "0" or "Escaped" 
		return false, "ESCAPED"
	end
end

function CaptureService.OnSuccess(player, targetModel)
	local entityId = targetModel:GetAttribute(Attr.EntityId) or "Unknown"
	local aiName = targetModel.Name
	
	-- 1. Create Pal Data
	local palData = {
		EntityId = entityId,
		Type = aiName,
		Level = targetModel:GetAttribute("Level") or 1,
		Nickname = aiName,
		CapturedAt = os.time(),
		Stats = {
			HP = 100, -- Default for captured
			MaxHP = 100,
			Attack = 10,
			WorkSpeed = 50,
		}
	}
	
	-- 2. Add to Player Save
	local save = SaveService.Get(player)
	if save and save.Pals then
		table.insert(save.Pals.Palbox, palData)
	end
	
	-- 3. Visuals & Removal
	-- Broadcast capture effect (TBD: EffectService)
	Net.Broadcast("Effect_Capture", { pos = targetModel:GetPivot().Position, success = true })
	
	-- Destroy the AI
	targetModel:Destroy()
	
	-- Notify Client (Optional UI popup)
	Net.Fire("UI_Notification", player, { msg = "Captured " .. aiName .. "!" })
end

function CaptureService:Init()
	Net.Register({ "Effect_Capture", "UI_Notification" })
	print("[CaptureService] ready")
end

return CaptureService
