local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local IngredientConfig = require(ReplicatedStorage.Modules.Config.IngredientConfig)
local Trove = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("Trove"))
local ShakerLogic = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"):WaitForChild("ShakerLogic")
local ShakerManager = require(ShakerLogic:WaitForChild("ShakerManager"))
local ShakerEffects = require(ShakerLogic:WaitForChild("ShakerEffects"))

local plotsFolder = Workspace:WaitForChild("Plots")

local mainTrove = Trove.new()
local playerTroves = {}
local shakerPartsCache = {} -- Cache para trackear partes: [playerUserId_shakerNumber][ingredientKey] = juicePart
local jellyEffectTroves = {} -- Troves para efectos de gelatina: [playerUserId_shakerNumber] = trove

local function removePartWithAnimation(part)
	if not part or not part.Parent then return end

	local finalSize = part.Size
	local targetSize = finalSize * 0.01

	-- Animar la escala inversa
	local tweenInfo = TweenInfo.new(
		0.3, -- Duración más corta para remover
		Enum.EasingStyle.Back, -- Mismo estilo pero inverso
		Enum.EasingDirection.In, -- Aceleración al final (opuesto a Out)
		0,
		false,
		0
	)

	local tween = TweenService:Create(part, tweenInfo, {
		Size = targetSize
	})

	tween.Completed:Connect(function()
		tween:Destroy()
		if part and part.Parent then
			part:Destroy()
		end
	end)

	tween:Play()
end

local function clearJuiceContent(contentPart)
	if not contentPart then return end

	for _, child in ipairs(contentPart:GetChildren()) do
		-- Solo destruir partes de ingredientes (Layer_), no VFX ni otros efectos
		if child:IsA("BasePart") and child.Name ~= "Content" and string.find(child.Name, "Layer_") then
			child:Destroy()
		end
	end
end

local function createJuiceParts(contentPart, ingredients, cacheKey, mixedColor)
	clearJuiceContent(contentPart)

	-- Inicializar cache para este shaker si no existe
	if cacheKey and not shakerPartsCache[cacheKey] then
		shakerPartsCache[cacheKey] = {}
	end

	local numIngredients = #ingredients
	if numIngredients == 0 then return end

	local contentSize = contentPart.Size
	local contentCFrame = contentPart.CFrame

	local partHeight = contentSize.Y / numIngredients

	local createdParts = {}

	for i, ingredientName in ipairs(ingredients) do
		local ingredientData = IngredientConfig.Ingredients[ingredientName]
		if ingredientData then
			local juicePart = Instance.new("Part")
			juicePart.Name = "Layer_" .. ingredientName .. "_" .. i
			juicePart.Transparency = 0

			-- Si hay color de mezcla, aplicar variaciones de tonalidad
			if mixedColor then
				local variation = -0.15 + math.random() * 0.3 -- Entre -0.15 y +0.15
				local variedColor
				if variation > 0 then
					-- Más claro (lerp hacia blanco)
					variedColor = mixedColor:Lerp(Color3.new(1, 1, 1), variation)
				else
					-- Más oscuro (lerp hacia negro)
					variedColor = mixedColor:Lerp(Color3.new(0, 0, 0), -variation)
				end
				juicePart.Color = variedColor
			else
				juicePart.Color = ingredientData.Color
			end

			juicePart.Material = Enum.Material.SmoothPlastic

			-- Tamaño final
			local finalSize = Vector3.new(contentSize.X, partHeight, contentSize.Z)

			-- Guardar el tamaño base para el efecto gelatina
			juicePart:SetAttribute("BaseSize", tostring(finalSize))

			-- Empezar con tamaño diminuto
			local initialScale = 0.01
			juicePart.Size = finalSize * initialScale

			local offsetY = -(contentSize.Y / 2) + (partHeight / 2) + ((i - 1) * partHeight)
			juicePart.CFrame = contentCFrame * CFrame.new(0, offsetY, 0)

			juicePart.Anchored = true
			juicePart.CanCollide = false

			juicePart.Parent = contentPart

			-- Animar la escala suavemente
			local tweenInfo = TweenInfo.new(
				0.4, -- Duración
				Enum.EasingStyle.Back, -- Estilo con efecto de rebote
				Enum.EasingDirection.Out, -- Desaceleración al final
				0, -- No repetir
				false, -- No revertir
				0 -- Sin delay
			)

			local tween = TweenService:Create(juicePart, tweenInfo, {
				Size = finalSize
			})

			-- Limpiar el tween cuando termine
			tween.Completed:Connect(function()
				tween:Destroy()
			end)

			tween:Play()

			-- Guardar en cache usando el nombre del ingrediente
			if cacheKey then
				shakerPartsCache[cacheKey][ingredientName] = juicePart
			end

			table.insert(createdParts, juicePart)
		end
	end

	return createdParts
