-- CraftingUI.lua
-- Palworld-style crafting panel (opens when near bench + press E)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local RecipeDB = require(Shared:WaitForChild("RecipeDB"))
local ItemDB = require(Shared:WaitForChild("ItemDB"))

local CraftingUI = {}

local SCREEN_NAME = "CraftingScreenGui"
local screenGui = nil
local recipeListFrame = nil
local isVisible = false
local localInventory = {} -- updated from InventoryController

local C = {
	PanelBg  = Color3.fromRGB(18, 18, 22),
	SlotBg   = Color3.fromRGB(35, 35, 42),
	Accent   = Color3.fromRGB(255, 180, 50),
	Text     = Color3.fromRGB(230, 230, 240),
	TextDim  = Color3.fromRGB(150, 150, 165),
	Green    = Color3.fromRGB(80, 200, 80),
	Red      = Color3.fromRGB(200, 80, 80),
	Border   = Color3.fromRGB(60, 60, 70),
}

local recipeCards = {} -- [recipeName] = { card = Frame, inputLabels = {}, craftBtn = TextButton }

-------------------------------------------------
-- Helpers
-------------------------------------------------

local function countItem(itemId)
	local total = 0
	for _, slot in pairs(localInventory) do
		if slot and slot.ItemId == itemId then
			total += (slot.Qty or 0)
		end
	end
	return total
end

local function getController()
	local ok, ctrl = pcall(function()
		return require(
			Players.LocalPlayer.PlayerScripts
				:WaitForChild("Code")
				:WaitForChild("Client")
				:WaitForChild("Controllers")
				:WaitForChild("CraftingController")
		)
	end)
	return ok and ctrl or nil
end

-------------------------------------------------
-- Init
-------------------------------------------------

function CraftingUI:Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local old = playerGui:FindFirstChild(SCREEN_NAME)
	if old then old:Destroy() end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = SCREEN_NAME
	screenGui.Enabled = false
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 25
	screenGui.Parent = playerGui

	-- Overlay
	local overlay = Instance.new("TextButton")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.55
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Parent = screenGui
	overlay.MouseButton1Click:Connect(function()
		CraftingUI.SetVisible(false)
	end)

	-- Panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 360, 0, 420)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = C.PanelBg
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	local ps = Instance.new("UIStroke", panel)
	ps.Color = C.Border
	ps.Thickness = 1

	-- Title
	local title = Instance.new("TextLabel")
	title.Text = "CRAFTING"
	title.Size = UDim2.new(1, -60, 0, 44)
	title.Position = UDim2.new(0, 16, 0, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = C.Accent
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	-- Close
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "✕"
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -48, 0, 8)
	closeBtn.BackgroundColor3 = C.SlotBg
	closeBtn.TextColor3 = C.TextDim
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 16
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = panel
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
	closeBtn.MouseButton1Click:Connect(function()
		CraftingUI.SetVisible(false)
	end)

	-- Recipe list (scrollable)
	recipeListFrame = Instance.new("ScrollingFrame")
	recipeListFrame.Name = "RecipeList"
	recipeListFrame.Size = UDim2.new(1, -32, 1, -60)
	recipeListFrame.Position = UDim2.new(0, 16, 0, 52)
	recipeListFrame.BackgroundTransparency = 1
	recipeListFrame.BorderSizePixel = 0
	recipeListFrame.ScrollBarThickness = 4
	recipeListFrame.ScrollBarImageColor3 = C.Accent
	recipeListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	recipeListFrame.Parent = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = recipeListFrame

	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		recipeListFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
	end)

	-- Build recipe cards
	local order = 0
	for recipeName, recipe in pairs(RecipeDB) do
		order += 1
		CraftingUI._createRecipeCard(recipeName, recipe, order)
	end
end

function CraftingUI._createRecipeCard(recipeName, recipe, layoutOrder)
	local card = Instance.new("Frame")
	card.Name = "Recipe_" .. recipeName
	card.LayoutOrder = layoutOrder
	card.Size = UDim2.new(1, 0, 0, 90)
	card.BackgroundColor3 = C.SlotBg
	card.BorderSizePixel = 0
	card.Parent = recipeListFrame
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	-- Output name
	local outName = recipe.outputs[1] and recipe.outputs[1].id or recipeName
	local titleLbl = Instance.new("TextLabel")
	titleLbl.Text = outName
	titleLbl.Size = UDim2.new(0.55, 0, 0, 24)
	titleLbl.Position = UDim2.new(0, 12, 0, 10)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3 = C.Text
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 14
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = card

	-- Input requirements
	local inputLabels = {}
	for idx, input in ipairs(recipe.inputs) do
		local lbl = Instance.new("TextLabel")
		lbl.Name = "Input_" .. idx
		lbl.Size = UDim2.new(1, -24, 0, 16)
		lbl.Position = UDim2.new(0, 12, 0, 34 + (idx - 1) * 18)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = input.id .. " x" .. input.qty
		lbl.TextColor3 = C.TextDim
		lbl.Parent = card
		inputLabels[idx] = { label = lbl, inputData = input }
	end

	-- Craft button
	local craftBtn = Instance.new("TextButton")
	craftBtn.Name = "CraftBtn"
	craftBtn.Text = "Craft"
	craftBtn.Size = UDim2.new(0, 80, 0, 30)
	craftBtn.Position = UDim2.new(1, -92, 0, 10)
	craftBtn.BackgroundColor3 = C.Accent
	craftBtn.TextColor3 = Color3.new(0, 0, 0)
	craftBtn.Font = Enum.Font.GothamBold
	craftBtn.TextSize = 13
	craftBtn.BorderSizePixel = 0
	craftBtn.Parent = card
	Instance.new("UICorner", craftBtn).CornerRadius = UDim.new(0, 6)

	craftBtn.MouseButton1Click:Connect(function()
		local ctrl = getController()
		if ctrl then
			ctrl.RequestCraft(recipeName)
		end
	end)

	recipeCards[recipeName] = {
		card = card,
		inputLabels = inputLabels,
		craftBtn = craftBtn,
	}
end

-------------------------------------------------
-- Update availability colors
-------------------------------------------------

function CraftingUI.UpdateAvailability()
	for recipeName, info in pairs(recipeCards) do
		local recipe = RecipeDB[recipeName]
		if not recipe then continue end

		local canCraft = true
		for idx, il in ipairs(info.inputLabels) do
			local input = il.inputData
			local have = countItem(input.id)
			local need = input.qty
			if have >= need then
				il.label.TextColor3 = C.Green
				il.label.Text = input.id .. " " .. have .. "/" .. need
			else
				il.label.TextColor3 = C.Red
				il.label.Text = input.id .. " " .. have .. "/" .. need
				canCraft = false
			end
		end

		info.craftBtn.BackgroundColor3 = canCraft and C.Accent or C.SlotBg
		info.craftBtn.TextColor3 = canCraft and Color3.new(0, 0, 0) or C.TextDim
	end
end

-------------------------------------------------
-- Visibility
-------------------------------------------------

function CraftingUI.SetVisible(visible)
	isVisible = visible
	if screenGui then
		screenGui.Enabled = visible
	end
	if visible then
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		CraftingUI.UpdateAvailability()
	end
end

function CraftingUI.IsVisible()
	return isVisible
end

function CraftingUI.UpdateInventory(inv)
	localInventory = inv or {}
	if isVisible then
		CraftingUI.UpdateAvailability()
	end
end

return CraftingUI
