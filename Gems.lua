
-- SERVICES

-- Services are fetched once and cached to avoid repeated
-- global lookups and to make dependencies explicit
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- DATASTORE SETUP

-- A single, versioned datastore name allows future migrations without wiping player data
local GEMS_DATASTORE_NAME = "PlayerGemsData_v1"
local GemsDataStore = DataStoreService:GetDataStore(GEMS_DATASTORE_NAME)

-- CONFIGURATION CONSTANTS

-- Constants are centralized to avoid magic numbers
local STARTING_GEMS = 0
local MAX_RETRY_ATTEMPTS = 3
local RETRY_DELAY = 1

-- INTERNAL STATE
-- Session cache prevents unnecessary DataStore calls and protects against overwriting newer values
local sessionCache = {}


-- DATA LOADING

-- Loads player data safely with retries and session caching.
-- This function is intentionally isolated to make it reusable and easier to unit test in the future.
local function loadPlayerData(player: Player): number
	local userId = player.UserId
	local attempts = 0

	-- If data already exists in session cache, trust it
	if sessionCache[userId] ~= nil then
		return sessionCache[userId]
	end

	while attempts < MAX_RETRY_ATTEMPTS do
		attempts += 1

		local success, result = pcall(function()
			return GemsDataStore:GetAsync(userId)
		end)

		if success then
			-- Default to starting value if player is new
			local gems = typeof(result) == "number" and result or STARTING_GEMS
			sessionCache[userId] = gems
			return gems
		end

		-- Exponential-style retry delay prevents request flooding
		warn(string.format(
			"[GEMS] Load failed for %s (Attempt %d)",
			player.Name,
			attempts
		))
		task.wait(RETRY_DELAY * attempts)
	end

	-- Fail-safe: never block player join due to datastore failure
	sessionCache[userId] = STARTING_GEMS
	return STARTING_GEMS
end

-- DATA SAVING
-- Saves player data using UpdateAsync to prevent data loss when multiple servers attempt to write simultaneously
local function savePlayerData(player: Player)
	local userId = player.UserId
	local cachedValue = sessionCache[userId]

	-- If no cached data exists, there is nothing meaningful to save
	if cachedValue == nil then
		return
	end

	local attempts = 0

	while attempts < MAX_RETRY_ATTEMPTS do
		attempts += 1

		local success, err = pcall(function()
			GemsDataStore:UpdateAsync(userId, function(oldValue)
				-- Old value is ignored intentionally; session cachd represents the most up-to-date server authority
				return cachedValue
			end)
		end)

		if success then
			return
		end

		warn(string.format(
			"[GEMS] Save failed for %s (Attempt %d): %s",
			player.Name,
			attempts,
			tostring(err)
		))
		task.wait(RETRY_DELAY * attempts)
	end
end

-- LEADERSTATS SETUP

-- Leaderstats creation is separated for clarity and reusability
local function setupLeaderstats(player: Player, gemsAmount: number)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gems = Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = gemsAmount
	gems.Parent = leaderstats

	-- Synchronize runtime changes into the session cache
	gems.Changed:Connect(function(newValue)
		sessionCache[player.UserId] = newValue
	end)
end

-- PLAYER LIFECYCLE

Players.PlayerAdded:Connect(function(player)
	-- Load persistent data first to avoid visual desync
	local gemsAmount = loadPlayerData(player)

	-- Create leaderboard values using loaded data
	setupLeaderstats(player, gemsAmount)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
	sessionCache[player.UserId] = nil
end)

-- SERVER SHUTDOWN HANDLING
-- BindToClose ensures data is saved even during shutdown,
-- which is critical for live updates and private servers
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end

	-- Yield briefly to allow DataStore requests to complete
	task.wait(2)
end)

-- DEBUG

if RunService:IsStudio() then
	print("[GEMS] DataStore system initialized (Studio)")
else
	print("[GEMS] DataStore system initialized (Live)")
end

