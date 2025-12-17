
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

--// CLASS DEFINITION

local TeleportController = {}
TeleportController.__index = TeleportController

--// CONSTANTS

local DESTINATION_PLACE_ID = 93465852001946

-- Camera offset relative to player root when stabilizing physics
-- This prevents Roblox from snapping the character mid-teleport
local CAMERA_OFFSET = CFrame.new(0, 3, -10)

--// CONSTRUCTOR

function TeleportController.new()
	local self = setmetatable({}, TeleportController)

	-- Centralized teleport configuration
	self.TeleportData = {
		mode = "Easy",
		spawnType = "MatchInstance",
		timestamp = os.time()
	}

	-- Prevents duplicate teleport calls per player
	self.ActiveTeleports = {}

	return self
end

--// INTERNAL UTILITIES

-- Ensures character physics are stable before teleporting
-- This avoids ragdolling, falling states, or velocity injection
function TeleportController:_stabilizeCharacter(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")

	if not root or not humanoid then return end

	-- Zero velocity to eliminate physics carryover
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	-- Force humanoid into a neutral state
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	-- Small yield to allow physics solver to settle
	RunService.Heartbeat:Wait()

	humanoid:ChangeState(Enum.HumanoidStateType.Running)
end

-- Positions camera deterministically before teleport
-- This prevents abrupt camera snaps on the destination server
function TeleportController:_prepareCamera(player: Player)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = root.CFrame * CAMERA_OFFSET
end

--// TELEPORT EXECUTION

function TeleportController:_executeTeleport(player: Player)
	if self.ActiveTeleports[player] then return end
	self.ActiveTeleports[player] = true

	local character = player.Character or player.CharacterAdded:Wait()

	-- Physics stabilization before teleport
	self:_stabilizeCharacter(character)

	-- Prepare teleport options
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	options:SetTeleportData(self.TeleportData)

	-- Execute teleport safely
	local success, err = pcall(function()
		TeleportService:TeleportAsync(
			DESTINATION_PLACE_ID,
			{ player },
			options
		)
	end)

	if not success then
		warn("[TeleportController] Teleport failed:", err)
	end

	self.ActiveTeleports[player] = nil
end

--// PUBLIC API

function TeleportController:BindPlayer(player: Player)
	-- Teleport only once character & camera are fully initialized
	player.CharacterAdded:Wait()
	task.wait(0.1)

	self:_executeTeleport(player)
end

--// INITIALIZATION

local Controller = TeleportController.new()

Players.PlayerAdded:Connect(function(player)
	Controller:BindPlayer(player)
end)
