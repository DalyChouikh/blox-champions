--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Homing = require(ReplicatedStorage.Shared.Ball.Homing)

local config = Config.defaults()
local pass = config.Actions.Pass.pass :: Config.PassSettings
-- The server's catch reach: a root this close to the ball's centre catches it.
local REACH = config.Ball.pickupRadius + config.Network.pickupLagToleranceStuds
local DT = 1 / 60

describe("Homing.step", function()
	it("turns a pass toward its target at homingAccel", function()
		local velocity = Vector3.new(0, 0, -90)
		Fixtures.expectNear(
			Homing.step(Vector3.zero, velocity, Vector3.new(10, 0, 0), 60, 0.5),
			Vector3.new(30, 0, -90)
		)
		-- A ball already at its target keeps its velocity.
		Fixtures.expectNear(Homing.step(Vector3.zero, velocity, Vector3.zero, 60, 0.5), velocity)
	end)
end)

-- A pass leads its receiver (#315): it flies where they will be when it gets there, speeding up by its homing on the
-- way, so it reaches a teammate skating across. Worked examples by brute force (s60\worked315b.py).
describe("Homing.lead", function()
	it("meets a receiver skating across where they will be, the pass speeding up on its way", function()
		local run = Vector3.new(30, 0, 0)
		local target = Vector3.new(0, 0, -40)
		-- |(30 t, 0, -40)| = 100 t + 75 t^2 at t = 0.33028.
		Fixtures.expectNear(Homing.lead(Vector3.zero, 100, 150, target, run), Vector3.new(9.908309, 0, -40), 1e-3)
		-- Without homing, a straight shot: 100 t = |(30 t, 0, -40)| at t = (1600 / 9100)^0.5 = 0.41931.
		Fixtures.expectNear(Homing.lead(Vector3.zero, 100, 0, target, run), Vector3.new(12.579418, 0, -40), 1e-3)
		-- In three dimensions, from off the origin.
		local from = Vector3.new(5, 3, 5)
		Fixtures.expectNear(
			Homing.lead(from, 100, 150, from + Vector3.new(10, 5, -60), Vector3.new(-20, 10, 40)),
			from + Vector3.new(2.720329, 8.639835, -45.440658),
			1e-3
		)
	end)

	it("aims at a receiver standing still, and at one it could never catch", function()
		local target = Vector3.new(0, 0, -40)
		Fixtures.expectNear(Homing.lead(Vector3.zero, 100, 150, target, Vector3.zero), target, 1e-4)
		-- Skating away faster than a pass that never speeds up.
		Fixtures.expectNear(Homing.lead(Vector3.zero, 100, 0, target, Vector3.new(0, 0, -120)), target)
		-- Already at the receiver, however fast they go.
		Fixtures.expectNear(Homing.lead(target, 100, 150, target, Vector3.new(30, 0, 0)), target)
		Fixtures.expectNear(Homing.lead(target, 100, 150, target, Vector3.new(120, 0, 0)), target)
	end)

	-- The owner's trial (Q139): 100 studs/s and homing 150. Steered at the receiver's spot alone, a pass to a teammate
	-- 80 studs out skating across at 55 studs/s passed 25.6 studs from them (s60\lead315.py).
	it("brings a pass, straight and on time, to a teammate skating across, away or toward the passer", function()
		-- The first frame within the catch reach, from the brute-force flights of s60\wander315.py.
		local cases: { { start: Vector3, run: Vector3, frames: number } } = {
			{ start = Vector3.new(0, 0, -80), run = Vector3.new(55, 0, 0), frames = 33 },
			{ start = Vector3.new(0, 0, -40), run = Vector3.new(30, 0, 0), frames = 17 },
			{ start = Vector3.new(0, 0, -120), run = Vector3.new(38.9, 0, -38.9), frames = 54 },
			{ start = Vector3.new(0, 0, -80), run = Vector3.new(0, 0, 55), frames = 24 },
		}
		for _, case in cases do
			local ball, receiver = Vector3.zero, case.start
			local velocity = (Homing.lead(ball, pass.speed, pass.homingAccel, receiver, case.run) - ball).Unit
				* pass.speed
			local way = velocity.Unit
			local caught = 0
			-- How far the ball strays from the line it left on (0.04 studs at most in the worked flights).
			local wander = 0
			for frame = 1, 120 do
				local aimAt = Homing.lead(ball, velocity.Magnitude, pass.homingAccel, receiver, case.run)
				velocity = Homing.step(ball, velocity, aimAt, pass.homingAccel, DT)
				ball += velocity * DT
				receiver += case.run * DT
				wander = math.max(wander, (ball - way * ball:Dot(way)).Magnitude)
				if (receiver - ball).Magnitude <= REACH then
					caught = frame
					break
				end
			end
			expect(math.abs(caught - case.frames)).toBeLessThanOrEqual(1)
			expect(wander).toBeLessThan(0.1)
		end
	end)
end)
