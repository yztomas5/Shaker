--[[
	ShakerClient - LocalScript del cliente
	- Click en modelo del shaker para añadir ingredientes
	- Highlight cuando tiene ingrediente en mano
	- TouchPart con efecto de presionado para añadir XP
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

local Trove = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("Trove"))
local ShakerButton = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"):WaitForChild("ShakerSystem"):WaitForChild("ShakerButton"))
local ShakerConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"):WaitForChild("ShakerSystem"):WaitForChild("ShakerConfig"))
local ShakerEffects = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"):WaitForChild("ShakerSystem"):WaitForChild("ShakerEffects"))

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
local TouchPartClickEvent = shakersFolder:WaitForChild("TouchPartClick")
local CancelMixingEvent = shakersFolder:WaitForChild("CancelMixing")
local IngredientAddedEvent = shakersFolder:WaitForChild("IngredientAdded")
local IngredientRemovedEvent = shakersFolder:WaitForChild("IngredientRemoved")
local EnergizingAddedEvent = shakersFolder:WaitForChild("EnergizingAdded")

-- GUI de Warning
local warnGui = player:WaitForChild("PlayerGui"):WaitForChild("Warn")
local warningFrame = warnGui:WaitForChild("Warning")

-- Config de ingredientes
local IngredientConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("IngredientConfig"))

-- Estado
local mainTrove = Trove.new()
local currentPlotTrove = nil
local currentTouchPart = nil
local currentRemovePart = nil
local cancelPopupTrove = nil

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

-- Verificar si una parte pertenece al shaker (pero NO es TouchPart)
local function isPartOfShakerModel(part)
	local shakerFolder = getShakerFolder()
	if not shakerFolder then return false end

	local touchPart = shakerFolder:FindFirstChild("TouchPart")
	if touchPart and (part == touchPart or part:IsDescendantOf(touchPart)) then
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
-- HIGHLIGHT PARA MODELO (cuando tiene ingrediente)
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
	stopEffects()

	local contentPart = getContentPart()
	if not contentPart then return end

	local ingredientNames = getIngredientNames()
	if #ingredientNames == 0 then return end

	local parts = createJuiceParts(contentPart, ingredientNames, mixedColor)

	-- Iniciar efectos de sonido y partículas de burbujas
	local soundClone, _ = ShakerEffects.StartShakeEffects(contentPart, mixedColor)

	ActiveEffects = {
		active = true,
		parts = parts,
		mixedColor = mixedColor,
		soundClone = soundClone
	}

	local connection = startJellyEffect(parts, mixedColor)
	ActiveEffects.connection = connection
end)

StopMixingEvent.OnClientEvent:Connect(function()
	local contentPart = getContentPart()

	-- Detener efectos de burbujas con fade
	if ActiveEffects.soundClone then
		ShakerEffects.StopShakeEffects(ActiveEffects.soundClone, contentPart)
	end

	-- Sonido de remover
	if contentPart then
		ShakerEffects.PlayRemoveIngredientSound(contentPart)
	end

	stopEffects()
end)

CompleteMixingEvent.OnClientEvent:Connect(function(mixedColor)
	-- Solo detener efectos sin animaciones adicionales
	stopEffects()
end)

-- Sonido y efecto de burbujas al añadir ingrediente
IngredientAddedEvent.OnClientEvent:Connect(function(ingredientColor)
	local contentPart = getContentPart()
	if contentPart then
		ShakerEffects.PlayAddIngredientSound(contentPart)
		if ingredientColor then
			ShakerEffects.PlayAddIngredientBubbles(contentPart, ingredientColor)
		end
	end
end)

-- Sonido al remover ingrediente
IngredientRemovedEvent.OnClientEvent:Connect(function()
	local contentPart = getContentPart()
	if contentPart then
		ShakerEffects.PlayRemoveIngredientSound(contentPart)
	end
end)

