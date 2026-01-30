--[[
	ShakerClientController - Controlador principal del cliente
	Coordina todos los módulos del cliente
	Usa Trove para limpieza automática
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Modules.Data.Trove)

local ShakerSystem = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"):WaitForChild("ShakerSystem")
local ShakerUI = require(ShakerSystem.ShakerUI)
local ShakerInput = require(ShakerSystem.ShakerInput)
local ShakerButton = require(ShakerSystem.ShakerButton)
local ShakerEffects = require(ShakerSystem.ShakerEffects)
local ShakerPopup = require(ShakerSystem.ShakerPopup)
local ShakerConfig = require(ShakerSystem.ShakerConfig)

local ShakerClientController = {}

local player = Players.LocalPlayer
local plotsFolder = Workspace:WaitForChild("Plots")

-- RemoteEvents
local shakersFolder = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Shakers")
local StartMixingEvent = shakersFolder:WaitForChild("StartMixing")
local StopMixingEvent = shakersFolder:WaitForChild("StopMixing")
local UpdateProgressEvent = shakersFolder:WaitForChild("UpdateProgress")
local CompleteMixingEvent = shakersFolder:WaitForChild("CompleteMixing")
local ShakerClickEvent = shakersFolder:WaitForChild("ShakerClick")
local TouchPartClickEvent = shakersFolder:WaitForChild("TouchPartClick")
local CancelMixingEvent = shakersFolder:WaitForChild("CancelMixing")
local IngredientAddedEvent = shakersFolder:WaitForChild("IngredientAdded")
local IngredientRemovedEvent = shakersFolder:WaitForChild("IngredientRemoved")
local EnergizingAddedEvent = shakersFolder:WaitForChild("EnergizingAdded")

-- Troves
local mainTrove = nil
local plotTrove = nil

-- State
local currentTouchPart = nil
local currentRemovePart = nil

------------------------------------------------------------------------
-- CLEANUP
------------------------------------------------------------------------

local function cleanupAll()
	ShakerUI.cleanup()
	ShakerEffects.cleanup()
	ShakerPopup.forceClose()

	currentTouchPart = nil
	currentRemovePart = nil
end

------------------------------------------------------------------------
-- BUTTON HANDLERS
------------------------------------------------------------------------

local function onTouchPartClick()
	local plotNumber = ShakerInput.getCurrentPlotNumber()
	if not plotNumber then return end

	if currentTouchPart then
		ShakerButton.lock(currentTouchPart)
		task.delay(ShakerConfig.TOUCH_COOLDOWN, function()
			if currentTouchPart and ShakerUI.isActive() then
				ShakerButton.unlock(currentTouchPart)
			end
		end)
	end

	TouchPartClickEvent:FireServer(plotNumber)
end

local function onRemovePartClick()
	ShakerPopup.open(function()
		local plotNumber = ShakerInput.getCurrentPlotNumber()
		if plotNumber then
			CancelMixingEvent:FireServer(plotNumber)
		end
	end)
end

------------------------------------------------------------------------
-- BUTTON STATE
------------------------------------------------------------------------

local function lockButtons()
	if currentTouchPart then
		ShakerButton.lock(currentTouchPart)
	end
	if currentRemovePart then
		ShakerButton.lock(currentRemovePart)
	end
end

local function unlockButtons()
	if currentTouchPart then
		ShakerButton.unlock(currentTouchPart)
	end
	if currentRemovePart then
		ShakerButton.unlock(currentRemovePart)
	end
end

------------------------------------------------------------------------
-- EVENT HANDLERS
------------------------------------------------------------------------

local function setupEvents()
	mainTrove:Connect(StartMixingEvent.OnClientEvent, function(mixedColor)
		local contentPart = ShakerInput.getContentPart()
		if not contentPart then return end

		local playerShakers = player:FindFirstChild("Shakers")
		if not playerShakers then return end

		local ingredientNames = {}
		for _, folder in ipairs(playerShakers:GetChildren()) do
			if folder:IsA("Folder") then
				table.insert(ingredientNames, folder.Name)
			end
		end

		if #ingredientNames == 0 then return end

		ShakerEffects.StartShakeEffects(contentPart, mixedColor)
		ShakerUI.startEffects(contentPart, ingredientNames, mixedColor)
		unlockButtons()
	end)

	mainTrove:Connect(StopMixingEvent.OnClientEvent, function()
		local contentPart = ShakerInput.getContentPart()
		if contentPart then
			ShakerEffects.StopShakeEffects()
			ShakerEffects.PlayRemoveIngredientSound(contentPart)
		end
		ShakerUI.stopEffects()
		lockButtons()
	end)

	mainTrove:Connect(CompleteMixingEvent.OnClientEvent, function(mixedColor)
		ShakerEffects.StopShakeEffects()
		ShakerUI.stopEffects()
		lockButtons()
		-- Limpiar highlight al completar
		ShakerUI.clearHighlight()
	end)

	mainTrove:Connect(IngredientAddedEvent.OnClientEvent, function(ingredientColor)
		local contentPart = ShakerInput.getContentPart()
		if contentPart then
			ShakerEffects.PlayAddIngredientSound(contentPart)
			if ingredientColor then
				ShakerEffects.PlayAddIngredientBubbles(contentPart, ingredientColor)
			end
		end
	end)

	mainTrove:Connect(IngredientRemovedEvent.OnClientEvent, function()
		local contentPart = ShakerInput.getContentPart()
		if contentPart then
			ShakerEffects.PlayRemoveIngredientSound(contentPart)
		end
	end)

	mainTrove:Connect(EnergizingAddedEvent.OnClientEvent, function(xpAdded, energizerName)
		local contentPart = ShakerInput.getContentPart()
		if not contentPart then return end

		if energizerName == "Energizing" then
			ShakerEffects.PlayEnergizingSound(contentPart)
		elseif energizerName == "Mid Energizing" then
			ShakerEffects.PlayMidEnergizingSound(contentPart)
		elseif energizerName == "Big Energizing" then
			ShakerEffects.PlayBigEnergizingSound(contentPart)
		else
			ShakerEffects.PlayEnergizingSound(contentPart)
		end

		ShakerUI.flashParts(Color3.fromRGB(255, 255, 150))
	end)
end

------------------------------------------------------------------------
-- PLOT SETUP
------------------------------------------------------------------------

local function loadPlot(plotName)
	-- Limpiar plot anterior
	if plotTrove then
		plotTrove:Destroy()
		plotTrove = nil
	end

	cleanupAll()

	if not plotName or plotName == "" then
		return
	end

	local plotFolder = plotsFolder:FindFirstChild(plotName)
	if not plotFolder then return end

	local shakerFolder = plotFolder:FindFirstChild("Shakers")
	if not shakerFolder then return end

	plotTrove = mainTrove:Extend()

	-- Setup TouchPart (nunca se bloquea)
	local touchPart = shakerFolder:FindFirstChild("TouchPart")
	if touchPart then
		currentTouchPart = touchPart
		ShakerButton.setup(touchPart, plotTrove, onTouchPartClick)
	end

	-- Setup RemovePart (bloqueado hasta que haya mezcla activa)
	local removePart = shakerFolder:FindFirstChild("RemovePart")
	if removePart then
		currentRemovePart = removePart
		ShakerButton.setup(removePart, plotTrove, onRemovePartClick)
		ShakerButton.lock(removePart)
	end

	-- Setup input
	ShakerInput.setup(plotTrove, {
		onClick = function(plotNumber)
			ShakerClickEvent:FireServer(plotNumber)
		end,
		onHover = function()
			local model = ShakerInput.getShakerModel()
			if model then
				ShakerUI.applyHighlight(model)
			end
		end,
		onHoverLeave = function()
			ShakerUI.clearHighlight()
		end
	})

	-- Cleanup cuando se destruye el plot trove
	plotTrove:Add(function()
		cleanupAll()
	end)
end

local function setupPlotWatcher()
	local currentPlotValue = player:WaitForChild("CurrentPlot", 10)
	if not currentPlotValue then return end

	if currentPlotValue.Value ~= "" then
		task.wait(0.3)
		loadPlot(currentPlotValue.Value)
	end

	mainTrove:Connect(currentPlotValue:GetPropertyChangedSignal("Value"), function()
		task.wait(0.2)
		loadPlot(currentPlotValue.Value)
	end)
end

------------------------------------------------------------------------
-- INIT
------------------------------------------------------------------------

function ShakerClientController.init()
	mainTrove = Trove.new()

	ShakerPopup.init()
	setupEvents()
	setupPlotWatcher()
end

function ShakerClientController.destroy()
	if plotTrove then
		plotTrove:Destroy()
		plotTrove = nil
	end

	if mainTrove then
		mainTrove:Destroy()
		mainTrove = nil
	end

	cleanupAll()
end

return ShakerClientController
