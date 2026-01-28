local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Data.Trove)
local trove = Trove.new()

local ShakerDataCache = {}
local ShakerDataManager = {}

function ShakerDataManager.SavePlayerShakerData(player)
	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return end

	local userId = player.UserId
	ShakerDataCache[userId] = {}

	for _, shakerFolder in ipairs(playerShakers:GetChildren()) do
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				ShakerDataCache[userId][shakerNumber] = {}

				for _, ingredientFolder in ipairs(shakerFolder:GetChildren()) do
					if ingredientFolder:IsA("Folder") then
						local idValue = ingredientFolder:FindFirstChild("Id")
						if idValue and idValue:IsA("IntValue") then
							table.insert(ShakerDataCache[userId][shakerNumber], {
								Name = ingredientFolder.Name,
								Id = idValue.Value
							})
						end
					end
				end
			end
		end
	end
end

function ShakerDataManager.RestorePlayerShakerData(player)
	local cachedData = ShakerDataCache[player.UserId]
	if not cachedData then return end

	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return end

	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return end

	local ingredients = inventory:FindFirstChild("Ingredients")
	if not ingredients then return end

	for shakerNumber, ingredientList in pairs(cachedData) do
		local shakerFolder = playerShakers:FindFirstChild(tostring(shakerNumber))
		if shakerFolder then
			for _, ingredientData in ipairs(ingredientList) do
				for _, ingredientFolder in ipairs(ingredients:GetChildren()) do
					if ingredientFolder:IsA("Folder") and ingredientFolder.Name == ingredientData.Name then
						local idValue = ingredientFolder:FindFirstChild("Id")
						if idValue and idValue:IsA("IntValue") and idValue.Value == ingredientData.Id then
							ingredientFolder.Parent = shakerFolder
							break
						end
					end
				end
			end
		end
	end
end

function ShakerDataManager.ClearPlayerCache(player)
	ShakerDataCache[player.UserId] = nil
end

trove:Connect(Players.PlayerRemoving, function(player)
	ShakerDataManager.ClearPlayerCache(player)
end)

return ShakerDataManager
