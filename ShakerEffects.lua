local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Trove = require(ReplicatedStorage.Modules.Data.Trove)

local ShakerEffects = {}

local shakerSFXFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Sounds"):WaitForChild("SFX"):WaitForChild("Shakers")

local addIngredientSound = shakerSFXFolder:WaitForChild("AddIngredient")
local removeIngredientSound = shakerSFXFolder:WaitForChild("Remove")
local bubblesSound = shakerSFXFolder:WaitForChild("Bubbles")
local pourSFX = shakerSFXFolder:WaitForChild("PourSFX")

local bubblesVFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Shakers"):WaitForChild("Bubbles")
local pourVFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Shakers"):WaitForChild("PourVFX")

local energizingVFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Shakers"):WaitForChild("Energizing")
local midEnergizingVFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Shakers"):WaitForChild("MidEnergizing")
local bigEnergizingVFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Shakers"):WaitForChild("BigEnergizing")

local energizingSound = shakerSFXFolder:WaitForChild("Energizing", 5)
local midEnergizingSound = shakerSFXFolder:WaitForChild("MidEnergizing", 5)
local bigEnergizingSound = shakerSFXFolder:WaitForChild("BigEnergizing", 5)

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

function ShakerEffects.ApplyColorToParticles(parent, color)
	for _, child in ipairs(parent:GetDescendants()) do
		if child:IsA("ParticleEmitter") then
			child.Color = ColorSequence.new(color)
		end
	end
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

local function cleanupAddIngredientSounds(contentPart)
	if not contentPart then return end

	for _, child in ipairs(contentPart:GetChildren()) do
		if child:IsA("Sound") and child.Name == "AddIngredient" then
			child:Stop()
			child:Destroy()
		end
	end
end

local function cleanupRemoveIngredientSounds(contentPart)
	if not contentPart then return end

	for _, child in ipairs(contentPart:GetChildren()) do
		if child:IsA("Sound") and child.Name == "Remove" then
			child:Stop()
			child:Destroy()
		end
	end
end

function ShakerEffects.PlayAddIngredientSound(contentPart)
	if not contentPart or not contentPart:IsA("BasePart") then return end

	cleanupAddIngredientSounds(contentPart)

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

	cleanupRemoveIngredientSounds(contentPart)

	local trove = Trove.new()
	local s = removeIngredientSound:Clone()
	s.Parent = contentPart
	trove:Add(s)
	s:Play()

	trove:Connect(s.Ended, function()
		trove:Destroy()
	end)
end

local function cleanupEnergizingSounds(contentPart)
	if not contentPart then return end

	for _, child in ipairs(contentPart:GetChildren()) do
		if child:IsA("Sound") and (child.Name == "Energizing" or child.Name == "MidEnergizing" or child.Name == "BigEnergizing") then
			child:Stop()
			child:Destroy()
		end
	end
end

