--[[
	ShakerConfig - Configuración central del sistema de Shakers
	Contiene constantes y configuraciones del sistema
]]

local ShakerConfig = {}

-- Límites
ShakerConfig.MAX_INGREDIENTS = 3
ShakerConfig.TOUCH_COOLDOWN = 2 -- Cooldown entre clicks de TouchPart (segundos)
ShakerConfig.INTERACTION_COOLDOWN = 0.5

-- XP por toque
ShakerConfig.XP_PER_TOUCH = 1

-- Porcentajes de aumento de XP por energizantes
ShakerConfig.ENERGIZERS = {
	["Energizing"] = 0.10,      -- +10%
	["Mid Energizing"] = 0.25,  -- +25%
	["Big Energizing"] = 0.50   -- +50%
}

-- Colores para notificaciones
ShakerConfig.COLORS = {
	ERROR = Color3.fromRGB(255, 85, 85),
	SUCCESS = Color3.fromRGB(85, 255, 85),
	INFO = Color3.fromRGB(85, 170, 255)
}

-- Nombres de RemoteEvents
ShakerConfig.EVENTS = {
	START_MIXING = "StartMixing",
	STOP_MIXING = "StopMixing",
	UPDATE_PROGRESS = "UpdateProgress",
	COMPLETE_MIXING = "CompleteMixing",
	ADD_XP = "AddXp"
}

return ShakerConfig
