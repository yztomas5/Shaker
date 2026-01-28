local Workspace = game:GetService("Workspace")

local ShakerModel = {}

local plotsFolder = Workspace:WaitForChild("Plots")

function ShakerModel.GetCurrentShakerModel(player, shakerNumber)
	local currentPlotValue = player:FindFirstChild("CurrentPlot")
	if not currentPlotValue then return nil end

	local plotNumber = currentPlotValue.Value
	if plotNumber == "" then return nil end

	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
	if not plotFolder then return nil end

	local plotShakersRoot = plotFolder:FindFirstChild("Shakers")
	if not plotShakersRoot then return nil end

	local modelInside = plotShakersRoot:FindFirstChildWhichIsA("Model")
	if not modelInside then return nil end

	local realShakersFolder = modelInside:FindFirstChild("Shakers")
	if not realShakersFolder then return nil end

	return realShakersFolder:FindFirstChild(tostring(shakerNumber))
end

function ShakerModel.GetContentPart(shakerModel)
	if not shakerModel then return nil end

	local juicesFolder = shakerModel:FindFirstChild("Juices")
	if not juicesFolder then return nil end

	local contentPart = juicesFolder:FindFirstChild("Content")
	return contentPart
end

function ShakerModel.GetPlayerForPlot(plotNumber)
	local Players = game:GetService("Players")
	for _, player in ipairs(Players:GetPlayers()) do
		local currentPlot = player:FindFirstChild("CurrentPlot")
		if currentPlot and currentPlot.Value == plotNumber then
			return player
		end
	end
	return nil
end

return ShakerModel