end

local function startJellyEffect(contentPart, ingredientParts, cacheKey, mixedColor)
	if #ingredientParts == 0 then return end

	-- Limpiar efecto anterior si existe
	if jellyEffectTroves[cacheKey] then
		jellyEffectTroves[cacheKey]:Destroy()
		jellyEffectTroves[cacheKey] = nil
	end

	local trove = Trove.new()
	jellyEffectTroves[cacheKey] = trove

	-- Función para generar variación de color
	local function getColorVariation(baseColor)
		local variation = -0.25 + math.random() * 0.3 -- Entre -0.15 y +0.15
		if variation > 0 then
			return baseColor:Lerp(Color3.new(1, 1, 1), variation)
		else
			return baseColor:Lerp(Color3.new(0, 0, 0), -variation)
		end
	end

	-- Efecto de cambio de color continuo
	if mixedColor then
		for _, part in ipairs(ingredientParts) do
			if part and part.Parent then
				local function cycleColor()
					if not part or not part.Parent then return end

					local newColor = getColorVariation(mixedColor)
					local duration = 1.5 + math.random() * 1.5 -- Entre 1.5 y 3 segundos

					local colorTween = TweenService:Create(
						part,
						TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{Color = newColor}
					)

					trove:Add(colorTween)

					colorTween.Completed:Connect(function()
						task.wait(0.1)
						cycleColor() -- Repetir el ciclo
					end)

					colorTween:Play()
				end

				-- Iniciar el ciclo de color con un delay aleatorio para cada parte
				task.delay(math.random() * 0.5, cycleColor)
			end
		end
	end

	-- Efecto de gelatina (pulsación aleatoria) - Más frecuente
	trove:Connect(RunService.Heartbeat, function()
		for _, part in ipairs(ingredientParts) do
			if part and part.Parent and math.random() < 0.03 then -- 3% de probabilidad por frame (casi 4x más frecuente)
				-- Obtener el tamaño base guardado
				local baseSizeStr = part:GetAttribute("BaseSize")
				if baseSizeStr then
					-- Parsear el Vector3
					local x, y, z = baseSizeStr:match("([%d%.]+), ([%d%.]+), ([%d%.]+)")
					if x and y and z then
						local baseSize = Vector3.new(tonumber(x), tonumber(y), tonumber(z))

						-- Variación aleatoria entre 80% y 110%
						local scale = 0.70 + math.random() * 0.40
						local targetSize = baseSize * scale

						-- Tween suave hacia el nuevo tamaño
						local pulseTween = TweenService:Create(
							part,
							TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
							{Size = targetSize}
						)

						pulseTween.Completed:Connect(function()
							-- Volver al tamaño base suavemente
							local returnTween = TweenService:Create(
								part,
								TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
								{Size = baseSize}
							)
							returnTween:Play()
							returnTween.Completed:Connect(function()
								returnTween:Destroy()
							end)
						end)

						pulseTween:Play()
					end
				end
			end
		end
	end)
end

local function clearAllShakerPartsInstantly(player, shakerNumber)
	local cacheKey = player.UserId .. "_" .. shakerNumber

	local currentPlotValue = player:FindFirstChild("CurrentPlot")
	if not currentPlotValue then return end

	local plotNumber = currentPlotValue.Value
	if plotNumber == "" then return end

	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
	if not plotFolder then return end

	local plotShakersRoot = plotFolder:FindFirstChild("Shakers")
	if not plotShakersRoot then return end

	local modelInside = plotShakersRoot:FindFirstChildWhichIsA("Model")
	if not modelInside then return end

	local realShakersFolder = modelInside:FindFirstChild("Shakers")
	if not realShakersFolder then return end

	local shakerModel = realShakersFolder:FindFirstChild(tostring(shakerNumber))
	if not shakerModel then return end

	local juicesFolder = shakerModel:FindFirstChild("Juices")
	if not juicesFolder then return end

	local contentPart = juicesFolder:FindFirstChild("Content")
	if not contentPart or not contentPart:IsA("BasePart") then return end

	-- Borrar TODAS las partes instantáneamente
	clearJuiceContent(contentPart)

	-- Limpiar caches
	shakerPartsCache[cacheKey] = {}
	if jellyEffectTroves[cacheKey] then
		jellyEffectTroves[cacheKey]:Destroy()
		jellyEffectTroves[cacheKey] = nil
	end
