local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("Trove"))
local ShakerInventory = require(script.Parent.ShakerInventory)
local ShakerJuice = require(script.Parent.ShakerJuice)
local ShakerUI = require(script.Parent.ShakerUI)

local IngredientConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("IngredientConfig"))
local MutationConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("MutationConfig"))

local warningEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Warn"):WaitForChild("Warning")

local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local shakersEventsFolder = remoteEventsFolder:FindFirstChild("Shakers")
if not shakersEventsFolder then
	shakersEventsFolder = Instance.new("Folder")
	shakersEventsFolder.Name = "Shakers"
	shakersEventsFolder.Parent = remoteEventsFolder
end

local updateXpEvent = shakersEventsFolder:FindFirstChild("UpdateXp")
if not updateXpEvent then
	updateXpEvent = Instance.new("RemoteEvent")
	updateXpEvent.Name = "UpdateXp"
	updateXpEvent.Parent = shakersEventsFolder
end

local startEffectsEvent = shakersEventsFolder:FindFirstChild("StartEffects")
if not startEffectsEvent then
	startEffectsEvent = Instance.new("RemoteEvent")
	startEffectsEvent.Name = "StartEffects"
	startEffectsEvent.Parent = shakersEventsFolder
end

local stopEffectsEvent = shakersEventsFolder:FindFirstChild("StopEffects")
if not stopEffectsEvent then
	stopEffectsEvent = Instance.new("RemoteEvent")
	stopEffectsEvent.Name = "StopEffects"
	stopEffectsEvent.Parent = shakersEventsFolder
end

local completeShakeEvent = shakersEventsFolder:FindFirstChild("CompleteShake")
if not completeShakeEvent then
	completeShakeEvent = Instance.new("RemoteEvent")
	completeShakeEvent.Name = "CompleteShake"
	completeShakeEvent.Parent = shakersEventsFolder
end

local plotsFolder = Workspace:WaitForChild("Plots")

local ShakerManager = {}
ShakerManager.ActiveShakes = {}
local shakeTroves = {}

local function getPlotShakersFolder(player, shakerNumber)
	local currentPlotValue = player:FindFirstChild("CurrentPlot")
	if not currentPlotValue then return nil end

	local plotNumber = currentPlotValue.Value
	if plotNumber == "" then return nil end

	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
	if not plotFolder then return nil end

	local plotShakersRoot = plotFolder:FindFirstChild("Shakers")
	if not plotShakersRoot then return nil end

	return plotShakersRoot:FindFirstChild(tostring(shakerNumber))
end

local function getInfoBillboard(player, shakerNumber)
	local shakersFolder = getPlotShakersFolder(player, shakerNumber)
	if not shakersFolder then return nil end

	local infoFolder = shakersFolder:FindFirstChild("Info")
	if not infoFolder then return nil end

	local billboard = infoFolder:FindFirstChild("BillboardGui")
	return billboard
end

local function getModelFolder(player, shakerNumber)
	local shakersFolder = getPlotShakersFolder(player, shakerNumber)
	if not shakersFolder then return nil end

	return shakersFolder:FindFirstChild("Model")
end

local function getIngredientsFolder(player, shakerNumber)
	local shakersFolder = getPlotShakersFolder(player, shakerNumber)
	if not shakersFolder then return nil end

	return shakersFolder:FindFirstChild("Ingredients")
end

local function calculateTotalRequiredXp(ingredientFolders)
	local totalXp = 0
	for _, folder in ipairs(ingredientFolders) do
		local ingredientInfo = IngredientConfig.Ingredients[folder.Name]
		if ingredientInfo and ingredientInfo.Xp then
			totalXp = totalXp + ingredientInfo.Xp
		end
	end
	return totalXp
end

