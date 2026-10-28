--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local MovementCheck = require(ReplicatedStorage.Shared.Skate.MovementCheck)
local SkateMath = require(ReplicatedStorage.Shared.Skate.SkateMath)
local Types = require(ReplicatedStorage.Shared.Skate.Types)

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

	-- The dive (#241) speeds up down the fall line to hardCap, never past it.
	it("accepts a whole dive down the fall line, sampled as the server samples it", function()
		local dt = 1 / 60
		local diver = SkateMath.new(movement, Fixtures.GRAVITY)
		diver.mode = "Airborne"
		diver:push(diver:diveChange((config.Actions.Dive.motion :: Config.Motion).diveSpeed :: number), false)
		local input: Types.SkateInput = {
			move = Vector3.zero,
			pump = false,
			brake = false,
			jump = false,
			draftAccel = 0,
			knockedDown = false,
			diving = true,
		}
		local noGround: Types.Ground = { hit = false, normal = Vector3.yAxis, distance = 0 }
		local check = MovementCheck.new(movement, network)
		local position = Vector3.new(0, 100, 0)
		check:reset("A", position, 0)
		local verdicts: { string } = {}
		for frame = 1, 120 do
			diver:step(input, noGround, dt)
			position += diver.velocity * dt
			if frame % 15 == 0 then
				table.insert(verdicts, check:sample("A", position, frame * dt))
			end
		end
		expect(diver.velocity.Magnitude).toBeCloseTo(movement.hardCap, 3)
		expect(verdicts).toEqual(table.create(8, "Ok"))
	end)
end)
