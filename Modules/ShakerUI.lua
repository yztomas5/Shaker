--[[
	ShakerUI - Efectos visuales del shaker (juice parts, jelly, highlights)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local IngredientConfig = require(ReplicatedStorage.Modules.Config.IngredientConfig)

local ShakerUI = {}

local activeEffects = {
	active = false,
	parts = {},
	mixedColor = nil,
	connection = nil
}

local currentHighlight = nil
local currentHoveredModel = nil

------------------------------------------------------------------------
-- HIGHLIGHT
------------------------------------------------------------------------

function ShakerUI.clearHighlight()
	if currentHighlight then
		currentHighlight:Destroy()
		currentHighlight = nil
	end
	currentHoveredModel = nil
end

function ShakerUI.applyHighlight(model)
	if not model then return end
	if currentHoveredModel == model then return end

	ShakerUI.clearHighlight()
	currentHoveredModel = model

	local highlight = Instance.new("Highlight")
	highlight.Name = "ShakerHighlight"
	highlight.FillColor = Color3.fromRGB(100, 255, 100)
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0
	highlight.Adornee = model
	highlight.Parent = model

	currentHighlight = highlight
end

------------------------------------------------------------------------
-- JUICE PARTS
------------------------------------------------------------------------

local function clearContent(contentPart)
	if not contentPart then return end
	for _, child in ipairs(contentPart:GetChildren()) do
		if child:IsA("BasePart") and child.Name:find("Layer_") then
			child:Destroy()
		end
	end
end

function ShakerUI.createJuiceParts(contentPart, ingredientNames, mixedColor)
	clearContent(contentPart)

	local numIngredients = #ingredientNames
	if numIngredients == 0 then return {} end

	local contentSize = contentPart.Size
	local contentCFrame = contentPart.CFrame
	local partHeight = contentSize.Y / numIngredients

	local parts = {}

	for i, ingredientName in ipairs(ingredientNames) do
		local ingredientData = IngredientConfig.Ingredients[ingredientName]
		if ingredientData then
			local part = Instance.new("Part")
			part.Name = "Layer_" .. ingredientName .. "_" .. i
			part.Anchored = true
			part.CanCollide = false
			part.Material = Enum.Material.SmoothPlastic

			local variation = -0.15 + math.random() * 0.3
			if variation > 0 then
				part.Color = mixedColor:Lerp(Color3.new(1, 1, 1), variation)
			else
				part.Color = mixedColor:Lerp(Color3.new(0, 0, 0), -variation)
			end

			local finalSize = Vector3.new(contentSize.X, partHeight, contentSize.Z)
			part:SetAttribute("BaseSize", tostring(finalSize))

			part.Size = finalSize * 0.01

			local offsetY = -(contentSize.Y / 2) + (partHeight / 2) + ((i - 1) * partHeight)
			part.CFrame = contentCFrame * CFrame.new(0, offsetY, 0)

			part.Parent = contentPart

			local tween = TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = finalSize
			})
			tween:Play()

			table.insert(parts, part)
		end
	end

	return parts
end

------------------------------------------------------------------------
-- JELLY EFFECT
------------------------------------------------------------------------

local function startJellyEffect(parts, mixedColor)
	if #parts == 0 then return nil end

	for _, part in ipairs(parts) do
		task.spawn(function()
			while activeEffects.active and part.Parent do
				local variation = -0.25 + math.random() * 0.3
				local newColor
				if variation > 0 then
					newColor = mixedColor:Lerp(Color3.new(1, 1, 1), variation)
				else
					newColor = mixedColor:Lerp(Color3.new(0, 0, 0), -variation)
				end

				local duration = 1.5 + math.random() * 1.5
				local colorTween = TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Color = newColor
				})
				colorTween:Play()
				colorTween.Completed:Wait()
				task.wait(0.1)
			end
		end)
	end

	local connection = RunService.Heartbeat:Connect(function()
		for _, part in ipairs(parts) do
			if part.Parent and math.random() < 0.03 then
				local baseSizeStr = part:GetAttribute("BaseSize")
				if baseSizeStr then
					local x, y, z = baseSizeStr:match("([%d%.]+), ([%d%.]+), ([%d%.]+)")
					if x and y and z then
						local baseSize = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
						local scale = 0.70 + math.random() * 0.40
						local targetSize = baseSize * scale

						local pulseTween = TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
							Size = targetSize
						})
						pulseTween:Play()
						pulseTween.Completed:Connect(function()
							if part.Parent then
								local returnTween = TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
									Size = baseSize
								})
								returnTween:Play()
							end
						end)
					end
				end
			end
		end
	end)

	return connection
end

------------------------------------------------------------------------
-- EFECTOS ACTIVOS
------------------------------------------------------------------------

function ShakerUI.startEffects(contentPart, ingredientNames, mixedColor)
	ShakerUI.stopEffects(contentPart)

	local parts = ShakerUI.createJuiceParts(contentPart, ingredientNames, mixedColor)

	activeEffects = {
		active = true,
		parts = parts,
		mixedColor = mixedColor
	}

	local connection = startJellyEffect(parts, mixedColor)
	activeEffects.connection = connection

	return parts
end

function ShakerUI.stopEffects(contentPart)
	if not activeEffects.active then return end

	if activeEffects.connection then
		activeEffects.connection:Disconnect()
	end

	if contentPart then
		for _, part in ipairs(activeEffects.parts or {}) do
			if part.Parent then
				local tween = TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Size = part.Size * 0.01
				})
				tween.Completed:Connect(function()
					part:Destroy()
				end)
				tween:Play()
			end
		end
	end

	activeEffects = {
		active = false,
		parts = {},
		mixedColor = nil,
		connection = nil
	}
end

function ShakerUI.isActive()
	return activeEffects.active
end

function ShakerUI.getParts()
	return activeEffects.parts
end

function ShakerUI.getMixedColor()
	return activeEffects.mixedColor
end

------------------------------------------------------------------------
-- FLASH EFFECT (para energizantes)
------------------------------------------------------------------------

function ShakerUI.flashParts(flashColor)
	if not activeEffects.parts then return end

	for _, part in ipairs(activeEffects.parts) do
		if part.Parent then
			local originalColor = part.Color
			local originalSize = part.Size

			local flashTween = TweenService:Create(part, TweenInfo.new(0.1), {
				Color = flashColor
			})
			flashTween:Play()
			flashTween.Completed:Connect(function()
				local returnTween = TweenService:Create(part, TweenInfo.new(0.3), {
					Color = originalColor
				})
				returnTween:Play()
			end)

			local bigSize = originalSize * 1.2
			local scaleTween = TweenService:Create(part, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = bigSize
			})
			scaleTween:Play()
			scaleTween.Completed:Connect(function()
				local returnScale = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Size = originalSize
				})
				returnScale:Play()
			end)
		end
	end
end

return ShakerUI
