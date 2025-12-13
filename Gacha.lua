local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CharacterStats = require(ReplicatedStorage.Modules.CharacterLobbyStats)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

local rollRemote = ReplicatedStorage.REs:WaitForChild("GachaRollRemote")
local rollRequestRemote = ReplicatedStorage.REs:WaitForChild("GachaRollRequest")
local roll10RequestRemote = ReplicatedStorage.REs:WaitForChild("GachaRoll10Request")
local addToInventoryRemote = ReplicatedStorage.REs:WaitForChild("AddToInventory")
local getStockRemote = ReplicatedStorage.REs:WaitForChild("GetGachaStock")
local stockUpdatedRemote = ReplicatedStorage.REs:WaitForChild("GachaStockUpdated")

local refreshInventoryRemote = Instance.new("RemoteEvent")
refreshInventoryRemote.Name = "RefreshInventory"
refreshInventoryRemote.Parent = ReplicatedStorage

-- Wait for the zone
local gachaZone = workspace:FindFirstChild("Zone")

-- Variables for zone GUI
local gachaGui = nil
local isInZone = false
local currentStock = {}
local rotationEndTime = 0

-- Auto-sell settings (saved per rarity)
local autoSellSettings = {
	Common = false,
	Rare = false,
	Epic = false,
	Legendary = false,
	Mythic = false,
	Godly = false
}

-- Rarity colors
local rarityColors = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(100, 180, 255),
	Epic = Color3.fromRGB(170, 80, 230),
	Legendary = Color3.fromRGB(255, 220, 80),
	Mythic = Color3.fromRGB(255, 100, 180),
	Godly = Color3.fromRGB(255, 80, 80)
}

local rarityOrder = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Godly"}

-- Function to get stock from server
local function updateStockFromServer()
	local success, stock, endTime = pcall(function()
		return getStockRemote:InvokeServer()
	end)

	if success and stock then
		currentStock = stock
		rotationEndTime = endTime
	end
end

-- Function to update timer display
local function updateTimerDisplay(timerLabel)
	local timeLeft = rotationEndTime - tick()

	if timeLeft <= 0 then
		timerLabel.Text = "?? Rotating..."
		return
	end

	local hours = math.floor(timeLeft / 3600)
	local minutes = math.floor((timeLeft % 3600) / 60)
	local seconds = math.floor(timeLeft % 60)

	timerLabel.Text = string.format("?? Rotates In: %d:%02d:%02d", hours, minutes, seconds)
end

