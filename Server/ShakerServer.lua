--[[
	ShakerServer - Script principal del servidor
	Solo inicializa el controlador y conecta eventos
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShakerServerController = require(
	ReplicatedStorage:WaitForChild("Modules")
	:WaitForChild("Utils")
	:WaitForChild("ShakerSystem")
	:WaitForChild("ShakerServerController")
)

------------------------------------------------------------------------
-- CREAR EVENTOS
------------------------------------------------------------------------

local eventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "RemoteEvents"
	eventsFolder.Parent = ReplicatedStorage
end

local shakersFolder = eventsFolder:FindFirstChild("Shakers")
if not shakersFolder then
	shakersFolder = Instance.new("Folder")
	shakersFolder.Name = "Shakers"
	shakersFolder.Parent = eventsFolder
end

local function getOrCreateEvent(name)
	local event = shakersFolder:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = shakersFolder
	end
	return event
end

local Events = {
	StartMixing = getOrCreateEvent("StartMixing"),
	StopMixing = getOrCreateEvent("StopMixing"),
	UpdateProgress = getOrCreateEvent("UpdateProgress"),
	CompleteMixing = getOrCreateEvent("CompleteMixing"),
	ShakerClick = getOrCreateEvent("ShakerClick"),
	TouchPartClick = getOrCreateEvent("TouchPartClick"),
	CancelMixing = getOrCreateEvent("CancelMixing"),
	IngredientAdded = getOrCreateEvent("IngredientAdded"),
	IngredientRemoved = getOrCreateEvent("IngredientRemoved"),
	EnergizingAdded = getOrCreateEvent("EnergizingAdded"),
	Warning = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Warn"):WaitForChild("Warning")
}

------------------------------------------------------------------------
-- INICIALIZAR CONTROLADOR
------------------------------------------------------------------------

ShakerServerController.init(Events)

------------------------------------------------------------------------
-- CONECTAR EVENTOS
------------------------------------------------------------------------

Events.ShakerClick.OnServerEvent:Connect(function(player, plotNumber)
	ShakerServerController.handleShakerClick(player, plotNumber)
end)

Events.TouchPartClick.OnServerEvent:Connect(function(player, plotNumber)
	ShakerServerController.handleTouchPartClick(player, plotNumber)
end)

Events.CancelMixing.OnServerEvent:Connect(function(player, plotNumber)
	ShakerServerController.handleCancelMixing(player, plotNumber)
end)

------------------------------------------------------------------------
-- JUGADORES
------------------------------------------------------------------------

Players.PlayerAdded:Connect(ShakerServerController.onPlayerAdded)
Players.PlayerRemoving:Connect(ShakerServerController.onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(ShakerServerController.onPlayerAdded, player)
end
