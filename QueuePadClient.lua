local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local LeaveQueueEvent = ReplicatedStorage:WaitForChild("LeaveQueue")

-- GUIs
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QueueUI"
screenGui.Parent = player:WaitForChild("PlayerGui")

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Parent = screenGui
leaveButton.Size = UDim2.new(0, 200, 0, 50)
leaveButton.Position = UDim2.new(0.5, -100, 0.85, 0)
leaveButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
leaveButton.TextColor3 = Color3.new(1,1,1)
leaveButton.TextScaled = true
leaveButton.Visible = false
leaveButton.Text = "LEAVE QUEUE"

-- Variables
local inQueue = false
local originalCameraType
local originalCameraSubject

-- Lock movement
local function LockMovement()
	if not character then return end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
end

-- Unlock movement
local function UnlockMovement()
	if not character then return end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	end
end

-- Camera front lock
local function LockCameraToPad(pad)
	local cam = workspace.CurrentCamera

	originalCameraType = cam.CameraType
	originalCameraSubject = cam.CameraSubject

	cam.CameraType = Enum.CameraType.Scriptable

	local padCFrame = pad:GetPivot()

	-- Put camera 6 studs in front looking at pad
	local camPos = padCFrame.Position + padCFrame.LookVector * -10 + Vector3.new(0, 3, 0)
	local camLook = padCFrame.Position + Vector3.new(0, 2, 0)

	cam.CFrame = CFrame.lookAt(camPos, camLook)
end

-- Restore camera
local function RestoreCamera()
	local cam = workspace.CurrentCamera
	cam.CameraType = originalCameraType or Enum.CameraType.Custom
	cam.CameraSubject = originalCameraSubject or player.Character:WaitForChild("Humanoid")
end

-- Called by server when player joins a queue
ReplicatedStorage:WaitForChild("QueuePadUpdate").OnClientEvent:Connect(function(pad, count, max)
	-- Only lock camera when YOU join
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- If this pad includes this player ? lock
	if pad and pad:FindFirstChild("BillboardGui") then
		if count > 0 then
			-- You are in queue if you are on the pad
			local distance = (hrp.Position - pad:GetPivot().Position).Magnitude
			if distance < 10 then
				if not inQueue then
					inQueue = true
					LockMovement()
					LockCameraToPad(pad)
					leaveButton.Visible = true
				end
			end
		end
	end
end)

-- Leave queue button
leaveButton.MouseButton1Click:Connect(function()
	if inQueue then
		inQueue = false
		UnlockMovement()
		RestoreCamera()
		leaveButton.Visible = false
		LeaveQueueEvent:FireServer()
	end
end)

-- If teleported or queue ends ? reset automatically
LeaveQueueEvent.OnClientEvent:Connect(function()
	inQueue = false
	UnlockMovement()
	RestoreCamera()
	leaveButton.Visible = false
end)
