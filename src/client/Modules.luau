--!strict
-- Ordered list of client modules started by Main. Later phases append controllers here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Util.Loader)

local modules: { Loader.LoadableModule } = {
	require(script.Parent.RobloxDefaults),
	require(script.Parent.InputController),
	require(script.Parent.RideSurfaces),
	require(script.Parent.BallCarrier),
	require(script.Parent.SkateController),
	require(script.Parent.ActionController),
	require(script.Parent.PoseController),
	require(script.Parent.CameraController),
	require(script.Parent.TouchControls),
	require(script.Parent.HudStore),
	require(script.Parent.Hud),
	require(script.Parent.FrameController),
}

return modules
