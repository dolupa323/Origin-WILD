-- client_init.lua
-- Client boot: initialize all UI modules and controllers in order

task.spawn(function()
	local UI = script.Parent:WaitForChild("UI")
	local Controllers = script.Parent:WaitForChild("Controllers")

	-- UI First (order matters: some controllers reference UI)
	local HotbarUI = require(UI:WaitForChild("HotbarUI"))
	if HotbarUI.Init then HotbarUI:Init() end

	local InteractionUI = require(UI:WaitForChild("InteractionUI"))
	if InteractionUI.Init then InteractionUI:Init() end

	local DamageUI = require(UI:WaitForChild("DamageUI"))
	if DamageUI.Init then DamageUI:Init() end

	local InventoryUI = require(UI:WaitForChild("InventoryUI"))
	if InventoryUI.Init then InventoryUI:Init() end

	local CraftingUI = require(UI:WaitForChild("CraftingUI"))
	if CraftingUI.Init then CraftingUI:Init() end

	-- Controllers
	local InventoryController = require(Controllers:WaitForChild("InventoryController"))
	if InventoryController.Init then InventoryController:Init() end

	local HotbarController = require(Controllers:WaitForChild("HotbarController"))
	if HotbarController.Init then HotbarController:Init() end

	local UseController = require(Controllers:WaitForChild("UseController"))
	if UseController.Init then UseController:Init() end

	local InteractController = require(Controllers:WaitForChild("InteractController"))
	if InteractController.Init then InteractController:Init() end

	local CraftingController = require(Controllers:WaitForChild("CraftingController"))
	if CraftingController.Init then CraftingController:Init() end
end)

return true
