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

	-- #394: what the guard measured goes with its Output line, so a skater returned by mistake can be told from a
	-- cheat.
	it("keeps the move a run of strikes was judged on", function()
		local check = MovementCheck.new(movement, network)
		check:reset("A", Vector3.zero, 0)
		check:sample("A", Vector3.new(0, 0, -30), 0.25)
		check:sample("A", Vector3.new(0, 0, -80), 0.5)
		check:sample("A", Vector3.new(0, 0, -130), 0.75)
		expect(check:sample("A", Vector3.new(0, 0, -180), 1)).toBe("Return")
		local move = check:lastMove("A") :: MovementCheck.Move
		expect(move.from).toEqual(Vector3.new(0, 0, -130))
		expect(move.to).toEqual(Vector3.new(0, 0, -180))
		expect(move.seconds).toBeCloseTo(0.25, 6)
		expect(move.distance).toBeCloseTo(50, 6)
		expect(move.allowed).toBeCloseTo(36.3, 6)
		expect(move.jumped).toBe(false)
		expect(move.strikes).toBe(network.guardStrikes)
	end)

	it("keeps the one move a jump was judged on, counting only the upward part of a fall", function()
		local check = MovementCheck.new(movement, network)
		check:reset("A", Vector3.new(0, 100, 0), 0)
		expect(check:sample("A", Vector3.new(0, 0, -85), 0.25)).toBe("Return")
		local move = check:lastMove("A") :: MovementCheck.Move
		expect(move.from).toEqual(Vector3.new(0, 100, 0))
		expect(move.to).toEqual(Vector3.new(0, 0, -85))
		expect(move.seconds).toBeCloseTo(0.25, 6)
		expect(move.distance).toBeCloseTo(85, 6)
		expect(move.allowed).toBeCloseTo(36.3, 6)
		expect(move.jumped).toBe(true)
		expect(move.strikes).toBe(1)
	end)

	it("keeps one record of the last move per player, written over by each sample", function()
		local check = MovementCheck.new(movement, network)
		expect(check:lastMove("A")).toBeNil()
		check:reset("A", Vector3.zero, 0)
		local move = check:lastMove("A")
		check:sample("A", Vector3.new(0, 0, -10), 0.25)
		check:sample("A", Vector3.new(0, 0, -30), 0.5)
		expect(check:lastMove("A")).toBe(move)
		expect((move :: MovementCheck.Move).from).toEqual(Vector3.new(0, 0, -10))
		expect((move :: MovementCheck.Move).distance).toBeCloseTo(20, 6)
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

	-- #424: at a Play start a client takes its new character's physics a frame after the server placed it, its copy at
	-- times still where the character stood before. A second (guardPlacementSeconds) at the 145.2 limit reaches 145.2.
	describe("after a server placement", function()
		local FROM = Vector3.new(0, 100, 0)
		local TO = Vector3.new(0, 0, -500)

		local function placed(net: Config.NetworkConfig?): MovementCheck.MovementCheck
			local check = MovementCheck.new(movement, net or network)
			check:place("A", FROM, TO, 0)
			return check
		end

		it("judges the next sample from where the server put the player, a first placement too", function()
			local check = placed()
			expect(check:sample("A", TO + Vector3.new(30, 0, 0), 0.25)).toBe("Ok")
			expect(placed():sample("A", TO + Vector3.new(100, 0, 0), 0.25)).toBe("Return")
		end)

		it("takes a report from where the player stood before as Stale, starting them over at the placement", function()
			local check = placed()
			expect(check:sample("A", FROM, 0.25)).toBe("Stale")
			expect(check:lastValid("A")).toEqual(TO)
			expect(check:sample("A", TO, 0.26)).toBe("Ok")
		end)

		it("forgives the strikes a Stale report finds, as the player is put back", function()
			local check = placed()
			expect(check:sample("A", TO + Vector3.new(0, 0, 50), 0.25)).toBe("Strike")
			expect(check:sample("A", FROM, 0.5)).toBe("Stale")
			expect(check:sample("A", TO, 0.55)).toBe("Ok")
		end)

		it("goes on taking the old spot as Stale through guardPlacementSeconds, then judges it as any move", function()
			local check = placed()
			expect(check:sample("A", FROM, 0.25)).toBe("Stale")
			expect(check:sample("A", FROM, 1)).toBe("Stale")
			expect(check:sample("A", FROM, 1.25)).toBe("Return")
		end)

		it("judges a move the allowance covers as Ok, even near the old spot", function()
			local check = MovementCheck.new(movement, network)
			check:place("A", Vector3.new(10, 0, 0), Vector3.zero, 0)
			expect(check:sample("A", Vector3.new(5, 0, 0), 0.25)).toBe("Ok")
			expect(check:lastValid("A")).toEqual(Vector3.new(5, 0, 0))
		end)

		it("reaches as far from the old spot as guardPlacementSeconds of skating, counting only the rise", function()
			local half = Fixtures.config({ Network = { guardPlacementSeconds = 0.5 } }).Network
			-- Half a second at the 145.2 limit: 72.6 studs.
			expect(placed(half):sample("A", FROM + Vector3.new(72, 0, 0), 0.25)).toBe("Stale")
			expect(placed(half):sample("A", FROM + Vector3.new(73, 0, 0), 0.25)).toBe("Return")
			-- Exactly as far, 121 × 1.25 × 0.5 = 75.625 studs, which floats hold exactly.
			local exact = Fixtures.config({ Network = { guardPlacementSeconds = 0.5, speedTolerance = 1.25 } }).Network
			expect(placed(exact):sample("A", FROM + Vector3.new(75.625, 0, 0), 0.25)).toBe("Stale")
			-- A client's copy falling from where the character stood: falling is legal.
			expect(placed(half):sample("A", FROM + Vector3.new(0, -100, 50), 0.25)).toBe("Stale")
			local check = placed(half)
			expect(check:sample("A", FROM, 0.5)).toBe("Stale")
			expect(check:sample("A", FROM, 0.75)).toBe("Return")
		end)
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
			jumpHeld = false,
			draftAccel = 0,
			knockdown = nil,
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
