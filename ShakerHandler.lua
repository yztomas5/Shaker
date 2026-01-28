local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("Trove"))

local shakerFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Models"):WaitForChild("Plot"):WaitForChild("Shakers")
local noPlayerModel = shakerFolder:WaitForChild("NoPlayer")

local plotsFolder = Workspace:WaitForChild("Plots")

local plotOwners = {}

local mainTrove = Trove.new()
local playerTroves = {}
local plotTroves = {}

local function clearShakers(plotModel)
	if not plotModel then return end

	local shakersFolder = plotModel:FindFirstChild("Shakers")
	if not shakersFolder then return end

	for _, child in ipairs(shakersFolder:GetChildren()) do
		if child.Name ~= "Position" and child ~= shakersFolder:FindFirstChild("Position") then
			child:Destroy()
		end
	end
end

local function findClosestShakerModel(rebirthValue)
	local closestModel = nil
	local closestRebirth = -1

	for _, model in ipairs(shakerFolder:GetChildren()) do
		local modelRebirth = tonumber(model.Name)

		if modelRebirth then
			if modelRebirth == rebirthValue then
				return model
			end

			if modelRebirth <= rebirthValue and modelRebirth > closestRebirth then
				closestRebirth = modelRebirth
				closestModel = model
			end
		end
	end

	if not closestModel then
		closestModel = shakerFolder:FindFirstChild("0")
	end

	return closestModel
end

local function cloneAndPositionShaker(template, plotModel)
	if not template or not plotModel then return end

	local shakersFolder = plotModel:FindFirstChild("Shakers")
	if not shakersFolder then return end

	local positionPart = shakersFolder:FindFirstChild("Position")
	if not positionPart then return end

	clearShakers(plotModel)

	local clone = template:Clone()

	local targetCFrame = positionPart.CFrame

	if clone:IsA("Model") then
		clone:PivotTo(targetCFrame)

	elseif clone:IsA("BasePart") then
		clone.CFrame = targetCFrame
	end

	clone.Parent = shakersFolder

	return clone
end

local function updatePlotShaker(plotName, player)
	if not plotName or plotName == "" then return end

	local plotModel = plotsFolder:FindFirstChild(plotName)
	if not plotModel then return end

	local isBusyValue = plotModel:FindFirstChild("isBusy")

	if not player or (isBusyValue and isBusyValue:IsA("BoolValue") and not isBusyValue.Value) then
		cloneAndPositionShaker(noPlayerModel, plotModel)
		return
	end

	local dataFolder = player:FindFirstChild("Data")
	if not dataFolder then
		cloneAndPositionShaker(noPlayerModel, plotModel)
		return
	end

	local rebirthValue = dataFolder:FindFirstChild("Rebirth")
	if not rebirthValue or not rebirthValue:IsA("IntValue") then
		cloneAndPositionShaker(noPlayerModel, plotModel)
		return
	end

	local shakerModel = findClosestShakerModel(rebirthValue.Value)

	if shakerModel then
		cloneAndPositionShaker(shakerModel, plotModel)
	else
		cloneAndPositionShaker(noPlayerModel, plotModel)
	end
end

function getPlotOwner(plotName)
	return plotOwners[plotName]
end

local function setupPlotWatcher(plotModel)
	local plotName = plotModel.Name

	if not plotTroves[plotName] then
		plotTroves[plotName] = Trove.new()
	end
	local plotTrove = plotTroves[plotName]

	local isBusyValue = plotModel:FindFirstChild("isBusy")
	if not isBusyValue or not isBusyValue:IsA("BoolValue") then return end

	plotTrove:Connect(isBusyValue:GetPropertyChangedSignal("Value"), function()
		local owner = plotOwners[plotName]
		updatePlotShaker(plotName, owner)
	end)
end

local function setupPlayerWatcher(player)
	if not playerTroves[player] then
		playerTroves[player] = Trove.new()
	end
	local playerTrove = playerTroves[player]

	local currentPlotValue = player:WaitForChild("CurrentPlot", 10)
	if not currentPlotValue or not currentPlotValue:IsA("StringValue") then return end

	local dataFolder = player:WaitForChild("Data", 10)
	local rebirthValue

	if dataFolder then
		rebirthValue = dataFolder:WaitForChild("Rebirth", 10)
	end

	local function updatePlayer()
		local plotName = currentPlotValue.Value

		for oldPlotName, oldPlayer in pairs(plotOwners) do
			if oldPlayer == player and oldPlotName ~= plotName then
				plotOwners[oldPlotName] = nil
				updatePlotShaker(oldPlotName, nil)
			end
		end

		if plotName ~= "" then
			plotOwners[plotName] = player
			updatePlotShaker(plotName, player)
		end
	end

	playerTrove:Connect(currentPlotValue:GetPropertyChangedSignal("Value"), updatePlayer)

	if rebirthValue and rebirthValue:IsA("IntValue") then
		playerTrove:Connect(rebirthValue:GetPropertyChangedSignal("Value"), function()
			local plotName = currentPlotValue.Value
			if plotName ~= "" then
				updatePlotShaker(plotName, player)
			end
		end)
	end

	if currentPlotValue.Value ~= "" then
		updatePlayer()
	end
end

local function onPlayerRemoving(player)
	for plotName, owner in pairs(plotOwners) do
		if owner == player then
			plotOwners[plotName] = nil
			updatePlotShaker(plotName, nil)
		end
	end

	if playerTroves[player] then
		playerTroves[player]:Destroy()
		playerTroves[player] = nil
	end
end

mainTrove:Connect(Players.PlayerAdded, setupPlayerWatcher)
mainTrove:Connect(Players.PlayerRemoving, onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		setupPlayerWatcher(player)
	end)
end

for _, plotModel in ipairs(plotsFolder:GetChildren()) do
	task.spawn(function()
		setupPlotWatcher(plotModel)
	end)
end

_G.GetPlotOwner = getPlotOwner