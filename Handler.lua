local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShakerLogic = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"):WaitForChild("ShakerLogic")
local ShakerInventory = require(ShakerLogic:WaitForChild("ShakerInventory"))
local ShakerEffects = require(ShakerLogic:WaitForChild("ShakerEffects"))
local ShakerTool = require(ShakerLogic:WaitForChild("ShakerTool"))
local ShakerManager = require(ShakerLogic:WaitForChild("ShakerManager"))
local ShakerModel = require(ShakerLogic:WaitForChild("ShakerModel"))

local ShakerDataManager = require(script.Parent.ShakerDataManager)

local Trove = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("Trove"))

local plotsFolder = Workspace:WaitForChild("Plots")
local warningEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Warn"):WaitForChild("Warning")
local MAX_INGREDIENTS = 3

local COLOR_ERROR = Color3.fromRGB(255, 0, 0)

local mainTrove = Trove.new()
local playerCooldowns = {}
local plotTroves = {}
local shakerTroves = {}

local COOLDOWN_TIME = 5

local function canPlayerInteract(player)
	local currentTime = tick()
	local cooldownEnd = playerCooldowns[player.UserId]

	if not cooldownEnd then
		return false
	end

	return currentTime >= cooldownEnd
end

mainTrove:Connect(Players.PlayerAdded, function(player)
	playerCooldowns[player.UserId] = tick() + COOLDOWN_TIME

	task.delay(COOLDOWN_TIME, function()
		if player and player.Parent then
		end
	end)
end)

mainTrove:Connect(Players.PlayerRemoving, function(player)
	playerCooldowns[player.UserId] = nil
end)

local function checkInventorySpace(player)
	local dataFolder = player:FindFirstChild("Data")
	if not dataFolder then return true, "" end

	local storageValue = dataFolder:FindFirstChild("Storage")
	if not storageValue or not storageValue:IsA("IntValue") then return true, "" end

	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return true, "" end

	local juicesFolder = inventory:FindFirstChild("Juices")
	if juicesFolder then
		local juiceCount = 0
		for _, child in ipairs(juicesFolder:GetChildren()) do
			if child:IsA("Folder") then
				juiceCount = juiceCount + 1
			end
		end

		if juiceCount >= storageValue.Value then
			local msg = "Juice inventory is full (" .. juiceCount .. "/" .. storageValue.Value .. ")"
			return false, msg
		end
	end

	local ingredientsFolder = inventory:FindFirstChild("Ingredients")
	if ingredientsFolder then
		local ingredientCount = 0
		for _, child in ipairs(ingredientsFolder:GetChildren()) do
			if child:IsA("Folder") then
				ingredientCount = ingredientCount + 1
			end
		end

		if ingredientCount >= storageValue.Value then
			local msg = "Ingredient inventory is full (" .. ingredientCount .. "/" .. storageValue.Value .. ")"
			return false, msg
		end
	end

	return true, ""
end

local function updateAddRemovePrompt(prompt, player, shakerNumber)
	if not canPlayerInteract(player) then
		prompt.Enabled = false
		return
	end

	local character = player.Character
	if not character then
		prompt.Enabled = false
		return
	end

	local tool = ShakerTool.GetEquippedTool(character)
	local ingredientCount = ShakerInventory.CountIngredients(player, shakerNumber)
	local isShakeActive = ShakerManager.IsShakeActive(player, shakerNumber)

	if isShakeActive and tool then
		local toolName = tool.Name
		if toolName == "Energizing" or toolName == "Mid Energizing" or toolName == "Big Energizing" then
			local toolId = ShakerTool.GetToolId(tool)
			if toolId then
				local energizingFolder = ShakerInventory.FindGearInPlayerInventory(player, toolName, toolId)
				if energizingFolder then
					prompt.ActionText = "Add " .. toolName
					prompt.Enabled = true
					return
				end
			end
		end
	end

	if isShakeActive then
		prompt.Enabled = false
		return
	end

	if tool and ShakerTool.IsIngredientTool(tool) and ingredientCount < MAX_INGREDIENTS then
		local toolId = ShakerTool.GetToolId(tool)
		if toolId then
			local ingredientFolder = ShakerInventory.FindIngredientInPlayerInventory(player, tool.Name, toolId)
			if ingredientFolder then
				prompt.ActionText = "Add (" .. ingredientCount .. "/" .. MAX_INGREDIENTS .. ")"
				prompt.Enabled = true
				return
			end
		end
	end

	if ingredientCount > 0 then
		prompt.ActionText = "Remove (" .. ingredientCount .. "/" .. MAX_INGREDIENTS .. ")"
		prompt.Enabled = true
		return
	end

	prompt.Enabled = false
