local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local inventoryDataStore = DataStoreService:GetDataStore("PlayerInventoryData")
local equippedDataStore = DataStoreService:GetDataStore("PlayerEquippedData")

local MAX_INVENTORY = 1000

local rollRemote = ReplicatedStorage:WaitForChild("GachaRollRemote")

local addToInventoryRemote = Instance.new("RemoteEvent")
addToInventoryRemote.Name = "AddToInventory"
addToInventoryRemote.Parent = ReplicatedStorage

local getInventoryRemote = Instance.new("RemoteFunction")
getInventoryRemote.Name = "GetInventory"
getInventoryRemote.Parent = ReplicatedStorage

local equipCharacterRemote = Instance.new("RemoteEvent")
equipCharacterRemote.Name = "EquipCharacter"
equipCharacterRemote.Parent = ReplicatedStorage

local sellCharacterRemote = Instance.new("RemoteEvent")
sellCharacterRemote.Name = "SellCharacter"
sellCharacterRemote.Parent = ReplicatedStorage

local sellPrices = {
	Common = 50,
	Rare = 150,
	Epic = 350,
	Legendary = 750,
	Mythic = 2000,
	Godly = 5000
}

local playerInventories = {}
local playerEquipped = {}

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

local function saveEquipped(player)
	if not playerEquipped[player.UserId] then return end

	pcall(function()
		equippedDataStore:SetAsync(player.UserId, playerEquipped[player.UserId])
	end)
end

Players.PlayerAdded:Connect(function(player)
	loadInventory(player)
	loadEquipped(player)
end)

Players.PlayerRemoving:Connect(function(player)
	saveInventory(player)
	saveEquipped(player)
	playerInventories[player.UserId] = nil
	playerEquipped[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in pairs(Players:GetPlayers()) do
		saveInventory(player)
		saveEquipped(player)
	end
	wait(2)
end)

getInventoryRemote.OnServerInvoke = function(player)
	return playerInventories[player.UserId] or {}, playerEquipped[player.UserId] or {}
end

addToInventoryRemote.OnServerEvent:Connect(function(player, characterName, rarity, characterData)
	local inventory = playerInventories[player.UserId]

	if not inventory then return end

	if #inventory >= MAX_INVENTORY then
		print(player.Name .. " inventory is full!")
		return
	end

	table.insert(inventory, {
		name = characterName,
		rarity = rarity,
		data = characterData,
		id = os.time() .. math.random(1000, 9999)
	})

	print("Added " .. characterName .. " (" .. rarity .. ") to " .. player.Name .. "'s inventory")
end)

equipCharacterRemote.OnServerEvent:Connect(function(player, characterId, slotNumber)
	local equipped = playerEquipped[player.UserId]
	if not equipped then return end

	local inventory = playerInventories[player.UserId]
	if not inventory then return end

	local character = nil
	for _, char in ipairs(inventory) do
		if char.id == characterId then
			character = char
			break
		end
	end

	if character then
		equipped[slotNumber] = character
		print(player.Name .. " equipped " .. character.name .. " to slot " .. slotNumber)
	end
end)

sellCharacterRemote.OnServerEvent:Connect(function(player, characterId)
	local inventory = playerInventories[player.UserId]
	if not inventory then return end

	for i, char in ipairs(inventory) do
		if char.id == characterId then
			local sellPrice = sellPrices[char.rarity] or 10

			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local gems = leaderstats:FindFirstChild("Gems")
				if gems then
					gems.Value = gems.Value + sellPrice
				end
			end

			table.remove(inventory, i)
			print(player.Name .. " sold " .. char.name .. " for " .. sellPrice .. " gems")
			break
		end
	end
end)

print("Inventory DataStore System loaded!")