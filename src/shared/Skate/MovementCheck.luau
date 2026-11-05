--!strict
-- Judges how far each skater's root moved between two samples (spec §10). Skating allows a top speed with a tolerance:
-- a move faster than that is a strike, and guardStrikes strikes in a row return the skater to their last valid place.
-- A move far beyond the allowance returns at once. Falling never counts, because falling is legal. Pure: it keeps
-- numbers per player and touches no Instance. It keeps the move it judged last, so the guard can say what it measured
-- (#394, the owner's Q271).

local Config = require(script.Parent.Parent.Config)

export type Verdict = "Ok" | "Strike" | "Return"

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
		}
		return
	end
	record.time = now
	record.position = position
	record.lastValid = position
	record.strikes = 0
end

-- Judges the move since the player's last sample. The first sample for a player is a reset, so it is always Ok.
function MovementCheck.sample(self: MovementCheck, player: string, position: Vector3, now: number): Verdict
	local record = self._records[player]
	if record == nil then
		self:reset(player, position, now)
		return "Ok"
	end

	local seconds = now - record.time
	local allowed = MovementCheck.speedLimit(self._movement, self._network) * seconds
	local move = position - record.position
	-- Falling is legal, so only the upward part of the move is judged.
	local rise = Vector3.new(move.X, math.max(move.Y, 0), move.Z)
	local distance = rise.Magnitude
	local strikes = if distance <= allowed then 0 else record.strikes + 1
	local jumped = distance > self._network.guardTeleportFactor * allowed
	local judged = record.move
	judged.from, judged.to, judged.seconds = record.position, position, seconds
	judged.distance, judged.allowed, judged.jumped, judged.strikes = distance, allowed, jumped, strikes

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
