local Players = game:GetService("Players")

local ShakerTool = {}

function ShakerTool.GetPlayerFromCharacter(character)
	return Players:GetPlayerFromCharacter(character)
end

function ShakerTool.GetEquippedTool(character)
	return character:FindFirstChildOfClass("Tool")
end

function ShakerTool.IsIngredientTool(tool)
	local typeValue = tool:FindFirstChild("Type")
	if not typeValue or not typeValue:IsA("StringValue") then return false end
	return typeValue.Value == "Ingredient"
end

function ShakerTool.GetToolId(tool)
	local idValue = tool:FindFirstChild("Id")
	if idValue and idValue:IsA("IntValue") then
		return idValue.Value
	end
	return nil
end

return ShakerTool