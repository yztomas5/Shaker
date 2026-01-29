local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local plotsFolder = Workspace:WaitForChild("Plots")

-- ShakerHandler simplified - shakers no longer change based on rebirths
-- The shaker structure is now directly in plot's Shakers folder

local function getPlotOwner(plotName)
	for _, player in ipairs(Players:GetPlayers()) do
		local currentPlot = player:FindFirstChild("CurrentPlot")
		if currentPlot and currentPlot.Value == plotName then
			return player
		end
	end
	return nil
end

_G.GetPlotOwner = getPlotOwner
