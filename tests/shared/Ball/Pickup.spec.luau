--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Pickup = require(ReplicatedStorage.Shared.Ball.Pickup)

local function always(_player: string): boolean
	return true
end

describe("Pickup candidate lists", function()
	it("refills a reused list in place, keeping its records", function()
		local list: { Pickup.Candidate } = {}
		Pickup.setCandidate(list, 1, "A", Vector3.zero)
		Pickup.setCandidate(list, 2, "B", Vector3.xAxis)
		local first = list[1]
		Pickup.setCandidate(list, 1, "C", Vector3.yAxis)
		Pickup.trimCandidates(list, 1)
		expect(#list).toBe(1)
		expect(list[1] == first).toBe(true)
		expect(list[1].player).toBe("C")
		expect(list[1].position).toEqual(Vector3.yAxis)
	end)
end)

describe("Pickup.choose", function()
	it("picks the nearest candidate within reach, counting the edge of the reach as in", function()
		local candidates: { Pickup.Candidate } = {
			{ player = "Far", position = Vector3.new(6, 0, 0) },
			{ player = "Near", position = Vector3.new(0, 3, 0) },
			{ player = "Out", position = Vector3.new(0, 0, 7.1) },
		}
		expect(Pickup.choose(Vector3.zero, candidates, 7, always)).toBe("Near")
		local edge: { Pickup.Candidate } = { { player = "Edge", position = Vector3.new(7, 0, 0) } }
		expect(Pickup.choose(Vector3.zero, edge, 7, always)).toBe("Edge")
		expect(Pickup.choose(Vector3.zero, { candidates[3] }, 7, always)).toBeNil()
	end)

	it("skips candidates the ball refuses and breaks a tie by order", function()
		local candidates: { Pickup.Candidate } = {
			{ player = "A", position = Vector3.new(2, 0, 0) },
			{ player = "B", position = Vector3.new(-2, 0, 0) },
		}
		expect(Pickup.choose(Vector3.zero, candidates, 7, always)).toBe("A")
		expect(Pickup.choose(Vector3.zero, candidates, 7, function(player: string): boolean
			return player ~= "A"
		end)).toBe("B")
	end)
end)
