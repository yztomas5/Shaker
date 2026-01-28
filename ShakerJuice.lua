local ShakerJuice = {}

local creatingJuice = {}

function ShakerJuice.CalculateIngredientPPS(ingredientFolder, ingredientData, mutationConfig)
	local basePPS = ingredientData.PricePerSec
	local multiplier = 1

	for _, child in ipairs(ingredientFolder:GetChildren()) do
		if child:IsA("StringValue") and mutationConfig[child.Name] then
			multiplier = multiplier * mutationConfig[child.Name].Multiplier
		end
	end

	return basePPS * multiplier
end

function ShakerJuice.DetermineJuiceQuality(ingredientQualities)
	local qualityOrder = {"Rare", "Unusual", "Mythical", "Legendary", "Divine", "Celestial"}
	local qualityValues = {}

	for _, quality in ipairs(ingredientQualities) do
		for i, q in ipairs(qualityOrder) do
			if q == quality then
				table.insert(qualityValues, i)
				break
			end
		end
	end

	if #qualityValues == 0 then return "Rare" end

	table.sort(qualityValues)
	local avgValue = 0
	for _, v in ipairs(qualityValues) do
		avgValue = avgValue + v
	end
	avgValue = math.floor(avgValue / #qualityValues + 0.5)

	return qualityOrder[avgValue] or "Rare"
end

function ShakerJuice.DetermineJuiceModel(sortedIngredients)
	if #sortedIngredients == 0 then return "Basic" end

	-- Elegir un ingrediente aleatorio con probabilidades iguales
	local randomIndex = math.random(1, #sortedIngredients)
	return sortedIngredients[randomIndex].category
end

function ShakerJuice.CreateJuice(player, shakerNumber, ingredientFolders, ingredientConfig, mutationConfig)
	local juiceKey = player.UserId .. "_" .. shakerNumber

	if creatingJuice[juiceKey] then
		return false
	end

	creatingJuice[juiceKey] = true

	local inventory = player:FindFirstChild("Inventory")
	if not inventory then
		creatingJuice[juiceKey] = nil
		return false
	end

	local juicesFolder = inventory:FindFirstChild("Juices")
	if not juicesFolder then
		juicesFolder = Instance.new("Folder")
		juicesFolder.Name = "Juices"
		juicesFolder.Parent = inventory
	end

	if #ingredientFolders == 0 then
		creatingJuice[juiceKey] = nil
		return false
	end

	local ingredientsData = {}
	local totalPrice = 0
	local totalPPS = 0
	local qualities = {}

	for _, folder in ipairs(ingredientFolders) do
		local ingredientName = folder.Name
		local ingredientInfo = ingredientConfig.Ingredients[ingredientName]

		if ingredientInfo then
			local pps = ShakerJuice.CalculateIngredientPPS(folder, ingredientInfo, mutationConfig)

			table.insert(ingredientsData, {
				folder = folder,
				name = ingredientName,
				price = ingredientInfo.Price,
				pps = pps,
				pronoun = ingredientInfo.Pronoun,
				category = ingredientInfo.Category,
				quality = ingredientInfo.Quality
			})

			totalPrice = totalPrice + ingredientInfo.Price
			totalPPS = totalPPS + pps
			table.insert(qualities, ingredientInfo.Quality)
		end
	end

	table.sort(ingredientsData, function(a, b) return a.price > b.price end)

	local juiceQuality = ShakerJuice.DetermineJuiceQuality(qualities)
	local juiceModel = ShakerJuice.DetermineJuiceModel(ingredientsData)

	local pronouns = {}
	for _, data in ipairs(ingredientsData) do
		table.insert(pronouns, data.pronoun)
	end
	local juiceName = juiceModel .. " " .. table.concat(pronouns, " ")

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

	for _, data in ipairs(ingredientsData) do
		local folder = data.folder
		local idValue = folder:FindFirstChild("Id")
		if idValue then
			idValue:Destroy()
		end
		folder.Parent = ingredientsContainer
	end

	creatingJuice[juiceKey] = nil

	return true
end

return ShakerJuice