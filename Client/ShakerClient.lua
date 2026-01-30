--[[
	ShakerClient - LocalScript del cliente
	Solo inicializa el controlador
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShakerClientController = require(
	ReplicatedStorage:WaitForChild("Modules")
	:WaitForChild("Utils")
	:WaitForChild("ShakerSystem")
	:WaitForChild("ShakerClientController")
)

ShakerClientController.init()
