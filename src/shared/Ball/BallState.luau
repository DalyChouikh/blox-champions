--!strict
-- The ball's life as the server sees it (spec §9.3): Dead (out of play — hidden for a kickoff, or after a point),
-- Loose (in play, nobody holds it), Flying (thrown, not yet down) and Carried (in a player's hand). BallService
-- applies these states to the ball part; only the server changes them.

local Types = require(script.Parent.Parent.Rules.Types)

type PlayerId = Types.PlayerId

export type Status = "Dead" | "Loose" | "Flying" | "Carried"

local FREE: { [Status]: boolean } = { Loose = true, Flying = true }
local DEAD: { [Status]: boolean } = { Dead = true }
local CARRIED: { [Status]: boolean } = { Carried = true }
local FLYING: { [Status]: boolean } = { Flying = true }

local BallState = {}
BallState.__index = BallState

type Fields = {
	status: Status,
	carrier: PlayerId?,
	-- Time since the ball last left a player's control (released, thrown, dropped or respawned) while free.
	looseSeconds: number,
	-- Time the carrier has held the ball since the catch; 0 while nobody does.
	heldSeconds: number,
	_rethrowPickupDelay: number,
	-- The last thrower, locked out of catching their own throw until _sinceThrow reaches the delay.
	_thrower: PlayerId?,
	_sinceThrow: number,
}

export type BallState = typeof(setmetatable({} :: Fields, BallState))

local function expectStatus(self: BallState, action: string, allowed: { [Status]: boolean })
	if not allowed[self.status] then
		error(`BallState: cannot {action} while {self.status}`, 0)
	end
end

-- The ball leaves a player's control: free, the idle count restarting.
local function free(self: BallState, status: Status)
	self.status = status
	self.carrier = nil
	self.looseSeconds = 0
	self.heldSeconds = 0
end

function BallState.new(rethrowPickupDelay: number): BallState
	return setmetatable(
		{
			status = "Dead",
			carrier = nil,
			looseSeconds = 0,
			heldSeconds = 0,
			_rethrowPickupDelay = rethrowPickupDelay,
			_thrower = nil,
			_sinceThrow = 0,
		} :: Fields,
		BallState
	)
end

function BallState.release(self: BallState)
	expectStatus(self, "release", DEAD)
	free(self, "Loose")
end

function BallState.pickUp(self: BallState, player: PlayerId)
	expectStatus(self, "pickUp", FREE)
	self.status = "Carried"
	self.carrier = player
	self.looseSeconds = 0
	self.heldSeconds = 0
	self._thrower = nil
end

function BallState.throw(self: BallState)
	expectStatus(self, "throw", CARRIED)
	self._thrower = self.carrier
	self._sinceThrow = 0
	free(self, "Flying")
end

function BallState.drop(self: BallState)
	expectStatus(self, "drop", CARRIED)
	free(self, "Loose")
end

function BallState.land(self: BallState)
	expectStatus(self, "land", FLYING)
	self.status = "Loose"
end

function BallState.respawn(self: BallState)
	expectStatus(self, "respawn", FREE)
	self._thrower = nil
	free(self, "Loose")
end

function BallState.kill(self: BallState)
	self._thrower = nil
	free(self, "Dead")
end

function BallState.tick(self: BallState, dt: number)
	if FREE[self.status] then
		self.looseSeconds += dt
	elseif CARRIED[self.status] then
		self.heldSeconds += dt
	end
	if self._thrower ~= nil then
		self._sinceThrow += dt
		if self._sinceThrow >= self._rethrowPickupDelay then
			self._thrower = nil
		end
	end
end

function BallState.canPickUp(self: BallState, player: PlayerId): boolean
	return FREE[self.status] == true and player ~= self._thrower
end

return BallState
