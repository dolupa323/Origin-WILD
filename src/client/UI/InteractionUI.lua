-- InteractionUI.lua
-- Phase 1-6 (Palworld Mechanics)
-- Advanced crosshair, prompts, and Entity Info (HP/Level).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local InteractionUI = {}

local SCREEN_NAME = "InteractionGui"
local PROMPT_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

-- State
local currentTarget = nil
local elements = {}

function InteractionUI:Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local old = playerGui:FindFirstChild(SCREEN_NAME)
	if old then old:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = SCREEN_NAME
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10 -- Ensure it's on top
	screenGui.Parent = playerGui

	-- 1. Crosshair
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.Size = UDim2.new(0, 4, 0, 4)
	crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
	crosshair.BorderSizePixel = 0
	crosshair.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = crosshair

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.5
	stroke.Parent = crosshair

	-- 2. Prompt Container
	local prompt = Instance.new("Frame")
	prompt.Name = "Prompt"
	prompt.Size = UDim2.new(0, 200, 0, 40)
	prompt.Position = UDim2.new(0.5, 0, 0.5, 40)
	prompt.AnchorPoint = Vector2.new(0.5, 0)
	prompt.BackgroundTransparency = 1
	prompt.Visible = false
	prompt.Parent = screenGui

	local keyFrame = Instance.new("Frame")
	keyFrame.Size = UDim2.new(0, 24, 0, 24)
	keyFrame.Position = UDim2.new(0, 0, 0.5, 0)
	keyFrame.AnchorPoint = Vector2.new(0, 0.5)
	keyFrame.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
	keyFrame.Parent = prompt
	
	Instance.new("UICorner", keyFrame).CornerRadius = UDim.new(0, 4)

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Text = "E"
	keyLabel.Size = UDim2.new(1, 0, 1, 0)
	keyLabel.BackgroundTransparency = 1
	keyLabel.TextColor3 = Color3.new(0, 0, 0)
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.TextSize = 14
	keyLabel.Parent = keyFrame

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "Action"
	actionLabel.Text = "Interact"
	actionLabel.Size = UDim2.new(1, -30, 1, 0)
	actionLabel.Position = UDim2.new(0, 30, 0, 0)
	actionLabel.BackgroundTransparency = 1
	actionLabel.TextColor3 = Color3.new(1, 1, 1)
	actionLabel.Font = Enum.Font.GothamMedium
	actionLabel.TextSize = 16
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.Parent = prompt
	
	local stroke2 = Instance.new("UIStroke")
	stroke2.Thickness = 2
	stroke2.Parent = actionLabel

	-- 3. Entity Info Panel (Top Center)
	local infoPanel = Instance.new("Frame")
	infoPanel.Name = "EntityInfo"
	infoPanel.Size = UDim2.new(0, 300, 0, 60)
	infoPanel.Position = UDim2.new(0.5, 0, 0, 100)
	infoPanel.AnchorPoint = Vector2.new(0.5, 0)
	infoPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	infoPanel.BackgroundTransparency = 0.2
	infoPanel.Visible = false
	infoPanel.Parent = screenGui
	
	Instance.new("UICorner", infoPanel).CornerRadius = UDim.new(0, 8)
	Instance.new("UIStroke", infoPanel).Color = Color3.fromRGB(100, 100, 110)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -20, 0, 20)
	nameLabel.Position = UDim2.new(0, 10, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = infoPanel

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "Level"
	levelLabel.Size = UDim2.new(0, 50, 0, 20)
	levelLabel.Position = UDim2.new(1, -60, 0, 8)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.fromRGB(255, 180, 50)
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextSize = 14
	levelLabel.TextXAlignment = Enum.TextXAlignment.Right
	levelLabel.Parent = infoPanel

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HP_BG"
	hpBg.Size = UDim2.new(1, -20, 0, 8)
	hpBg.Position = UDim2.new(0, 10, 1, -18)
	hpBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	hpBg.Parent = infoPanel
	
	Instance.new("UICorner", hpBg)

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HP_Fill"
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
	hpFill.Parent = hpBg
	
	Instance.new("UICorner", hpFill)

	elements = {
		Crosshair = crosshair,
		Prompt = prompt,
		ActionLabel = actionLabel,
		InfoPanel = infoPanel,
		NameLabel = nameLabel,
		LevelLabel = levelLabel,
		HPFill = hpFill
	}

	-- Raycast loop
	print("[InteractionUI] Starting RenderStepped loop")
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then return end
		
		local ray = camera:ScreenPointToRay(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
		
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		
		local result = workspace:Raycast(ray.Origin, ray.Direction * 100, params) -- Longer range for info
		
		local found = nil
		if result then
			local hit = result.Instance
			local model = hit:FindFirstAncestorOfClass("Model")
			
			-- Check for AI Info
			if model and model:GetAttribute("Level") then
				InteractionUI.UpdateEntityInfo(model)
				found = model
			else
				elements.InfoPanel.Visible = false
			end

			-- Check for Interaction (closer range)
			if result.Distance <= 15 then
				local interactable = nil
				if CollectionService:HasTag(hit, "Interactable") then
					interactable = hit
				else
					local parent = hit.Parent
					if parent and CollectionService:HasTag(parent, "Interactable") then
						interactable = parent
					end
				end

				if interactable then
					found = interactable
					InteractionUI.ShowPrompt(found:GetAttribute("InteractType") or "Interact")
					InteractionUI.SetCrosshairState(true)
				else
					InteractionUI.HidePrompt()
					InteractionUI.SetCrosshairState(false)
				end
			else
				InteractionUI.HidePrompt()
				InteractionUI.SetCrosshairState(false)
			end
		else
			elements.InfoPanel.Visible = false
			InteractionUI.HidePrompt()
			InteractionUI.SetCrosshairState(false)
		end
		
		currentTarget = found
	end)

	print("[InteractionUI] Advanced Ready - Crosshair Created")
end

function InteractionUI.UpdateEntityInfo(model)
	local hp = model:GetAttribute("HP") or 100
	local maxHp = model:GetAttribute("MaxHP") or 100
	local level = model:GetAttribute("Level") or 1
	
	elements.NameLabel.Text = model.Name
	elements.LevelLabel.Text = "Lv." .. level
	elements.InfoPanel.Visible = true
	
	local ratio = math.clamp(hp/maxHp, 0, 1)
	TweenService:Create(elements.HPFill, TweenInfo.new(0.2), {
		Size = UDim2.new(ratio, 0, 1, 0),
		BackgroundColor3 = ratio > 0.3 and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(220, 80, 80)
	}):Play()
end

function InteractionUI.ShowPrompt(actionText)
	elements.ActionLabel.Text = actionText
	elements.Prompt.Visible = true
	elements.Prompt.Position = UDim2.new(0.5, 0, 0.5, 30)
end

function InteractionUI.HidePrompt()
	elements.Prompt.Visible = false
	elements.Prompt.Position = UDim2.new(0.5, 0, 0.5, 40)
end

function InteractionUI.SetCrosshairState(isHighlight)
	local targetSize = isHighlight and 8 or 4
	local targetColor = isHighlight and Color3.fromRGB(255, 180, 50) or Color3.new(1, 1, 1)
	
	TweenService:Create(elements.Crosshair, PROMPT_TWEEN_INFO, {
		Size = UDim2.new(0, targetSize, 0, targetSize),
		BackgroundColor3 = targetColor
	}):Play()
end

return InteractionUI
