
-- SERVICES

-- Centralized service fetching avoids repeated calls and improves clarity
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

-- PLAYER REFERENCES

-- Cached references reduce repeated lookups and allow safe re-binding on respawn
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- REMOTE REFERENCES
-- All remotes are grouped under a single folder to avoid hardcoded paths
local Remotes = ReplicatedStorage:WaitForChild("REs")

local RollResultRemote = Remotes:WaitForChild("GachaRollRemote")
local RollRequestRemote = Remotes:WaitForChild("GachaRollRequest")
local Roll10RequestRemote = Remotes:WaitForChild("GachaRoll10Request")
local AddInventoryRemote = Remotes:WaitForChild("AddToInventory")
local GetStockRemote = Remotes:WaitForChild("GetGachaStock")
local StockUpdatedRemote = Remotes:WaitForChild("GachaStockUpdated")
local RefreshInventoryRemote = Remotes:WaitForChild("RefreshInventory")

-- DATA MODULES

-- Character metadata is kept server-authoritative and reused client-side
local CharacterStats = require(ReplicatedStorage.Modules.CharacterLobbyStats)

-- CHARACTER STATE

-- These references are rebound whenever the character respawns
local character
local humanoidRootPart

-- UI STATE

-- Explicit state variables make UI behavior predictable and debuggable
local gachaGui = nil
local rewardGui = nil
local insideZone = false

-- Cached server data to avoid excessive remote calls
local stockCache = {}
local rotationEnd = 0

-- Stores UI connections for clean teardown
local uiConnections = {}

-- Zone polling throttling to prevent per-frame distance checks
local lastZoneCheck = 0
local ZONE_INTERVAL = 0.25

-- GAMEPLAY CONSTANTS

-- Order is explicitly defined to prevent reliance on table iteration order
local rarityOrder = {"Common","Rare","Epic","Legendary","Mythic","Godly"}

-- Visual identity per rarity
local rarityColors = {
	Common = Color3.fromRGB(180,180,180),
	Rare = Color3.fromRGB(100,180,255),
	Epic = Color3.fromRGB(170,80,230),
	Legendary = Color3.fromRGB(255,220,80),
	Mythic = Color3.fromRGB(255,100,180),
	Godly = Color3.fromRGB(255,80,80)
}

-- Auto-sell flags are client-side preferences only
local autoSell = {
	Common=false,
	Rare=false,
	Epic=false,
	Legendary=false,
	Mythic=false,
	Godly=false
}

-- CHARACTER BINDING

-- Rebinding logic ensures scripts remain valid after respawns
local function bindCharacter(char)
	character = char
	humanoidRootPart = char:WaitForChild("HumanoidRootPart")
end

bindCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(bindCharacter)


-- ZONE DISCOVERY

-- Uses CollectionService instead of hardcoded workspace paths
local function getZone()
	local zones = CollectionService:GetTagged("GachaZone")
	return zones[1]
end

-- SERVER DATA SYNC

-- Pulls stock data once and caches it locally for UI use
local function fetchStock()
	local ok, stock, endTime = pcall(function()
		return GetStockRemote:InvokeServer()
	end)
	if ok then
		stockCache = stock or {}
		rotationEnd = endTime or 0
	end
end

-- Converts remaining rotation time into a readable string
local function formatTime()
	local t = rotationEnd - os.clock()
	if t <= 0 then
		return "Rotating..."
	end
	local h = math.floor(t/3600)
	local m = math.floor((t%3600)/60)
	local s = math.floor(t%60)
	return string.format("%02d:%02d:%02d",h,m,s)
end

-- UI CLEANUP

-- Explicit disconnection prevents memory leaks
local function clearConnections()
	for _,c in ipairs(uiConnections) do
		c:Disconnect()
	end
	table.clear(uiConnections)
end

-- Centralized GUI teardown logic
local function destroyGacha()
	clearConnections()
	if gachaGui then
		gachaGui:Destroy()
		gachaGui = nil
	end
