local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local DataModules = Modules:WaitForChild("Data")

local Trove = require(DataModules:WaitForChild("Trove"))
local DataSaver = require(DataModules:WaitForChild("DataSaver"))

local mainTrove = Trove.new()
local playerTroves = {}

local ShakerPersistence = {}

local ShakerManager = nil
local ShakerJuice = nil
local ShakerEffects = nil
local ShakerModel = nil
local IngredientConfig = nil
local MutationConfig = nil

local function InitializeDependencies()
	if ShakerManager then return end

	local ShakerLogic = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"):WaitForChild("ShakerLogic")
	ShakerManager = require(ShakerLogic:WaitForChild("ShakerManager"))
	ShakerJuice = require(ShakerLogic:WaitForChild("ShakerJuice"))
	ShakerEffects = require(ShakerLogic:WaitForChild("ShakerEffects"))
	ShakerModel = require(ShakerLogic:WaitForChild("ShakerModel"))

	IngredientConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("IngredientConfig"))
	MutationConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("MutationConfig"))
end

local function SerializeValue(instance)
	return {
		ClassName = instance.ClassName,
		Name = instance.Name,
		Value = instance.Value
	}
end

local function SerializeFolder(folder)
	local data = {
		ClassName = "Folder",
		Name = folder.Name,
		Contents = {}
	}

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Folder") then
			table.insert(data.Contents, SerializeFolder(child))
		elseif child:IsA("ValueBase") then
			table.insert(data.Contents, SerializeValue(child))
		end
	end

	return data
end

local function DeserializeValue(data, parent)
	local instance = Instance.new(data.ClassName)
	instance.Name = data.Name
	if data.Value ~= nil then
		instance.Value = data.Value
	end
	instance.Parent = parent
	return instance
end

local function DeserializeFolder(data, parent)
	local folder = Instance.new("Folder")
	folder.Name = data.Name
	folder.Parent = parent

	if data.Contents then
		for _, childData in ipairs(data.Contents) do
			if childData.ClassName == "Folder" then
				DeserializeFolder(childData, folder)
			else
				DeserializeValue(childData, folder)
			end
		end
	end

	return folder
end

function ShakerPersistence.UpdatePlayerData(player)
	local profile = DataSaver.GetProfile(player)
	if not profile then return end

	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return end

	profile.Data.Shakers.ShakerContents = {}
	profile.Data.Shakers.ActiveShakes = {}
	profile.Data.Shakers.SaveTime = os.time()

	for _, shakerFolder in ipairs(playerShakers:GetChildren()) do
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				profile.Data.Shakers.ShakerContents[tostring(shakerNumber)] = {}

				for _, child in ipairs(shakerFolder:GetChildren()) do
					if child:IsA("Folder") then
						table.insert(profile.Data.Shakers.ShakerContents[tostring(shakerNumber)], SerializeFolder(child))
					elseif child:IsA("ValueBase") then
						table.insert(profile.Data.Shakers.ShakerContents[tostring(shakerNumber)], SerializeValue(child))
					end
				end
			end
		end
	end

	if ShakerManager then
		for shakeKey, shakeData in pairs(ShakerManager.ActiveShakes) do
			if shakeData.player == player then
				local elapsed = tick() - shakeData.startTime
				local remaining = math.max(0, shakeData.duration - elapsed)

				if remaining > 0 then
					profile.Data.Shakers.ActiveShakes[tostring(shakeData.shakerNumber)] = {
						TimeRemaining = remaining,
						TotalDuration = shakeData.duration,
						MixedColor = {shakeData.mixedColor.R, shakeData.mixedColor.G, shakeData.mixedColor.B}
					}
				end
			end
		end
	end
end

function ShakerPersistence.LoadPlayerData(player, profile)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then
		playerShakers = Instance.new("Folder")
		playerShakers.Name = "Shakers"
		playerShakers.Parent = player
	end

	if profile.Data.Shakers.ShakerContents then
		for shakerNumber, contents in pairs(profile.Data.Shakers.ShakerContents) do
			if tonumber(shakerNumber) then
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
						DeserializeFolder(childData, shakerFolder)
					else
						DeserializeValue(childData, shakerFolder)
					end
				end
			end
		end
	end

	task.spawn(function()
		task.wait(2)
		ShakerPersistence.RestoreActiveShakes(player, profile.Data.Shakers)
	end)
end

