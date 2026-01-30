--[[
	ShakerEffects - Efectos de sonido y partículas VFX
	Usa Trove para limpieza automática
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Data.Trove)

local ShakerEffects = {}

-- Referencias a carpetas de assets
local shakerSFXFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Sounds"):WaitForChild("SFX"):WaitForChild("Shakers")
local shakerVFXFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Shakers")

-- Sonidos
local addIngredientSound = shakerSFXFolder:WaitForChild("AddIngredient")
local removeIngredientSound = shakerSFXFolder:WaitForChild("Remove")

local energizingSound = shakerSFXFolder:FindFirstChild("Energizing")
local midEnergizingSound = shakerSFXFolder:FindFirstChild("MidEnergizing")
local bigEnergizingSound = shakerSFXFolder:FindFirstChild("BigEnergizing")

-- VFX
local bubblesVFX = shakerVFXFolder:WaitForChild("Bubbles")

local energizingVFX = shakerVFXFolder:FindFirstChild("Energizing")
local midEnergizingVFX = shakerVFXFolder:FindFirstChild("MidEnergizing")
local bigEnergizingVFX = shakerVFXFolder:FindFirstChild("BigEnergizing")

-- Trove para efectos activos
local shakeEffectsTrove = nil

------------------------------------------------------------------------
-- UTILIDADES DE COLOR
------------------------------------------------------------------------

function ShakerEffects.MixColors(colors)
	if #colors == 0 then
		return Color3.fromRGB(255, 255, 255)
	end

	local r, g, b = 0, 0, 0
	for _, c in ipairs(colors) do
		r += c.R
		g += c.G
		b += c.B
	end

	return Color3.new(r / #colors, g / #colors, b / #colors)
end

------------------------------------------------------------------------
-- SONIDOS DE INGREDIENTES
------------------------------------------------------------------------

function ShakerEffects.PlayAddIngredientSound(contentPart)
	if not contentPart or not contentPart:IsA("BasePart") then return end

	local trove = Trove.new()
	local s = addIngredientSound:Clone()
	s.Parent = contentPart
	trove:Add(s)
	s:Play()

	trove:Connect(s.Ended, function()
		trove:Destroy()
	end)
end

function ShakerEffects.PlayRemoveIngredientSound(contentPart)
	if not contentPart or not contentPart:IsA("BasePart") then return end

	local trove = Trove.new()
	local s = removeIngredientSound:Clone()
	s.Parent = contentPart
	trove:Add(s)
	s:Play()

	trove:Connect(s.Ended, function()
		trove:Destroy()
	end)
end

------------------------------------------------------------------------
-- EFECTO DE BURBUJAS AL AÑADIR INGREDIENTE
------------------------------------------------------------------------

function ShakerEffects.PlayAddIngredientBubbles(contentPart, ingredientColor)
	if not contentPart or not contentPart:IsA("BasePart") then return end
	if not ingredientColor then return end

	local trove = Trove.new()

	for _, effect in ipairs(bubblesVFX:GetChildren()) do
		if effect:IsA("ParticleEmitter") then
			local emitterClone = effect:Clone()
			emitterClone.Color = ColorSequence.new(ingredientColor)
			emitterClone.Enabled = true
			emitterClone.Parent = contentPart
			trove:Add(emitterClone)
		end
	end

	task.delay(0.5, function()
		trove:Destroy()
	end)
end

------------------------------------------------------------------------
-- EFECTOS DE ENERGIZANTES
------------------------------------------------------------------------

local function playEnergizingEffect(contentPart, vfxPart)
	if not contentPart or not vfxPart then return end

	local trove = Trove.new()

	local vfxClone = vfxPart:Clone()
	vfxClone.CFrame = contentPart.CFrame
	vfxClone.Parent = contentPart
	trove:Add(vfxClone)

	local particles = {}
	for _, d in ipairs(vfxClone:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Enabled = false
			table.insert(particles, d)
		end
	end

	task.wait()

	for _, p in ipairs(particles) do
		if p and p.Parent then
			p.Enabled = true
		end
	end

	task.delay(0.5, function()
		for _, p in ipairs(particles) do
			if p and p.Parent then
				p.Enabled = false
			end
		end

		task.wait(2)
		trove:Destroy()
	end)
end

function ShakerEffects.PlayEnergizingSound(contentPart)
	if not contentPart or not contentPart:IsA("BasePart") then return end

	local trove = Trove.new()

	local soundToUse = energizingSound or addIngredientSound
	local s = soundToUse:Clone()
	if not energizingSound then
		s.PlaybackSpeed = 1.5
	end
	s.Parent = contentPart
	trove:Add(s)
	s:Play()

	trove:Connect(s.Ended, function()
		trove:Destroy()
	end)

	if energizingVFX then
		playEnergizingEffect(contentPart, energizingVFX)
	end
end

function ShakerEffects.PlayMidEnergizingSound(contentPart)
	if not contentPart or not contentPart:IsA("BasePart") then return end

	local trove = Trove.new()

	local soundToUse = midEnergizingSound or addIngredientSound
	local s = soundToUse:Clone()
	if not midEnergizingSound then
		s.PlaybackSpeed = 1.75
	end
	s.Parent = contentPart
	trove:Add(s)
	s:Play()

	trove:Connect(s.Ended, function()
		trove:Destroy()
	end)

	if midEnergizingVFX then
		playEnergizingEffect(contentPart, midEnergizingVFX)
	end
end

function ShakerEffects.PlayBigEnergizingSound(contentPart)
	if not contentPart or not contentPart:IsA("BasePart") then return end

	local trove = Trove.new()

	local soundToUse = bigEnergizingSound or addIngredientSound
	local s = soundToUse:Clone()
	if not bigEnergizingSound then
		s.PlaybackSpeed = 2.0
	end
	s.Parent = contentPart
	trove:Add(s)
	s:Play()

	trove:Connect(s.Ended, function()
		trove:Destroy()
	end)

	if bigEnergizingVFX then
		playEnergizingEffect(contentPart, bigEnergizingVFX)
	end
end

------------------------------------------------------------------------
-- EFECTOS DE MEZCLA (BURBUJAS CONTINUAS)
------------------------------------------------------------------------

function ShakerEffects.StartShakeEffects(contentPart, mixedColor)
	if not contentPart then return end

	ShakerEffects.StopShakeEffects()

	shakeEffectsTrove = Trove.new()

	for _, effect in ipairs(bubblesVFX:GetChildren()) do
		if effect:IsA("ParticleEmitter") then
			local emitterClone = effect:Clone()
			emitterClone.Color = ColorSequence.new(mixedColor)
			emitterClone.Enabled = true
			emitterClone.Parent = contentPart
			shakeEffectsTrove:Add(emitterClone)
		end
	end
end

function ShakerEffects.StopShakeEffects()
	if shakeEffectsTrove then
		shakeEffectsTrove:Destroy()
		shakeEffectsTrove = nil
	end
end

function ShakerEffects.cleanup()
	ShakerEffects.StopShakeEffects()
end

return ShakerEffects
