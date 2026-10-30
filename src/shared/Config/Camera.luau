--!strict
-- The chase camera (spec §8.4): how far behind and above the skater it sits, how its view widens with speed toward
-- Movement.hardCap, how far it tips, how fast and how far it rolls with the surface the skater rides, and how fast it
-- swings back behind them (gamepad and touch), turns toward the ball (Ball Focus) and pulls in in front of the arena.
-- Responses are rates per second: each frame closes 1 − e^(−response × dt) of the gap. Distances in studs, angles in
-- degrees. The spec gives distance, height and the two fields of view; the rest are starting points for tuning.

local Validate = require(script.Parent.Validate)

export type CameraConfig = {
	distance: number,
	-- The point the camera looks past sits this far above the root, along the camera's up.
	height: number,
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
	distance = 12,
	height = 4,
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

local schema = Validate.checkAll(
	Validate.record({
		distance = positive,
		height = positive,
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
	}
)

return {
	defaults = defaults,
	schema = schema,
}
