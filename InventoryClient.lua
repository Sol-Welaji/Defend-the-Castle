local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

starterGui = game:GetService("StarterGui")

local getInventoryRemote = rs.REs:WaitForChild("GetInventory")
local equipCharacterRemote = rs.REs:WaitForChild("EquipCharacter")
local sellCharacterRemote = rs.REs:WaitForChild("SellCharacter")
local refreshInventoryRemote = rs.REs:WaitForChild("RefreshInventory")

local inventoryGui = starterGui:WaitForChild("InventoryGui")
local openButton = inventoryGui:WaitForChild("OpenButton")
local mainFrame = inventoryGui:WaitForChild("MainFrame")
local closeButton = mainFrame:WaitForChild("TitleBar"):WaitForChild("CloseButton")
local countLabel = mainFrame:WaitForChild("TitleBar"):WaitForChild("CountLabel")
local scrollFrame = mainFrame:WaitForChild("CharacterScroll")
local detailsPanel = mainFrame:WaitForChild("DetailsPanel")

local CharacterStats = require(rs.Modules.CharacterLobbyStats)

local currentInventory = {}
local currentEquipped = {}
local selectedCharacter = nil
local sellAllGui = nil

local rarityColors = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(100, 180, 255),
	Epic = Color3.fromRGB(170, 80, 230),
	Legendary = Color3.fromRGB(255, 220, 80),
	Mythic = Color3.fromRGB(255, 100, 180),
	Godly = Color3.fromRGB(255, 80, 80)
}

local rarityOrder = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Godly"}

local function sortInventory()
	table.sort(currentInventory, function(a, b)
		local aIndex, bIndex = 0, 0

		for i, rarity in ipairs(rarityOrder) do
			if a.rarity == rarity then aIndex = i end
			if b.rarity == rarity then bIndex = i end
		end

		if aIndex == bIndex then
			return a.name < b.name
		end

		return aIndex < bIndex
	end)
end

local function showDetailsPanel(character)
	detailsPanel.Visible = true

	detailsPanel.CharacterName.Text = character.name
	detailsPanel.CharacterImage.Image = character.data.icon
	detailsPanel.RarityLabel.Text = "Rarity: " .. character.rarity
	detailsPanel.RarityLabel.TextColor3 = rarityColors[character.rarity]
end

