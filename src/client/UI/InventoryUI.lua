-- InventoryUI.lua
-- Palworld-style inventory with drag-and-drop, world drop, stack merge

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Code"):WaitForChild("Shared")
local ItemDB = require(Shared:WaitForChild("ItemDB"))

local InventoryUI = {}

-- Layout
local SCREEN_NAME = "InventoryScreenGui"
local GRID_COLS = 6
local GRID_ROWS = 5
local TOTAL_SLOTS = 30
local SLOT_SIZE = 64
local SLOT_GAP = 4
local PANEL_PAD = 16

-- Palworld Dark Theme
local C = {
	PanelBg    = Color3.fromRGB(18, 18, 22),
	SlotBg     = Color3.fromRGB(35, 35, 42),
	SlotHover  = Color3.fromRGB(50, 50, 60),
	SlotEmpty  = Color3.fromRGB(28, 28, 34),
	Accent     = Color3.fromRGB(255, 180, 50),
	AccentDim  = Color3.fromRGB(180, 130, 40),
	Text       = Color3.fromRGB(230, 230, 240),
	TextDim    = Color3.fromRGB(150, 150, 165),
	QtyText    = Color3.fromRGB(255, 255, 255),
	Danger     = Color3.fromRGB(220, 60, 60),
	Border     = Color3.fromRGB(60, 60, 70),
}

-- State
local screenGui = nil
local panelFrame = nil
local gridFrame = nil
local elements = {}         -- [i] = { Frame, Stroke, NameLbl, QtyLbl }
local inventoryData = {}    -- current server data
local isVisible = false

-- Drag State
local isDragging = false
local dragFromSlot = nil
local ghostFrame = nil

-------------------------------------------------
-- Helpers
-------------------------------------------------

local function isInBounds(obj, x, y)
	local p = obj.AbsolutePosition
	local s = obj.AbsoluteSize
	return x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y
end

local function getSlotAt(x, y)
	for i, el in pairs(elements) do
		if isInBounds(el.Frame, x, y) then
			return i
		end
	end
	return nil
end

local function resetAllBorders()
	for _, el in pairs(elements) do
		el.Stroke.Color = C.Border
		el.Stroke.Transparency = 0.7
		el.Stroke.Thickness = 1
	end
end

local function getController()
	local ok, ctrl = pcall(function()
		return require(
			Players.LocalPlayer.PlayerScripts
				:WaitForChild("Code")
				:WaitForChild("Client")
				:WaitForChild("Controllers")
				:WaitForChild("InventoryController")
		)
	end)
	return ok and ctrl or nil
end

-------------------------------------------------
-- Init
-------------------------------------------------