local function playEnergizingEffect(contentPart, vfxPart)
	if not contentPart or not vfxPart then return end

	local trove = Trove.new()

	-- Clonar la parte de VFX
	local vfxClone = vfxPart:Clone()
	vfxClone.CFrame = contentPart.CFrame
	vfxClone.Parent = contentPart
	trove:Add(vfxClone)

	-- Recolectar todas las partículas y asegurar que estén deshabilitadas
	local particles = {}
	for _, d in ipairs(vfxClone:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Enabled = false
			table.insert(particles, d)
		end
	end

	-- Esperar un frame para asegurar que todo está listo
	task.wait()

	-- Habilitar las partículas
	for _, p in ipairs(particles) do
		if p and p.Parent then
			p.Enabled = true
		end
	end

	-- Después de 0.5 segundos, deshabilitar las partículas
	task.delay(0.5, function()
		for _, p in ipairs(particles) do
			if p and p.Parent then
				p.Enabled = false
			end
		end

		-- Esperar a que las partículas existentes se disipen
		task.wait(2)

		-- Limpiar todo
		trove:Destroy()
	end)
end

function ShakerEffects.PlayEnergizingSound(contentPart)
	if not contentPart or not contentPart:IsA("BasePart") then return end

	cleanupEnergizingSounds(contentPart)

	local trove = Trove.new()

	if not energizingSound then
		cleanupAddIngredientSounds(contentPart)

		local s = addIngredientSound:Clone()
		s.PlaybackSpeed = 1.5
		s.Parent = contentPart
		trove:Add(s)
		s:Play()
		trove:Connect(s.Ended, function()
			trove:Destroy()
		end)
		return
	end

	local s = energizingSound:Clone()
	s.Parent = contentPart
	trove:Add(s)
	s:Play()

	trove:Connect(s.Ended, function()
		trove:Destroy()
	end)

	-- Reproducir efecto de partículas
	playEnergizingEffect(contentPart, energizingVFX)
end

function ShakerEffects.PlayMidEnergizingSound(contentPart)
	if not contentPart or not contentPart:IsA("BasePart") then return end

	cleanupEnergizingSounds(contentPart)

	local trove = Trove.new()

	if not midEnergizingSound then
		cleanupAddIngredientSounds(contentPart)

		local s = addIngredientSound:Clone()
		s.PlaybackSpeed = 1.75
		s.Parent = contentPart
		trove:Add(s)
		s:Play()
		trove:Connect(s.Ended, function()
			trove:Destroy()
		end)
		return
	end

	local s = midEnergizingSound:Clone()
	s.Parent = contentPart
	trove:Add(s)
	s:Play()

	trove:Connect(s.Ended, function()
		trove:Destroy()
	end)

	-- Reproducir efecto de partículas
	playEnergizingEffect(contentPart, midEnergizingVFX)
end

function ShakerEffects.PlayBigEnergizingSound(contentPart)
	if not contentPart or not contentPart:IsA("BasePart") then return end

	cleanupEnergizingSounds(contentPart)

	local trove = Trove.new()

	if not bigEnergizingSound then
		cleanupAddIngredientSounds(contentPart)

		local s = addIngredientSound:Clone()
		s.PlaybackSpeed = 2.0
		s.Parent = contentPart
		trove:Add(s)
		s:Play()
		trove:Connect(s.Ended, function()
			trove:Destroy()
		end)
		return
	end

	local s = bigEnergizingSound:Clone()
	s.Parent = contentPart
	trove:Add(s)
	s:Play()

	trove:Connect(s.Ended, function()
		trove:Destroy()
	end)

	-- Reproducir efecto de partículas
	playEnergizingEffect(contentPart, bigEnergizingVFX)
end

local function cleanupBubbleEffects(contentPart)
	if not contentPart then return end

	for _, child in ipairs(contentPart:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			child:Destroy()
		end
		if child:IsA("Sound") and child.Name == "Bubbles" then
			child:Stop()
			child:Destroy()
		end
	end
end

function ShakerEffects.StartShakeEffects(shakerModel, mixedColor)
	local juicesFolder = shakerModel:FindFirstChild("Juices")
	if not juicesFolder then return end

	local contentPart = juicesFolder:FindFirstChild("Content")
	if not contentPart then return end

	cleanupAddIngredientSounds(contentPart)
	cleanupRemoveIngredientSounds(contentPart)
	cleanupEnergizingSounds(contentPart)
	cleanupBubbleEffects(contentPart)

	local soundClone = bubblesSound:Clone()
	soundClone.Parent = contentPart
	soundClone.Looped = true
	soundClone:Play()

	-- Clonar y habilitar las partículas
	for _, effect in ipairs(bubblesVFX:GetChildren()) do
		if effect:IsA("ParticleEmitter") then
			local emitterClone = effect:Clone()
			emitterClone.Color = ColorSequence.new(mixedColor)
			emitterClone.Enabled = true
			emitterClone.Parent = contentPart
		end
	end

	return soundClone, contentPart
end

function ShakerEffects.StopShakeEffects(soundClone, contentPart)
	if soundClone and soundClone.Parent then
		-- Fade out suave del volumen del sonido
		local originalVolume = soundClone.Volume
		local fadeOutTween = TweenService:Create(soundClone, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {
			Volume = 0
		})

		fadeOutTween.Completed:Connect(function()
			soundClone:Stop()
			soundClone:Destroy()
			fadeOutTween:Destroy()
		end)

		fadeOutTween:Play()
	end

	if contentPart then
		-- Desactivar gradualmente las partículas
		local particlesToFade = {}
		for _, child in ipairs(contentPart:GetChildren()) do
			if child:IsA("ParticleEmitter") then
				table.insert(particlesToFade, child)
			end
		end

		-- Deshabilitar las partículas para que no se emitan más
		for _, emitter in ipairs(particlesToFade) do
			if emitter and emitter.Parent then
				emitter.Enabled = false
			end
		end

		-- Esperar un poco para que las partículas existentes se disipen naturalmente
		task.delay(1.5, function()
			if contentPart then
				cleanupAddIngredientSounds(contentPart)
				cleanupRemoveIngredientSounds(contentPart)
				cleanupEnergizingSounds(contentPart)
				cleanupBubbleEffects(contentPart)
			end
		end)
	end
end

function ShakerEffects.PlayPourEffect(shakerModel, mixedColor)
	local pourPart = shakerModel:FindFirstChild("Pour")
	if not pourPart then return end

	local trove = Trove.new()

	local pourVFXClone = pourVFX:Clone()
	pourVFXClone.CFrame = pourPart.CFrame
	pourVFXClone.Parent = shakerModel
	trove:Add(pourVFXClone)

	ShakerEffects.ApplyColorToParticles(pourVFXClone, mixedColor)

	local pourSound = pourSFX:Clone()
	pourSound.Parent = pourPart
	trove:Add(pourSound)

	-- Recolectar todas las partículas y asegurar que estén deshabilitadas
	local particles = {}
	for _, d in ipairs(pourVFXClone:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Enabled = false
			table.insert(particles, d)
		end
	end

	-- Iniciar el sonido
	pourSound:Play()

	-- Esperar un frame para asegurar que todo está listo
	task.wait()

	-- Habilitar las partículas
	for _, p in ipairs(particles) do
		if p and p.Parent then
			p.Enabled = true
		end
	end

	-- Loop de emisión mientras suena
	local emitConnection
	emitConnection = trove:Connect(RunService.Heartbeat, function()
		if pourSound.IsPlaying then
			for _, p in ipairs(particles) do
				if p and p.Parent and p.Enabled then
					p:Emit(2)
				end
			end
		else
			if emitConnection then
				emitConnection:Disconnect()
			end
		end
	end)

	-- Cuando termine el sonido, deshabilitar las partículas
	trove:Connect(pourSound.Ended, function()
		-- Deshabilitar para que no se emitan más
		for _, p in ipairs(particles) do
			if p and p.Parent then
				p.Enabled = false
			end
		end

		-- Esperar a que las partículas existentes se disipen
		task.wait(2.5)

		-- Limpiar todo
		trove:Destroy()
	end)
end

function ShakerEffects.SetStartButtonColor(shakerModel, isActive)
	local startPart = shakerModel:FindFirstChild("Start")
	if not startPart then return end

	if isActive then
		startPart.Color = Color3.fromRGB(255, 0, 0)
	else
		startPart.Color = Color3.fromRGB(0, 255, 0)
	end
end

function ShakerEffects.PlayAddIngredientBubbles(contentPart, ingredientColor)
	if not contentPart or not contentPart:IsA("BasePart") then return end
	if not ingredientColor then return end

	local particleClones = {}

	-- Clonar todas las partículas de burbujas
	for _, effect in ipairs(bubblesVFX:GetChildren()) do
		if effect:IsA("ParticleEmitter") then
			local emitterClone = effect:Clone()
			emitterClone.Color = ColorSequence.new(ingredientColor)
			emitterClone.Enabled = true
			emitterClone.Parent = contentPart
			table.insert(particleClones, emitterClone)
		end
	end

	-- Después de 0.5 segundos, deshabilitar y destruir las partículas
	task.delay(0.5, function()
		for _, emitter in ipairs(particleClones) do
			if emitter and emitter.Parent then
				emitter.Enabled = false
			end
		end

		-- Esperar un poco más para que las partículas existentes terminen de renderizarse
		task.delay(2, function()
			for _, emitter in ipairs(particleClones) do
				if emitter and emitter.Parent then
					emitter:Destroy()
				end
			end
		end)
	end)
end

return ShakerEffects