end

local function updateShakerJuices(player, shakerNumber)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return end

	local shakerFolder = playerShakers:FindFirstChild(tostring(shakerNumber))
	if not shakerFolder then return end

	-- Crear cacheKey único para este shaker
	local cacheKey = player.UserId .. "_" .. shakerNumber

	-- Obtener ingredientes actuales
	local currentIngredients = {}
	local currentIngredientSet = {}
	for _, ingredientFolder in ipairs(shakerFolder:GetChildren()) do
		if ingredientFolder:IsA("Folder") then
			table.insert(currentIngredients, ingredientFolder.Name)
			currentIngredientSet[ingredientFolder.Name] = true
		end
	end

	local currentPlotValue = player:FindFirstChild("CurrentPlot")
	if not currentPlotValue then return end

	local plotNumber = currentPlotValue.Value
	if plotNumber == "" then return end

	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
	if not plotFolder then return end

	local plotShakersRoot = plotFolder:FindFirstChild("Shakers")
	if not plotShakersRoot then return end

	local modelInside = plotShakersRoot:FindFirstChildWhichIsA("Model")
	if not modelInside then return end

	local realShakersFolder = modelInside:FindFirstChild("Shakers")
	if not realShakersFolder then return end

	local shakerModel = realShakersFolder:FindFirstChild(tostring(shakerNumber))
	if not shakerModel then return end

	local juicesFolder = shakerModel:FindFirstChild("Juices")
	if not juicesFolder then return end

	local contentPart = juicesFolder:FindFirstChild("Content")
	if not contentPart or not contentPart:IsA("BasePart") then return end

	-- Detectar y animar partes de ingredientes eliminados
	local partsToAnimate = {}
	if shakerPartsCache[cacheKey] then
		for ingredientName, part in pairs(shakerPartsCache[cacheKey]) do
			if not currentIngredientSet[ingredientName] then
				-- Este ingrediente fue eliminado, animar su parte
				if part and part.Parent then
					table.insert(partsToAnimate, part)
				end
			end
		end
	end

	-- Caso especial: si no hay ingredientes actuales pero hay partes en cache
	-- Animar todas las partes antes de limpiar
	if #currentIngredients == 0 and shakerPartsCache[cacheKey] then
		for _, part in pairs(shakerPartsCache[cacheKey]) do
			if part and part.Parent then
				removePartWithAnimation(part)
			end
		end
		shakerPartsCache[cacheKey] = {}

		-- Limpiar efecto gelatina
		if jellyEffectTroves[cacheKey] then
			jellyEffectTroves[cacheKey]:Destroy()
			jellyEffectTroves[cacheKey] = nil
		end

		return
	end

	-- Animar remoción de partes eliminadas
	if #partsToAnimate > 0 then
		for _, part in ipairs(partsToAnimate) do
			removePartWithAnimation(part)
		end
		-- Esperar un poco para que la animación se vea
		task.wait(0.1)
	end

	-- Limpiar el cache para este shaker
	shakerPartsCache[cacheKey] = {}

	-- Limpiar efecto gelatina anterior si existe
	if jellyEffectTroves[cacheKey] then
		jellyEffectTroves[cacheKey]:Destroy()
		jellyEffectTroves[cacheKey] = nil
	end

	-- Detectar si hay mezcla activa
	local isShakeActive = ShakerManager.IsShakeActive(player, shakerNumber)
	local mixedColor = nil

	if isShakeActive then
		local shakeKey = player.UserId .. "_" .. shakerNumber
		local shakeData = ShakerManager.ActiveShakes[shakeKey]
		if shakeData and shakeData.mixedColor then
			mixedColor = shakeData.mixedColor
		end
	end

	shakerModel:SetAttribute("Mixing", isShakeActive)

	-- Crear las partes actualizadas
	local createdParts = createJuiceParts(contentPart, currentIngredients, cacheKey, mixedColor)

	-- Si hay mezcla activa, iniciar efecto gelatina
	if isShakeActive and createdParts and #createdParts > 0 then
		startJellyEffect(contentPart, createdParts, cacheKey, mixedColor)
	end
