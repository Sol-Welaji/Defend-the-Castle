-- SERVICES
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- DATASTORE
-- Stores the player's gem amount
local gemsDataStore = DataStoreService:GetDataStore("PlayerGemsData")

-- CONSTANTS
local STARTING_GEMS = 0 -- Gems new players start with

-- LOAD PLAYER GEMS FROM DATASTORE
local function loadPlayerData(player)
	local success, data
	local attempts = 0

	-- Try loading up to 3 times
	repeat
		attempts = attempts + 1
		success, data = pcall(function()
			return gemsDataStore:GetAsync(player.UserId)
		end)

		-- If it fails, warn and retry
		if not success then
			warn("Failed to load data for " .. player.Name .. " (Attempt " .. attempts .. ")")
			wait(1)
		end
	until success or attempts >= 3

	-- Returns nil if player is new or loading failed
	return data
end

-- SAVE PLAYER GEMS TO DATASTORE
local function savePlayerData(player)
	-- Make sure leaderstats exists
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	-- Make sure Gems value exists
	local gems = leaderstats:FindFirstChild("Gems")
	if not gems then return end

	local success, errorMsg
	local attempts = 0

	-- Try saving up to 3 times
	repeat
		attempts = attempts + 1
		success, errorMsg = pcall(function()
			gemsDataStore:SetAsync(player.UserId, gems.Value)
		end)

		-- If it fails, warn and retry
		if not success then
			warn("Failed to save data for " .. player.Name .. " (Attempt " .. attempts .. "): " .. errorMsg)
			wait(1)
		end
	until success or attempts >= 3

	-- Final result
	if success then
		print("Successfully saved " .. gems.Value .. " gems for " .. player.Name)
	else
		warn("Failed to save data for " .. player.Name .. " after 3 attempts!")
	end
end

-- PLAYER JOIN
Players.PlayerAdded:Connect(function(player)
	-- Create leaderstats folder
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- Create Gems value
	local gems = Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = STARTING_GEMS
	gems.Parent = leaderstats

	-- Load saved gem data
	local data = loadPlayerData(player)

	if data then
		gems.Value = data
		print(player.Name .. " loaded with " .. data .. " gems")
	else
		print(player.Name .. " is new - starting with " .. STARTING_GEMS .. " gems")
	end
end)

-- PLAYER LEAVE
Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
end)

-- SERVER SHUTDOWN
game:BindToClose(function()
	print("Server shutting down - saving all player data...")

	for _, player in pairs(Players:GetPlayers()) do
		savePlayerData(player)
	end

	wait(2)
end)

print("Gems DataStore System Loaded!")
