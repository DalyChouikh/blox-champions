--!strict
-- Who carries the ball, as the server last said (the BallCarrier remote). One module every client module reads, so
-- only one listens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type PlayerId = Types.PlayerId

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type BallCarrier = {
	name: string,
	dependencies: { string },
	init: (self: BallCarrier, deps: { [string]: any }) -> (),
	start: (self: BallCarrier) -> (),
	-- The carrier, or nil while the ball is loose.
	carrier: PlayerId?,
	set: (self: BallCarrier, player: PlayerId?) -> (),
}

local BallCarrier: BallCarrier = {
	name = "BallCarrier",
	dependencies = {},
	carrier = nil,

	init = function(self: BallCarrier, _deps: { [string]: any })
		self.carrier = nil
	end,

	start = function(self: BallCarrier)
		Remotes.get(ReplicatedStorage, Remotes.names.BallCarrier).OnClientEvent:Connect(function(payload: {
			carrier: PlayerId?,
		})
			self:set(payload.carrier)
		end)
	end,

	set = function(self: BallCarrier, player: PlayerId?)
		self.carrier = player
	end,
}

return BallCarrier
