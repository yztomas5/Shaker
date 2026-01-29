--[[
	ShakerData - Persistencia de datos de shakers
	Solo hay un shaker - guarda ingredientes directamente en player.Shakers
	Guarda: ingredientes + XP actual/requerida
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShakerData = {}

-- Serializar valor
local function serializeValue(instance)
	return {
		ClassName = instance.ClassName,
		Name = instance.Name,
		Value = instance.Value
	}
end

-- Serializar folder
local function serializeFolder(folder)
	local data = {
		ClassName = "Folder",
		Name = folder.Name,
		Contents = {}
	}

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Folder") then
			table.insert(data.Contents, serializeFolder(child))
		elseif child:IsA("ValueBase") then
			table.insert(data.Contents, serializeValue(child))
		end
	end

	return data
end

-- Deserializar valor
local function deserializeValue(data, parent)
	local instance = Instance.new(data.ClassName)
	instance.Name = data.Name
	if data.Value ~= nil then
		instance.Value = data.Value
	end
	instance.Parent = parent
	return instance
end

-- Deserializar folder
local function deserializeFolder(data, parent)
	local folder = Instance.new("Folder")
	folder.Name = data.Name
	folder.Parent = parent

	if data.Contents then
		for _, childData in ipairs(data.Contents) do
			if childData.ClassName == "Folder" then
				deserializeFolder(childData, folder)
			else
				deserializeValue(childData, folder)
			end
		end
	end

	return folder
end

-- Guardar datos de shakers del jugador
function ShakerData.Save(player, activeShakes)
	local DataSaver = require(ReplicatedStorage.Modules.Data.DataSaver)
	local profile = DataSaver.GetProfile(player)
	if not profile then return end

	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return end

	profile.Data.Shakers = profile.Data.Shakers or {}
	profile.Data.Shakers.Ingredients = {}
	profile.Data.Shakers.CurrentXp = 0
	profile.Data.Shakers.RequiredXp = 0

	-- Guardar ingredientes (están directamente en player.Shakers)
	for _, child in ipairs(playerShakers:GetChildren()) do
		if child:IsA("Folder") then
			table.insert(profile.Data.Shakers.Ingredients, serializeFolder(child))
		end
	end

	-- Guardar mezcla activa
	if activeShakes then
		local key = player.UserId
		local shakeData = activeShakes[key]
		if shakeData then
			profile.Data.Shakers.CurrentXp = shakeData.currentXp
			profile.Data.Shakers.RequiredXp = shakeData.requiredXp
		end
	end
end

-- Cargar datos de shakers del jugador
function ShakerData.Load(player)
	local DataSaver = require(ReplicatedStorage.Modules.Data.DataSaver)
	local profile = DataSaver.GetProfile(player)
	if not profile or not profile.Data.Shakers then return nil end

	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then
		playerShakers = Instance.new("Folder")
		playerShakers.Name = "Shakers"
		playerShakers.Parent = player
	end

	-- Limpiar contenido actual
	for _, child in ipairs(playerShakers:GetChildren()) do
		if child:IsA("Folder") then
			child:Destroy()
		end
	end

	-- Cargar ingredientes
	if profile.Data.Shakers.Ingredients then
		for _, childData in ipairs(profile.Data.Shakers.Ingredients) do
			if childData.ClassName == "Folder" then
				deserializeFolder(childData, playerShakers)
			end
		end
	end

	-- Devolver datos de mezcla activa
	return {
		CurrentXp = profile.Data.Shakers.CurrentXp or 0,
		RequiredXp = profile.Data.Shakers.RequiredXp or 0
	}
end

-- Asegurar folder de shakers existe
function ShakerData.EnsureShakersFolder(player)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then
		playerShakers = Instance.new("Folder")
		playerShakers.Name = "Shakers"
		playerShakers.Parent = player
	end
	return playerShakers
end

return ShakerData
