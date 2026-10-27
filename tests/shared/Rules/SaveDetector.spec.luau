--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local SaveDetector = require(ReplicatedStorage.Shared.Rules.SaveDetector)

-- Reaches x = 200 after 0.1 s, 0.98 studs below the ring's center.
local ON_TARGET_POSITION, ON_TARGET_VELOCITY = Vector3.new(190, 15, 0), Vector3.new(100, 0, 0)

local function detector(lookaheadSeconds: number?): SaveDetector.SaveDetector
	return SaveDetector.new(Fixtures.ring(), Fixtures.GRAVITY, lookaheadSeconds or 1.5)
end

describe("SaveDetector", function()
	it("calls a touch on a thrown ball headed through the ring, from either side, a block", function()
		expect(detector():classify("Touch", true, ON_TARGET_POSITION, ON_TARGET_VELOCITY)).toBe("Block")
		-- The mirror image: from behind the ring, back through it (the owner, 2026-10-27: the goal scores either way).
		local behind = Vector3.new(2 * 200 - ON_TARGET_POSITION.X, ON_TARGET_POSITION.Y, 0)
		expect(detector():classify("Touch", true, behind, -ON_TARGET_VELOCITY)).toBe("Block")
	end)

	it("calls a block on the later of an arc's two crossings when only it passes through the ring", function()
		-- A ring lying flat 10 up (ours stands upright, so an arc meets it once): a ball thrown up from (6, 0, 0) at
		-- (-1, 30) under 10 studs/s^2 rises through its plane 5.65 from the axis, then falls back through it at 0.35.
		local flat = { frame = CFrame.lookAt(Vector3.new(0, 10, 0), Vector3.new(0, 11, 0), Vector3.zAxis), radius = 3 }
		local position, velocity, gravity = Vector3.new(6, 0, 0), Vector3.new(-1, 30, 0), Vector3.new(0, -10, 0)
		expect(SaveDetector.new(flat, gravity, 10):classify("Touch", true, position, velocity)).toBe("Block")
		-- Before the fall back through the ring: only the miss going up.
		expect(SaveDetector.new(flat, gravity, 3):classify("Touch", true, position, velocity)).toBeNil()
	end)

	it("needs the ball to have been thrown for a block", function()
		expect(detector():classify("Touch", false, ON_TARGET_POSITION, ON_TARGET_VELOCITY)).toBeNil()
	end)

	it("ignores a thrown ball that would miss the ring", function()
		expect(detector():classify("Touch", true, ON_TARGET_POSITION, Vector3.new(100, 0, 50))).toBeNil()
	end)

	it("ignores a ball that would reach the ring after the lookahead", function()
		-- Arcs up and back down to (200, 15, 0) at t = 2 s.
		local position, velocity = Vector3.new(0, 15, 0), Vector3.new(100, 196.2, 0)
		expect(detector(1.5):classify("Touch", true, position, velocity)).toBeNil()
		expect(detector(2.5):classify("Touch", true, position, velocity)).toBe("Block")
	end)

	it("calls a defender's pickup a steal save, and a pickup that is also a block one block", function()
		expect(detector():classify("Pickup", false, Vector3.zero, Vector3.zero)).toBe("Steal")
		expect(detector():classify("Pickup", true, ON_TARGET_POSITION, ON_TARGET_VELOCITY)).toBe("Block")
	end)
end)
