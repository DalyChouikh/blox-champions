--!strict
-- The chase camera (spec §8.4): how far behind and above the skater it sits, how its view widens with speed toward
-- Movement.hardCap, how far it tips, and how fast it rolls with the surface the skater rides, swings back behind them
-- (gamepad and touch), turns toward the ball (Ball Focus) and pulls in in front of the arena. Responses are rates per
-- second: each frame closes 1 − e^(−response × dt) of the gap. Distances in studs, angles in degrees. The spec gives
-- distance, height and the two fields of view; the rest are starting points for tuning.

local Validate = require(script.Parent.Validate)

export type CameraConfig = {
	distance: number,
	-- The point the camera looks past sits this far above the root, along the camera's up.
	height: number,
	-- In front of a wall the camera pulls in, never closer than minDistance, and stays collisionMargin off it.
	minDistance: number,
	collisionMargin: number,
	fovBase: number,
	fovMax: number,
	fovResponse: number,
	minPitchDeg: number,
	maxPitchDeg: number,
	rollResponse: number,
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
	minDistance = 2,
	collisionMargin = 0.5,
	fovBase = 70,
	fovMax = 90,
	fovResponse = 6,
	minPitchDeg = -70,
	maxPitchDeg = 60,
	rollResponse = 8,
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
		minDistance = positive,
		collisionMargin = nonNegative,
		fovBase = fov,
		fovMax = fov,
		fovResponse = nonNegative,
		minPitchDeg = Validate.number({ min = -89, max = 0 }),
		maxPitchDeg = Validate.number({ min = 0, max = 89 }),
		rollResponse = nonNegative,
		recenterDelay = nonNegative,
		recenterResponse = nonNegative,
		recenterMinSpeed = nonNegative,
		ballFocusResponse = nonNegative,
		spectator = Validate.record({ distance = positive, height = nonNegative }),
	}),
	{
		{
			message = "minDistance must be at most distance",
			holds = function(camera: CameraConfig): boolean
				return camera.minDistance <= camera.distance
			end,
		},
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