end

local function updateStartPrompt(prompt, player, shakerNumber)
	if not canPlayerInteract(player) then
		prompt.Enabled = false
		return
	end

	if ShakerManager.IsShakeActive(player, shakerNumber) then
		prompt.ActionText = "Cancel"
		prompt.Enabled = true
		return
	end

	local ingredientCount = ShakerInventory.CountIngredients(player, shakerNumber)
	if ingredientCount > 0 then
		prompt.ActionText = "Start"
		prompt.Enabled = true
	else
		prompt.Enabled = false
	end
end

local function handleAddRemove(player, shakerNumber, plotNumber)
	if not canPlayerInteract(player) then
		return
	end

	if player:FindFirstChild("CurrentPlot") and player.CurrentPlot.Value ~= plotNumber then
		return
	end

	local character = player.Character
	if not character then return end

	local tool = ShakerTool.GetEquippedTool(character)
	local isShakeActive = ShakerManager.IsShakeActive(player, shakerNumber)

	if isShakeActive and tool then
		local toolName = tool.Name
		local reductionPercentage = nil

		if toolName == "Energizing" then
			reductionPercentage = 0.25
		elseif toolName == "Mid Energizing" then
			reductionPercentage = 0.50
		elseif toolName == "Big Energizing" then
			reductionPercentage = 1.00
		end

		if reductionPercentage then
			local toolId = ShakerTool.GetToolId(tool)
			if not toolId then return end

			local energizingFolder = ShakerInventory.FindGearInPlayerInventory(player, toolName, toolId)
			if energizingFolder then
				tool:Destroy()
				energizingFolder:Destroy()
				task.wait(0.1)

				ShakerManager.ReduceShakeTime(player, shakerNumber, reductionPercentage)

				local shakerModel = ShakerModel.GetCurrentShakerModel(player, shakerNumber)
				if shakerModel then
					local contentPart = ShakerModel.GetContentPart(shakerModel)
					if contentPart then
						if toolName == "Energizing" then
							ShakerEffects.PlayEnergizingSound(contentPart)
						elseif toolName == "Mid Energizing" then
							ShakerEffects.PlayMidEnergizingSound(contentPart)
						elseif toolName == "Big Energizing" then
							ShakerEffects.PlayBigEnergizingSound(contentPart)
						end
					end
				end

				local percentText = math.floor(reductionPercentage * 100)
			end
			return
		end
	end

	if isShakeActive then
		return
	end

	local ingredientCount = ShakerInventory.CountIngredients(player, shakerNumber)
	local shouldAdd = tool 
		and ShakerTool.IsIngredientTool(tool) 
		and ingredientCount < MAX_INGREDIENTS

	if shouldAdd then
		local hasSpace, errorMsg = checkInventorySpace(player)
		if not hasSpace then
			warningEvent:FireClient(player, errorMsg, COLOR_ERROR)
			return
		end

		local toolId = ShakerTool.GetToolId(tool)
		if not toolId then return end

		local ingredientFolder = ShakerInventory.FindIngredientInPlayerInventory(player, tool.Name, toolId)
		if ingredientFolder then
			local ingredientName = tool.Name
			tool:Destroy()
			task.wait(0.1)

			if ShakerInventory.AddIngredient(player, shakerNumber, ingredientFolder) then
				local shakerModel = ShakerModel.GetCurrentShakerModel(player, shakerNumber)
				if shakerModel then
					local contentPart = ShakerModel.GetContentPart(shakerModel)
					if contentPart then
						ShakerEffects.PlayAddIngredientSound(contentPart)

						-- Obtener el color del ingrediente y aplicar partículas
						local IngredientConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("IngredientConfig"))
						local ingredientData = IngredientConfig.Ingredients[ingredientName]
						if ingredientData and ingredientData.Color then
							ShakerEffects.PlayAddIngredientBubbles(contentPart, ingredientData.Color)
						end
					end
				end
			end
		end
	elseif ingredientCount > 0 then
		if ShakerInventory.RemoveIngredient(player, shakerNumber) then
			local shakerModel = ShakerModel.GetCurrentShakerModel(player, shakerNumber)
			if shakerModel then
				local contentPart = ShakerModel.GetContentPart(shakerModel)
				if contentPart then
					ShakerEffects.PlayRemoveIngredientSound(contentPart)
				end
			end
		end
	end
