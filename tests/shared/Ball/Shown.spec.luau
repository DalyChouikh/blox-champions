--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Shown = require(ReplicatedStorage.Shared.Ball.Shown)

local GRAVITY = Vector3.new(0, -130.8, 0)
local CORRECTION = 0.08
local SNAP = 10

-- #316 (Q101): each screen draws the loose ball where the server's last state says it is now, closing on each new
-- state smoothly, at once across a jump.
describe("Shown", function()
	it("carries a state on to now: in a straight line with its weight cancelled, else falling", function()
		local position, velocity = Shown.predict(Vector3.new(0, 10, 0), Vector3.new(90, 0, 0), GRAVITY, 0.1)
		-- 90 x 0.1 along; 10 - 130.8 x 0.1^2 / 2 = 9.346 up; falling at 130.8 x 0.1 = 13.08.
		Fixtures.expectNear(position, Vector3.new(9, 9.346, 0))
		Fixtures.expectNear(velocity, Vector3.new(90, -13.08, 0))
		position, velocity = Shown.predict(Vector3.new(0, 10, 0), Vector3.new(90, 0, 0), Vector3.zero, 0.1)
		Fixtures.expectNear(position, Vector3.new(9, 10, 0))
		Fixtures.expectNear(velocity, Vector3.new(90, 0, 0))
		position = Shown.predict(Vector3.new(0, 10, 0), Vector3.new(90, 0, 0), GRAVITY, 0)
		Fixtures.expectNear(position, Vector3.new(0, 10, 0))
	end)

	it("moves a drawn ball with the server's, and closes a gap over the correction time", function()
		-- On the target: it moves with it, 90 / 60 = 1.5 a frame.
		local drawn, snapped =
			Shown.follow(Vector3.zero, Vector3.new(1.5, 0, 0), Vector3.new(90, 0, 0), 1 / 60, CORRECTION, SNAP)
		Fixtures.expectNear(drawn, Vector3.new(1.5, 0, 0))
		expect(snapped).toBe(false)
		-- 2 studs short of a still target: after one correction time, 1 - e^-1 = 63.2% of the gap is closed.
		drawn, snapped = Shown.follow(Vector3.zero, Vector3.new(2, 0, 0), Vector3.zero, CORRECTION, CORRECTION, SNAP)
		Fixtures.expectNear(drawn, Vector3.new(1.26424, 0, 0))
		expect(snapped).toBe(false)
		-- No time, no change.
		drawn = Shown.follow(Vector3.zero, Vector3.new(2, 0, 0), Vector3.new(90, 0, 0), 0, CORRECTION, SNAP)
		Fixtures.expectNear(drawn, Vector3.zero)
	end)

	it("jumps to a target farther than the snap distance, and only then", function()
		local drawn, snapped =
			Shown.follow(Vector3.zero, Vector3.new(0, 10.01, 0), Vector3.zero, 1 / 60, CORRECTION, SNAP)
		Fixtures.expectNear(drawn, Vector3.new(0, 10.01, 0))
		expect(snapped).toBe(true)
		-- Exactly the snap distance away: closed smoothly, 1 - e^(-1/60 / 0.08) = 18.81% of it.
		drawn, snapped = Shown.follow(Vector3.zero, Vector3.new(0, 10, 0), Vector3.zero, 1 / 60, CORRECTION, SNAP)
		Fixtures.expectNear(drawn, Vector3.new(0, 1.88064, 0))
		expect(snapped).toBe(false)
		-- The gap counts after the drawn ball moves with the server's: 11.5 away, past the snap distance, but 90 for
		-- 1/12 s moves it 7.5, leaving 4, closed by 1 - e^(-1/12 / 0.08) = 64.71%: 7.5 + 2.58854.
		drawn, snapped =
			Shown.follow(Vector3.zero, Vector3.new(11.5, 0, 0), Vector3.new(90, 0, 0), 1 / 12, CORRECTION, SNAP)
		Fixtures.expectNear(drawn, Vector3.new(10.08854, 0, 0))
		expect(snapped).toBe(false)
	end)
end)
