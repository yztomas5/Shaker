--[[
	ShakerServer - Script principal del servidor
	Maneja toda la lógica de shakers, mezclas, XP

	Estructura esperada en Workspace:
	Plots/{PlotNumber}/Shakers/{ShakerNumber}/
		├─ Ingredients/Content
		├─ Info/BillboardGui/Content/{Filler, Amount}
		├─ Add (Part con ProximityPrompt)
		└─ TouchPart (Part)
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Módulos
local Modules = script.Parent.Parent.Modules
local Config = require(Modules.ShakerConfig)
local Utils = require(Modules.ShakerUtils)
local Inventory = require(Modules.ShakerInventory)
local Juice = require(Modules.ShakerJuice)
local Data = require(Modules.ShakerData)

local IngredientConfig = require(ReplicatedStorage.Modules.Config.IngredientConfig)

-- Crear RemoteEvents
local eventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder", ReplicatedStorage)
eventsFolder.Name = "RemoteEvents"

local shakersFolder = eventsFolder:FindFirstChild("Shakers") or Instance.new("Folder", eventsFolder)
shakersFolder.Name = "Shakers"

local function createEvent(name)
	local event = shakersFolder:FindFirstChild(name) or Instance.new("RemoteEvent", shakersFolder)
	event.Name = name
	return event
end

local Events = {
	StartMixing = createEvent("StartMixing"),
	StopMixing = createEvent("StopMixing"),
	UpdateProgress = createEvent("UpdateProgress"),
	CompleteMixing = createEvent("CompleteMixing")
}

local warningEvent = ReplicatedStorage.RemoteEvents.Warn.Warning

-- Estado
local ActiveShakes = {} -- [shakeKey] = {player, shakerNumber, currentXp, requiredXp, mixedColor}
local TouchCooldowns = {} -- [playerId] = lastTouchTime
local SetupShakers = {} -- [shakerKey] = true

local plotsFolder = Workspace:WaitForChild("Plots")

------------------------------------------------------------------------
-- FUNCIONES DE MEZCLA
------------------------------------------------------------------------

local function calculateRequiredXp(ingredientFolders)
	local totalXp = 0
	for _, folder in ipairs(ingredientFolders) do
		local info = IngredientConfig.Ingredients[folder.Name]
		if info and info.Xp then
			totalXp = totalXp + info.Xp
		end
	end
	return totalXp
end

local function getIngredientColors(ingredientFolders)
	local colors = {}
	for _, folder in ipairs(ingredientFolders) do
		local info = IngredientConfig.Ingredients[folder.Name]
		if info and info.Color then
			table.insert(colors, info.Color)
		end
	end
	return colors
end

local function updateBillboard(player, shakerNumber, currentXp, requiredXp, enabled)
	local billboard = Utils.GetBillboard(player, shakerNumber)
	if not billboard then return end

	billboard.Enabled = enabled

	if enabled then
		local content = billboard:FindFirstChild("Content")
		if content then
			local filler = content:FindFirstChild("Filler")
			local amount = content:FindFirstChild("Amount")

			if filler then
				local progress = requiredXp > 0 and math.clamp(currentXp / requiredXp, 0, 1) or 0
				filler.Size = UDim2.new(progress, 0, 1, 0)
			end

			if amount then
				amount.Text = Utils.FormatXp(currentXp) .. " / " .. Utils.FormatXp(requiredXp)
			end
		end
	end
end

local function startMixing(player, shakerNumber)
	local shakeKey = player.UserId .. "_" .. shakerNumber

	local ingredients = Inventory.GetIngredients(player, shakerNumber)
	if #ingredients == 0 then return false end

	local requiredXp = calculateRequiredXp(ingredients)
	local colors = getIngredientColors(ingredients)
	local mixedColor = Utils.MixColors(colors)

	-- Si ya está activo, actualizar valores
	if ActiveShakes[shakeKey] then
		ActiveShakes[shakeKey].requiredXp = requiredXp
		ActiveShakes[shakeKey].mixedColor = mixedColor
		updateBillboard(player, shakerNumber, ActiveShakes[shakeKey].currentXp, requiredXp, true)
		Events.StartMixing:FireClient(player, shakerNumber, mixedColor)
		return true
	end

	ActiveShakes[shakeKey] = {
		player = player,
		shakerNumber = shakerNumber,
		currentXp = 0,
		requiredXp = requiredXp,
		mixedColor = mixedColor
	}

	updateBillboard(player, shakerNumber, 0, requiredXp, true)
	Events.StartMixing:FireClient(player, shakerNumber, mixedColor)

	return true
end

local function stopMixing(player, shakerNumber, returnIngredients)
	local shakeKey = player.UserId .. "_" .. shakerNumber

	if not ActiveShakes[shakeKey] then return false end

	if returnIngredients then
		Inventory.ReturnAll(player, shakerNumber)
	end

	updateBillboard(player, shakerNumber, 0, 0, false)
	Events.StopMixing:FireClient(player, shakerNumber)

	ActiveShakes[shakeKey] = nil
	return true
end

local function completeMixing(player, shakerNumber)
	local shakeKey = player.UserId .. "_" .. shakerNumber
	local shakeData = ActiveShakes[shakeKey]
	if not shakeData then return end

	local ingredients = Inventory.GetIngredients(player, shakerNumber)
	local mixedColor = shakeData.mixedColor

	-- Crear jugo
	Juice.Create(player, ingredients)

	-- Limpiar shaker
	Inventory.Clear(player, shakerNumber)

	updateBillboard(player, shakerNumber, 0, 0, false)
	Events.CompleteMixing:FireClient(player, shakerNumber, mixedColor)

	warningEvent:FireClient(player, "Your juice is ready!", "Juice")

	ActiveShakes[shakeKey] = nil
end

local function addXp(player, shakerNumber, amount)
	local shakeKey = player.UserId .. "_" .. shakerNumber
	local shakeData = ActiveShakes[shakeKey]
	if not shakeData then return false end

	shakeData.currentXp = shakeData.currentXp + amount

	updateBillboard(player, shakerNumber, shakeData.currentXp, shakeData.requiredXp, true)
	Events.UpdateProgress:FireClient(player, shakerNumber, shakeData.currentXp, shakeData.requiredXp)

	if shakeData.currentXp >= shakeData.requiredXp then
		completeMixing(player, shakerNumber)
	end

	return true
end

local function increaseRequiredXp(player, shakerNumber, percentage)
	local shakeKey = player.UserId .. "_" .. shakerNumber
	local shakeData = ActiveShakes[shakeKey]
	if not shakeData then return false end

	local increase = math.floor(shakeData.requiredXp * percentage)
	shakeData.requiredXp = shakeData.requiredXp + increase

	updateBillboard(player, shakerNumber, shakeData.currentXp, shakeData.requiredXp, true)
	Events.UpdateProgress:FireClient(player, shakerNumber, shakeData.currentXp, shakeData.requiredXp)

	return true
end

------------------------------------------------------------------------
-- INTERACCIONES
------------------------------------------------------------------------

local function handleAddInteraction(player, shakerNumber, plotNumber)
	if player.CurrentPlot.Value ~= plotNumber then return end

	local character = player.Character
	if not character then return end

	local tool = Utils.GetEquippedTool(character)
	local isActive = ActiveShakes[player.UserId .. "_" .. shakerNumber] ~= nil
	local count = Inventory.Count(player, shakerNumber)

	-- Si está mezclando y tiene energizante
	if isActive and tool then
		local energizerPercent = Config.ENERGIZERS[tool.Name]
		if energizerPercent then
			local toolId = Utils.GetToolId(tool)
			if toolId then
				local gearFolder = Inventory.FindGear(player, tool.Name, toolId)
				if gearFolder then
					tool:Destroy()
					gearFolder:Destroy()
					increaseRequiredXp(player, shakerNumber, energizerPercent)
					return
				end
			end
		end
	end

	-- Si está mezclando, cancelar
	if isActive then
		stopMixing(player, shakerNumber, true)
		return
	end

	-- Añadir ingrediente
	if tool and Utils.IsIngredientTool(tool) and count < Config.MAX_INGREDIENTS then
		local toolId = Utils.GetToolId(tool)
		if toolId then
			local ingredientFolder = Inventory.FindIngredient(player, tool.Name, toolId)
			if ingredientFolder then
				tool:Destroy()
				Inventory.Add(player, shakerNumber, ingredientFolder)
				startMixing(player, shakerNumber)
				return
			end
		end
	end

	-- Remover ingrediente
	if count > 0 and not isActive then
		Inventory.RemoveLast(player, shakerNumber)

		-- Si quedan ingredientes, recalcular
		local newCount = Inventory.Count(player, shakerNumber)
		if newCount > 0 then
			startMixing(player, shakerNumber)
		end
	end
end

local function handleTouchPart(player, shakerNumber, plotNumber)
	if player.CurrentPlot.Value ~= plotNumber then return end

	local now = tick()
	local lastTouch = TouchCooldowns[player.UserId] or 0
	if now - lastTouch < Config.TOUCH_COOLDOWN then return end
	TouchCooldowns[player.UserId] = now

	local shakeKey = player.UserId .. "_" .. shakerNumber
	if not ActiveShakes[shakeKey] then return end

	addXp(player, shakerNumber, Config.XP_PER_TOUCH)
end

------------------------------------------------------------------------
-- SETUP DE SHAKERS
------------------------------------------------------------------------

local function setupShaker(shakerFolder, shakerNumber, plotNumber)
	local shakerKey = plotNumber .. "_" .. shakerNumber
	if SetupShakers[shakerKey] then return end
	SetupShakers[shakerKey] = true

	local addPart = shakerFolder:FindFirstChild("Add")
	local touchPart = shakerFolder:FindFirstChild("TouchPart")

	if addPart then
		-- Crear ProximityPrompt si no existe
		local prompt = addPart:FindFirstChild("Prompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "Prompt"
			prompt.ActionText = "Interact"
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Parent = addPart
		end

		prompt.Triggered:Connect(function(player)
			handleAddInteraction(player, shakerNumber, plotNumber)
		end)

		-- Actualizar texto del prompt
		RunService.Heartbeat:Connect(function()
			for _, player in ipairs(Players:GetPlayers()) do
				local currentPlot = player:FindFirstChild("CurrentPlot")
				if currentPlot and currentPlot.Value == plotNumber then
					local character = player.Character
					if character then
						local hrp = character:FindFirstChild("HumanoidRootPart")
						if hrp and (hrp.Position - addPart.Position).Magnitude <= 10 then
							local tool = Utils.GetEquippedTool(character)
							local isActive = ActiveShakes[player.UserId .. "_" .. shakerNumber] ~= nil
							local count = Inventory.Count(player, shakerNumber)

							if isActive and tool and Config.ENERGIZERS[tool.Name] then
								prompt.ActionText = "Add " .. tool.Name
								prompt.Enabled = true
							elseif isActive then
								prompt.ActionText = "Cancel"
								prompt.Enabled = true
							elseif tool and Utils.IsIngredientTool(tool) and count < Config.MAX_INGREDIENTS then
								prompt.ActionText = "Add (" .. count .. "/" .. Config.MAX_INGREDIENTS .. ")"
								prompt.Enabled = true
							elseif count > 0 then
								prompt.ActionText = "Remove (" .. count .. "/" .. Config.MAX_INGREDIENTS .. ")"
								prompt.Enabled = true
							else
								prompt.Enabled = false
							end
						end
					end
				end
			end
		end)
	end

	if touchPart then
		touchPart.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end
			local player = Players:GetPlayerFromCharacter(character)
			if not player then return end

			handleTouchPart(player, shakerNumber, plotNumber)
		end)
	end
end

local function setupPlot(plotFolder)
	local plotNumber = plotFolder.Name
	local shakersRoot = plotFolder:FindFirstChild("Shakers")
	if not shakersRoot then return end

	for _, shakerFolder in ipairs(shakersRoot:GetChildren()) do
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				setupShaker(shakerFolder, shakerNumber, plotNumber)
			end
		end
	end

	shakersRoot.ChildAdded:Connect(function(shakerFolder)
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				setupShaker(shakerFolder, shakerNumber, plotNumber)
			end
		end
	end)
end

------------------------------------------------------------------------
-- SINCRONIZACIÓN DE FOLDERS DEL JUGADOR
------------------------------------------------------------------------

local function syncPlayerShakers(player)
	local currentPlot = player:FindFirstChild("CurrentPlot")
	if not currentPlot or currentPlot.Value == "" then return end

	local playerShakers = Data.EnsureShakersFolder(player)
	local plotFolder = plotsFolder:FindFirstChild(currentPlot.Value)
	if not plotFolder then return end

	local shakersRoot = plotFolder:FindFirstChild("Shakers")
	if not shakersRoot then return end

	-- Sincronizar folders
	local desired = {}
	for _, shakerFolder in ipairs(shakersRoot:GetChildren()) do
		if shakerFolder:IsA("Folder") then
			desired[shakerFolder.Name] = true
		end
	end

	for _, folder in ipairs(playerShakers:GetChildren()) do
		if folder:IsA("Folder") and not desired[folder.Name] then
			folder:Destroy()
		end
	end

	for name in pairs(desired) do
		if not playerShakers:FindFirstChild(name) then
			local newFolder = Instance.new("Folder")
			newFolder.Name = name
			newFolder.Parent = playerShakers
		end
	end
end

------------------------------------------------------------------------
-- EVENTOS DE JUGADORES
------------------------------------------------------------------------

local function onPlayerAdded(player)
	Data.EnsureShakersFolder(player)
	TouchCooldowns[player.UserId] = 0

	-- Esperar CurrentPlot
	local currentPlot = player:WaitForChild("CurrentPlot", 10)
	if currentPlot then
		currentPlot.Changed:Connect(function()
			syncPlayerShakers(player)
		end)

		task.wait(1)
		syncPlayerShakers(player)

		-- Cargar datos guardados
		local savedShakes = Data.Load(player)
		if savedShakes then
			for shakerNumber, shakeData in pairs(savedShakes) do
				local num = tonumber(shakerNumber)
				if num and shakeData.RequiredXp > 0 and shakeData.CurrentXp < shakeData.RequiredXp then
					task.spawn(function()
						task.wait(0.5)
						local ingredients = Inventory.GetIngredients(player, num)
						if #ingredients > 0 then
							local colors = getIngredientColors(ingredients)
							local mixedColor = Utils.MixColors(colors)

							ActiveShakes[player.UserId .. "_" .. num] = {
								player = player,
								shakerNumber = num,
								currentXp = shakeData.CurrentXp,
								requiredXp = shakeData.RequiredXp,
								mixedColor = mixedColor
							}

							updateBillboard(player, num, shakeData.CurrentXp, shakeData.RequiredXp, true)
							Events.StartMixing:FireClient(player, num, mixedColor)
						end
					end)
				end
			end
		end
	end
end

local function onPlayerRemoving(player)
	Data.Save(player, ActiveShakes)
	TouchCooldowns[player.UserId] = nil

	-- Limpiar mezclas activas
	for key in pairs(ActiveShakes) do
		if key:find(tostring(player.UserId)) then
			ActiveShakes[key] = nil
		end
	end
end

------------------------------------------------------------------------
-- INICIALIZACIÓN
------------------------------------------------------------------------

-- Setup plots existentes
for _, plotFolder in ipairs(plotsFolder:GetChildren()) do
	task.spawn(function()
		setupPlot(plotFolder)
	end)
end

plotsFolder.ChildAdded:Connect(function(plotFolder)
	task.wait(0.5)
	setupPlot(plotFolder)
end)

-- Jugadores
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		onPlayerAdded(player)
	end)
end

-- Auto-guardado periódico
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(function()
				Data.Save(player, ActiveShakes)
			end)
		end
	end
end)

-- Guardar al cerrar
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		Data.Save(player, ActiveShakes)
	end
	task.wait(3)
end)
