-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- PLAYER
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- REMOTES
local Remotes = ReplicatedStorage:WaitForChild("REs")
local getInventoryRemote = Remotes:WaitForChild("GetInventory")
local equipCharacterRemote = Remotes:WaitForChild("EquipCharacter")
local sellCharacterRemote = Remotes:WaitForChild("SellCharacter")
local refreshInventoryRemote = Remotes:WaitForChild("RefreshInventory")

-- GUI
local inventoryGui = playerGui:WaitForChild("InventoryGui")
local openButton = inventoryGui:WaitForChild("OpenButton")
local mainFrame = inventoryGui:WaitForChild("MainFrame")
local closeButton = mainFrame.TitleBar.CloseButton
local countLabel = mainFrame.TitleBar.CountLabel
local scrollFrame = mainFrame.CharacterScroll
local detailsPanel = mainFrame.DetailsPanel

-- MODULES
local CharacterStats = require(ReplicatedStorage.Modules.CharacterLobbyStats)

-- STATE
local currentInventory = {}
local currentEquipped = {}
local selectedCharacter = nil
local sellAllGui = nil

-- RARITY COLORS
local rarityColors = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(100, 180, 255),
	Epic = Color3.fromRGB(170, 80, 230),
	Legendary = Color3.fromRGB(255, 220, 80),
	Mythic = Color3.fromRGB(255, 100, 180),
	Godly = Color3.fromRGB(255, 80, 80)
}

-- RARITY ORDER
local rarityOrder = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Godly"}

-- PRECOMPUTED RARITY PRIORITY ( )
local rarityPriority = {}
for index, rarity in ipairs(rarityOrder) do
	rarityPriority[rarity] = index
end

-- SORT FUNCTION
local function sortInventory()
	table.sort(currentInventory, function(a, b)
		local aPriority = rarityPriority[a.rarity] or math.huge
		local bPriority = rarityPriority[b.rarity] or math.huge

		if aPriority ~= bPriority then
			return aPriority < bPriority
		end

		return a.name < b.name
	end)
end

-- DETAILS PANEL
local function showDetailsPanel(character)
	detailsPanel.Visible = true
	detailsPanel.CharacterName.Text = character.name
	detailsPanel.CharacterImage.Image = character.data.icon
	detailsPanel.RarityLabel.Text = "Rarity: " .. character.rarity
	detailsPanel.RarityLabel.TextColor3 = rarityColors[character.rarity]
end

-- INVENTORY DISPLAY
local function updateInventoryDisplay()
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	sortInventory()
	countLabel.Text = #currentInventory .. "/1000"

	for i, character in ipairs(currentInventory) do
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(0, 90, 0, 110)
		frame.LayoutOrder = i
		frame.BackgroundColor3 = rarityColors[character.rarity]
		frame.BorderSizePixel = 0
		frame.Parent = scrollFrame

		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(0.9, 0, 0, 65)
		img.Position = UDim2.new(0.05, 0, 0, 5)
		img.BackgroundTransparency = 1
		img.Image = character.data.icon
		img.Parent = frame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.9, 0, 0, 30)
		nameLabel.Position = UDim2.new(0.05, 0, 0, 75)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = character.name
		nameLabel.TextWrapped = true
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextSize = 12
		nameLabel.TextColor3 = Color3.new(1,1,1)
		nameLabel.Parent = frame

		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, 0, 1, 0)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Parent = frame

		button.MouseButton1Click:Connect(function()
			selectedCharacter = character
			showDetailsPanel(character)
		end)
	end

	-- Dynamic canvas size
	local itemsPerRow = math.max(1, math.floor(scrollFrame.AbsoluteSize.X / 100))
	local rows = math.ceil(#currentInventory / itemsPerRow)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, rows * 120)
end

-- LOAD INVENTORY
local function loadInventory()
	local success, inventory, equipped = pcall(function()
		return getInventoryRemote:InvokeServer()
	end)

	if success then
		currentInventory = inventory or {}
		currentEquipped = equipped or {}
		updateInventoryDisplay()
	else
		warn("Inventory load failed")
	end
end

-- OPEN / CLOSE
openButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = not mainFrame.Visible
	detailsPanel.Visible = false
	if mainFrame.Visible then
		loadInventory()
	end
end)

closeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	detailsPanel.Visible = false
end)

-- EQUIP
detailsPanel.EquipButton.MouseButton1Click:Connect(function()
	if selectedCharacter then
		equipCharacterRemote:FireServer(selectedCharacter.id)
	end
end)

-- SELL
detailsPanel.SellButton.MouseButton1Click:Connect(function()
	if selectedCharacter then
		sellCharacterRemote:FireServer(selectedCharacter.id)
		selectedCharacter = nil
		detailsPanel.Visible = false
		loadInventory()
	end
end)

-- REFRESH
refreshInventoryRemote.OnClientEvent:Connect(loadInventory)

print("✅ Inventory GUI loaded ( )")