function InventoryUI:Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local old = playerGui:FindFirstChild(SCREEN_NAME)
	if old then old:Destroy() end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = SCREEN_NAME
	screenGui.Enabled = false
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 20
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Overlay (click to close)
	local overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.55
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Parent = screenGui
	overlay.MouseButton1Click:Connect(function()
		InventoryUI.SetVisible(false)
	end)

	-- Main Panel
	local gridW = (SLOT_SIZE * GRID_COLS) + (SLOT_GAP * (GRID_COLS - 1))
	local gridH = (SLOT_SIZE * GRID_ROWS) + (SLOT_GAP * (GRID_ROWS - 1))
	local panelW = gridW + (PANEL_PAD * 2)
	local panelH = gridH + (PANEL_PAD * 2) + 56 -- header + padding

	panelFrame = Instance.new("Frame")
	panelFrame.Name = "Panel"
	panelFrame.Size = UDim2.new(0, panelW, 0, panelH)
	panelFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	panelFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	panelFrame.BackgroundColor3 = C.PanelBg
	panelFrame.BackgroundTransparency = 0.05
	panelFrame.BorderSizePixel = 0
	panelFrame.Parent = screenGui
	Instance.new("UICorner", panelFrame).CornerRadius = UDim.new(0, 12)
	local ps = Instance.new("UIStroke", panelFrame)
	ps.Color = C.Border
	ps.Thickness = 1
	ps.Transparency = 0.3

	-- Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundTransparency = 1
	header.Parent = panelFrame

	local title = Instance.new("TextLabel")
	title.Text = "INVENTORY"
	title.Size = UDim2.new(1, -60, 1, 0)
	title.Position = UDim2.new(0, PANEL_PAD, 0, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = C.Accent
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "✕"
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -PANEL_PAD - 32, 0, 8)
	closeBtn.BackgroundColor3 = C.Danger
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = header
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
	closeBtn.MouseButton1Click:Connect(function()
		InventoryUI.SetVisible(false)
	end)

	-- Subtitle hint
	local hint = Instance.new("TextLabel")
	hint.Text = "Drag items to rearrange • Drop outside to discard"
	hint.Size = UDim2.new(1, -(PANEL_PAD * 2), 0, 16)
	hint.Position = UDim2.new(0, PANEL_PAD, 0, 36)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = C.TextDim
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 10
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = panelFrame

	-- Grid
	gridFrame = Instance.new("Frame")
	gridFrame.Name = "Grid"
	gridFrame.Size = UDim2.new(0, gridW, 0, gridH)
	gridFrame.Position = UDim2.new(0, PANEL_PAD, 0, 56)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = panelFrame

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	grid.CellPadding = UDim2.new(0, SLOT_GAP, 0, SLOT_GAP)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.FillDirectionMaxCells = GRID_COLS
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridFrame

	-- Create Slots
	for i = 1, TOTAL_SLOTS do
		local slot = Instance.new("TextButton")
		slot.Name = "Slot_" .. i
		slot.LayoutOrder = i
		slot.Text = ""
		slot.AutoButtonColor = false
		slot.BackgroundColor3 = C.SlotEmpty
		slot.BorderSizePixel = 0
		slot.Parent = gridFrame
		Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 8)

		local stroke = Instance.new("UIStroke", slot)
		stroke.Color = C.Border
		stroke.Transparency = 0.7
		stroke.Thickness = 1

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "ItemName"
		nameLbl.Size = UDim2.new(1, -8, 0.55, 0)
		nameLbl.Position = UDim2.new(0, 4, 0, 4)
		nameLbl.BackgroundTransparency = 1
		nameLbl.TextColor3 = C.Text
		nameLbl.Font = Enum.Font.GothamMedium
		nameLbl.TextSize = 11
		nameLbl.TextWrapped = true
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextYAlignment = Enum.TextYAlignment.Top
		nameLbl.Text = ""
		nameLbl.Parent = slot

		local qtyLbl = Instance.new("TextLabel")
		qtyLbl.Name = "Qty"
		qtyLbl.Size = UDim2.new(0, 30, 0, 16)
		qtyLbl.Position = UDim2.new(1, -4, 1, -4)
		qtyLbl.AnchorPoint = Vector2.new(1, 1)
		qtyLbl.BackgroundTransparency = 1
		qtyLbl.TextColor3 = C.QtyText
		qtyLbl.Font = Enum.Font.GothamBold
		qtyLbl.TextSize = 12
		qtyLbl.TextXAlignment = Enum.TextXAlignment.Right
		qtyLbl.Text = ""
		qtyLbl.Parent = slot

		elements[i] = {
			Frame = slot,
			Stroke = stroke,
			NameLbl = nameLbl,
			QtyLbl = qtyLbl,
		}

		-- Drag start
		slot.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local data = inventoryData[i]
				if data then
					InventoryUI._startDrag(i, data)
				end
			end
		end)

		-- Hover
		slot.MouseEnter:Connect(function()
			if not isDragging then
				TweenService:Create(slot, TweenInfo.new(0.12), {
					BackgroundColor3 = C.SlotHover,
				}):Play()
			end
		end)
		slot.MouseLeave:Connect(function()
			if not isDragging then
				local data = inventoryData[i]
				TweenService:Create(slot, TweenInfo.new(0.12), {
					BackgroundColor3 = data and C.SlotBg or C.SlotEmpty,
				}):Play()
			end
		end)
	end

	-- Mouse move while dragging
	UserInputService.InputChanged:Connect(function(input)
		if isDragging and ghostFrame and input.UserInputType == Enum.UserInputType.MouseMovement then
			local mx, my = input.Position.X, input.Position.Y
			ghostFrame.Position = UDim2.new(0, mx - SLOT_SIZE / 2, 0, my - SLOT_SIZE / 2)

			-- Highlight target slot
			local target = getSlotAt(mx, my)
			for idx, el in pairs(elements) do
				if idx == target then
					el.Stroke.Color = C.Accent
					el.Stroke.Transparency = 0
					el.Stroke.Thickness = 2
				elseif idx == dragFromSlot then
					el.Stroke.Color = C.AccentDim
					el.Stroke.Transparency = 0.3
					el.Stroke.Thickness = 2
				else
					el.Stroke.Color = C.Border
					el.Stroke.Transparency = 0.7
					el.Stroke.Thickness = 1
				end
			end
		end
	end)

	-- Mouse up → end drag
	UserInputService.InputEnded:Connect(function(input)
		if isDragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
			InventoryUI._endDrag(input.Position)
		end
	end)
end

-------------------------------------------------
-- Drag & Drop
-------------------------------------------------

