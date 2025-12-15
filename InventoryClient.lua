-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local starterGui = game:GetService("StarterGui")

-- REMOTES
local getInventoryRemote = ReplicatedStorage.REs:WaitForChild("GetInventory")
local equipCharacterRemote = ReplicatedStorage.REs:WaitForChild("EquipCharacter")
local sellCharacterRemote = ReplicatedStorage.REs:WaitForChild("SellCharacter")
local refreshInventoryRemote = ReplicatedStorage.REs:WaitForChild("RefreshInventory")

-- GUI References
local inventoryGui = starterGui:WaitForChild("InventoryGui")
local openButton = inventoryGui:WaitForChild("OpenButton")
local mainFrame = inventoryGui:WaitForChild("MainFrame")
local closeButton = mainFrame:WaitForChild("TitleBar"):WaitForChild("CloseButton")
local countLabel = mainFrame:WaitForChild("TitleBar"):WaitForChild("CountLabel")
local scrollFrame = mainFrame:WaitForChild("CharacterScroll")
local detailsPanel = mainFrame:WaitForChild("DetailsPanel")

-- MODULES
local CharacterStats = require(ReplicatedStorage.Modules.CharacterLobbyStats)

-- VARIABLES
local currentInventory = {}
local currentEquipped = {}
local selectedCharacter = nil
local sellAllGui = nil

local rarityColors = {
	Common = Color3.fromRGB(180,180,180),
	Rare = Color3.fromRGB(100,180,255),
	Epic = Color3.fromRGB(170,80,230),
	Legendary = Color3.fromRGB(255,220,80),
	Mythic = Color3.fromRGB(255,100,180),
	Godly = Color3.fromRGB(255,80,80)
}

local rarityOrder = {"Common","Rare","Epic","Legendary","Mythic","Godly"}

-- HELPER: Get index of rarity
local function indexOf(tbl, val)
	for i,v in ipairs(tbl) do
		if v == val then return i end
	end
	return 0
end

-- SORT INVENTORY BY RARITY & NAME
local function sortInventory()
	table.sort(currentInventory, function(a,b)
		local aIndex = indexOf(rarityOrder, a.rarity)
		local bIndex = indexOf(rarityOrder, b.rarity)
		if aIndex == bIndex then
			return a.name < b.name
		end
		return aIndex < bIndex
	end)
end

-- SHOW CHARACTER DETAILS PANEL
local function showDetailsPanel(character)
	detailsPanel.Visible = true
	detailsPanel.CharacterName.Text = character.name
	detailsPanel.CharacterImage.Image = character.data.icon
	detailsPanel.RarityLabel.Text = "Rarity: "..character.rarity
	detailsPanel.RarityLabel.TextColor3 = rarityColors[character.rarity]
end

-- UPDATE INVENTORY DISPLAY
local function updateInventoryDisplay()
	-- Clear existing items
	for _, child in pairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	sortInventory()
	countLabel.Text = string.format("%d/1000", #currentInventory)

	-- Create item frames
	for i, character in ipairs(currentInventory) do
		local charFrame = Instance.new("Frame")
		charFrame.Name = "Character_"..character.id
		charFrame.Size = UDim2.new(0,90,0,110)
		charFrame.BackgroundColor3 = rarityColors[character.rarity] or Color3.fromRGB(100,100,100)
		charFrame.BorderSizePixel = 0
		charFrame.LayoutOrder = i
		charFrame.Parent = scrollFrame

		-- Round corners
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0,10)
		corner.Parent = charFrame

		-- Image
		local image = Instance.new("ImageLabel")
		image.Size = UDim2.new(0.9,0,0,65)
		image.Position = UDim2.new(0.05,0,0,5)
		image.BackgroundTransparency = 1
		image.Image = character.data.icon
		image.ScaleType = Enum.ScaleType.Fit
		image.Parent = charFrame

		-- Name label
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.9,0,0,30)
		nameLabel.Position = UDim2.new(0.05,0,0,75)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = character.name
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextSize = 12
		nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
		nameLabel.TextWrapped = true
		nameLabel.TextStrokeTransparency = 0.7
		nameLabel.Parent = charFrame

		-- Click button
		local button = Instance.new("TextButton")
		button.Name = "ClickButton"
		button.Size = UDim2.new(1,0,1,0)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.ZIndex = 2
		button.Parent = charFrame

		button.MouseButton1Click:Connect(function()
			selectedCharacter = character
			showDetailsPanel(character)
		end)
	end

	-- Update canvas size dynamically
	local cellWidth, cellHeight, paddingX, paddingY = 90,110,8,8
	local itemsPerRow = math.max(1, math.floor((scrollFrame.AbsoluteSize.X + paddingX)/(cellWidth+paddingX)))
	local numRows = math.ceil(#currentInventory/itemsPerRow)
	scrollFrame.CanvasSize = UDim2.new(0,0,0,numRows*(cellHeight+paddingY)+paddingY)
end

-- LOAD INVENTORY FROM SERVER
local function loadInventory()
	local success, inventory, equipped = pcall(function()
		return getInventoryRemote:InvokeServer()
	end)
	if success then
		currentInventory = inventory or {}
		currentEquipped = equipped or {}
		updateInventoryDisplay()
	else
		warn("Failed to load inventory: "..tostring(inventory))
	end
end

-- GUI BUTTON EVENTS
openButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = not mainFrame.Visible
	if mainFrame.Visible then loadInventory() end
end)

closeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	detailsPanel.Visible = false
end)

detailsPanel.EquipButton.MouseButton1Click:Connect(function()
	if selectedCharacter then
		equipCharacterRemote:FireServer(selectedCharacter.id)
	end
end)

detailsPanel.SellButton.MouseButton1Click:Connect(function()
	if selectedCharacter then
		sellCharacterRemote:FireServer(selectedCharacter.id)
		detailsPanel.Visible = false
		selectedCharacter = nil
		loadInventory()
	end
end)

refreshInventoryRemote.OnClientEvent:Connect(loadInventory)

print("Inventory GUI LocalScript loaded!")
