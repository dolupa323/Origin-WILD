-- SaveService.lua
-- Phase0-0-4
-- Centralized persistent storage

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Code.Shared.Types)

local SaveService = {}

local STORE = DataStoreService:GetDataStore("WILD_SAVE_V5")
print("[SaveService] STORE = WILD_SAVE_V5")

local cache: {[number]: table} = {}

-------------------------------------------------
-- Internal
-------------------------------------------------

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local r = {}
	for k,v in pairs(t) do
		r[k] = deepCopy(v)
	end
	return r
end

-------------------------------------------------
-- Core API
-------------------------------------------------

function SaveService.Get(player)
	return cache[player.UserId]
end

function SaveService.Load(player)
	local key = "P_" .. player.UserId

	local data
	local ok, err = pcall(function()
		data = STORE:GetAsync(key)
	end)
  print("[SaveService] Load key =", key, "found =", data ~= nil)

	if not ok then
		warn("[SaveService] Load failed:", err)
	end

	if not data then
		data = Types.NewPlayerSave()
	end
  -- Hard normalize inventory slots (phase0)
if not data.Inventory then data.Inventory = {} end
if type(data.Inventory.Slots) ~= "table" then data.Inventory.Slots = {} end

for i = 1, 30 do
	if data.Inventory.Slots[i] == nil then
		data.Inventory.Slots[i] = nil
	end
end

	cache[player.UserId] = data
	return data
end

function SaveService.Save(player)
	local data = cache[player.UserId]
	if not data then return end

	local key = "P_" .. player.UserId

	local ok, err = pcall(function()
		STORE:SetAsync(key, data)
	end)

	if not ok then
		warn("[SaveService] Save failed:", err)
	end
end

function SaveService.Release(player)
	cache[player.UserId] = nil
end

-------------------------------------------------
-- Lifecycle hooks
-------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	SaveService.Load(player)
end)

Players.PlayerRemoving:Connect(function(player)
	SaveService.Save(player)
	SaveService.Release(player)
end)

-- autosave
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			SaveService.Save(player)
		end
	end
end)

return SaveService