-- Efecto de energizante añadido (sonido y partículas según tipo)
EnergizingAddedEvent.OnClientEvent:Connect(function(xpAdded, energizerName)
	local contentPart = getContentPart()
	if not contentPart then return end

	-- Reproducir sonido y VFX según el tipo de energizante
	if energizerName == "Energizing" then
		ShakerEffects.PlayEnergizingSound(contentPart)
	elseif energizerName == "Mid Energizing" then
		ShakerEffects.PlayMidEnergizingSound(contentPart)
	elseif energizerName == "Big Energizing" then
		ShakerEffects.PlayBigEnergizingSound(contentPart)
	else
		-- Fallback al efecto básico
		ShakerEffects.PlayEnergizingSound(contentPart)
	end

	-- Efecto visual adicional: flash en las partes del juice
	if ActiveEffects.parts then
		for _, part in ipairs(ActiveEffects.parts) do
			if part.Parent then
				local originalColor = part.Color
				local flashColor = Color3.fromRGB(255, 255, 150)

				local flashTween = TweenService:Create(part, TweenInfo.new(0.1), {
					Color = flashColor
				})
				flashTween:Play()
				flashTween.Completed:Connect(function()
					local returnTween = TweenService:Create(part, TweenInfo.new(0.3), {
						Color = originalColor
					})
					returnTween:Play()
				end)

				local originalSize = part.Size
				local bigSize = originalSize * 1.2
				local scaleTween = TweenService:Create(part, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = bigSize
				})
				scaleTween:Play()
				scaleTween.Completed:Connect(function()
					local returnScale = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Size = originalSize
					})
					returnScale:Play()
				end)
			end
		end
	end
end)

------------------------------------------------------------------------
-- TOUCHPART CLICK (con efecto de presionado)
------------------------------------------------------------------------

local function onTouchPartClick()
	local plotNumber = getCurrentPlotNumber()
	if not plotNumber then return end

	-- Bloquear el botón durante el cooldown
	if currentTouchPart then
		ShakerButton.lock(currentTouchPart)

		task.delay(ShakerConfig.TOUCH_COOLDOWN, function()
			if currentTouchPart then
				ShakerButton.unlock(currentTouchPart)
			end
		end)
	end

	TouchPartClickEvent:FireServer(plotNumber)
end

------------------------------------------------------------------------
-- CANCEL POPUP (con efecto de popup)
------------------------------------------------------------------------

local function closePopup()
	if cancelPopupTrove then
		cancelPopupTrove:Destroy()
		cancelPopupTrove = nil
	end

	-- Efecto de cerrar popup
	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	local tween = TweenService:Create(warningFrame, tweenInfo, {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0)
	})
	tween:Play()
	tween.Completed:Connect(function()
		warningFrame.Visible = false
	end)
end

local function openPopup()
	if cancelPopupTrove then
		cancelPopupTrove:Destroy()
	end
	cancelPopupTrove = mainTrove:Extend()

	-- Guardar tamaño original
	local originalSize = warningFrame:GetAttribute("OriginalSize")
	if not originalSize then
		originalSize = warningFrame.Size
		warningFrame:SetAttribute("OriginalSize", originalSize)
	end

	-- Preparar para animación
	warningFrame.Size = UDim2.new(0, 0, 0, 0)
	warningFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	warningFrame.Visible = true

	-- Efecto de abrir popup
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = TweenService:Create(warningFrame, tweenInfo, {
		Size = originalSize,
		Position = UDim2.new(0.5, -originalSize.X.Offset / 2, 0.5, -originalSize.Y.Offset / 2)
	})
	tween:Play()

	-- Conectar botones
	local optionsFrame = warningFrame:FindFirstChild("Options")
	if optionsFrame then
		local yesButton = optionsFrame:FindFirstChild("Yes")
		local noButton = optionsFrame:FindFirstChild("No")

		if yesButton then
			cancelPopupTrove:Connect(yesButton.MouseButton1Click, function()
				closePopup()
				local plotNumber = getCurrentPlotNumber()
				if plotNumber then
					CancelMixingEvent:FireServer(plotNumber)
				end
			end)
		end

		if noButton then
			cancelPopupTrove:Connect(noButton.MouseButton1Click, function()
				closePopup()
			end)
		end
	end
