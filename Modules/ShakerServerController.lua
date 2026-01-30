--[[
	ShakerServerController - Controlador principal del servidor
	Maneja toda la lógica de mezcla
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShakerSystem = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"):WaitForChild("ShakerSystem")
local Config = require(ShakerSystem.ShakerConfig)
local Utils = require(ShakerSystem.ShakerUtils)
local Inventory = require(ShakerSystem.ShakerInventory)
local Juice = require(ShakerSystem.ShakerJuice)
local Data = require(ShakerSystem.ShakerData)

local IngredientConfig = require(ReplicatedStorage.Modules.Config.IngredientConfig)

local ShakerServerController = {}

local plotsFolder = Workspace:WaitForChild("Plots")

-- State
local ActiveShakes = {}
local TouchCooldowns = {}
local ClickCooldowns = {}

-- Events (set by init)
local Events = {}

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
-- LIMPIEZA DE PLOT
------------------------------------------------------------------------

local function cleanupPlotVisuals(plotNumber)
	if not plotNumber then return end

	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
	if not plotFolder then return end

	local shakerFolder = plotFolder:FindFirstChild("Shakers")
	if not shakerFolder then return end

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
				-- Limpiar partes de juice (Layer_)
				if child:IsA("BasePart") and child.Name:find("Layer_") then
					child:Destroy()
				end
				-- Limpiar partículas
				if child:IsA("ParticleEmitter") then
					child:Destroy()
				end
				-- Limpiar sonidos
				if child:IsA("Sound") then
					child:Stop()
					child:Destroy()
				end
			end
		end
	end

	-- Limpiar modelo también por si acaso
	local modelFolder = shakerFolder:FindFirstChild("Model")
	if modelFolder then
		for _, model in ipairs(modelFolder:GetChildren()) do
			if model:IsA("Model") then
				-- Limpiar highlights
				local highlight = model:FindFirstChild("ShakerHighlight")
				if highlight then
					highlight:Destroy()
				end
			end
		end
	end
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

	local ingredients = Inventory.GetIngredients(player)
	if #ingredients == 0 then return false end

	local requiredXp = calculateRequiredXp(ingredients)
	local mixedColor = getMixedColor(ingredients)

	if ActiveShakes[key] then
		ActiveShakes[key].requiredXp = requiredXp
		ActiveShakes[key].mixedColor = mixedColor
		-- Resetear isReady porque ahora hay más XP requerido
		ActiveShakes[key].isReady = false
	else
		ActiveShakes[key] = {
			player = player,
			currentXp = 0,
			requiredXp = requiredXp,
			mixedColor = mixedColor,
			isReady = false
		}
	end

	updateBillboard(player, ActiveShakes[key].currentXp, requiredXp, true)
	Events.StartMixing:FireClient(player, mixedColor)

	return true
end

local function stopMixing(player, returnIngredients)
	local key = player.UserId

	if not ActiveShakes[key] then return end

	if returnIngredients then
		Inventory.ReturnAll(player)
	end

	updateBillboard(player, 0, 0, false)
	Events.StopMixing:FireClient(player)

	ActiveShakes[key] = nil
end

local function completeMixing(player)
	local key = player.UserId
	local data = ActiveShakes[key]
	if not data then return end

	local ingredients = Inventory.GetIngredients(player)
	Juice.Create(player, ingredients)
	Inventory.Clear(player)

	updateBillboard(player, 0, 0, false)
	Events.CompleteMixing:FireClient(player, data.mixedColor)
	Events.Warning:FireClient(player, "Your juice is ready!", "Juice")

	ActiveShakes[key] = nil
end

local function addXp(player, amount)
	local key = player.UserId
	local data = ActiveShakes[key]
	if not data then return end

	-- Si ya está listo, no añadir más XP
	if data.isReady then return end

	data.currentXp = math.min(data.currentXp + amount, data.requiredXp)

	updateBillboard(player, data.currentXp, data.requiredXp, true)
	Events.UpdateProgress:FireClient(player, data.currentXp, data.requiredXp)

	-- Marcar como listo pero NO completar automáticamente
	if data.currentXp >= data.requiredXp then
		data.isReady = true
	end
end

------------------------------------------------------------------------
-- HANDLERS
------------------------------------------------------------------------

function ShakerServerController.handleShakerClick(player, plotNumber)
	local currentPlotNumber = getPlotNumber(player)
	if not currentPlotNumber or currentPlotNumber ~= plotNumber then return end

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

	-- Energizante
	if isActive and tool then
		local percent = Config.ENERGIZERS[tool.Name]
		if percent then
			local toolId = Utils.GetToolId(tool)
			local gear = toolId and Inventory.FindGear(player, tool.Name, toolId)
			if gear then
				local data = ActiveShakes[key]

				-- Si ya está listo, no añadir más energizantes
				if data.isReady then return end

				tool:Destroy()
				gear:Destroy()

				local xpToAdd = math.floor(data.requiredXp * percent)
				data.currentXp = math.min(data.currentXp + xpToAdd, data.requiredXp)

				updateBillboard(player, data.currentXp, data.requiredXp, true)
				Events.UpdateProgress:FireClient(player, data.currentXp, data.requiredXp)
				Events.EnergizingAdded:FireClient(player, xpToAdd, tool.Name)

				-- Marcar como listo pero NO completar automáticamente
				if data.currentXp >= data.requiredXp then
					data.isReady = true
				end
				return
			end
		end
	end

	-- Ingrediente
	if tool and Utils.IsIngredientTool(tool) and count < Config.MAX_INGREDIENTS then
		local toolId = Utils.GetToolId(tool)
		local ingredient = toolId and Inventory.FindIngredient(player, tool.Name, toolId)
		if ingredient then
			local ingredientInfo = IngredientConfig.Ingredients[tool.Name]
			local ingredientColor = ingredientInfo and ingredientInfo.Color or nil
			tool:Destroy()
			Inventory.Add(player, ingredient)
			Events.IngredientAdded:FireClient(player, ingredientColor)
			startMixing(player)
		end
	end
end

function ShakerServerController.handleTouchPartClick(player, plotNumber)
	local currentPlotNumber = getPlotNumber(player)
	if not currentPlotNumber or currentPlotNumber ~= plotNumber then return end

	local now = tick()
	local last = TouchCooldowns[player.UserId] or 0
	if now - last < Config.TOUCH_COOLDOWN then return end
	TouchCooldowns[player.UserId] = now

	local key = player.UserId
	if not ActiveShakes[key] then return end

	-- Si la mezcla está lista, completarla con el toque final
	if ActiveShakes[key].isReady then
		completeMixing(player)
		return
	end

	addXp(player, Config.XP_PER_TOUCH)
end

function ShakerServerController.handleCancelMixing(player, plotNumber)
	local currentPlotNumber = getPlotNumber(player)
	if not currentPlotNumber or currentPlotNumber ~= plotNumber then return end

	local key = player.UserId
	if not ActiveShakes[key] then return end

	stopMixing(player, true)
end

------------------------------------------------------------------------
-- PLAYER LIFECYCLE
------------------------------------------------------------------------

function ShakerServerController.onPlayerAdded(player)
	Data.EnsureShakersFolder(player)
	TouchCooldowns[player.UserId] = 0
	ClickCooldowns[player.UserId] = 0

	local currentPlot = player:WaitForChild("CurrentPlot", 15)
	if not currentPlot then return end

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
				Events.StartMixing:FireClient(player, ActiveShakes[key].mixedColor)
			end
		end
	end

	currentPlot.Changed:Connect(function()
		local key = player.UserId
		if ActiveShakes[key] then
			stopMixing(player, true)
		end
		task.spawn(restoreMixing)
	end)

	task.spawn(restoreMixing)
end

function ShakerServerController.onPlayerRemoving(player)
	-- Obtener la plot del jugador antes de limpiar
	local plotNumber = getPlotNumber(player)

	-- Limpiar todos los visuales de la plot
	cleanupPlotVisuals(plotNumber)

	-- Limpiar estado
	TouchCooldowns[player.UserId] = nil
	ClickCooldowns[player.UserId] = nil
	ActiveShakes[player.UserId] = nil
end

------------------------------------------------------------------------
-- INIT
------------------------------------------------------------------------

function ShakerServerController.init(events)
	Events = events
end

return ShakerServerController
