local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("Trove"))

local plotsFolder = Workspace:WaitForChild("Plots")

local mainTrove = Trove.new()
local playerTroves = {}

local function clearAllShakerPartsInstantly(player, shakerNumber)
	local currentPlotValue = player:FindFirstChild("CurrentPlot")
	if not currentPlotValue then return end

	local plotNumber = currentPlotValue.Value
	if plotNumber == "" then return end

	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
	if not plotFolder then return end

	local plotShakersRoot = plotFolder:FindFirstChild("Shakers")
	if not plotShakersRoot then return end

	local shakersFolder = plotShakersRoot:FindFirstChild(tostring(shakerNumber))
	if not shakersFolder then return end

	local ingredientsFolder = shakersFolder:FindFirstChild("Ingredients")
	if not ingredientsFolder then return end

	local contentPart = ingredientsFolder:FindFirstChild("Content")
	if not contentPart or not contentPart:IsA("BasePart") then return end

	for _, child in ipairs(contentPart:GetChildren()) do
		if child:IsA("BasePart") and child.Name ~= "Content" and string.find(child.Name, "Layer_") then
			child:Destroy()
		end
	end
end

local function updateShakerJuices(player, shakerNumber)
	-- Visual effects are now handled client-side via ShakerEffectsClient.lua
end

mainTrove:Connect(Players.PlayerAdded, function(player)
	playerTroves[player] = Trove.new()
end)

mainTrove:Connect(Players.PlayerRemoving, function(player)
	if playerTroves[player] then
		playerTroves[player]:Destroy()
		playerTroves[player] = nil
	end
end)

_G.LoadSystem = _G.LoadSystem or {}
_G.LoadSystem.UpdateShakerJuices = updateShakerJuices
_G.LoadSystem.ClearAllShakerPartsInstantly = clearAllShakerPartsInstantly