function ShakerPersistence.RestoreActiveShakes(player, savedData)
	if not savedData or not savedData.ActiveShakes then return end

	local currentTime = os.time()
	local saveTime = savedData.SaveTime or currentTime
	local offlineTime = currentTime - saveTime

	for shakerNumber, shakeData in pairs(savedData.ActiveShakes) do
		shakerNumber = tonumber(shakerNumber)
		if not shakerNumber then continue end

		local timeRemaining = shakeData.TimeRemaining - offlineTime

		if timeRemaining <= 0 then
			task.spawn(function()
				task.wait(0.5)

				local playerShakers = player:FindFirstChild("Shakers")
				if not playerShakers then return end

				local shakerFolder = playerShakers:FindFirstChild(tostring(shakerNumber))
				if not shakerFolder then return end

				local ingredientFolders = {}
				for _, child in ipairs(shakerFolder:GetChildren()) do
					if child:IsA("Folder") then
						table.insert(ingredientFolders, child)
					end
				end

				if #ingredientFolders > 0 then
					ShakerJuice.CreateJuice(player, shakerNumber, ingredientFolders, IngredientConfig, MutationConfig)

					local shakerModel = ShakerModel.GetCurrentShakerModel(player, shakerNumber)
					if shakerModel and shakeData.MixedColor then
						local mixedColor = Color3.new(
							shakeData.MixedColor[1],
							shakeData.MixedColor[2],
							shakeData.MixedColor[3]
						)
						ShakerEffects.PlayPourEffect(shakerModel, mixedColor)
					end
				end
			end)
		else
			task.spawn(function()
				task.wait(1)

				local playerShakers = player:FindFirstChild("Shakers")
				if not playerShakers then return end

				local shakerFolder = playerShakers:FindFirstChild(tostring(shakerNumber))
				if not shakerFolder then return end

				local ingredientFolders = {}
				for _, child in ipairs(shakerFolder:GetChildren()) do
					if child:IsA("Folder") then
						table.insert(ingredientFolders, child)
					end
				end

				if #ingredientFolders > 0 then
					local shakeKey = player.UserId .. "_" .. shakerNumber

					local mixedColor = Color3.new(
						shakeData.MixedColor[1],
						shakeData.MixedColor[2],
						shakeData.MixedColor[3]
					)

					ShakerManager.ActiveShakes[shakeKey] = {
						startTime = tick(),
						duration = timeRemaining,
						player = player,
						shakerNumber = shakerNumber,
						cancelled = false,
						mixedColor = mixedColor,
						soundClone = nil,
						contentPart = nil
					}

					local currentModel = ShakerModel.GetCurrentShakerModel(player, shakerNumber)
					if currentModel then
						local soundClone, contentPart =
							ShakerEffects.StartShakeEffects(currentModel, mixedColor)

						ShakerManager.ActiveShakes[shakeKey].soundClone = soundClone
						ShakerManager.ActiveShakes[shakeKey].contentPart = contentPart

						ShakerEffects.SetStartButtonColor(currentModel, true)
					end

					task.spawn(function()
						ShakerManager.UpdateShakeLoop(shakeKey, timeRemaining)
					end)
				end
			end)
		end
	end
end

local function connectShakerChanges(player)
	if not playerTroves[player] then
		playerTroves[player] = Trove.new()
	end
	local playerTrove = playerTroves[player]

	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return end

	playerTrove:Connect(playerShakers.ChildAdded, function()
		ShakerPersistence.UpdatePlayerData(player)
	end)

	playerTrove:Connect(playerShakers.ChildRemoved, function()
		ShakerPersistence.UpdatePlayerData(player)
	end)

	playerTrove:Connect(playerShakers.DescendantAdded, function()
		ShakerPersistence.UpdatePlayerData(player)
	end)

	playerTrove:Connect(playerShakers.DescendantRemoving, function()
		ShakerPersistence.UpdatePlayerData(player)
	end)
end

local function PlayerAdded(player)
	InitializeDependencies()

	local maxWait = 10
	local waited = 0
	local profile = DataSaver.GetProfile(player)

	while not profile and waited < maxWait do
		task.wait(0.1)
		waited = waited + 0.1
		profile = DataSaver.GetProfile(player)
	end

	if not profile then
		warn(`[SaveShakers]: Failed to get profile for {player.Name}`)
		return
	end

	playerTroves[player] = Trove.new()

	task.wait(1)
	ShakerPersistence.LoadPlayerData(player, profile)

	connectShakerChanges(player)
end

local function PlayerRemoving(player)
	if playerTroves[player] then
		playerTroves[player]:Destroy()
		playerTroves[player] = nil
	end

	ShakerPersistence.UpdatePlayerData(player)
end

mainTrove:Add(task.spawn(function()
	while true do
		task.wait(120)

		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataSaver.GetProfile(player)
			if profile then
				task.spawn(function()
					ShakerPersistence.UpdatePlayerData(player)
				end)
			end
		end
	end
end))

mainTrove:Connect(Players.PlayerAdded, PlayerAdded)
mainTrove:Connect(Players.PlayerRemoving, PlayerRemoving)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataSaver.GetProfile(player)
		if profile then
			ShakerPersistence.UpdatePlayerData(player)
		end
	end

	task.wait(3)
end)

function ShakerPersistence.GetProfile(player)
	return DataSaver.GetProfile(player)
end

return ShakerPersistence