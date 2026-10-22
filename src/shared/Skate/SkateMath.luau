--!strict
-- One skater's momentum (spec §7): velocity, mode and orientation, stepped from the stick, the ground ray and the
-- time. Pure and deterministic. A step mutates the skater in place and allocates nothing (vectors are values), so
-- the client can run it every physics step.

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Types)

-- Below this a vector has no usable direction.
local EPSILON = 1e-6

local SkateMath = {}
SkateMath.__index = SkateMath

type Fields = {
	-- What the controller applies: momentum plus the hover's pull along the surface normal.
	velocity: Vector3,
	mode: Types.Mode,
	up: Vector3,
	-- The way the skater faces; kept while stopped.
	forward: Vector3,
	_movement: Config.MovementConfig,
	_gravity: Vector3,
	-- Gravity's pull along a surface no steeper than pumpFlatSlopeDeg: pumping there counts as on the flat.
	_flatPull: number,
}

export type Skater = typeof(setmetatable({} :: Fields, SkateMath))

function SkateMath.new(movement: Config.MovementConfig, gravity: Vector3): Skater
	local self: Fields = {
		velocity = Vector3.zero,
		mode = "Grounded",
		up = -gravity.Unit,
		forward = -Vector3.zAxis,
		_movement = movement,
		_gravity = gravity,
		_flatPull = gravity.Magnitude * math.sin(math.rad(movement.pumpFlatSlopeDeg)),
	}
	return setmetatable(self, SkateMath)
end

-- `vector` without its part along `normal`.
local function alongSurface(vector: Vector3, normal: Vector3): Vector3
	return vector - normal * vector:Dot(normal)
end

-- `from` turned toward `to` (both unit vectors) by at most `maxAngle` radians, about `fallbackAxis` when they are
-- exactly opposite.
local function rotateToward(from: Vector3, to: Vector3, maxAngle: number, fallbackAxis: Vector3): Vector3
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	if angle <= maxAngle then
		return to
	end
	local axis = from:Cross(to)
	axis = if axis.Magnitude > EPSILON then axis.Unit else fallbackAxis
	local cos, sin = math.cos(maxAngle), math.sin(maxAngle)
	return from * cos + axis:Cross(from) * sin + axis * (axis:Dot(from) * (1 - cos))
end

-- Turns widen with speed: turnRateLow at rest down to turnRateHigh at hardCap.
local function turnRate(movement: Config.MovementConfig, speed: number): number
	local fraction = math.min(speed / movement.hardCap, 1)
	return movement.turnRateLow + (movement.turnRateHigh - movement.turnRateLow) * fraction
end

-- Pumping multiplies the pull downhill, gives a small push on the flat and nothing uphill.
local function pumpPush(self: Skater, downhillPull: number): number
	local movement = self._movement
	if downhillPull > self._flatPull then
		return math.max(movement.pumpFlatAccel, (movement.pumpSlopeMultiplier - 1) * downhillPull)
	elseif downhillPull >= -self._flatPull then
		return movement.pumpFlatAccel
	end
	return 0
end

local function stepGrounded(self: Skater, input: Types.SkateInput, ground: Types.Ground, dt: number)
	local movement = self._movement
	local normal = ground.normal
	local velocity = alongSurface(self.velocity, normal)
	local speed = velocity.Magnitude
	local heading = if speed > EPSILON then velocity / speed else alongSurface(self.forward, normal).Unit

	local stick = math.min(input.move.Magnitude, 1)
	local wish = alongSurface(input.move, normal)
	local wishDirection = Vector3.zero
	if stick > 0 and wish.Magnitude > EPSILON then
		wishDirection = wish.Unit
		heading = if speed > EPSILON
			then rotateToward(heading, wishDirection, turnRate(movement, speed) * dt, normal)
			else wishDirection
	else
		stick = 0
	end

	local gravityAlong = alongSurface(self._gravity, normal)
	local acceleration = gravityAlong + heading * input.draftAccel
	if input.pump and not input.brake then
		acceleration += heading * pumpPush(self, gravityAlong:Dot(heading))
	end
	if not input.brake and stick > 0 and speed < movement.cruiseSpeed then
		acceleration += heading * (movement.strideAccel * stick * math.max(0, wishDirection:Dot(heading)))
	end
	local forwardPart = acceleration:Dot(heading)
	if forwardPart > 0 and speed > movement.softCap then
		local kept = math.clamp((movement.hardCap - speed) / (movement.hardCap - movement.softCap), 0, 1)
		acceleration -= heading * (forwardPart * (1 - kept))
	end

	velocity = heading * speed + acceleration * dt
	speed = velocity.Magnitude
	local direction = if speed > EPSILON then velocity / speed else heading
	speed = math.max(0, speed - (movement.rollingFriction + movement.airDrag * speed) * dt)
	if input.brake then
		local tiptoe = movement.tiptoeSpeed * stick
		if speed > tiptoe then
			speed = math.max(tiptoe, speed - movement.brakeDecel * dt)
		end
		if stick > 0 and speed <= tiptoe then
			direction = wishDirection
			speed = tiptoe
		end
	end
	speed = math.min(speed, movement.hardCap)

	self.velocity = direction * speed + normal * ((movement.hoverHeight - ground.distance) * movement.hoverSpring)
	self.up = normal
	self.forward = if speed > EPSILON then direction else heading
end

function SkateMath.step(self: Skater, input: Types.SkateInput, ground: Types.Ground, dt: number)
	stepGrounded(self, input, ground, dt)
end

return SkateMath
