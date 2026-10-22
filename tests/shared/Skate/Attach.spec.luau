--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Attach = require(ReplicatedStorage.Shared.Skate.Attach)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local SkateMath = require(ReplicatedStorage.Shared.Skate.SkateMath)

local movement = Config.defaults().Movement

local function candidate(player: string, position: Vector3, velocity: Vector3): Attach.Candidate
	return { player = player, position = position, velocity = velocity, forward = velocity.Unit }
end

local LEADER = candidate("A", Vector3.zero, Vector3.new(0, 0, -30))

describe("Attach", function()
	it("finds the nearest teammate the skater is right behind", function()
		local farther = candidate("B", Vector3.new(0, 0, -2), Vector3.new(0, 0, -30))
		local found = Attach.findLeader(movement, Vector3.new(0, 0, 6), { farther, LEADER }) :: Attach.Candidate
		expect(found.player).toBe("A")
		expect(Attach.findLeader(movement, Vector3.new(0, 0, 9), { LEADER })).toBeNil() -- beyond attachRange 8
		expect(Attach.findLeader(movement, Vector3.new(6, 0, 4), { LEADER })).toBeNil() -- 56.3° off the line behind
		expect(Attach.findLeader(movement, Vector3.new(0, 0, -6), { LEADER })).toBeNil() -- in front
	end)

	it("attaches while held and follows behind the leader", function()
		local attach = Attach.new(movement)
		expect(attach:update(1 / 60, true, LEADER)).toBe("Attached")
		expect(attach.leader).toBe("A")
		Fixtures.expectNear(Attach.target(movement, LEADER), Vector3.new(0, 0, 4))
		local s = SkateMath.new(movement, Fixtures.GRAVITY)
		s:follow(Attach.target(movement, LEADER), Vector3.new(0, 0, 6), LEADER.velocity, LEADER.forward)
		expect(s.mode).toBe("Attached")
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -50)) -- −30 plus attachSpring 10 × 2 studs short
		expect(attach:update(1 / 60, true, LEADER)).toBe("None")
	end)

	it("lets go with a boost along the leader's way when released, then cools down", function()
		local attach = Attach.new(movement)
		attach:update(1 / 60, true, LEADER)
		expect(attach:update(1 / 60, false, LEADER)).toBe("Released")
		expect(attach.leader).toBeNil()
		Fixtures.expectNear(attach.releaseDirection, Vector3.new(0, 0, -1))
		local s = SkateMath.new(movement, Fixtures.GRAVITY)
		s.velocity = Vector3.new(0, 0, -30)
		s:release(attach.releaseDirection)
		expect(s.mode).toBe("Airborne")
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -70))
		expect(attach:update(2.9, true, LEADER)).toBe("None") -- attachCooldown 3
		expect(attach:update(0.2, true, LEADER)).toBe("Attached")
	end)

	it("lets go after attachMaxSeconds even while held", function()
		local attach = Attach.new(movement)
		attach:update(1 / 60, true, LEADER)
		expect(attach:update(2.9, true, LEADER)).toBe("None")
		expect(attach:update(0.2, true, LEADER)).toBe("Released")
	end)

	it("lets go when the leader is gone", function()
		local attach = Attach.new(movement)
		attach:update(1 / 60, true, LEADER)
		expect(attach:update(1 / 60, true, nil)).toBe("Released")
		Fixtures.expectNear(attach.releaseDirection, Vector3.new(0, 0, -1))
	end)

	it("forgets its leader and its cooldown on reset, as every skater does at a kickoff", function()
		local attach = Attach.new(movement)
		attach:update(1 / 60, true, LEADER)
		expect(attach.leader).toBe("A")
		attach:reset()
		expect(attach.leader).toBe(nil)
		expect(attach:update(1 / 60, false, nil)).toBe("None")
		attach:update(1 / 60, true, LEADER)
		attach:update(1 / 60, false, nil)
		expect(attach.cooldownLeft > 0).toBe(true)
		attach:reset()
		expect(attach.cooldownLeft).toBe(0)
	end)
end)
