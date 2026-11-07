--!strict
-- Judges how far each skater's root moved between two samples (spec §10). Skating allows a top speed with a tolerance:
-- a move faster than that is a strike, and guardStrikes strikes in a row return the skater to their last valid place.
-- A move far beyond the allowance returns at once. Falling never counts, because falling is legal. A server placement
-- starts the skater over where it put them, and for a while a report from where they stood before is Stale (#424):
-- their client sent it before it saw the placement, so it puts them back without a strike. Pure: it keeps numbers per
-- player and touches no Instance. It keeps the move it judged last, so the guard can say what it measured (#394, the
-- owner's Q271).

local Config = require(script.Parent.Parent.Config)

export type Verdict = "Ok" | "Strike" | "Return" | "Stale"

-- The move a sample judged: where from and where to, over how long, how far it counted (only the upward part of a
-- fall), how far that time allowed, whether it went past guardTeleportFactor times that, and how many samples in a row
-- have been over the allowance, this one included. One per player, written over by each sample, so judging allocates
-- nothing.
export type Move = {
	from: Vector3,
	to: Vector3,
	seconds: number,
	distance: number,
	allowed: number,
	jumped: boolean,
	strikes: number,
}

type Record = {
	time: number,
	position: Vector3,
	lastValid: Vector3,
	strikes: number,
	move: Move,
	-- Where the server's last placement took the skater from, and when (-math.huge before any).
	placedFrom: Vector3,
	placedAt: number,
}

type Fields = {
	_movement: Config.MovementConfig,
	_network: Config.NetworkConfig,
	_records: { [string]: Record },
}

local MovementCheck = {}
MovementCheck.__index = MovementCheck

export type MovementCheck = typeof(setmetatable({} :: Fields, MovementCheck))

-- The fastest a skater may move: hardCap with the speed tolerance. The server trusts no client-reported velocity
-- beyond it.
function MovementCheck.speedLimit(movement: Config.MovementConfig, network: Config.NetworkConfig): number
	return movement.hardCap * network.speedTolerance
end

-- How far a move counts: falling is legal, so only its upward part.
local function risen(move: Vector3): number
	return Vector3.new(move.X, math.max(move.Y, 0), move.Z).Magnitude
end

-- Whether a report could be one the client sent before it saw its last placement: within guardPlacementSeconds of
-- it, and within that time's skating of where the skater stood before.
local function sentBeforePlacement(self: MovementCheck, record: Record, position: Vector3, now: number): boolean
	local window = self._network.guardPlacementSeconds
	return now - record.placedAt <= window
		and risen(position - record.placedFrom) <= MovementCheck.speedLimit(self._movement, self._network) * window
end

function MovementCheck.new(movement: Config.MovementConfig, network: Config.NetworkConfig): MovementCheck
	local self: Fields = {
		_movement = movement,
		_network = network,
		_records = {},
	}
	return setmetatable(self, MovementCheck)
end

-- Starts a player over at `position`: their next sample is measured from here. A player's record is reused, so only
-- their first sample allocates.
function MovementCheck.reset(self: MovementCheck, player: string, position: Vector3, now: number)
	local record = self._records[player]
	if record == nil then
		self._records[player] = {
			time = now,
			position = position,
			lastValid = position,
			strikes = 0,
			move = {
				from = position,
				to = position,
				seconds = 0,
				distance = 0,
				allowed = 0,
				jumped = false,
				strikes = 0,
			},
			placedFrom = position,
			placedAt = -math.huge,
		}
		return
	end
	record.time = now
	record.position = position
	record.lastValid = position
	record.strikes = 0
end

-- The server moved the player from `from` to `to`: their next sample is judged from `to`, and for
-- guardPlacementSeconds a report near `from` is Stale.
function MovementCheck.place(self: MovementCheck, player: string, from: Vector3, to: Vector3, now: number)
	self:reset(player, to, now)
	local record = self._records[player]
	record.placedFrom = from
	record.placedAt = now
end

-- Judges the move since the player's last sample. The first sample for a player is a reset, so it is always Ok. A move
-- over the allowance that a report from before the last placement explains is Stale, and starts the player over at
-- their last valid place, where the guard puts them back.
function MovementCheck.sample(self: MovementCheck, player: string, position: Vector3, now: number): Verdict
	local record = self._records[player]
	if record == nil then
		self:reset(player, position, now)
		return "Ok"
	end

	local seconds = now - record.time
	local allowed = MovementCheck.speedLimit(self._movement, self._network) * seconds
	local distance = risen(position - record.position)
	local strikes = if distance <= allowed then 0 else record.strikes + 1
	local jumped = distance > self._network.guardTeleportFactor * allowed
	local judged = record.move
	judged.from, judged.to, judged.seconds = record.position, position, seconds
	judged.distance, judged.allowed, judged.jumped, judged.strikes = distance, allowed, jumped, strikes

	if strikes > 0 and sentBeforePlacement(self, record, position, now) then
		self:reset(player, record.lastValid, now)
		return "Stale"
	end
	if jumped or strikes >= self._network.guardStrikes then
		self:reset(player, record.lastValid, now)
		return "Return"
	end
	record.time = now
	record.position = position
	record.strikes = strikes
	if strikes == 0 then
		record.lastValid = position
		return "Ok"
	end
	return "Strike"
end

-- The move the player's last sample judged (their reset's, standing still, before any), or nil for a player with no
-- record.
function MovementCheck.lastMove(self: MovementCheck, player: string): Move?
	local record = self._records[player]
	return if record ~= nil then record.move else nil
end

function MovementCheck.lastValid(self: MovementCheck, player: string): Vector3?
	local record = self._records[player]
	return if record ~= nil then record.lastValid else nil
end

-- Forgets a player: their next sample is a reset.
function MovementCheck.forget(self: MovementCheck, player: string)
	self._records[player] = nil
end

return MovementCheck
