--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Draft = require(ReplicatedStorage.Shared.Skate.Draft)

local movement = Config.defaults().Movement
local LEADER: Draft.Source = { position = Vector3.zero, velocity = Vector3.new(0, 0, -60) }

describe("Draft.accel", function()
	it("pulls a skater in the cone behind another, more the closer they are", function()
		expect(Draft.accel(movement, Vector3.new(0, 0, 9), { LEADER })).toBeCloseTo(10, 4) -- 20 × (1 − 9/18)
		expect(Draft.accel(movement, Vector3.new(0, 0, 13.5), { LEADER })).toBeCloseTo(5, 4)
		local offAxis = 9 * Vector3.new(math.sin(math.rad(20)), 0, math.cos(math.rad(20)))
		expect(Draft.accel(movement, offAxis, { LEADER })).toBeCloseTo(10, 4)
	end)

	it("gives nothing outside the cone, out of range, in front, or behind someone standing still", function()
		local wide = 9 * Vector3.new(math.sin(math.rad(40)), 0, math.cos(math.rad(40)))
		expect(Draft.accel(movement, wide, { LEADER })).toBe(0)
		expect(Draft.accel(movement, Vector3.new(0, 0, 19), { LEADER })).toBe(0)
		expect(Draft.accel(movement, Vector3.new(0, 0, -9), { LEADER })).toBe(0)
		local still: Draft.Source = { position = Vector3.zero, velocity = Vector3.zero }
		expect(Draft.accel(movement, Vector3.new(0, 0, 9), { still })).toBe(0)
		expect(Draft.accel(movement, Vector3.zero, { LEADER })).toBe(0)
	end)

	it("uses the strongest pull when several skaters are ahead", function()
		local closer: Draft.Source = { position = Vector3.new(0, 0, 4.5), velocity = Vector3.new(0, 0, -60) }
		-- The closer one is 4.5 studs ahead: 20 × (1 − 4.5/18).
		expect(Draft.accel(movement, Vector3.new(0, 0, 9), { LEADER, closer })).toBeCloseTo(15, 4)
	end)
end)
