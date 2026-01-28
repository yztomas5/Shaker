local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Data.Trove)

local LoadingBillboard = {}

local PULSE_DURATION = 0.8
local MIN_TRANSPARENCY = 0
local MAX_TRANSPARENCY = 0.6
local FADE_OUT_DURATION = 0.3

function LoadingBillboard.Show(plotNumber)
	local Workspace = game:GetService("Workspace")
	local plotsFolder = Workspace:WaitForChild("Plots")
	local plotFolder = plotsFolder:FindFirstChild(plotNumber)

	if not plotFolder then
		return nil, nil
	end

	local plotShakersRoot = plotFolder:FindFirstChild("Shakers")
	if not plotShakersRoot then
		return nil, nil
	end

	local positionFolder = plotShakersRoot:FindFirstChild("Position")
	if not positionFolder then
		return nil, nil
	end

	local billboardTemplate = ReplicatedStorage:WaitForChild("Assets")
		:WaitForChild("GUI")
		:WaitForChild("Billboards")
		:WaitForChild("Loading")

	local trove = Trove.new()
	local billboard = billboardTemplate:Clone()
	billboard.Parent = positionFolder
	trove:Add(billboard)

	local infoFrame = billboard:FindFirstChild("Info")
	if not infoFrame then
		trove:Destroy()
		return nil, nil
	end

	local dataLabel = infoFrame:FindFirstChild("Data")
	if not dataLabel then
		trove:Destroy()
		return nil, nil
	end

	dataLabel.Text = "Loading Data..."

	local isPulsing = true

	local pulseThread = trove:Add(task.spawn(function()
		while isPulsing do
			local tweenOut = TweenService:Create(
				dataLabel,
				TweenInfo.new(PULSE_DURATION / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{TextTransparency = MAX_TRANSPARENCY}
			)
			tweenOut:Play()
			tweenOut.Completed:Wait()

			if not isPulsing then break end

			local tweenIn = TweenService:Create(
				dataLabel,
				TweenInfo.new(PULSE_DURATION / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{TextTransparency = MIN_TRANSPARENCY}
			)
			tweenIn:Play()
			tweenIn.Completed:Wait()
		end
	end))

	billboard:SetAttribute("IsPulsing", true)

	local stopData = {
		trove = trove,
		billboard = billboard,
		isPulsing = function() return isPulsing end,
		stopPulse = function()
			isPulsing = false
		end
	}

	return stopData
end

function LoadingBillboard.Hide(stopData)
	if not stopData or not stopData.billboard then
		return
	end

	local billboard = stopData.billboard
	if not billboard.Parent then
		return
	end

	stopData.stopPulse()

	local infoFrame = billboard:FindFirstChild("Info")
	if infoFrame then
		local dataLabel = infoFrame:FindFirstChild("Data")
		if dataLabel then
			local textTween = TweenService:Create(
				dataLabel,
				TweenInfo.new(FADE_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{TextTransparency = 1}
			)
			textTween:Play()
		end

		if infoFrame:IsA("GuiObject") then
			local frameTween = TweenService:Create(
				infoFrame,
				TweenInfo.new(FADE_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{BackgroundTransparency = 1}
			)
			frameTween:Play()
			frameTween.Completed:Wait()
		else
			task.wait(FADE_OUT_DURATION)
		end
	end

	if stopData.trove then
		stopData.trove:Destroy()
	end
end

return LoadingBillboard