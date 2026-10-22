--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Reach = require(ReplicatedStorage.Shared.Actions.Reach)

local FACING = Vector3.new(0, 0, -1)
local tackle: Config.Hit = { range = 7, coneDeg = 50, aimUpDeg = 0, knockdownSeconds = 1.5 }

local function nearest(hit: Config.Hit, extra: number, candidates: { Reach.Candidate }): string?
	return Reach.nearest(Vector3.zero, FACING, Vector3.yAxis, hit, extra, candidates)
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
end)
