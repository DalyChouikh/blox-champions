--!strict
-- The chase camera's state (spec §8.4), stepped each frame: which way is up, the heading on the plane that up defines,
-- the pitch above or below it, and the field of view. Up rolls toward the surface the skater rides, so on a wall the
-- view tilts and over an overhang it loops (owner, 2026-10-23); the heading rides along with the roll. The look input
-- turns and tips it. Ball Focus turns it toward the ball; otherwise, on a device that allows it, it swings back behind
-- the skater's travel once the look input has rested. Every response closes 1 − e^(−rate × dt) of its gap. Vector3
-- math only: a step allocates nothing.

local Config = require(script.Parent.Parent.Config)
local Vectors = require(script.Parent.Parent.Util.Vectors)

-- One frame's input.
export type Target = {
	-- The up to roll toward: the skater's surface up, or world up for a spectator.
	up: Vector3,
	-- The velocity the swing-back turns behind.
	travel: Vector3,
	-- The look input as a rate, in radians per second, as Roblox's own camera reads it (a step turns it for dt): x > 0
	-- turns right, y > 0 tips down.
	look: Vector2,
	-- The device swings back behind the travel (gamepad and touch; never a mouse).
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

-- Rolls up toward `toward` by its share of the angle, carrying the heading by the same rotation. Turned exactly
-- upside down, it rolls about the camera's right, as over the top of a loop.
local function roll(self: ChaseCamera, toward: Vector3, dt: number)
	if toward.Magnitude <= Vectors.EPSILON then
		return
	end
	local goal = toward.Unit
	local angle = Vectors.angleBetween(self.up, goal)
	if angle <= Vectors.EPSILON then
		return
	end
	local axis = self.up:Cross(goal)
	axis = if axis.Magnitude > Vectors.EPSILON then axis.Unit else self.forward:Cross(self.up).Unit
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
		up = Vector3.yAxis,
		forward = -Vector3.zAxis,
		pitch = 0,
		fov = camera.fovBase,
		idle = 0,
		_camera = camera,
		_hardCap = hardCap,
		_minPitch = math.rad(camera.minPitchDeg),
		_maxPitch = math.rad(camera.maxPitchDeg),
	}
	local chase = setmetatable(self, ChaseCamera)
	chase:reset(up, forward)
	return chase
end

-- Behind `forward` on `up`, level, at the resting field of view, as at a kickoff or for a new character.
function ChaseCamera.reset(self: ChaseCamera, up: Vector3, forward: Vector3)
	self.up = up.Unit
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
		local travel = Vectors.alongSurface(target.travel, self.up)
		if travel.Magnitude >= camera.recenterMinSpeed then
			turnToward(self, travel, closed(camera.recenterResponse, dt))
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
