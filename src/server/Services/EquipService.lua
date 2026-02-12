local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")

local Net = require(Shared:WaitForChild("Net"))
local EquipRegistry = require(Shared:WaitForChild("Equip"):WaitForChild("EquipRegistry"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Equip"))

local SaveService = require(script.Parent:WaitForChild("SaveService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local ResourceNodeService = require(script.Parent:WaitForChild("ResourceNodeService"))
local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))

local EquipService = {}

local cooldowns = {} -- cooldowns[userId][key] = nextTime

local function now()
	return os.clock()
end

local function ack(rid, ok, code, msg, data)
	return { rid=rid, ok=ok, code=code, msg=msg, data=data }
end

local function validateEnvelope(p)
	return type(p) == "table" and type(p.rid) == "string" and type(p.data) == "table"
end

local function validEquipSlot(name)
	return Contracts.EquipSlots[name] == true
end

local function getSave(player)
	-- SaveService는 점 호출(Get)인 걸 InventoryService에서 이미 사용 중
	return SaveService.Get(player)
end

local function getEquipTable(player)
	local s = getSave(player)
	s.Inventory.Equip = s.Inventory.Equip or {}
	return s.Inventory.Equip
end

local function getSlots(player)
	return InventoryService.GetSlots(player)
end

local function bucket(userId)
	local b = cooldowns[userId]
	if not b then
		b = {}
		cooldowns[userId] = b
	end
	return b
end

local function passCooldown(userId, key, cd)
	if not cd or cd <= 0 then return true end
	local t = now()
	local b = bucket(userId)
	local nextOk = b[key] or 0
	if t < nextOk then return false end
	b[key] = t + cd
	return true
end

local function cloneSlot(s)
	if not s then return nil end
	return { ItemId=s.ItemId, Qty=s.Qty, Durability=s.Durability, Meta=s.Meta }
end

local function takeOneFromIndex(player, idx)
	local slots = getSlots(player)
	local s = slots[idx]
	if not s then return nil, "NOT_FOUND", "empty slot" end
	-- 1개만 장착 대상으로 처리(Phase0 최소)
	local one = { ItemId=s.ItemId, Qty=1, Durability=s.Durability, Meta=s.Meta }
	s.Qty -= 1
	if s.Qty <= 0 then slots[idx] = nil end
	return one
end

local function putSlotIntoIndexOrAdd(player, idx, slot)
	-- 우선 idx가 비어있으면 거기에 넣고, 아니면 AddItem로 남은 qty 넣기
	local slots = getSlots(player)
	if not slots[idx] then
		slots[idx] = cloneSlot(slot)
		return true
	end
	-- 같은 아이템이면 AddItem로 합치기(단순)
	return InventoryService.AddItem(player, slot.ItemId, slot.Qty)
end

function EquipService:_handleEquip(player, payload)
	if not validateEnvelope(payload) then
		return ack(payload and payload.rid or "?", false, Contracts.Error.VALIDATION_FAILED, "bad envelope")
	end

	local rid = payload.rid
	local data = payload.data

	local fromIdx = data.fromIdx
	local equipSlot = data.equipSlot

	if type(fromIdx) ~= "number" or fromIdx < 1 or fromIdx > 30 then
		return ack(rid, false, Contracts.Error.OUT_OF_RANGE, "fromIdx must be 1..30")
	end
	if type(equipSlot) ~= "string" or not validEquipSlot(equipSlot) then
		return ack(rid, false, Contracts.Error.DENIED, "invalid equipSlot")
	end

	local equip = getEquipTable(player)
	local current = equip[equipSlot] -- Slot? (equipped)

	-- Slots[fromIdx]에서 1개 뽑기
	local one, ecode, emsg = takeOneFromIndex(player, fromIdx)
	if not one then
		return ack(rid, false, Contracts.Error.NOT_FOUND, emsg)
	end

	-- 장착 슬롯에 이미 있으면: swap(현재 장착을 인벤으로 반환)
	if current then
		local okBack = putSlotIntoIndexOrAdd(player, fromIdx, current)
		if not okBack then
			-- 롤백: 뽑았던 one을 다시 넣기
			putSlotIntoIndexOrAdd(player, fromIdx, one)
			return ack(rid, false, Contracts.Error.INTERNAL_ERROR, "cannot return equipped to inventory")
		end
	end

	-- 새 장착 세팅(1개만)
	equip[equipSlot] = one

	-- OnEquip 훅
	local mod = EquipRegistry:Get(one.ItemId)
	if mod and mod.OnEquip then
		local okHook, code = mod.OnEquip({ player=player, equipSlot=equipSlot, slot=one })
		if okHook == false then
			return ack(rid, false, code or Contracts.Error.DENIED, "OnEquip denied")
		end
	end

	return ack(rid, true, Contracts.Error.OK, nil, { equipSlot=equipSlot, itemId=one.ItemId })
end

function EquipService:_handleUse(player, payload)
	if not validateEnvelope(payload) then
		return ack(payload and payload.rid or "?", false, Contracts.Error.VALIDATION_FAILED, "bad envelope")
	end

	local rid = payload.rid
	local data = payload.data

	local equipSlot = data.equipSlot
	if type(equipSlot) ~= "string" or not validEquipSlot(equipSlot) then
		return ack(rid, false, Contracts.Error.VALIDATION_FAILED, "bad equipSlot")
	end

	local equip = getEquipTable(player)
	local slot = equip[equipSlot]
	if not slot then
		return ack(rid, false, Contracts.Error.NOT_FOUND, "nothing equipped")
	end

	local mod = EquipRegistry:Get(slot.ItemId)
	if not mod or not mod.OnUse then
		return ack(rid, false, Contracts.Error.DENIED, "no OnUse")
	end

	local cd = tonumber(mod.Cooldown) or 0
	local cdKey = "Use:"..equipSlot..":"..tostring(slot.ItemId)
	if not passCooldown(player.UserId, cdKey, cd) then
		return ack(rid, false, Contracts.Error.COOLDOWN, "cooldown")
	end

	local okHook, code, outData = mod.OnUse({
		player=player,
		equipSlot=equipSlot,
		slot=slot,
		aim=data.aim,
		mode=data.mode,
		ResourceNodeService=ResourceNodeService,
		CombatSystem=CombatSystem,
	})
	if okHook == false then
		return ack(rid, false, code or Contracts.Error.DENIED, "OnUse denied")
	end

	return ack(rid, true, Contracts.Error.OK, nil, outData)
end

-- Phase 1-4-2: Expose DispatchUse for UseService
function EquipService.DispatchUse(itemId, ctx)
	local mod = EquipRegistry:Get(itemId)
	if not mod or not mod.OnUse then
		return false, "NO_HANDLER_OR_MODULE"
	end
	
	-- Pass cooldown check here if needed, or rely on UseService's check?
	-- UseService does Global Cooldown (0.2s). Item might have its own cooldown.
	-- Let's doing item cooldown check here.
	local player = ctx.player
	local cd = tonumber(mod.Cooldown) or 0
	-- Note: EquipService uses "Use:EquipSlot:ItemId" for key.
	-- Hotbar usage doesn't have "EquipSlot". Key convention: "Hotbar:ItemId"?
	-- Or just "Use:ItemId"?
	-- Let's use "Use:Item:ItemId" for now.
	local cdKey = "Use:Item:"..tostring(itemId)
	
	if not passCooldown(player.UserId, cdKey, cd) then
		return false, "COOLDOWN"
	end

	local ok, code, data = mod.OnUse(ctx)
	if not ok then
		return false, code or "HANDLER_FAIL", data
	end
	
	return true, "OK", { handler = itemId, data = data }
end

function EquipService:Init()
	-- Phase 0: Register "Equip_*" net messages
	-- (Previously defined, keeping them for backward compat if any test uses them)
	-- But Phase 1-4-2 UseService handles "Use_Request".
	-- We just keep existing inits.
	
	Net.Register({ "Equip_Request", "Equip_Use", "Equip_Ack" })

	Net.On("Equip_Request", function(player, payload)
		Net.Fire("Equip_Ack", player, self:_handleEquip(player, payload))
	end)

	Net.On("Equip_Use", function(player, payload)
		Net.Fire("Equip_Ack", player, self:_handleUse(player, payload))
	end)
	
	print("[EquipService] ready")
end

Players.PlayerRemoving:Connect(function(p)
	cooldowns[p.UserId] = nil
end)

return EquipService
