-- HotbarUI.lua
-- Phase 1-6 (UX Refinement)
-- Premium modern UI with animations and glassmorphism.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("HotbarConfig"))

local HotbarUI = {}

-- Constants
local SCREEN_GUI_NAME = "HotbarScreenGui"
local SLOT_SIZE = 55
local ACTIVE_SIZE = 65
local SLOT_GAP = 8
local POS_Y_OFFSET = -30

-- Styling
local COLORS = {
	BG = Color3.fromRGB(20, 20, 25),
	SLOT_BG = Color3.fromRGB(30, 30, 35),
	ACCENT = Color3.fromRGB(255, 180, 50),
	TEXT = Color3.fromRGB(255, 255, 255),
	KEY = Color3.fromRGB(150, 150, 160)
}

-- State
local slots = {} -- [index] = UI Elements
local activeSlot = Config.DEFAULT_ACTIVE

-- UI Helper: Create Rounded Frame
local function createRoundedFrame(name, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = COLORS.SLOT_BG
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.9
	stroke.Thickness = 1
	stroke.Parent = frame

	return frame, stroke
end

local function animateSlot(index, isActive)
	local slot = slots[index]
	if not slot then return end

	local targetSize = isActive and ACTIVE_SIZE or SLOT_SIZE
	local targetColor = isActive and COLORS.BG or COLORS.SLOT_BG
	local strokeTransparency = isActive and 0.4 or 0.9
	local strokeColor = isActive and COLORS.ACCENT or Color3.new(1, 1, 1)

	TweenService:Create(slot.Frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, targetSize, 0, targetSize),
		BackgroundColor3 = targetColor
	}):Play()

	TweenService:Create(slot.Stroke, TweenInfo.new(0.3), {
		Transparency = strokeTransparency,
		Color = strokeColor,
		Thickness = isActive and 2 or 1
	}):Play()
end

function HotbarUI:Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local old = playerGui:FindFirstChild(SCREEN_GUI_NAME)
	if old then old:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = SCREEN_GUI_NAME
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundTransparency = 1
	container.Position = UDim2.new(0.5, 0, 1, POS_Y_OFFSET)
	container.AnchorPoint = Vector2.new(0.5, 1)
	
	local width = (SLOT_SIZE * Config.HOTBAR_SIZE) + (SLOT_GAP * (Config.HOTBAR_SIZE - 1)) + 20
	container.Size = UDim2.new(0, width, 0, ACTIVE_SIZE + 10)
	container.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, SLOT_GAP)
	layout.Parent = container

	for i = 1, Config.HOTBAR_SIZE do
		local frame, stroke = createRoundedFrame("Slot_" .. i, container)
		frame.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
		
		-- Key Label
		local key = Instance.new("TextLabel")
		key.Text = tostring(i)
		key.Size = UDim2.new(1, 0, 0, 15)
		key.Position = UDim2.new(0, 0, 0, 4)
		key.BackgroundTransparency = 1
		key.TextColor3 = COLORS.KEY
		key.Font = Enum.Font.GothamBold
		key.TextSize = 10
		key.Parent = frame

		-- Item Image (Placeholder)
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(0.7, 0, 0.7, 0)
		icon.Position = UDim2.new(0.5, 0, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.ImageTransparency = 1
		icon.Parent = frame

		-- Item Name (Fallback)
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "ItemName"
		nameLbl.Size = UDim2.new(1, -4, 1, -4)
		nameLbl.Position = UDim2.new(0.5, 0, 0.5, 0)
		nameLbl.AnchorPoint = Vector2.new(0.5, 0.5)
		nameLbl.BackgroundTransparency = 1
		nameLbl.TextColor3 = COLORS.TEXT
		nameLbl.Font = Enum.Font.GothamMedium
		nameLbl.TextSize = 10
		nameLbl.TextWrapped = true
		nameLbl.Text = ""
		nameLbl.Parent = frame

		-- Quantity
		local qty = Instance.new("TextLabel")
		qty.Name = "Qty"
		qty.Size = UDim2.new(0, 20, 0, 15)
		qty.Position = UDim2.new(1, -4, 1, -4)
		qty.AnchorPoint = Vector2.new(1, 1)
		qty.BackgroundTransparency = 1
		qty.TextColor3 = COLORS.TEXT
		qty.Font = Enum.Font.GothamBold
		qty.TextSize = 12
		qty.TextXAlignment = Enum.TextXAlignment.Right
		qty.Text = ""
		qty.Parent = frame

		slots[i] = {
			Frame = frame,
			Stroke = stroke,
			NameLbl = nameLbl,
			Icon = icon,
			QtyLbl = qty
		}
	end

	animateSlot(activeSlot, true)
	print("[HotbarUI] Ready")
	return HotbarUI
end

function HotbarUI.OnSelect(slotIndex, itemId, qty)
	if slots[activeSlot] then
		animateSlot(activeSlot, false)
	end

	activeSlot = slotIndex

	if slots[activeSlot] then
		animateSlot(activeSlot, true)
		
		-- Update content
		local slot = slots[activeSlot]
		if itemId then
			slot.NameLbl.Text = tostring(itemId)
			slot.QtyLbl.Text = (qty and qty > 1) and tostring(qty) or ""
			
			-- Pop animation for content
			slot.NameLbl.Size = UDim2.new(0, 0, 0, 0)
			TweenService:Create(slot.NameLbl, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
				Size = UDim2.new(1, -4, 1, -4)
			}):Play()
		else
			slot.NameLbl.Text = ""
			slot.QtyLbl.Text = ""
		end
	end
end

-- Full Refresh (e.g. for inventory updates)
function HotbarUI.Refresh(inventoryData)
	for i, slotData in pairs(inventoryData) do
		local ui = slots[i]
		if ui then
			ui.NameLbl.Text = slotData.ItemId or ""
			ui.QtyLbl.Text = (slotData.Quantity and slotData.Quantity > 1) and tostring(slotData.Quantity) or ""
		end
	end
end

return HotbarUI
