--[[
	ShakerButton - Módulo para el efecto del TouchPart del shaker
	Compatible con todas las plataformas (PC, móvil, consola)
	Usa RunService para hover detection
	Usa UserInputService para clicks (funciona con tools equipadas)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ShakerButton = {}

local PRESS_DURATION = 0.08
local RELEASE_DURATION = 0.1
local SCALE_FACTOR = 0.1
local MAX_ACTIVATION_DISTANCE = 32

local buttonData = {}
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local clickSound = ReplicatedStorage.Assets.Sounds.SFX.Shakers.Click

local function isClickInput(inputType)
	return inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.Touch
		or inputType == Enum.UserInputType.Gamepad1
end

local function isWithinDistance(part)
	local character = player.Character
	if not character then return false end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false end

	local distance = (humanoidRootPart.Position - part.Position).Magnitude
	return distance <= MAX_ACTIVATION_DISTANCE
end

local function isMouseOverPart(part)
	local target = mouse.Target
	if not target then return false end
	return target == part or target:IsDescendantOf(part)
end

function ShakerButton.setup(touchPart, trove, onClickCallback)
	if not touchPart or not touchPart:IsA("BasePart") then return end

	local originalSize = touchPart.Size
	local originalCFrame = touchPart.CFrame

	local squashedSize = Vector3.new(originalSize.X * SCALE_FACTOR, originalSize.Y, originalSize.Z)
	local sizeOffset = (originalSize.X - squashedSize.X) / 2
	local squashedCFrame = originalCFrame * CFrame.new(sizeOffset, 0, 0)

	local highlight = Instance.new("Highlight")
	highlight.Adornee = touchPart
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = touchPart
	trove:Add(highlight)

	local data = {
		isPressed = false,
		isLocked = false,
		isHovered = false,
		originalSize = originalSize,
		originalCFrame = originalCFrame,
		squashedSize = squashedSize,
		squashedCFrame = squashedCFrame,
		touchPart = touchPart,
		highlight = highlight
	}

	buttonData[touchPart] = data

	-- Hover con RunService (independiente de estados)
	trove:Connect(RunService.RenderStepped, function()
		local shouldHover = isMouseOverPart(touchPart) and isWithinDistance(touchPart)

		if shouldHover and not data.isHovered then
			data.isHovered = true
			highlight.Enabled = true
		elseif not shouldHover and data.isHovered then
			data.isHovered = false
			highlight.Enabled = false
		end
	end)

	-- Click con UserInputService (compatible con PC, móvil y consola)
	local function handleClick()
		if data.isPressed or data.isLocked then return end

		-- Verificar distancia
		if not isWithinDistance(touchPart) then return end

		-- Verificar que el mouse/touch está sobre esta parte
		if not isMouseOverPart(touchPart) then return end

		data.isPressed = true

		-- Reproducir sonido de click
		local sound = clickSound:Clone()
		sound.Parent = touchPart
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)

		local pressInfo = TweenInfo.new(PRESS_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local pressEffect = TweenService:Create(touchPart, pressInfo, {
			Size = squashedSize,
			CFrame = squashedCFrame
		})

		pressEffect:Play()

		pressEffect.Completed:Connect(function()
			local releaseInfo = TweenInfo.new(RELEASE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local releaseEffect = TweenService:Create(touchPart, releaseInfo, {
				Size = originalSize,
				CFrame = originalCFrame
			})

			releaseEffect:Play()

			releaseEffect.Completed:Connect(function()
				data.isPressed = false
			end)
		end)

		if onClickCallback then
			onClickCallback()
		end
	end

	trove:Connect(UserInputService.InputBegan, function(input, gameProcessed)
		if gameProcessed then return end
		if isClickInput(input.UserInputType) then
			handleClick()
		end
	end)

	trove:Add(function()
		buttonData[touchPart] = nil
	end)

	return data
end

function ShakerButton.unlock(touchPart)
	local data = buttonData[touchPart]
	if data then
		data.isLocked = false
	end
end

function ShakerButton.lock(touchPart)
	local data = buttonData[touchPart]
	if data then
		data.isLocked = true
	end
end

function ShakerButton.isLocked(touchPart)
	local data = buttonData[touchPart]
	return data and data.isLocked or false
end

function ShakerButton.clearHighlight(touchPart)
	local data = buttonData[touchPart]
	if data and data.highlight then
		data.highlight.Enabled = false
	end
end

return ShakerButton
