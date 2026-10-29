--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Reach = require(ReplicatedStorage.Shared.Actions.Reach)

local FACING = Vector3.new(0, 0, -1)
local tackle: Config.Hit = { range = 7, coneDeg = 50, aimUpDeg = 0, knockdownSeconds = 1.5 }

local function nearest(cone: Config.Cone, extra: number, candidates: { Reach.Candidate }): string?
	return Reach.nearest(Vector3.zero, FACING, Vector3.yAxis, cone, extra, candidates)
end

describe("Reach.nearest", function()
	it("reaches the nearest opponent within range and cone", function()
		local candidates: { Reach.Candidate } = {
			{ player = "Far", position = Vector3.new(0, 0, -6) },
			{ player = "Near", position = Vector3.new(0, 0, -3) },
			-- 5.1 studs away, 79° off the facing.
			{ player = "Wide", position = Vector3.new(5, 0, -1) },
		}
		expect(nearest(tackle, 0, candidates)).toBe("Near")
		expect(nearest(tackle, 0, { candidates[3] })).toBeNil()
	end)

	it("adds the lag tolerance to the range, and reaches nobody beyond it", function()
		local inside: { Reach.Candidate } = { { player = "In", position = Vector3.new(0, 0, -9.9) } }
		local outside: { Reach.Candidate } = { { player = "Out", position = Vector3.new(0, 0, -10.1) } }
		expect(nearest(tackle, 3, inside)).toBe("In")
		expect(nearest(tackle, 3, outside)).toBeNil()
		expect(nearest(tackle, 0, inside)).toBeNil()
	end)

	it("aims an uppercut up", function()
		local uppercut: Config.Hit = { range = 6, coneDeg = 60, aimUpDeg = 30, knockdownSeconds = 1.5 }
		-- 54° from the aim, which is 30° above the facing.
		local above: { Reach.Candidate } = { { player = "Above", position = Vector3.new(0, 5, -0.5) } }
		-- 150° from the aim, 4 studs away: inside the range.
		local behind: { Reach.Candidate } = { { player = "Behind", position = Vector3.new(0, 0, 4) } }
		expect(nearest(uppercut, 0, above)).toBe("Above")
		expect(nearest(uppercut, 0, behind)).toBeNil()
		-- The same point is outside a level tackle's cone.
		expect(nearest(tackle, 0, above)).toBeNil()
	end)

	it("takes any cone, not only a hit's: a strike's snap zone reaches a skater beside", function()
		local snap: Config.Cone = { range = 12, coneDeg = 90, aimUpDeg = 0 }
		-- 10 studs away, 89.4° off the facing.
		local beside: { Reach.Candidate } = { { player = "Beside", position = Vector3.new(10, 0, -0.1) } }
		expect(nearest(snap, 0, beside)).toBe("Beside")
		expect(nearest(tackle, 0, beside)).toBeNil()
	end)
end)

describe("Reach.inCone", function()
	it("says whether an offset lies within a cone's angle, whatever its range", function()
		local cone: Config.Cone = { range = 1, coneDeg = 45, aimUpDeg = 0 }
		-- 44.4° and 45.6° off the facing, both far past the range.
		expect(Reach.inCone(Vector3.new(9.8, 0, -10), FACING, Vector3.yAxis, cone)).toBe(true)
		expect(Reach.inCone(Vector3.new(10.2, 0, -10), FACING, Vector3.yAxis, cone)).toBe(false)
	end)

	it("aims a cone up by its aimUpDeg", function()
		local above: Config.Cone = { range = 1, coneDeg = 45, aimUpDeg = 90 }
		-- 44.4° and 45.6° from straight up.
		expect(Reach.inCone(Vector3.new(0, 10, -9.8), FACING, Vector3.yAxis, above)).toBe(true)
		expect(Reach.inCone(Vector3.new(0, 10, -10.2), FACING, Vector3.yAxis, above)).toBe(false)
	end)
end)

describe("Reach.strikable", function()
	it("lets a strike reach only an opponent on their feet who is not dodging", function()
		expect(Reach.strikable("Blue", "Orange", false, false)).toBe(true)
		-- A teammate, a player without a seat, a knocked-down opponent and a dodging one.
		expect(Reach.strikable("Blue", "Blue", false, false)).toBe(false)
		expect(Reach.strikable("Blue", nil, false, false)).toBe(false)
		expect(Reach.strikable("Blue", "Orange", true, false)).toBe(false)
		expect(Reach.strikable("Blue", "Orange", false, true)).toBe(false)
	end)
end)