-- Function to create the Gacha GUI
local function createGachaGui()
	if gachaGui then
		gachaGui:Destroy()
	end

	updateStockFromServer()

	gachaGui = Instance.new("ScreenGui")
	gachaGui.Name = "GachaShopGui"
	gachaGui.ResetOnSpawn = false
	gachaGui.Parent = playerGui

	-- Main Frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 550, 0, 480)
	mainFrame.Position = UDim2.new(0.5, -150, 0.5, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = gachaGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 15)
	mainCorner.Parent = mainFrame

	-- Title Bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 60)
	titleBar.BackgroundColor3 = Color3.fromRGB(40, 30, 55)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainFrame

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 15)
	titleCorner.Parent = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0.4, 0, 1, 0)
	titleLabel.Position = UDim2.new(0, 15, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "?? GACHA SHOP"
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 24
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBar

	-- Timer Label (moved more to the right)
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(0.5, 0, 0.6, 0)
	timerLabel.Position = UDim2.new(0.95, 0, 0.5, 0)
	timerLabel.AnchorPoint = Vector2.new(1, 0.5)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "?? Loading..."
	timerLabel.Font = Enum.Font.Gotham
	timerLabel.TextSize = 14
	timerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right
	timerLabel.Parent = titleBar

	-- Close Button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -50, 0.5, 0)
	closeButton.AnchorPoint = Vector2.new(0, 0.5)
	closeButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	closeButton.Text = "?"
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 20
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.BorderSizePixel = 0
	closeButton.Parent = titleBar

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		if gachaGui then
			gachaGui:Destroy()
			gachaGui = nil
		end
	end)

	-- Content Frame
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -20, 1, -80)
	contentFrame.Position = UDim2.new(0, 10, 0, 70)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = mainFrame

	-- Stock Display Frame
	local stockFrame = Instance.new("ScrollingFrame")
	stockFrame.Name = "StockFrame"
	stockFrame.Size = UDim2.new(1, 0, 0.7, 0)
	stockFrame.Position = UDim2.new(0, 0, 0, 0)
	stockFrame.BackgroundColor3 = Color3.fromRGB(35, 25, 45)
	stockFrame.BorderSizePixel = 0
	stockFrame.ScrollBarThickness = 6
	stockFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	stockFrame.Parent = contentFrame

	local stockCorner = Instance.new("UICorner")
	stockCorner.CornerRadius = UDim.new(0, 10)
	stockCorner.Parent = stockFrame

	local stockLayout = Instance.new("UIListLayout")
	stockLayout.Padding = UDim.new(0, 10)
	stockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stockLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stockLayout.Parent = stockFrame

	-- Populate stock display with actual data (ordered)
	for index, rarity in ipairs(rarityOrder) do
		local rarityFrame = Instance.new("Frame")
		rarityFrame.Name = rarity .. "Frame"
		rarityFrame.Size = UDim2.new(0.95, 0, 0, 80)
		rarityFrame.BackgroundColor3 = Color3.fromRGB(45, 35, 60)
		rarityFrame.BorderSizePixel = 0
		rarityFrame.LayoutOrder = index
		rarityFrame.Parent = stockFrame

		local rarityCorner = Instance.new("UICorner")
		rarityCorner.CornerRadius = UDim.new(0, 8)
		rarityCorner.Parent = rarityFrame

		local rarityStroke = Instance.new("UIStroke")
		rarityStroke.Color = rarityColors[rarity] or Color3.fromRGB(255, 255, 255)
		rarityStroke.Thickness = 2
		rarityStroke.Parent = rarityFrame

		-- Character Image
		local charImage = Instance.new("ImageLabel")
		charImage.Name = "CharacterImage"
		charImage.Size = UDim2.new(0, 60, 0, 60)
		charImage.Position = UDim2.new(0, 10, 0.5, 0)
		charImage.AnchorPoint = Vector2.new(0, 0.5)
		charImage.BackgroundColor3 = Color3.fromRGB(30, 25, 40)
		charImage.BorderSizePixel = 0
		charImage.ScaleType = Enum.ScaleType.Fit
		charImage.Parent = rarityFrame

		local imageCorner = Instance.new("UICorner")
		imageCorner.CornerRadius = UDim.new(0, 8)
		imageCorner.Parent = charImage

		-- Rarity Label
		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size = UDim2.new(0, 100, 0, 20)
		rarityLabel.Position = UDim2.new(0, 80, 0, 10)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Text = "? " .. rarity
		rarityLabel.Font = Enum.Font.GothamBold
		rarityLabel.TextSize = 16
		rarityLabel.TextColor3 = rarityColors[rarity] or Color3.fromRGB(255, 255, 255)
		rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
		rarityLabel.Parent = rarityFrame

		-- Character Name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "CharacterName"
		nameLabel.Size = UDim2.new(0.6, -90, 0, 25)
		nameLabel.Position = UDim2.new(0, 80, 0, 35)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = "Loading..."
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextSize = 18
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = rarityFrame

		-- Update with actual stock data
		if currentStock[rarity] then
			local characterName = currentStock[rarity]
			local characterData = CharacterStats[rarity] and CharacterStats[rarity][characterName]

			if characterData then
				nameLabel.Text = characterName
				charImage.Image = characterData.icon
			end
		end
	end

	-- Update canvas size
	stockLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		stockFrame.CanvasSize = UDim2.new(0, 0, 0, stockLayout.AbsoluteContentSize.Y + 10)
	end)
	stockFrame.CanvasSize = UDim2.new(0, 0, 0, stockLayout.AbsoluteContentSize.Y + 10)

	-- Button Frame
	local buttonFrame = Instance.new("Frame")
	buttonFrame.Name = "ButtonFrame"
	buttonFrame.Size = UDim2.new(1, 0, 0.25, 0)
	buttonFrame.Position = UDim2.new(0, 0, 0.75, 0)
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.Parent = contentFrame

	-- Roll Button
	local rollButton = Instance.new("TextButton")
	rollButton.Name = "RollButton"
	rollButton.Size = UDim2.new(0.48, 0, 0, 70)
	rollButton.Position = UDim2.new(0, 0, 0.5, -35)
	rollButton.BackgroundColor3 = Color3.fromRGB(80, 150, 255)
	rollButton.Text = "?? ROLL\n?? 100 Gems"
	rollButton.Font = Enum.Font.GothamBold
	rollButton.TextSize = 18
	rollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	rollButton.BorderSizePixel = 0
	rollButton.Parent = buttonFrame

	local rollCorner = Instance.new("UICorner")
	rollCorner.CornerRadius = UDim.new(0, 12)
	rollCorner.Parent = rollButton

	-- Roll 10 Button
	local roll10Button = Instance.new("TextButton")
	roll10Button.Name = "Roll10Button"
	roll10Button.Size = UDim2.new(0.48, 0, 0, 70)
	roll10Button.Position = UDim2.new(0.52, 0, 0.5, -35)
	roll10Button.BackgroundColor3 = Color3.fromRGB(255, 150, 80)
	roll10Button.Text = "?? ROLL 10x\n?? 1000 Gems"
	roll10Button.Font = Enum.Font.GothamBold
	roll10Button.TextSize = 18
	roll10Button.TextColor3 = Color3.fromRGB(255, 255, 255)
	roll10Button.BorderSizePixel = 0
	roll10Button.Parent = buttonFrame

	local roll10Corner = Instance.new("UICorner")
	roll10Corner.CornerRadius = UDim.new(0, 12)
	roll10Corner.Parent = roll10Button

	-- Button Connections
	rollButton.MouseButton1Click:Connect(function()
		rollRequestRemote:FireServer()
	end)

	roll10Button.MouseButton1Click:Connect(function()
		roll10RequestRemote:FireServer()
	end)

	-- ============ SETTINGS PANEL ============
	local settingsPanel = Instance.new("Frame")
	settingsPanel.Name = "SettingsPanel"
	settingsPanel.Size = UDim2.new(0, 280, 0, 550)
	settingsPanel.Position = UDim2.new(0.23, 670, 0.5, 0)
	settingsPanel.AnchorPoint = Vector2.new(0, 0.5)
	settingsPanel.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
	settingsPanel.BorderSizePixel = 0
	settingsPanel.Parent = gachaGui

	local settingsCorner = Instance.new("UICorner")
	settingsCorner.CornerRadius = UDim.new(0, 15)
	settingsCorner.Parent = settingsPanel

	-- Settings Title Bar
	local settingsTitleBar = Instance.new("Frame")
	settingsTitleBar.Name = "TitleBar"
	settingsTitleBar.Size = UDim2.new(1, 0, 0, 60)
	settingsTitleBar.BackgroundColor3 = Color3.fromRGB(40, 30, 55)
	settingsTitleBar.BorderSizePixel = 0
	settingsTitleBar.Parent = settingsPanel

	local settingsTitleCorner = Instance.new("UICorner")
	settingsTitleCorner.CornerRadius = UDim.new(0, 15)
	settingsTitleCorner.Parent = settingsTitleBar

	local settingsTitle = Instance.new("TextLabel")
	settingsTitle.Size = UDim2.new(1, -20, 1, 0)
	settingsTitle.Position = UDim2.new(0, 10, 0, 0)
	settingsTitle.BackgroundTransparency = 1
	settingsTitle.Text = "?? AUTO-SELL"
	settingsTitle.Font = Enum.Font.GothamBold
	settingsTitle.TextSize = 20
	settingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
	settingsTitle.Parent = settingsTitleBar

	-- Settings Content
	local settingsContent = Instance.new("Frame")
	settingsContent.Name = "Content"
	settingsContent.Size = UDim2.new(1, -20, 1, -80)
	settingsContent.Position = UDim2.new(0, 10, 0, 70)
	settingsContent.BackgroundTransparency = 1
	settingsContent.Parent = settingsPanel

	local settingsLayout = Instance.new("UIListLayout")
	settingsLayout.Padding = UDim.new(0, 12)
	settingsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	settingsLayout.Parent = settingsContent

	-- Create toggle switches for each rarity
	for index, rarity in ipairs(rarityOrder) do
		local toggleFrame = Instance.new("Frame")
		toggleFrame.Name = rarity .. "Toggle"
		toggleFrame.Size = UDim2.new(0.95, 0, 0, 60)
		toggleFrame.BackgroundColor3 = Color3.fromRGB(35, 25, 45)
		toggleFrame.BorderSizePixel = 0
		toggleFrame.LayoutOrder = index
		toggleFrame.Parent = settingsContent

		local toggleCorner = Instance.new("UICorner")
		toggleCorner.CornerRadius = UDim.new(0, 10)
		toggleCorner.Parent = toggleFrame

		local toggleStroke = Instance.new("UIStroke")
		toggleStroke.Color = rarityColors[rarity]
		toggleStroke.Thickness = 2
		toggleStroke.Parent = toggleFrame

		-- Rarity Label
		local toggleLabel = Instance.new("TextLabel")
		toggleLabel.Size = UDim2.new(0.6, 0, 1, 0)
		toggleLabel.Position = UDim2.new(0, 15, 0, 0)
		toggleLabel.BackgroundTransparency = 1
		toggleLabel.Text = "? " .. rarity
		toggleLabel.Font = Enum.Font.GothamBold
		toggleLabel.TextSize = 16
		toggleLabel.TextColor3 = rarityColors[rarity]
		toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
		toggleLabel.Parent = toggleFrame

		-- Toggle Button
		local toggleButton = Instance.new("TextButton")
		toggleButton.Name = "ToggleButton"
		toggleButton.Size = UDim2.new(0, 80, 0, 35)
		toggleButton.Position = UDim2.new(1, -90, 0.5, 0)
		toggleButton.AnchorPoint = Vector2.new(0, 0.5)
		toggleButton.BackgroundColor3 = Color3.fromRGB(60, 50, 70)
		toggleButton.Text = "OFF"
		toggleButton.Font = Enum.Font.GothamBold
		toggleButton.TextSize = 14
		toggleButton.TextColor3 = Color3.fromRGB(180, 180, 180)
		toggleButton.BorderSizePixel = 0
		toggleButton.Parent = toggleFrame

		local toggleButtonCorner = Instance.new("UICorner")
		toggleButtonCorner.CornerRadius = UDim.new(0, 8)
		toggleButtonCorner.Parent = toggleButton

		-- Set initial state
		if autoSellSettings[rarity] then
			toggleButton.BackgroundColor3 = rarityColors[rarity]
			toggleButton.Text = "ON"
			toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		end

		-- Toggle functionality
		toggleButton.MouseButton1Click:Connect(function()
			autoSellSettings[rarity] = not autoSellSettings[rarity]

			if autoSellSettings[rarity] then
				toggleButton.BackgroundColor3 = rarityColors[rarity]
				toggleButton.Text = "ON"
				toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				toggleButton.BackgroundColor3 = Color3.fromRGB(60, 50, 70)
				toggleButton.Text = "OFF"
				toggleButton.TextColor3 = Color3.fromRGB(180, 180, 180)
			end
		end)
	end

	-- Start timer update loop
	task.spawn(function()
		while gachaGui and gachaGui.Parent do
			updateTimerDisplay(timerLabel)
			wait(1)
		end
	end)
