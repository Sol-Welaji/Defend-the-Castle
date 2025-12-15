-- SERVICES
-- ReplicatedStorage is used to store RemoteEvents that define
-- the client/server communication contract.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- REMOTE EVENTS
-- These events are fired by the server whenever the queue
-- state changes for a specific pad.
local QueueCountEvent = ReplicatedStorage:WaitForChild("QueuePadUpdate")
local QueueTimerEvent = ReplicatedStorage:WaitForChild("QueueTimerUpdate")

-- BILLBOARD ACCESS HELPERS
-- Centralized validation prevents duplicated nil checks
-- and protects against runtime errors if pads are misconfigured.
local function getBillboardLabel(pad: Instance, labelName: string): TextLabel?
	if not pad or not pad:IsA("Model") then
		return nil
	end

	local billboard = pad:FindFirstChild("BillboardGui")
	if not billboard then
		return nil
	end

	local label = billboard:FindFirstChild(labelName)
	if label and label:IsA("TextLabel") then
		return label
	end

	return nil
end

-- QUEUE COUNT HANDLING
-- Updates the player count display for a queue pad.
-- Logic is client-side for responsiveness and to avoid
-- unnecessary server-side UI replication.
QueueCountEvent.OnClientEvent:Connect(function(pad: Model, count: number, max: number)
	local countLabel = getBillboardLabel(pad, "CountLabel")
	if not countLabel then
		return
	end

	-- Using string.format avoids implicit string concatenation
	-- and improves readability for formatted UI text.
	countLabel.Text = string.format("%d / %d", count, max)
end)

-- QUEUE TIMER HANDLING
-- Updates the countdown text shown above a queue pad.
-- The server remains authoritative over timing,
-- while the client only reflects visual state.
QueueTimerEvent.OnClientEvent:Connect(function(pad: Model, timeLeft: number)
	local timerLabel = getBillboardLabel(pad, "TimerLabel")
	if not timerLabel then
		return
	end

	-- Timer visibility is derived from state instead of toggling
	-- the BillboardGui itself, preventing flicker or desync.
	if timeLeft > 0 then
		timerLabel.Text = string.format("Starting in: %d", timeLeft)
	else
		timerLabel.Text = ""
	end
end)

print(" Queue billboard client handler loaded successfully")
