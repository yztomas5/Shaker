--[[
	ShakerInput - Manejo de input del mouse para el shaker
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ShakerInput = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local plotsFolder = Workspace:WaitForChild("Plots")

local trove = nil
local onClickCallback = nil
local onHoverCallback = nil
local onHoverLeaveCallback = nil

------------------------------------------------------------------------
-- UTILIDADES
------------------------------------------------------------------------

local function getCurrentPlotNumber()
	local currentPlot = player:FindFirstChild("CurrentPlot")
	if currentPlot and currentPlot.Value ~= "" then
		return currentPlot.Value
	end
	return nil
end

local function getShakerFolder()
	local plotNumber = getCurrentPlotNumber()
	if not plotNumber then return nil end

	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
	if not plotFolder then return nil end

	return plotFolder:FindFirstChild("Shakers")
end

function ShakerInput.getContentPart()
	local shakerFolder = getShakerFolder()
	if not shakerFolder then return nil end

	local ingredientsFolder = shakerFolder:FindFirstChild("Ingredients")
	if not ingredientsFolder then return nil end

	return ingredientsFolder:FindFirstChild("Content")
end

function ShakerInput.getShakerModel()
	local shakerFolder = getShakerFolder()
	if not shakerFolder then return nil end

	local modelFolder = shakerFolder:FindFirstChild("Model")
	if not modelFolder then return nil end

	for _, child in ipairs(modelFolder:GetChildren()) do
		if child:IsA("Model") then
			return child
		end
	end
	return nil
end

function ShakerInput.getShakerFolder()
	return getShakerFolder()
end

function ShakerInput.getCurrentPlotNumber()
	return getCurrentPlotNumber()
end

------------------------------------------------------------------------
-- DETECCIÓN DE PARTES
------------------------------------------------------------------------

local function isPartOfShakerModel(part)
	local shakerFolder = getShakerFolder()
	if not shakerFolder then return false end

	local touchPart = shakerFolder:FindFirstChild("TouchPart")
	if touchPart and (part == touchPart or part:IsDescendantOf(touchPart)) then
		return false
	end

	local removePart = shakerFolder:FindFirstChild("RemovePart")
	if removePart and (part == removePart or part:IsDescendantOf(removePart)) then
		return false
	end

	local current = part
	while current and current ~= Workspace do
		if current == shakerFolder then
			return true
		end
		current = current.Parent
	end
	return false
end

------------------------------------------------------------------------
-- TOOL DETECTION
------------------------------------------------------------------------

function ShakerInput.getEquippedTool()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChildOfClass("Tool")
end

function ShakerInput.isIngredientTool(tool)
	if not tool then return false end
	local typeValue = tool:FindFirstChild("Type")
	return typeValue and typeValue:IsA("StringValue") and typeValue.Value == "Ingredient"
end

function ShakerInput.isEnergizingTool(tool)
	if not tool then return false end
	return tool.Name:find("Energizing") ~= nil
end

function ShakerInput.hasValidTool()
	local tool = ShakerInput.getEquippedTool()
	return tool and (ShakerInput.isIngredientTool(tool) or ShakerInput.isEnergizingTool(tool))
end

------------------------------------------------------------------------
-- SETUP
------------------------------------------------------------------------

function ShakerInput.setup(inputTrove, callbacks)
	trove = inputTrove
	onClickCallback = callbacks.onClick
	onHoverCallback = callbacks.onHover
	onHoverLeaveCallback = callbacks.onHoverLeave

	-- Hover detection - simple hover independiente de estados
	local isHovering = false

	trove:Connect(RunService.RenderStepped, function()
		local target = mouse.Target
		local shouldHover = target and isPartOfShakerModel(target)

		if shouldHover and not isHovering then
			isHovering = true
			if onHoverCallback then
				onHoverCallback()
			end
		elseif not shouldHover and isHovering then
			isHovering = false
			if onHoverLeaveCallback then
				onHoverLeaveCallback()
			end
		end
	end)

	-- Click detection
	trove:Connect(mouse.Button1Down, function()
		local target = mouse.Target
		if not target then return end

		local plotNumber = getCurrentPlotNumber()
		if not plotNumber then return end

		if isPartOfShakerModel(target) then
			if onClickCallback then
				onClickCallback(plotNumber)
			end
		end
	end)
end

function ShakerInput.cleanup()
	trove = nil
	onClickCallback = nil
	onHoverCallback = nil
	onHoverLeaveCallback = nil
end

return ShakerInput
