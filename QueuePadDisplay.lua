local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CountEvent = ReplicatedStorage:WaitForChild("QueuePadUpdate")
local TimerEvent = ReplicatedStorage:WaitForChild("QueueTimerUpdate")

-- Update count label: "2 / 4"
CountEvent.OnClientEvent:Connect(function(pad, count, max)
	if pad:FindFirstChild("BillboardGui") then
		local label = pad.BillboardGui:FindFirstChild("CountLabel")
		if label then
			label.Text = count .. " / " .. max
		end
	end
end)

-- Update timer label: "Starting in: 12"
TimerEvent.OnClientEvent:Connect(function(pad, timeLeft)
	if pad:FindFirstChild("BillboardGui") then
		local label = pad.BillboardGui:FindFirstChild("TimerLabel")
		if label then
			if timeLeft > 0 then
				label.Text = "Starting in: " .. timeLeft
			else
				label.Text = ""
			end
		end
	end
end)
