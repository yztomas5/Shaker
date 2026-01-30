--[[
	ShakerPopup - Manejo del popup de confirmación para cancelar mezcla
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Data.Trove)

local ShakerPopup = {}

local player = Players.LocalPlayer
local warningFrame = nil
local popupTrove = nil
local onConfirmCallback = nil

------------------------------------------------------------------------
-- SETUP
------------------------------------------------------------------------

function ShakerPopup.init()
	local warnGui = player:WaitForChild("PlayerGui"):WaitForChild("Warn")
	warningFrame = warnGui:WaitForChild("Warning")
end

------------------------------------------------------------------------
-- POPUP CONTROL
------------------------------------------------------------------------

function ShakerPopup.open(onConfirm)
	if popupTrove then
		popupTrove:Destroy()
	end
	popupTrove = Trove.new()
	onConfirmCallback = onConfirm

	local originalSize = warningFrame:GetAttribute("OriginalSize")
	if not originalSize then
		originalSize = warningFrame.Size
		warningFrame:SetAttribute("OriginalSize", originalSize)
	end

	warningFrame.Size = UDim2.new(0, 0, 0, 0)
	warningFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	warningFrame.Visible = true

	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = TweenService:Create(warningFrame, tweenInfo, {
		Size = originalSize,
		Position = UDim2.new(0.5, -originalSize.X.Offset / 2, 0.5, -originalSize.Y.Offset / 2)
	})
	tween:Play()

	local optionsFrame = warningFrame:FindFirstChild("Options")
	if optionsFrame then
		local yesButton = optionsFrame:FindFirstChild("Yes")
		local noButton = optionsFrame:FindFirstChild("No")

		if yesButton then
			popupTrove:Connect(yesButton.MouseButton1Click, function()
				ShakerPopup.close()
				if onConfirmCallback then
					onConfirmCallback()
				end
			end)
		end

		if noButton then
			popupTrove:Connect(noButton.MouseButton1Click, function()
				ShakerPopup.close()
			end)
		end
	end
end

function ShakerPopup.close()
	if popupTrove then
		popupTrove:Destroy()
		popupTrove = nil
	end

	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	local tween = TweenService:Create(warningFrame, tweenInfo, {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0)
	})
	tween:Play()
	tween.Completed:Connect(function()
		warningFrame.Visible = false
	end)
end

function ShakerPopup.forceClose()
	if popupTrove then
		popupTrove:Destroy()
		popupTrove = nil
	end
	if warningFrame then
		warningFrame.Visible = false
	end
end

return ShakerPopup
