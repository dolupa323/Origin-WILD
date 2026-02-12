-- InteractionUI.lua
-- Interaction prompts and Entity Info (HP/Level) - No crosshair

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local InteractionUI = {}

local SCREEN_NAME = "InteractionGui"
local PROMPT_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

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
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui

	-- Prompt Container (E key popup)
	local prompt = Instance.new("Frame")
	prompt.Name = "Prompt"
	prompt.Size = UDim2.new(0, 200, 0, 40)
	prompt.Position = UDim2.new(0.5, 0, 0.5, 40)
	prompt.AnchorPoint = Vector2.new(0.5, 0)
	prompt.BackgroundTransparency = 1
	prompt.Visible = false
	prompt.Parent = screenGui

	local keyFrame = Instance.new("Frame")
	keyFrame.Size = UDim2.new(0, 28, 0, 28)
	keyFrame.Position = UDim2.new(0, 0, 0.5, 0)
	keyFrame.AnchorPoint = Vector2.new(0, 0.5)
	keyFrame.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
	keyFrame.Parent = prompt
	Instance.new("UICorner", keyFrame).CornerRadius = UDim.new(0, 6)

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Text = "E"
	keyLabel.Size = UDim2.new(1, 0, 1, 0)
	keyLabel.BackgroundTransparency = 1
	keyLabel.TextColor3 = Color3.new(0, 0, 0)
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.TextSize = 15
	keyLabel.Parent = keyFrame

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "Action"
	actionLabel.Text = "Interact"
	actionLabel.Size = UDim2.new(1, -36, 1, 0)
	actionLabel.Position = UDim2.new(0, 34, 0, 0)
	actionLabel.BackgroundTransparency = 1
	actionLabel.TextColor3 = Color3.new(1, 1, 1)
	actionLabel.Font = Enum.Font.GothamMedium
	actionLabel.TextSize = 16
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.Parent = prompt

	local actionStroke = Instance.new("UIStroke")
	actionStroke.Thickness = 1.5
	actionStroke.Color = Color3.new(0, 0, 0)
	actionStroke.Transparency = 0.3
	actionStroke.Parent = actionLabel

	-- Entity Info Panel (HP bar for AI/Entities)
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
	local infoPanelStroke = Instance.new("UIStroke", infoPanel)
	infoPanelStroke.Color = Color3.fromRGB(100, 100, 110)

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
		Prompt = prompt,
		ActionLabel = actionLabel,
		InfoPanel = infoPanel,
		NameLabel = nameLabel,
		LevelLabel = levelLabel,
		HPFill = hpFill,
	}

	-- Scan loop (no crosshair, just prompt + entity info)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then return end

		local ray = camera:ScreenPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }

		local result = workspace:Raycast(ray.Origin, ray.Direction * 100, params)

		local found = nil
		if result then
			local hit = result.Instance
			local model = hit:FindFirstAncestorOfClass("Model")

			-- Entity Info (HP bar)
			if model and model:GetAttribute("Level") then
				InteractionUI._updateEntityInfo(model)
				found = model
			else
				elements.InfoPanel.Visible = false
			end

			-- Interaction Prompt (E key)
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
					local iType = interactable:GetAttribute("InteractType") or "Interact"
					local label = "Interact"
					if iType == "WorldDrop" then
						local itemId = interactable:GetAttribute("ItemId")
						label = "Pick up" .. (itemId and (" " .. itemId) or "")
					elseif iType == "CraftBench" then
						label = "Craft"
					elseif iType == "ResourceNode" then
						label = "Harvest"
					end
					InteractionUI._showPrompt(label)
				else
					InteractionUI._hidePrompt()
				end
			else
				InteractionUI._hidePrompt()
			end
		else
			elements.InfoPanel.Visible = false
			InteractionUI._hidePrompt()
		end

		currentTarget = found
	end)
end

function InteractionUI._updateEntityInfo(model)
	local hp = model:GetAttribute("HP") or 100
	local maxHp = model:GetAttribute("MaxHP") or 100
	local level = model:GetAttribute("Level") or 1

	elements.NameLabel.Text = model.Name
	elements.LevelLabel.Text = "Lv." .. level
	elements.InfoPanel.Visible = true

	local ratio = math.clamp(hp / maxHp, 0, 1)
	TweenService:Create(elements.HPFill, TweenInfo.new(0.2), {
		Size = UDim2.new(ratio, 0, 1, 0),
		BackgroundColor3 = ratio > 0.3 and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(220, 80, 80),
	}):Play()
end

function InteractionUI._showPrompt(actionText)
	elements.ActionLabel.Text = actionText
	elements.Prompt.Visible = true
end

function InteractionUI._hidePrompt()
	elements.Prompt.Visible = false
end

return InteractionUI