end

-- Function to update GUI stock display
local function updateGuiStock(stock)
	if not gachaGui then return end

	currentStock = stock

	local stockFrame = gachaGui:FindFirstChild("MainFrame")
		and gachaGui.MainFrame:FindFirstChild("ContentFrame")
		and gachaGui.MainFrame.ContentFrame:FindFirstChild("StockFrame")

	if not stockFrame then return end

	for _, rarity in ipairs(rarityOrder) do
		local rarityFrame = stockFrame:FindFirstChild(rarity .. "Frame")

		if rarityFrame and stock[rarity] then
			local characterName = stock[rarity]
			local characterData = CharacterStats[rarity] and CharacterStats[rarity][characterName]

			if characterData then
				local nameLabel = rarityFrame:FindFirstChild("CharacterName")
				local charImage = rarityFrame:FindFirstChild("CharacterImage")

				if nameLabel then
					nameLabel.Text = characterName
				end

				if charImage then
					charImage.Image = characterData.icon
				end
			end
		end
	end
end

-- Listen for stock updates from server
stockUpdatedRemote.OnClientEvent:Connect(function(stock)
	updateGuiStock(stock)
end)

-- Function to check if player is in zone
local function checkZone()
	task.wait(0.5)
	if not humanoidRootPart then return end

	local distance = (humanoidRootPart.Position - gachaZone.Position).Magnitude
	local zoneSize = gachaZone.Size.Magnitude / 2

	if distance <= zoneSize then
		if not isInZone then
			isInZone = true
			createGachaGui()
		end
	else
		if isInZone then
			isInZone = false
			if gachaGui then
				gachaGui:Destroy()
				gachaGui = nil
			end
		end
	end
