--// SERVICES
-- Services are cached once to avoid repeated global lookups
-- and to clearly document external dependencies
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--// PLAYER CONTEXT
-- PlayerGui is the correct runtime container for UI.
-- StarterGui should NEVER be used directly in LocalScripts.
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// REMOTES
-- All remotes are grouped under a single folder to keep
-- ReplicatedStorage organized and scalable
local Remotes = ReplicatedStorage:WaitForChild("REs")

local getInventoryRemote = Remotes:WaitForChild("GetInventory")
local equipCharacterRemote = Remotes:WaitForChild("EquipCharacter")
local sellCharacterRemote = Remotes:WaitForChild("SellCharacter")
local refreshInventoryRemote = Remotes:WaitForChild("RefreshInventory")

--// GUI REFERENCES
-- UI is cloned into PlayerGui at runtime, so references
-- must always be pulled from PlayerGui, not StarterGui
local inventoryGui = playerGui:WaitForChild("InventoryGui")

local openButton = inventoryGui:WaitForChild("OpenButton")
local mainFrame = inventoryGui:WaitForChild("MainFrame")

local titleBar = mainFrame:WaitForChild("TitleBar")
local closeButton = titleBar:WaitForChild("CloseButton")
local countLabel = titleBar:WaitForChild("CountLabel")

local scrollFrame = mainFrame:WaitForChild("CharacterScroll")
local detailsPanel = mainFrame:WaitForChild("DetailsPanel")

--// MODULES
-- CharacterStats contains all character metadata.
-- Keeping this in a shared module avoids hardcoding icons,
-- rarities, or names inside UI logic.
local CharacterStats = require(
	ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CharacterLobbyStats")
)

--// CLIENT STATE
-- These tables represent a client-side snapshot of
-- server-authoritative inventory data.
local currentInventory = {}
local currentEquipped = {}

-- Tracks which character is currently selected in the UI
local selectedCharacter = nil

--// RARITY CONFIGURATION
-- Visual configuration is data-driven so rarities can be
-- rebalanced without touching UI or logic code.
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

-- Precompute rarity priority ONCE.
-- This avoids repeated table scans inside sort functions,
-- which is a common performance mistake.
local rarityPriority = {}
for index, rarity in ipairs(rarityOrder) do
	rarityPriority[rarity] = index
end

--// INVENTORY SORTING
-- Inventory sorting prioritizes rarity first, then name.
-- Using a precomputed priority table ensures:
--  • O(n log n) behavior
--  • Stable and predictable ordering
--  • No redundant table traversal
local function sortInventory()
	table.sort(currentInventory, function(a, b)
		local aRank = rarityPriority[a.rarity] or math.huge
		local bRank = rarityPriority[b.rarity] or math.huge

		if aRank ~= bRank then
			return aRank < bRank
		end

		-- Secondary sort ensures consistency within same rarity
		return a.name < b.name
	end)
end

--// DETAILS PANEL
-- Isolated into its own function so animations, transitions,
-- or additional stats can be added later without touching
-- inventory rendering logic.
local function showDetailsPanel(character)
	detailsPanel.Visible = true

	detailsPanel.CharacterName.Text = character.name
	detailsPanel.CharacterImage.Image = character.data.icon

	detailsPanel.RarityLabel.Text = "Rarity: " .. character.rarity
	detailsPanel.RarityLabel.TextColor3 = rarityColors[character.rarity]
end

--// INVENTORY RENDERING
-- The UI is fully rebuilt intentionally to avoid stale state
-- and to guarantee the UI always matches server data.
local function updateInventoryDisplay()
	-- Clear previous UI elements safely
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	sortInventory()

	countLabel.Text = string.format("%d / 1000", #currentInventory)

	for index, character in ipairs(currentInventory) do
		local frame = Instance.new("Frame")
		frame.Name = "Character_" .. character.id
		frame.Size = UDim2.fromOffset(90, 110)
		frame.LayoutOrder = index
		frame.BackgroundColor3 = rarityColors[character.rarity] or Color3.fromRGB(100, 100, 100)
		frame.BorderSizePixel = 0
		frame.Parent = scrollFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = frame

		local image = Instance.new("ImageLabel")
		image.Size = UDim2.new(0.9, 0, 0, 65)
		image.Position = UDim2.fromScale(0.05, 0)
		image.BackgroundTransparency = 1
		image.Image = character.data.icon
		image.ScaleType = Enum.ScaleType.Fit
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

		-- Invisible button captures input without affecting visuals
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

	-- Responsive canvas sizing based on available width
	local itemsPerRow = math.max(1, math.floor(scrollFrame.AbsoluteSize.X / 100))
	local rows = math.ceil(#currentInventory / itemsPerRow)

	scrollFrame.CanvasSize = UDim2.fromOffset(0, rows * 120)
end

--// INVENTORY LOADING
-- Server remains authoritative. The client only renders
-- whatever the server returns.
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

--// UI INTERACTION
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

--// CHARACTER ACTIONS
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

--// SERVER-DRIVEN REFRESH
-- Allows the server to force UI refreshes when inventory
-- changes externally (gacha, admin actions, trades).
refreshInventoryRemote.OnClientEvent:Connect(loadInventory)

print(" Inventory GUI LocalScript initialized successfully")
