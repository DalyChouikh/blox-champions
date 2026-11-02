--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Throw = require(ReplicatedStorage.Shared.Actions.Throw)
local Trajectory = require(ReplicatedStorage.Shared.Ball.Trajectory)

local config = Config.defaults()
local actions = config.Actions
local throw = actions.ChargeThrow.throw :: Config.ThrowSettings
local pass = actions.Pass.pass :: Config.PassSettings
local GRAVITY = Config.gravity(config)
local MIN, MAX, SHARE = throw.minSpeed, throw.maxSpeed, throw.inheritCarrierVelocity

-- The worked examples' own settings (#342's and #346's, worked apart from the code): the shipped ones when they were
-- worked, held here so a tuning of the shipped config cannot break them (#350).
local WORKED: Config.ThrowSettings = table.clone(throw)
WORKED.minSpeed, WORKED.maxSpeed, WORKED.inheritCarrierVelocity, WORKED.exactSeconds = 90, 240, 0.5, 0.8
local WORKED_PASS: Config.PassSettings = table.clone(pass)
WORKED_PASS.speed, WORKED_PASS.aimHeight = 150, 1.5
local WORKED_GRAVITY = Vector3.new(0, -130.8, 0)

-- Where a throw from `from` at `velocity` is once it has covered `across` studs at right angles to gravity.
local function whereAcross(from: Vector3, velocity: Vector3, across: number): Vector3
	return Fixtures.flightAcross(from, velocity, GRAVITY, across)
end

describe("Throw", function()
	-- One rule for the charge a held throw key gives (#312): the client's request, the server's cap, the crosshair.
	it("charges a share of a full charge by how long the throw key is held, up to a full one", function()
		local full = throw.chargeMaxSeconds
		expect(Throw.share(throw, 0)).toBe(0)
		expect(Throw.share(throw, full / 4)).toBeCloseTo(0.25, 6)
		expect(Throw.share(throw, full)).toBe(1)
		expect(Throw.share(throw, 6 * full)).toBe(1)
	end)

	it("leaves the hand faster the longer the charge, from minSpeed to maxSpeed", function()
		expect(Throw.speed(throw, 0)).toBe(MIN)
		expect(Throw.speed(throw, 1)).toBe(MAX)
		expect(Throw.speed(throw, 0.5)).toBeCloseTo((MIN + MAX) / 2, 6)
		-- A charge outside 0..1 counts as the nearest end.
		expect(Throw.speed(throw, 2)).toBe(MAX)
		expect(Throw.speed(throw, -1)).toBe(MIN)
	end)

	-- A Magnetic Pass flies straight at its steady 150 studs/s (#346, the owner's trial: Q175, Q176) to where its
	-- receiver's chest will be when it gets there (Homing.lead, Homing.aimOn; worked apart from the code by bisection).
	it("passes straight at the pass's speed to where the receiver's chest will be", function()
		local aim = Vector3.new(2, 0, 0)
		local from = Vector3.new(5, 3, 5)
		local still = Vector3.zero
		Fixtures.expectNear(
			Throw.pass(WORKED_PASS, from, aim, from + Vector3.new(0, 0, -30), still),
			Vector3.new(0, 7.490643, -149.812851),
			1e-3
		)
		Fixtures.expectNear(
			Throw.pass(WORKED_PASS, from, aim, from + Vector3.new(30, 0, 40), still),
			Vector3.new(89.959527, 4.497976, 119.946036),
			1e-3
		)
		-- Skating across at 30: a steady pass that meets them crosses at their pace.
		Fixtures.expectNear(
			Throw.pass(WORKED_PASS, from, aim, from + Vector3.new(0, 0, -40), Vector3.new(30, 0, 0)),
			Vector3.new(30, 5.507481, -146.866156),
			1e-3
		)
		-- A receiver whose chest is right at the hand gives no direction: along the aim.
		local under = from - Vector3.new(0, pass.aimHeight, 0)
		Fixtures.expectNear(Throw.pass(pass, from, aim, under, still), Vector3.xAxis * pass.speed)
	end)

	-- Roll Ball (#312): the aim's way across the ground at the charge's speed, plus the carrier's share of their
	-- velocity along the ground. Aimed (3, 4, -4) on the flat: along (3, 0, -4) / 5 = (0.6, 0, -0.8).
	it("rolls the aim's way across the ground at the charge's speed, plus the carrier's share along it", function()
		local up, facing = Vector3.yAxis, -Vector3.zAxis
		local carrier = Vector3.new(10, 6, 0)
		local carried = Vector3.new(10, 0, 0) * SHARE
		local aim = Vector3.new(3, 4, -4)
		local way = Vector3.new(0.6, 0, -0.8)
		Fixtures.expectNear(Throw.rolled(throw, aim, 1, carrier, up, facing), way * MAX + carried)
		Fixtures.expectNear(Throw.rolled(throw, aim, 0.5, carrier, up, facing), way * (MIN + MAX) / 2 + carried)
		-- Aimed straight up (the camera under the skater) or down: along the facing.
		Fixtures.expectNear(Throw.rolled(throw, Vector3.new(0, 2, 0), 1, carrier, up, facing), facing * MAX + carried)
		Fixtures.expectNear(Throw.rolled(throw, Vector3.new(0, -1, 0), 0, carrier, up, facing), facing * MIN + carried)
		-- Riding up a wall whose face looks along +X: across that face, whatever leans into it.
		local wall = Vector3.xAxis
		Fixtures.expectNear(
			Throw.rolled(throw, Vector3.new(1, 0, -1), 1, Vector3.new(20, 30, 0), wall, Vector3.yAxis),
			Vector3.new(0, 30 * SHARE, -MAX)
		)
	end)

	-- Where the crosshair points (#313, the owner: Q148): its line from the camera ends at `finish`, where it first
	-- meets the arena; a line that passes through the goal ring's opening on the way aims at the ring's centre. The
	-- ring here hangs 50 studs out, facing the line, 7 studs across its opening's radius.
	it(
		"aims at where the crosshair's line meets the arena, or at the goal ring's centre when it passes through",
		function()
			local goal = { frame = CFrame.new(0, 20, -50), radius = 7 }
			local finish = Vector3.new(0, 20, -100)
			Fixtures.expectNear(Throw.spot(Vector3.new(0, 20, 0), finish, goal), goal.frame.Position)
			-- Through the opening off its centre (5 studs out): still the centre.
			Fixtures.expectNear(Throw.spot(Vector3.new(3, 24, 0), Vector3.new(3, 24, -100), goal), goal.frame.Position)
			-- Past the ring (10 studs out), short of it (a wall at 40), or with no ring: where the line ends.
			local above = Vector3.new(0, 30, -100)
			Fixtures.expectNear(Throw.spot(Vector3.new(0, 30, 0), above, goal), above)
			local wall = Vector3.new(0, 20, -40)
			Fixtures.expectNear(Throw.spot(Vector3.new(0, 20, 0), wall, goal), wall)
			Fixtures.expectNear(Throw.spot(Vector3.new(0, 20, 0), finish, nil), finish)
		end
	)

	-- A charged throw lands on the crosshair's spot (#313, the owner: Q148 on real gravity, Q151 kept it) when it gets
	-- there within exactSeconds of flight (#342, Q169): from the hand at the charge's speed, on the flatter of the two
	-- arcs through the spot. A floor spot 100 studs out, 3 below the hand, the crosshair's line coming down to it: a
	-- full charge gets there in 0.42 s, a half in 0.61.
	it("comes down on the spot from the hand on the flatter arc, at the charge's speed", function()
		local from, spot = Vector3.new(0, 3, 0), Vector3.new(0, 0, -100)
		local aim = Vector3.new(0, -0.05, -1)
		local full = Throw.aimed(throw, 1, from, aim, spot, Vector3.zero, GRAVITY)
		expect(full.Magnitude).toBeCloseTo(MAX, 3)
		Fixtures.expectNear(whereAcross(from, full, 100), spot, 1e-4)
		-- The flatter arc: under 45 degrees.
		expect(full.Y < -full.Z).toBe(true)
		local half = Throw.aimed(throw, 0.5, from, aim, spot, Vector3.zero, GRAVITY)
		expect(half.Magnitude).toBeCloseTo((MIN + MAX) / 2, 3)
		Fixtures.expectNear(whereAcross(from, half, 100), spot, 1e-4)
	end)

	-- Thrown on the move, the ball keeps the carrier's share of their velocity, and still lands on the spot.
	it("lands on the spot with the carrier's share of their velocity in the ball", function()
		local from, spot = Vector3.new(0, 3, 0), Vector3.new(0, 0, -100)
		local carrier = Vector3.new(20, 0, -10)
		local velocity = Throw.aimed(throw, 1, from, Vector3.new(0, -0.05, -1), spot, carrier, GRAVITY)
		expect((velocity - carrier * SHARE).Magnitude).toBeCloseTo(MAX, 3)
		Fixtures.expectNear(whereAcross(from, velocity, 100), spot, 1e-2)
	end)

	-- RC's throw is exact only so far (#342, Video 35: a goal ~0.85 s away went in dead centre, one far down a straight
	-- sank under the ring), so a spot it would get to after exactSeconds is not: the ball goes on the arc through the
	-- farthest point of the crosshair's line it reaches in exactSeconds and falls on past it (Q169-Q170). Worked apart
	-- from the code (earliest flight times by scanning, the farthest point by bisection): a full charge along a level
	-- line through the hand at a spot 260 out passes the line 187.3822 out at 0.8 s, leaving at (234.2277, 52.32, 0),
	-- and is 22.507 studs (3.85 body heights) under the spot when it gets there.
	it("falls under a spot it would reach only after exactSeconds, through the line's point it reaches then", function()
		local velocity =
			Throw.aimed(WORKED, 1, Vector3.zero, Vector3.xAxis, Vector3.new(260, 0, 0), Vector3.zero, WORKED_GRAVITY)
		Fixtures.expectNear(velocity, Vector3.new(234.2277, 52.32, 0), 1e-2)
		local onLine = Trajectory.positionAt(Vector3.zero, velocity, WORKED_GRAVITY, WORKED.exactSeconds)
		Fixtures.expectNear(onLine, Vector3.new(187.3822, 0, 0), 1e-2)
		local under = Fixtures.flightAcross(Vector3.zero, velocity, WORKED_GRAVITY, 260)
		expect(under.Y).toBeCloseTo(-22.507, 2)
	end)

	-- The aim still allows for the thrower's own motion (Q167): moving at (20, 0, -10), half of it in the ball, the
	-- same throw passes the line 195.3395 out at 0.8 s, leaving at (244.1743, 52.32, 0), 240 from the hand.
	it("still allows for the carrier's share of their velocity when it falls under a far spot", function()
		local carrier = Vector3.new(20, 0, -10)
		local velocity =
			Throw.aimed(WORKED, 1, Vector3.zero, Vector3.xAxis, Vector3.new(260, 0, 0), carrier, WORKED_GRAVITY)
		Fixtures.expectNear(velocity, Vector3.new(244.1743, 52.32, 0), 1e-2)
		expect((velocity - carrier * WORKED.inheritCarrierVelocity).Magnitude).toBeCloseTo(WORKED.maxSpeed, 3)
		local onLine = Trajectory.positionAt(Vector3.zero, velocity, WORKED_GRAVITY, WORKED.exactSeconds)
		Fixtures.expectNear(onLine, Vector3.new(195.3395, 0, 0), 1e-2)
	end)

	-- Out of the charge's reach, the farthest point of the crosshair's line it reaches within exactSeconds: on a level
	-- line 6 studs over the hand a tap at 90 under 130.8 could reach 55.60 studs out (where speed^2 = g (6 + r)), but
	-- only after 0.8 s: in 0.8 s it reaches 53.7941 out, leaving at (67.2426, 59.82, 0). The search pins the point
	-- within 500 / 65536 = 0.008 studs along the line, which turns this steep arc's launch by up to ~0.02 studs/s.
	it("goes as far along the crosshair's line as the charge reaches in time when the spot is out of reach", function()
		local farthest = Vector3.new(53.7941, 6, 0)
		local velocity =
			Throw.aimed(WORKED, 0, Vector3.zero, Vector3.xAxis, Vector3.new(500, 6, 0), Vector3.zero, WORKED_GRAVITY)
		expect(velocity.Magnitude).toBeCloseTo(WORKED.minSpeed, 3)
		Fixtures.expectNear(velocity, Vector3.new(67.2426, 59.82, 0), 0.03)
		Fixtures.expectNear(Fixtures.flightAcross(Vector3.zero, velocity, WORKED_GRAVITY, farthest.X), farthest, 0.05)
	end)

	-- A spot out of reach behind the hand along the line (the camera looking steeply down behind the skater) has no
	-- part of the line ahead to fall back on: the arc that needs the least speed toward it, tan = (0 + 500) / 500.
	it("throws at a spot out of reach behind the hand on the arc that needs the least speed", function()
		local velocity =
			Throw.aimed(throw, 0, Vector3.zero, Vector3.xAxis, Vector3.new(-500, 0, 0), Vector3.zero, GRAVITY)
		Fixtures.expectNear(velocity, Vector3.new(-1, 1, 0).Unit * MIN, 1e-3)
	end)
end)