end

local function updateAllShakerJuices(player)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return end

	for _, shakerFolder in ipairs(playerShakers:GetChildren()) do
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				updateShakerJuices(player, shakerNumber)
			end
		end
	end
end

local function connectShakerJuiceChanges(player)
	if not playerTroves[player] then
		playerTroves[player] = Trove.new()
	end
	local playerTrove = playerTroves[player]

	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return end

	playerTrove:Connect(playerShakers.ChildAdded, function(shakerFolder)
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				playerTrove:Connect(shakerFolder.ChildAdded, function()
					task.defer(function()
						updateShakerJuices(player, shakerNumber)
					end)
				end)

				playerTrove:Connect(shakerFolder.ChildRemoved, function()
					task.defer(function()
						updateShakerJuices(player, shakerNumber)
					end)
				end)

				task.defer(function()
					updateShakerJuices(player, shakerNumber)
				end)
			end
		end
	end)

	for _, shakerFolder in ipairs(playerShakers:GetChildren()) do
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				playerTrove:Connect(shakerFolder.ChildAdded, function()
					task.defer(function()
						updateShakerJuices(player, shakerNumber)
					end)
				end)

				playerTrove:Connect(shakerFolder.ChildRemoved, function()
					task.defer(function()
						updateShakerJuices(player, shakerNumber)
					end)
				end)
			end
		end
	end

	task.defer(function()
		updateAllShakerJuices(player)
	end)
end

local function monitorPlotModelChanges(player)
	if not playerTroves[player] then
		playerTroves[player] = Trove.new()
	end
	local playerTrove = playerTroves[player]

	local currentPlotValue = player:FindFirstChild("CurrentPlot")
	if not currentPlotValue then return end

	local function setupModelMonitoring()
		local plotNumber = currentPlotValue.Value
		if plotNumber == "" then return end

		local plotFolder = plotsFolder:FindFirstChild(plotNumber)
		if not plotFolder then return end

		local plotShakersRoot = plotFolder:FindFirstChild("Shakers")
		if not plotShakersRoot then
			plotShakersRoot = plotFolder:WaitForChild("Shakers", 10)
		end

		if not plotShakersRoot then return end

		playerTrove:Connect(plotShakersRoot.ChildAdded, function(child)
			if child:IsA("Model") then
				task.defer(function()
					updateAllShakerJuices(player)
				end)
			end
		end)

		playerTrove:Connect(currentPlotValue.Changed, function()
			task.defer(function()
				setupModelMonitoring()
				updateAllShakerJuices(player)
			end)
		end)
	end

	setupModelMonitoring()
end

mainTrove:Connect(Players.PlayerAdded, function(player)
	task.spawn(function()
		local currentPlot = player:FindFirstChild("CurrentPlot") or player:WaitForChild("CurrentPlot", 5)
		if currentPlot then
			connectShakerJuiceChanges(player)
			monitorPlotModelChanges(player)
		end
	end)
end)

mainTrove:Connect(Players.PlayerRemoving, function(player)
	if playerTroves[player] then
		playerTroves[player]:Destroy()
		playerTroves[player] = nil
	end

	-- Limpiar cache de partes del jugador
	local userId = player.UserId
	for cacheKey in pairs(shakerPartsCache) do
		if string.find(cacheKey, tostring(userId)) then
			shakerPartsCache[cacheKey] = nil
		end
	end

	-- Limpiar efectos gelatina del jugador
	for cacheKey in pairs(jellyEffectTroves) do
		if string.find(cacheKey, tostring(userId)) then
			jellyEffectTroves[cacheKey]:Destroy()
			jellyEffectTroves[cacheKey] = nil
		end
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		if player:FindFirstChild("CurrentPlot") then
			connectShakerJuiceChanges(player)
			monitorPlotModelChanges(player)
		end
	end)
end

-- Exponer función pública para que ShakerManager pueda forzar actualizaciones
_G.LoadSystem = _G.LoadSystem or {}
_G.LoadSystem.UpdateShakerJuices = updateShakerJuices
_G.LoadSystem.ClearAllShakerPartsInstantly = clearAllShakerPartsInstantly