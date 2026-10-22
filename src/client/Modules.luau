--!strict
-- Ordered list of client modules started by Main. Later phases append controllers here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Util.Loader)

local modules: { Loader.LoadableModule } = {
	require(script.Parent.InputController),
	require(script.Parent.SkateController),
	require(script.Parent.PoseController),
}

return modules
