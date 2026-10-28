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

-- How many past grounded steps the curvature window can reach back over: at hardCap a window of ten studs spans five,
-- and at a crawl the window simply covers less road, where the loop rule's speed² makes the curve irrelevant.
local HISTORY = 32
-- A ground normal turning less than this in a step (radians) has not turned: float noise on a flat surface.
local TURN_EPSILON = 1e-6
-- A face leaning past straight up by less than this (the sine of the lean) is a vertical wall, not an overhang: the
-- arena's built glass reads up to 6.5e-5 past vertical (measured, #234). The lips' first strip leans 22.5°.
local OVERHANG_EPSILON = 1e-3
-- What a knocked-down skater's input becomes: no stick, pump, brake, jump or draft. They only slide.
local LOCKED: Types.SkateInput = table.freeze({
	move = Vector3.zero,
	pump = false,
	brake = false,
	jump = false,
	jumpHeld = false,
	draftAccel = 0,
	knockedDown = true,
	diving = false,
})
-- What a diver's input becomes until their touchdown's knockdown (#242): the same, but they glide, slowed by friction
-- and drag only, and in the air fly down the fall line (#241).
local GLIDING: Types.SkateInput = table.freeze({
	move = Vector3.zero,
	pump = false,
	brake = false,
	jump = false,
	jumpHeld = false,
	draftAccel = 0,
	knockedDown = false,
	diving = true,
})

local SkateMath = {}
SkateMath.__index = SkateMath

type Fields = {
	-- What the controller applies: momentum plus the hover's pull along the surface normal.
	velocity: Vector3,
	mode: Types.Mode,
	up: Vector3,
	-- The way the skater faces; kept while stopped, turning toward the way they move (#246: turnFacing).
	forward: Vector3,
	-- Whether a press in the air would strike the Air Pose (once until landing), and whether it is struck now: from
	-- the press until the jump key is let go or the skater lands (#245).
	airPoseReady: boolean,
	airPosing: boolean,
	-- Whether this step touched down still posing: a fall, which the server judges (#245).
	landedPosed: boolean,
	_movement: Config.MovementConfig,
	_gravity: Vector3,
	_worldUp: Vector3,
	-- A surface whose normal is closer to world up than this cosine is not a wall (wallAngle).
	_wallCos: number,
	-- Gravity's pull along a surface no steeper than pumpFlatSlopeDeg: pumping there counts as on the flat.
	_flatPull: number,
	-- Gravity's pull off a face leaning OVERHANG_EPSILON past vertical: up to it the face holds like a wall.
	_overhangPull: number,
	-- The fall line (fallLineDeg below the facing): its angle's cosine and sine, and gravity's pull along it.
	_lineCos: number,
	_lineSin: number,
	_linePull: number,
	-- How fast the facing turns (a half-turn in turnRoundSeconds), and the cosine of backwardsConeDeg.
	_turnRoundRate: number,
	_backwardsCos: number,
	-- Whether the skater rides backwards (#246).
	_backwards: boolean,
	-- The ground normal the last grounded step rode on, nil in the air: each step's turn is measured from it (A3).
	_lastNormal: Vector3?,
	-- The last grounded steps, newest at `_historyHead`: how far each went and how much the ground turned under it,
	-- positive on the inside of a loop. The curve is read over curvatureWindow studs of them.
	_steps: { number },
	_turns: { number },
	_historyHead: number,
	_historyCount: number,
}

export type Skater = typeof(setmetatable({} :: Fields, SkateMath))

function SkateMath.new(movement: Config.MovementConfig, gravity: Vector3): Skater
	local line = math.rad(movement.fallLineDeg)
	local self: Fields = {
		velocity = Vector3.zero,
		mode = "Grounded",
		up = -gravity.Unit,
		forward = -Vector3.zAxis,
		airPoseReady = true,
		airPosing = false,
		landedPosed = false,
		_movement = movement,
		_gravity = gravity,
		_worldUp = -gravity.Unit,
		_wallCos = math.cos(math.rad(movement.wallAngle)),
		_flatPull = gravity.Magnitude * math.sin(math.rad(movement.pumpFlatSlopeDeg)),
		_overhangPull = gravity.Magnitude * OVERHANG_EPSILON,
		_lineCos = math.cos(line),
		_lineSin = math.sin(line),
		_linePull = gravity.Magnitude * math.sin(line),
		_turnRoundRate = math.pi / movement.turnRoundSeconds,
		_backwardsCos = math.cos(math.rad(movement.backwardsConeDeg)),
		_backwards = false,
		_lastNormal = nil,
		_steps = table.create(HISTORY, 0),
		_turns = table.create(HISTORY, 0),
		_historyHead = 0,
		_historyCount = 0,
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

-- Turns the facing toward `way` (unit, the way the skater moves on the plane `up` defines), at most a half-turn in
-- turnRoundSeconds, so it never snaps (#246). A skater `carried` back against their facing (down a slope) rides
-- backwards instead while the stick (`wish`, unit or zero) points the way they move and the facing the way back,
-- both within backwardsConeDeg; then the facing turns toward the way back, so their back leads. Once they stop
-- holding it they turn round, and a turn begun leaves the cone at once, so it never flips back. A facing along `up`
-- lies on the plane nowhere: there is nothing to turn from, so they face the way they move at once.
local function turnFacing(self: Skater, up: Vector3, way: Vector3, wish: Vector3, carried: boolean, dt: number)
	local flat = alongSurface(self.forward, up)
	if flat.Magnitude <= EPSILON then
		self.forward = way
		return
	end
	local from = flat.Unit
	local cone = self._backwardsCos
	self._backwards = (self._backwards or carried) and wish:Dot(way) >= cone and from:Dot(way) <= -cone
	self.forward = rotateToward(from, if self._backwards then -way else way, self._turnRoundRate * dt, up)
end

-- The way a diver flies (#241): fallLineDeg below the facing.
local function fallLine(self: Skater): Vector3
	local worldUp = self._worldUp
	return facingOn(self, worldUp) * self._lineCos - worldUp * self._lineSin
end

-- Across what the speedometer reads (#233): the surface on the ground, on walls and behind a teammate; the ground
-- below in the air.
local function readingUp(self: Skater): Vector3
	return if self.mode == "Airborne" then self._worldUp else self.up
end

-- Turns widen with speed: turnRateLow at rest down to turnRateHigh at hardCap, and never faster than wallTurnRate on a
-- wall (#239).
local function turnRate(movement: Config.MovementConfig, speed: number, wall: boolean): number
	local fraction = math.min(speed / movement.hardCap, 1)
	local rate = movement.turnRateLow + (movement.turnRateHigh - movement.turnRateLow) * fraction
	return if wall then math.min(rate, movement.wallTurnRate) else rate
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

-- Steeper than wallAngle: a wall, where gravity pulls along the surface at wallGravityScale.
local function isWall(self: Skater, normal: Vector3): boolean
	return normal:Dot(self._worldUp) < self._wallCos
end

local function stepGrounded(self: Skater, input: Types.SkateInput, ground: Types.Ground, dt: number)
	local movement = self._movement
	local normal = ground.normal
	local velocity = alongSurface(self.velocity, normal)
	local speed = velocity.Magnitude
	local heading = if speed > EPSILON then velocity / speed else facingOn(self, normal)
	-- On a wall the skates only roll (#239): the stick steers at most wallTurnRate and never strides, the brake does
	-- nothing, and gravity pulls along it at wallGravityScale of its strength (#216); in the air it stays full.
	local wall = isWall(self, normal)
	local brake = input.brake and not wall

	local stick = math.min(input.move.Magnitude, 1)
	local wish = alongSurface(input.move, normal)
	local wishDirection = Vector3.zero
	if stick > 0 and wish.Magnitude > EPSILON then
		wishDirection = wish.Unit
		heading = if speed > EPSILON
			then rotateToward(heading, wishDirection, turnRate(movement, speed, wall) * dt, normal)
			else wishDirection
	else
		stick = 0
	end

	local gravityAlong = alongSurface(self._gravity, normal)
	if wall then
		gravityAlong *= movement.wallGravityScale
	end
	local acceleration = gravityAlong + heading * input.draftAccel
	if input.pump and not brake then
		acceleration += heading * pumpPush(self, gravityAlong:Dot(heading))
	end
	if not wall and not brake and stick > 0 and speed < movement.cruiseSpeed then
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
	-- Friction and drag, with more slowing on top for a knocked-down skater or one pressing nothing (#215); a diver
	-- glides (#242).
	local extra = if input.knockedDown
		then movement.knockdownDecel
		elseif input.diving then 0
		elseif stick == 0 and not input.pump and not brake then movement.coastDecel
		else 0
	speed = math.max(0, speed - (movement.rollingFriction + extra + movement.airDrag * speed) * dt)
	if brake then
		local tiptoe = movement.tiptoeSpeed * stick
		if speed > tiptoe then
			speed = math.max(tiptoe, speed - movement.brakeDecel * dt)
		end
		if stick > 0 and speed <= tiptoe then
			direction = wishDirection
			speed = tiptoe
		end
	end
	-- Speed past softCap bleeds off, the further over the faster (RC, #214); only on the ground, since RC's dive gains
	-- speed in the air.
	local softCap = movement.softCap
	if speed > softCap then
		speed = softCap + (speed - softCap) * math.exp(-movement.overSpeedBleed * dt)
	end
	speed = math.min(speed, movement.hardCap)

	self.velocity = direction * speed + normal * ((movement.hoverHeight - ground.distance) * movement.hoverSpring)
	self.up = normal
	if speed > EPSILON then
		-- A slope or a wall pulling them the way they go carries them (#246).
		turnFacing(self, normal, direction, wishDirection, gravityAlong:Dot(direction) > self._flatPull, dt)
	else
		self.forward = heading
	end
end

-- Ballistic: gravity and drag, a little horizontal steering, and turning back upright. A diver, and a posed skater
-- once falling (#245), fly down the fall line instead, gravity's pull along it speeding them up (#241).
local function stepAirborne(self: Skater, input: Types.SkateInput, dt: number)
	local movement = self._movement
	local worldUp = self._worldUp
	local velocity = self.velocity
	local wish = input.move - worldUp * input.move:Dot(worldUp)
	local wishDirection = if wish.Magnitude > EPSILON then wish.Unit else Vector3.zero
	if input.diving or (self.airPosing and velocity:Dot(worldUp) <= 0) then
		local line = fallLine(self)
		velocity = line * (math.max(velocity:Dot(line), 0) + self._linePull * dt)
	else
		local rising = worldUp * velocity:Dot(worldUp)
		local horizontal = velocity - rising
		local horizontalSpeed = horizontal.Magnitude
		if horizontalSpeed > EPSILON and wish.Magnitude > EPSILON then
			local turned = rotateToward(horizontal / horizontalSpeed, wishDirection, movement.airTurnRate * dt, worldUp)
			horizontal = turned * horizontalSpeed
		end
		velocity = horizontal + rising + self._gravity * dt
	end
	local speed = velocity.Magnitude
	if speed > EPSILON then
		velocity *= math.min(speed - movement.airDrag * speed * dt, movement.hardCap) / speed
	end
	self.velocity = velocity
	self.up = rotateToward(self.up, worldUp, movement.airUprightRate * dt, self.forward)
	-- Nothing carries a skater back in the air; one already riding backwards keeps on while they hold it (#246).
	local travel = velocity - worldUp * velocity:Dot(worldUp)
	if travel.Magnitude > EPSILON then
		turnFacing(self, worldUp, travel.Unit, wishDirection, false, dt)
	end
end

-- This step's travel along the ground and how far the ground's normal turned since the last grounded step, positive
-- when the surface bends around the skater (the inside of a loop). No turn is known before a grounded step.
local function measure(self: Skater, normal: Vector3, dt: number): (number, number)
	local along = alongSurface(self.velocity, normal)
	local speed = along.Magnitude
	local last = self._lastNormal
	if last == nil or speed <= EPSILON then
		return speed * dt, 0
	end
	-- Exactly zero for a normal that has not turned, where an arccosine reads enough to look like a turn.
	local angle = Vectors.angleBetween(last, normal)
	return speed * dt, if (normal - last):Dot(along) > 0 then -angle else angle
end

-- How sharply the surface bends around the skater, 1/radius, from the turns of the last curvatureWindow studs of
-- path. Across a lip's flat strips the ground turns only at each strip's edge, so the curve is the turning
-- between the oldest and the newest turn in the window over the road between them: one strip's angle per strip's
-- width, the arc they make. On a smooth curve every step turns, and this is the turn per stud. With fewer than two
-- turns in the window it is the turning over the window's road. Zero until a grounded step has measured a turn.
local function curvature(self: Skater, travel: number, turn: number): number
	local window = self._movement.curvatureWindow
	-- Walking back from now, a step's turn happened where that step ended: `behind` studs ago.
	local behind, turned, turns = 0, 0, 0
	local newest, oldest, oldestTurn = 0, 0, 0
	local step, stepTurn = travel, turn
	local index, remaining = self._historyHead, self._historyCount
	while true do
		if math.abs(stepTurn) > TURN_EPSILON then
			if turns == 0 then
				newest = behind
			end
			turns += 1
			turned += stepTurn
			oldest, oldestTurn = behind, stepTurn
		end
		behind += step
		if behind >= window or remaining == 0 then
			break
		end
		step, stepTurn = self._steps[index], self._turns[index]
		index = if index == 1 then HISTORY else index - 1
		remaining -= 1
	end
	if turns >= 2 then
		return (turned - oldestTurn) / (oldest - newest)
	end
	return if behind > EPSILON then turned / behind else 0
end

-- Past straight up the surface overhangs, and gravity pulls the skater off it: they stay on only while speed² ×
-- curvature reaches that pull. A flat ceiling has no curvature, so it never holds (spec §7.2, A3). A face only float
-- noise past vertical is a wall.
local function loopBreaks(self: Skater, normal: Vector3, travel: number, turn: number): boolean
	local pull = self._gravity:Dot(normal)
	if pull <= self._overhangPull then
		return false
	end
	local speed = alongSurface(self.velocity, normal).Magnitude
	return speed * speed * curvature(self, travel, turn) < pull
end

-- Keeps this grounded step's travel and turn for the curvature window.
local function remember(self: Skater, normal: Vector3, travel: number, turn: number)
	if self._lastNormal ~= nil and travel > EPSILON then
		local head = self._historyHead % HISTORY + 1
		self._historyHead = head
		self._steps[head] = travel
		self._turns[head] = turn
		self._historyCount = math.min(self._historyCount + 1, HISTORY)
	end
	self._lastNormal = normal
end

-- Off the ground the path's curve no longer says anything about a surface.
local function forget(self: Skater)
	self._lastNormal = nil
	self._historyCount = 0
end

-- On the ground again: the Air Pose ends and is ready for the next time in the air.
local function land(self: Skater)
	self.mode = "Grounded"
	self.airPoseReady = true
	self.airPosing = false
end

-- Down from the air. A touchdown on the belly, diving or still posing, keeps bellyLandingKeep of the speed (#245); a
-- posed one is a fall, and says so for this step.
local function touchDown(self: Skater, input: Types.SkateInput)
	if self.airPosing or input.diving then
		self.velocity *= self._movement.bellyLandingKeep
		self.landedPosed = self.airPosing
	end
	land(self)
end

-- The Air Pose's hop (#218): the fall cancelled, airPoseImpulse straight up, and jumpSpeedCost of the speed across.
local function airPose(self: Skater)
	local movement = self._movement
	local worldUp = self._worldUp
	local rising = self.velocity:Dot(worldUp)
	local across = self.velocity - worldUp * rising
	self.velocity = across * (1 - movement.jumpSpeedCost) + worldUp * (math.max(rising, 0) + movement.airPoseImpulse)
	self.airPoseReady = false
	self.airPosing = true
end

-- The mode changes first, so a jump or a fall is stepped in the air at once. In the air, letting go of the jump key
-- ends the Air Pose before the touchdown is judged (#245); a press and release between two steps poses for one step,
-- and its hop still breaks a fall.
local function resolveMode(self: Skater, input: Types.SkateInput, ground: Types.Ground, travel: number, turn: number)
	local movement = self._movement
	if self.mode == "Grounded" then
		if ground.hit and input.jump then
			-- A jump keeps 1 − jumpSpeedCost of the speed along the surface (#218).
			self.velocity -= alongSurface(self.velocity, ground.normal) * movement.jumpSpeedCost
			self.velocity += ground.normal * movement.jumpImpulse
			self.mode = "Airborne"
		elseif not ground.hit or loopBreaks(self, ground.normal, travel, turn) then
			-- No ground, or past straight up the surface's curve no longer holds the skater (A3).
			self.mode = "Airborne"
		end
		return
	end
	if not input.jumpHeld then
		self.airPosing = false
	end
	if ground.hit and ground.distance <= movement.hoverHeight and self.velocity:Dot(ground.normal) <= 0 then
		touchDown(self, input)
	elseif input.jump and self.airPoseReady then
		airPose(self)
	end
end

function SkateMath.step(self: Skater, input: Types.SkateInput, ground: Types.Ground, dt: number)
	local controls = if input.knockedDown then LOCKED elseif input.diving then GLIDING else input
	self.landedPosed = false
	local travel, turn = 0, 0
	if self.mode == "Grounded" and ground.hit then
		travel, turn = measure(self, ground.normal, dt)
	end
	resolveMode(self, controls, ground, travel, turn)
	if self.mode == "Grounded" then
		remember(self, ground.normal, travel, turn)
		stepGrounded(self, controls, ground, dt)
	else
		forget(self)
		stepAirborne(self, controls, dt)
	end
end

-- Never faster than hardCap.
local function capped(self: Skater, velocity: Vector3): Vector3
	local speed = velocity.Magnitude
	local hardCap = self._movement.hardCap
	return if speed > hardCap then velocity * (hardCap / speed) else velocity
end

-- Attached behind a leader (Attach): moving with them, pulled toward the follow point. A step of its own, with no
-- touchdown.
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
	self.landedPosed = false
	self._backwards = false
end

-- Let go of the leader with a boost; the next step lands the skater if the ground is close.
function SkateMath.release(self: Skater, direction: Vector3)
	self.velocity = capped(self, self.velocity + direction * self._movement.attachBoostSpeed)
	self.mode = "Airborne"
end

-- An action's push (a lunge, a dodge, a wall leap) added to the velocity, never past hardCap. A launch leaves the
-- ground.
function SkateMath.push(self: Skater, change: Vector3, launch: boolean)
	self.velocity = capped(self, self.velocity + change)
	if launch then
		self.mode = "Airborne"
	end
end

-- The pushes below are worked out in the speedometer's terms (shownSpeed), keeping the velocity off its plane (a
-- rise, a fall, the hover's pull), and handed to `push`.

-- A lunge's change (#241): `add` more speed along the facing, never past `ceiling`; a faster skater slows to it.
function SkateMath.lungeChange(self: Skater, add: number, ceiling: number): Vector3
	local up = readingUp(self)
	local across = alongSurface(self.velocity, up)
	local lunged = across + facingOn(self, up) * add
	local speed = lunged.Magnitude
	return (if speed > ceiling then lunged * (ceiling / speed) else lunged) - across
end

-- The change that brings the speed down to `ceiling` if it is above (a lunge easing back, #241).
function SkateMath.slowChange(self: Skater, ceiling: number): Vector3
	local across = alongSurface(self.velocity, readingUp(self))
	local speed = across.Magnitude
	return if speed > ceiling then across * (ceiling / speed - 1) else Vector3.zero
end

-- The Dive's change (#241): `speed` along the way, or the skater's own if faster: along the facing on the ground,
-- down the fall line in the air, where stepAirborne keeps a diver.
function SkateMath.diveChange(self: Skater, speed: number): Vector3
	local up = readingUp(self)
	local across = alongSurface(self.velocity, up)
	local target = math.max(across.Magnitude, speed)
	if self.mode == "Airborne" then
		return fallLine(self) * target - self.velocity
	end
	return facingOn(self, up) * target - across
end

-- A surface in the way (the controller finds it): the velocity loses its part into the surface and keeps the rest, so
-- the skater slides along it. Says whether anything was lost.
function SkateMath.block(self: Skater, normal: Vector3): boolean
	local into = self.velocity:Dot(normal)
	if into >= 0 then
		return false
	end
	self.velocity -= normal * into
	return true
end

-- Still and on the ground: the kickoff freeze and a fresh character start from rest.
function SkateMath.stop(self: Skater)
	self.velocity = Vector3.zero
	self._backwards = false
	land(self)
	forget(self)
end

-- The speed the speedometer shows, in studs per second, Roller Champions' way (#233): along the surface on the ground,
-- on walls and behind a teammate, without the hover's pull off it; across the ground in the air, so a standing jump
-- reads 0 and a fall adds nothing.
function SkateMath.shownSpeed(self: Skater): number
	return alongSurface(self.velocity, readingUp(self)).Magnitude
end

return SkateMath
