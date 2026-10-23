--!strict
-- Who carries the ball, as the server last said (the BallCarrier remote). One module every client module reads, so
-- only one listens. A throw or pass predicts the ball leaving at once; a refusal undoes that, unless the server has
-- spoken since (its messages may arrive in any order).

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
	-- The server's word: it replaces any prediction.
	set: (self: BallCarrier, player: PlayerId?) -> (),
	-- The local player just threw or passed: nobody carries until the server says otherwise.
	predictRelease: (self: BallCarrier) -> (),
	-- The throw or pass was refused: the carrier is back, unless the server has spoken since the prediction.
	undoPrediction: (self: BallCarrier) -> (),
	-- Who carried before the pending prediction; nil when none is pending.
	_released: PlayerId?,
}

local BallCarrier: BallCarrier = {
	name = "BallCarrier",
	dependencies = {},
	carrier = nil,
	_released = nil,

	init = function(self: BallCarrier, _deps: { [string]: any })
		self.carrier = nil
		self._released = nil
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
		self._released = nil
	end,

	predictRelease = function(self: BallCarrier)
		self._released = self.carrier
		self.carrier = nil
	end,

	undoPrediction = function(self: BallCarrier)
		local released = self._released
		if released ~= nil then
			self.carrier = released
			self._released = nil
		end
	end,
}

return BallCarrier
