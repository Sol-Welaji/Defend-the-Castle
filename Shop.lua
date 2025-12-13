local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterStats = require(ReplicatedStorage.Modules.CharacterLobbyStats)

local gachaPart = workspace:WaitForChild("GachaShopPart")
local surfaceGui = gachaPart:WaitForChild("GachaShopUI")
local mainFrame = surfaceGui:WaitForChild("MainFrame")
local timerLabel = mainFrame:WaitForChild("RotateTimer"):WaitForChild("TimerLabel")
local slotsContainer = mainFrame:WaitForChild("SlotsContainer")

local ROLL_COST = 100
local ROLL_10_COST = 1000
local ROTATION_TIME = 3600

local currentStock = {}
local rotationEndTime = 0

local rarityChances = {
	{rarity = "Common", chance = 50},
	{rarity = "Rare", chance = 25},
	{rarity = "Epic", chance = 15},
	{rarity = "Legendary", chance = 7},
	{rarity = "Mythic", chance = 2.5},
	{rarity = "Godly", chance = 0.5}
}

local rollRemote = Instance.new("RemoteEvent")
rollRemote.Name = "GachaRollRemote"
rollRemote.Parent = ReplicatedStorage

local rollRequestRemote = Instance.new("RemoteEvent")
rollRequestRemote.Name = "GachaRollRequest"
rollRequestRemote.Parent = ReplicatedStorage

local roll10RequestRemote = Instance.new("RemoteEvent")
roll10RequestRemote.Name = "GachaRoll10Request"
roll10RequestRemote.Parent = ReplicatedStorage

-- New remote for sending stock data to clients
local getStockRemote = Instance.new("RemoteFunction")
getStockRemote.Name = "GetGachaStock"
getStockRemote.Parent = ReplicatedStorage

local stockUpdatedRemote = Instance.new("RemoteEvent")
stockUpdatedRemote.Name = "GachaStockUpdated"
stockUpdatedRemote.Parent = ReplicatedStorage

local function getRandomCharacterFromRarity(rarity)
	local characters = CharacterStats[rarity]
	local characterList = {}

	for name, data in pairs(characters) do
		table.insert(characterList, name)
	end

	if #characterList > 0 then
		return characterList[math.random(1, #characterList)]
	end
	return nil
end

local function rollRarity()
	local roll = math.random() * 100
	local cumulative = 0

	for _, rarityData in ipairs(rarityChances) do
		cumulative = cumulative + rarityData.chance
		if roll <= cumulative then
			return rarityData.rarity
		end
	end

	return "Common"
end

local function updateStockDisplay()
	for _, rarityData in ipairs(rarityChances) do
		local rarity = rarityData.rarity
		local slot = slotsContainer:FindFirstChild(rarity .. "Slot")

		if slot and currentStock[rarity] then
			local characterName = currentStock[rarity]
			local characterData = CharacterStats[rarity][characterName]

			slot.CharacterName.Text = characterName
			slot.CharacterImage.Image = characterData.icon
		end
	end
end

local function rotateStock()
	currentStock = {}

	for _, rarityData in ipairs(rarityChances) do
		local rarity = rarityData.rarity
		local character = getRandomCharacterFromRarity(rarity)
		if character then
			currentStock[rarity] = character
		end
	end

	updateStockDisplay()
	rotationEndTime = tick() + ROTATION_TIME

	-- Notify all clients that stock has been updated
	stockUpdatedRemote:FireAllClients(currentStock)
end

local function updateTimer()
	while true do
		local timeLeft = rotationEndTime - tick()

		if timeLeft <= 0 then
			rotateStock()
			timeLeft = ROTATION_TIME
		end

		local hours = math.floor(timeLeft / 3600)
		local minutes = math.floor((timeLeft % 3600) / 60)
		local seconds = math.floor(timeLeft % 60)

		timerLabel.Text = string.format("?? Rotates In: %d:%02d:%02d", hours, minutes, seconds)
		wait(1)
	end
end

-- Function for clients to request current stock
getStockRemote.OnServerInvoke = function(player)
	return currentStock, rotationEndTime
end

rollRequestRemote.OnServerEvent:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local gems = leaderstats:FindFirstChild("Gems")
	if not gems then return end

	if gems.Value < ROLL_COST then return end

	gems.Value = gems.Value - ROLL_COST

	local rarity = rollRarity()
	local characterName = currentStock[rarity]

	if characterName then
		local characterData = CharacterStats[rarity][characterName]
		rollRemote:FireClient(player, {{name = characterName, rarity = rarity, data = characterData}})
	end
end)

roll10RequestRemote.OnServerEvent:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local gems = leaderstats:FindFirstChild("Gems")
	if not gems then return end

	if gems.Value < ROLL_10_COST then return end

	gems.Value = gems.Value - ROLL_10_COST

	local results = {}
	for i = 1, 10 do
		local rarity = rollRarity()
		local characterName = currentStock[rarity]

		if characterName then
			local characterData = CharacterStats[rarity][characterName]
			table.insert(results, {name = characterName, rarity = rarity, data = characterData})
		end
	end

	if #results > 0 then
		rollRemote:FireClient(player, results)
	end
end)

rotateStock()
task.spawn(updateTimer)

print("Gacha Server loaded!")