function InventoryUI._startDrag(slotIndex, data)
	isDragging = true
	dragFromSlot = slotIndex

	-- Create ghost frame
	ghostFrame = Instance.new("Frame")
	ghostFrame.Name = "DragGhost"
	ghostFrame.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	ghostFrame.BackgroundColor3 = C.SlotBg
	ghostFrame.BackgroundTransparency = 0.2
	ghostFrame.BorderSizePixel = 0
	ghostFrame.ZIndex = 100
	ghostFrame.Parent = screenGui
	Instance.new("UICorner", ghostFrame).CornerRadius = UDim.new(0, 8)
	local gs = Instance.new("UIStroke", ghostFrame)
	gs.Color = C.Accent
	gs.Thickness = 2

	local gn = Instance.new("TextLabel")
	gn.Size = UDim2.new(1, -8, 0.55, 0)
	gn.Position = UDim2.new(0, 4, 0, 4)
	gn.BackgroundTransparency = 1
	gn.TextColor3 = C.Text
	gn.Font = Enum.Font.GothamMedium
	gn.TextSize = 11
	gn.TextWrapped = true
	gn.TextXAlignment = Enum.TextXAlignment.Left
	gn.TextYAlignment = Enum.TextYAlignment.Top
	gn.Text = data.ItemId or ""
	gn.ZIndex = 101
	gn.Parent = ghostFrame

	local gq = Instance.new("TextLabel")
	gq.Size = UDim2.new(0, 30, 0, 16)
	gq.Position = UDim2.new(1, -4, 1, -4)
	gq.AnchorPoint = Vector2.new(1, 1)
	gq.BackgroundTransparency = 1
	gq.TextColor3 = C.QtyText
	gq.Font = Enum.Font.GothamBold
	gq.TextSize = 12
	gq.TextXAlignment = Enum.TextXAlignment.Right
	gq.Text = (data.Qty and data.Qty > 1) and tostring(data.Qty) or ""
	gq.ZIndex = 101
	gq.Parent = ghostFrame

	-- Dim origin slot
	local orig = elements[slotIndex]
	if orig then
		orig.NameLbl.TextTransparency = 0.6
		orig.QtyLbl.TextTransparency = 0.6
		orig.Frame.BackgroundTransparency = 0.4
	end

	-- Initial ghost position
	local m = UserInputService:GetMouseLocation()
	ghostFrame.Position = UDim2.new(0, m.X - SLOT_SIZE / 2, 0, m.Y - SLOT_SIZE / 2)
end

function InventoryUI._endDrag(mousePos)
	if not isDragging or not dragFromSlot then return end

	local fromSlot = dragFromSlot
	local mx, my = mousePos.X, mousePos.Y
	local targetSlot = getSlotAt(mx, my)

	-- 보정: 정확히 슬롯 위가 아니더라도 그리드 내부라면 가장 가까운 슬롯 찾기
	if not targetSlot and gridFrame and isInBounds(gridFrame, mx, my) then
		local closest = nil
		local minDst = math.huge
		for i, el in pairs(elements) do
			local f = el.Frame
			local center = f.AbsolutePosition + (f.AbsoluteSize / 2)
			local dst = (Vector2.new(mx, my) - center).Magnitude
			if dst < (SLOT_SIZE * 0.8) and dst < minDst then
				closest = i
				minDst = dst
			end
		end
		targetSlot = closest
	end

	-- Cleanup ghost
	if ghostFrame then
		ghostFrame:Destroy()
		ghostFrame = nil
	end

	-- Restore origin slot appearance
	local orig = elements[fromSlot]
	if orig then
		orig.NameLbl.TextTransparency = 0
		orig.QtyLbl.TextTransparency = 0
		orig.Frame.BackgroundTransparency = 0
	end
	resetAllBorders()

	isDragging = false
	dragFromSlot = nil

	local ctrl = getController()
	if not ctrl then return end

	if targetSlot and targetSlot ~= fromSlot then
		-- Swap / Merge
		ctrl.RequestSwap(fromSlot, targetSlot)
	elseif not targetSlot then
		-- Check if outside panel → world drop
		if panelFrame and not isInBounds(panelFrame, mx, my) then
			ctrl.RequestDrop(fromSlot)
		end
	end
end

-------------------------------------------------
-- Visibility
-------------------------------------------------

function InventoryUI.SetVisible(visible)
	isVisible = visible
	if screenGui then
		screenGui.Enabled = visible
	end
	if visible then
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	else
		UserInputService.MouseIconEnabled = true
		-- Cancel any active drag
		if isDragging then
			if ghostFrame then ghostFrame:Destroy() ghostFrame = nil end
			if dragFromSlot and elements[dragFromSlot] then
				elements[dragFromSlot].NameLbl.TextTransparency = 0
				elements[dragFromSlot].QtyLbl.TextTransparency = 0
				elements[dragFromSlot].Frame.BackgroundTransparency = 0
			end
			resetAllBorders()
			isDragging = false
			dragFromSlot = nil
		end
	end
end

function InventoryUI.IsVisible()
	return isVisible
end

-------------------------------------------------
-- Refresh (called when inventory data changes)
-------------------------------------------------

function InventoryUI.Refresh(slotsData)
	inventoryData = slotsData or {}
	for i = 1, TOTAL_SLOTS do
		local el = elements[i]
		if not el then continue end
		local data = slotsData[i]
		if data then
			el.NameLbl.Text = tostring(data.ItemId or "")
			el.QtyLbl.Text = (data.Qty and data.Qty > 1) and tostring(data.Qty) or ""
			el.Frame.BackgroundColor3 = C.SlotBg
		else
			el.NameLbl.Text = ""
			el.QtyLbl.Text = ""
			el.Frame.BackgroundColor3 = C.SlotEmpty
		end
	end
end

return InventoryUI
