local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("Trove"))
local IngredientConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("IngredientConfig"))

local player = Players.LocalPlayer
local plotsFolder = Workspace:WaitForChild("Plots")

local shakersEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Shakers")
local startEffectsEvent = shakersEventsFolder:WaitForChild("StartEffects")
local stopEffectsEvent = shakersEventsFolder:WaitForChild("StopEffects")
local completeShakeEvent = shakersEventsFolder:WaitForChild("CompleteShake")
local updateXpEvent = shakersEventsFolder:WaitForChild("UpdateXp")

local activeEffects = {}
local jellyEffectTroves = {}
local ingredientPartsCache = {}

local function getPlotShakersFolder(shakerNumber)
	local currentPlotValue = player:FindFirstChild("CurrentPlot")
	if not currentPlotValue then return nil end

	local plotNumber = currentPlotValue.Value
	if plotNumber == "" then return nil end

	local plotFolder = plotsFolder:FindFirstChild(plotNumber)
	if not plotFolder then return nil end

	local plotShakersRoot = plotFolder:FindFirstChild("Shakers")
	if not plotShakersRoot then return nil end

	return plotShakersRoot:FindFirstChild(tostring(shakerNumber))
end

local function getIngredientsContentPart(shakerNumber)
	local shakersFolder = getPlotShakersFolder(shakerNumber)
	if not shakersFolder then return nil end

	local ingredientsFolder = shakersFolder:FindFirstChild("Ingredients")
	if not ingredientsFolder then return nil end

	return ingredientsFolder:FindFirstChild("Content")
end

local function getModelFolder(shakerNumber)
	local shakersFolder = getPlotShakersFolder(shakerNumber)
	if not shakersFolder then return nil end

	return shakersFolder:FindFirstChild("Model")
end

local function clearJuiceContent(contentPart)
	if not contentPart then return end

	for _, child in ipairs(contentPart:GetChildren()) do
		if child:IsA("BasePart") and child.Name ~= "Content" and string.find(child.Name, "Layer_") then
			child:Destroy()
		end
	end
end

local function removePartWithAnimation(part)
	if not part or not part.Parent then return end

	local finalSize = part.Size
	local targetSize = finalSize * 0.01

	local tweenInfo = TweenInfo.new(
		0.3,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.In,
		0,
		false,
		0
	)

	local tween = TweenService:Create(part, tweenInfo, {
		Size = targetSize
	})

	tween.Completed:Connect(function()
		tween:Destroy()
		if part and part.Parent then
			part:Destroy()
		end
	end)

	tween:Play()
end

local function createJuiceParts(contentPart, ingredients, cacheKey, mixedColor)
	clearJuiceContent(contentPart)

	if cacheKey and not ingredientPartsCache[cacheKey] then
		ingredientPartsCache[cacheKey] = {}
	end

	local numIngredients = #ingredients
	if numIngredients == 0 then return {} end

	local contentSize = contentPart.Size
	local contentCFrame = contentPart.CFrame

	local partHeight = contentSize.Y / numIngredients

	local createdParts = {}

	for i, ingredientName in ipairs(ingredients) do
		local ingredientData = IngredientConfig.Ingredients[ingredientName]
		if ingredientData then
			local juicePart = Instance.new("Part")
			juicePart.Name = "Layer_" .. ingredientName .. "_" .. i
			juicePart.Transparency = 0

			if mixedColor then
				local variation = -0.15 + math.random() * 0.3
				local variedColor
				if variation > 0 then
					variedColor = mixedColor:Lerp(Color3.new(1, 1, 1), variation)
				else
					variedColor = mixedColor:Lerp(Color3.new(0, 0, 0), -variation)
				end
				juicePart.Color = variedColor
			else
				juicePart.Color = ingredientData.Color
			end

			juicePart.Material = Enum.Material.SmoothPlastic

			local finalSize = Vector3.new(contentSize.X, partHeight, contentSize.Z)

			juicePart:SetAttribute("BaseSize", tostring(finalSize))

			local initialScale = 0.01
			juicePart.Size = finalSize * initialScale

			local offsetY = -(contentSize.Y / 2) + (partHeight / 2) + ((i - 1) * partHeight)
			juicePart.CFrame = contentCFrame * CFrame.new(0, offsetY, 0)

			juicePart.Anchored = true
			juicePart.CanCollide = false

			juicePart.Parent = contentPart

			local tweenInfo = TweenInfo.new(
				0.4,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out,
				0,
				false,
				0
			)

			local tween = TweenService:Create(juicePart, tweenInfo, {
				Size = finalSize
			})

			tween.Completed:Connect(function()
				tween:Destroy()
			end)

			tween:Play()

			if cacheKey then
				ingredientPartsCache[cacheKey][ingredientName] = juicePart
			end

			table.insert(createdParts, juicePart)
		end
	end

	return createdParts
