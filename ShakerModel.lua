local Workspace = game:GetService("Workspace")

local ShakerModel = {}

local plotsFolder = Workspace:WaitForChild("Plots")

function ShakerModel.GetPlotShakersFolder(player)
	local currentPlotValue = player:FindFirstChild("CurrentPlot")
	if not currentPlotValue then return nil end

	local plotNumber = currentPlotValue.Value
	if plotNumber == "" then return nil end

	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
	if not plotFolder then return nil end

	return plotFolder:FindFirstChild("Shakers")
end

function ShakerModel.GetShakerFolder(player, shakerNumber)
	local plotShakers = ShakerModel.GetPlotShakersFolder(player)
	if not plotShakers then return nil end

	return plotShakers:FindFirstChild(tostring(shakerNumber))
end

function ShakerModel.GetCurrentShakerModel(player, shakerNumber)
	-- For backwards compatibility, returns the shaker folder
	return ShakerModel.GetShakerFolder(player, shakerNumber)
end

function ShakerModel.GetContentPart(shakerFolder)
	if not shakerFolder then return nil end

	local ingredientsFolder = shakerFolder:FindFirstChild("Ingredients")
	if not ingredientsFolder then return nil end

	return ingredientsFolder:FindFirstChild("Content")
end

function ShakerModel.GetModelFolder(shakerFolder)
	if not shakerFolder then return nil end
	return shakerFolder:FindFirstChild("Model")
end

function ShakerModel.GetInfoBillboard(shakerFolder)
	if not shakerFolder then return nil end

	local infoFolder = shakerFolder:FindFirstChild("Info")
	if not infoFolder then return nil end

	return infoFolder:FindFirstChild("BillboardGui")
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
