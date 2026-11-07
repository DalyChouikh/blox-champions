--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Crossing = require(ReplicatedStorage.Shared.Rules.Crossing)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local GoalEscape = require(ReplicatedStorage.Shared.Skate.GoalEscape)

-- A goal turned off the axes, so a push read in the wrong frame shows: its scoring disc's radius 9, the housing
-- round it 11 deep.
local FRAME = CFrame.new(40, 52, -20) * CFrame.Angles(0, math.rad(30), 0)
local DISC: Crossing.Disc = { frame = FRAME, radius = 9 }
local DEPTH = 11
local SETTINGS: Config.GoalEscapeSettings = { speed = 2, seconds = 0.5, push = 30 }
local DT = 0.1

-- A point in the tunnel's frame, in the world.
local function at(x: number, y: number, z: number): Vector3
	return FRAME * Vector3.new(x, y, z)
end

-- Steps a skater at `position` moving at `velocity` `steps` times; the pushes returned, in order (none: an empty list).
local function run(state: GoalEscape.State, position: Vector3, velocity: Vector3, steps: number): { Vector3 }
	local pushes: { Vector3 } = {}
	for _ = 1, steps do
		local push = GoalEscape.step(state, DISC, DEPTH, position, velocity, DT, SETTINGS)
		if push ~= nil then
			table.insert(pushes, push)
		end
	end
	return pushes
end

-- #423, the owner's Q339-Q340: anyone resting inside the goal's tunnel is pushed back out the way they came.
describe("GoalEscape", function()
	it("leaves a skater outside the tunnel be, however still", function()
		local state = GoalEscape.new()
		expect(#run(state, at(9.5, 0, 0), Vector3.zero, 20)).toBe(0)
		expect(#run(state, at(0, 0, 5.5), Vector3.zero, 20)).toBe(0)
		expect(#run(state, at(0, 0, -5.5), Vector3.zero, 20)).toBe(0)
	end)

	it("leaves a skater moving through the tunnel be", function()
		local state = GoalEscape.new()
		expect(#run(state, at(0, -8, 2), FRAME.LookVector * SETTINGS.speed, 20)).toBe(0)
	end)

	it("pushes a skater barely moving inside out of the face they are on once still for the time", function()
		local state = GoalEscape.new()
		local slow = FRAME.RightVector * (SETTINGS.speed * 0.9)
		-- Four steps of 0.1 s: 0.4 s, not yet.
		expect(#run(state, at(3, -8, 2), slow, 4)).toBe(0)
		local pushes = run(state, at(3, -8, 2), slow, 1)
		expect(#pushes).toBe(1)
		-- Along the disc's normal toward their side (+Z, the front), never across the disc.
		Fixtures.expectNear(pushes[1], FRAME.LookVector * -SETTINGS.push)
	end)

	it("pushes a skater on the back side out of the back", function()
		local state = GoalEscape.new()
		local pushes = run(state, at(0, -8, -2), Vector3.zero, 5)
		expect(#pushes).toBe(1)
		Fixtures.expectNear(pushes[1], FRAME.LookVector * SETTINGS.push)
	end)

	it("starts the time over when the skater moves on or leaves, and after a push", function()
		local state = GoalEscape.new()
		expect(#run(state, at(0, -8, 2), Vector3.zero, 4)).toBe(0)
		expect(#run(state, at(0, -8, 2), FRAME.LookVector * SETTINGS.speed, 1)).toBe(0)
		expect(#run(state, at(0, -8, 2), Vector3.zero, 4)).toBe(0)
		expect(#run(state, at(0, 0, 6), Vector3.zero, 1)).toBe(0)
		expect(#run(state, at(0, -8, 2), Vector3.zero, 4)).toBe(0)
		expect(#run(state, at(0, -8, 2), Vector3.zero, 1)).toBe(1)
		expect(#run(state, at(0, -8, 2), Vector3.zero, 4)).toBe(0)
	end)
end)
