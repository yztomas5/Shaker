--[[
	ShakerClient - LocalScript del cliente
	- Click en modelo del shaker para añadir ingredientes
	- Highlight cuando tiene ingrediente en mano
	- Efectos visuales de mezcla (gelatina)

	Estructura:
	Plots/{PlotNumber}/Shakers/  <-- El shaker
		├── Ingredients/Content
		├── Model/{ModelName}
		├── Info
		└── TouchPart
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

-- Esperar eventos
local shakersFolder = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Shakers")
local StartMixingEvent = shakersFolder:WaitForChild("StartMixing")
local StopMixingEvent = shakersFolder:WaitForChild("StopMixing")
local UpdateProgressEvent = shakersFolder:WaitForChild("UpdateProgress")
local CompleteMixingEvent = shakersFolder:WaitForChild("CompleteMixing")
local ShakerClickEvent = shakersFolder:WaitForChild("ShakerClick")

-- Config de ingredientes
local IngredientConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("IngredientConfig"))

-- Estado
local ActiveEffects = {}
local CurrentHighlight = nil
local CurrentHoveredModel = nil

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

local function getContentPart()
	local shakerFolder = getShakerFolder()
	if not shakerFolder then return nil end

	local ingredientsFolder = shakerFolder:FindFirstChild("Ingredients")
	if not ingredientsFolder then return nil end

	return ingredientsFolder:FindFirstChild("Content")
end

local function getShakerModel()
	local shakerFolder = getShakerFolder()
	if not shakerFolder then return nil end

	local modelFolder = shakerFolder:FindFirstChild("Model")
	if not modelFolder then return nil end

	-- Buscar el primer Model dentro de Model folder
	for _, child in ipairs(modelFolder:GetChildren()) do
		if child:IsA("Model") then
			return child
		end
	end
	return nil
end

local function getIngredientNames()
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return {} end

	local names = {}
	for _, folder in ipairs(playerShakers:GetChildren()) do
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

-- Verificar si una parte pertenece al shaker
local function isPartOfShaker(part)
	local shakerFolder = getShakerFolder()
	if not shakerFolder then return false end

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
-- HIGHLIGHT
------------------------------------------------------------------------

local function clearHighlight()
	if CurrentHighlight then
		CurrentHighlight:Destroy()
		CurrentHighlight = nil
	end
	CurrentHoveredModel = nil
end

local function applyHighlight()
	local model = getShakerModel()
	if not model then return end

	if CurrentHoveredModel == model then return end

	clearHighlight()
	CurrentHoveredModel = model

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

local function startJellyEffect(parts, mixedColor)
	if #parts == 0 then return end

	for _, part in ipairs(parts) do
		task.spawn(function()
			while ActiveEffects.active and part.Parent do
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

local function stopEffects()
	if not ActiveEffects.active then return end

	if ActiveEffects.connection then
		ActiveEffects.connection:Disconnect()
	end

	local contentPart = getContentPart()
	if contentPart then
		for _, part in ipairs(ActiveEffects.parts or {}) do
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

	ActiveEffects = {}
end

------------------------------------------------------------------------
-- EVENTOS DEL SERVIDOR
------------------------------------------------------------------------

StartMixingEvent.OnClientEvent:Connect(function(mixedColor)
	print("[ShakerClient] StartMixing recibido")
	stopEffects()

	local contentPart = getContentPart()
	if not contentPart then
		print("[ShakerClient] No se encontró contentPart")
		return
	end

	local ingredientNames = getIngredientNames()
	if #ingredientNames == 0 then
		print("[ShakerClient] No hay ingredientes")
		return
	end

	print("[ShakerClient] Creando efectos visuales con", #ingredientNames, "ingredientes")
	local parts = createJuiceParts(contentPart, ingredientNames, mixedColor)

	ActiveEffects = {
		active = true,
		parts = parts,
		mixedColor = mixedColor
	}

	local connection = startJellyEffect(parts, mixedColor)
	ActiveEffects.connection = connection
end)

StopMixingEvent.OnClientEvent:Connect(function()
	print("[ShakerClient] StopMixing recibido")
	stopEffects()
end)

CompleteMixingEvent.OnClientEvent:Connect(function(mixedColor)
	print("[ShakerClient] CompleteMixing recibido")
	stopEffects()

	local contentPart = getContentPart()
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

	if isPartOfShaker(target) then
		local tool = getEquippedTool()
		-- Mostrar highlight si tiene ingrediente o energizante en mano
		if tool and (isIngredientTool(tool) or tool.Name:find("Energizing")) then
			applyHighlight()
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

	local plotNumber = getCurrentPlotNumber()
	if not plotNumber then return end

	if isPartOfShaker(target) then
		print("[ShakerClient] Click en shaker detectado, enviando al servidor")
		ShakerClickEvent:FireServer(plotNumber)
	end
end)

------------------------------------------------------------------------
-- SINCRONIZACIÓN CON INGREDIENTES
------------------------------------------------------------------------

local function setupPlayerShakers()
	local playerShakers = player:WaitForChild("Shakers", 10)
	if not playerShakers then
		print("[ShakerClient] ERROR: No se encontró folder Shakers")
		return
	end

	local function updateVisuals()
		if not ActiveEffects.active then return end

		local contentPart = getContentPart()
		if not contentPart then return end

		local ingredientNames = getIngredientNames()
		if #ingredientNames == 0 then
			stopEffects()
			return
		end

		if ActiveEffects.connection then
			ActiveEffects.connection:Disconnect()
		end

		local parts = createJuiceParts(contentPart, ingredientNames, ActiveEffects.mixedColor)
		ActiveEffects.parts = parts
		ActiveEffects.connection = startJellyEffect(parts, ActiveEffects.mixedColor)
	end

	playerShakers.ChildAdded:Connect(updateVisuals)
	playerShakers.ChildRemoved:Connect(updateVisuals)
end

task.spawn(setupPlayerShakers)

print("[ShakerClient] Inicialización completa")
