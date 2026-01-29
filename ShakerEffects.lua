local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShakerEffects = {}

function ShakerEffects.MixColors(colors)
	if #colors == 0 then
		return Color3.fromRGB(255, 255, 255)
	end

	local r, g, b = 0, 0, 0
	for _, c in ipairs(colors) do
		r = r + c.R
		g = g + c.G
		b = b + c.B
	end

	return Color3.new(r / #colors, g / #colors, b / #colors)
end

function ShakerEffects.GetIngredientColors(ingredientFolders, ingredientConfig)
	local colors = {}

	for _, folder in ipairs(ingredientFolders) do
		local data = ingredientConfig.Ingredients[folder.Name]
		if data and data.Color then
			table.insert(colors, data.Color)
		end
	end

	return colors
end

return ShakerEffects
