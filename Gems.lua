local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local gemsDataStore = DataStoreService:GetDataStore("PlayerGemsData")

local STARTING_GEMS = 0

local function loadPlayerData(player)
	local success, data
	local attempts = 0

	repeat
		attempts = attempts + 1
		success, data = pcall(function()
			return gemsDataStore:GetAsync(player.UserId)
		end)

		if not success then
			warn("Failed to load data for " .. player.Name .. " (Attempt " .. attempts .. ")")
			wait(1)
		end
	until success or attempts >= 3

	return data
end

local function savePlayerData(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local gems = leaderstats:FindFirstChild("Gems")
	if not gems then return end

	local success, errorMsg
	local attempts = 0

	repeat
		attempts = attempts + 1
		success, errorMsg = pcall(function()
			gemsDataStore:SetAsync(player.UserId, gems.Value)
		end)

		if not success then
			warn("Failed to save data for " .. player.Name .. " (Attempt " .. attempts .. "): " .. errorMsg)
			wait(1)
		end
	until success or attempts >= 3

	if success then
		print("Successfully saved " .. gems.Value .. " gems for " .. player.Name)
	else
		warn("Failed to save data for " .. player.Name .. " after 3 attempts!")
	end
end

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gems = Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = STARTING_GEMS
	gems.Parent = leaderstats

	local data = loadPlayerData(player)

	if data then
		gems.Value = data
		print(player.Name .. " loaded with " .. data .. " gems")
	else
		print(player.Name .. " is new - starting with " .. STARTING_GEMS .. " gems")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
end)

game:BindToClose(function()
	print("Server shutting down - saving all player data...")

	for _, player in pairs(Players:GetPlayers()) do
		savePlayerData(player)
	end

	wait(2)
end)

print("Gems DataStore System Loaded!")