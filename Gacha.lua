local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

-- PLAYER REFERENCES
-- Cached references improve performance and simplify access.
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- REMOTE REFERENCES
-- All remotes are centralized under one folder to avoid
-- hardcoded paths and to keep networking organized.
local Remotes = ReplicatedStorage:WaitForChild("REs")

local RollResultRemote = Remotes:WaitForChild("GachaRollRemote")
local RollRequestRemote = Remotes:WaitForChild("GachaRollRequest")
local Roll10RequestRemote = Remotes:WaitForChild("GachaRoll10Request")
local AddInventoryRemote = Remotes:WaitForChild("AddToInventory")
local GetStockRemote = Remotes:WaitForChild("GetGachaStock")
local StockUpdatedRemote = Remotes:WaitForChild("GachaStockUpdated")
local RefreshInventoryRemote = Remotes:WaitForChild("RefreshInventory")

-- DATA MODULES
-- CharacterStats is a shared metadata module used to display
-- icons, names, and other visual information client-side.
local CharacterStats = require(ReplicatedStorage.Modules.CharacterLobbyStats)

-- GACHA CLIENT CLASS
-- Implements OOP via metatables to encapsulate state and logic.
local GachaClient = {}
GachaClient.__index = GachaClient

-- CONSTANTS
-- Zone checks are throttled to reduce expensive distance math.
local ZONE_INTERVAL = 0.25

-- RARITY DEFINITIONS
-- Order is explicit to avoid reliance on table iteration order.
local rarityOrder = {
	"Common","Rare","Epic","Legendary","Mythic","Godly"
}

-- VISUAL STYLING PER RARITY
-- Centralized color definitions ensure consistency across UI.
local rarityColors = {
	Common = Color3.fromRGB(180,180,180),
	Rare = Color3.fromRGB(100,180,255),
	Epic = Color3.fromRGB(170,80,230),
	Legendary = Color3.fromRGB(255,220,80),
	Mythic = Color3.fromRGB(255,100,180),
	Godly = Color3.fromRGB(255,80,80)
}

-- CONSTRUCTOR
-- Initializes state, binds character, and connects core loops.
function GachaClient.new()
	local self = setmetatable({}, GachaClient)

	-- Character-related references (rebound on respawn)
	self.Character = nil
	self.Root = nil

	-- UI state
	self.GachaGui = nil
	self.RewardGui = nil
	self.InsideZone = false

	-- Cached server data to reduce remote calls
	self.StockCache = {}
	self.RotationEnd = 0

	-- Tracks UI connections for clean teardown
	self.UIConnections = {}

	-- Zone polling throttling accumulator
	self.LastZoneCheck = 0

	-- Client-side autosell preferences
	self.AutoSell = {
		Common=false,
		Rare=false,
		Epic=false,
		Legendary=false,
		Mythic=false,
		Godly=false
	}

	-- Bind initial character and rebind on respawn
	self:_bindCharacter(player.Character or player.CharacterAdded:Wait())
	player.CharacterAdded:Connect(function(char)
		self:_bindCharacter(char)
	end)

	-- Core update loops and server listeners
	self:_connectCoreLoops()
	self:_connectServerEvents()

	return self
end

-- CHARACTER BINDING
-- Ensures references stay valid across respawns.
function GachaClient:_bindCharacter(char)
	self.Character = char
	self.Root = char:WaitForChild("HumanoidRootPart")
end

-- ZONE DISCOVERY
-- Uses CollectionService instead of hardcoded workspace paths.
function GachaClient:_getZone()
	local zones = CollectionService:GetTagged("GachaZone")
	return zones[1]
end

-- SERVER DATA FETCH
-- Pulls stock data once and caches it locally.
function GachaClient:_fetchStock()
	local ok, stock, endTime = pcall(function()
		return GetStockRemote:InvokeServer()
	end)

	if ok then
		self.StockCache = stock or {}
		self.RotationEnd = endTime or 0
	end
end

-- TIMER FORMATTING
-- Converts remaining rotation time into HH:MM:SS.
function GachaClient:_formatTime()
	local t = self.RotationEnd - os.clock()
	if t <= 0 then
		return "Rotating..."
	end

	local h = math.floor(t/3600)
	local m = math.floor((t%3600)/60)
	local s = math.floor(t%60)

	return string.format("%02d:%02d:%02d",h,m,s)
end

-- CONNECTION MANAGEMENT
-- Explicit disconnection prevents memory leaks.
function GachaClient:_clearConnections()
	for _,c in ipairs(self.UIConnections) do
		c:Disconnect()
	end
	table.clear(self.UIConnections)
end

-- GUI CLEANUP
-- Centralized teardown logic for safe destruction.
function GachaClient:_destroyGui()
	self:_clearConnections()
	if self.GachaGui then
		self.GachaGui:Destroy()
		self.GachaGui = nil
	end
end

