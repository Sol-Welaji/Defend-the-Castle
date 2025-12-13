local Players = game:GetService("Players")

local QueueService = {}
QueueService.__index = QueueService

function QueueService.new(maxPlayers: number)
	local self = setmetatable({}, QueueService)
	self.MaxPlayers = maxPlayers
	self.Queue = {}
	self.PlayerInQueue = {}
	self.QueueChanged = Instance.new("BindableEvent")
	return self
end

function QueueService:Add(player: Player)
	if self.PlayerInQueue[player] then return end
	if #self.Queue >= self.MaxPlayers then return end

	self.PlayerInQueue[player] = true
	table.insert(self.Queue, player)
	self.QueueChanged:Fire(self.Queue)

	if #self.Queue >= self.MaxPlayers then
		task.defer(function()
			self:OnFull()
		end)
	end
end

function QueueService:Remove(player: Player)
	if not self.PlayerInQueue[player] then return end
	self.PlayerInQueue[player] = nil

	for i, p in ipairs(self.Queue) do
		if p == player then
			table.remove(self.Queue, i)
			break
		end
	end

	self.QueueChanged:Fire(self.Queue)
end

function QueueService:OnFull()

end

return QueueService
