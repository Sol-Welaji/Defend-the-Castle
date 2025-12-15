-
local QueueService = {}
QueueService.__index = QueueService

-- Constructor
function QueueService.new(maxPlayers: number)
	assert(maxPlayers > 0, "MaxPlayers must be greater than 0")

	local self = setmetatable({}, QueueService)

	-- Maximum players allowed in the queue
	self.MaxPlayers = maxPlayers

	-- Ordered list of players in the queue
	self.Queue = {}

	-- Fast lookup table for O(1) membership checks
	self.PlayerLookup = {}

	-- Fired whenever players are added/removed
	self.QueueChanged = Instance.new("BindableEvent")

	-- Prevents adding players once queue is full
	self._sealed = false

	return self
end

-- Adds a player to the queue
function QueueService:Add(player: Player)
	-- Reject invalid states
	if self._sealed then return false end
	if self.PlayerLookup[player] then return false end
	if #self.Queue >= self.MaxPlayers then return false end

	-- Insert player
	self.PlayerLookup[player] = true
	table.insert(self.Queue, player)

	-- Notify listeners
	self.QueueChanged:Fire(self.Queue)

	-- Seal queue if full
	if #self.Queue == self.MaxPlayers then
		self._sealed = true
	end

	return true
end

-- Removes a player from the queue
function QueueService:Remove(player: Player)
	if not self.PlayerLookup[player] then return false end

	self.PlayerLookup[player] = nil

	-- Remove player from ordered queue
	for i = #self.Queue, 1, -1 do
		if self.Queue[i] == player then
			table.remove(self.Queue, i)
			break
		end
	end

	-- Allow queue to accept players again
	self._sealed = false

	self.QueueChanged:Fire(self.Queue)
	return true
end

-- Clears the entire queue
function QueueService:Flush()
	table.clear(self.Queue)
	table.clear(self.PlayerLookup)
	self._sealed = false

	self.QueueChanged:Fire(self.Queue)
end

-- Returns a safe copy of the queue
function QueueService:GetPlayers()
	return table.clone(self.Queue)
end

return QueueService