end

local function handleStartCancel(player, shakerNumber, plotNumber)
	if not canPlayerInteract(player) then
		return
	end

	if player:FindFirstChild("CurrentPlot") and player.CurrentPlot.Value ~= plotNumber then
		return
	end

	if ShakerManager.IsShakeActive(player, shakerNumber) then
		ShakerManager.CancelShake(player, shakerNumber)
	else
		ShakerManager.StartShake(player, shakerNumber)
	end
end

local function setupShakerPrompts(shakerModel, shakerNumber, plotNumber)
	local addPart = shakerModel:WaitForChild("Add", 5)
	local startPart = shakerModel:WaitForChild("Start", 5)

	if not addPart or not startPart then
		return
	end

	if addPart:FindFirstChild("AddRemovePrompt") then
		return
	end

	local shakerKey = plotNumber .. "_" .. shakerNumber
	if shakerTroves[shakerKey] then
		shakerTroves[shakerKey]:Destroy()
	end
	shakerTroves[shakerKey] = Trove.new()
	local shakerTrove = shakerTroves[shakerKey]

	local addRemovePrompt = Instance.new("ProximityPrompt")
	addRemovePrompt.Name = "AddRemovePrompt"
	addRemovePrompt.ActionText = "Interact"
	addRemovePrompt.ObjectText = ""
	addRemovePrompt.HoldDuration = 0.5
	addRemovePrompt.MaxActivationDistance = 10
	addRemovePrompt.RequiresLineOfSight = false
	addRemovePrompt.Style = Enum.ProximityPromptStyle.Custom
	addRemovePrompt.Enabled = false
	addRemovePrompt.Parent = addPart
	shakerTrove:Add(addRemovePrompt)

	local startPrompt = Instance.new("ProximityPrompt")
	startPrompt.Name = "StartPrompt"
	startPrompt.ActionText = "Start"
	startPrompt.ObjectText = ""
	startPrompt.HoldDuration = 1
	startPrompt.MaxActivationDistance = 10
	startPrompt.RequiresLineOfSight = false
	startPrompt.Style = Enum.ProximityPromptStyle.Custom
	startPrompt.Enabled = false
	startPrompt.Parent = startPart
	shakerTrove:Add(startPrompt)

	if startPart:IsA("BasePart") then
		startPart.Color = Color3.fromRGB(0, 255, 0)
	end

	shakerTrove:Connect(addRemovePrompt.Triggered, function(player)
		handleAddRemove(player, shakerNumber, plotNumber)
	end)

	shakerTrove:Connect(startPrompt.Triggered, function(player)
		handleStartCancel(player, shakerNumber, plotNumber)
	end)

	shakerTrove:Connect(RunService.Heartbeat, function()
		if not shakerModel.Parent or not addPart.Parent then
			if shakerTroves[shakerKey] then
				shakerTroves[shakerKey]:Destroy()
				shakerTroves[shakerKey] = nil
			end
			return
		end

		for _, player in ipairs(Players:GetPlayers()) do
			if player:FindFirstChild("CurrentPlot") and player.CurrentPlot.Value == plotNumber then
				local character = player.Character
				if character and character:FindFirstChild("HumanoidRootPart") then
					local distanceToAdd = (character.HumanoidRootPart.Position - addPart.Position).Magnitude
					local distanceToStart = (character.HumanoidRootPart.Position - startPart.Position).Magnitude

					if distanceToAdd <= 10 then
						updateAddRemovePrompt(addRemovePrompt, player, shakerNumber)
					end

					if distanceToStart <= 10 then
						updateStartPrompt(startPrompt, player, shakerNumber)
					end
				end
			end
		end
	end)
