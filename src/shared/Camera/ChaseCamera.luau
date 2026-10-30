--!strict
-- The chase camera's state (spec §8.4), stepped each frame: which way is up, the heading on the plane that up defines,
-- the pitch above or below it, and the field of view. Up rolls toward the surface the skater rides, but leans at most
-- maxTiltDeg from world up (the owner, #223; it used to roll all the way and loop over overhangs), so on a wall the
-- view tilts part of the way; the heading rides along with the roll. The look input turns and tips it. Ball Focus turns
-- it toward the ball; otherwise, on a device that allows it, it swings back behind the skater's facing (#246) once the
-- look input has rested. Every response closes 1 − e^(−rate × dt) of its gap. Vector3 math only: a step allocates
-- nothing.

local Config = require(script.Parent.Parent.Config)
local Vectors = require(script.Parent.Parent.Util.Vectors)

-- The up the camera leans from, and starts at.
local WORLD_UP = Vector3.yAxis

-- One frame's input.
export type Target = {
	-- The up to roll toward: the skater's surface up, or world up for a spectator.
	up: Vector3,
	-- What the swing-back turns behind, as long as the speed it is worth: the skater's facing at their shown speed
	-- (#246: riding backwards, the view still looks the way they face), or the watched ball's velocity.
	behind: Vector3,
	-- The look input as a rate, in radians per second, as Roblox's own camera reads it (a step turns it for dt): x > 0
	-- turns right, y > 0 tips down.
	look: Vector2,
	-- The device swings back (gamepad and touch; never a mouse).
	recenter: boolean,
	-- A direction to turn toward (Ball Focus).
	aimAt: Vector3?,
	-- For the field of view.
	speed: number,
}

local ChaseCamera = {}
ChaseCamera.__index = ChaseCamera

type Fields = {
	up: Vector3,
	-- Unit, on the plane perpendicular to up.
	forward: Vector3,
	-- Radians above the heading's plane.
	pitch: number,
	fov: number,
	-- Seconds since the last look input.
	idle: number,
	_camera: Config.CameraConfig,
	_hardCap: number,
	_minPitch: number,
	_maxPitch: number,
	-- Radians: maxTiltDeg.
	_maxTilt: number,
}

export type ChaseCamera = typeof(setmetatable({} :: Fields, ChaseCamera))

-- The share of a gap a response closes in `dt`.
local function closed(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

-- `vector` laid onto the plane perpendicular to the unit `up`, as a unit vector; `fallback` when it lies on no such
-- plane (it points along up).
local function onPlane(vector: Vector3, up: Vector3, fallback: Vector3): Vector3
	local flat = Vectors.alongSurface(vector, up)
	return if flat.Magnitude > Vectors.EPSILON then flat.Unit else fallback
end

-- Turns the heading toward `direction` laid on the plane, by `share` of the angle between them.
local function turnToward(self: ChaseCamera, direction: Vector3, share: number)
	local flat = Vectors.alongSurface(direction, self.up)
	if flat.Magnitude <= Vectors.EPSILON then
		return
	end
	local goal = flat.Unit
	local turned = Vectors.rotateToward(self.forward, goal, Vectors.angleBetween(self.forward, goal) * share, self.up)
	self.forward = onPlane(turned, self.up, self.forward)
end

-- The up the camera may take for a surface whose up is the unit `up`: leaned toward it at most maxTiltDeg from world
-- up, or nil for a surface facing straight down, where no side is nearer than another.
local function withinTilt(self: ChaseCamera, up: Vector3): Vector3?
	if Vectors.angleBetween(WORLD_UP, up) <= self._maxTilt then
		return up
	end
	local axis = WORLD_UP:Cross(up)
	if axis.Magnitude <= Vectors.EPSILON then
		return nil
	end
	return Vectors.rotateAbout(WORLD_UP, axis.Unit, self._maxTilt)
end

-- Rolls up toward `toward` leaned within maxTiltDeg, by its share of the angle, carrying the heading by the same
-- rotation; facing straight down, it keeps its lean. Up and its goal are both within the limit, under 90° from world
-- up, so they are never opposite and the roll always has an axis.
local function roll(self: ChaseCamera, toward: Vector3, dt: number)
	if toward.Magnitude <= Vectors.EPSILON then
		return
	end
	local goal = withinTilt(self, toward.Unit)
	if goal == nil then
		return
	end
	local angle = Vectors.angleBetween(self.up, goal)
	if angle <= Vectors.EPSILON then
		return
	end
	local axis = self.up:Cross(goal).Unit
	local turn = angle * closed(self._camera.rollResponse, dt)
	self.up = Vectors.rotateAbout(self.up, axis, turn).Unit
	self.forward = onPlane(Vectors.rotateAbout(self.forward, axis, turn), self.up, self.forward)
end

-- Turns right at look.X and tips down at look.Y radians per second, within the pitch limits; no input counts toward
-- the swing-back.
local function applyLook(self: ChaseCamera, look: Vector2, dt: number)
	if look.X == 0 and look.Y == 0 then
		self.idle += dt
		return
	end
	self.idle = 0
	if look.X ~= 0 then
		self.forward = onPlane(Vectors.rotateAbout(self.forward, self.up, -look.X * dt), self.up, self.forward)
	end
	self.pitch = math.clamp(self.pitch - look.Y * dt, self._minPitch, self._maxPitch)
end

-- Any unit vector perpendicular to the unit `up`.
local function perpendicular(up: Vector3): Vector3
	local cross = up:Cross(Vector3.xAxis)
	return if cross.Magnitude > Vectors.EPSILON then cross.Unit else up:Cross(Vector3.zAxis).Unit
end

function ChaseCamera.new(camera: Config.CameraConfig, hardCap: number, up: Vector3, forward: Vector3): ChaseCamera
	local self: Fields = {
		up = WORLD_UP,
		forward = -Vector3.zAxis,
		pitch = 0,
		fov = camera.fovBase,
		idle = 0,
		_camera = camera,
		_hardCap = hardCap,
		_minPitch = math.rad(camera.minPitchDeg),
		_maxPitch = math.rad(camera.maxPitchDeg),
		_maxTilt = math.rad(camera.maxTiltDeg),
	}
	local chase = setmetatable(self, ChaseCamera)
	chase:reset(up, forward)
	return chase
end

-- Behind `forward` on `up` (leaned within maxTiltDeg; world up for a surface facing straight down), level, at the
-- resting field of view, as at a kickoff or for a new character.
function ChaseCamera.reset(self: ChaseCamera, up: Vector3, forward: Vector3)
	local leaned = withinTilt(self, up.Unit)
	self.up = if leaned ~= nil then leaned else WORLD_UP
	self.forward = onPlane(forward, self.up, perpendicular(self.up))
	self.pitch = 0
	self.idle = 0
	self.fov = self._camera.fovBase
end

function ChaseCamera.step(self: ChaseCamera, target: Target, dt: number)
	local camera = self._camera
	roll(self, target.up, dt)
	applyLook(self, target.look, dt)
	local aimAt = target.aimAt
	if aimAt ~= nil and aimAt.Magnitude > Vectors.EPSILON then
		-- Ball Focus turns the camera: the look has not rested, so no swing-back follows it at once.
		self.idle = 0
		local share = closed(camera.ballFocusResponse, dt)
		turnToward(self, aimAt, share)
		local wanted = math.asin(math.clamp(aimAt.Unit:Dot(self.up), -1, 1))
		self.pitch += (math.clamp(wanted, self._minPitch, self._maxPitch) - self.pitch) * share
	elseif target.recenter and self.idle >= camera.recenterDelay then
		local behind = Vectors.alongSurface(target.behind, self.up)
		if behind.Magnitude >= camera.recenterMinSpeed then
			turnToward(self, behind, closed(camera.recenterResponse, dt))
		end
	end
	local fov = ChaseCamera.targetFov(camera, target.speed, self._hardCap)
	self.fov += (fov - self.fov) * closed(camera.fovResponse, dt)
end

-- Where the camera looks: along the heading, tipped by the pitch.
function ChaseCamera.lookVector(self: ChaseCamera): Vector3
	return self.forward * math.cos(self.pitch) + self.up * math.sin(self.pitch)
end

-- The field of view for a speed: fovBase at rest, widening to fovMax at hardCap.
function ChaseCamera.targetFov(camera: Config.CameraConfig, speed: number, hardCap: number): number
	return camera.fovBase + (camera.fovMax - camera.fovBase) * math.clamp(speed / hardCap, 0, 1)
end

-- How far along a ray a point may go: `desired`, or collisionMargin in front of a hit `hit` studs away, never past
-- it (nor behind the ray's start).
function ChaseCamera.pullIn(camera: Config.CameraConfig, desired: number, hit: number?): number
	if hit == nil then
		return desired
	end
	return math.max(0, math.min(desired, hit - camera.collisionMargin))
end

return ChaseCamera
