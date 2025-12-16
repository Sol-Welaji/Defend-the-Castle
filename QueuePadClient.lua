-- SERVICES
-- Services are cached once for performance, clarity, and to document all engine dependencies up front.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- PLAYER CONTEXT
-- LocalPlayer is only valid in LocalScripts and represents the client executing this code.
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Character references must be refreshed on respawn, so they are NOT treated as static.
local character = player.Character or player.CharacterAdded:Wait()

-- REMOTES
-- All queue-related remotes are centralized in ReplicatedStorage to maintain a clean client/server contract.
local LeaveQueueEvent = ReplicatedStorage:WaitForChild("LeaveQueue")
local QueuePadUpdateEvent = ReplicatedStorage:WaitForChild("QueuePadUpdate")

-- UI SETUP
-- UI is created client-side to ensure it is:
-- • Not replicated unnecessarily
-- • Fully client-authoritative
-- • Easy to clean up or reset
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QueueUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.fromOffset(200, 50)
leaveButton.Position = UDim2.fromScale(0.5, 0.85)
leaveButton.AnchorPoint = Vector2.new(0.5, 0)
leaveButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.TextScaled = true
leaveButton.Visible = false
leaveButton.Text = "LEAVE QUEUE"
leaveButton.Parent = screenGui

-- Rounded corners for visual polish without impacting logic
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = leaveButton

-- CLIENT STATE
-- Tracks whether THIS client is currently locked into a queue.
-- State is client-driven but validated by the server.
local inQueue = false

-- Camera state is stored so it can be restored exactly, rather than guessing default values.
local originalCameraType
local originalCameraSubject

-- CHARACTER CONTROL
-- Movement locking is handled by modifying Humanoid properties.
-- This avoids anchoring parts, which can break animations and physics replication.
local function setMovementEnabled(enabled: boolean)
	if not character then return end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then return end

	if enabled then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	else
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
end

-- CAMERA CONTROL
-- Camera is placed into Scriptable mode so the player cannot override it via mouse movement.
local function lockCameraToPad(pad: Model)
	local camera = workspace.CurrentCamera

	-- Store previous camera state for clean restoration
	originalCameraType = camera.CameraType
	originalCameraSubject = camera.CameraSubject

	camera.CameraType = Enum.CameraType.Scriptable

	local padCFrame = pad:GetPivot()

	-- Camera offset is calculated relative to pad orientation instead of hardcoded world positions.
	local cameraPosition =
		padCFrame.Position
		- padCFrame.LookVector * 10
		+ Vector3.new(0, 3, 0)

	local lookTarget = padCFrame.Position + Vector3.new(0, 2, 0)

	camera.CFrame = CFrame.lookAt(cameraPosition, lookTarget)
end

-- Restores the camera to its original state without assuming defaults.
local function restoreCamera()
	local camera = workspace.CurrentCamera

	camera.CameraType = originalCameraType or Enum.CameraType.Custom
	camera.CameraSubject = originalCameraSubject
end

-- QUEUE STATE MANAGEMENT
-- Centralized function ensures entering the queue always applies the same rules.
local function enterQueue(pad: Model)
	if inQueue then return end

	inQueue = true
	setMovementEnabled(false)
	lockCameraToPad(pad)
	leaveButton.Visible = true
end

-- Centralized exit logic avoids duplicated cleanup code.
local function exitQueue()
	if not inQueue then return end

	inQueue = false
	setMovementEnabled(true)
	restoreCamera()
	leaveButton.Visible = false
end

-- SERVER → CLIENT UPDATES
-- Server informs the client when queue state changes.
-- The client validates whether the update applies to THEM.
QueuePadUpdateEvent.OnClientEvent:Connect(function(pad: Model, count: number)
	if not pad or not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Distance check ensures this only applies to the local player without relying on server-side player lists.
	local distance = (root.Position - pad:GetPivot().Position).Magnitude

	if count > 0 and distance <= 10 then
		enterQueue(pad)
	end
end)

-- UI INTERACTION
leaveButton.MouseButton1Click:Connect(function()
	if not inQueue then return end

	exitQueue()
	LeaveQueueEvent:FireServer()
end)

-- FORCED QUEUE EXIT
-- Server can force an exit due to teleport, match start, or administrative override.
LeaveQueueEvent.OnClientEvent:Connect(function()
	exitQueue()
end)

-- CHARACTER RESPAWN HANDLING
-- Character references must be refreshed on respawn to prevent stale humanoid or camera references.
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	exitQueue()
end)