-- REWARD FRAME CREATION
-- Each reward card animates in with rarity styling.
function GachaClient:_createRewardFrame(parent, roll)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(0,0)
	frame.AnchorPoint = Vector2.new(0.5,0.5)
	frame.Position = UDim2.fromScale(0.5,0.5)
	frame.BackgroundColor3 = Color3.fromRGB(30,25,40)
	frame.Parent = parent

	Instance.new("UICorner",frame).CornerRadius = UDim.new(0,10)

	local stroke = Instance.new("UIStroke",frame)
	stroke.Thickness = 3
	stroke.Color = rarityColors[roll.rarity]

	local img = Instance.new("ImageLabel",frame)
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(0.9,0.6)
	img.Position = UDim2.fromScale(0.5,0.45)
	img.AnchorPoint = Vector2.new(0.5,0.5)
	img.Image = roll.data.icon

	local label = Instance.new("TextLabel",frame)
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1,0.15)
	label.Position = UDim2.fromScale(0.5,0)
	label.AnchorPoint = Vector2.new(0.5,0)
	label.Text = roll.name
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1,1,1)

	TweenService:Create(frame,TweenInfo.new(0.4,Enum.EasingStyle.Back),{
		Size = UDim2.fromOffset(120,160)
	}):Play()
end

-- REWARD DISPLAY
-- Shows all rewards and auto-dismisses after a delay.
function GachaClient:_showRewards(results)
	if self.RewardGui then self.RewardGui:Destroy() end

	self.RewardGui = Instance.new("ScreenGui")
	self.RewardGui.ResetOnSpawn = false
	self.RewardGui.Parent = playerGui

	local overlay = Instance.new("Frame",self.RewardGui)
	overlay.Size = UDim2.fromScale(1,1)
	overlay.BackgroundColor3 = Color3.new(0,0,0)
	overlay.BackgroundTransparency = 0.4

	for _,roll in ipairs(results) do
		self:_createRewardFrame(overlay,roll)
	end

	task.delay(5,function()
		if self.RewardGui then
			self.RewardGui:Destroy()
			self.RewardGui = nil
		end
	end)
end

-- MAIN GACHA UI
-- Built lazily when player enters the gacha zone.
function GachaClient:_buildGui()
	if self.GachaGui then return end

	self:_fetchStock()

	self.GachaGui = Instance.new("ScreenGui")
	self.GachaGui.ResetOnSpawn = false
	self.GachaGui.Parent = playerGui

	local main = Instance.new("Frame",self.GachaGui)
	main.Size = UDim2.fromOffset(500,450)
	main.Position = UDim2.fromScale(0.5,0.5)
	main.AnchorPoint = Vector2.new(0.5,0.5)
	main.BackgroundColor3 = Color3.fromRGB(25,20,35)

	local timer = Instance.new("TextLabel",main)
	timer.Size = UDim2.fromScale(0.4,0.07)
	timer.Position = UDim2.fromScale(0.3,0.02)
	timer.BackgroundTransparency = 1
	timer.Font = Enum.Font.Gotham
	timer.TextScaled = true
	timer.TextColor3 = Color3.new(1,1,1)

	table.insert(self.UIConnections,RunService.Heartbeat:Connect(function()
		timer.Text = self:_formatTime()
	end))

	local rollBtn = Instance.new("TextButton",main)
	rollBtn.Size = UDim2.fromScale(0.45,0.15)
	rollBtn.Position = UDim2.fromScale(0.05,0.8)
	rollBtn.Text = "ROLL"
	rollBtn.Font = Enum.Font.GothamBold
	rollBtn.TextScaled = true

	local roll10Btn = Instance.new("TextButton",main)
	roll10Btn.Size = UDim2.fromScale(0.45,0.15)
	roll10Btn.Position = UDim2.fromScale(0.5,0.8)
	roll10Btn.Text = "ROLL x10"
	roll10Btn.Font = Enum.Font.GothamBold
	roll10Btn.TextScaled = true

	table.insert(self.UIConnections,rollBtn.MouseButton1Click:Connect(function()
		RollRequestRemote:FireServer()
	end))

	table.insert(self.UIConnections,roll10Btn.MouseButton1Click:Connect(function()
		Roll10RequestRemote:FireServer()
	end))
end

-- CORE ZONE LOOP
-- Throttled distance checks prevent unnecessary calculations.
function GachaClient:_connectCoreLoops()
	RunService.Heartbeat:Connect(function(dt)
		self.LastZoneCheck += dt
		if self.LastZoneCheck < ZONE_INTERVAL then return end
		self.LastZoneCheck = 0

		if not self.Root then return end
		local zone = self:_getZone()
		if not zone then return end

		local inside = (self.Root.Position-zone.Position).Magnitude <= zone.Size.Magnitude/2

		if inside and not self.InsideZone then
			self.InsideZone = true
			self:_buildGui()
		elseif not inside and self.InsideZone then
			self.InsideZone = false
			self:_destroyGui()
		end
	end)
end

-- SERVER EVENT HANDLING
-- Processes stock updates and roll results from the server.
function GachaClient:_connectServerEvents()
	StockUpdatedRemote.OnClientEvent:Connect(function(stock)
		self.StockCache = stock
	end)

	RollResultRemote.OnClientEvent:Connect(function(results)
		for _,roll in ipairs(results) do
			if not self.AutoSell[roll.rarity] then
				AddInventoryRemote:FireServer(roll.name,roll.rarity,roll.data)
			end
		end
		self:_showRewards(results)
		RefreshInventoryRemote:FireServer()
	end)
end

-- INITIALIZATION
-- Creates a single persistent controller instance.
GachaClient.new()

print("Gacha client controller loaded successfully")
