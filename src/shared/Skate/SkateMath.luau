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
	_worldUp: Vector3,
	-- A surface whose normal is closer to world up than this cosine is not steep (maxStickAngle).
	_stickCos: number,
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
		_worldUp = -gravity.Unit,
		_stickCos = math.cos(math.rad(movement.maxStickAngle)),
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

-- The way the skater faces, laid onto the surface. A facing straight into it (head-on against a wall, or straight
-- up after riding a wall) lies on it nowhere, so the skater then faces up the surface's slope, or sideways on level
-- ground.
local function facingOn(self: Skater, normal: Vector3): Vector3
	local facing = alongSurface(self.forward, normal)
	if facing.Magnitude > EPSILON then
		return facing.Unit
	end
	local uphill = alongSurface(self._worldUp, normal)
	if uphill.Magnitude > EPSILON then
		return uphill.Unit
	end
	return normal:Cross(Vector3.zAxis).Unit
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
	local heading = if speed > EPSILON then velocity / speed else facingOn(self, normal)

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

-- Ballistic: gravity and drag, a little horizontal steering, and turning back upright.
local function stepAirborne(self: Skater, input: Types.SkateInput, dt: number)
	local movement = self._movement
	local worldUp = self._worldUp
	local velocity = self.velocity
	local rising = worldUp * velocity:Dot(worldUp)
	local horizontal = velocity - rising
	local horizontalSpeed = horizontal.Magnitude
	local wish = input.move - worldUp * input.move:Dot(worldUp)
	if horizontalSpeed > EPSILON and wish.Magnitude > EPSILON then
		local turned = rotateToward(horizontal / horizontalSpeed, wish.Unit, movement.airTurnRate * dt, worldUp)
		horizontal = turned * horizontalSpeed
	end

	velocity = horizontal + rising + self._gravity * dt
	local speed = velocity.Magnitude
	if speed > EPSILON then
		velocity *= math.min(speed - movement.airDrag * speed * dt, movement.hardCap) / speed
	end
	self.velocity = velocity
	self.up = rotateToward(self.up, worldUp, movement.airUprightRate * dt, self.forward)
	local travel = velocity - worldUp * velocity:Dot(worldUp)
	if travel.Magnitude > EPSILON then
		self.forward = travel.Unit
	end
end

-- The mode changes first, so a jump or a fall is stepped in the air at once.
local function resolveMode(self: Skater, input: Types.SkateInput, ground: Types.Ground)
	local movement = self._movement
	if self.mode == "Grounded" then
		if ground.hit and input.jump then
			self.velocity += ground.normal * movement.jumpImpulse
			self.mode = "Airborne"
		elseif
			not ground.hit
			-- Too slow to ride a surface this steep.
			or (
				ground.normal:Dot(self._worldUp) < self._stickCos
				and alongSurface(self.velocity, ground.normal).Magnitude < movement.minWallSpeed
			)
		then
			self.mode = "Airborne"
		end
	elseif ground.hit and ground.distance <= movement.hoverHeight and self.velocity:Dot(ground.normal) <= 0 then
		self.mode = "Grounded"
	end
end

function SkateMath.step(self: Skater, input: Types.SkateInput, ground: Types.Ground, dt: number)
	resolveMode(self, input, ground)
	if self.mode == "Grounded" then
		stepGrounded(self, input, ground, dt)
	else
		stepAirborne(self, input, dt)
	end
end

-- Still and on the ground: the kickoff freeze and a fresh character start from rest.
function SkateMath.stop(self: Skater)
	self.velocity = Vector3.zero
	self.mode = "Grounded"
end

return SkateMath
