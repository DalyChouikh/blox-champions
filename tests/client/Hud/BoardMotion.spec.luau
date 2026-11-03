--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Hud = game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud
local Animator = require(Hud.Animator)
local BoardMotion = require(Hud.BoardMotion)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)

-- Motion.spec's round timings: every part eases out, 0.875 of the way halfway through.
local config = Fixtures.config({
	UI = {
		hud = {
			motion = {
				pop = { seconds = 0.2, overshoot = 0.12 },
				bounce = { seconds = 0.3, scale = 1.6, rebound = 0.9 },
				easeSeconds = 0.2,
				lapHoldSeconds = 0.5,
				glow = { seconds = 2, transparency = 0.8 },
			},
		},
	},
})

-- A scoreboard's motion watching match snapshots, and its clock.
local function board(): (BoardMotion.BoardMotion, Animator.Animator)
	local animator = Animator.new(config.UI.hud.motion)
	return BoardMotion.new(HudText.new(config), animator), animator
end

local function match(overrides: { [string]: any }?): any
	return Fixtures.matchSnapshot(overrides).match
end

-- Each lap chip's fill, in order.
local function fills(motion: BoardMotion.BoardMotion): { number }
	local values = {}
	for _, chip in motion.chips do
		table.insert(values, chip.value)
	end
	return values
end

describe("BoardMotion", function()
	it("starts at rest on the first snapshot: the chips filled, the worth chip shown and glowing", function()
		local motion, animator = board()
		motion:watch(match({ possessingTeam = "Blue", lapProgress = 2, streak = 2, goalOpenFor = "Blue" }))
		expect(fills(motion)).toEqual({ 1, 1, 0, 0 })
		expect(motion.worth.value).toBe(1)
		expect(motion.worthText).toBe("+3")
		expect(motion.worthTeam).toBe("Blue")
		expect(motion.glow.moving).toBe(true)
		expect(motion.scores.Blue.moving or motion.scores.Orange.moving).toBe(false)
		animator:step(1)
		expect(motion.glow.value).toBeCloseTo(0.8, 6)
	end)

	it("bounces a team's score when it rises, and not when a new match sets it back", function()
		local motion, animator = board()
		motion:watch(match({ scores = { Blue = 1, Orange = 2 } }))
		motion:watch(match({ scores = { Blue = 4, Orange = 2 } }))
		expect(motion.scores.Blue.moving).toBe(true)
		expect(motion.scores.Orange.moving).toBe(false)
		animator:step(0.1)
		expect(motion.scores.Blue.value).toBeCloseTo(1.6, 6)
		animator:step(0.2)
		expect(motion.scores.Blue.value).toBe(1)
		motion:watch(match({ scores = { Blue = 0, Orange = 0 } }))
		expect(motion.scores.Blue.moving or motion.scores.Orange.moving).toBe(false)
	end)

	it("fills a chip for each gate the team with the ball crosses, easing", function()
		local motion, animator = board()
		motion:watch(match({ possessingTeam = "Orange", lapProgress = 1 }))
		motion:watch(match({ possessingTeam = "Orange", lapProgress = 2 }))
		animator:step(0.1)
		expect(fills(motion)).toEqual({ 1, 0.875, 0, 0 })
		animator:step(0.1)
		expect(fills(motion)).toEqual({ 1, 1, 0, 0 })
	end)

	-- The owner (Q196): the fourth chip fills at the lap's last gate, then all four empty for the next lap.
	it("fills the last chip as a lap completes, holds the row full, then empties it for the next lap", function()
		local motion, animator = board()
		motion:watch(match({ possessingTeam = "Blue", lapProgress = 3, streak = 0 }))
		-- The lap's last gate: the snapshot has the next lap's progress, 0, and one more lap.
		motion:watch(match({ possessingTeam = "Blue", lapProgress = 0, streak = 1 }))
		animator:step(0.1)
		expect(fills(motion)).toEqual({ 1, 1, 1, 0.875 })
		animator:step(0.4)
		expect(fills(motion)).toEqual({ 1, 1, 1, 1 })
		animator:step(0.3)
		local after = fills(motion)
		for _, fill in after do
			expect(fill).toBeCloseTo(0.125, 6)
		end
		animator:step(0.1)
		expect(fills(motion)).toEqual({ 0, 0, 0, 0 })
	end)

	it("moves the chips at once when the ball changes teams or goes loose", function()
		local motion = board()
		motion:watch(match({ possessingTeam = "Blue", lapProgress = 3, streak = 1 }))
		motion:watch(match({ possessingTeam = "Orange", lapProgress = 1, streak = 0 }))
		expect(fills(motion)).toEqual({ 1, 0, 0, 0 })
		motion:watch(match({ lapProgress = 0, streak = 0 }))
		expect(fills(motion)).toEqual({ 0, 0, 0, 0 })
		for _, chip in motion.chips do
			expect(chip.moving).toBe(false)
		end
	end)

	it("pops the worth chip in as the goal opens, bounces it as it grows, shrinks it as it closes", function()
		local motion, animator = board()
		motion:watch(match({ possessingTeam = "Orange", lapProgress = 0, streak = 0 }))
		expect(motion.worth.value).toBe(0)
		motion:watch(match({ possessingTeam = "Orange", streak = 1, goalOpenFor = "Orange" }))
		expect(motion.worthText).toBe("+1")
		expect(motion.worthTeam).toBe("Orange")
		animator:step(0.1)
		expect(motion.worth.value).toBeCloseTo(1.12, 6)
		expect(motion.glow.moving).toBe(true)
		animator:step(0.1)
		expect(motion.worth.value).toBe(1)

		motion:watch(match({ possessingTeam = "Orange", streak = 2, goalOpenFor = "Orange" }))
		expect(motion.worthText).toBe("+3")
		animator:step(0.1)
		expect(motion.worthBounce.value).toBeCloseTo(1.6, 6)
		expect(motion.worth.value).toBe(1)

		-- A goal closes it (the streak stays until the kickoff); the chip keeps its last text and colour as it goes.
		motion:watch(match({ possessingTeam = "Orange", streak = 2, scores = { Blue = 0, Orange = 3 } }))
		animator:step(0.1)
		expect(motion.worth.value).toBeCloseTo(0.125, 6)
		expect(motion.worthText).toBe("+3")
		expect(motion.worthTeam).toBe("Orange")
		expect(motion.glow.moving).toBe(false)
		expect(motion.glow.value).toBe(1)
		animator:step(0.1)
		expect(motion.worth.value).toBe(0)
	end)

	it("waits for the first snapshot, and makes one chip per gate of the arena", function()
		local motion = board()
		motion:watch(nil)
		expect(#motion.chips).toBe(0)
		motion:watch(match({ gateCount = 5 }))
		expect(#motion.chips).toBe(5)
	end)
end)
