--[[
	ShakerUtils - Utilidades compartidas del sistema de Shakers
	Formateo de XP, mezcla de colores, helpers
	Solo hay UN shaker por plot - el folder Shakers ES el shaker
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local ShakerUtils = {}

local SUFFIXES = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc"}

-- Formatear XP a formato legible (ej: 5M Xp, 10K Xp)
function ShakerUtils.FormatXp(xp)
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

-- Mezclar array de colores
function ShakerUtils.MixColors(colors)
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

-- Obtener folder de shaker del plot (ES el folder Shakers directamente)
function ShakerUtils.GetShakerFolder(player)
	local currentPlot = player:FindFirstChild("CurrentPlot")
	if not currentPlot or currentPlot.Value == "" then
		return nil
	end

	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil end

	local plotFolder = plotsFolder:FindFirstChild(currentPlot.Value)
	if not plotFolder then return nil end

	return plotFolder:FindFirstChild("Shakers")
end

-- Obtener BillboardGui del shaker
function ShakerUtils.GetBillboard(player)
	local shakerFolder = ShakerUtils.GetShakerFolder(player)
	if not shakerFolder then return nil end

	local infoFolder = shakerFolder:FindFirstChild("Info")
	if not infoFolder then return nil end

	return infoFolder:FindFirstChild("BillboardGui")
end

-- Obtener Content part para ingredientes visuales
function ShakerUtils.GetContentPart(player)
	local shakerFolder = ShakerUtils.GetShakerFolder(player)
	if not shakerFolder then return nil end

	local ingredientsFolder = shakerFolder:FindFirstChild("Ingredients")
	if not ingredientsFolder then return nil end

	return ingredientsFolder:FindFirstChild("Content")
end

-- Obtener herramienta equipada
function ShakerUtils.GetEquippedTool(character)
	if not character then return nil end
	return character:FindFirstChildOfClass("Tool")
end

-- Verificar si es herramienta de ingrediente
function ShakerUtils.IsIngredientTool(tool)
	if not tool then return false end
	local typeValue = tool:FindFirstChild("Type")
	return typeValue and typeValue:IsA("StringValue") and typeValue.Value == "Ingredient"
end

-- Obtener ID de herramienta
function ShakerUtils.GetToolId(tool)
	if not tool then return nil end
	local idValue = tool:FindFirstChild("Id")
	return idValue and idValue:IsA("IntValue") and idValue.Value or nil
end

-- Obtener owner del plot
function ShakerUtils.GetPlotOwner(plotNumber)
	for _, player in ipairs(Players:GetPlayers()) do
		local currentPlot = player:FindFirstChild("CurrentPlot")
		if currentPlot and currentPlot.Value == plotNumber then
			return player
		end
	end
	return nil
end

return ShakerUtils
