-- server_init.server.lua
-- Phase0: services/systems will be loaded here in strict order.
-- return true

require(script.Parent.Services.SaveService)
require(script.Parent.Services.InventoryService)
print("[InventoryService] ready")

-- ✅ Phase0-6 EquipService 로드/바인딩
local EquipService = require(script.Parent.Services.EquipService)
if EquipService.Init then
	EquipService:Init()
else
	warn("[EquipService] missing Init()")
end
print("[EquipService] ready")

return true
