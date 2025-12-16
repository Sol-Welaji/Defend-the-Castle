
-- TeleportService handles all cross-place and private server teleports
local TeleportService = game:GetService("TeleportService")

-- Players service is required for player events
local Players = game:GetService("Players")

-- Destination place ID
-- Kept as a constant so it is easy to change or reuse
local DESTINATION_PLACE_ID = 93465852001946

-- Teleport data sent to the destination server
-- This allows the receiving place to configure gameplay
-- (difficulty, gamemode, matchmaking rules, etc.)
local TELEPORT_DATA = {
	mode = "Easy",
}

-- Handles teleporting a single player into a reserved server
local function teleportPlayer(player: Player)
	-- TeleportOptions allows us to configure how the teleport behaves
	local teleportOptions = Instance.new("TeleportOptions")

	-- Ensures all players are placed into a brand-new private server rather than an existing public instance
	teleportOptions.ShouldReserveServer = true

	-- Attach structured data to the teleport
	-- This data can be read on the destination server via Player:GetJoinData().TeleportData
	teleportOptions:SetTeleportData(TELEPORT_DATA)

	-- Use pcall to prevent server crashes if teleport fails
	local success, errorMessage = pcall(function()
		TeleportService:TeleportAsync(
			DESTINATION_PLACE_ID,
			{ player },
			teleportOptions
		)
	end)

	-- Log teleport failures for debugging and analytics
	if not success then
		warn(
			string.format(
				"[Teleport Failed] Player: %s | Reason: %s",
				player.Name,
				tostring(errorMessage)
			)
		)
	end
end

--// PLAYER JOIN CONNECTION

-- When a player joins the server, immediately teleport them
-- This pattern is commonly used for: Lobby servers, Matchmaking hubs, Difficulty selectors
Players.PlayerAdded:Connect(function(player)
	teleportPlayer(player)
end)
