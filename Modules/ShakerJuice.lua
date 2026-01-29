--[[
	ShakerJuice - Creación de jugos a partir de ingredientes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShakerJuice = {}

local QUALITY_ORDER = {"Rare", "Unusual", "Mythical", "Legendary", "Divine", "Celestial"}

-- Calcular PPS con mutaciones
local function calculatePPS(ingredientFolder, ingredientData, mutationConfig)
	local basePPS = ingredientData.PricePerSec or 0
	local multiplier = 1

	for _, child in ipairs(ingredientFolder:GetChildren()) do
		if child:IsA("StringValue") and mutationConfig[child.Name] then
			multiplier = multiplier * mutationConfig[child.Name].Multiplier
		end
	end

	return basePPS * multiplier
end

-- Determinar calidad del jugo
local function determineQuality(qualities)
	local values = {}

	for _, quality in ipairs(qualities) do
		for i, q in ipairs(QUALITY_ORDER) do
			if q == quality then
				table.insert(values, i)
				break
			end
		end
	end

	if #values == 0 then return "Rare" end

	local sum = 0
	for _, v in ipairs(values) do sum = sum + v end
	local avg = math.floor(sum / #values + 0.5)

	return QUALITY_ORDER[avg] or "Rare"
end

-- Crear jugo a partir de ingredientes
function ShakerJuice.Create(player, ingredientFolders)
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return false end

	local juicesFolder = inventory:FindFirstChild("Juices")
	if not juicesFolder then
		juicesFolder = Instance.new("Folder")
		juicesFolder.Name = "Juices"
		juicesFolder.Parent = inventory
	end

	if #ingredientFolders == 0 then return false end

	-- Obtener configs
	local IngredientConfig = require(ReplicatedStorage.Modules.Config.IngredientConfig)
	local MutationConfig = require(ReplicatedStorage.Modules.Config.MutationConfig)

	local ingredientsData = {}
	local totalPrice = 0
	local totalPPS = 0
	local qualities = {}

	for _, folder in ipairs(ingredientFolders) do
		local info = IngredientConfig.Ingredients[folder.Name]
		if info then
			local pps = calculatePPS(folder, info, MutationConfig)

			table.insert(ingredientsData, {
				folder = folder,
				name = folder.Name,
				price = info.Price or 0,
				pps = pps,
				pronoun = info.Pronoun or "",
				category = info.Category or "Basic",
				quality = info.Quality or "Rare"
			})

			totalPrice = totalPrice + (info.Price or 0)
			totalPPS = totalPPS + pps
			table.insert(qualities, info.Quality or "Rare")
		end
	end

	-- Ordenar por precio
	table.sort(ingredientsData, function(a, b) return a.price > b.price end)

	local juiceQuality = determineQuality(qualities)

	-- Elegir modelo aleatorio
	local juiceModel = "Basic"
	if #ingredientsData > 0 then
		juiceModel = ingredientsData[math.random(1, #ingredientsData)].category
	end

	-- Construir nombre
	local pronouns = {}
	for _, data in ipairs(ingredientsData) do
		table.insert(pronouns, data.pronoun)
	end
	local juiceName = juiceModel .. " " .. table.concat(pronouns, " ")

	-- Crear folder del jugo
	local juiceFolder = Instance.new("Folder")
	juiceFolder.Name = juiceName
	juiceFolder.Parent = juicesFolder

	local qualityValue = Instance.new("StringValue")
	qualityValue.Name = "Quality"
	qualityValue.Value = juiceQuality
	qualityValue.Parent = juiceFolder

	local modelValue = Instance.new("StringValue")
	modelValue.Name = "Model"
	modelValue.Value = juiceModel
	modelValue.Parent = juiceFolder

	local priceValue = Instance.new("IntValue")
	priceValue.Name = "Price"
	priceValue.Value = totalPrice
	priceValue.Parent = juiceFolder

	local ppsValue = Instance.new("IntValue")
	ppsValue.Name = "PricePerSec"
	ppsValue.Value = math.floor(totalPPS)
	ppsValue.Parent = juiceFolder

	local slotValue = Instance.new("IntValue")
	slotValue.Name = "Slot"
	slotValue.Value = 0
	slotValue.Parent = juiceFolder

	local ingredientsContainer = Instance.new("Folder")
	ingredientsContainer.Name = "Ingredients"
	ingredientsContainer.Parent = juiceFolder

	-- Mover ingredientes al jugo
	for _, data in ipairs(ingredientsData) do
		local idValue = data.folder:FindFirstChild("Id")
		if idValue then idValue:Destroy() end
		data.folder.Parent = ingredientsContainer
	end

	return true
end

return ShakerJuice
