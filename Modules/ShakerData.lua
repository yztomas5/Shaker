--[[
	ShakerData - Persistencia de datos de shakers
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
	profile.Data.Shakers.ShakerContents = {}
	profile.Data.Shakers.ActiveShakes = {}

	-- Guardar contenido de shakers
	for _, shakerFolder in ipairs(playerShakers:GetChildren()) do
		if shakerFolder:IsA("Folder") then
			local shakerNumber = shakerFolder.Name
			profile.Data.Shakers.ShakerContents[shakerNumber] = {}

			for _, child in ipairs(shakerFolder:GetChildren()) do
				if child:IsA("Folder") then
					table.insert(profile.Data.Shakers.ShakerContents[shakerNumber], serializeFolder(child))
				end
			end
		end
	end

	-- Guardar mezclas activas
	if activeShakes then
		for shakeKey, shakeData in pairs(activeShakes) do
			if shakeData.player == player then
				profile.Data.Shakers.ActiveShakes[tostring(shakeData.shakerNumber)] = {
					CurrentXp = shakeData.currentXp,
					RequiredXp = shakeData.requiredXp
				}
			end
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

	-- Cargar contenido de shakers
	if profile.Data.Shakers.ShakerContents then
		for shakerNumber, contents in pairs(profile.Data.Shakers.ShakerContents) do
			local shakerFolder = playerShakers:FindFirstChild(shakerNumber)
			if not shakerFolder then
				shakerFolder = Instance.new("Folder")
				shakerFolder.Name = shakerNumber
				shakerFolder.Parent = playerShakers
			else
				shakerFolder:ClearAllChildren()
			end

			for _, childData in ipairs(contents) do
				if childData.ClassName == "Folder" then
					deserializeFolder(childData, shakerFolder)
				end
			end
		end
	end

	return profile.Data.Shakers.ActiveShakes
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
