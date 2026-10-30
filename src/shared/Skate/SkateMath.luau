--!strict
-- One skater's momentum (spec §7): velocity, mode and orientation, stepped from the stick, the ground ray and the
-- time. Pure and deterministic. A step mutates the skater in place and allocates nothing (vectors are values), so
-- the client can run it every physics step.

local Attributes = require(script.Parent.Parent.Net.Attributes)
local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Types)
local Vectors = require(script.Parent.Parent.Util.Vectors)

local EPSILON = Vectors.EPSILON
local alongSurface = Vectors.alongSurface
local rotateToward = Vectors.rotateToward

-- How many past steps on a surface the curvature window can reach back over: at hardCap a window of ten studs spans
-- five, and at a crawl the window simply covers less road, where the contact rule's speed² makes the curve irrelevant.
local HISTORY = 32
-- A ground normal turning less than this in a step (radians) has not turned: float noise. Rays on one flat face
-- differed by up to 1.5e-4 (measured, #257); the arena's smooth shape reads within 2.2e-5 of exact (#294). A smooth
-- curve turns a step by its speed x dt / radius: round the round glass (a path of radius 22.5) a drift slower than
-- 1.35 studs/s reads no turn, far inside what its grip holds (#289).
local TURN_EPSILON = 1e-3
-- The contact rule's slack for float noise, as a share of gravity: the arena's built glass reads up to 6.5e-5 past
-- vertical (measured, #234), so a face leaning less than this past straight up still holds like a wall. The lips'
-- first strip leans 22.5°.
local CONTACT_SLACK = 1e-3
-- A skater leaving a wall along it moves off it by float noise only (studs/s): the glass leans up to 6.5e-5 past
-- upright (#234), so at hardCap and through a second of gravity under 0.03. A jump leaves at jumpImpulse (48.99), a
-- bend turning away at several studs/s: neither is caught back (#258).
local DRIFT_EPSILON = 0.1
-- What a knocked-down skater's input becomes, one for each kind of knockdown: no stick, pump, brake, jump or draft.
-- They only slide, for their kind's time (#252).
local function locked(knockdown: Attributes.Knockdown): Types.SkateInput
	return table.freeze({
		move = Vector3.zero,
		pump = false,
		brake = false,
		jump = false,
		jumpHeld = false,
		draftAccel = 0,
		knockdown = knockdown,
		diving = false,
	})
end
local LOCKED = table.freeze({ Hit = locked("Hit"), Fall = locked("Fall"), Dive = locked("Dive") })
-- What a diver's input becomes until their touchdown's knockdown (#242): the same, but they glide, slowed by friction
-- and drag only, and in the air fly down the fall line (#241).
local GLIDING: Types.SkateInput = table.freeze({
	move = Vector3.zero,
	pump = false,
	brake = false,
	jump = false,
	jumpHeld = false,
	draftAccel = 0,
	knockdown = nil,
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
	-- A surface whose normal is closer to world up than this cosine is gentle enough to crawl up (crawlLimitDeg).
	_crawlCos: number,
	-- Gravity's pull along a surface no steeper than pumpFlatSlopeDeg: pumping there counts as on the flat.
	_flatPull: number,
	-- Gravity's pull at CONTACT_SLACK of its strength: a push this small that the curve misses is float noise.
	_slackPull: number,
	-- The cosine of cornerDeg: the ground turning less than that since the last step is a curve (#255).
	_cornerCos: number,
	-- The fall line (fallLineDeg below the facing): its angle's cosine and sine, and gravity's pull along it.
	_lineCos: number,
	_lineSin: number,
	_linePull: number,
	-- How fast the facing turns (a half-turn in turnRoundSeconds), and the cosine of backwardsConeDeg.
	_turnRoundRate: number,
	_backwardsCos: number,
	-- Whether the skater rides backwards (#246).
	_backwards: boolean,
	-- How long a knocked-down skater's slide has left, from its first step on the ground; nil on their feet (#252).
	_slideLeft: number?,
	-- The normal of the surface the last measured step rode on or flew beside, nil in the air unless beside a wall
	-- that grips them: each step's turn is measured from it (A3).
	_lastNormal: Vector3?,
	-- The wall the skater last left or touched, nil once on the ground again: they look for it, kept by it rising by
	-- its grip (#289) and coming back onto it falling (#258), unless it is out of reach, they move away from it or it
	-- bends away from them more than its grip holds.
	_leftWall: Vector3?,
	-- The way the surface bends under them (unit, along its face): the way its normal last turned through a curve,
	-- nil before one (#289).
	_bendWay: Vector3?,
	-- The last measured steps, newest at `_historyHead`: how far each went the way the surface bends (#289) and how
	-- much it turned, positive on the inside of a loop. The curve is read over curvatureWindow studs of them.
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
		_crawlCos = math.cos(math.rad(movement.crawlLimitDeg)),
		_flatPull = gravity.Magnitude * math.sin(math.rad(movement.pumpFlatSlopeDeg)),
		_slackPull = gravity.Magnitude * CONTACT_SLACK,
		_cornerCos = math.cos(math.rad(movement.cornerDeg)),
		_lineCos = math.cos(line),
		_lineSin = math.sin(line),
		_linePull = gravity.Magnitude * math.sin(line),
		_turnRoundRate = math.pi / movement.turnRoundSeconds,
		_backwardsCos = math.cos(math.rad(movement.backwardsConeDeg)),
		_backwards = false,
		_slideLeft = nil,
		_lastNormal = nil,
		_leftWall = nil,
		_bendWay = nil,
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

-- Steeper than wallAngle: a wall, where the skates only roll (#239).
local function isWall(self: Skater, normal: Vector3): boolean
	return normal:Dot(self._worldUp) < self._wallCos
end

-- A knocked-down skater slows evenly to a stop in their kind's knockdownSlideSeconds, whatever the speed (RC, #252),
-- timed from the slide's first step on the ground. Each step loses its share of the time left (dt over it), so on
-- the flat the speed falls in a straight line to zero at the end; a slope's pull only bends the line, and after
-- the end they lie still until up.
local function slide(self: Skater, knockdown: Attributes.Knockdown, speed: number, dt: number): number
	local left = self._slideLeft or self._movement.knockdownSlideSeconds[knockdown]
	self._slideLeft = math.max(left - dt, 0)
	return if left > dt then speed * (1 - dt / left) else 0
end

-- Whether a surface's normal turning from `last` to `normal` is a curve's small turn, not a corner (cornerDeg, #255).
local function curving(self: Skater, last: Vector3, normal: Vector3): boolean
	return last:Dot(normal) >= self._cornerCos
end

-- The velocity along a surface whose normal turned from `last` to `normal`: through a curve's small turn the surface
-- does no work, so the speed along it turns with it (#255); at a corner, or with no last normal (touching down), the
-- speed into the new face is lost.
local function turnedOnto(self: Skater, last: Vector3?, normal: Vector3): Vector3
	local velocity = alongSurface(self.velocity, normal)
	local speed = velocity.Magnitude
	if last ~= nil and curving(self, last, normal) and speed > EPSILON then
		return velocity * (alongSurface(self.velocity, last).Magnitude / speed)
	end
	return velocity
end

local function stepGrounded(self: Skater, input: Types.SkateInput, ground: Types.Ground, dt: number)
	local movement = self._movement
	local normal = ground.normal
	local velocity = turnedOnto(self, self._lastNormal, normal)
	local speed = velocity.Magnitude
	local heading = if speed > EPSILON then velocity / speed else facingOn(self, normal)
	-- On a wall the skates only roll (#239): the stick steers at most wallTurnRate and never strides, and the brake
	-- does nothing. Gravity pulls along every surface at full strength (#256).
	local wall = isWall(self, normal)
	local brake = input.brake and not wall

	local stick = math.min(input.move.Magnitude, 1)
	local wish = alongSurface(input.move, normal)
	local wishDirection = Vector3.zero
	-- How far the stick points back against the motion (Roller Champions, #266): that part pushes back like a
	-- stride and only the rest turns, so a stick held straight back stops the skater before they go its way,
	-- never carving a U-turn at speed.
	local against = 0
	if stick > 0 and wish.Magnitude > EPSILON then
		wishDirection = wish.Unit
		if speed > EPSILON then
			against = math.max(-wishDirection:Dot(heading), 0)
			local toward = wishDirection + heading * against
			local share = toward.Magnitude
			if share > EPSILON then
				heading = rotateToward(heading, toward / share, turnRate(movement, speed, wall) * share * dt, normal)
			end
		else
			heading = wishDirection
		end
	else
		stick = 0
	end

	local gravityAlong = alongSurface(self._gravity, normal)
	local acceleration = gravityAlong + heading * input.draftAccel
	if input.pump and not brake then
		acceleration += heading * pumpPush(self, gravityAlong:Dot(heading))
	end
	if not wall and not brake and stick > 0 then
		local push = if against > 0
			then -against
			elseif speed < movement.cruiseSpeed then math.max(0, wishDirection:Dot(heading))
			else 0
		acceleration += heading * (movement.strideAccel * stick * push)
	end
	local forwardPart = acceleration:Dot(heading)
	if forwardPart > 0 and speed > movement.softCap then
		local kept = math.clamp((movement.hardCap - speed) / (movement.hardCap - movement.softCap), 0, 1)
		acceleration -= heading * (forwardPart * (1 - kept))
	end

	velocity = heading * speed + acceleration * dt
	speed = velocity.Magnitude
	local direction = if speed > EPSILON then velocity / speed else heading
	-- A knocked-down skater slides for their knockdown's time (#252); anyone else, a gliding diver too (#242), loses
	-- friction and drag, the same whether keys are pressed or not (the owner, #288: real physics, Q67-Q70).
	local knockdown: Attributes.Knockdown? = input.knockdown
	if knockdown ~= nil then
		speed = slide(self, knockdown, speed, dt)
	else
		speed = math.max(0, speed - (movement.rollingFriction + movement.airDrag * speed) * dt)
	end
	-- Holding the stick up a slope gentler than crawlLimitDeg, and steeper than flat, a skater never slows below
	-- crawlSpeed along their heading, walls under the limit included, so they creep up to the outer wall (the owner,
	-- #273: RC's crawl up a bank, Video 20). Not with the stick pushing back against the motion. Flat means under
	-- pumpFlatSlopeDeg, so float noise on a level floor never jump-starts a skater.
	if
		stick > 0
		and against == 0
		and normal:Dot(self._worldUp) > self._crawlCos
		and gravityAlong:Dot(heading) < -self._flatPull
	then
		local moving = direction * speed
		local short = movement.crawlSpeed * wishDirection:Dot(heading) - moving:Dot(heading)
		if short > 0 then
			moving += heading * short
			speed = moving.Magnitude
			direction = if speed > EPSILON then moving / speed else heading
		end
	end
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

-- Ballistic: gravity and drag, a little horizontal steering, and turning back upright. A diver flies down the fall
-- line instead, gravity's pull along it speeding them up (#241). A posed skater falls as anyone does: the pose adds no
-- motion of its own (the owner, #278, Q76: a standing jump's pose lands where it took off).
local function stepAirborne(self: Skater, input: Types.SkateInput, dt: number)
	local movement = self._movement
	local worldUp = self._worldUp
	local velocity = self.velocity
	local wish = input.move - worldUp * input.move:Dot(worldUp)
	local wishDirection = if wish.Magnitude > EPSILON then wish.Unit else Vector3.zero
	if input.diving then
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

-- The skater's speed `along` the surface, the part the way it bends (all of it before any bend is known): only that
-- part of their motion follows the curve (#289), so rising up the middle glass's round ends while drifting slowly
-- round them bends their path little, however fast they rise.
local function alongBend(self: Skater, along: Vector3): number
	local way = self._bendWay
	return if way ~= nil then math.abs(way:Dot(along)) else along.Magnitude
end

-- This step's travel the way the surface bends and how far its normal turned since the last measured step, positive
-- when it bends around the skater (the inside of a loop). A curve's turn also says the way it bends now, along its new
-- face (#289); a corner's says nothing of a curve. No turn is known before a step on a surface.
local function measure(self: Skater, normal: Vector3, dt: number): (number, number)
	local along = alongSurface(self.velocity, normal)
	local speed = along.Magnitude
	local last = self._lastNormal
	if last == nil or speed <= EPSILON then
		return speed * dt, 0
	end
	-- Exactly zero for a normal that has not turned, where an arccosine reads enough to look like a turn.
	local angle = Vectors.angleBetween(last, normal)
	if angle > TURN_EPSILON and curving(self, last, normal) then
		self._bendWay = alongSurface(normal - last, normal).Unit
	end
	return alongBend(self, along) * dt, if (normal - last):Dot(along) > 0 then -angle else angle
end

-- How sharply the surface bends around the skater, 1/radius (negative where it bends away), from the turns over the
-- last curvatureWindow studs of path the way it bends (#289). Across flat strips the ground turns only at each strip's
-- edge, so the curve is the turning between the oldest and the newest turn in the window over the road between them:
-- one strip's angle per strip's width, the arc they make. On a smooth curve (the arena's, #294) every step turns, and
-- this is the turn per stud. With fewer than two turns in the window it is the turning over the window's road. Zero
-- until a step has measured a turn.
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

-- Whether a surface can hold a skater touching down on it: an overhang's push depends on a curve no touchdown knows
-- yet, so it holds no one (#258).
local function holds(self: Skater, normal: Vector3): boolean
	return self._gravity:Dot(normal) <= self._slackPull
end

-- How firmly a surface presses the skates onto it: gravity's push into it, and on one that holds never less than
-- wallGrip (#289), since gravity presses nothing onto an upright wall. Negative under an overhang, which gravity pulls
-- them off.
local function pressing(self: Skater, normal: Vector3): number
	local push = -self._gravity:Dot(normal)
	return if holds(self, normal) then math.max(push, self._movement.wallGrip) else push
end

-- Whether it is the grip, not gravity, that presses the skates onto a surface that holds: a wall near upright (#289).
local function grips(self: Skater, normal: Vector3): boolean
	return holds(self, normal) and -self._gravity:Dot(normal) < self._movement.wallGrip
end

-- A surface only pushes (#257, A3): the skater stays on while the push their path's curve needs, speed² × curvature
-- (negative where the surface bends away from them), reaches how firmly it presses them on, within the slack. So a
-- flat ceiling never holds, an overhang holds only fast enough round its curve, a crest throws off a skater too fast
-- for gravity to keep on it, a curve bending toward them always holds, and a wall bending away (the middle glass's
-- round ends) holds only a drift round it slow enough for the grip (#289).
local function letsGo(self: Skater, normal: Vector3, travel: number, turn: number): boolean
	local speed = alongBend(self, alongSurface(self.velocity, normal))
	return speed * speed * curvature(self, travel, turn) < -pressing(self, normal) - self._slackPull
end

-- Keeps this measured step's travel and turn for the curvature window.
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

-- Flying beside the wall they left or touched (only the air keeps one), found by the controller's ray toward it
-- (groundRay), when its grip is what holds them there (#289): rising up it after a jump, or falling back onto it.
local function besideWall(self: Skater, ground: Types.Ground): boolean
	return self._leftWall ~= nil and ground.hit and grips(self, ground.normal)
end

-- Off the ground, and not beside a wall that grips them, the path's curve no longer says anything about a surface.
local function forget(self: Skater)
	self._lastNormal = nil
	self._bendWay = nil
	self._historyCount = 0
end

-- On the ground again: the Air Pose ends and is ready for the next time in the air.
local function land(self: Skater)
	self.mode = "Grounded"
	self.airPoseReady = true
	self.airPosing = false
	self._leftWall = nil
end

-- Into the air from the surface they rode (`up`), which they may come back onto if it is a wall that holds (#258).
local function liftOff(self: Skater)
	local up = self.up
	self._leftWall = if isWall(self, up) and holds(self, up) then up else nil
	self.mode = "Airborne"
end

local function ascending(self: Skater): boolean
	return self.velocity:Dot(self._worldUp) > 0
end

-- Falling beside the wall they left: they look for it to come back onto (#258).
local function catching(self: Skater): boolean
	return self._leftWall ~= nil and not ascending(self)
end

-- Whether a touchdown onto `normal` lands them: onto a surface that holds, and never while they rise off the wall they
-- left, since a leap up the glass is a flight with every air action until they fall (#258, Q28), or into any wall,
-- which they slide up instead (#267, RC Video 14).
local function landsOn(self: Skater, normal: Vector3): boolean
	return holds(self, normal) and (not ascending(self) or (self._leftWall == nil and not isWall(self, normal)))
end

-- The way a jump pushes: along a floor's normal, but up along a wall, never off it (#267, RC Video 14: a jump riding
-- up the glass rose along it). Straight under a ceiling there is no way up along it.
local function jumpWay(self: Skater, normal: Vector3): Vector3
	if isWall(self, normal) then
		local up = alongSurface(self._worldUp, normal)
		if up.Magnitude > EPSILON then
			return up.Unit
		end
	end
	return normal
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
local function resolveMode(
	self: Skater,
	input: Types.SkateInput,
	ground: Types.Ground,
	travel: number,
	turn: number,
	beside: boolean
)
	local movement = self._movement
	if self.mode == "Grounded" then
		if ground.hit and input.jump then
			-- A jump keeps 1 − jumpSpeedCost of the speed along the surface (#218), and only that: the hover's pull is
			-- no momentum, so a jump up a wall is caught by it once falling (#258, #267).
			self.velocity = alongSurface(self.velocity, ground.normal) * (1 - movement.jumpSpeedCost)
				+ jumpWay(self, ground.normal) * movement.jumpImpulse
			liftOff(self)
		elseif not ground.hit or letsGo(self, ground.normal, travel, turn) then
			-- No ground, or the surface can no longer push the skater round their path's curve (#257).
			liftOff(self)
		end
		return
	end
	if not input.jumpHeld then
		self.airPosing = false
	end
	-- Beside a wall that grips them (#289), where it bends away from them they keep by it round its curve, as on it:
	-- the speed along it turns with it and their part off it stays, unless it bends away more than the grip holds; then
	-- they fly on free. A wall bending toward them needs no grip: it meets them (touch).
	local wall = self._leftWall
	if beside and wall ~= nil then
		if letsGo(self, ground.normal, travel, turn) then
			self._leftWall = nil
		elseif (ground.normal - wall):Dot(self.velocity) > 0 then
			self.velocity = turnedOnto(self, wall, ground.normal) + ground.normal * self.velocity:Dot(wall)
			self._leftWall = ground.normal
		end
	end
	-- Down onto ground they land on: within hoverHeight and not moving off it, or the wall they left anywhere the ray
	-- reaches while they do not move away from it (#258). A wall that no longer can catch them is let go.
	local catch = catching(self)
	if ground.hit and landsOn(self, ground.normal) then
		local into = self.velocity:Dot(ground.normal)
		local down = if catch then into <= DRIFT_EPSILON else ground.distance <= movement.hoverHeight and into <= 0
		if down then
			touchDown(self, input)
			return
		end
	end
	if catch then
		self._leftWall = nil
	end
	if input.jump and self.airPoseReady then
		airPose(self)
	end
end

function SkateMath.step(self: Skater, input: Types.SkateInput, ground: Types.Ground, dt: number)
	local knockdown: Attributes.Knockdown? = input.knockdown
	local controls = if knockdown ~= nil then LOCKED[knockdown] elseif input.diving then GLIDING else input
	if knockdown == nil then
		-- On their feet: the next knockdown's slide is timed afresh (#252).
		self._slideLeft = nil
	end
	self.landedPosed = false
	-- On the ground, or beside a wall that grips them, each step's turn is measured against the surface (#257, #289).
	local beside = besideWall(self, ground)
	local measured = ground.hit and (self.mode == "Grounded" or beside)
	local travel, turn = 0, 0
	if measured then
		travel, turn = measure(self, ground.normal, dt)
	end
	resolveMode(self, controls, ground, travel, turn, beside)
	if self.mode == "Grounded" then
		-- The grounded step turns the speed from the last step's ground; then this one's is kept.
		stepGrounded(self, controls, ground, dt)
		remember(self, ground.normal, travel, turn)
	else
		-- Leaving a wall that holds, or flying beside one that grips them, the path's curve is kept for the next steps.
		if measured and self._leftWall ~= nil then
			remember(self, ground.normal, travel, turn)
		else
			forget(self)
		end
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
	self._leftWall = nil
end

-- Let go of the leader with a boost; the next step lands the skater if the ground is close.
function SkateMath.release(self: Skater, direction: Vector3)
	self.velocity = capped(self, self.velocity + direction * self._movement.attachBoostSpeed)
	self.mode = "Airborne"
end

-- An action's push (a lunge, a dodge, a wall leap) added to the velocity, never past hardCap. A launch leaves the
-- ground with the speed along it: the hover's pull off the surface is no momentum (measured, #258: kept, up to 1.5
-- studs/s carried a skater leaping up a wall off it, out of its catch).
function SkateMath.push(self: Skater, change: Vector3, launch: boolean)
	local velocity = if launch and self.mode == "Grounded" then alongSurface(self.velocity, self.up) else self.velocity
	self.velocity = capped(self, velocity + change)
	if launch then
		liftOff(self)
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

-- A strike's aim (#277): the facing turned toward `offset` (from the skater to their target, or the stick's way) across
-- what the speedometer reads (the surface; the ground below in the air), by at most `maxAngle` radians. An offset
-- straight along that up leaves it.
function SkateMath.faceToward(self: Skater, offset: Vector3, maxAngle: number)
	local up = readingUp(self)
	local way = alongSurface(offset, up)
	if way.Magnitude > EPSILON then
		self.forward = rotateToward(facingOn(self, up), way.Unit, maxAngle, up)
	end
end

-- The change that turns the speed across that same plane toward `way` by at most `maxAngle` radians, keeping it and
-- what lies off the plane (a rise, the hover's pull): a strike turning its skater at the press (#277).
function SkateMath.turnChange(self: Skater, way: Vector3, maxAngle: number): Vector3
	local up = readingUp(self)
	local across = alongSurface(self.velocity, up)
	local toward = alongSurface(way, up)
	local speed = across.Magnitude
	if speed <= EPSILON or toward.Magnitude <= EPSILON then
		return Vector3.zero
	end
	return rotateToward(across / speed, toward.Unit, maxAngle, up) * speed - across
end

-- A homing strike's change toward `offset` (#277): on the ground as turnChange; in the air the whole motion turns, so
-- an Uppercut's leap tilts toward an opponent above and an air strike bends down at one below.
function SkateMath.homeChange(self: Skater, offset: Vector3, maxAngle: number): Vector3
	if self.mode ~= "Airborne" then
		return self:turnChange(offset, maxAngle)
	end
	local velocity = self.velocity
	local speed = velocity.Magnitude
	if speed <= EPSILON or offset.Magnitude <= EPSILON then
		return Vector3.zero
	end
	return rotateToward(velocity / speed, offset.Unit, maxAngle, self.up) * speed - velocity
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

-- A surface the collider meets in the air (the controller finds it, #258): a ride surface they land on (landsOn) takes
-- them feet first, as any touchdown (a diver's on the belly); anything else, or on the ground, only blocks, so a leap
-- up the glass slides up it. A surface that holds but does not land them (they are still rising, landsOn) is the one
-- that catches them once they fall (#267). Says whether anything was lost.
function SkateMath.touch(self: Skater, normal: Vector3, input: Types.SkateInput): boolean
	if not self:block(normal) then
		return false
	end
	if self.mode == "Airborne" then
		if landsOn(self, normal) then
			touchDown(self, input)
			self.up = normal
		elseif holds(self, normal) then
			self._leftWall = normal
		end
	end
	return true
end

-- The way the controller's ground ray looks (a unit direction): along the feet, or toward the wall they left or
-- touched while they fly beside it, rising (its grip keeps them by it, #289) or falling (it catches them, #258).
function SkateMath.groundRay(self: Skater): Vector3
	local wall = self._leftWall
	return if wall ~= nil then -wall else -self.up
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
