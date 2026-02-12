-- InventoryUI.lua
-- Phase 1-6 (UX Improvement)
-- Fullscreen grid UI with swap logic and premium aesthetics.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local InventoryUI = {}

-- Constants
local SCREEN_NAME = "InventoryScreenGui"
local GRID_ROWS = 5
local GRID_COLS = 6
local SLOT_SIZE = 60
local SLOT_GAP = 10

-- Styling
local COLORS = {
	OVERLAY = Color3.fromRGB(10, 10, 15),
	SLOT_BG = Color3.fromRGB(30, 30, 35),
	ACCENT = Color3.fromRGB(255, 180, 50),
	TEXT = Color3.fromRGB(255, 255, 255)
}

-- State
local elements = {} -- [index] = UI
local selectedSlot = nil -- idx
local isVisible = false
local screenGui = nil

function InventoryUI:Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local old = playerGui:FindFirstChild(SCREEN_NAME)
	if old then old:Destroy() end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = SCREEN_NAME
	screenGui.Enabled = false
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- Background Blur/Overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = COLORS.OVERLAY
	overlay.BackgroundTransparency = 0.4
	overlay.Parent = screenGui

	-- Content Container
	local container = Instance.new("Frame")
	container.Name = "Main"
	container.Size = UDim2.new(0, (SLOT_SIZE + SLOT_GAP) * GRID_COLS, 0, (SLOT_SIZE + SLOT_GAP) * GRID_ROWS)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.Parent = screenGui

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	grid.CellPadding = UDim2.new(0, SLOT_GAP, 0, SLOT_GAP)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.FillDirectionMaxCells = GRID_COLS
	grid.Parent = container

	-- Header
	local header = Instance.new("TextLabel")
	header.Text = "INVENTORY"
	header.Size = UDim2.new(1, 0, 0, 40)
	header.Position = UDim2.new(0, 0, 0, -50)
	header.BackgroundTransparency = 1
	header.TextColor3 = COLORS.TEXT
	header.Font = Enum.Font.GothamBold
	header.TextSize = 24
	header.Parent = container

	-- Slots
	for i = 1, 30 do
		local slotFrame = Instance.new("TextButton")
		slotFrame.Name = "Slot_" .. i
		slotFrame.Text = ""
		slotFrame.BackgroundColor3 = COLORS.SLOT_BG
		slotFrame.BorderSizePixel = 0
		slotFrame.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = slotFrame

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0.9
		stroke.Thickness = 1
		stroke.Parent = slotFrame

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "ItemName"
		nameLbl.Size = UDim2.new(1, -6, 1, -6)
		nameLbl.Position = UDim2.new(0.5, 0, 0.5, 0)
		nameLbl.AnchorPoint = Vector2.new(0.5, 0.5)
		nameLbl.BackgroundTransparency = 1
		nameLbl.TextColor3 = COLORS.TEXT
		nameLbl.Font = Enum.Font.GothamMedium
		nameLbl.TextSize = 10
		nameLbl.TextWrapped = true
		nameLbl.Text = ""
		nameLbl.Parent = slotFrame

		local qtyLbl = Instance.new("TextLabel")
		qtyLbl.Name = "Qty"
		qtyLbl.Size = UDim2.new(1, -4, 0, 15)
		qtyLbl.Position = UDim2.new(0, 0, 1, -15)
		qtyLbl.BackgroundTransparency = 1
		qtyLbl.TextColor3 = COLORS.TEXT
		qtyLbl.Font = Enum.Font.GothamBold
		qtyLbl.TextSize = 12
		qtyLbl.TextXAlignment = Enum.TextXAlignment.Right
		qtyLbl.Text = ""
		qtyLbl.Parent = slotFrame

		elements[i] = {
			Frame = slotFrame,
			Stroke = stroke,
			NameLbl = nameLbl,
			QtyLbl = qtyLbl
		}

		slotFrame.MouseButton1Click:Connect(function()
			InventoryUI.HandleSlotClick(i)
		end)
	end

	print("[InventoryUI] initialized")
end

function InventoryUI.SetVisible(visible)
	isVisible = visible
	screenGui.Enabled = visible
	
	if not visible then
		InventoryUI.Deselect()
	end
end

function InventoryUI.HandleSlotClick(index)
	if not selectedSlot then
		-- Select
		selectedSlot = index
		local ui = elements[index]
		TweenService:Create(ui.Stroke, TweenInfo.new(0.2), {
			Color = COLORS.ACCENT,
			Transparency = 0.2,
			Thickness = 2
		}):Play()
	else
		if selectedSlot == index then
			-- Deselect
			InventoryUI.Deselect()
		else
			-- Request Swap
			local from = selectedSlot
			local to = index
			InventoryUI.Deselect()
			
			local InventoryController = require(Players.LocalPlayer.PlayerScripts.Code.Client.Controllers.InventoryController)
			InventoryController.RequestSwap(from, to)
		end
	end
end

function InventoryUI.Deselect()
	if selectedSlot and elements[selectedSlot] then
		local ui = elements[selectedSlot]
		TweenService:Create(ui.Stroke, TweenInfo.new(0.2), {
			Color = Color3.new(1, 1, 1),
			Transparency = 0.9,
			Thickness = 1
		}):Play()
	end
	selectedSlot = nil
end

function InventoryUI.Refresh(slotsData)
	for i = 1, 30 do
		local ui = elements[i]
		local data = slotsData[i]
		if not ui then continue end
		
		if data then
			ui.NameLbl.Text = tostring(data.ItemId)
			ui.QtyLbl.Text = (data.Qty and data.Qty > 1) and tostring(data.Qty) or ""
		else
			ui.NameLbl.Text = ""
			ui.QtyLbl.Text = ""
		end
	end
end

return InventoryUI