end

-- Run zone check
RunService.Heartbeat:Connect(checkZone)

-- Handle character respawn
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	isInZone = false
	if gachaGui then
		gachaGui:Destroy()
		gachaGui = nil
	end
end)

-- Show reward GUI function
local function showRewardGui(rollResults)
	local rewardGui = Instance.new("ScreenGui")
	rewardGui.Name = "RewardGui"
	rewardGui.ResetOnSpawn = false
	rewardGui.Parent = playerGui

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Parent = rewardGui

	local closed = false
	local function closeGui()
		if closed then return end
		closed = true
		rewardGui:Destroy()
	end

	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closeGui()
		end
	end)

	local numRolls = #rollResults
	local columns = numRolls == 1 and 1 or 5
	local rows = math.ceil(numRolls / columns)
	local sizeX = numRolls == 1 and 200 or 100
	local sizeY = numRolls == 1 and 250 or 100

	for i, roll in ipairs(rollResults) do
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(0, 0, 0, 0)
		frame.BackgroundColor3 = Color3.fromRGB(30, 25, 40)
		frame.BorderSizePixel = 0
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Parent = overlay

		local col = (i-1) % columns
		local row = math.floor((i-1) / columns)
		frame.Position = UDim2.new(0.5, (col - (columns-1)/2) * 110, 0.5, (row - (rows-1)/2) * 110)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = frame

		local rarityColor = rarityColors[roll.rarity] or Color3.fromRGB(255, 255, 255)

		local glow = Instance.new("UIStroke")
		glow.Color = rarityColor
		glow.Thickness = 3
		glow.Parent = frame

		local image = Instance.new("ImageLabel")
		image.Size = UDim2.new(0, sizeX * 0.9, 0, sizeY * 0.6)
		image.Position = UDim2.new(0.5, 0, 0.35, 0)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.Image = roll.data.icon
		image.ScaleType = Enum.ScaleType.Fit
		image.Parent = frame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.9, 0, 0, 20)
		nameLabel.Position = UDim2.new(0.5, 0, 0, 5)
		nameLabel.AnchorPoint = Vector2.new(0.5, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = roll.name
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 14
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeTransparency = 0.5
		nameLabel.Parent = frame

		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size = UDim2.new(0.9, 0, 0, 20)
		rarityLabel.Position = UDim2.new(0.5, 0, 1, -25)
		rarityLabel.AnchorPoint = Vector2.new(0.5, 0)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Text = "? " .. roll.rarity .. " ?"
		rarityLabel.Font = Enum.Font.GothamBold
		rarityLabel.TextSize = 12
		rarityLabel.TextColor3 = rarityColor
		rarityLabel.TextStrokeTransparency = 0.5
		rarityLabel.Parent = frame

		TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, sizeX, 0, sizeY)
		}):Play()
	end

	task.spawn(function()
		wait(5)
		if rewardGui and rewardGui.Parent then
			rewardGui:Destroy()
		end
	end)
end

rollRemote.OnClientEvent:Connect(function(rollResults)
	-- Filter out auto-sold items
	for _, roll in ipairs(rollResults) do
		if not autoSellSettings[roll.rarity] then
			-- Only add to inventory if auto-sell is OFF for this rarity
			addToInventoryRemote:FireServer(roll.name, roll.rarity, roll.data)
		end
	end

	showRewardGui(rollResults)
	refreshInventoryRemote:FireServer()
end)

-- Initial stock fetch
updateStockFromServer()

print("Gacha Zone LocalScript loaded!")