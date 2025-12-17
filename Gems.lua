local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local GemsController = {}
GemsController.__index = GemsController

-- Configuration values are centralized to avoid magic numbers
local STORE_NAME = "PlayerGemsData"
local MAX_RETRIES = 3
local DEFAULT_GEMS = 0

-- Constructor
-- Creates a new controller instance with its own DataStore reference
function GemsController.new()
	local self = setmetatable({}, GemsController)
	self.Store = DataStoreService:GetDataStore(STORE_NAME)
	return self
end

-- Loads gem data for a player
-- Uses retry logic to handle temporary DataStore outages
function GemsController:Load(player: Player): number
	local attempts = 0
	local success, result

	repeat
		attempts += 1
		success, result = pcall(function()
			return self.Store:GetAsync(player.UserId)
		end)

		-- If the request fails, we wait briefly to avoid hammering DataStore limits
		if not success then
			task.wait(1)
		end
	until success or attempts >= MAX_RETRIES

	-- If no data exists, player is treated as new
	return result or DEFAULT_GEMS
end

-- Saves gem data for a player
-- Retry logic prevents permanent data loss on transient failures
function GemsController:Save(player: Player, amount: number)
	local attempts = 0
	local success

	repeat
		attempts += 1
		success = pcall(function()
			self.Store:SetAsync(player.UserId, amount)
		end)

		if not success then
			task.wait(1)
		end
	until success or attempts >= MAX_RETRIES
end

-- Initializes leaderstats for a joining player
-- This separates UI-facing stats from persistence logic
function GemsController:InitializePlayer(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gems = Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = self:Load(player)
	gems.Parent = leaderstats
end

-- Cleans up and saves data when player leaves
function GemsController:Cleanup(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local gems = leaderstats:FindFirstChild("Gems")
	if gems then
		self:Save(player, gems.Value)
	end
end

return GemsController

