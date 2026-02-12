-- HotbarUI.lua
-- Phase 1-4-5
-- Handles rendering the Hotbar HUD and syncing state with HotbarController

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("HotbarConfig"))
local Contracts = require(Shared:WaitForChild("Contracts"):WaitForChild("Contracts_Hotbar"))

local HotbarUI = {}

local SCREEN_GUI_NAME = "HotbarScreenGui"
local SLOT_SIZE = 50
local SLOT_GAP = 5
local POS_Y_OFFSET = -20 -- From bottom

-- State
local currentActiveSlot = Config.DEFAULT_ACTIVE
local slots = {} -- [index] = { Frame, Icon, Text, Border }

local function createSlot(parent, index)
	local frame = Instance.new("Frame")
	frame.Name = "Slot_" .. index
	frame.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	frame.BorderSizePixel = 0
	frame.Parent = parent

	-- Selection Border
	local border = Instance.new("UIStroke")
	border.Name = "SelectionBorder"
	border.Thickness = 3
	border.Color = Color3.fromRGB(255, 255, 255)
	border.Transparency = 1 -- Hidden by default
	border.Parent = frame

	-- Key Number
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "Key"
	keyLabel.Text = tostring(index)
	keyLabel.Size = UDim2.new(0, 15, 0, 15)
	keyLabel.Position = UDim2.new(0, 2, 0, 2)
	keyLabel.BackgroundTransparency = 1
	keyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	keyLabel.Font = Enum.Font.SourceSansBold
	keyLabel.TextSize = 12
	keyLabel.Parent = frame

	-- Item Icon/Text (Placeholder for now, just text)
	local itemLabel = Instance.new("TextLabel")
	itemLabel.Name = "ItemName"
	itemLabel.Text = ""
	itemLabel.Size = UDim2.new(1, -4, 1, -4)
	itemLabel.Position = UDim2.new(0, 2, 0, 2)
	itemLabel.BackgroundTransparency = 1
	itemLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	itemLabel.TextWrapped = true
	itemLabel.Font = Enum.Font.SourceSans
	itemLabel.TextSize = 10
	itemLabel.TextYAlignment = Enum.TextYAlignment.Center
	itemLabel.Parent = frame
	
	-- Qty Label
	local qtyLabel = Instance.new("TextLabel")
	qtyLabel.Name = "Qty"
	qtyLabel.Text = ""
	qtyLabel.Size = UDim2.new(0, 20, 0, 15)
	qtyLabel.Position = UDim2.new(1, -22, 1, -17)
	qtyLabel.BackgroundTransparency = 1
	qtyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	qtyLabel.Font = Enum.Font.SourceSansBold
	qtyLabel.TextSize = 12
	qtyLabel.TextXAlignment = Enum.TextXAlignment.Right
	qtyLabel.Parent = frame

	return {
		Frame = frame,
		Border = border,
		ItemLabel = itemLabel,
		QtyLabel = qtyLabel,
	}
end

local function updateUI(slotIndex, isActive, itemId, qty)
	local slot = slots[slotIndex]
	if not slot then return end

	-- Visual Update for Selection
	if isActive then
		slot.Border.Transparency = 0
		slot.Frame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		-- Simple pop animation
		-- slot.Frame:TweenSize... (UX Improvement)
	else
		slot.Border.Transparency = 1
		slot.Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	end

	-- Content Update
	if itemId then
		slot.ItemLabel.Text = tostring(itemId)
		slot.QtyLabel.Text = (qty and qty > 1) and tostring(qty) or ""
	else
		slot.ItemLabel.Text = ""
		slot.QtyLabel.Text = ""
	end
end

function HotbarUI:Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Cleanup old
	local old = playerGui:FindFirstChild(SCREEN_GUI_NAME)
	if old then old:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = SCREEN_GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundTransparency = 1
	-- Centered at bottom
	local width = (SLOT_SIZE * Config.HOTBAR_SIZE) + (SLOT_GAP * (Config.HOTBAR_SIZE - 1))
	container.Size = UDim2.new(0, width, 0, SLOT_SIZE)
	container.Position = UDim2.new(0.5, -width/2, 1, POS_Y_OFFSET - SLOT_SIZE)
	container.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.Parent = container
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, SLOT_GAP)

	-- Create SLots
	for i = 1, Config.HOTBAR_SIZE do
		slots[i] = createSlot(container, i)
	end
	
	-- Highlight default
	updateUI(currentActiveSlot, true)
	
	print("[HotbarUI] Initialized")
	
	-- Listen to updates from Controller via Net (or Controller can call UI)
	-- Controller listens to Net.Ack.
	-- *Better architecture*: Controller updates UI? Or UI listens to events?
	-- Let's have Controller call UI methods or expose state.
	-- But Controller is already written to just print.
	-- Let's update Controller to require UI and call it.
	
	return HotbarUI
end

-- Exposed API for Controller
function HotbarUI.OnSelect(slotIndex, itemId, qty)
	-- Deactivate old
	updateUI(currentActiveSlot, false, nil, nil) -- Wait, we need to know what was in old slot?
	-- Actually we don't know old slot content unless we track state.
	-- Simply update border for old.
	local oldSlot = slots[currentActiveSlot]
	if oldSlot then
		oldSlot.Border.Transparency = 1
		oldSlot.Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	end
	
	currentActiveSlot = slotIndex
	updateUI(currentActiveSlot, true, itemId, qty)
end

-- When inventory changes (e.g. qty update), we also need to update the UI.
-- Currently protocol Hotbar_Ack only returns info on Select.
-- If we use an item and qty decreases, we need an event "Inventory_Update" or similar.
-- Or Use_Ack returns new Qty.
-- For Phase 1-4-5 simplicity, Hotbar_Ack updates the *Active* slot visual.
-- We might need a full refresh later.

return HotbarUI
