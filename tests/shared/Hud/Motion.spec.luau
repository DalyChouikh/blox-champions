--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Motion = require(ReplicatedStorage.Shared.Hud.Motion)

-- Round timings of this spec's own, so each value below can be worked by hand; every part eases out, 1 - (1 - p)^3,
-- which is 0.875 halfway through.
local MOTION: Config.MotionSettings = {
	pop = { seconds = 0.2, overshoot = 0.12 },
	bounce = { seconds = 0.3, scale = 1.6, rebound = 0.9 },
	press = { seconds = 0.3, scale = 0.8, rebound = 1.1 },
	easeSeconds = 0.2,
	lapHoldSeconds = 0.5,
	glow = { seconds = 2, transparency = 0.8 },
	speedRate = 6,
}

describe("Motion", function()
	it("pops a part in from nothing, past its size by the overshoot at half the time, then settles", function()
		expect(Motion.pop(MOTION, -0.1)).toBe(0)
		expect(Motion.pop(MOTION, 0)).toBe(0)
		-- 1.12 x 0.875.
		expect(Motion.pop(MOTION, 0.05)).toBeCloseTo(0.98, 6)
		expect(Motion.pop(MOTION, 0.1)).toBeCloseTo(1.12, 6)
		-- 1.12 - 0.12 x 0.875.
		expect(Motion.pop(MOTION, 0.15)).toBeCloseTo(1.015, 6)
		expect(Motion.pop(MOTION, 0.2)).toBe(1)
		expect(Motion.pop(MOTION, 5)).toBe(1)
	end)

	it("bounces up to its scale, back to the rebound, then settles, in three equal parts", function()
		expect(Motion.bounce(MOTION.bounce, 0)).toBe(1)
		-- 1 + 0.6 x 0.875.
		expect(Motion.bounce(MOTION.bounce, 0.05)).toBeCloseTo(1.525, 6)
		expect(Motion.bounce(MOTION.bounce, 0.1)).toBeCloseTo(1.6, 6)
		-- 1.6 - 0.7 x 0.875.
		expect(Motion.bounce(MOTION.bounce, 0.15)).toBeCloseTo(0.9875, 6)
		expect(Motion.bounce(MOTION.bounce, 0.2)).toBeCloseTo(0.9, 6)
		-- 0.9 + 0.1 x 0.875.
		expect(Motion.bounce(MOTION.bounce, 0.25)).toBeCloseTo(0.9875, 6)
		expect(Motion.bounce(MOTION.bounce, 0.3)).toBe(1)
		expect(Motion.bounce(MOTION.bounce, 5)).toBe(1)
	end)

	-- A key pressed (#354): the same three parts, in to `scale`, out past its size to `rebound`, then settled.
	it("presses a part in and springs it back past its size, in the bounce's three parts", function()
		expect(Motion.bounce(MOTION.press, 0)).toBe(1)
		expect(Motion.bounce(MOTION.press, 0.05)).toBeCloseTo(0.825, 6)
		expect(Motion.bounce(MOTION.press, 0.1)).toBeCloseTo(0.8, 6)
		expect(Motion.bounce(MOTION.press, 0.2)).toBeCloseTo(1.1, 6)
		expect(Motion.bounce(MOTION.press, 0.3)).toBeCloseTo(1, 6)
	end)

	it("eases a part over its seconds, easing out", function()
		expect(Motion.ease(MOTION, -1)).toBe(0)
		expect(Motion.ease(MOTION, 0)).toBe(0)
		expect(Motion.ease(MOTION, 0.1)).toBeCloseTo(0.875, 6)
		expect(Motion.ease(MOTION, 0.2)).toBe(1)
		expect(Motion.ease(MOTION, 1)).toBe(1)
	end)

	it("fills a lap chip, holds it full, then eases it to where the next lap starts", function()
		-- An empty chip (the lap's last gate): fills over 0.2 s, holds 0.5 s, empties over 0.2 s.
		expect(Motion.lap(MOTION, 0, 0, 0)).toBe(0)
		expect(Motion.lap(MOTION, 0, 0, 0.1)).toBeCloseTo(0.875, 6)
		expect(Motion.lap(MOTION, 0, 0, 0.2)).toBe(1)
		expect(Motion.lap(MOTION, 0, 0, 0.6)).toBe(1)
		expect(Motion.lap(MOTION, 0, 0, 0.7)).toBe(1)
		expect(Motion.lap(MOTION, 0, 0, 0.8)).toBeCloseTo(0.125, 6)
		expect(Motion.lap(MOTION, 0, 0, 0.9)).toBe(0)
		-- A chip already full stays full, then empties with the rest.
		expect(Motion.lap(MOTION, 1, 0, 0.1)).toBe(1)
		expect(Motion.lap(MOTION, 1, 0, 0.8)).toBeCloseTo(0.125, 6)
		-- A gate of the next lap already crossed: that chip ends full.
		expect(Motion.lap(MOTION, 0, 1, 0.8)).toBe(1)
		expect(Motion.lap(MOTION, 0, 1, 5)).toBe(1)
	end)

	it("glows brighter and back once a cycle, the veil thinnest halfway", function()
		expect(Motion.glow(MOTION, 0)).toBeCloseTo(1, 6)
		-- 1 - 0.2 x (1 - cos(pi / 2)) / 2.
		expect(Motion.glow(MOTION, 0.5)).toBeCloseTo(0.9, 6)
		expect(Motion.glow(MOTION, 1)).toBeCloseTo(0.8, 6)
		expect(Motion.glow(MOTION, 1.5)).toBeCloseTo(0.9, 6)
		expect(Motion.glow(MOTION, 2)).toBeCloseTo(1, 6)
		-- It loops.
		expect(Motion.glow(MOTION, 3)).toBeCloseTo(0.8, 6)
	end)

	it("eases a reading toward its target at the same pace whatever the frame rate", function()
		-- 100 x (1 - e^-1) after a sixth of a second at 6 a second.
		expect(Motion.approach(0, 100, 6, 1 / 6)).toBeCloseTo(63.2121, 4)
		local stepped = 0
		for _ = 1, 10 do
			stepped = Motion.approach(stepped, 100, 6, 1 / 60)
		end
		expect(stepped).toBeCloseTo(63.2121, 4)
		expect(Motion.approach(50, 50, 6, 1 / 60)).toBe(50)
		expect(Motion.approach(80, 20, 6, 0)).toBe(80)
	end)
end)
