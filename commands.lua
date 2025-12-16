--// SERVICES
-- Players is used to resolve message senders into Player objects
local Players = game:GetService("Players")

-- TextChatService is the modern, non-deprecated system for
-- handling chat input on Roblox.
local TextChatService = game:GetService("TextChatService")

--// CONFIGURATION
-- Prefix allows commands to be changed without touching logic
local COMMAND_PREFIX = "/"

-- Command keyword definitions keep parsing predictable
local GIVE_COMMAND = "give"
local CURRENCY_NAME = "gems"

--// INTERNAL HELPERS
-- Safely resolves a player's Gems IntValue without assuming structure.
-- This avoids runtime errors if leaderstats are missing or renamed.
local function getGemsValue(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	local gems = leaderstats:FindFirstChild("Gems")
	if not gems or not gems:IsA("IntValue") then
		return nil
	end

	return gems
end

-- Parses a chat message into lowercase arguments
-- This centralizes string logic and avoids duplication.
local function parseMessage(text: string): {string}
	local args = string.split(string.lower(text), " ")
	return args
end

--// CHAT COMMAND HANDLER
-- This function is executed for every chat message sent by players.
-- Using TextChatService ensures compatibility with future Roblox updates.
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	-- Ignore system messages or messages without a source
	if not message.TextSource then
		return
	end

	local player = Players:GetPlayerByUserId(message.TextSource.UserId)
	if not player then
		return
	end

	local args = parseMessage(message.Text)
	if #args < 3 then
		return
	end

	-- Validate command prefix and structure
	if args[1] ~= COMMAND_PREFIX .. GIVE_COMMAND then
		return
	end

	if args[2] ~= CURRENCY_NAME then
		return
	end

	-- Convert and validate amount
	local amount = tonumber(args[3])
	if not amount or amount <= 0 then
		return
	end

	-- Resolve Gems value safely
	local gems = getGemsValue(player)
	if not gems then
		warn("Gems value missing for player:", player.Name)
		return
	end

	-- Apply reward
	gems.Value += amount

	print(("[DEV COMMAND] %s granted themselves %d gems")
		:format(player.Name, amount)
	)

	-- Returning nil allows the chat message to still appear normally
	return
end

print("Developer gem command loaded (TextChatService)")
print("Usage: /give gems <amount>")