end

local function startJellyEffect(contentPart, ingredientParts, cacheKey, mixedColor)
	if #ingredientParts == 0 then return end

	if jellyEffectTroves[cacheKey] then
		jellyEffectTroves[cacheKey]:Destroy()
		jellyEffectTroves[cacheKey] = nil
	end

	local trove = Trove.new()
	jellyEffectTroves[cacheKey] = trove

	local function getColorVariation(baseColor)
		local variation = -0.25 + math.random() * 0.3
		if variation > 0 then
			return baseColor:Lerp(Color3.new(1, 1, 1), variation)
		else
			return baseColor:Lerp(Color3.new(0, 0, 0), -variation)
		end
	end

	if mixedColor then
		for _, part in ipairs(ingredientParts) do
			if part and part.Parent then
				local function cycleColor()
					if not part or not part.Parent then return end

					local newColor = getColorVariation(mixedColor)
					local duration = 1.5 + math.random() * 1.5

					local colorTween = TweenService:Create(
						part,
						TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{Color = newColor}
					)

					trove:Add(colorTween)

					colorTween.Completed:Connect(function()
						task.wait(0.1)
						cycleColor()
					end)

					colorTween:Play()
				end

				task.delay(math.random() * 0.5, cycleColor)
			end
		end
	end

	trove:Connect(RunService.Heartbeat, function()
		for _, part in ipairs(ingredientParts) do
			if part and part.Parent and math.random() < 0.03 then
				local baseSizeStr = part:GetAttribute("BaseSize")
				if baseSizeStr then
					local x, y, z = baseSizeStr:match("([%d%.]+), ([%d%.]+), ([%d%.]+)")
					if x and y and z then
						local baseSize = Vector3.new(tonumber(x), tonumber(y), tonumber(z))

						local scale = 0.70 + math.random() * 0.40
						local targetSize = baseSize * scale

						local pulseTween = TweenService:Create(
							part,
							TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
							{Size = targetSize}
						)

						pulseTween.Completed:Connect(function()
							local returnTween = TweenService:Create(
								part,
								TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
								{Size = baseSize}
							)
							returnTween:Play()
							returnTween.Completed:Connect(function()
								returnTween:Destroy()
							end)
						end)

						pulseTween:Play()
					end
				end
			end
		end
	end)
end

local function stopJellyEffect(cacheKey)
	if jellyEffectTroves[cacheKey] then
		jellyEffectTroves[cacheKey]:Destroy()
		jellyEffectTroves[cacheKey] = nil
	end
end

