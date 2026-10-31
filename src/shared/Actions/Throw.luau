--!strict
-- The ball's velocity as it leaves a player's hands (spec §8.2): a charged throw along the aim, a charged roll along
-- the floor, or a pass at a fixed speed toward its target. Aims need not be unit.

local Actions = require(script.Parent.Parent.Config.Actions)
local Vectors = require(script.Parent.Parent.Util.Vectors)

local Throw = {}

-- From minSpeed at no charge to maxSpeed at a full one (`charge` is clamped to 0..1), plus the carrier's velocity
-- scaled by inheritCarrierVelocity.
function Throw.charged(throw: Actions.ThrowSettings, aim: Vector3, charge: number, carrierVelocity: Vector3): Vector3
	local speed = throw.minSpeed + (throw.maxSpeed - throw.minSpeed) * math.clamp(charge, 0, 1)
	return aim.Unit * speed + carrierVelocity * throw.inheritCarrierVelocity
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
	return Throw.charged(throw, way, charge, Vectors.alongSurface(carrierVelocity, up))
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
