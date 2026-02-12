-- AIService.lua
-- Phase0-0-11
-- Server authoritative AI framework: StateMachine + Spawn + Pathfinding integration

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Tags = require(Shared:WaitForChild("Tags"))
local Attr = require(Shared:WaitForChild("Attr"))

local EntityService = require(script.Parent.EntityService)
local FeedbackService = require(script.Parent.FeedbackService)

local AIService = {}

----- ===== Tunables =====
local SPAWN_OFFSET_DIST = 15      -- studs from player HRP
local DETECTION_RANGE = 30        -- studs (Idle -> Chase)
local ATTACK_RANGE = 10           -- studs (Chase -> Attack, must match CombatSystem.MELEE_RANGE)
local AI_MOVE_SPEED = 20          -- studs/second
local ATTACK_COOLDOWN = 0.5       -- seconds (AI's own cooldown, separate from CombatSystem)
local TICK_DT = 0.1               -- internal update rate

----- ===== State Machine Definition =====

local States = {
	Idle = "Idle",
	Chase = "Chase",
	Attack = "Attack",
	Dead = "Dead",
}

----- ===== AI Registry =====

-- aiId -> aiState (internal tracking)
local aiRegistry = {}

local function now()
	return os.clock()
end

local function createAIState(aiModel, targetPlayer)
	--[[
		aiState = {
			aiId: string (GUID),
			aiModel: Model,
			targetPlayer: Player,
			state: "Idle" | "Chase" | "Attack" | "Dead",
			spawnTime: number,
			lastAttackTime: number,
			lastAttackDir: Vector3?,
		}
	]]
	return {
		aiId = aiModel:GetAttribute(Attr.EntityId) or "UNKNOWN",
		aiModel = aiModel,
		targetPlayer = targetPlayer,
		state = States.Idle,
		spawnTime = now(),
		lastAttackTime = 0,
		lastAttackDir = nil,
	}
end

local function getAIRootPart(aiModel: Model): BasePart?
	return aiModel:FindFirstChild("HumanoidRootPart")
end

local function getAIHumanoid(aiModel: Model): Humanoid?
	return aiModel:FindFirstChildOfClass("Humanoid")
end

local function getPlayerOrigin(player: Player): Vector3?
	local char = player.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position
	end
	return nil
end

local function distance(a: Vector3, b: Vector3): number
	return (a - b).Magnitude
end

----- ===== State Behavior =====

local function stateIdle(aiState)
	local targetPlayer = aiState.targetPlayer
	if not targetPlayer or not targetPlayer.Parent then
		return States.Dead
	end

	local aiPos = getAIRootPart(aiState.aiModel)
	if not aiPos then return States.Dead end

	local targetPos = getPlayerOrigin(targetPlayer)
	if not targetPos then return States.Idle end

	local dist = distance(aiPos.Position, targetPos)
	if dist <= DETECTION_RANGE then
		return States.Chase
	end

	return States.Idle
end

local function stateChase(aiState, dt)
	local targetPlayer = aiState.targetPlayer
	if not targetPlayer or not targetPlayer.Parent then
		return States.Dead
	end

	local aiModel = aiState.aiModel
	local aiRoot = getAIRootPart(aiModel)
	local aiHum = getAIHumanoid(aiModel)

	if not aiRoot or not aiHum or aiHum.Health <= 0 then
		return States.Dead
	end

	local targetPos = getPlayerOrigin(targetPlayer)
	if not targetPos then return States.Idle end

	local aiPos = aiRoot.Position
	local dist = distance(aiPos, targetPos)

	-- Check attack range
	if dist <= ATTACK_RANGE then
		return States.Attack
	end

	-- Check if target out of detection range (lose target)
	if dist > DETECTION_RANGE * 1.5 then
		return States.Idle
	end

	-- Move towards player
	local dir = (targetPos - aiPos).Unit
	local moveDir = dir * AI_MOVE_SPEED * dt

	aiRoot.Velocity = Vector3.new(moveDir.X, aiRoot.Velocity.Y, moveDir.Z)

	print(("[AI] %s Chase: dist=%.2f target_pos=%s"):format(
		aiModel.Name, dist, tostring(targetPos)
	))

	return States.Chase
end

local function stateAttack(aiState, dt)
	local targetPlayer = aiState.targetPlayer
	if not targetPlayer or not targetPlayer.Parent then
		return States.Dead
	end

	local aiModel = aiState.aiModel
	local aiRoot = getAIRootPart(aiModel)
	local aiHum = getAIHumanoid(aiModel)

	if not aiRoot or not aiHum or aiHum.Health <= 0 then
		return States.Dead
	end

	local targetPos = getPlayerOrigin(targetPlayer)
	if not targetPos then return States.Idle end

	local aiPos = aiRoot.Position
	local dist = distance(aiPos, targetPos)

	-- Out of range, return to chase
	if dist > ATTACK_RANGE * 1.5 then
		return States.Chase
	end

	-- Attack cooldown check
	local t = now()
	if t < aiState.lastAttackTime + ATTACK_COOLDOWN then
		-- Cooldown active, hold position
		return States.Attack
	end

	-- Perform attack
	aiState.lastAttackTime = t
	local aimDir = (targetPos - aiPos).Unit
	aiState.lastAttackDir = aimDir

	print(("[AI] %s Attack: raycast origin=%s dir=%s range=%d target_dist=%.2f"):format(
		aiModel.Name, tostring(aiPos), tostring(aimDir), ATTACK_RANGE, dist
	))

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { aiModel }
	params.IgnoreWater = true

	local origin = aiPos + Vector3.new(0, 2, 0)  -- ⭐ 머리/가슴 높이
	local result = workspace:Raycast(origin, aimDir * ATTACK_RANGE, params)

	if result then
		local hitInst = result.Instance
		print(("[AI] %s Attack: raycast hit %s"):format(aiModel.Name, hitInst:GetFullName()))

		-- Find Humanoid from hit
		local model = hitInst:FindFirstAncestorOfClass("Model")
		if model then
			print(("[AI] %s Attack: found model %s"):format(aiModel.Name, model:GetFullName()))
			local hum = model and model:FindFirstChildOfClass("Humanoid")
			
			-- ⭐ 추가: 플레이어 캐릭터 강제 fallback
			if not hum then
				local player = Players:GetPlayerFromCharacter(model)
				if player and player.Character then
					model = player.Character      -- ⭐ 핵심: model을 캐릭터로 교체
					hum = model:FindFirstChildOfClass("Humanoid")
				end
			end
			
			if hum then
				print(("[AI] %s Attack: found humanoid, health=%d"):format(aiModel.Name, hum.Health))
				if hum.Health > 0 then
					-- Apply damage (15 same as CombatSystem)
					local dmg = 15
					local before = hum.Health
					hum:TakeDamage(dmg)
					local after = hum.Health
					
					FeedbackService.ShowDamage(model:GetPivot().Position, dmg, "Critical")

					print(("[AI] %s Attack: hit=%s dmg=%d hp %.1f->%.1f"):format(
						aiModel.Name, model:GetFullName(), dmg, before, after
					))

					-- Apply burn to victim if it's a player
					local victimPlayer = Players:GetPlayerFromCharacter(model)
					if victimPlayer then
						local EffectService = require(script.Parent.EffectService)
						EffectService.Apply(victimPlayer, "Burn", 3, 1)
					end
				else
					print(("[AI] %s Attack: humanoid already dead (health=%d)"):format(aiModel.Name, hum.Health))
				end
			else
				print(("[AI] %s Attack: no humanoid found in model"):format(aiModel.Name))
			end
		else
			print(("[AI] %s Attack: no model ancestor found for %s"):format(aiModel.Name, hitInst:GetFullName()))
		end
	else
		print(("[AI] %s Attack: raycast missed (dist=%.2f)"):format(aiModel.Name, dist))
	end

	return States.Attack
end

local function stateDead(aiState)
	-- Dead state: AI should be cleaned up
	-- For Phase0, just stay in Dead state
	return States.Dead
end

----- ===== Core API =====

function AIService.SpawnAI(position: Vector3, targetPlayer: Player, opts: table?): Model?
	opts = opts or {}

	-- Create Model
	local aiModel = Instance.new("Model")
	local targetName = (targetPlayer and targetPlayer.Name) or "Unknown"
	aiModel.Name = opts.Name or "AI_" .. targetName

	-- Create HumanoidRootPart
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Anchored = false
	hrp.CanCollide = false
	hrp.Parent = aiModel

	-- Create Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Anchored = false
	head.CanCollide = false
	head.Parent = aiModel

	-- Create Humanoid
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = opts.MaxHP or 50
	hum.Health = opts.HP or hum.MaxHealth
	hum.Parent = aiModel

	-- Position
	hrp.Position = position
	head.Position = hrp.Position + Vector3.new(0, 2, 0)

	-- Parent to workspace
	aiModel.Parent = workspace

	-- Register as entity
	EntityService.CreateEntity(aiModel, {
		Faction = opts.Faction or "Enemy",
		HP = hum.Health,
		MaxHP = hum.MaxHealth,
		OwnerUserId = targetPlayer.UserId,
	})

	-- Add tags
	CollectionService:AddTag(aiModel, Tags.Entity)
	CollectionService:AddTag(hrp, Tags.Entity)
	CollectionService:AddTag(head, Tags.Entity)
	CollectionService:AddTag(aiModel, Tags.Damageable)
	CollectionService:AddTag(hrp, Tags.Damageable)
	CollectionService:AddTag(head, Tags.Damageable)

	-- Set attributes
	local entityId = aiModel:GetAttribute(Attr.EntityId)
	hrp:SetAttribute("HP", hum.Health)
	hrp:SetAttribute("MaxHP", hum.MaxHealth)
	head:SetAttribute("HP", hum.Health)
	head:SetAttribute("MaxHP", hum.MaxHealth)

	local aiState = createAIState(aiModel, targetPlayer)
	aiRegistry[entityId] = aiState

	-- Expose to attributes for UI
	aiModel:SetAttribute("Level", opts.Level or math.random(1, 5))
	aiModel:SetAttribute("State", aiState.state)
	aiModel:SetAttribute("WorkPower", opts.WorkPower or 10)

	print(("[AI] Spawned %s (entityId=%s) at %s for player %s"):format(
		aiModel.Name, entityId, tostring(position), targetPlayer.Name
	))

	return aiModel
end

function AIService.GetAIState(aiModel: Model)
	local entityId = aiModel:GetAttribute(Attr.EntityId)
	if not entityId then return nil end
	return aiRegistry[entityId]
end

----- ===== Internal Ticking =====

local function stepTick(dt)
	for entityId, aiState in pairs(aiRegistry) do
		local aiModel = aiState.aiModel
		if not aiModel or not aiModel.Parent then
			aiRegistry[entityId] = nil
			continue
		end

		local hum = getAIHumanoid(aiModel)
		if not hum or hum.Health <= 0 then
			aiState.state = States.Dead
			aiRegistry[entityId] = nil
			print(("[AI] %s died, unregistered"):format(aiModel.Name))
			continue
		end

		-- State machine
		local newState = aiState.state
		if aiState.state == States.Idle then
			newState = stateIdle(aiState)
		elseif aiState.state == States.Chase then
			newState = stateChase(aiState, dt)
		elseif aiState.state == States.Attack then
			newState = stateAttack(aiState, dt)
		elseif aiState.state == States.Dead then
			newState = stateDead(aiState)
		end

		if newState ~= aiState.state then
			print(("[AI] %s state transition: %s -> %s"):format(aiModel.Name, aiState.state, newState))
			aiState.state = newState
			aiModel:SetAttribute("State", newState)
		end
		
		-- Sync HP for UI
		aiModel:SetAttribute("HP", hum.Health)
		aiModel:SetAttribute("MaxHP", hum.MaxHealth)
	end
end

local tickConn = nil
local accum = 0

function AIService:Init()
	if tickConn then tickConn:Disconnect() end
	tickConn = RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum >= TICK_DT then
			accum = 0
			stepTick(TICK_DT)
		end
	end)

	print("[AIService] ready")
end

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(p)
	-- Remove all AI targeting this player
	local toRemove = {}
	for entityId, aiState in pairs(aiRegistry) do
		if aiState.targetPlayer == p then
			table.insert(toRemove, entityId)
		end
	end
	for _, entityId in ipairs(toRemove) do
		aiRegistry[entityId] = nil
	end
end)

return AIService
