--[[
	ShakerInventory - Manejo de ingredientes en shakers
	Añadir, remover, contar ingredientes
]]

local ShakerInventory = {}

-- Obtener folders de ingredientes en un shaker
function ShakerInventory.GetIngredients(player, shakerNumber)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return {} end

	local shakerFolder = playerShakers:FindFirstChild(tostring(shakerNumber))
	if not shakerFolder then return {} end

	local folders = {}
	for _, child in ipairs(shakerFolder:GetChildren()) do
		if child:IsA("Folder") then
			table.insert(folders, child)
		end
	end
	return folders
end

-- Contar ingredientes
function ShakerInventory.Count(player, shakerNumber)
	return #ShakerInventory.GetIngredients(player, shakerNumber)
end

-- Buscar ingrediente en inventario del jugador
function ShakerInventory.FindIngredient(player, name, id)
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return nil end

	local ingredients = inventory:FindFirstChild("Ingredients")
	if not ingredients then return nil end

	for _, folder in ipairs(ingredients:GetChildren()) do
		if folder:IsA("Folder") and folder.Name == name then
			local idValue = folder:FindFirstChild("Id")
			if idValue and idValue:IsA("IntValue") and idValue.Value == id then
				return folder
			end
		end
	end
	return nil
end

-- Buscar gear en inventario del jugador
function ShakerInventory.FindGear(player, name, id)
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return nil end

	local gears = inventory:FindFirstChild("Gears")
	if not gears then return nil end

	for _, folder in ipairs(gears:GetChildren()) do
		if folder:IsA("Folder") and folder.Name == name then
			local idValue = folder:FindFirstChild("Id")
			if idValue and idValue:IsA("IntValue") and idValue.Value == id then
				return folder
			end
		end
	end
	return nil
end

-- Añadir ingrediente al shaker
function ShakerInventory.Add(player, shakerNumber, ingredientFolder)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return false end

	local shakerFolder = playerShakers:FindFirstChild(tostring(shakerNumber))
	if not shakerFolder then return false end

	local idValue = ingredientFolder:FindFirstChild("Id")
	if idValue then idValue:Destroy() end

	ingredientFolder.Parent = shakerFolder
	return true
end

-- Remover último ingrediente del shaker
function ShakerInventory.RemoveLast(player, shakerNumber)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return false end

	local shakerFolder = playerShakers:FindFirstChild(tostring(shakerNumber))
	if not shakerFolder then return false end

	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return false end

	local ingredients = inventory:FindFirstChild("Ingredients")
	if not ingredients then
		ingredients = Instance.new("Folder")
		ingredients.Name = "Ingredients"
		ingredients.Parent = inventory
	end

	local ingredientFolder = shakerFolder:FindFirstChildOfClass("Folder")
	if not ingredientFolder then return false end

	ingredientFolder.Parent = ingredients
	return true
end

-- Devolver todos los ingredientes al inventario
function ShakerInventory.ReturnAll(player, shakerNumber)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return false end

	local shakerFolder = playerShakers:FindFirstChild(tostring(shakerNumber))
	if not shakerFolder then return false end

	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return false end

	local ingredients = inventory:FindFirstChild("Ingredients")
	if not ingredients then
		ingredients = Instance.new("Folder")
		ingredients.Name = "Ingredients"
		ingredients.Parent = inventory
	end

	for _, child in ipairs(shakerFolder:GetChildren()) do
		if child:IsA("Folder") then
			child.Parent = ingredients
		end
	end
	return true
end

-- Limpiar todos los ingredientes (para cuando se crea jugo)
function ShakerInventory.Clear(player, shakerNumber)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return end

	local shakerFolder = playerShakers:FindFirstChild(tostring(shakerNumber))
	if not shakerFolder then return end

	for _, child in ipairs(shakerFolder:GetChildren()) do
		if child:IsA("Folder") then
			child:Destroy()
		end
	end
end

return ShakerInventory
