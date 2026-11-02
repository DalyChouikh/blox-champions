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

-- A receiver skating at `before`, then from `at` seconds on at `after`.
local function skating(before: Vector3, after: Vector3?, at: number?): (number) -> Vector3
	return function(t: number): Vector3
		return if after ~= nil and t >= (at :: number) then after else before
	end
end

-- The chest (#346, Q175): straight up from the root, however the receiver leans.
describe("Homing.aimOn", function()
	it("aims a pass the given height straight above its receiver's root", function()
		Fixtures.expectNear(Homing.aimOn(Vector3.new(4, 2, -7), 1.5), Vector3.new(4, 3.5, -7))
		Fixtures.expectNear(Homing.aimOn(Vector3.new(4, 2, -7), 0), Vector3.new(4, 2, -7))
	end)
end)

-- A pass leads its receiver (#315) at its steady speed (#346): it flies where they will be when it gets there. Worked
-- by bisection apart from the code, independently of the closed form.
describe("Homing.lead", function()
	it("meets a receiver skating across where they will be", function()
		local run = Vector3.new(30, 0, 0)
		local target = Vector3.new(0, 0, -40)
		-- 150 t = |(30 t, 0, -40)| at t = (1600 / 21600)^0.5 = 0.27217.
		Fixtures.expectNear(Homing.lead(Vector3.zero, 150, target, run), Vector3.new(8.164966, 0, -40), 1e-3)
		-- Slower, later: 100 t = |(30 t, 0, -40)| at t = (1600 / 9100)^0.5 = 0.41931.
		Fixtures.expectNear(Homing.lead(Vector3.zero, 100, target, run), Vector3.new(12.579418, 0, -40), 1e-3)
		-- In three dimensions, from off the origin, the receiver coming back toward the passer.
		local from = Vector3.new(5, 3, 5)
		Fixtures.expectNear(
			Homing.lead(from, 150, from + Vector3.new(10, 5, -60), Vector3.new(-20, 10, 40)),
			from + Vector3.new(3.595551, 8.202225, -47.191102),
			1e-3
		)
	end)

	it("aims at a receiver standing still, and at one it could never catch", function()
		local target = Vector3.new(0, 0, -40)
		Fixtures.expectNear(Homing.lead(Vector3.zero, 150, target, Vector3.zero), target, 1e-4)
		-- Skating straight away faster than the pass, or exactly as fast.
		Fixtures.expectNear(Homing.lead(Vector3.zero, 100, target, Vector3.new(0, 0, -120)), target)
		Fixtures.expectNear(Homing.lead(Vector3.zero, 100, target, Vector3.new(0, 0, -100)), target)
		-- Already at the receiver, however fast they go.
		Fixtures.expectNear(Homing.lead(target, 150, target, Vector3.new(30, 0, 0)), target)
		Fixtures.expectNear(Homing.lead(target, 150, target, Vector3.new(200, 0, 0)), target)
	end)
end)

-- A pass turns toward where its receiver will be without speeding up (#346, Q175): at most turnAccel sideways, so
-- turnAccel / speed x dt radians a step, always at its speed (worked apart from the code).
describe("Homing.turn", function()
	it("turns a pass at most turnAccel sideways, at its steady speed", function()
		local heading = Vector3.new(0, 0, -150)
		-- A quarter turn off: turned 300 / 150 x 0.1 = 0.2 rad toward it.
		Fixtures.expectNear(
			Homing.turn(heading, Vector3.new(10, 0, 0), 150, 300, 0.1),
			Vector3.new(29.8004, 0, -147.009987),
			1e-3
		)
		-- 1.9 deg off, within this step's turn: straight at it.
		local toward = Vector3.new(1, 0, -30)
		Fixtures.expectNear(Homing.turn(heading, toward, 150, 300, 0.1), Vector3.new(4.997225, 0, -149.916736), 1e-3)
		-- A slower ball comes back to the pass's speed; a faster one too.
		Fixtures.expectNear(
			Homing.turn(Vector3.new(0, 0, -90), toward, 150, 300, 0.1),
			Vector3.new(4.997225, 0, -149.916736),
			1e-3
		)
		Fixtures.expectNear(
			Homing.turn(Vector3.new(0, 0, -240), toward, 150, 300, 0.1),
			Vector3.new(4.997225, 0, -149.916736),
			1e-3
		)
		-- No turning at all: straight on.
		Fixtures.expectNear(Homing.turn(heading, Vector3.new(10, 0, 0), 150, 0, 0.1), heading)
	end)

	it("keeps its heading with nowhere to turn, and takes the way with no heading", function()
		Fixtures.expectNear(Homing.turn(Vector3.new(0, 0, -90), Vector3.zero, 150, 300, 0.1), Vector3.new(0, 0, -150))
		Fixtures.expectNear(Homing.turn(Vector3.zero, Vector3.new(3, 0, -4), 150, 300, 0.1), Vector3.new(90, 0, -120))
	end)

	-- The owner's pick (Q175, Q176): a steady 150 studs/s turning at 300, aimed at the chest, caught 90% of passes over
	-- real receivers' paths. The first frame within the catch reach, from flights stepped apart from the code.
	it("brings a pass to a teammate skating across, away, toward or cutting, and not to one turning back", function()
		local cases: { { start: Vector3, run: (number) -> Vector3, frames: number? } } = {
			{ start = Vector3.new(0, 0, -80), run = skating(Vector3.new(55, 0, 0)), frames = 32 },
			{ start = Vector3.new(0, 0, -40), run = skating(Vector3.new(30, 0, 0)), frames = 14 },
			{ start = Vector3.new(0, 0, -120), run = skating(Vector3.new(38.9, 0, -38.9)), frames = 64 },
			{ start = Vector3.new(0, 0, -80), run = skating(Vector3.new(0, 0, 55)), frames = 22 },
			-- A quarter turn away 0.21 s into the flight: the pass turns after them.
			{
				start = Vector3.new(0, 0, -80),
				run = skating(Vector3.new(55, 0, 0), Vector3.new(0, 0, -55), 0.21),
				frames = 40,
			},
			-- Turning back 0.21 s in: it passes 19.7 studs from them.
			{ start = Vector3.new(0, 0, -80), run = skating(Vector3.new(55, 0, 0), Vector3.new(-55, 0, 0), 0.21) },
		}
		for _, case in cases do
			local ball, receiver = Vector3.zero, case.start
			local first = Homing.lead(ball, pass.speed, Homing.aimOn(receiver, pass.aimHeight), case.run(0))
			local velocity = (first - ball).Unit * pass.speed
			local caught: number? = nil
			for frame = 1, 150 do
				local t = frame * DT
				ball += velocity * DT
				receiver += case.run(t - DT) * DT
				if (receiver - ball).Magnitude <= REACH then
					caught = frame
					break
				end
				local meet = Homing.lead(ball, pass.speed, Homing.aimOn(receiver, pass.aimHeight), case.run(t))
				velocity = Homing.turn(velocity, meet - ball, pass.speed, pass.turnAccel, DT)
				expect(velocity.Magnitude).toBeCloseTo(pass.speed, 3)
			end
			if case.frames == nil then
				expect(caught).toBeNil()
			else
				expect(math.abs((caught or 0) - case.frames)).toBeLessThanOrEqual(1)
			end
		end
	end)
end)