local function onStartEffects(shakerNumber, mixedColor)
	local cacheKey = player.UserId .. "_" .. shakerNumber

	local contentPart = getIngredientsContentPart(shakerNumber)
	if not contentPart then return end

	local playerShakers = player:FindFirstChild("Shakers")
	if not playerShakers then return end

	local shakerFolder = playerShakers:FindFirstChild(tostring(shakerNumber))
	if not shakerFolder then return end

	local currentIngredients = {}
	for _, ingredientFolder in ipairs(shakerFolder:GetChildren()) do
		if ingredientFolder:IsA("Folder") then
			table.insert(currentIngredients, ingredientFolder.Name)
		end
	end

	if #currentIngredients == 0 then return end

	ingredientPartsCache[cacheKey] = {}
	stopJellyEffect(cacheKey)

	local createdParts = createJuiceParts(contentPart, currentIngredients, cacheKey, mixedColor)

	if createdParts and #createdParts > 0 then
		startJellyEffect(contentPart, createdParts, cacheKey, mixedColor)
	end

	activeEffects[cacheKey] = {
		mixedColor = mixedColor,
		shakerNumber = shakerNumber
	}
end

local function onStopEffects(shakerNumber)
	local cacheKey = player.UserId .. "_" .. shakerNumber

	stopJellyEffect(cacheKey)

	local contentPart = getIngredientsContentPart(shakerNumber)
	if contentPart then
		if ingredientPartsCache[cacheKey] then
			for _, part in pairs(ingredientPartsCache[cacheKey]) do
				if part and part.Parent then
					removePartWithAnimation(part)
				end
			end
		end
	end

	ingredientPartsCache[cacheKey] = {}
	activeEffects[cacheKey] = nil
end

local function onCompleteShake(shakerNumber, mixedColor)
	local cacheKey = player.UserId .. "_" .. shakerNumber

	stopJellyEffect(cacheKey)

	local contentPart = getIngredientsContentPart(shakerNumber)
	if contentPart then
		clearJuiceContent(contentPart)
	end

	ingredientPartsCache[cacheKey] = {}
	activeEffects[cacheKey] = nil
end

local function onUpdateXp(shakerNumber, currentXp, requiredXp)
	-- XP updates are handled by the server updating the billboard
end

startEffectsEvent.OnClientEvent:Connect(onStartEffects)
stopEffectsEvent.OnClientEvent:Connect(onStopEffects)
completeShakeEvent.OnClientEvent:Connect(onCompleteShake)
updateXpEvent.OnClientEvent:Connect(onUpdateXp)

local function connectPlayerShakerChanges()
	local playerShakers = player:WaitForChild("Shakers", 10)
	if not playerShakers then return end

	local function updateShakerVisuals(shakerNumber)
		local cacheKey = player.UserId .. "_" .. shakerNumber

		if activeEffects[cacheKey] then
			local effectData = activeEffects[cacheKey]
			onStartEffects(shakerNumber, effectData.mixedColor)
		end
	end

	playerShakers.ChildAdded:Connect(function(shakerFolder)
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				shakerFolder.ChildAdded:Connect(function()
					task.defer(function()
						local cacheKey = player.UserId .. "_" .. shakerNumber
						if activeEffects[cacheKey] then
							updateShakerVisuals(shakerNumber)
						end
					end)
				end)

				shakerFolder.ChildRemoved:Connect(function()
					task.defer(function()
						local cacheKey = player.UserId .. "_" .. shakerNumber
						if activeEffects[cacheKey] then
							updateShakerVisuals(shakerNumber)
						end
					end)
				end)
			end
		end
	end)

	for _, shakerFolder in ipairs(playerShakers:GetChildren()) do
		if shakerFolder:IsA("Folder") then
			local shakerNumber = tonumber(shakerFolder.Name)
			if shakerNumber then
				shakerFolder.ChildAdded:Connect(function()
					task.defer(function()
						local cacheKey = player.UserId .. "_" .. shakerNumber
						if activeEffects[cacheKey] then
							updateShakerVisuals(shakerNumber)
						end
					end)
				end)

				shakerFolder.ChildRemoved:Connect(function()
					task.defer(function()
						local cacheKey = player.UserId .. "_" .. shakerNumber
						if activeEffects[cacheKey] then
							updateShakerVisuals(shakerNumber)
						end
					end)
				end)
			end
		end
	end
end

task.spawn(connectPlayerShakerChanges)
