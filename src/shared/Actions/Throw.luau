--!strict
-- The ball's velocity as it leaves a player's hands (spec §8.2): a charged throw down onto the crosshair's spot, a
-- charged roll along the floor, or a pass at a fixed speed toward its target; and the charge a held throw key gives.
-- Aims need not be unit.

local Actions = require(script.Parent.Parent.Config.Actions)
local Crossing = require(script.Parent.Parent.Rules.Crossing)
local Trajectory = require(script.Parent.Parent.Ball.Trajectory)
local Vectors = require(script.Parent.Parent.Util.Vectors)

local Throw = {}

-- How many halvings Throw.aimed takes to find the farthest point of the crosshair's line a throw reaches: 16 pin it
-- within aimReach / 65536 (0.015 studs over the default 1000).
local SEARCH_ROUNDS = 16

-- The charge of a throw key held `heldSeconds`: a share of a full one (0..1), full after chargeMaxSeconds. What a
-- throw or a roll spends and the crosshair's ring shows (#312).
function Throw.share(throw: Actions.ThrowSettings, heldSeconds: number): number
	return math.clamp(heldSeconds / throw.chargeMaxSeconds, 0, 1)
end

-- How fast a throw or a roll leaves the hand: from minSpeed at no charge to maxSpeed at a full one (`charge` is
-- clamped to 0..1).
function Throw.speed(throw: Actions.ThrowSettings, charge: number): number
	return throw.minSpeed + (throw.maxSpeed - throw.minSpeed) * math.clamp(charge, 0, 1)
end

-- Roll Ball (#312): a charged throw across the floor under the carrier, whose direction is the unit `up`: the aim's way
-- across it at the charge's whole speed, or the carrier's `facing` where the aim is straight up or down, plus their
-- velocity along the floor scaled by inheritCarrierVelocity.
function Throw.rolled(
	throw: Actions.ThrowSettings,
	aim: Vector3,
	charge: number,
	carrierVelocity: Vector3,
	up: Vector3,
	facing: Vector3
): Vector3
	local way = Vectors.alongSurface(aim.Unit, up)
	if way.Magnitude <= Vectors.EPSILON then
		way = Vectors.alongSurface(facing, up)
	end
	local carried = Vectors.alongSurface(carrierVelocity, up) * throw.inheritCarrierVelocity
	return way.Unit * Throw.speed(throw, charge) + carried
end

-- Where a throw along the crosshair's line from `origin` aims (#313, the owner: Q148): the goal ring's centre when the
-- line passes through its opening on its way to `finish` (where it first meets the arena, or ends); else `finish`.
function Throw.spot(origin: Vector3, finish: Vector3, goal: Crossing.Disc?): Vector3
	if goal ~= nil and Crossing.throughDisc(goal, origin, finish) ~= nil then
		return goal.frame.Position
	end
	return finish
end

-- A charged throw from the hand at `from` (#313, the owner: Q148, Q151): the velocity that brings the ball down on
-- `spot` under `gravity` on the flatter arc, with the carrier's share of `carrierVelocity` in it. A spot out of the
-- charge's reach falls back along the crosshair's line (`aim`, the way it runs to the spot) toward the thrower: the
-- throw goes to the farthest point of the line the charge reaches, so on the thrower's screen it still flies into the
-- crosshair. A spot behind the hand along the line leaves no line to fall back on: the least-speed arc toward it.
function Throw.aimed(
	throw: Actions.ThrowSettings,
	charge: number,
	from: Vector3,
	aim: Vector3,
	spot: Vector3,
	carrierVelocity: Vector3,
	gravity: Vector3
): Vector3
	local speed = Throw.speed(throw, charge)
	local carry = carrierVelocity * throw.inheritCarrierVelocity
	local velocity, reaches = Trajectory.toward(speed, from, spot, carry, gravity)
	local way = aim.Unit
	-- How far back along the line from the spot its point level with the hand lies.
	local back = (spot - from):Dot(way)
	if reaches or back <= 0 then
		return velocity
	end
	-- Distances back from the spot: `reached` one the charge reaches, `short` one it does not.
	local reached, short = back, 0
	for _ = 1, SEARCH_ROUNDS do
		local middle = (reached + short) / 2
		local _, inReach = Trajectory.toward(speed, from, spot - way * middle, carry, gravity)
		if inReach then
			reached = middle
		else
			short = middle
		end
	end
	return (Trajectory.toward(speed, from, spot - way * reached, carry, gravity))
end

-- Straight at the target's position, or along the aim with no target (or a target with no direction from `from`).
function Throw.pass(pass: Actions.PassSettings, from: Vector3, aim: Vector3, target: Vector3?): Vector3
	if target ~= nil then
		local offset = target - from
		if offset.Magnitude > Vectors.EPSILON then
			return offset.Unit * pass.speed
		end
	end
	return aim.Unit * pass.speed
end

return table.freeze(Throw)
