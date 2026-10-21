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
	it("calls a touch on a thrown ball headed through the ring a block", function()
		expect(detector():classify("Touch", true, ON_TARGET_POSITION, ON_TARGET_VELOCITY)).toBe("Block")
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