local function getMixedColor(ingredientFolders)
	local colors = {}
	for _, folder in ipairs(ingredientFolders) do
		local ingredientInfo = IngredientConfig.Ingredients[folder.Name]
		if ingredientInfo and ingredientInfo.Color then
			table.insert(colors, ingredientInfo.Color)
		end
	end

	if #colors == 0 then
		return Color3.fromRGB(255, 255, 255)
	end

	local r, g, b = 0, 0, 0
	for _, c in ipairs(colors) do
		r = r + c.R
		g = g + c.G
		b = b + c.B
	end

	return Color3.new(r / #colors, g / #colors, b / #colors)
end

local function updateBillboardDisplay(player, shakerNumber, currentXp, requiredXp, isActive)
	local billboard = getInfoBillboard(player, shakerNumber)
	if not billboard then return end

	billboard.Enabled = isActive

	if isActive then
		local content = billboard:FindFirstChild("Content")
		if content then
			local filler = content:FindFirstChild("Filler")
			local amount = content:FindFirstChild("Amount")

			if filler then
				local progress = math.clamp(currentXp / requiredXp, 0, 1)
				filler.Size = UDim2.new(progress, 0, 1, 0)
			end

			if amount then
				amount.Text = ShakerUI.FormatXp(currentXp) .. " / " .. ShakerUI.FormatXp(requiredXp)
			end
		end
	end
end

function ShakerManager.StartShake(player, shakerNumber)
	local shakeKey = player.UserId .. "_" .. shakerNumber

	local ingredientFolders = ShakerInventory.GetIngredientFolders(player, shakerNumber)
	if #ingredientFolders == 0 then
		return false
	end

	local requiredXp = calculateTotalRequiredXp(ingredientFolders)
	local mixedColor = getMixedColor(ingredientFolders)

	if ShakerManager.ActiveShakes[shakeKey] then
		ShakerManager.ActiveShakes[shakeKey].requiredXp = requiredXp
		ShakerManager.ActiveShakes[shakeKey].mixedColor = mixedColor
		updateBillboardDisplay(player, shakerNumber, ShakerManager.ActiveShakes[shakeKey].currentXp, requiredXp, true)
		return true
	end

	ShakerManager.ActiveShakes[shakeKey] = {
		player = player,
		shakerNumber = shakerNumber,
		currentXp = 0,
		requiredXp = requiredXp,
		mixedColor = mixedColor,
		cancelled = false
	}

	updateBillboardDisplay(player, shakerNumber, 0, requiredXp, true)

	startEffectsEvent:FireClient(player, shakerNumber, mixedColor)

	if _G.LoadSystem and _G.LoadSystem.UpdateShakerJuices then
		task.defer(function()
			_G.LoadSystem.UpdateShakerJuices(player, shakerNumber)
		end)
	end

	return true
end

function ShakerManager.StopShake(player, shakerNumber)
	local shakeKey = player.UserId .. "_" .. shakerNumber

	local shakeData = ShakerManager.ActiveShakes[shakeKey]
	if not shakeData then
		return false
	end

	shakeData.cancelled = true

	updateBillboardDisplay(player, shakerNumber, 0, 0, false)

	stopEffectsEvent:FireClient(player, shakerNumber)

	ShakerManager.ActiveShakes[shakeKey] = nil
	if shakeTroves[shakeKey] then
		shakeTroves[shakeKey]:Destroy()
		shakeTroves[shakeKey] = nil
	end

	if _G.LoadSystem and _G.LoadSystem.ClearAllShakerPartsInstantly then
		_G.LoadSystem.ClearAllShakerPartsInstantly(player, shakerNumber)
	end

	return true
end

function ShakerManager.RecalculateRequiredXp(player, shakerNumber)
	local shakeKey = player.UserId .. "_" .. shakerNumber

	local shakeData = ShakerManager.ActiveShakes[shakeKey]
	if not shakeData then
		return false
	end

	local ingredientFolders = ShakerInventory.GetIngredientFolders(player, shakerNumber)
	if #ingredientFolders == 0 then
		ShakerManager.StopShake(player, shakerNumber)
		return false
	end

	local newRequiredXp = calculateTotalRequiredXp(ingredientFolders)
	local newMixedColor = getMixedColor(ingredientFolders)

	shakeData.requiredXp = newRequiredXp
	shakeData.mixedColor = newMixedColor

	if shakeData.currentXp >= newRequiredXp then
		shakeData.currentXp = newRequiredXp - 1
	end

	updateBillboardDisplay(player, shakerNumber, shakeData.currentXp, newRequiredXp, true)

	startEffectsEvent:FireClient(player, shakerNumber, newMixedColor)

	if _G.LoadSystem and _G.LoadSystem.UpdateShakerJuices then
		task.defer(function()
			_G.LoadSystem.UpdateShakerJuices(player, shakerNumber)
		end)
	end

	return true
end

function ShakerManager.AddXp(player, shakerNumber, amount)
	local shakeKey = player.UserId .. "_" .. shakerNumber

	local shakeData = ShakerManager.ActiveShakes[shakeKey]
	if not shakeData or shakeData.cancelled then
		return false
	end

	shakeData.currentXp = shakeData.currentXp + amount

	updateXpEvent:FireClient(player, shakerNumber, shakeData.currentXp, shakeData.requiredXp)

	updateBillboardDisplay(player, shakerNumber, shakeData.currentXp, shakeData.requiredXp, true)

	if shakeData.currentXp >= shakeData.requiredXp then
		ShakerManager.CompleteShake(shakeKey)
	end

	return true
end

function ShakerManager.IncreaseRequiredXp(player, shakerNumber, percentage)
	local shakeKey = player.UserId .. "_" .. shakerNumber

	local shakeData = ShakerManager.ActiveShakes[shakeKey]
	if not shakeData then
		return false
	end

	local increase = math.floor(shakeData.requiredXp * percentage)
	shakeData.requiredXp = shakeData.requiredXp + increase

	updateBillboardDisplay(player, shakerNumber, shakeData.currentXp, shakeData.requiredXp, true)

	updateXpEvent:FireClient(player, shakerNumber, shakeData.currentXp, shakeData.requiredXp)

	return true
end

function ShakerManager.CompleteShake(shakeKey)
	local shakeData = ShakerManager.ActiveShakes[shakeKey]
	if not shakeData or shakeData.cancelled then return end

	local player = shakeData.player
	local shakerNumber = shakeData.shakerNumber
	local mixedColor = shakeData.mixedColor

	updateBillboardDisplay(player, shakerNumber, 0, 0, false)

	stopEffectsEvent:FireClient(player, shakerNumber)
	completeShakeEvent:FireClient(player, shakerNumber, mixedColor)

	if _G.LoadSystem and _G.LoadSystem.ClearAllShakerPartsInstantly then
		_G.LoadSystem.ClearAllShakerPartsInstantly(player, shakerNumber)
	end

	local ingredientFolders = ShakerInventory.GetIngredientFolders(player, shakerNumber)
	ShakerJuice.CreateJuice(player, shakerNumber, ingredientFolders, IngredientConfig, MutationConfig)

	warningEvent:FireClient(player, "Your juice is ready!", "Juice")

	ShakerManager.ActiveShakes[shakeKey] = nil
	if shakeTroves[shakeKey] then
		shakeTroves[shakeKey]:Destroy()
		shakeTroves[shakeKey] = nil
	end

	if _G.LoadSystem and _G.LoadSystem.UpdateShakerJuices then
		task.defer(function()
			_G.LoadSystem.UpdateShakerJuices(player, shakerNumber)
		end)
	end
end

function ShakerManager.CancelShake(player, shakerNumber)
	local shakeKey = player.UserId .. "_" .. shakerNumber

	local shakeData = ShakerManager.ActiveShakes[shakeKey]
	if not shakeData then
		return false
	end

	shakeData.cancelled = true

	updateBillboardDisplay(player, shakerNumber, 0, 0, false)

	stopEffectsEvent:FireClient(player, shakerNumber)

	if _G.LoadSystem and _G.LoadSystem.ClearAllShakerPartsInstantly then
		_G.LoadSystem.ClearAllShakerPartsInstantly(player, shakerNumber)
	end

	ShakerInventory.ReturnAllIngredients(player, shakerNumber)

	ShakerManager.ActiveShakes[shakeKey] = nil
	if shakeTroves[shakeKey] then
		shakeTroves[shakeKey]:Destroy()
		shakeTroves[shakeKey] = nil
	end

	if _G.LoadSystem and _G.LoadSystem.UpdateShakerJuices then
		task.defer(function()
			_G.LoadSystem.UpdateShakerJuices(player, shakerNumber)
		end)
	end

	return true
end

function ShakerManager.IsShakeActive(player, shakerNumber)
	local shakeKey = player.UserId .. "_" .. shakerNumber
	return ShakerManager.ActiveShakes[shakeKey] ~= nil
end

function ShakerManager.GetShakeData(player, shakerNumber)
	local shakeKey = player.UserId .. "_" .. shakerNumber
	return ShakerManager.ActiveShakes[shakeKey]
end

function ShakerManager.RestoreShake(player, shakerNumber, currentXp, requiredXp)
	local shakeKey = player.UserId .. "_" .. shakerNumber

	if ShakerManager.ActiveShakes[shakeKey] then
		return false
	end

	local ingredientFolders = ShakerInventory.GetIngredientFolders(player, shakerNumber)
	if #ingredientFolders == 0 then
		return false
	end

	local mixedColor = getMixedColor(ingredientFolders)

	ShakerManager.ActiveShakes[shakeKey] = {
		player = player,
		shakerNumber = shakerNumber,
		currentXp = currentXp,
		requiredXp = requiredXp,
		mixedColor = mixedColor,
		cancelled = false
	}

	updateBillboardDisplay(player, shakerNumber, currentXp, requiredXp, true)

	startEffectsEvent:FireClient(player, shakerNumber, mixedColor)

	if _G.LoadSystem and _G.LoadSystem.UpdateShakerJuices then
		task.defer(function()
			_G.LoadSystem.UpdateShakerJuices(player, shakerNumber)
		end)
	end

	return true
end

return ShakerManager
