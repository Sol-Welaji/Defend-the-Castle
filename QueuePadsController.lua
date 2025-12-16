
local TeleportService = game:GetService("TeleportService")

-- Players is required for resolving characters into Player objects and for cleanup when players leave the server.
local Players = game:GetService("Players")

-- ReplicatedStorage acts as the shared contract layer between server logic and client UI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- DEPENDENCIES
-- QueueService abstracts queue logic away from this script, allowing this file to focus purely on orchestration.
local QueueService = require(ReplicatedStorage.Modules.QueueService)

-- All queue pads must exist under this container.
-- This allows new pads to be added without code changes.
local QueuePadsFolder = workspace:WaitForChild("QueuePads")

-- REMOTE EVENTS (DECLARED ON SERVER)
-- Fired when a player manually leaves a queue.
local LeaveQueueEvent = Instance.new("RemoteEvent")
LeaveQueueEvent.Name = "LeaveQueue"
LeaveQueueEvent.Parent = ReplicatedStorage

-- Fired whenever a queue's player count changes.
local QueueCountUpdate = Instance.new("RemoteEvent")
QueueCountUpdate.Name = "QueuePadUpdate"
QueueCountUpdate.Parent = ReplicatedStorage

-- Fired every second during an active countdown.
local QueueTimerUpdate = Instance.new("RemoteEvent")
QueueTimerUpdate.Name = "QueueTimerUpdate"
QueueTimerUpdate.Parent = ReplicatedStorage

-- INTERNAL STATE
-- Maps queue pads to their QueueService instances.
local padQueues: {[Instance]: any} = {}

-- Prevents multiple countdown coroutines from running
-- simultaneously for the same pad.
local activeCountdowns: {[Instance]: boolean} = {}

-- TIMER / TELEPORT LOGIC
-- Handles countdown execution and teleporting once complete.
-- This function is intentionally isolated to keep timing logic deterministic and easy to reason about.
local function startQueueCountdown(pad: Instance, queue)
	-- Prevent duplicate timers for the same pad
	if activeCountdowns[pad] then
		return
	end
	activeCountdowns[pad] = true

	-- Timer duration is data-driven via attributes
	local duration = pad:GetAttribute("TimerLength") or 15

	for remaining = duration, 1, -1 do
		-- If everyone leaves mid-countdown, abort gracefully
		if queue:GetSize() == 0 then
			activeCountdowns[pad] = nil
			QueueTimerUpdate:FireAllClients(pad, 0)
			return
		end

		QueueTimerUpdate:FireAllClients(pad, remaining)
		task.wait(1)
	end

	activeCountdowns[pad] = nil
	QueueTimerUpdate:FireAllClients(pad, 0)

	-- Capture players at teleport time to avoid mutation issues
	local playersToTeleport = queue:GetPlayers()
	if #playersToTeleport == 0 then
		return
	end

	-- Clear queue before teleporting to prevent re-entry bugs
	queue:Flush()

	-- TeleportPartyAsync ensures players stay together
	TeleportService:TeleportPartyAsync(
		pad:GetAttribute("PlaceId"),
		playersToTeleport
	)
end

-- PAD INITIALIZATION
-- Each pad is configured purely through attributes, making this system scalable and designer-friendly.
for _, pad in ipairs(QueuePadsFolder:GetChildren()) do
	local maxPlayers = pad:GetAttribute("MaxPlayers")
	local placeId = pad:GetAttribute("PlaceId")

	-- Invalid pads are ignored rather than crashing the system
	if typeof(maxPlayers) ~= "number" or typeof(placeId) ~= "number" then
		warn("Queue pad missing required attributes:", pad:GetFullName())
		continue
	end

	local queue = QueueService.new(maxPlayers)
	padQueues[pad] = queue

	-- React to queue changes instead of polling
	queue.QueueChanged.Event:Connect(function(players)
		QueueCountUpdate:FireAllClients(pad, #players, maxPlayers)

		-- Countdown begins when the first player joins
		if #players == 1 then
			task.spawn(startQueueCountdown, pad, queue)
		end
	end)

	-- Resolve collision surface
	local touchPart =
		pad:IsA("Model") and pad.PrimaryPart
		or pad:IsA("BasePart") and pad
		or nil

	if not touchPart then
		warn("Queue pad has no valid touch surface:", pad:GetFullName())
		continue
	end

	-- Lightweight per-player debounce prevents rapid re-fires
	local touchDebounce: {[Player]: boolean} = {}

	touchPart.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or touchDebounce[player] then
			return
		end

		touchDebounce[player] = true
		queue:Add(player)

		-- Debounce clears automatically to avoid memory leaks
		task.delay(1, function()
			touchDebounce[player] = nil
		end)
	end)
end

-- MANUAL QUEUE EXIT
-- Allows players to leave via UI instead of physics.
LeaveQueueEvent.OnServerEvent:Connect(function(player)
	for _, queue in pairs(padQueues) do
		queue:Remove(player)
	end
end)

-- PLAYER CLEANUP
-- Ensures queues remain valid if players disconnect.
Players.PlayerRemoving:Connect(function(player)
	for _, queue in pairs(padQueues) do
		queue:Remove(player)
	end
end)
