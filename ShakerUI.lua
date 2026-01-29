local TweenService = game:GetService("TweenService")

local ShakerUI = {}

local SUFFIXES = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}

function ShakerUI.FormatXp(xp)
	if xp < 1000 then
		return tostring(math.floor(xp)) .. " Xp"
	end

	local suffixIndex = 1
	local value = xp

	while value >= 1000 and suffixIndex < #SUFFIXES do
		value = value / 1000
		suffixIndex = suffixIndex + 1
	end

	if value >= 100 then
		return string.format("%.0f%s Xp", value, SUFFIXES[suffixIndex])
	elseif value >= 10 then
		return string.format("%.1f%s Xp", value, SUFFIXES[suffixIndex])
	else
		return string.format("%.2f%s Xp", value, SUFFIXES[suffixIndex])
	end
end

function ShakerUI.FormatTime(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%02d:%02d:%02d", hours, minutes, secs)
	else
		return string.format("%02d:%02d", minutes, secs)
	end
end

function ShakerUI.UpdateStatusDisplay(shakerModel, timeRemaining, isShaking)
	local display = shakerModel:FindFirstChild("Display")
	if not display or not display:IsA("BasePart") then return end
	local infoGui = display:FindFirstChild("InfoGui")
	if not infoGui then return end
	local status = infoGui:FindFirstChild("Status")
	if not status then return end

	if isShaking and timeRemaining then
		local wasVisible = status.Visible
		status.Visible = true
		status.Text = ShakerUI.FormatTime(timeRemaining)

		if not wasVisible then
			local originalSize = status:GetAttribute("OriginalSize")
			if not originalSize then
				status:SetAttribute("OriginalSize", tostring(status.Size))
			end

			status.Size = UDim2.new(0.01, 0, 0.01, 0)

			local tweenInfo = TweenInfo.new(
				0.4,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			)

			local targetSizeStr = status:GetAttribute("OriginalSize")
			local targetSize
			if targetSizeStr then
				local x, xo, y, yo = targetSizeStr:match("{(%d+%.?%d*), (%d+)}, {(%d+%.?%d*), (%d+)}")
				if x and xo and y and yo then
					targetSize = UDim2.new(tonumber(x), tonumber(xo), tonumber(y), tonumber(yo))
				end
			end

			if not targetSize then
				targetSize = UDim2.new(1, 0, 1, 0)
			end

			local tween = TweenService:Create(status, tweenInfo, {
				Size = targetSize
			})

			tween:Play()
		end
	else
		if status.Visible then
			local tweenInfo = TweenInfo.new(
				0.3,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.In
			)

			local tween = TweenService:Create(status, tweenInfo, {
				Size = UDim2.new(0.01, 0, 0.01, 0)
			})

			tween.Completed:Connect(function()
				status.Visible = false
				status.Text = ""
				tween:Destroy()
			end)

			tween:Play()
		else
			status.Visible = false
			status.Text = ""
		end
	end
end

return ShakerUI
