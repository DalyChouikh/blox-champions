--!strict
-- Decides whether a defender's contact with the ball is a save (spec §6.3): a block of a thrown ball headed
-- through the open ring, either way, within the lookahead, or a pickup that steals the ball from the team whose
-- goal is open. One contact that is both counts once, as a block. The engine calls this only for a contact by
-- the team defending an open goal.

local Crossing = require(script.Parent.Crossing)
local Trajectory = require(script.Parent.Parent.Ball.Trajectory)
local Types = require(script.Parent.Types)

export type Contact = "Pickup" | "Touch"

local SaveDetector = {}
SaveDetector.__index = SaveDetector

type Fields = {
	_ring: Crossing.Disc,
	_gravity: Vector3,
	_lookaheadSeconds: number,
}

export type SaveDetector = typeof(setmetatable({} :: Fields, SaveDetector))

-- Whether the ball, on its path at time t (nil: no crossing), is inside the ring.
local function inRingAt(self: SaveDetector, position: Vector3, velocity: Vector3, t: number?): boolean
	return t ~= nil and Crossing.withinDisc(self._ring, Trajectory.positionAt(position, velocity, self._gravity, t))
end

function SaveDetector.new(ring: Crossing.Disc, gravity: Vector3, lookaheadSeconds: number): SaveDetector
	return setmetatable(
		{ _ring = ring, _gravity = gravity, _lookaheadSeconds = lookaheadSeconds } :: Fields,
		SaveDetector
	)
end

function SaveDetector.classify(
	self: SaveDetector,
	contact: Contact,
	ballThrown: boolean,
	ballPosition: Vector3,
	ballVelocity: Vector3
): Types.SaveKind?
	if ballThrown then
		-- An arc can meet the ring's plane twice (an upright ring's, once): either crossing through the ring counts.
		local first, second = Trajectory.crossingTimes(
			ballPosition,
			ballVelocity,
			self._gravity,
			self._ring.frame,
			self._lookaheadSeconds
		)
		if inRingAt(self, ballPosition, ballVelocity, first) or inRingAt(self, ballPosition, ballVelocity, second) then
			return "Block"
		end
	end
	if contact == "Pickup" then
		return "Steal"
	end
	return nil
end

return SaveDetector
