--!strict
-- The chase camera (spec §8.4): how far behind and above the skater it sits at each pitch, how its view widens with
-- speed toward Movement.hardCap, how far it tips, how fast and how far it rolls with the surface the skater rides, and
-- how fast it swings back behind them (gamepad and touch), turns toward the ball (Ball Focus) and pulls in in front of
-- the arena. Responses are rates per second: each frame closes 1 − e^(−response × dt) of the gap. Distances in studs,
-- angles in degrees. The owner picked the framing by playing it, the spec gives the two fields of view, and the rest
-- are starting points for tuning.

local Validate = require(script.Parent.Validate)

-- One point of the camera's framing.
export type CameraFraming = {
	-- Degrees above the heading's plane (below it when negative).
	pitchDeg: number,
	-- How far behind its focus, the point it looks past, the camera sits.
	distance: number,
	-- How far above the root the focus sits, along the camera's up; below it, toward the feet, when negative.
	height: number,
}

export type CameraConfig = {
	-- Where the camera sits by its pitch: points rising in pitch, joined by straight lines, held past the first and
	-- the last. The owner's trial A3 (#276, Q53), the third played: Roller Champions' camera (Video 18) backs out
	-- above the skater looking down and slides in to their feet looking up; trial A (Q47: RC's sizes on screen at
	-- our field of view, 6 out level) and A2 (Q48: 1.5 times A) sat too close aiming up at the ring ("the camera is
	-- almost attached to the player"), and A2's focus on the head put the crosshair dot on it (Q51). A3 is about
	-- 1.2 times A2, 12 out level (the old camera's distance), the focus 1.5 above the head (the root is 2.5 above
	-- the floor, the head's top about 3.3 above the root).
	framing: { CameraFraming },
	-- The local skater fades, on this client only, as the camera closes in on its focus: whole at `seen` studs or
	-- farther, gone at `gone` or nearer, straight between. Roller Champions' skater turns see-through and vanishes
	-- as its camera slides in to the feet (Video 18: fading from 2.6 s, gone by 3.1 s); the owner played it in
	-- trials A to A3 (#276, Q47-Q53). A wall pulling the camera in fades them too, so the body never fills the view.
	fade: { seen: number, gone: number },
	-- The camera, and the point it looks past, stay this far in front of any arena surface between them and the
	-- skater: they never pass through the arena, however close that brings them (the owner's choice, 2026-10-23).
	collisionMargin: number,
	fovBase: number,
	fovMax: number,
	fovResponse: number,
	minPitchDeg: number,
	maxPitchDeg: number,
	rollResponse: number,
	-- The camera's up leans with the surface at most this far from world up, so on a wall the floor never stands up on
	-- screen and over a lip the view never turns past sideways. The owner (#223): 30, picked from screenshots. Under
	-- 90, so two ups it may take are never opposite (two facing walls at 90 would be) and a roll always has an axis.
	maxTiltDeg: number,
	-- Gamepad and touch: once the look input has rested recenterDelay seconds, the camera swings behind a skater moving
	-- at least recenterMinSpeed.
	recenterDelay: number,
	recenterResponse: number,
	recenterMinSpeed: number,
	ballFocusResponse: number,
	-- A player with no character watches the ball from here.
	spectator: { distance: number, height: number },
}

local defaults: CameraConfig = {
	framing = {
		{ pitchDeg = -55, distance = 22, height = 5 },
		{ pitchDeg = -35, distance = 19, height = 5 },
		{ pitchDeg = -20, distance = 16, height = 5 },
		{ pitchDeg = -10, distance = 14, height = 5 },
		{ pitchDeg = 0, distance = 12, height = 5 },
		{ pitchDeg = 15, distance = 10, height = 5 },
		{ pitchDeg = 30, distance = 5, height = 1.5 },
		{ pitchDeg = 45, distance = 1, height = -1.5 },
	},
	fade = { seen = 4, gone = 1.5 },
	collisionMargin = 0.5,
	fovBase = 70,
	fovMax = 90,
	fovResponse = 6,
	minPitchDeg = -70,
	maxPitchDeg = 60,
	rollResponse = 8,
	maxTiltDeg = 30,
	recenterDelay = 0.5,
	recenterResponse = 2.5,
	recenterMinSpeed = 10,
	ballFocusResponse = 10,
	spectator = { distance = 30, height = 6 },
}

local positive = Validate.number({ above = 0 })
local nonNegative = Validate.number({ min = 0 })
local fov = Validate.number({ above = 0, max = 120 })
local framingPoint = Validate.record({ pitchDeg = Validate.number(), distance = positive, height = Validate.number() })

local schema = Validate.checkAll(
	Validate.record({
		framing = Validate.check(Validate.list(framingPoint), function(points: { CameraFraming }): boolean
			return #points > 0
		end, "must not be empty"),
		fade = Validate.record({ seen = nonNegative, gone = nonNegative }),
		collisionMargin = nonNegative,
		fovBase = fov,
		fovMax = fov,
		fovResponse = nonNegative,
		minPitchDeg = Validate.number({ min = -89, max = 0 }),
		maxPitchDeg = Validate.number({ min = 0, max = 89 }),
		rollResponse = nonNegative,
		maxTiltDeg = Validate.number({ above = 0, max = 89 }),
		recenterDelay = nonNegative,
		recenterResponse = nonNegative,
		recenterMinSpeed = nonNegative,
		ballFocusResponse = nonNegative,
		spectator = Validate.record({ distance = positive, height = nonNegative }),
	}),
	{
		{
			message = "fovMax must be at least fovBase",
			holds = function(camera: CameraConfig): boolean
				return camera.fovMax >= camera.fovBase
			end,
		},
		-- Points out of order leave pitches with no line to sit on, and two at one pitch make a line of no width.
		{
			message = "framing must rise in pitchDeg, each point above the one before",
			holds = function(camera: CameraConfig): boolean
				local points = camera.framing
				for index = 2, #points do
					if points[index].pitchDeg <= points[index - 1].pitchDeg then
						return false
					end
				end
				return true
			end,
		},
		{
			message = "fade.seen must be above fade.gone",
			holds = function(camera: CameraConfig): boolean
				return camera.fade.seen > camera.fade.gone
			end,
		},
		-- A point past a limit is never reached: it could only bend the line to the next one.
		{
			message = "framing's pitchDeg must lie within minPitchDeg and maxPitchDeg",
			holds = function(camera: CameraConfig): boolean
				for _, point in camera.framing do
					if point.pitchDeg < camera.minPitchDeg or point.pitchDeg > camera.maxPitchDeg then
						return false
					end
				end
				return true
			end,
		},
	}
)

return {
	defaults = defaults,
	schema = schema,
}