local function updateInventoryDisplay()
	for _, child in pairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	sortInventory()

	countLabel.Text = #currentInventory .. "/1000"

	for i, character in ipairs(currentInventory) do
		local charFrame = Instance.new("Frame")
		charFrame.Name = "Character_" .. character.id
		charFrame.Size = UDim2.new(0, 90, 0, 110)
		charFrame.BackgroundColor3 = rarityColors[character.rarity] or Color3.fromRGB(100, 100, 100)
		charFrame.BorderSizePixel = 0
		charFrame.LayoutOrder = i
		charFrame.Parent = scrollFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = charFrame

		local image = Instance.new("ImageLabel")
		image.Size = UDim2.new(0.9, 0, 0, 65)
		image.Position = UDim2.new(0.05, 0, 0, 5)
		image.BackgroundTransparency = 1
		image.Image = character.data.icon
		image.ScaleType = Enum.ScaleType.Fit
		image.Parent = charFrame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.9, 0, 0, 30)
		nameLabel.Position = UDim2.new(0.05, 0, 0, 75)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = character.name
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextSize = 12
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextWrapped = true
		nameLabel.TextStrokeTransparency = 0.7
		nameLabel.Parent = charFrame

		local button = Instance.new("TextButton")
		button.Name = "ClickButton"
		button.Size = UDim2.new(1, 0, 1, 0)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.ZIndex = 2
		button.Parent = charFrame

		button.MouseButton1Click:Connect(function()
			print("Clicked on: " .. character.name)
			selectedCharacter = character
			showDetailsPanel(character)
		end)
	end

	-- Calculate CanvasSize dynamically based on ScrollingFrame width
	local cellWidth = 90
	local cellHeight = 110
	local paddingX = 8
	local paddingY = 8
	local scrollFrameWidth = scrollFrame.AbsoluteSize.X
	local itemsPerRow = math.floor((scrollFrameWidth + paddingX) / (cellWidth + paddingX))
	itemsPerRow = math.max(itemsPerRow, 1)
	local numRows = math.ceil(#currentInventory / itemsPerRow)
	local totalHeight = numRows * (cellHeight + paddingY) + paddingY
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
	print("Inventory items: " .. #currentInventory .. ", Items per row: " .. itemsPerRow .. ", Rows: " .. numRows .. ", Canvas height: " .. totalHeight)

	-- Update sell all panel counts if it exists
	updateSellAllCounts()
end

local function updateSellAllCounts()
	if not sellAllGui or not sellAllGui.Parent then return end

	local sellAllPanel = sellAllGui:FindFirstChild("SellAllPanel")
	if not sellAllPanel then return end

	-- Count each rarity
	local rarityCounts = {}
	for _, rarity in ipairs(rarityOrder) do
		rarityCounts[rarity] = 0
	end

	for _, character in ipairs(currentInventory) do
		if rarityCounts[character.rarity] then
			rarityCounts[character.rarity] = rarityCounts[character.rarity] + 1
		end
	end

	-- Update button text
	local content = sellAllPanel:FindFirstChild("Content")
	if content then
		for _, rarity in ipairs(rarityOrder) do
			local buttonFrame = content:FindFirstChild(rarity .. "SellAll")
			if buttonFrame then
				local button = buttonFrame:FindFirstChild("SellButton")
				if button then
					button.Text = "Sell All " .. rarity .. "\n(" .. rarityCounts[rarity] .. ")"
				end
			end
		end
	end
end

local function createSellAllPanel()
	if sellAllGui then
		sellAllGui:Destroy()
	end

	-- Create a new ScreenGui for the sell all panel
	sellAllGui = Instance.new("ScreenGui")
	sellAllGui.Name = "SellAllGui"
	sellAllGui.ResetOnSpawn = false
	sellAllGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sellAllGui.Parent = playerGui

	local sellAllPanel = Instance.new("Frame")
	sellAllPanel.Name = "SellAllPanel"
	sellAllPanel.Size = UDim2.new(0, 260, 0, 0)
	-- Position calculation: Start where mainFrame ends (0.25 + 0.5 = 0.75) + small gap
	sellAllPanel.Position = UDim2.new(0.76, 0, 0.15, 0)
	sellAllPanel.AnchorPoint = Vector2.new(0, 0)
	sellAllPanel.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
	sellAllPanel.BorderSizePixel = 0
	sellAllPanel.ClipsDescendants = true
	sellAllPanel.Parent = sellAllGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 15)
	panelCorner.Parent = sellAllPanel

	-- Title Bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 50)
	titleBar.BackgroundColor3 = Color3.fromRGB(40, 30, 55)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = sellAllPanel

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 15)
	titleCorner.Parent = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 1, 0)
	titleLabel.Position = UDim2.new(0, 10, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "??? SELL ALL"
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBar

	-- Content ScrollFrame
	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -20, 1, -70)
	content.Position = UDim2.new(0, 10, 0, 60)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.Parent = sellAllPanel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	-- Create sell all buttons for each rarity
	for index, rarity in ipairs(rarityOrder) do
		local buttonFrame = Instance.new("Frame")
		buttonFrame.Name = rarity .. "SellAll"
		buttonFrame.Size = UDim2.new(0.95, 0, 0, 60)
		buttonFrame.BackgroundColor3 = Color3.fromRGB(35, 25, 45)
		buttonFrame.BorderSizePixel = 0
		buttonFrame.LayoutOrder = index
		buttonFrame.Parent = content

		local frameCorner = Instance.new("UICorner")
		frameCorner.CornerRadius = UDim.new(0, 10)
		frameCorner.Parent = buttonFrame

		local frameStroke = Instance.new("UIStroke")
		frameStroke.Color = rarityColors[rarity]
		frameStroke.Thickness = 2
		frameStroke.Parent = buttonFrame

		local sellButton = Instance.new("TextButton")
		sellButton.Name = "SellButton"
		sellButton.Size = UDim2.new(1, -10, 1, -10)
		sellButton.Position = UDim2.new(0.5, 0, 0.5, 0)
		sellButton.AnchorPoint = Vector2.new(0.5, 0.5)
		sellButton.BackgroundColor3 = rarityColors[rarity]
		sellButton.Text = "Sell All " .. rarity .. "\n(0)"
		sellButton.Font = Enum.Font.GothamBold
		sellButton.TextSize = 15
		sellButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		sellButton.BorderSizePixel = 0
		sellButton.Parent = buttonFrame

		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = sellButton

		-- Sell All functionality
		sellButton.MouseButton1Click:Connect(function()
			local itemsToSell = {}
			for _, character in ipairs(currentInventory) do
				if character.rarity == rarity then
					table.insert(itemsToSell, character.id)
				end
			end

			if #itemsToSell > 0 then
				for _, id in ipairs(itemsToSell) do
					sellCharacterRemote:FireServer(id)
				end
				print("Sold all " .. rarity .. " characters (" .. #itemsToSell .. " items)")
				task.wait(0.1)
				loadInventory()
			else
				print("No " .. rarity .. " characters to sell")
			end
		end)
	end

	-- Update canvas size
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end)
	content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)

	-- Update counts
	updateSellAllCounts()
