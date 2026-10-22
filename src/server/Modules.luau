--!strict
-- Ordered list of server modules started by Main. Later phases append services here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Util.Loader)

local modules: { Loader.LoadableModule } = {
	require(script.Parent.ArenaService),
	require(script.Parent.NetService),
	require(script.Parent.BallService),
	require(script.Parent.TeamService),
	require(script.Parent.CharacterService),
	require(script.Parent.ActionService),
	require(script.Parent.MovementGuard),
	require(script.Parent.MatchService),
}

return modules
