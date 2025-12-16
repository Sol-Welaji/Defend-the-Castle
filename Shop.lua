
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Character metadata table.
-- This module defines which characters belong to which rarity.
local CharacterStats = require(
	ReplicatedStorage.Modules.CharacterLobbyStats
)

-- RANDOM NUMBER GENERATOR

-- Using a dedicated Random object avoids reliance on math.random(), which is global, less predictable, and harder to control or test.
-- A single RNG instance also allows deterministic behavior in the future if a seed is ever introduced.
local RNG = Random.new()

-- CONFIGURATION CONSTANTS

-- Stock rotation duration (seconds).
-- Kept here so timing logic remains centralized and
-- configurable without touching unrelated systems.
local ROTATION_TIME = 3600

-- Weighted rarity table.
-- Values do not need to sum to 100; only their ratios matter.
-- This allows designers to tweak rarity without rebalancing the enttire table.
local rarityWeights = {
	Common = 50,
	Rare = 25,
	Epic = 15,
	Legendary = 7,
	Mythic = 2.5,
	Godly = 0.5,
}

-- PRECOMPUTATION

-- Precompute total weight once at initialization.
-- This avoids recalculating the total on every roll, which improves performance when rolls occur frequently
local TOTAL_WEIGHT = 0
for _, weight in pairs(rarityWeights) do
	TOTAL_WEIGHT += weight
end

-- RARITY ROLL LOGIC

-- Rolls a rarity using weighted probability.
--
-- Algorithm:
-- 1. Generate a random number in the range [0, TOTAL_WEIGHT)
-- 2. Iterate through the rarity table, accumulating weights
-- 3. Return the first rarity whose cumulative weight
--    exceeds the roll value
--
-- This approach is deterministic, easy to audit,
-- and resistant to floating-point drift.
local function rollRarity(): string
	local roll = RNG:NextNumber(0, TOTAL_WEIGHT)
	local cumulative = 0

	for rarity, weight in pairs(rarityWeights) do
		cumulative += weight
		if roll <= cumulative then
			return rarity
		end
	end

	-- Fallback safety return.
	-- This should never be reached unless the table is misconfigured, but it prevents runtime errors.
	return "Common"
end

-- Selects a random character from a given rarity pool.
--
-- This function: Avoids relying on array-style tables, converts dictionary keys into a temporary list, uses Random:NextInteger for selection
--
-- The separation of rarity roll and character selection
-- allows easy future features such as:
-- Pity systems
--  Rarity locks
--  Event-based exclusions
local function getRandomCharacter(rarity: string): string?
	local pool = CharacterStats[rarity]
	if not pool then
		return nil
	end

	-- Build a key list to allow indexed access
	local names = {}
	for name in pairs(pool) do
		table.insert(names, name)
	end

	if #names == 0 then
		return nil
	end

	return names[RNG:NextInteger(1, #names)]
end

-- PUBLIC API

-- Returning a table instead of globals makes this moduleexplicit, testable, and easy to mock.
return {
	RotationTime = ROTATION_TIME,
	RollRarity = rollRarity,
	GetRandomCharacter = getRandomCharacter,
}

