--[[
	ShakerClient - LocalScript del cliente
	- Click en modelo del shaker para añadir ingredientes
	- Highlight cuando tiene ingrediente en mano
	- Efectos visuales de mezcla (gelatina)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

print("[ShakerClient] Iniciando...")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local plotsFolder = Workspace:WaitForChild("Plots")

print("[ShakerClient] Esperando eventos...")

-- Esperar eventos
local shakersFolder = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Shakers")
local StartMixingEvent = shakersFolder:WaitForChild("StartMixing")
local StopMixingEvent = shakersFolder:WaitForChild("StopMixing")
local UpdateProgressEvent = shakersFolder:WaitForChild("UpdateProgress")
local CompleteMixingEvent = shakersFolder:WaitForChild("CompleteMixing")
local ShakerClickEvent = shakersFolder:WaitForChild("ShakerClick")

print("[ShakerClient] Eventos encontrados")

-- Config de ingredientes
local IngredientConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("IngredientConfig"))

print("[ShakerClient] Config cargada")

-- Estado
local ActiveEffects = {} -- [shakerNumber] = {parts, connection, mixedColor}
local CurrentHighlight = nil
local CurrentHoveredShaker = nil

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

local function getShakerFolder(shakerNumber)
	local plotNumber = getCurrentPlotNumber()
	if not plotNumber then return nil end

	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
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

local function getEquippedTool()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChildOfClass("Tool")
end

local function isIngredientTool(tool)
	if not tool then return false end
	local typeValue = tool:FindFirstChild("Type")
	return typeValue and typeValue:IsA("StringValue") and typeValue.Value == "Ingredient"
end

-- Buscar shaker desde una parte clickeada
-- Busca hacia arriba en la jerarquía hasta encontrar un folder de shaker numerado
local function findShakerFromPart(part)
	local plotNumber = getCurrentPlotNumber()
	if not plotNumber then return nil, nil end

	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
	if not plotFolder then return nil, nil end

	local shakersRoot = plotFolder:FindFirstChild("Shakers")
	if not shakersRoot then return nil, nil end

	-- Buscar hacia arriba hasta encontrar algo que sea hijo de un shaker
	local current = part
	while current and current ~= Workspace do
		local parent = current.Parent
		if parent then
			-- Verificar si el parent es un shaker folder (hijo directo de shakersRoot)
			if parent.Parent == shakersRoot then
				local shakerNum = tonumber(parent.Name)
				if shakerNum then
					return shakerNum, parent
				end
			end
			-- Verificar si el parent es shakersRoot y current es un shaker folder
			if parent == shakersRoot then
				local shakerNum = tonumber(current.Name)
				if shakerNum then
					return shakerNum, current
				end
			end
		end
		current = parent
	end

	return nil, nil
end

------------------------------------------------------------------------
-- HIGHLIGHT
------------------------------------------------------------------------

local function clearHighlight()
	if CurrentHighlight then
		CurrentHighlight:Destroy()
		CurrentHighlight = nil
	end
	CurrentHoveredShaker = nil
end

local function applyHighlight(shakerFolder)
	if CurrentHoveredShaker == shakerFolder then return end

	clearHighlight()
	CurrentHoveredShaker = shakerFolder

	-- Buscar el modelo dentro del folder Model
	local modelFolder = shakerFolder:FindFirstChild("Model")
	if not modelFolder then return end

	local model = modelFolder:FindFirstChildOfClass("Model")
	if not model then
		-- Si no hay Model, buscar cualquier BasePart
		model = modelFolder:FindFirstChildOfClass("BasePart")
	end
	if not model then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = "ShakerHighlight"
	highlight.FillColor = Color3.fromRGB(100, 255, 100)
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0
	highlight.Adornee = model
	highlight.Parent = model

	CurrentHighlight = highlight
end

------------------------------------------------------------------------
-- EFECTOS VISUALES DE MEZCLA
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

			local variation = -0.15 + math.random() * 0.3
			if variation > 0 then
				part.Color = mixedColor:Lerp(Color3.new(1, 1, 1), variation)
			else
				part.Color = mixedColor:Lerp(Color3.new(0, 0, 0), -variation)
			end

			local finalSize = Vector3.new(contentSize.X, partHeight, contentSize.Z)
			part:SetAttribute("BaseSize", tostring(finalSize))

			part.Size = finalSize * 0.01

			local offsetY = -(contentSize.Y / 2) + (partHeight / 2) + ((i - 1) * partHeight)
			part.CFrame = contentCFrame * CFrame.new(0, offsetY, 0)

			part.Parent = contentPart

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
-- EVENTOS DEL SERVIDOR
------------------------------------------------------------------------

StartMixingEvent.OnClientEvent:Connect(function(shakerNumber, mixedColor)
	print("[ShakerClient] StartMixing recibido:", shakerNumber)
	stopEffects(shakerNumber)

	local contentPart = getContentPart(shakerNumber)
	if not contentPart then
		print("[ShakerClient] No se encontró contentPart para shaker:", shakerNumber)
		return
	end

	local ingredientNames = getIngredientNames(shakerNumber)
	if #ingredientNames == 0 then
		print("[ShakerClient] No hay ingredientes para shaker:", shakerNumber)
		return
	end

	print("[ShakerClient] Creando efectos visuales con", #ingredientNames, "ingredientes")
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

StopMixingEvent.OnClientEvent:Connect(function(shakerNumber)
	print("[ShakerClient] StopMixing recibido:", shakerNumber)
	stopEffects(shakerNumber)
end)

CompleteMixingEvent.OnClientEvent:Connect(function(shakerNumber, mixedColor)
	print("[ShakerClient] CompleteMixing recibido:", shakerNumber)
	stopEffects(shakerNumber)

	local contentPart = getContentPart(shakerNumber)
	if contentPart then
		clearContent(contentPart)
	end
end)

------------------------------------------------------------------------
-- CLICK Y HOVER
------------------------------------------------------------------------

-- Detectar hover para highlight
RunService.RenderStepped:Connect(function()
	local target = mouse.Target
	if not target then
		clearHighlight()
		return
	end

	local shakerNum, shakerFolder = findShakerFromPart(target)

	if shakerNum and shakerFolder then
		local tool = getEquippedTool()
		-- Mostrar highlight si tiene ingrediente o energizante en mano
		if tool and (isIngredientTool(tool) or tool.Name:find("Energizing")) then
			applyHighlight(shakerFolder)
		else
			clearHighlight()
		end
	else
		clearHighlight()
	end
end)

-- Detectar click
mouse.Button1Down:Connect(function()
	local target = mouse.Target
	if not target then return end

	local shakerNum, shakerFolder = findShakerFromPart(target)
	local plotNumber = getCurrentPlotNumber()

	print("[ShakerClient] Click detectado - target:", target.Name, "shakerNum:", shakerNum, "plot:", plotNumber)

	if shakerNum and plotNumber then
		print("[ShakerClient] Enviando click al servidor - shaker:", shakerNum, "plot:", plotNumber)
		ShakerClickEvent:FireServer(shakerNum, plotNumber)
	end
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
	print("[ShakerClient] Esperando folder Shakers del jugador...")
	local playerShakers = player:WaitForChild("Shakers", 10)
	if not playerShakers then
		print("[ShakerClient] ERROR: No se encontró folder Shakers después de 10 segundos")
		return
	end

	print("[ShakerClient] Folder Shakers encontrado")

	for _, shakerFolder in ipairs(playerShakers:GetChildren()) do
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				watchShakerFolder(shakerFolder, shakerNumber)
				print("[ShakerClient] Observando shaker:", shakerNumber)
			end
		end
	end

	playerShakers.ChildAdded:Connect(function(shakerFolder)
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				watchShakerFolder(shakerFolder, shakerNumber)
				print("[ShakerClient] Nuevo shaker añadido:", shakerNumber)
			end
		end
	end)
end

task.spawn(setupPlayerShakers)

print("[ShakerClient] Inicialización completa")
