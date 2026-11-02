--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local DropIn = require(ReplicatedStorage.Shared.Ball.DropIn)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

local config = Fixtures.config()
local arena = config.Arena
local ball = config.Ball
local dropIn = ball.dropIn
-- The glass's top (120) less its lip (12) and the ball's width (3).
local HEIGHT = 105
-- Halfway along the top straight (heading -X at z -60) and round the left curved end (centred on x -100, heading
-- +Z at its apex).
local MID_STRAIGHT = 100
local APEX = arena.straightLength + math.pi * arena.endRadius / 2

describe("DropIn", function()
	-- The owner (Q112, Q113, #321): from just under the glass's lip, on a line by the outer wall or the middle glass.
	it("starts a drop just under the lip, on the line by the outer wall or the middle glass", function()
		-- The middle glass's face lies 40 inside the centerline, the outer wall's 40 outside: 6 and 8 studs in.
		Fixtures.expectNear(DropIn.start(arena, ball, MID_STRAIGHT, false), Vector3.new(0, HEIGHT, -26))
		Fixtures.expectNear(DropIn.start(arena, ball, MID_STRAIGHT, true), Vector3.new(0, HEIGHT, -92))
		Fixtures.expectNear(DropIn.start(arena, ball, APEX, false), Vector3.new(-126, HEIGHT, 0))
		Fixtures.expectNear(DropIn.start(arena, ball, APEX, true), Vector3.new(-192, HEIGHT, 0))
	end)

	-- Q112: a new random spot every time, anywhere round the loop, half by each wall.
	it("picks each start anywhere round the loop, on either line alike", function()
		local random = Random.new(321)
		local outerLateral = arena.trackWidth - dropIn.outerIn
		local sides = { inner = 0, outer = 0 }
		-- Per section: the top straight, the left curved end, the bottom straight, the right curved end.
		local sections = { 0, 0, 0, 0 }
		local distances: { [number]: boolean } = {}
		local distinct = 0
		for _ = 1, 400 do
			local start = DropIn.pick(arena, ball, random)
			local distance = Centerline.distanceOf(arena, start)
			local inner = (Centerline.pose(arena, distance, dropIn.innerIn, HEIGHT) - start).Magnitude < 1e-3
			local outer = (Centerline.pose(arena, distance, outerLateral, HEIGHT) - start).Magnitude < 1e-3
			expect(inner ~= outer).toBe(true)
			if inner then
				sides.inner += 1
			else
				sides.outer += 1
			end
			local section = 1
			for gate = 2, Centerline.gateCount do
				if distance >= Centerline.gateDistance(arena, gate) then
					section = gate
				end
			end
			sections[section] += 1
			if not distances[distance] then
				distances[distance] = true
				distinct += 1
			end
		end
		-- Half each way within 5 standard deviations (10 at 400 picks); every section about its share of the loop.
		expect(math.abs(sides.inner - 200) <= 50).toBe(true)
		for _, count in sections do
			expect(count >= 60).toBe(true)
		end
		expect(distinct).toBe(400)
	end)

	-- Q114, Q116: falling steadily while moving the lap's way along the track's curve, whatever the height or lane.
	it("holds the lap's way along the track where the ball is, and a steady fall", function()
		Fixtures.expectNear(
			DropIn.velocity(arena, ball, Vector3.new(0, HEIGHT, -26)),
			Vector3.new(-dropIn.speed, -dropIn.descent, 0)
		)
		Fixtures.expectNear(
			DropIn.velocity(arena, ball, Vector3.new(0, 10, -92)),
			Vector3.new(-dropIn.speed, -dropIn.descent, 0)
		)
		Fixtures.expectNear(
			DropIn.velocity(arena, ball, Vector3.new(-126, 60, 0)),
			Vector3.new(0, -dropIn.descent, dropIn.speed)
		)
		-- The bottom straight, back the other way.
		Fixtures.expectNear(
			DropIn.velocity(arena, ball, Vector3.new(0, 50, 70)),
			Vector3.new(dropIn.speed, -dropIn.descent, 0)
		)
	end)
end)