end


-- REWARD DISPLAY

-- Creates a single reward card with animated entry
local function createRewardFrame(parent,roll,index,total)
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

	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(0.9,0.6)
	img.Position = UDim2.fromScale(0.5,0.4)
	img.AnchorPoint = Vector2.new(0.5,0.5)
	img.Image = roll.data.icon
	img.Parent = frame

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1,0.15)
	name.Position = UDim2.fromScale(0.5,0)
	name.AnchorPoint = Vector2.new(0.5,0)
	name.Text = roll.name
	name.TextColor3 = Color3.new(1,1,1)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.Parent = frame

	TweenService:Create(frame,TweenInfo.new(0.4,Enum.EasingStyle.Back),{
		Size = UDim2.fromOffset(120,160)
	}):Play()
end

-- Displays all roll results and auto-dismisses after a delay
local function showRewards(results)
	if rewardGui then rewardGui:Destroy() end
	rewardGui = Instance.new("ScreenGui")
	rewardGui.ResetOnSpawn = false
	rewardGui.Parent = playerGui

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1,1)
	overlay.BackgroundColor3 = Color3.new(0,0,0)
	overlay.BackgroundTransparency = 0.4
	overlay.Parent = rewardGui

	for i,roll in ipairs(results) do
		createRewardFrame(overlay,roll,i,#results)
	end

	task.delay(5,function()
		if rewardGui then rewardGui:Destroy() rewardGui=nil end
	end)
end

-- MAIN GACHA UI

-- Builds UI only once per zone entry
local function buildGui()
	if gachaGui then return end

	fetchStock()

	gachaGui = Instance.new("ScreenGui")
	gachaGui.ResetOnSpawn = false
	gachaGui.Parent = playerGui

	local main = Instance.new("Frame",gachaGui)
	main.Size = UDim2.fromOffset(500,450)
	main.Position = UDim2.fromScale(0.5,0.5)
	main.AnchorPoint = Vector2.new(0.5,0.5)
	main.BackgroundColor3 = Color3.fromRGB(25,20,35)

	local timer = Instance.new("TextLabel",main)
	timer.Size = UDim2.fromScale(0.4,0.07)
	timer.Position = UDim2.fromScale(0.3,0.02)
	timer.BackgroundTransparency = 1
	timer.TextColor3 = Color3.new(1,1,1)
	timer.Font = Enum.Font.Gotham
	timer.TextScaled = true

	table.insert(uiConnections,RunService.Heartbeat:Connect(function()
		timer.Text = formatTime()
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

	table.insert(uiConnections,rollBtn.MouseButton1Click:Connect(function()
		RollRequestRemote:FireServer()
	end))

	table.insert(uiConnections,roll10Btn.MouseButton1Click:Connect(function()
		Roll10RequestRemote:FireServer()
	end))
end

-- ZONE CHECK LOOP

-- Throttled distance checks prevent unnecessary per-frame math
RunService.Heartbeat:Connect(function(dt)
	lastZoneCheck += dt
	if lastZoneCheck < ZONE_INTERVAL then return end
	lastZoneCheck = 0
	if not humanoidRootPart then return end

	local zone = getZone()
	if not zone then return end

	local inside = (humanoidRootPart.Position-zone.Position).Magnitude <= zone.Size.Magnitude/2

	if inside and not insideZone then
		insideZone = true
		buildGui()
	elseif not inside and insideZone then
		insideZone = false
		destroyGacha()
	end
end)

-- SERVER EVENT HANDLING

StockUpdatedRemote.OnClientEvent:Connect(function(stock)
	stockCache = stock
end)

RollResultRemote.OnClientEvent:Connect(function(results)
	for _,roll in ipairs(results) do
		if not autoSell[roll.rarity] then
			AddInventoryRemote:FireServer(roll.name,roll.rarity,roll.data)
		end
	end
	showRewards(results)
	RefreshInventoryRemote:FireServer()
end)

print("Gacha client loaded")