end

local function monitorShakersFolder(realShakersFolder, plotNumber)
	local plotKey = "monitor_" .. plotNumber
	if not plotTroves[plotKey] then
		plotTroves[plotKey] = Trove.new()
	end
	local plotTrove = plotTroves[plotKey]

	for _, shakerModel in ipairs(realShakersFolder:GetChildren()) do
		if shakerModel:IsA("Model") then
			local shakerNumber = tonumber(shakerModel.Name)
			if shakerNumber then
				task.spawn(function()
					setupShakerPrompts(shakerModel, shakerNumber, plotNumber)
				end)
			end
		end
	end

	plotTrove:Connect(realShakersFolder.ChildAdded, function(shakerModel)
		if shakerModel:IsA("Model") then
			local shakerNumber = tonumber(shakerModel.Name)
			if shakerNumber then
				task.spawn(function()
					setupShakerPrompts(shakerModel, shakerNumber, plotNumber)
				end)
			end
		end
	end)
end

local function initializePlotShakers(plotFolder)
	local plotNumber = plotFolder.Name

	local plotShakersRoot = plotFolder:FindFirstChild("Shakers")
	if not plotShakersRoot then 
		plotShakersRoot = plotFolder:WaitForChild("Shakers", 10)
		if not plotShakersRoot then
			return
		end
	end

	if plotTroves[plotNumber] then
		plotTroves[plotNumber]:Destroy()
	end
	plotTroves[plotNumber] = Trove.new()
	local plotTrove = plotTroves[plotNumber]

	local currentModel = nil

	local function onModelChanged(newModel)
		if currentModel then
			local player = ShakerModel.GetPlayerForPlot(plotNumber)
			if player then
				ShakerDataManager.SavePlayerShakerData(player)
			end
		end

		currentModel = newModel

		if newModel and newModel:IsA("Model") then
			task.wait(0.5)

			local realShakersFolder = newModel:FindFirstChild("Shakers")
			if realShakersFolder then
				monitorShakersFolder(realShakersFolder, plotNumber)

				local player = ShakerModel.GetPlayerForPlot(plotNumber)
				if player then
					task.wait(0.5)
					ShakerDataManager.RestorePlayerShakerData(player)
				end
			end
		end
	end

	plotTrove:Connect(plotShakersRoot.ChildAdded, function(child)
		if child:IsA("Model") then
			onModelChanged(child)
		end
	end)

	plotTrove:Connect(plotShakersRoot.ChildRemoved, function(child)
		if child:IsA("Model") and child == currentModel then
			local player = ShakerModel.GetPlayerForPlot(plotNumber)
			if player then
				ShakerDataManager.SavePlayerShakerData(player)
			end
			currentModel = nil
		end
	end)

	local modelInside = plotShakersRoot:FindFirstChildWhichIsA("Model")
	if modelInside then
		onModelChanged(modelInside)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	playerCooldowns[player.UserId] = tick() + COOLDOWN_TIME
end

for _, plotFolder in ipairs(plotsFolder:GetChildren()) do
	task.spawn(function()
		initializePlotShakers(plotFolder)
	end)
end

mainTrove:Connect(plotsFolder.ChildAdded, function(plotFolder)
	task.spawn(function()
		task.wait(0.5)
		initializePlotShakers(plotFolder)
	end)
end)