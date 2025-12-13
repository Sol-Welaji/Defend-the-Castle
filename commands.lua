local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		local args = string.split(message, " ")

		if args[1]:lower() == "/give" and args[2] == "gems" and args[3] then
			local amount = tonumber(args[3])

			if amount then
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local gems = leaderstats:FindFirstChild("Gems")
					if gems then
						gems.Value = gems.Value + amount
						print(player.Name .. " gave themselves " .. amount .. " gems!")
					end
				end
			end
		end
	end)
end)

print("Temporary gems command loaded! Use: /give gems (number)")