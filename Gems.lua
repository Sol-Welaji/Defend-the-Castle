-- SERVICES
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- DATASTORE
local gemsDataStore = DataStoreService:GetDataStore("PlayerGemsData")

-- CONSTANTS
local STARTING_GEMS = 0 
local MAX_ATTEMPTS = 3  

-- LOAD PLAYER GEMS FROM DATASTORE
local function loadPlayerData(player)
	local success, data
	local attempts = 0

	repeat
		attempts += 1
		success, data = pcall(function()
			return gemsDataStore:GetAsync(player.UserId)
		end)

		if not success then
			warn(string.format("Failed to load data for %s (Attempt %d)", player.Name, attempts))
			wait(1)
		end
	until success or attempts >= MAX_ATTEMPTS

	return data
end

-- SAVE PLAYER GEMS TO DATASTORE
local function savePlayerData(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local gems = leaderstats:FindFirstChild("Gems")
	if not gems then return end

	local success, errorMsg
	local attempts = 0

	repeat
		attempts += 1
		success, errorMsg = pcall(function()
			gemsDataStore:SetAsync(player.UserId, gems.Value)
		end)

		if not success then
			warn(string.format("Failed to save data for %s (Attempt %d): %s", player.Name, attempts, errorMsg))
			wait(1)
		end
	until success or attempts >= MAX_ATTEMPTS

	if success then
		print(string.format("Successfully saved %d gems for %s", gems.Value, player.Name))
	else
		warn(string.format("Failed to save data for %s after %d attempts!", player.Name, MAX_ATTEMPTS))
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
Players.PlayerRemoving:Connect(savePlayerData)

-- SERVER SHUTDOWN
game:BindToClose(function()
	print("Server shutting down - saving all player data...")
	for _, player in pairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
	wait(2)
end)

print("Gems DataStore System Loaded!")
