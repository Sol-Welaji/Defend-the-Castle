-- SERVICES
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- DATASTORES
-- Stores all characters the player owns
local inventoryDataStore = DataStoreService:GetDataStore("PlayerInventoryData")

-- Stores which characters the player has equipped
local equippedDataStore = DataStoreService:GetDataStore("PlayerEquippedData")

-- CONSTANTS
local MAX_INVENTORY = 1000 -- Maximum number of characters a player can own

-- REMOTES
-- Remote used when a player rolls a character
local rollRemote = ReplicatedStorage:WaitForChild("GachaRollRemote")

-- Remote to add a character to inventory
local addToInventoryRemote = Instance.new("RemoteEvent")
addToInventoryRemote.Name = "AddToInventory"
addToInventoryRemote.Parent = ReplicatedStorage

-- Remote to request inventory + equipped data
local getInventoryRemote = Instance.new("RemoteFunction")
getInventoryRemote.Name = "GetInventory"
getInventoryRemote.Parent = ReplicatedStorage

-- Remote to equip a character
local equipCharacterRemote = Instance.new("RemoteEvent")
equipCharacterRemote.Name = "EquipCharacter"
equipCharacterRemote.Parent = ReplicatedStorage

-- Remote to sell a character
local sellCharacterRemote = Instance.new("RemoteEvent")
sellCharacterRemote.Name = "SellCharacter"
sellCharacterRemote.Parent = ReplicatedStorage

-- SELL PRICES BASED ON RARITY
local sellPrices = {
	Common = 50,
	Rare = 150,
	Epic = 350,
	Legendary = 750,
	Mythic = 2000,
	Godly = 5000
}

-- SERVER-SIDE PLAYER DATA (NOT SAVED DIRECTLY)
local playerInventories = {} -- [UserId] = inventory table
local playerEquipped = {}    -- [UserId] = equipped table

-- LOAD PLAYER INVENTORY FROM DATASTORE
local function loadInventory(player)
	local success, data = pcall(function()
		return inventoryDataStore:GetAsync(player.UserId)
	end)

	if success and data then
		playerInventories[player.UserId] = data
		print(player.Name .. " inventory loaded: " .. #data .. " characters")
	else
		playerInventories[player.UserId] = {}
		print(player.Name .. " starting with empty inventory")
	end
end

-- LOAD EQUIPPED CHARACTERS FROM DATASTORE
local function loadEquipped(player)
	local success, data = pcall(function()
		return equippedDataStore:GetAsync(player.UserId)
	end)

	if success and data then
		playerEquipped[player.UserId] = data
	else
		playerEquipped[player.UserId] = {}
	end
end

-- SAVE INVENTORY TO DATASTORE
local function saveInventory(player)
	if not playerInventories[player.UserId] then return end

	local success, err = pcall(function()
		inventoryDataStore:SetAsync(player.UserId, playerInventories[player.UserId])
	end)

	if success then
		print("Saved inventory for " .. player.Name)
	else
		warn("Failed to save inventory for " .. player.Name .. ": " .. err)
	end
end

-- SAVE EQUIPPED DATA TO DATASTORE
local function saveEquipped(player)
	if not playerEquipped[player.UserId] then return end

	pcall(function()
		equippedDataStore:SetAsync(player.UserId, playerEquipped[player.UserId])
	end)
end

-- PLAYER JOIN
Players.PlayerAdded:Connect(function(player)
	loadInventory(player)
	loadEquipped(player)
end)

-- PLAYER LEAVE
Players.PlayerRemoving:Connect(function(player)
	saveInventory(player)
	saveEquipped(player)

	-- Clear memory
	playerInventories[player.UserId] = nil
	playerEquipped[player.UserId] = nil
end)

-- SERVER SHUTDOWN SAVE
game:BindToClose(function()
	for _, player in pairs(Players:GetPlayers()) do
		saveInventory(player)
		saveEquipped(player)
	end
	wait(2)
end)

-- CLIENT REQUESTS INVENTORY DATA
getInventoryRemote.OnServerInvoke = function(player)
	return playerInventories[player.UserId] or {}, playerEquipped[player.UserId] or {}
end

-- ADD CHARACTER TO INVENTORY
addToInventoryRemote.OnServerEvent:Connect(function(player, characterName, rarity, characterData)
	local inventory = playerInventories[player.UserId]
	if not inventory then return end

	-- Check inventory limit
	if #inventory >= MAX_INVENTORY then
		print(player.Name .. " inventory is full!")
		return
	end

	-- Insert new character
	table.insert(inventory, {
		name = characterName,
		rarity = rarity,
		data = characterData,
		id = os.time() .. math.random(1000, 9999) -- Unique character ID
	})

	print("Added " .. characterName .. " (" .. rarity .. ") to " .. player.Name .. "'s inventory")
end)

-- EQUIP CHARACTER
equipCharacterRemote.OnServerEvent:Connect(function(player, characterId, slotNumber)
	local equipped = playerEquipped[player.UserId]
	if not equipped then return end

	local inventory = playerInventories[player.UserId]
	if not inventory then return end

	-- Find character in inventory
	local character = nil
	for _, char in ipairs(inventory) do
		if char.id == characterId then
			character = char
			break
		end
	end

	-- Equip character into slot
	if character then
		equipped[slotNumber] = character
		print(player.Name .. " equipped " .. character.name .. " to slot " .. slotNumber)
	end
end)

-- SELL CHARACTER
sellCharacterRemote.OnServerEvent:Connect(function(player, characterId)
	local inventory = playerInventories[player.UserId]
	if not inventory then return end

	for i, char in ipairs(inventory) do
		if char.id == characterId then
			-- Get sell value based on rarity
			local sellPrice = sellPrices[char.rarity] or 10

			-- Give gems
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local gems = leaderstats:FindFirstChild("Gems")
				if gems then
					gems.Value = gems.Value + sellPrice
				end
			end

			-- Remove character from inventory
			table.remove(inventory, i)
			print(player.Name .. " sold " .. char.name .. " for " .. sellPrice .. " gems")
			break
		end
	end
end)

print("Inventory DataStore System loaded!")
