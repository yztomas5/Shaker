--[[
	ShakerClient - LocalScript del cliente
	Maneja efectos visuales de mezcla (gelatina)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local plotsFolder = Workspace:WaitForChild("Plots")

-- Esperar eventos
local shakersFolder = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Shakers")
local StartMixing = shakersFolder:WaitForChild("StartMixing")
local StopMixing = shakersFolder:WaitForChild("StopMixing")
local UpdateProgress = shakersFolder:WaitForChild("UpdateProgress")
local CompleteMixing = shakersFolder:WaitForChild("CompleteMixing")

-- Config de ingredientes
local IngredientConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("IngredientConfig"))

-- Estado
local ActiveEffects = {} -- [shakerNumber] = {parts, connection, mixedColor}

------------------------------------------------------------------------
-- UTILIDADES
------------------------------------------------------------------------

local function getShakerFolder(shakerNumber)
	local currentPlot = player:FindFirstChild("CurrentPlot")
	if not currentPlot or currentPlot.Value == "" then return nil end

	local plotFolder = plotsFolder:FindFirstChild(currentPlot.Value)
	if not plotFolder then return nil end

	local shakersRoot = plotFolder:FindFirstChild("Shakers")
	if not shakersRoot then return nil end

	return shakersRoot:FindFirstChild(tostring(shakerNumber))
end

local function getContentPart(shakerNumber)
	local shakerFolder = getShakerFolder(shakerNumber)
	if not shakerFolder then return nil end

	local ingredientsFolder = shakerFolder:FindFirstChild("Ingredients")
	if not ingredientsFolder then return nil end

	return ingredientsFolder:FindFirstChild("Content")
end

local function getIngredientNames(shakerNumber)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return {} end

	local shakerFolder = playerShakers:FindFirstChild(tostring(shakerNumber))
	if not shakerFolder then return {} end

	local names = {}
	for _, folder in ipairs(shakerFolder:GetChildren()) do
		if folder:IsA("Folder") then
			table.insert(names, folder.Name)
		end
	end
	return names
end

------------------------------------------------------------------------
-- EFECTOS VISUALES
------------------------------------------------------------------------

local function clearContent(contentPart)
	if not contentPart then return end
	for _, child in ipairs(contentPart:GetChildren()) do
		if child:IsA("BasePart") and child.Name:find("Layer_") then
			child:Destroy()
		end
	end
end

local function createJuiceParts(contentPart, ingredientNames, mixedColor)
	clearContent(contentPart)

	local numIngredients = #ingredientNames
	if numIngredients == 0 then return {} end

	local contentSize = contentPart.Size
	local contentCFrame = contentPart.CFrame
	local partHeight = contentSize.Y / numIngredients

	local parts = {}

	for i, ingredientName in ipairs(ingredientNames) do
		local ingredientData = IngredientConfig.Ingredients[ingredientName]
		if ingredientData then
			local part = Instance.new("Part")
			part.Name = "Layer_" .. ingredientName .. "_" .. i
			part.Anchored = true
			part.CanCollide = false
			part.Material = Enum.Material.SmoothPlastic

			-- Color con variación
			local variation = -0.15 + math.random() * 0.3
			if variation > 0 then
				part.Color = mixedColor:Lerp(Color3.new(1, 1, 1), variation)
			else
				part.Color = mixedColor:Lerp(Color3.new(0, 0, 0), -variation)
			end

			local finalSize = Vector3.new(contentSize.X, partHeight, contentSize.Z)
			part:SetAttribute("BaseSize", tostring(finalSize))

			-- Empezar pequeño
			part.Size = finalSize * 0.01

			local offsetY = -(contentSize.Y / 2) + (partHeight / 2) + ((i - 1) * partHeight)
			part.CFrame = contentCFrame * CFrame.new(0, offsetY, 0)

			part.Parent = contentPart

			-- Animar entrada
			local tween = TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = finalSize
			})
			tween:Play()

			table.insert(parts, part)
		end
	end

	return parts
end