end

local function animateSellAllPanel(show)
	if not sellAllGui then return end

	local sellAllPanel = sellAllGui:FindFirstChild("SellAllPanel")
	if not sellAllPanel then return end

	local targetHeight = show and 480 or 0

	local tween = TweenService:Create(sellAllPanel, TweenInfo.new(0.3, Enum.EasingStyle.Back, show and Enum.EasingDirection.Out or Enum.EasingDirection.In), {
		Size = UDim2.new(0, 260, 0, targetHeight)
	})

	tween:Play()
end

local function loadInventory()
	local success, inventory, equipped = pcall(function()
		return getInventoryRemote:InvokeServer()
	end)
	if success then
		currentInventory = inventory or {}
		currentEquipped = equipped or {}
		updateInventoryDisplay()
		print("Loaded inventory: " .. #currentInventory .. " characters")
	else
		warn("Failed to load inventory: " .. tostring(inventory))
	end
end

openButton.MouseButton1Click:Connect(function()
	print("Open button clicked")
	if mainFrame.Visible then
		print("Closing inventory")

		-- Animate panel closing first
		if sellAllGui then
			animateSellAllPanel(false)
			task.wait(0.3)
			sellAllGui:Destroy()
			sellAllGui = nil
		end

		mainFrame.Visible = false
		detailsPanel.Visible = false
		mainFrame.Size = UDim2.new(0.5, 0, 0.7, 0)
		mainFrame.Position = UDim2.new(0.25, 0, 0.15, 0)
		print("Inventory closed")
	else
		print("Opening inventory")
		mainFrame.Visible = true
		mainFrame.Size = UDim2.new(0.5, 0, 0.7, 0)
		mainFrame.Position = UDim2.new(0.25, 0, 0.15, 0)
		loadInventory()

		-- Create and animate sell all panel
		createSellAllPanel()
		task.wait(0.1)
		animateSellAllPanel(true)

		print("Inventory opened")
	end
end)

closeButton.MouseButton1Click:Connect(function()
	print("Close button clicked")

	-- Animate panel closing
	if sellAllGui then
		animateSellAllPanel(false)
		task.wait(0.3)
		sellAllGui:Destroy()
		sellAllGui = nil
	end

	mainFrame.Visible = false
	detailsPanel.Visible = false
	mainFrame.Size = UDim2.new(0.5, 0, 0.7, 0)
	mainFrame.Position = UDim2.new(0.25, 0, 0.15, 0)
	print("Inventory closed")
end)

detailsPanel.EquipButton.MouseButton1Click:Connect(function()
	if selectedCharacter then
		equipCharacterRemote:FireServer(selectedCharacter.id)
		print("Equip button clicked for " .. selectedCharacter.name)
	end
end)

detailsPanel.SellButton.MouseButton1Click:Connect(function()
	if selectedCharacter then
		sellCharacterRemote:FireServer(selectedCharacter.id)
		detailsPanel.Visible = false
		selectedCharacter = nil
		loadInventory()
		print("Character sold!")
	end
end)

refreshInventoryRemote.OnClientEvent:Connect(function()
	print("Refresh inventory triggered")
	loadInventory()
end)

print("Inventory GUI LocalScript loaded!")