end

------------------------------------------------------------------------
-- REMOVEPART CLICK (cancelar mezcla)
------------------------------------------------------------------------

local function onRemovePartClick()
	-- Mostrar popup de confirmación
	openPopup()
end

------------------------------------------------------------------------
-- CLICK EN MODELO (para añadir ingredientes)
------------------------------------------------------------------------

-- Detectar hover para highlight del modelo
mainTrove:Connect(RunService.RenderStepped, function()
	local target = mouse.Target
	if not target then
		clearHighlight()
		return
	end

	if isPartOfShakerModel(target) then
		local tool = getEquippedTool()
		if tool and (isIngredientTool(tool) or tool.Name:find("Energizing")) then
			applyHighlight()
		else
			clearHighlight()
		end
	else
		clearHighlight()
	end
end)

-- Detectar click en modelo
mainTrove:Connect(mouse.Button1Down, function()
	local target = mouse.Target
	if not target then return end

	local plotNumber = getCurrentPlotNumber()
	if not plotNumber then return end

	-- Click en modelo del shaker = añadir ingrediente
	if isPartOfShakerModel(target) then
		ShakerClickEvent:FireServer(plotNumber)
	end
end)

------------------------------------------------------------------------
-- SETUP PLOT
------------------------------------------------------------------------

local function loadPlotEffects(plotName)
	if currentPlotTrove then
		currentPlotTrove:Destroy()
		currentPlotTrove = nil
	end

	if cancelPopupTrove then
		cancelPopupTrove:Destroy()
		cancelPopupTrove = nil
	end

	currentTouchPart = nil
	currentRemovePart = nil
	clearHighlight()

	-- Cerrar popup si está abierto
	warningFrame.Visible = false

	if not plotName or plotName == "" then
		return
	end

	local plotFolder = plotsFolder:FindFirstChild(plotName)
	if not plotFolder then return end

	local shakerFolder = plotFolder:FindFirstChild("Shakers")
	if not shakerFolder then return end

	currentPlotTrove = mainTrove:Extend()

	-- Setup TouchPart
	local touchPart = shakerFolder:FindFirstChild("TouchPart")
	if touchPart then
		currentTouchPart = touchPart
		ShakerButton.setup(touchPart, currentPlotTrove, onTouchPartClick)
	end

	-- Setup RemovePart
	local removePart = shakerFolder:FindFirstChild("RemovePart")
	if removePart then
		currentRemovePart = removePart
		ShakerButton.setup(removePart, currentPlotTrove, onRemovePartClick)
	end
end

local function setupPlotWatcher()
	local currentPlotValue = player:WaitForChild("CurrentPlot", 10)
	if not currentPlotValue then return end

	if currentPlotValue.Value ~= "" then
		task.wait(0.3)
		loadPlotEffects(currentPlotValue.Value)
	end

	mainTrove:Connect(currentPlotValue:GetPropertyChangedSignal("Value"), function()
		task.wait(0.2)
		loadPlotEffects(currentPlotValue.Value)
	end)
end

------------------------------------------------------------------------
-- SINCRONIZACIÓN CON INGREDIENTES
------------------------------------------------------------------------

local function setupPlayerShakers()
	local playerShakers = player:WaitForChild("Shakers", 10)
	if not playerShakers then return end

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

	mainTrove:Connect(playerShakers.ChildAdded, updateVisuals)
	mainTrove:Connect(playerShakers.ChildRemoved, updateVisuals)
end

------------------------------------------------------------------------
-- INICIALIZACIÓN
------------------------------------------------------------------------

local function initialize()
	local success, err = pcall(function()
		setupPlotWatcher()
		setupPlayerShakers()
	end)

	if not success then
		warn("[ShakerClient] Error initializing:", err)
		task.wait(2)
		initialize()
	end
end

initialize()
