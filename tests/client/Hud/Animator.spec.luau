--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Animator = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Animator)
local Config = require(ReplicatedStorage.Shared.Config)

-- Motion.spec's round timings: every part eases out, 0.875 of the way halfway through. The press lasts twice
-- Motion.spec's, longer than the bounce, so a press timed as a bounce shows.
local MOTION: Config.MotionSettings = {
	pop = { seconds = 0.2, overshoot = 0.12 },
	bounce = { seconds = 0.3, scale = 1.6, rebound = 0.9 },
	press = { seconds = 0.6, scale = 0.8, rebound = 1.1 },
	easeSeconds = 0.2,
	lapHoldSeconds = 0.5,
	glow = { seconds = 2, transparency = 0.8 },
	speedRate = 6,
}

describe("Animator", function()
	it("keeps a track at rest where it was made, writing nothing while it rests", function()
		local animator = Animator.new(MOTION)
		local track = animator:track(1)
		expect(track.value).toBe(1)
		expect(track.binding:getValue()).toBe(1)
		animator:step(1 / 60)
		animator:step(1 / 60)
		expect(animator.writes).toBe(0)
	end)

	it("pops a part in, then rests on its size", function()
		local animator = Animator.new(MOTION)
		local track = animator:track(0)
		animator:play(track, "Pop", 1)
		animator:step(0.05)
		expect(track.value).toBeCloseTo(0.98, 6)
		expect(track.binding:getValue()).toBeCloseTo(0.98, 6)
		animator:step(0.05)
		expect(track.value).toBeCloseTo(1.12, 6)
		animator:step(0.1)
		expect(track.value).toBe(1)
		local writes = animator.writes
		animator:step(0.1)
		expect(animator.writes).toBe(writes)
		expect(track.moving).toBe(false)
	end)

	it("bounces a part about its size", function()
		local animator = Animator.new(MOTION)
		local track = animator:track(1)
		animator:play(track, "Bounce", 1)
		expect(track.moving).toBe(true)
		animator:step(0.1)
		expect(track.value).toBeCloseTo(1.6, 6)
		animator:step(0.1)
		expect(track.value).toBeCloseTo(0.9, 6)
		animator:step(0.1)
		expect(track.value).toBe(1)
		expect(track.moving).toBe(false)
	end)

	it("presses a part in and springs it back", function()
		local animator = Animator.new(MOTION)
		local track = animator:track(1)
		animator:play(track, "Press", 1)
		animator:step(0.2)
		expect(track.value).toBeCloseTo(0.8, 6)
		animator:step(0.2)
		expect(track.value).toBeCloseTo(1.1, 6)
		animator:step(0.2)
		expect(track.value).toBe(1)
		expect(track.moving).toBe(false)
	end)

	it("eases a part from where it is to where it goes, a new motion starting from where the last left it", function()
		local animator = Animator.new(MOTION)
		local track = animator:track(1)
		animator:play(track, "Ease", 0)
		expect(track.target).toBe(0)
		animator:step(0.1)
		expect(track.value).toBeCloseTo(0.125, 6)
		-- Back to full from 0.125: 0.125 + 0.875 x 0.875 halfway.
		animator:play(track, "Ease", 1)
		animator:step(0.1)
		expect(track.value).toBeCloseTo(0.890625, 6)
		animator:step(0.1)
		expect(track.value).toBe(1)
	end)

	it("fills a lap chip, holds it, then empties it", function()
		local animator = Animator.new(MOTION)
		local track = animator:track(0)
		animator:play(track, "Lap", 0)
		animator:step(0.1)
		expect(track.value).toBeCloseTo(0.875, 6)
		animator:step(0.4)
		expect(track.value).toBe(1)
		animator:step(0.3)
		expect(track.value).toBeCloseTo(0.125, 6)
		animator:step(0.1)
		expect(track.value).toBe(0)
		expect(track.moving).toBe(false)
	end)

	it("glows on, cycle after cycle, until the track is put to rest", function()
		local animator = Animator.new(MOTION)
		local track = animator:track(1)
		animator:play(track, "Glow", 1)
		animator:step(1)
		expect(track.value).toBeCloseTo(0.8, 6)
		animator:step(2)
		expect(track.value).toBeCloseTo(0.8, 6)
		expect(track.moving).toBe(true)
		animator:rest(track, 1)
		expect(track.value).toBe(1)
		expect(track.binding:getValue()).toBe(1)
		expect(track.moving).toBe(false)
		local writes = animator.writes
		animator:step(0.5)
		expect(animator.writes).toBe(writes)
	end)

	it("writes a track's binding only when its value changes", function()
		local animator = Animator.new(MOTION)
		local track = animator:track(1)
		animator:rest(track, 1)
		expect(animator.writes).toBe(0)
		animator:rest(track, 0)
		expect(animator.writes).toBe(1)
		-- A bounce about 1 leaves 0 for 1 at once: the first step writes, the rest only while it moves.
		animator:play(track, "Bounce", 1)
		animator:step(0.15)
		animator:step(0.15)
		animator:step(0.15)
		expect(animator.writes).toBe(3)
	end)
end)
