--[[
	ShakerServer - Script principal del servidor

	Estructura en Workspace:
	Plots/{PlotNumber}/Shakers/{ShakerNumber}/
		├─ Ingredients/Content
		├─ Info/BillboardGui/Content/{Filler, Amount}
		├─ Add (Part)
		└─ TouchPart (Part)
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

local warningEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Warn"):WaitForChild("Warning")

-- Estado global
local ActiveShakes = {}
local TouchCooldowns = {}

local plotsFolder = Workspace:WaitForChild("Plots")

------------------------------------------------------------------------
-- BILLBOARD
------------------------------------------------------------------------

local function updateBillboard(player, shakerNumber, currentXp, requiredXp, enabled)
	local billboard = Utils.GetBillboard(player, shakerNumber)
	if not billboard then
		print("[ShakerServer] Billboard no encontrado para shaker", shakerNumber)
		return
	end

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

local function startMixing(player, shakerNumber)
	local key = player.UserId .. "_" .. shakerNumber
	print("[ShakerServer] Iniciando mezcla:", key)

	local ingredients = Inventory.GetIngredients(player, shakerNumber)
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
			shakerNumber = shakerNumber,
			currentXp = 0,
			requiredXp = requiredXp,
			mixedColor = mixedColor
		}
	end

	updateBillboard(player, shakerNumber, ActiveShakes[key].currentXp, requiredXp, true)
	StartMixingEvent:FireClient(player, shakerNumber, mixedColor)

	return true
end

local function stopMixing(player, shakerNumber, returnIngredients)
	local key = player.UserId .. "_" .. shakerNumber
	print("[ShakerServer] Deteniendo mezcla:", key)

	if not ActiveShakes[key] then return end

	if returnIngredients then
		Inventory.ReturnAll(player, shakerNumber)
	end

	updateBillboard(player, shakerNumber, 0, 0, false)
	StopMixingEvent:FireClient(player, shakerNumber)

	ActiveShakes[key] = nil
end

local function completeMixing(player, shakerNumber)
	local key = player.UserId .. "_" .. shakerNumber
	local data = ActiveShakes[key]
	if not data then return end

	print("[ShakerServer] Completando mezcla:", key)

	local ingredients = Inventory.GetIngredients(player, shakerNumber)
	Juice.Create(player, ingredients)
	Inventory.Clear(player, shakerNumber)

	updateBillboard(player, shakerNumber, 0, 0, false)
	CompleteMixingEvent:FireClient(player, shakerNumber, data.mixedColor)
	warningEvent:FireClient(player, "Your juice is ready!", "Juice")

	ActiveShakes[key] = nil
end

local function addXp(player, shakerNumber, amount)
	local key = player.UserId .. "_" .. shakerNumber
	local data = ActiveShakes[key]
	if not data then return end

	data.currentXp = data.currentXp + amount

	updateBillboard(player, shakerNumber, data.currentXp, data.requiredXp, true)
	UpdateProgressEvent:FireClient(player, shakerNumber, data.currentXp, data.requiredXp)

	if data.currentXp >= data.requiredXp then
		completeMixing(player, shakerNumber)
	end
end

------------------------------------------------------------------------
-- INTERACCIÓN ADD
------------------------------------------------------------------------

local function onAddTriggered(player, shakerNumber, plotNumber)
	local currentPlot = player:FindFirstChild("CurrentPlot")
	if not currentPlot or currentPlot.Value ~= plotNumber then
		print("[ShakerServer] Plot incorrecto")
		return
	end

	local character = player.Character
	if not character then return end

	local key = player.UserId .. "_" .. shakerNumber
	local isActive = ActiveShakes[key] ~= nil
	local tool = Utils.GetEquippedTool(character)
	local count = Inventory.Count(player, shakerNumber)

	print("[ShakerServer] Add triggered - isActive:", isActive, "tool:", tool and tool.Name, "count:", count)

	-- Energizante durante mezcla
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
				local increase = math.floor(data.requiredXp * percent)
				data.requiredXp = data.requiredXp + increase

				updateBillboard(player, shakerNumber, data.currentXp, data.requiredXp, true)
				UpdateProgressEvent:FireClient(player, shakerNumber, data.currentXp, data.requiredXp)
				return
			end
		end
	end

	-- Cancelar mezcla
	if isActive then
		print("[ShakerServer] Cancelando mezcla")
		stopMixing(player, shakerNumber, true)
		return
	end

	-- Añadir ingrediente
	if tool and Utils.IsIngredientTool(tool) and count < Config.MAX_INGREDIENTS then
		local toolId = Utils.GetToolId(tool)
		local ingredient = toolId and Inventory.FindIngredient(player, tool.Name, toolId)
		if ingredient then
			print("[ShakerServer] Añadiendo ingrediente:", tool.Name)
			tool:Destroy()
			Inventory.Add(player, shakerNumber, ingredient)
			startMixing(player, shakerNumber)
			return
		end
	end

	-- Remover ingrediente
	if count > 0 then
		print("[ShakerServer] Removiendo ingrediente")
		Inventory.RemoveLast(player, shakerNumber)

		local newCount = Inventory.Count(player, shakerNumber)
		if newCount > 0 then
			startMixing(player, shakerNumber)
		end
	end
end

------------------------------------------------------------------------
-- TOUCH PART
------------------------------------------------------------------------

local function onTouchPart(player, shakerNumber, plotNumber)
	local currentPlot = player:FindFirstChild("CurrentPlot")
	if not currentPlot or currentPlot.Value ~= plotNumber then return end

	local now = tick()
	local last = TouchCooldowns[player.UserId] or 0
	if now - last < Config.TOUCH_COOLDOWN then return end
	TouchCooldowns[player.UserId] = now

	local key = player.UserId .. "_" .. shakerNumber
	if not ActiveShakes[key] then return end

	addXp(player, shakerNumber, Config.XP_PER_TOUCH)
end

------------------------------------------------------------------------
-- SETUP SHAKERS
------------------------------------------------------------------------

local function setupShaker(shakerFolder, shakerNumber, plotNumber)
	print("[ShakerServer] Setup shaker:", plotNumber, shakerNumber)

	local addPart = shakerFolder:FindFirstChild("Add")
	local touchPart = shakerFolder:FindFirstChild("TouchPart")

	if addPart then
		-- Buscar o crear prompt
		local prompt = addPart:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "Prompt"
			prompt.ActionText = "Interact"
			prompt.ObjectText = "Shaker"
			prompt.HoldDuration = 0.2
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Parent = addPart
		end

		prompt.Triggered:Connect(function(triggerPlayer)
			onAddTriggered(triggerPlayer, shakerNumber, plotNumber)
		end)

		print("[ShakerServer] ProximityPrompt configurado en Add")
	else
		print("[ShakerServer] ADVERTENCIA: No se encontró parte Add")
	end

	if touchPart then
		touchPart.Touched:Connect(function(hit)
			local character = hit.Parent
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local touchPlayer = humanoid and Players:GetPlayerFromCharacter(character)

			if touchPlayer then
				onTouchPart(touchPlayer, shakerNumber, plotNumber)
			end
		end)
		print("[ShakerServer] TouchPart configurado")
	else
		print("[ShakerServer] ADVERTENCIA: No se encontró TouchPart")
	end
end

local function setupPlot(plotFolder)
	local plotNumber = plotFolder.Name
	local shakersRoot = plotFolder:FindFirstChild("Shakers")

	if not shakersRoot then
		print("[ShakerServer] No se encontró Shakers en plot:", plotNumber)
		return
	end

	print("[ShakerServer] Setup plot:", plotNumber)

	for _, child in ipairs(shakersRoot:GetChildren()) do
		if child:IsA("Folder") then
			local num = tonumber(child.Name)
			if num then
				setupShaker(child, num, plotNumber)
			end
		end
	end

	shakersRoot.ChildAdded:Connect(function(child)
		if child:IsA("Folder") then
			local num = tonumber(child.Name)
			if num then
				task.wait(0.1)
				setupShaker(child, num, plotNumber)
			end
		end
	end)
end

------------------------------------------------------------------------
-- SINCRONIZAR FOLDERS DEL JUGADOR
------------------------------------------------------------------------

local function syncPlayerShakers(player)
	local currentPlot = player:FindFirstChild("CurrentPlot")
	if not currentPlot or currentPlot.Value == "" then return end

	local playerShakers = Data.EnsureShakersFolder(player)
	local plotFolder = plotsFolder:FindFirstChild(currentPlot.Value)
	if not plotFolder then return end

	local shakersRoot = plotFolder:FindFirstChild("Shakers")
	if not shakersRoot then return end

	-- Obtener shakers deseados
	local desired = {}
	for _, child in ipairs(shakersRoot:GetChildren()) do
		if child:IsA("Folder") then
			desired[child.Name] = true
		end
	end

	-- Eliminar los que sobran
	for _, folder in ipairs(playerShakers:GetChildren()) do
		if folder:IsA("Folder") and not desired[folder.Name] then
			folder:Destroy()
		end
	end

	-- Crear los que faltan
	for name in pairs(desired) do
		if not playerShakers:FindFirstChild(name) then
			local f = Instance.new("Folder")
			f.Name = name
			f.Parent = playerShakers
		end
	end

	print("[ShakerServer] Shakers sincronizados para:", player.Name)
end

------------------------------------------------------------------------
-- JUGADORES
------------------------------------------------------------------------

local function onPlayerAdded(player)
	print("[ShakerServer] Jugador conectado:", player.Name)

	Data.EnsureShakersFolder(player)
	TouchCooldowns[player.UserId] = 0

	local currentPlot = player:WaitForChild("CurrentPlot", 15)
	if not currentPlot then
		print("[ShakerServer] CurrentPlot no encontrado para:", player.Name)
		return
	end

	currentPlot.Changed:Connect(function()
		syncPlayerShakers(player)
	end)

	task.wait(1)
	syncPlayerShakers(player)

	-- Restaurar mezclas guardadas
	local saved = Data.Load(player)
	if saved then
		for shakerNum, shakeData in pairs(saved) do
			local num = tonumber(shakerNum)
			if num and shakeData.RequiredXp > 0 and shakeData.CurrentXp < shakeData.RequiredXp then
				task.spawn(function()
					task.wait(1)
					local ingredients = Inventory.GetIngredients(player, num)
					if #ingredients > 0 then
						local key = player.UserId .. "_" .. num
						ActiveShakes[key] = {
							player = player,
							shakerNumber = num,
							currentXp = shakeData.CurrentXp,
							requiredXp = shakeData.RequiredXp,
							mixedColor = getMixedColor(ingredients)
						}
						updateBillboard(player, num, shakeData.CurrentXp, shakeData.RequiredXp, true)
						StartMixingEvent:FireClient(player, num, ActiveShakes[key].mixedColor)
						print("[ShakerServer] Mezcla restaurada:", key)
					end
				end)
			end
		end
	end
end

local function onPlayerRemoving(player)
	print("[ShakerServer] Jugador desconectado:", player.Name)

	Data.Save(player, ActiveShakes)
	TouchCooldowns[player.UserId] = nil

	-- Limpiar mezclas activas
	local prefix = tostring(player.UserId) .. "_"
	for key in pairs(ActiveShakes) do
		if key:sub(1, #prefix) == prefix then
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
	task.spawn(onPlayerAdded, player)
end

-- Auto-guardado
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
