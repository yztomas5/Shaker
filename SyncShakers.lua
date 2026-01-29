local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("Trove"))

local plotsFolder = Workspace:WaitForChild("Plots")

local mainTrove = Trove.new()
local playerTroves = {}
local playerInitialized = {}

local function ensurePlayerShakersFolder(player)
	local f = player:FindFirstChild("Shakers")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Shakers"
		f.Parent = player
	end
	return f
end

local function getPlotShakersFolder(player)
	local currentPlotValue = player:FindFirstChild("CurrentPlot")
	if not currentPlotValue then return nil end
	local plotNumber = currentPlotValue.Value
	if plotNumber == "" then return nil end

	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
	if not plotFolder then return nil end

	return plotFolder:FindFirstChild("Shakers")
end

local function syncShakers(player)
	if not player or not player.Parent then return end
	local playerShakers = ensurePlayerShakersFolder(player)
	local plotShakers = getPlotShakersFolder(player)
	if not plotShakers then
		return
	end

	local desired = {}
	for _, child in ipairs(plotShakers:GetChildren()) do
		if child:IsA("Folder") then
			local shakerNumber = tonumber(child.Name)
			if shakerNumber then
				desired[tostring(child.Name)] = true
			end
		end
	end

	local existing = {}
	for _, child in ipairs(playerShakers:GetChildren()) do
		if child:IsA("Folder") then
			existing[tostring(child.Name)] = child
		end
	end

	for name, _ in pairs(desired) do
		if not existing[name] then
			local newFolder = Instance.new("Folder")
			newFolder.Name = name
			newFolder.Parent = playerShakers
		end
	end

	for name, folderInstance in pairs(existing) do
		if not desired[name] then
			folderInstance:Destroy()
		end
	end
end

local function attachListenersForPlayer(player)
	if not playerTroves[player] then
		playerTroves[player] = Trove.new()
	end
	local playerTrove = playerTroves[player]

	playerTrove:Clean()

	local function connectToPlotShakers()
		local plotShakers = getPlotShakersFolder(player)
		if not plotShakers then return end

		playerTrove:Connect(plotShakers.ChildAdded, function(child)
			if child:IsA("Folder") then
				task.defer(function()
					syncShakers(player)
				end)
			end
		end)

		playerTrove:Connect(plotShakers.ChildRemoved, function(child)
			if child:IsA("Folder") then
				task.defer(function()
					syncShakers(player)
				end)
			end
		end)
	end

	local currentPlotValue = player:FindFirstChild("CurrentPlot")
	if currentPlotValue then
		playerTrove:Connect(currentPlotValue.Changed, function()
			task.defer(function()
				syncShakers(player)
				connectToPlotShakers()
			end)
		end)
	end

	syncShakers(player)
	connectToPlotShakers()
end

mainTrove:Connect(Players.PlayerAdded, function(player)
	ensurePlayerShakersFolder(player)
	playerInitialized[player.UserId] = false

	local function initializePlayer()
		if playerInitialized[player.UserId] then
			return
		end

		local currentPlotValue = player:FindFirstChild("CurrentPlot")
		if not currentPlotValue or currentPlotValue.Value == "" then
			return
		end

		attachListenersForPlayer(player)
		playerInitialized[player.UserId] = true
	end

	if not player:FindFirstChild("CurrentPlot") then
		local childAddedConn
		childAddedConn = player.ChildAdded:Connect(function(child)
			if child.Name == "CurrentPlot" then
				task.defer(function()
					initializePlayer()
				end)
				if childAddedConn then
					childAddedConn:Disconnect()
				end
			end
		end)

		if not playerTroves[player] then
			playerTroves[player] = Trove.new()
		end
		playerTroves[player]:Add(childAddedConn)
	else
		task.defer(function()
			initializePlayer()
		end)
	end
end)

mainTrove:Connect(Players.PlayerRemoving, function(player)
	if playerTroves[player] then
		playerTroves[player]:Destroy()
		playerTroves[player] = nil
	end
	playerInitialized[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	ensurePlayerShakersFolder(player)
	playerInitialized[player.UserId] = false

	if player:FindFirstChild("CurrentPlot") and player.CurrentPlot.Value ~= "" then
		attachListenersForPlayer(player)
		playerInitialized[player.UserId] = true
	end
end
