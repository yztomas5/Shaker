local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShakerLogic = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"):WaitForChild("ShakerLogic")
local ShakerInventory = require(ShakerLogic:WaitForChild("ShakerInventory"))
local ShakerTool = require(ShakerLogic:WaitForChild("ShakerTool"))
local ShakerManager = require(ShakerLogic:WaitForChild("ShakerManager"))

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
local TOUCH_COOLDOWN = 0.1

local playerTouchCooldowns = {}

local function canPlayerInteract(player)
	local currentTime = tick()
	local cooldownEnd = playerCooldowns[player.UserId]

	if not cooldownEnd then
		return false
	end

	return currentTime >= cooldownEnd
end

local function canPlayerTouch(player)
	local currentTime = tick()
	local cooldownEnd = playerTouchCooldowns[player.UserId]

	if not cooldownEnd then
		playerTouchCooldowns[player.UserId] = currentTime
		return true
	end

	if currentTime >= cooldownEnd then
		playerTouchCooldowns[player.UserId] = currentTime + TOUCH_COOLDOWN
		return true
	end

	return false
end

mainTrove:Connect(Players.PlayerAdded, function(player)
	playerCooldowns[player.UserId] = tick() + COOLDOWN_TIME
	playerTouchCooldowns[player.UserId] = tick()
end)

mainTrove:Connect(Players.PlayerRemoving, function(player)
	playerCooldowns[player.UserId] = nil
	playerTouchCooldowns[player.UserId] = nil
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
		prompt.ActionText = "Cancel"
		prompt.Enabled = true
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

	if ingredientCount > 0 and not isShakeActive then
		prompt.ActionText = "Remove (" .. ingredientCount .. "/" .. MAX_INGREDIENTS .. ")"
		prompt.Enabled = true
		return
	end

	prompt.Enabled = false
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
		local xpIncreasePercentage = nil

		if toolName == "Energizing" then
			xpIncreasePercentage = 0.10
		elseif toolName == "Mid Energizing" then
			xpIncreasePercentage = 0.25
		elseif toolName == "Big Energizing" then
			xpIncreasePercentage = 0.50
		end

		if xpIncreasePercentage then
			local toolId = ShakerTool.GetToolId(tool)
			if not toolId then return end

			local energizingFolder = ShakerInventory.FindGearInPlayerInventory(player, toolName, toolId)
			if energizingFolder then
				tool:Destroy()
				energizingFolder:Destroy()
				task.wait(0.1)

				ShakerManager.IncreaseRequiredXp(player, shakerNumber, xpIncreasePercentage)
			end
			return
		end
	end

	if isShakeActive then
		ShakerManager.CancelShake(player, shakerNumber)
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
				ShakerManager.StartShake(player, shakerNumber)
			end
		end
	elseif ingredientCount > 0 then
		if ShakerInventory.RemoveIngredient(player, shakerNumber) then
			local newCount = ShakerInventory.CountIngredients(player, shakerNumber)
			if newCount == 0 then
				ShakerManager.StopShake(player, shakerNumber)
			else
				ShakerManager.RecalculateRequiredXp(player, shakerNumber)
			end
		end
	end
end

local function handleTouchPart(player, shakerNumber, plotNumber)
	if not canPlayerTouch(player) then
		return
	end

	if player:FindFirstChild("CurrentPlot") and player.CurrentPlot.Value ~= plotNumber then
		return
	end

	if not ShakerManager.IsShakeActive(player, shakerNumber) then
		return
	end

	ShakerManager.AddXp(player, shakerNumber, 1)
end

local function getPlotShakersFolder(plotNumber)
	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
	if not plotFolder then return nil end
	return plotFolder:FindFirstChild("Shakers")
end

local function setupShakerPrompts(shakersFolder, shakerNumber, plotNumber)
	local addPart = shakersFolder:FindFirstChild("Add")
	local touchPart = shakersFolder:FindFirstChild("TouchPart")

	if not addPart then
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

	shakerTrove:Connect(addRemovePrompt.Triggered, function(player)
		handleAddRemove(player, shakerNumber, plotNumber)
	end)

	if touchPart then
		shakerTrove:Connect(touchPart.Touched, function(hit)
			local character = hit.Parent
			if not character then return end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end

			local player = Players:GetPlayerFromCharacter(character)
			if not player then return end

			handleTouchPart(player, shakerNumber, plotNumber)
		end)
	end

	shakerTrove:Connect(RunService.Heartbeat, function()
		if not shakersFolder.Parent or not addPart.Parent then
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

					if distanceToAdd <= 10 then
						updateAddRemovePrompt(addRemovePrompt, player, shakerNumber)
					end
				end
			end
		end
	end)
end

local function monitorShakersFolder(plotShakersFolder, plotNumber)
	local plotKey = "monitor_" .. plotNumber
	if not plotTroves[plotKey] then
		plotTroves[plotKey] = Trove.new()
	end
	local plotTrove = plotTroves[plotKey]

	for _, shakerFolder in ipairs(plotShakersFolder:GetChildren()) do
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				task.spawn(function()
					setupShakerPrompts(shakerFolder, shakerNumber, plotNumber)
				end)
			end
		end
	end

	plotTrove:Connect(plotShakersFolder.ChildAdded, function(shakerFolder)
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				task.spawn(function()
					setupShakerPrompts(shakerFolder, shakerNumber, plotNumber)
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

	monitorShakersFolder(plotShakersRoot, plotNumber)
end

for _, player in ipairs(Players:GetPlayers()) do
	playerCooldowns[player.UserId] = tick() + COOLDOWN_TIME
	playerTouchCooldowns[player.UserId] = tick()
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
