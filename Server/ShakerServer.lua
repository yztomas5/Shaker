--[[
	ShakerServer - Script principal del servidor

	Estructura en Workspace:
	Plots/{PlotNumber}/Shakers/  <-- El shaker (solo hay uno por plot)
		├── Ingredients/Content
		├── Model/{ModelName}
		├── Info/BillboardGui/Content/{Filler, Amount}
		└── TouchPart
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Módulos
local ShakerSystem = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"):WaitForChild("ShakerSystem")
local Config = require(ShakerSystem.ShakerConfig)
local Utils = require(ShakerSystem.ShakerUtils)
local Inventory = require(ShakerSystem.ShakerInventory)
local Juice = require(ShakerSystem.ShakerJuice)
local Data = require(ShakerSystem.ShakerData)

local IngredientConfig = require(ReplicatedStorage.Modules.Config.IngredientConfig)

print("[ShakerServer] Inicializando...")

-- RemoteEvents
local eventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "RemoteEvents"
	eventsFolder.Parent = ReplicatedStorage
end

local shakersFolder = eventsFolder:FindFirstChild("Shakers")
if not shakersFolder then
	shakersFolder = Instance.new("Folder")
	shakersFolder.Name = "Shakers"
	shakersFolder.Parent = eventsFolder
end

local function getOrCreateEvent(name)
	local event = shakersFolder:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = shakersFolder
	end
	return event
end

local StartMixingEvent = getOrCreateEvent("StartMixing")
local StopMixingEvent = getOrCreateEvent("StopMixing")
local UpdateProgressEvent = getOrCreateEvent("UpdateProgress")
local CompleteMixingEvent = getOrCreateEvent("CompleteMixing")
local ShakerClickEvent = getOrCreateEvent("ShakerClick")
local TouchPartClickEvent = getOrCreateEvent("TouchPartClick")
local CancelMixingEvent = getOrCreateEvent("CancelMixing")
local IngredientAddedEvent = getOrCreateEvent("IngredientAdded")
local IngredientRemovedEvent = getOrCreateEvent("IngredientRemoved")
local EnergizingAddedEvent = getOrCreateEvent("EnergizingAdded")

local warningEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Warn"):WaitForChild("Warning")

-- Estado global (key = UserId ya que solo hay un shaker por plot)
local ActiveShakes = {} -- [UserId] = {player, currentXp, requiredXp, mixedColor}
local TouchCooldowns = {}
local ClickCooldowns = {}

local plotsFolder = Workspace:WaitForChild("Plots")

------------------------------------------------------------------------
-- UTILIDADES
------------------------------------------------------------------------

local function getPlotNumber(player)
	local currentPlot = player:FindFirstChild("CurrentPlot")
	if currentPlot and currentPlot.Value ~= "" then
		return currentPlot.Value
	end
	return nil
end

local function getShakerFolder(player)
	local plotNumber = getPlotNumber(player)
	if not plotNumber then return nil end

	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
	if not plotFolder then return nil end

	return plotFolder:FindFirstChild("Shakers")
end

local function getBillboard(player)
	local shakerFolder = getShakerFolder(player)
	if not shakerFolder then return nil end

	local info = shakerFolder:FindFirstChild("Info")
	if not info then return nil end

	return info:FindFirstChild("BillboardGui")
end

------------------------------------------------------------------------
-- BILLBOARD
------------------------------------------------------------------------

local function updateBillboard(player, currentXp, requiredXp, enabled)
	local billboard = getBillboard(player)
	if not billboard then return end

	billboard.Enabled = enabled

	if enabled and requiredXp > 0 then
		local content = billboard:FindFirstChild("Content")
		if content then
			local filler = content:FindFirstChild("Filler")
			local amount = content:FindFirstChild("Amount")

			if filler then
				local progress = math.clamp(currentXp / requiredXp, 0, 1)
				filler.Size = UDim2.new(progress, 0, 1, 0)
			end

			if amount then
				amount.Text = Utils.FormatXp(currentXp) .. " / " .. Utils.FormatXp(requiredXp)
			end
		end
	end
end

------------------------------------------------------------------------
-- MEZCLA
------------------------------------------------------------------------

local function calculateRequiredXp(ingredients)
	local total = 0
	for _, folder in ipairs(ingredients) do
		local info = IngredientConfig.Ingredients[folder.Name]
		if info and info.Xp then
			total = total + info.Xp
		end
	end
	return total
end

local function getMixedColor(ingredients)
	local colors = {}
	for _, folder in ipairs(ingredients) do
		local info = IngredientConfig.Ingredients[folder.Name]
		if info and info.Color then
			table.insert(colors, info.Color)
		end
	end
	return Utils.MixColors(colors)
end

local function startMixing(player)
	local key = player.UserId
	print("[ShakerServer] Iniciando mezcla para:", player.Name)

	local ingredients = Inventory.GetIngredients(player)
	if #ingredients == 0 then
		print("[ShakerServer] No hay ingredientes")
		return false
	end

	local requiredXp = calculateRequiredXp(ingredients)
	local mixedColor = getMixedColor(ingredients)

	print("[ShakerServer] XP requerida:", requiredXp, "Ingredientes:", #ingredients)

	if ActiveShakes[key] then
		ActiveShakes[key].requiredXp = requiredXp
		ActiveShakes[key].mixedColor = mixedColor
	else
		ActiveShakes[key] = {
			player = player,
			currentXp = 0,
			requiredXp = requiredXp,
			mixedColor = mixedColor
		}
	end

	updateBillboard(player, ActiveShakes[key].currentXp, requiredXp, true)
	StartMixingEvent:FireClient(player, mixedColor)

	return true
end

local function stopMixing(player, returnIngredients)
	local key = player.UserId
	print("[ShakerServer] Deteniendo mezcla para:", player.Name)

	if not ActiveShakes[key] then return end

	if returnIngredients then
		Inventory.ReturnAll(player)
	end

	updateBillboard(player, 0, 0, false)
	StopMixingEvent:FireClient(player)

	ActiveShakes[key] = nil
end

local function completeMixing(player)
	local key = player.UserId
	local data = ActiveShakes[key]
	if not data then return end

	print("[ShakerServer] Completando mezcla para:", player.Name)

	local ingredients = Inventory.GetIngredients(player)
	Juice.Create(player, ingredients)
	Inventory.Clear(player)

	updateBillboard(player, 0, 0, false)
	CompleteMixingEvent:FireClient(player, data.mixedColor)
	warningEvent:FireClient(player, "Your juice is ready!", "Juice")

	ActiveShakes[key] = nil
end

local function addXp(player, amount)
	local key = player.UserId
	local data = ActiveShakes[key]
	if not data then return end

	data.currentXp = data.currentXp + amount

	updateBillboard(player, data.currentXp, data.requiredXp, true)
	UpdateProgressEvent:FireClient(player, data.currentXp, data.requiredXp)

	if data.currentXp >= data.requiredXp then
		completeMixing(player)
	end
end

------------------------------------------------------------------------
-- CLICK EN SHAKER (añadir/remover ingrediente)
------------------------------------------------------------------------

local function handleShakerClick(player, plotNumber)
	-- Verificar plot
	local currentPlotNumber = getPlotNumber(player)
	if not currentPlotNumber or currentPlotNumber ~= plotNumber then
		print("[ShakerServer] Plot incorrecto:", currentPlotNumber, "vs", plotNumber)
		return
	end

	-- Cooldown
	local now = tick()
	local lastClick = ClickCooldowns[player.UserId] or 0
	if now - lastClick < Config.INTERACTION_COOLDOWN then return end
	ClickCooldowns[player.UserId] = now

	local character = player.Character
	if not character then return end

	local key = player.UserId
	local isActive = ActiveShakes[key] ~= nil
	local tool = Utils.GetEquippedTool(character)
	local count = Inventory.Count(player)

	print("[ShakerServer] Click en shaker - isActive:", isActive, "tool:", tool and tool.Name, "count:", count)

	-- Energizante durante mezcla (suma XP basado en % del total requerido)
	if isActive and tool then
		local percent = Config.ENERGIZERS[tool.Name]
		if percent then
			local toolId = Utils.GetToolId(tool)
			local gear = toolId and Inventory.FindGear(player, tool.Name, toolId)
			if gear then
				print("[ShakerServer] Añadiendo energizante:", tool.Name)
				tool:Destroy()
				gear:Destroy()

				local data = ActiveShakes[key]
				local xpToAdd = math.floor(data.requiredXp * percent)
				data.currentXp = data.currentXp + xpToAdd

				print("[ShakerServer] Energizante añadió", xpToAdd, "XP. Ahora:", data.currentXp, "/", data.requiredXp)

				updateBillboard(player, data.currentXp, data.requiredXp, true)
				UpdateProgressEvent:FireClient(player, data.currentXp, data.requiredXp)
				EnergizingAddedEvent:FireClient(player, xpToAdd, tool.Name)

				-- Verificar si se completó
				if data.currentXp >= data.requiredXp then
					completeMixing(player)
				end
				return
			end
		end
	end

	-- Añadir ingrediente
	if tool and Utils.IsIngredientTool(tool) and count < Config.MAX_INGREDIENTS then
		local toolId = Utils.GetToolId(tool)
		local ingredient = toolId and Inventory.FindIngredient(player, tool.Name, toolId)
		if ingredient then
			print("[ShakerServer] Añadiendo ingrediente:", tool.Name)
			-- Obtener color del ingrediente para efectos
			local ingredientInfo = IngredientConfig.Ingredients[tool.Name]
			local ingredientColor = ingredientInfo and ingredientInfo.Color or nil
			tool:Destroy()
			Inventory.Add(player, ingredient)
			IngredientAddedEvent:FireClient(player, ingredientColor)
			startMixing(player)
			return
		else
			print("[ShakerServer] No se encontró ingrediente en inventario")
		end
	end
end

-- Escuchar evento de click del cliente
ShakerClickEvent.OnServerEvent:Connect(function(player, plotNumber)
	print("[ShakerServer] Click recibido de:", player.Name, "plot:", plotNumber)
	handleShakerClick(player, plotNumber)
end)

------------------------------------------------------------------------
-- TOUCH PART CLICK (añadir XP)
------------------------------------------------------------------------

local function handleTouchPartClick(player, plotNumber)
	local currentPlotNumber = getPlotNumber(player)
	if not currentPlotNumber or currentPlotNumber ~= plotNumber then return end

	local now = tick()
	local last = TouchCooldowns[player.UserId] or 0
	if now - last < Config.TOUCH_COOLDOWN then return end
	TouchCooldowns[player.UserId] = now

	local key = player.UserId
	if not ActiveShakes[key] then return end

	print("[ShakerServer] TouchPart click - añadiendo XP")
	addXp(player, Config.XP_PER_TOUCH)
end

TouchPartClickEvent.OnServerEvent:Connect(function(player, plotNumber)
	handleTouchPartClick(player, plotNumber)
end)

------------------------------------------------------------------------
-- CANCEL MIXING (RemovePart)
------------------------------------------------------------------------

local function handleCancelMixing(player, plotNumber)
	local currentPlotNumber = getPlotNumber(player)
	if not currentPlotNumber or currentPlotNumber ~= plotNumber then return end

	local key = player.UserId
	if not ActiveShakes[key] then return end

	print("[ShakerServer] Cancelando mezcla para:", player.Name)
	stopMixing(player, true)
end

CancelMixingEvent.OnServerEvent:Connect(function(player, plotNumber)
	handleCancelMixing(player, plotNumber)
end)

------------------------------------------------------------------------
-- SETUP SHAKERS
------------------------------------------------------------------------

local function setupPlot(plotFolder)
	local plotNumber = plotFolder.Name
	local shakerFolder = plotFolder:FindFirstChild("Shakers")

	if not shakerFolder then
		print("[ShakerServer] No se encontró Shakers en plot:", plotNumber)
		return
	end

	print("[ShakerServer] Setup plot:", plotNumber)
end

------------------------------------------------------------------------
-- JUGADORES
------------------------------------------------------------------------

local function onPlayerAdded(player)
	print("[ShakerServer] Jugador conectado:", player.Name)

	Data.EnsureShakersFolder(player)
	TouchCooldowns[player.UserId] = 0
	ClickCooldowns[player.UserId] = 0

	local currentPlot = player:WaitForChild("CurrentPlot", 15)
	if not currentPlot then
		print("[ShakerServer] CurrentPlot no encontrado para:", player.Name)
		return
	end

	-- Restaurar mezcla guardada
	local function restoreMixing()
		task.wait(1)
		local saved = Data.Load(player)
		if saved and saved.RequiredXp and saved.RequiredXp > 0 and saved.CurrentXp < saved.RequiredXp then
			local ingredients = Inventory.GetIngredients(player)
			if #ingredients > 0 then
				local key = player.UserId
				ActiveShakes[key] = {
					player = player,
					currentXp = saved.CurrentXp,
					requiredXp = saved.RequiredXp,
					mixedColor = getMixedColor(ingredients)
				}
				updateBillboard(player, saved.CurrentXp, saved.RequiredXp, true)
				StartMixingEvent:FireClient(player, ActiveShakes[key].mixedColor)
				print("[ShakerServer] Mezcla restaurada para:", player.Name)
			end
		end
	end

	currentPlot.Changed:Connect(function()
		-- Limpiar estado anterior si cambia de plot
		local key = player.UserId
		if ActiveShakes[key] then
			stopMixing(player, true)
		end
		task.spawn(restoreMixing)
	end)

	task.spawn(restoreMixing)
end

local function onPlayerRemoving(player)
	print("[ShakerServer] Jugador desconectado:", player.Name)

	-- Guardar datos
	Data.Save(player, ActiveShakes)

	-- Obtener la plot del jugador antes de limpiar
	local plotNumber = getPlotNumber(player)
	if plotNumber then
		local plotFolder = plotsFolder:FindFirstChild(plotNumber)
		if plotFolder then
			local shakerFolder = plotFolder:FindFirstChild("Shakers")
			if shakerFolder then
				-- Desactivar billboard
				local info = shakerFolder:FindFirstChild("Info")
				if info then
					local billboard = info:FindFirstChild("BillboardGui")
					if billboard then
						billboard.Enabled = false
					end
				end

				-- Limpiar contenido visual de ingredientes
				local ingredientsFolder = shakerFolder:FindFirstChild("Ingredients")
				if ingredientsFolder then
					local contentPart = ingredientsFolder:FindFirstChild("Content")
					if contentPart then
						for _, child in ipairs(contentPart:GetChildren()) do
							if child:IsA("BasePart") and child.Name:find("Layer_") then
								child:Destroy()
							end
						end
					end
				end
			end
		end
	end

	-- Limpiar estado
	TouchCooldowns[player.UserId] = nil
	ClickCooldowns[player.UserId] = nil
	ActiveShakes[player.UserId] = nil
end

------------------------------------------------------------------------
-- INICIALIZACIÓN
------------------------------------------------------------------------

for _, plotFolder in ipairs(plotsFolder:GetChildren()) do
	task.spawn(function()
		setupPlot(plotFolder)
	end)
end

plotsFolder.ChildAdded:Connect(function(plotFolder)
	task.wait(0.5)
	setupPlot(plotFolder)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			Data.Save(player, ActiveShakes)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		Data.Save(player, ActiveShakes)
	end
	task.wait(2)
end)

print("[ShakerServer] Inicialización completa")
