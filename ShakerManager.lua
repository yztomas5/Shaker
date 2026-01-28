local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("Trove"))
local ShakerInventory = require(script.Parent.ShakerInventory)
local ShakerEffects = require(script.Parent.ShakerEffects)
local ShakerJuice = require(script.Parent.ShakerJuice)
local ShakerUI = require(script.Parent.ShakerUI)
local ShakerModel = require(script.Parent.ShakerModel)

local IngredientConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("IngredientConfig"))
local MutationConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("MutationConfig"))

local warningEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Warn"):WaitForChild("Warning")

local ShakerManager = {}
ShakerManager.ActiveShakes = {}
local shakeTroves = {}

function ShakerManager.StartShake(player, shakerNumber)
	local shakeKey = player.UserId .. "_" .. shakerNumber

	if ShakerManager.ActiveShakes[shakeKey] then 
		return false
	end

	local ingredientFolders = ShakerInventory.GetIngredientFolders(player, shakerNumber)
	if #ingredientFolders == 0 then 
		return false
	end

	local totalDuration = 0
	for _, folder in ipairs(ingredientFolders) do
		local ingredientInfo = IngredientConfig.Ingredients[folder.Name]
		if ingredientInfo then
			totalDuration = totalDuration + ingredientInfo.ShakeDuration
		end
	end

	local colors = ShakerEffects.GetIngredientColors(ingredientFolders, IngredientConfig)
	local mixedColor = ShakerEffects.MixColors(colors)

	ShakerManager.ActiveShakes[shakeKey] = {
		startTime = tick(),
		duration = totalDuration,
		originalDuration = totalDuration,
		player = player,
		shakerNumber = shakerNumber,
		cancelled = false,
		mixedColor = mixedColor,
		soundClone = nil,
		contentPart = nil
	}

	local currentModel = ShakerModel.GetCurrentShakerModel(player, shakerNumber)
	if not currentModel then
		ShakerManager.ActiveShakes[shakeKey] = nil
		return false
	end

	local soundClone, contentPart = ShakerEffects.StartShakeEffects(currentModel, mixedColor)
	ShakerEffects.SetStartButtonColor(currentModel, true)

	local shakeData = ShakerManager.ActiveShakes[shakeKey]
	shakeData.soundClone = soundClone
	shakeData.contentPart = contentPart

	local startPart = currentModel:FindFirstChild("Start")
	if startPart then
		local startPrompt = startPart:FindFirstChild("StartPrompt")
		if startPrompt then
			startPrompt.Enabled = false
		end
	end

	shakeTroves[shakeKey] = Trove.new()

	task.spawn(function()
		ShakerManager.UpdateShakeLoop(shakeKey, totalDuration)
	end)

	-- Notify Load system to update visuals for mixing effects
	if _G.LoadSystem and _G.LoadSystem.UpdateShakerJuices then
		task.defer(function()
			_G.LoadSystem.UpdateShakerJuices(player, shakerNumber)
		end)
	end

	return true
end

function ShakerManager.ReduceShakeTime(player, shakerNumber, percentage)
	local shakeKey = player.UserId .. "_" .. shakerNumber
	local shakeData = ShakerManager.ActiveShakes[shakeKey]

	if not shakeData then
		return false
	end

	local elapsed = tick() - shakeData.startTime
	local currentRemaining = shakeData.duration - elapsed

	local reduction = currentRemaining * percentage
	local newRemaining = math.max(0, currentRemaining - reduction)

	shakeData.duration = elapsed + newRemaining

	return true
end

