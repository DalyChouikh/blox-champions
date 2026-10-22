--!strict
-- One skater's momentum (spec §7): velocity, mode and orientation, stepped from the stick, the ground ray and the
-- time. Pure and deterministic. A step mutates the skater in place and allocates nothing (vectors are values), so
-- the client can run it every physics step.

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Types)
local Vectors = require(script.Parent.Parent.Util.Vectors)

local EPSILON = Vectors.EPSILON
local alongSurface = Vectors.alongSurface
local rotateToward = Vectors.rotateToward

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
	-- The ground normal the last grounded step rode on: the curve the surface makes is measured from it (A3).
	_lastNormal: Vector3?,
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
		_lastNormal = nil,
	}
	return setmetatable(self, SkateMath)
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

-- How sharply the surface bends around the skater, 1/radius, positive on the inside of a loop: how far the normal
-- turned along the heading in one step, per stud travelled. Zero until a grounded step has measured it, and while
-- the skater is still.
local function curvature(self: Skater, normal: Vector3, heading: Vector3, speed: number, dt: number): number
	local last = self._lastNormal
	if last == nil or speed * dt <= EPSILON then
		return 0
	end
	return -(normal - last):Dot(heading) / (speed * dt)
end

-- Past straight up the surface overhangs, and gravity pulls the skater off it: they stay on only while speed² ×
-- curvature reaches that pull. A flat ceiling has no curvature, so it never holds (spec §7.2, A3).
local function loopBreaks(self: Skater, normal: Vector3, dt: number): boolean
	local pull = self._gravity:Dot(normal)
	if pull <= 0 then
		return false
	end
	local along = alongSurface(self.velocity, normal)
	local speed = along.Magnitude
	local heading = if speed > EPSILON then along / speed else Vector3.zero
	return speed * speed * curvature(self, normal, heading, speed, dt) < pull
end

-- A surface steeper than maxStickAngle holds only a skater moving at least minWallSpeed along it.
local function tooSlowOnWall(self: Skater, normal: Vector3): boolean
	local steep = normal:Dot(self._worldUp) < self._stickCos
	return steep and alongSurface(self.velocity, normal).Magnitude < self._movement.minWallSpeed
end

-- The mode changes first, so a jump or a fall is stepped in the air at once.
local function resolveMode(self: Skater, input: Types.SkateInput, ground: Types.Ground, dt: number)
	local movement = self._movement
	if self.mode == "Grounded" then
		if ground.hit and input.jump then
			self.velocity += ground.normal * movement.jumpImpulse
			self.mode = "Airborne"
		elseif
			not ground.hit
			or tooSlowOnWall(self, ground.normal)
			-- Past straight up, the curve of the surface must hold the skater (A3).
			or loopBreaks(self, ground.normal, dt)
		then
			self.mode = "Airborne"
		end
	elseif ground.hit and ground.distance <= movement.hoverHeight and self.velocity:Dot(ground.normal) <= 0 then
		self.mode = "Grounded"
	end
end

function SkateMath.step(self: Skater, input: Types.SkateInput, ground: Types.Ground, dt: number)
	resolveMode(self, input, ground, dt)
	if self.mode == "Grounded" then
		self._lastNormal = ground.normal
		stepGrounded(self, input, ground, dt)
	else
		self._lastNormal = nil
		stepAirborne(self, input, dt)
	end
end

-- Never faster than hardCap.
local function capped(self: Skater, velocity: Vector3): Vector3
	local speed = velocity.Magnitude
	local hardCap = self._movement.hardCap
	return if speed > hardCap then velocity * (hardCap / speed) else velocity
end

-- Attached behind a leader (Attach): moving with them, pulled toward the follow point.
function SkateMath.follow(
	self: Skater,
	target: Vector3,
	position: Vector3,
	leaderVelocity: Vector3,
	leaderForward: Vector3
)
	self.velocity = capped(self, leaderVelocity + (target - position) * self._movement.attachSpring)
	self.mode = "Attached"
	self.forward = leaderForward
end

-- Let go of the leader with a boost; the next step lands the skater if the ground is close.
function SkateMath.release(self: Skater, direction: Vector3)
	self.velocity = capped(self, self.velocity + direction * self._movement.attachBoostSpeed)
	self.mode = "Airborne"
end

-- Still and on the ground: the kickoff freeze and a fresh character start from rest.
function SkateMath.stop(self: Skater)
	self.velocity = Vector3.zero
	self.mode = "Grounded"
	self._lastNormal = nil
end

return SkateMath
