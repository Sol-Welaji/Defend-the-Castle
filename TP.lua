local tpService = game:GetService("TeleportService")

game.Players.PlayerAdded:Connect(function(p : Player)
	local tpOpt = Instance.new("TeleportOptions")
	tpOpt.ShouldReserveServer = true
	
	local tpData = {
		mode = "Easy"
	}
	
	tpOpt:SetTeleportData(tpData)
	tpService:TeleportAsync(93465852001946,{p},tpOpt)
end)