function ShakerManager.UpdateShakeLoop(shakeKey, totalDuration)
	local elapsed = 0
	local lastModel = nil
	local startTime = tick()

	if not shakeTroves[shakeKey] then
		shakeTroves[shakeKey] = Trove.new()
	end
	local trove = shakeTroves[shakeKey]

	trove:Connect(RunService.Heartbeat, function(dt)
		local shakeData = ShakerManager.ActiveShakes[shakeKey]

		if not shakeData or shakeData.cancelled then
			trove:Destroy()
			shakeTroves[shakeKey] = nil
			return
		end

		elapsed = tick() - startTime
		local remaining = math.max(0, shakeData.duration - elapsed)

		local currentModel = ShakerModel.GetCurrentShakerModel(shakeData.player, shakeData.shakerNumber)

		if currentModel ~= lastModel then
			if lastModel then
				ShakerEffects.StopShakeEffects(
					shakeData.soundClone,
					shakeData.contentPart
				)
			end

			if currentModel then
				local soundClone, contentPart =
					ShakerEffects.StartShakeEffects(currentModel, shakeData.mixedColor)

				shakeData.soundClone = soundClone
				shakeData.contentPart = contentPart

				ShakerEffects.SetStartButtonColor(currentModel, true)

				-- Notify Load system to apply mixing visuals when model becomes available
				if _G.LoadSystem and _G.LoadSystem.UpdateShakerJuices then
					task.defer(function()
						_G.LoadSystem.UpdateShakerJuices(shakeData.player, shakeData.shakerNumber)
					end)
				end
			end

			lastModel = currentModel
		end

		if currentModel then
			ShakerUI.UpdateStatusDisplay(currentModel, math.ceil(remaining), true)
		end

		if elapsed >= shakeData.duration then
			trove:Destroy()
			shakeTroves[shakeKey] = nil
			ShakerManager.CompleteShake(shakeKey)
		end
	end)
end

function ShakerManager.CompleteShake(shakeKey)
	local shakeData = ShakerManager.ActiveShakes[shakeKey]
	if not shakeData or shakeData.cancelled then return end

	local player = shakeData.player
	local shakerNumber = shakeData.shakerNumber
	local mixedColor = shakeData.mixedColor

	local finalModel = ShakerModel.GetCurrentShakerModel(player, shakerNumber)

	if finalModel then
		finalModel:SetAttribute("Mixing", false)
		ShakerEffects.StopShakeEffects(
			shakeData.soundClone,
			shakeData.contentPart
		)
		ShakerEffects.SetStartButtonColor(finalModel, false)
		ShakerUI.UpdateStatusDisplay(finalModel, 0, false)

		ShakerEffects.PlayPourEffect(finalModel, mixedColor)

		local startPart = finalModel:FindFirstChild("Start")
		if startPart then
			local startPrompt = startPart:FindFirstChild("StartPrompt")
			if startPrompt then
				startPrompt.Enabled = true
			end
		end
	end

	-- Borrar todas las partes instantáneamente antes de crear el jugo
	if _G.LoadSystem and _G.LoadSystem.ClearAllShakerPartsInstantly then
		_G.LoadSystem.ClearAllShakerPartsInstantly(player, shakerNumber)
	end

	local ingredientFolders = ShakerInventory.GetIngredientFolders(player, shakerNumber)
	ShakerJuice.CreateJuice(player, shakerNumber, ingredientFolders, IngredientConfig, MutationConfig)

	-- Notify player that juice is ready
	warningEvent:FireClient(player, "Your juice is ready!", "Juice")

	ShakerManager.ActiveShakes[shakeKey] = nil
	if shakeTroves[shakeKey] then
		shakeTroves[shakeKey]:Destroy()
		shakeTroves[shakeKey] = nil
	end

	-- Notify Load system to update visuals (restore original colors)
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

	local currentModel = ShakerModel.GetCurrentShakerModel(player, shakerNumber)

	if currentModel then
		currentModel:SetAttribute("Mixing", false)

		-- Reproducir sonido Remove al cancelar
		local contentPart = ShakerModel.GetContentPart(currentModel)
		if contentPart then
			ShakerEffects.PlayRemoveIngredientSound(contentPart)
		end

		ShakerEffects.StopShakeEffects(
			shakeData.soundClone,
			shakeData.contentPart
		)
		ShakerEffects.SetStartButtonColor(currentModel, false)
		ShakerUI.UpdateStatusDisplay(currentModel, 0, false)

		local startPart = currentModel:FindFirstChild("Start")
		if startPart then
			local startPrompt = startPart:FindFirstChild("StartPrompt")
			if startPrompt then
				startPrompt.Enabled = true
			end
		end
	end

	-- Borrar todas las partes instantáneamente al cancelar
	if _G.LoadSystem and _G.LoadSystem.ClearAllShakerPartsInstantly then
		_G.LoadSystem.ClearAllShakerPartsInstantly(player, shakerNumber)
	end

	ShakerInventory.ReturnAllIngredients(player, shakerNumber)

	ShakerManager.ActiveShakes[shakeKey] = nil
	if shakeTroves[shakeKey] then
		shakeTroves[shakeKey]:Destroy()
		shakeTroves[shakeKey] = nil
	end

	-- Notify Load system to update visuals (restore original colors)
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

return ShakerManager