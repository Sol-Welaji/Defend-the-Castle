
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterStats = require(ReplicatedStorage.Modules.CharacterLobbyStats)

-- Dedicated RNG instance (best practice)
local RNG = Random.new()

local ROTATION_TIME = 3600

-- Rarity weights
local rarityWeights = {
	Common = 50,
	Rare = 25,
	Epic = 15,
	Legendary = 7,
	Mythic = 2.5,
	Godly = 0.5
}

-- Calculate total weight once
local totalWeight = 0
for _, weight in pairs(rarityWeights) do
	totalWeight += weight
end

-- Rolls a rarity using weighted probability
local function rollRarity()
	local roll = RNG:NextNumber(0, totalWeight)
	local cumulative = 0

	for rarity, weight in pairs(rarityWeights) do
		cumulative += weight
		if roll <= cumulative then
			return rarity
		end
	end
end

-- Picks a random character from a given rarity
local function getRandomCharacter(rarity)
	local pool = CharacterStats[rarity]
	local keys = {}

	for name in pairs(pool) do
		table.insert(keys, name)
	end

	return keys[RNG:NextInteger(1, #keys)]
end
