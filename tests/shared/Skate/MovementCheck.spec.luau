--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local MovementCheck = require(ReplicatedStorage.Shared.Skate.MovementCheck)

local config = Config.defaults()
local movement = config.Movement
local network = config.Network

-- A 0.25 s sample allows hardCap × speedTolerance × 0.25 = 121 × 1.2 × 0.25 = 36.3 studs, and a move past twice that
-- returns at once.
describe("MovementCheck", function()
	it("allows hardCap × speedTolerance, the fastest a skater may move", function()
		expect(MovementCheck.speedLimit(movement, network)).toBeCloseTo(145.2, 6)
	end)

	it("returns a skater who is too fast for guardStrikes samples in a row to the last valid place", function()
		local check = MovementCheck.new(movement, network)
		check:reset("A", Vector3.zero, 0)
		expect(check:sample("A", Vector3.new(0, 0, -30), 0.25)).toBe("Ok")
		expect(check:sample("A", Vector3.new(0, 0, -80), 0.5)).toBe("Strike")
		expect(check:sample("A", Vector3.new(0, 0, -130), 0.75)).toBe("Strike")
		expect(check:sample("A", Vector3.new(0, 0, -180), 1)).toBe("Return")
		expect((check:lastValid("A") :: Vector3).Z).toBeCloseTo(-30, 6)
	end)

	it("forgives the strikes once the skater is back under the limit", function()
		local check = MovementCheck.new(movement, network)
		check:reset("A", Vector3.zero, 0)
		check:sample("A", Vector3.new(0, 0, -50), 0.25)
		check:sample("A", Vector3.new(0, 0, -100), 0.5)
		expect(check:sample("A", Vector3.new(0, 0, -130), 0.75)).toBe("Ok")
		expect(check:sample("A", Vector3.new(0, 0, -180), 1)).toBe("Strike")
	end)

	it("returns at once a skater who moves farther than guardTeleportFactor allows in one sample", function()
		local check = MovementCheck.new(movement, network)
		check:reset("A", Vector3.zero, 0)
		expect(check:sample("A", Vector3.new(0, 0, -85), 0.25)).toBe("Return")
	end)

	it("never counts falling", function()
		local check = MovementCheck.new(movement, network)
		check:reset("A", Vector3.new(0, 100, 0), 0)
		expect(check:sample("A", Vector3.zero, 0.25)).toBe("Ok")
	end)

	it("starts over from a reset, so the server's own jumps never count", function()
		local check = MovementCheck.new(movement, network)
		check:reset("A", Vector3.zero, 0)
		check:reset("A", Vector3.new(500, 0, 0), 0.2)
		expect(check:sample("A", Vector3.new(510, 0, 0), 0.45)).toBe("Ok")
	end)

	it("judges a first sample as a reset, and keeps players apart", function()
		local check = MovementCheck.new(movement, network)
		expect(check:sample("A", Vector3.new(900, 0, 0), 0)).toBe("Ok")
		check:reset("B", Vector3.zero, 0)
		expect(check:sample("B", Vector3.new(30, 0, 0), 0.25)).toBe("Ok")
	end)

	it("forgets a player, so their next sample starts over", function()
		local check = MovementCheck.new(movement, network)
		check:reset("A", Vector3.zero, 0)
		check:forget("A")
		expect(check:lastValid("A")).toBe(nil)
		expect(check:sample("A", Vector3.new(500, 0, 0), 0.25)).toBe("Ok")
	end)
end)
