
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueService = require(ReplicatedStorage.Modules.QueueService)
local QueuePads = workspace:WaitForChild("QueuePads")

-- Remote events
local LeaveQueueEvent = Instance.new("RemoteEvent")
LeaveQueueEvent.Name = "LeaveQueue"
LeaveQueueEvent.Parent = ReplicatedStorage

local CountUpdate = Instance.new("RemoteEvent")
CountUpdate.Name = "QueuePadUpdate"
CountUpdate.Parent = ReplicatedStorage

local TimerUpdate = Instance.new("RemoteEvent")
TimerUpdate.Name = "QueueTimerUpdate"
TimerUpdate.Parent = ReplicatedStorage

-- Internal state
local queues = {}
local activeTimers = {}

-- Starts countdown timer for a queue pad
local function runTimer(pad, queue)
	if activeTimers[pad] then return end
	activeTimers[pad] = true

	local duration = pad:GetAttribute("TimerLength") or 15

	-- Countdown loop
	for t = duration, 1, -1 do
		if #queue:GetPlayers() == 0 then
			break
		end

		TimerUpdate:FireAllClients(pad, t)
		task.wait(1)
	end

	activeTimers[pad] = nil
	TimerUpdate:FireAllClients(pad, 0)

	-- Teleport players if queue still has players
	local group = queue:GetPlayers()
	if #group > 0 then
		queue:Flush()
		TeleportService:TeleportPartyAsync(
			pad:GetAttribute("PlaceId"),
			group
		)
	end
end

-- Initialize queues for each pad
for _, pad in ipairs(QueuePads:GetChildren()) do
	local maxPlayers = pad:GetAttribute("MaxPlayers")
	local placeId = pad:GetAttribute("PlaceId")

	if not (maxPlayers and placeId) then continue end

	local queue = QueueService.new(maxPlayers)
	queues[pad] = queue

	-- Listen for queue changes
	queue.QueueChanged.Event:Connect(function(players)
		CountUpdate:FireAllClients(pad, #players, maxPlayers)

		-- Start timer when first player joins
		if #players == 1 then
			task.spawn(runTimer, pad, queue)
		end
	end)

	-- Handle player stepping on pad
	local part = pad:IsA("Model") and pad.PrimaryPart or pad
	local debounce = {}

	part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or debounce[player] then return end

		debounce[player] = true
		queue:Add(player)

		task.delay(1, function()
			debounce[player] = nil
		end)
	end)
end

-- Manual leave queue
LeaveQueueEvent.OnServerEvent:Connect(function(player)
	for _, queue in pairs(queues) do
		queue:Remove(player)
	end
end)

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(player)
	for _, queue in pairs(queues) do
		queue:Remove(player)
	end
end)
