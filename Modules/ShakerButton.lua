--[[
	ShakerButton - Módulo para el efecto del TouchPart del shaker
	Igual que DispenserButton: ClickDetector, highlight, efecto de presionado
	Usa mouse.Button1Down para clicks (funciona con tools equipadas)
	Usa ClickDetector para hover
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ShakerButton = {}

local PRESS_DURATION = 0.08
local RELEASE_DURATION = 0.1
local SCALE_FACTOR = 0.1

local buttonData = {}
local player = Players.LocalPlayer
local mouse = player:GetMouse()

function ShakerButton.setup(touchPart, trove, onClickCallback)
	if not touchPart or not touchPart:IsA("BasePart") then return end

	local originalSize = touchPart.Size
	local originalCFrame = touchPart.CFrame

	local squashedSize = Vector3.new(originalSize.X * SCALE_FACTOR, originalSize.Y, originalSize.Z)
	local sizeOffset = (originalSize.X - squashedSize.X) / 2
	local squashedCFrame = originalCFrame * CFrame.new(sizeOffset, 0, 0)

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 32
	clickDetector.Parent = touchPart
	trove:Add(clickDetector)

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
		originalSize = originalSize,
		originalCFrame = originalCFrame,
		squashedSize = squashedSize,
		squashedCFrame = squashedCFrame,
		touchPart = touchPart,
		highlight = highlight,
		clickDetector = clickDetector
	}

	buttonData[touchPart] = data

	-- Hover con ClickDetector (funciona siempre)
	trove:Connect(clickDetector.MouseHoverEnter, function()
		highlight.Enabled = true
	end)

	trove:Connect(clickDetector.MouseHoverLeave, function()
		highlight.Enabled = false
	end)

	-- Click con mouse.Button1Down (funciona incluso con tools equipadas)
	local function handleClick()
		if data.isPressed or data.isLocked then return end

		-- Verificar que el mouse está sobre esta parte
		local target = mouse.Target
		if target ~= touchPart and not (target and target:IsDescendantOf(touchPart)) then
			return
		end

		data.isPressed = true

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

	trove:Connect(mouse.Button1Down, handleClick)

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
		-- Forzar limpiar highlight al bloquear
		if data.highlight then
			data.highlight.Enabled = false
		end
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
