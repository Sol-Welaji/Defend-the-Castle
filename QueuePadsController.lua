local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueService = require(ReplicatedStorage.Modules.QueueService)

local QueuePads = workspace:WaitForChild("QueuePads")

local LeaveQueueEvent = Instance.new("RemoteEvent")
LeaveQueueEvent.Name = "LeaveQueue"
LeaveQueueEvent.Parent = ReplicatedStorage


local RemoteCountUpdate = Instance.new("RemoteEvent")
RemoteCountUpdate.Name = "QueuePadUpdate"
RemoteCountUpdate.Parent = ReplicatedStorage

local RemoteTimerUpdate = Instance.new("RemoteEvent")
RemoteTimerUpdate.Name = "QueueTimerUpdate"
RemoteTimerUpdate.Parent = ReplicatedStorage

local PadQueues = {}
local PadTimerRunning = {}

local function StartTimer(pad, queue)
	if PadTimerRunning[pad] then return end
	PadTimerRunning[pad] = true

	local timerLength = pad:GetAttribute("TimerLength") or 15
	local timeLeft = timerLength

	while timeLeft > 0 do
		-- Send time to all clients
		RemoteTimerUpdate:FireAllClients(pad, timeLeft)
		task.wait(1)

		if #queue.Queue == 0 then
			PadTimerRunning[pad] = false
			RemoteTimerUpdate:FireAllClients(pad, 0)
			return
		end

		if #queue.Queue >= queue.MaxPlayers then
			queue.OnFull()
			PadTimerRunning[pad] = false
			RemoteTimerUpdate:FireAllClients(pad, 0)
			return
		end

		timeLeft -= 1
	end

	-- Timer finished > teleport current players
	queue.OnFull()
	PadTimerRunning[pad] = false
	RemoteTimerUpdate:FireAllClients(pad, 0)
end

-- Create queues for each pad
for _, pad in ipairs(QueuePads:GetChildren()) do
	if pad:IsA("BasePart") or pad:IsA("Model") then

		local maxPlayers = pad:GetAttribute("MaxPlayers")
		local placeId = pad:GetAttribute("PlaceId")
		local timerLength = pad:GetAttribute("TimerLength")

		if maxPlayers and placeId and timerLength then
			local queue = QueueService.new(maxPlayers)
			PadQueues[pad] = queue

			-- Teleport group
			queue.OnFull = function()
				local group = table.clone(queue.Queue)

				for _, plr in ipairs(group) do
					queue:Remove(plr)
				end

				TeleportService:TeleportPartyAsync(placeId, group)
			end

			-- Update counter and start timer
			queue.QueueChanged.Event:Connect(function(currentQueue)
				RemoteCountUpdate:FireAllClients(pad, #currentQueue, queue.MaxPlayers)

				-- Start timer when first player joins
				if #currentQueue == 1 then
					StartTimer(pad, queue)
				end
			end)
		end
	end
end

-- Touch to join
for pad, queue in pairs(PadQueues) do
	local part = pad:IsA("Model") and pad.PrimaryPart or pad

	part.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if player then
			queue:Add(player)
		end
	end)
end

LeaveQueueEvent.OnServerEvent:Connect(function(player)
	for _, queue in pairs(PadQueues) do
		queue:Remove(player)
	end
end)

-- Remove on leave
Players.PlayerRemoving:Connect(function(player)
	for _, queue in pairs(PadQueues) do
		queue:Remove(player)
	end
end)
