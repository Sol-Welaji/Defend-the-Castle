-- SERVICES
-- Services are cached once to reduce global lookups and clearly define script dependencies
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- PLAYER REFERENCES
-- LocalPlayer and PlayerGui are resolved once to prevent
-- repeated waits and potential race conditions
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- REMOTES
-- Remotes are grouped under a single folder to prevent namespace pollution inside ReplicatedStorage
local Remotes = ReplicatedStorage:WaitForChild("REs")

local getInventoryRemote = Remotes:WaitForChild("GetInventory")
local equipCharacterRemote = Remotes:WaitForChild("EquipCharacter")
local sellCharacterRemote = Remotes:WaitForChild("SellCharacter")
local refreshInventoryRemote = Remotes:WaitForChild("RefreshInventory")

-- GUI REFERENCES
-- GUI elements are referenced once and reused, which avoids unnecessary Instance lookups during runtime
local inventoryGui = playerGui:WaitForChild("InventoryGui")

local openButton = inventoryGui:WaitForChild("OpenButton")
local mainFrame = inventoryGui:WaitForChild("MainFrame")

local titleBar = mainFrame:WaitForChild("TitleBar")
local closeButton = titleBar:WaitForChild("CloseButton")
local countLabel = titleBar:WaitForChild("CountLabel")

local scrollFrame = mainFrame:WaitForChild("CharacterScroll")
local detailsPanel = mainFrame:WaitForChild("DetailsPanel")

-- MODULES
-- Character metadata is kept in a shared module so that the client does not hardcode stats or icons
local CharacterStats = require(
	ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CharacterLobbyStats")
)

-- CLIENT STATE
-- These tables represent the client-side snapshot of server-authoritative inventory data
local currentInventory = {}
local currentEquipped = {}

-- Tracks the currently selected character in the UI
local selectedCharacter = nil

-- RARITY VISUAL CONFIG
-- Visual styling is data-driven so rarities can be adjusted without touching UI logic
local rarityColors = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(100, 180, 255),
	Epic = Color3.fromRGB(170, 80, 230),
	Legendary = Color3.fromRGB(255, 220, 80),
	Mythic = Color3.fromRGB(255, 100, 180),
	Godly = Color3.fromRGB(255, 80, 80),
}

-- Defines display order independent of string comparison
local rarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Godly" }

-- Precompute rarity priority to avoid repeated table scans
local rarityPriority = {}
for index, rarity in ipairs(rarityOrder) do
	rarityPriority[rarity] = index
end

-- INVENTORY SORTING
-- Inventory sorting prioritizes rarity first, then name.
-- Using a precomputed priority table prevents O(n²) scans and ensures stable, predictable ordering.
local function sortInventory()
	table.sort(currentInventory, function(a, b)
		local aRank = rarityPriority[a.rarity] or math.huge
		local bRank = rarityPriority[b.rarity] or math.huge

		if aRank ~= bRank then
			return aRank < bRank
		end

		-- Secondary sort ensures consistent ordering within rarity
		return a.name < b.name
	end)
end

-- DETAILS PANEL LOGIC
-- Displays detailed information for the selected character.
-- This is isolated so future UI transitions or animations can be added without touching inventory logic.
local function showDetailsPanel(character)
	detailsPanel.Visible = true

	detailsPanel.CharacterName.Text = character.name
	detailsPanel.CharacterImage.Image = character.data.icon

	detailsPanel.RarityLabel.Text = "Rarity: " .. character.rarity
	detailsPanel.RarityLabel.TextColor3 = rarityColors[character.rarity]
end

-- INVENTORY UI RENDERING
-- Rebuilds the inventory UI from currentInventory.
-- UI is regenerated intentionally to avoid stale state and simplify synchronization with server data.
local function updateInventoryDisplay()
	-- Clear existing frames safely
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	sortInventory()

	-- Update capacity label
	countLabel.Text = string.format("%d / 1000", #currentInventory)

	for index, character in ipairs(currentInventory) do
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(90, 110)
		frame.LayoutOrder = index
		frame.BackgroundColor3 = rarityColors[character.rarity]
		frame.BorderSizePixel = 0
		frame.Parent = scrollFrame

		-- Rounded visuals without additional image assets
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = frame

		local image = Instance.new("ImageLabel")
		image.Size = UDim2.new(0.9, 0, 0, 65)
		image.Position = UDim2.fromScale(0.05, 0)
		image.BackgroundTransparency = 1
		image.Image = character.data.icon
		image.Parent = frame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.9, 0, 0, 30)
		nameLabel.Position = UDim2.fromOffset(5, 75)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextWrapped = true
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextSize = 12
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Text = character.name
		nameLabel.Parent = frame

		-- Transparent button captures input without interfering with layout or visuals
		local clickButton = Instance.new("TextButton")
		clickButton.Size = UDim2.fromScale(1, 1)
		clickButton.BackgroundTransparency = 1
		clickButton.Text = ""
		clickButton.Parent = frame

		clickButton.MouseButton1Click:Connect(function()
			selectedCharacter = character
			showDetailsPanel(character)
		end)
	end

	-- Dynamically adjust scroll height based on layout width
	local itemsPerRow = math.max(1, math.floor(scrollFrame.AbsoluteSize.X / 100))
	local rows = math.ceil(#currentInventory / itemsPerRow)

	scrollFrame.CanvasSize = UDim2.fromOffset(0, rows * 120)
end

-- INVENTORY LOADING
-- Requests inventory from the server and updates the UI.
-- Server remains authoritative; client only renders data.
local function loadInventory()
	local success, inventory, equipped = pcall(function()
		return getInventoryRemote:InvokeServer()
	end)

	if not success then
		warn("[Inventory] Failed to fetch inventory from server")
		return
	end

	currentInventory = inventory or {}
	currentEquipped = equipped or {}

	updateInventoryDisplay()
end

-- UI INTERACTION
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

-- CHARACTER ACTIONS
detailsPanel.EquipButton.MouseButton1Click:Connect(function()
	if selectedCharacter then
		equipCharacterRemote:FireServer(selectedCharacter.id)
	end
end)

detailsPanel.SellButton.MouseButton1Click:Connect(function()
	if not selectedCharacter then return end

	sellCharacterRemote:FireServer(selectedCharacter.id)

	selectedCharacter = nil
	detailsPanel.Visible = false
	loadInventory()
end)

-- SERVER SYNC
-- Allows the server to force a refresh when inventory changes due to trades, rewards, or admin actions
refreshInventoryRemote.OnClientEvent:Connect(loadInventory)

print(" Inventory GUI initialized successfully")

