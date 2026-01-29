--[[
	ShakerInventory - Manejo de ingredientes en shakers
	Solo hay un shaker por plot, los ingredientes van directo en player.Shakers
]]

local ShakerInventory = {}

-- Obtener folders de ingredientes en el shaker
function ShakerInventory.GetIngredients(player)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return {} end

	local folders = {}
	for _, child in ipairs(playerShakers:GetChildren()) do
		if child:IsA("Folder") then
			table.insert(folders, child)
		end
	end
	return folders
end

-- Contar ingredientes
function ShakerInventory.Count(player)
	return #ShakerInventory.GetIngredients(player)
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
function ShakerInventory.Add(player, ingredientFolder)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return false end

	local idValue = ingredientFolder:FindFirstChild("Id")
	if idValue then idValue:Destroy() end

	ingredientFolder.Parent = playerShakers
	return true
end

-- Remover último ingrediente del shaker
function ShakerInventory.RemoveLast(player)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return false end

	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return false end

	local ingredients = inventory:FindFirstChild("Ingredients")
	if not ingredients then
		ingredients = Instance.new("Folder")
		ingredients.Name = "Ingredients"
		ingredients.Parent = inventory
	end

	local ingredientFolder = playerShakers:FindFirstChildOfClass("Folder")
	if not ingredientFolder then return false end

	ingredientFolder.Parent = ingredients
	return true
end

-- Devolver todos los ingredientes al inventario
function ShakerInventory.ReturnAll(player)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return false end

	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return false end

	local ingredients = inventory:FindFirstChild("Ingredients")
	if not ingredients then
		ingredients = Instance.new("Folder")
		ingredients.Name = "Ingredients"
		ingredients.Parent = inventory
	end

	for _, child in ipairs(playerShakers:GetChildren()) do
		if child:IsA("Folder") then
			child.Parent = ingredients
		end
	end
	return true
end

-- Limpiar todos los ingredientes (para cuando se crea jugo)
function ShakerInventory.Clear(player)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return end

	for _, child in ipairs(playerShakers:GetChildren()) do
		if child:IsA("Folder") then
			child:Destroy()
		end
	end
end

return ShakerInventory
