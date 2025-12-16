
local QueueService = {}
QueueService.__index = QueueService

-- CONSTRUCTOR
-- Creates a new queue with a fixed capacity.
-- The queue does NOT teleport players itself — it only
-- manages state and emits signals. This separation keeps
-- the service reusable and testable.
function QueueService.new(maxPlayers: number)
	assert(
		typeof(maxPlayers) == "number" and maxPlayers > 0,
		"QueueService.new requires a positive maxPlayers value"
	)

	local self = setmetatable({}, QueueService)

	-- Maximum number of players allowed in the queue.
	-- This value is immutable after construction to avoid race conditions or inconsistent capacity logic.
	self.MaxPlayers = maxPlayers

	-- Ordered array preserving join order.
	-- Order matters for teleport grouping.
	self._queue = {}

	-- Hash table used for constant-time membership checks.
	-- This avoids expensive linear searches.
	self._lookup = {}

	-- BindableEvent allows external systems (pads, UI, etc.)
	-- to react to queue changes without tight coupling.
	self.QueueChanged = Instance.new("BindableEvent")

	-- When sealed, new players are rejected even if they
	-- attempt to join again. This prevents edge-case joins
	-- during teleport countdowns.
	self._sealed = false

	return self
end

-- INTERNAL UTILITIES

-- Fires QueueChanged with a defensive copy to prevent
-- external mutation of internal state.
function QueueService:_signalChange()
	self.QueueChanged:Fire(table.clone(self._queue))
end

-- PUBLIC API

-- Adds a player to the queue.
-- Returns true on success, false if rejected.
function QueueService:Add(player: Player): boolean
	-- Reject invalid or unsafe states
	if self._sealed then return false end
	if not player or not player:IsA("Player") then return false end
	if self._lookup[player] then return false end
	if #self._queue >= self.MaxPlayers then return false end

	-- Insert player
	self._lookup[player] = true
	table.insert(self._queue, player)

	-- Notify listeners of state change
	self:_signalChange()

	-- Seal queue once capacity is reached
	if #self._queue == self.MaxPlayers then
		self._sealed = true
	end

	return true
end

-- Removes a player from the queue.
-- Safe to call redundantly.
function QueueService:Remove(player: Player): boolean
	if not self._lookup[player] then
		return false
	end

	-- Clear lookup first to avoid race conditions
	self._lookup[player] = nil

	-- Remove from ordered queue (reverse loop avoids shifting issues)
	for i = #self._queue, 1, -1 do
		if self._queue[i] == player then
			table.remove(self._queue, i)
			break
		end
	end

	-- Unseal queue to allow new players
	self._sealed = false

	self:_signalChange()
	return true
end

-- Clears the queue entirely.
-- Used after teleporting players or aborting matchmaking.
function QueueService:Flush()
	table.clear(self._queue)
	table.clear(self._lookup)
	self._sealed = false

	self:_signalChange()
end

-- Returns a copy of players currently in the queue.
-- Callers must NOT mutate the returned table.
function QueueService:GetPlayers(): {Player}
	return table.clone(self._queue)
end

-- Returns the current queue size.
-- Exposed to avoid leaking internal tables.
function QueueService:GetCount(): number
	return #self._queue
end

-- Indicates whether the queue is currently full or sealed.
function QueueService:IsSealed(): boolean
	return self._sealed
end

-- CLEANUP
-- Explicit destroy method prevents BindableEvent leak if queues are dynamically created/destroyed.
function QueueService:Destroy()
	if self.QueueChanged then
		self.QueueChanged:Destroy()
	end

	table.clear(self._queue)
	table.clear(self._lookup)
	self._sealed = true
end

return QueueService