local function startJellyEffect(shakerNumber, parts, mixedColor)
	if #parts == 0 then return end

	-- Efecto de color
	for _, part in ipairs(parts) do
		task.spawn(function()
			while ActiveEffects[shakerNumber] and part.Parent do
				local variation = -0.25 + math.random() * 0.3
				local newColor
				if variation > 0 then
					newColor = mixedColor:Lerp(Color3.new(1, 1, 1), variation)
				else
					newColor = mixedColor:Lerp(Color3.new(0, 0, 0), -variation)
				end

				local duration = 1.5 + math.random() * 1.5
				local colorTween = TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Color = newColor
				})
				colorTween:Play()
				colorTween.Completed:Wait()
				task.wait(0.1)
			end
		end)
	end

	-- Efecto de pulso
	local connection = RunService.Heartbeat:Connect(function()
		for _, part in ipairs(parts) do
			if part.Parent and math.random() < 0.03 then
				local baseSizeStr = part:GetAttribute("BaseSize")
				if baseSizeStr then
					local x, y, z = baseSizeStr:match("([%d%.]+), ([%d%.]+), ([%d%.]+)")
					if x and y and z then
						local baseSize = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
						local scale = 0.70 + math.random() * 0.40
						local targetSize = baseSize * scale

						local pulseTween = TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
							Size = targetSize
						})
						pulseTween:Play()
						pulseTween.Completed:Connect(function()
							if part.Parent then
								local returnTween = TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
									Size = baseSize
								})
								returnTween:Play()
							end
						end)
					end
				end
			end
		end
	end)

	return connection
end

local function stopEffects(shakerNumber)
	local effectData = ActiveEffects[shakerNumber]
	if not effectData then return end

	if effectData.connection then
		effectData.connection:Disconnect()
	end

	local contentPart = getContentPart(shakerNumber)
	if contentPart then
		-- Animar salida
		for _, part in ipairs(effectData.parts or {}) do
			if part.Parent then
				local tween = TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Size = part.Size * 0.01
				})
				tween.Completed:Connect(function()
					part:Destroy()
				end)
				tween:Play()
			end
		end
	end

	ActiveEffects[shakerNumber] = nil
end

------------------------------------------------------------------------
-- EVENTOS
------------------------------------------------------------------------

StartMixing.OnClientEvent:Connect(function(shakerNumber, mixedColor)
	-- Detener efectos anteriores
	stopEffects(shakerNumber)

	local contentPart = getContentPart(shakerNumber)
	if not contentPart then return end

	local ingredientNames = getIngredientNames(shakerNumber)
	if #ingredientNames == 0 then return end

	local parts = createJuiceParts(contentPart, ingredientNames, mixedColor)

	ActiveEffects[shakerNumber] = {
		parts = parts,
		mixedColor = mixedColor
	}

	local connection = startJellyEffect(shakerNumber, parts, mixedColor)
	if ActiveEffects[shakerNumber] then
		ActiveEffects[shakerNumber].connection = connection
	end
end)

StopMixing.OnClientEvent:Connect(function(shakerNumber)
	stopEffects(shakerNumber)
end)

CompleteMixing.OnClientEvent:Connect(function(shakerNumber, mixedColor)
	stopEffects(shakerNumber)

	local contentPart = getContentPart(shakerNumber)
	if contentPart then
		clearContent(contentPart)
	end
end)

UpdateProgress.OnClientEvent:Connect(function(shakerNumber, currentXp, requiredXp)
	-- Actualización de progreso manejada por el servidor en Billboard
end)

------------------------------------------------------------------------
-- SINCRONIZACIÓN CON INGREDIENTES
------------------------------------------------------------------------

local function watchShakerFolder(shakerFolder, shakerNumber)
	local function updateVisuals()
		local effectData = ActiveEffects[shakerNumber]
		if not effectData then return end

		local contentPart = getContentPart(shakerNumber)
		if not contentPart then return end

		local ingredientNames = getIngredientNames(shakerNumber)
		if #ingredientNames == 0 then
			stopEffects(shakerNumber)
			return
		end

		-- Recrear partes
		if effectData.connection then
			effectData.connection:Disconnect()
		end

		local parts = createJuiceParts(contentPart, ingredientNames, effectData.mixedColor)
		effectData.parts = parts
		effectData.connection = startJellyEffect(shakerNumber, parts, effectData.mixedColor)
	end

	shakerFolder.ChildAdded:Connect(updateVisuals)
	shakerFolder.ChildRemoved:Connect(updateVisuals)
end

local function setupPlayerShakers()
	local playerShakers = player:WaitForChild("Shakers", 10)
	if not playerShakers then return end

	for _, shakerFolder in ipairs(playerShakers:GetChildren()) do
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				watchShakerFolder(shakerFolder, shakerNumber)
			end
		end
	end

	playerShakers.ChildAdded:Connect(function(shakerFolder)
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				watchShakerFolder(shakerFolder, shakerNumber)
			end
		end
	end)
end

task.spawn(setupPlayerShakers)
