local Players = game:GetService("Players")

local ShakerInventory = {}

function ShakerInventory.GetIngredientFolders(player, shakerNumber)
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

function ShakerInventory.CountIngredients(player, shakerNumber)
	return #ShakerInventory.GetIngredientFolders(player, shakerNumber)
end

function ShakerInventory.IsFull(player, shakerNumber, maxIngredients)
	return ShakerInventory.CountIngredients(player, shakerNumber) >= maxIngredients
end

function ShakerInventory.IsEmpty(player, shakerNumber)
	return ShakerInventory.CountIngredients(player, shakerNumber) == 0
end

function ShakerInventory.FindIngredientInPlayerInventory(player, toolName, toolId)
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return nil end

	local ingredients = inventory:FindFirstChild("Ingredients")
	if not ingredients then return nil end

	for _, ingredientFolder in ipairs(ingredients:GetChildren()) do
		if ingredientFolder:IsA("Folder") and ingredientFolder.Name == toolName then
			local idValue = ingredientFolder:FindFirstChild("Id")
			if idValue and idValue:IsA("IntValue") and idValue.Value == toolId then
				return ingredientFolder
			end
		end
	end

	return nil
end

function ShakerInventory.FindGearInPlayerInventory(player, gearName, toolId)
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return nil end

	local gears = inventory:FindFirstChild("Gears")
	if not gears then return nil end

	for _, gearFolder in ipairs(gears:GetChildren()) do
		if gearFolder:IsA("Folder") and gearFolder.Name == gearName then
			local idValue = gearFolder:FindFirstChild("Id")
			if idValue and idValue:IsA("IntValue") and idValue.Value == toolId then
				return gearFolder
			end
		end
	end

	return nil
end

function ShakerInventory.AddIngredient(player, shakerNumber, ingredientFolder)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return false end

	local shakerFolder = playerShakers:FindFirstChild(tostring(shakerNumber))
	if not shakerFolder then return false end

	local idValue = ingredientFolder:FindFirstChild("Id")
	if idValue then
		idValue:Destroy()
	end

	ingredientFolder.Parent = shakerFolder
	task.wait(0.1)

	return ingredientFolder.Parent == shakerFolder
end

function ShakerInventory.RemoveIngredient(player, shakerNumber)
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

	local ingredientName = ingredientFolder.Name

	ingredientFolder.Parent = ingredients
	task.wait(0.1)
	return ingredientFolder.Parent == ingredients
end

function ShakerInventory.ReturnAllIngredients(player, shakerNumber)
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

return ShakerInventory