--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local BallService = require(game:GetService("ServerScriptService").Server.BallService)
local BallSkins = require(ReplicatedStorage.Shared.Skins.BallSkins)
local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local DropIn = require(ReplicatedStorage.Shared.Ball.DropIn)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Homing = require(ReplicatedStorage.Shared.Ball.Homing)
local Look = require(ReplicatedStorage.Shared.Ball.Look)
local MovementCheck = require(ReplicatedStorage.Shared.Skate.MovementCheck)
local Profile = require(ReplicatedStorage.Shared.Arena.Geometry.Profile)
local SkaterBody = require(game:GetService("ServerScriptService").Server.SkaterBody)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local config = Fixtures.config()
local OUTSIDE = Fixtures.outsideArena(config)
-- How long a loose ball rests on something nobody skates before it respawns (#308).
local STRANDED = config.Ball.strandedSeconds
-- The middle of the top straight at a standing root's height, well inside the arena: where tests catch the ball (a
-- drop-in starts high beside a wall, #321) or rest it.
local ON_TRACK = Vector3.new(0, 3, -60)
-- How far from a skater's middle the server hands them a loose ball (#311): the magnet plus the lag tolerance.
local REACH = config.Ball.pickupRadius + config.Network.pickupLagToleranceStuds
-- A Magnetic Pass: its steady speed, its turn, where it aims and where it leaves (#346, the owner's trial: Q176).
local PASS = config.Actions.Pass.pass :: Config.PassSettings
-- The fastest a throw ever leaves the hand: a full charge plus its share of the carrier's speed, which the movement
-- guard holds to its limit.
local THROW = config.Actions.ChargeThrow.throw :: Config.ThrowSettings
local FASTEST_THROW = THROW.maxSpeed
	+ THROW.inheritCarrierVelocity * MovementCheck.speedLimit(config.Movement, config.Network)

local folder: Folder
-- The arena's parts in a test: what a resting ball lies on (#308) and what no ball may pass through (#311). The rigs
-- stand outside it, in `folder`, as characters stand outside the real arena.
local arena: Folder
-- The server's time the ball's states carry (#316).
local serverNow = 0
beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "BallServiceTest"
	folder.Parent = workspace
	arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = folder
	serverNow = 0
	-- The drops' spots repeat (#321).
	BallService:init({
		Config = config,
		ArenaService = { model = arena },
		BallLook = Fixtures.ballLook(config),
		Random = Random.new(1),
		ServerClock = function(): number
			return serverNow
		end,
	})
end)
afterEach(function()
	BallService:destroy()
	folder:Destroy()
end)

-- The name of the ball's model's parent. Assertions compare names: Jest prints a failing Instance with all its
-- descendants, which for the workspace can take minutes.
local function ballAt(): string?
	local parent = BallService.model.Parent
	return if parent ~= nil then parent.Name else nil
end

-- A holder who can catch, unless `canCatch` is false (knocked down).
local function holder(name: string, rig: Model, canCatch: boolean?): BallService.Holder
	return {
		player = name,
		root = Fixtures.root(rig),
		canCatch = canCatch ~= false,
	}
end

-- Whether the ball's lift is on: a pass, or a drop (#321), flies with its weight cancelled.
local function weightless(): boolean
	local lift = BallService.part:FindFirstChildOfClass("VectorForce")
	if lift then
		return lift.Enabled
	end
	return false
end

-- Whether a drop starts at `position`: just under the lip, on the line by either wall (#321).
local function isDropInStart(position: Vector3): boolean
	local distance = Centerline.distanceOf(config.Arena, position)
	for _, outer in { false, true } do
		if (DropIn.start(config.Arena, config.Ball, distance, outer) - position).Magnitude < 1e-3 then
			return true
		end
	end
	return false
end

-- A slab of the arena just under a ball resting still at `position`: a ride surface (a part in a folder tagged
-- RideSurface, as the floors are) or not (as the goal's rim is, #308).
local function slabUnder(position: Vector3, rideSurface: boolean): Part
	local parent: Instance = arena
	if rideSurface then
		parent = Instance.new("Folder")
		parent:AddTag(Tags.RideSurface)
		parent.Parent = arena
	end
	local slab = Instance.new("Part")
	slab.Anchored = true
	slab.Size = Vector3.new(8, 1, 8)
	slab.CFrame = CFrame.new(position - Vector3.new(0, config.Ball.radius + 0.5, 0))
	slab.Parent = parent
	return slab
end

-- Spawns the ball and rests it still at ON_TRACK on a slab it has touched: a ride surface or not (#308).
local function spawnResting(rideSurface: boolean): Part
	BallService:spawn()
	BallService.part.CFrame = CFrame.new(ON_TRACK)
	BallService.part.AssemblyLinearVelocity = Vector3.zero
	local slab = slabUnder(ON_TRACK, rideSurface)
	BallService:onTouched(slab)
	return slab
end

-- Steps the ball a second at a time for `seconds`; true if it respawned on any step.
local function respawnsWithin(seconds: number, holders: { BallService.Holder }?): boolean
	local respawned = false
	for _ = 1, seconds do
		respawned = BallService:step(1, holders or {}).respawned or respawned
	end
	return respawned
end

-- Spawns the ball and has a rig standing on the track catch it there.
local function caughtBy(name: string): Model
	BallService:spawn()
	BallService.part.CFrame = CFrame.new(ON_TRACK)
	local rig = Fixtures.rig(folder, name, CFrame.new(ON_TRACK))
	BallService:step(1 / 60, { holder(name, rig) })
	return rig
end

describe("BallService", function()
	it("makes a ball of the configured size, physics and skin, hidden until it spawns", function()
		local ball = BallService.part
		expect(ball.Shape).toBe(Enum.PartType.Ball)
		expect(ball.Size).toEqual(Vector3.one * (2 * config.Ball.radius))
		local physics = ball.CustomPhysicalProperties :: PhysicalProperties
		expect(physics.Density).toBeCloseTo(0.7, 4)
		expect(physics.Friction).toBeCloseTo(0.3, 4)
		expect(physics.Elasticity).toBeCloseTo(0.5, 4)
		-- #400: drawn by its look in the Default skin (BallLook); the part itself, which bounces and rolls, unseen.
		local look = Look.of(ball) :: BasePart
		expect(look.Color).toEqual(BallSkins.get(BallSkins.DEFAULT).color)
		expect(look:FindFirstChildOfClass("SurfaceAppearance")).never.toBeNil()
		expect(ball.Transparency).toBe(1)
		expect(ballAt()).toBe("ServerStorage")
		expect(BallService.state.status).toBe("Dead")
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
	end)

	it("tags its ball part so clients can find it", function()
		expect(CollectionService:HasTag(BallService.part, Tags.Ball)).toBe(true)
	end)

	it("spawns the ball loose at a drop's start and reports only real movement", function()
		BallService:spawn()
		local ball = BallService.part
		expect(ballAt()).toBe("Workspace")
		expect(isDropInStart(ball.Position)).toBe(true)
		expect(BallService.state.status).toBe("Loose")
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
		local start = ball.Position
		ball.CFrame = CFrame.new(start + Vector3.new(4, 0, 0))
		local frame = BallService:step(1 / 60, {})
		expect(frame.moved).toBe(true)
		Fixtures.expectNear(frame.from, start)
		Fixtures.expectNear(frame.to, start + Vector3.new(4, 0, 0))
	end)

	-- The owner (Q111-Q116, #321): Roller Champions' drop from above, as trialled.
	it("drops the ball in falling steadily the lap's way, weightless, until it first touches the arena", function()
		BallService:spawn()
		local ball = BallService.part
		local dropIn = config.Ball.dropIn
		Fixtures.expectNear(ball.AssemblyLinearVelocity, DropIn.velocity(config.Arena, config.Ball, ball.Position))
		expect(weightless()).toBe(true)
		-- Wherever it has fallen to, it holds the drop's way there: at the left curved end's apex, by the middle glass
		-- (26 out from the end's axis at x -straightLength / 2), +Z.
		ball.CFrame = CFrame.new(-config.Arena.straightLength / 2 - 26, 60, 0)
		BallService:step(1 / 60, {})
		Fixtures.expectNear(ball.AssemblyLinearVelocity, Vector3.new(0, -dropIn.descent, dropIn.speed))
		local floor = Instance.new("Part")
		floor.Parent = folder
		BallService:onTouched(floor)
		expect(weightless()).toBe(false)
		ball.AssemblyLinearVelocity = Vector3.new(5, 0, 0)
		BallService:step(1 / 60, {})
		Fixtures.expectNear(ball.AssemblyLinearVelocity, Vector3.new(5, 0, 0))
	end)

	it("ends a drop when it touches a body, is caught, or play stops for a point or a kickoff", function()
		BallService:spawn()
		local down = Fixtures.rig(folder, "B", CFrame.new(BallService.part.Position + Vector3.new(2, 0, 0)))
		expect(BallService:step(1 / 60, { holder("B", down, false) }).toucher).toBe("B")
		expect(weightless()).toBe(false)
		BallService:kill()
		BallService:spawn()
		local rig = Fixtures.rig(folder, "A", CFrame.new(BallService.part.Position))
		BallService:step(1 / 60, { holder("A", rig) })
		expect(BallService.state.carrier).toBe("A")
		expect(weightless()).toBe(false)
		BallService:kill()
		BallService:spawn()
		expect(weightless()).toBe(true)
		BallService:kill()
		expect(weightless()).toBe(false)
		BallService:spawn()
		BallService:hide()
		expect(weightless()).toBe(false)
	end)

	it("gives the ball to the nearest player in reach with its velocity from before the catch", function()
		BallService:spawn()
		BallService.part.CFrame = CFrame.new(ON_TRACK)
		local at = ON_TRACK
		BallService.part.AssemblyLinearVelocity = Vector3.new(20, 0, 0)
		local closest = Fixtures.rig(folder, "Near", CFrame.new(at + Vector3.new(3, 0, 0)))
		local farther = Fixtures.rig(folder, "Far", CFrame.new(at + Vector3.new(6, 0, 0)))
		local outside = Fixtures.rig(folder, "Out", CFrame.new(at + Vector3.new(0, 0, REACH + 0.5)))
		local frame =
			BallService:step(1 / 60, { holder("Far", farther), holder("Near", closest), holder("Out", outside) })
		expect(frame.picker).toBe("Near")
		Fixtures.expectNear(frame.pickupPosition, at)
		Fixtures.expectNear(frame.pickupVelocity, Vector3.new(20, 0, 0))
		expect(BallService.state.carrier).toBe("Near")
		expect(BallService.part.CanCollide).toBe(false)
		expect(BallService.part.CanTouch).toBe(false)
		expect(BallService.part.Massless).toBe(true)
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
		closest:PivotTo(closest:GetPivot() + Vector3.new(10, 0, 0))
		local root = Fixtures.root(closest)
		Fixtures.expectNear(BallService.part.Position, root.CFrame * config.Ball.carryOffset)
	end)

	-- MovementGuard's two moves of a carrier (Phase 9 review): neither may count as the ball crossing a gate.
	it("reports no movement for a carrier the server moved, the ball welded to them", function()
		local rig = caughtBy("A")
		BallService:step(1 / 60, {})
		rig:PivotTo(rig:GetPivot() + Vector3.new(0, 0, 40))
		BallService:jumped()
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
		expect(BallService.state.carrier).toBe("A")
		rig:PivotTo(rig:GetPivot() + Vector3.new(1, 0, 0))
		expect(BallService:step(1 / 60, {}).moved).toBe(true)
	end)

	it("drops a carried ball loose at a place, still and with no movement reported for the jump", function()
		local rig = caughtBy("A")
		BallService:step(1 / 60, {})
		local at = BallService.part.Position + Vector3.new(0, 0, -30)
		rig:PivotTo(rig:GetPivot() + Vector3.new(0, -50, 0))
		-- The carrier still moving: the ball must not keep their speed.
		Fixtures.root(rig).AssemblyLinearVelocity = Vector3.new(30, 0, 0)
		BallService:dropAt(at)
		expect(BallService.state.status).toBe("Loose")
		expect(BallService.state.carrier).toBe(nil)
		expect(BallService.part.CanCollide).toBe(true)
		Fixtures.expectNear(BallService.part.Position, at)
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.zero)
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
	end)

	it("carries the ball in the carrier's hand, clear of the floor they hover over", function()
		local rig = caughtBy("A")
		expect(BallService.state.carrier).toBe("A")
		local floor = Fixtures.root(rig).Position.Y - config.Movement.hoverHeight
		expect(BallService.part.Position.Y - config.Ball.radius > floor).toBe(true)
	end)

	it("keeps the thrower from catching their own throw, and reports the throw once", function()
		local rig = caughtBy("A")
		BallService:throw("A", Vector3.new(0, 0, 30))
		expect(BallService.state.status).toBe("Flying")
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.new(0, 0, 30))
		expect(BallService.part.CanCollide).toBe(true)
		local frame = BallService:step(1 / 60, { holder("A", rig) })
		expect(frame.thrower).toBe("A")
		expect(frame.picker).toBeNil()
		expect(BallService:step(1 / 60, { holder("A", rig) }).thrower).toBeNil()
		expect(BallService:step(0.4, { holder("A", rig) }).picker).toBe("A")
		expect(function()
			BallService:throw("B", Vector3.zero)
		end).toThrow("BallService: only the carrier can throw (carrier: A, thrower: B)")
	end)

	-- The ball's trail on every screen (#313) follows this mark: from a throw, a pass or a roll (all let go through
	-- `throw`) until the next catch, drop-in, kill or hide. Landing does not end it: a rolled ball lands at once.
	it("marks the ball thrown from a throw, a pass or a roll until a catch, drop-in, kill or hide", function()
		local part = BallService.part
		-- The mark as the server left it: true, or absent (never false).
		local function thrown(): unknown
			return part:GetAttribute(Attributes.Thrown)
		end
		local rig = caughtBy("A")
		local function catch()
			part.CFrame = CFrame.new(ON_TRACK)
			BallService:jumped()
			BallService:step(1 / 60, {})
			BallService:step(config.Ball.rethrowPickupDelay, { holder("A", rig) })
			expect(BallService.state.carrier).toBe("A")
		end
		expect(thrown()).toBeNil()
		BallService:throw("A", Vector3.new(0, 0, 30))
		expect(thrown()).toBe(true)
		BallService:onTouched(slabUnder(ON_TRACK, true))
		expect(BallService.state.status).toBe("Loose")
		expect(thrown()).toBe(true)
		catch()
		expect(thrown()).toBeNil()
		BallService:pass("A", Vector3.new(0, 0, 30), "B")
		expect(thrown()).toBe(true)
		BallService:spawn()
		expect(thrown()).toBeNil()
		catch()
		BallService:roll("A", Vector3.new(0, 0, 30))
		expect(thrown()).toBe(true)
		BallService:kill()
		expect(thrown()).toBeNil()
		BallService:spawn()
		catch()
		BallService:throw("A", Vector3.new(0, 0, 30))
		BallService:hide()
		expect(thrown()).toBeNil()
	end)

	-- Roll Ball (#312): a throw along the floor. It leaves from the floor under the hand (the hand's spot across the
	-- root's frame, a radius above the floor the root hovers over), already rolling: its bottom, on the floor, still.
	it("rolls a carried ball from the floor under the hand, spinning as it rolls, as a jump the server made", function()
		local rig = caughtBy("A")
		-- The catch's own jump is spent first: the roll must mark its own.
		BallService:step(1 / 60, {})
		-- Turned a quarter left: the root's right is world -Z, its back world +X.
		rig:PivotTo(CFrame.new(ON_TRACK) * CFrame.Angles(0, math.rad(90), 0))
		local velocity = Vector3.new(-30, 0, 0)
		BallService:roll("A", velocity)
		expect(BallService.state.status).toBe("Flying")
		expect(BallService.state.carrier).toBeNil()
		expect(BallService.part.CanCollide).toBe(true)
		local ball, offset = config.Ball, config.Ball.carryOffset
		local floor = ball.radius - config.Movement.hoverHeight
		Fixtures.expectNear(BallService.part.Position, ON_TRACK + Vector3.new(offset.Z, floor, -offset.X))
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, velocity)
		local spin = BallService.part.AssemblyAngularVelocity
		Fixtures.expectNear(velocity + spin:Cross(-Vector3.yAxis * ball.radius), Vector3.zero)
		local frame = BallService:step(1 / 60, { holder("A", rig) })
		expect(frame.moved).toBe(false)
		expect(frame.thrower).toBe("A")
		expect(function()
			BallService:roll("B", velocity)
		end).toThrow("BallService: only the carrier can throw (carrier: none, thrower: B)")
	end)

	-- On a bank, 30 deg about the track's line: the floor under the hand lies along the root's own up (its right is
	-- (cos 30, sin 30, 0), its up (-sin 30, cos 30, 0)), and the ball rolls on that floor.
	it("rolls along a banked floor from under the hand, spinning about that floor", function()
		local rig = caughtBy("A")
		local bank = math.rad(30)
		rig:PivotTo(CFrame.new(ON_TRACK) * CFrame.Angles(0, 0, bank))
		local right = Vector3.new(math.cos(bank), math.sin(bank), 0)
		local up = Vector3.new(-math.sin(bank), math.cos(bank), 0)
		-- Along the bank's line.
		local velocity = Vector3.new(0, 0, -30)
		BallService:roll("A", velocity)
		local ball, offset = config.Ball, config.Ball.carryOffset
		local floor = ball.radius - config.Movement.hoverHeight
		local spot = ON_TRACK + right * offset.X + up * floor + Vector3.zAxis * offset.Z
		Fixtures.expectNear(BallService.part.Position, spot)
		local spin = BallService.part.AssemblyAngularVelocity
		Fixtures.expectNear(velocity + spin:Cross(-up * ball.radius), Vector3.zero)
	end)

	-- The playtest's finding (#345, Q172): a carrier just landed on a slope leans less than it, so the hand on its
	-- uphill side dips into the floor, and a ball let go from there touched the arena at once (a pass dropped dead).
	-- Here an upright carrier over a slope rising to their right at the rise's steepest, 38 deg, where the server saw
	-- the hand 0.7 into it: the ball leaves from where it would first touch the slope on the way from the root to the
	-- hand, Ball.releaseClearance off it.
	local SLOPE_DEG = 38

	-- Catches the ball, then puts a slope under the carrier, rising into their hand: the rig, a point of the slope's
	-- face (the floor under the root) and its normal.
	local function leaningIntoSlope(): (Model, Vector3, Vector3)
		local rig = caughtBy("A")
		local root = Fixtures.root(rig).CFrame
		local under = root.Position - root.UpVector * config.Movement.hoverHeight
		local _, normal = Fixtures.slopeBeside(arena, root, under, SLOPE_DEG)
		return rig, under, normal
	end

	-- Where a ball let go toward `spot` from the rig's root starts, clear of the slope through `under`.
	local function clearOfSlope(rig: Model, spot: Vector3, under: Vector3, normal: Vector3): Vector3
		local meets = Fixtures.sphereMeetsPlane(Fixtures.root(rig).Position, spot, config.Ball.radius, under, normal)
		assert(meets ~= nil, "the spot should be in the slope")
		return meets + normal * config.Ball.releaseClearance
	end

	-- Whether the ball overlaps any part of the test's arena.
	local function inArena(): boolean
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { arena }
		return #workspace:GetPartsInPart(BallService.part, params) > 0
	end

	-- How far above the hand each way of letting go starts: a pass beside the chest (#346, Q175).
	local RISE: { [string]: number } = { throw = 0, pass = PASS.releaseHeight, drop = 0 }
	local LET_GO: { [string]: (velocity: Vector3) -> () } = {
		throw = function(velocity: Vector3)
			BallService:throw("A", velocity)
		end,
		pass = function(velocity: Vector3)
			BallService:pass("A", velocity, "B")
		end,
		drop = function(velocity: Vector3)
			BallService:drop(velocity)
		end,
	}
	for _, way in { "throw", "pass", "drop" } do
		it(
			`lets go of a ball from the nearest point toward its start in the arena that is clear of it: a {way}`,
			function()
				local rig, under, normal = leaningIntoSlope()
				local hand = BallService.part.Position
				expect(inArena()).toBe(true)
				local clear = clearOfSlope(rig, hand + Vector3.new(0, RISE[way], 0), under, normal)
				local velocity = Vector3.new(0, 10, -30)
				LET_GO[way](velocity)
				Fixtures.expectNear(BallService.part.Position, clear)
				Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, velocity)
				expect(inArena()).toBe(false)
			end
		)
	end

	-- Leaning with the slope (its up the slope's normal), the hand is as clear of it as of a flat floor.
	it("lets go of a ball whose hand is clear of the arena from the hand, over a slope or not", function()
		local rig = caughtBy("A")
		rig:PivotTo(Fixtures.root(rig).CFrame * CFrame.Angles(0, 0, math.rad(SLOPE_DEG)))
		local root = Fixtures.root(rig).CFrame
		Fixtures.slopeBeside(arena, root, root.Position - root.UpVector * config.Movement.hoverHeight, 0)
		local hand = root * config.Ball.carryOffset
		Fixtures.expectNear(BallService:releasePoint(), hand)
		BallService:throw("A", Vector3.new(0, 0, -30))
		Fixtures.expectNear(BallService.part.Position, hand)
		expect(inArena()).toBe(false)
	end)

	it("says where a carried ball will leave the hand: the hand, or the nearest clear point toward it", function()
		local rig, under, normal = leaningIntoSlope()
		local hand = BallService.part.Position
		Fixtures.expectNear(BallService:releasePoint(), clearOfSlope(rig, hand, under, normal))
		arena:ClearAllChildren()
		Fixtures.expectNear(BallService:releasePoint(), hand)
		-- Saying it lets nothing go.
		expect(BallService.state.carrier).toBe("A")
		Fixtures.expectNear(BallService.part.Position, hand)
		-- A ball nobody carries leaves nobody's hand: it is where it is.
		BallService:throw("A", Vector3.new(0, 0, -30))
		BallService.part.Position = ON_TRACK
		Fixtures.expectNear(BallService:releasePoint(), ON_TRACK)
	end)

	-- A pass leaves Actions.Pass.pass.releaseHeight above the hand (#346, Q175: beside the chest, so its line clears
	-- the floor), still in this slope: from the nearest point toward there that is clear of it.
	it("says where a pass will leave: releaseHeight above the hand, or the nearest clear point toward it", function()
		local rig, under, normal = leaningIntoSlope()
		local hand = BallService.part.Position
		local spot = hand + Vector3.new(0, PASS.releaseHeight, 0)
		Fixtures.expectNear(BallService:passPoint(), clearOfSlope(rig, spot, under, normal))
		arena:ClearAllChildren()
		Fixtures.expectNear(BallService:passPoint(), spot)
		Fixtures.expectNear(BallService:releasePoint(), hand)
		-- Saying it lets nothing go.
		expect(BallService.state.carrier).toBe("A")
		Fixtures.expectNear(BallService.part.Position, hand)
		BallService:pass("A", Vector3.new(0, 0, -30), "B")
		Fixtures.expectNear(BallService.part.Position, spot)
		-- A ball nobody carries leaves nobody's hand: it is where it is.
		BallService.part.Position = ON_TRACK
		Fixtures.expectNear(BallService:passPoint(), ON_TRACK)
	end)

	-- Roll Ball starts on the floor under the hand; on a slope the carrier leans into, on the slope, not in it.
	it("rolls a ball from a slope the carrier leans into: on it, not in it", function()
		local rig, under, normal = leaningIntoSlope()
		local root = Fixtures.root(rig).CFrame
		local ball, offset = config.Ball, config.Ball.carryOffset
		local spot = root * Vector3.new(offset.X, ball.radius - config.Movement.hoverHeight, offset.Z)
		local clear = clearOfSlope(rig, spot, under, normal)
		BallService:roll("A", Vector3.new(0, 0, -30))
		Fixtures.expectNear(BallService.part.Position, clear)
		expect(inArena()).toBe(false)
	end)

	it("respawns a ball that leaves the arena, without reporting the jump", function()
		BallService:spawn()
		BallService:step(1 / 60, {})
		BallService.part.CFrame = CFrame.new(OUTSIDE)
		local out = BallService:step(1 / 60, {})
		expect(out.moved).toBe(true)
		Fixtures.expectNear(out.to, OUTSIDE)
		expect(out.respawned).toBe(true)
		expect(isDropInStart(BallService.part.Position)).toBe(true)
		expect(weightless()).toBe(true)
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
		-- Found over the top (only a fault puts it there, R9): out at once, never flying on.
		BallService.part.CFrame = CFrame.new(0, Profile.topHeight(config.Arena) + 5, 57)
		expect(BallService:step(1 / 60, {}).respawned).toBe(true)
		expect(isDropInStart(BallService.part.Position)).toBe(true)
	end)

	-- The owner (Q93): no idle respawn; a loose ball stays where it rolls until someone picks it up.
	it("leaves a loose ball resting on a ride surface where it is, however long", function()
		spawnResting(true)
		expect(respawnsWithin(60)).toBe(false)
		Fixtures.expectNear(BallService.part.Position, ON_TRACK)
		expect(BallService.state.status).toBe("Loose")
	end)

	it("respawns a loose ball resting on something nobody skates, the whole wait again once it is back", function()
		local slab = spawnResting(false)
		expect(respawnsWithin(STRANDED - 1)).toBe(false)
		expect(BallService:step(1, {}).respawned).toBe(true)
		expect(isDropInStart(BallService.part.Position)).toBe(true)
		expect(BallService.state.status).toBe("Loose")
		-- It drops a moment, then comes to rest there again.
		BallService:step(1 / 60, {})
		BallService.part.CFrame = CFrame.new(ON_TRACK)
		BallService.part.AssemblyLinearVelocity = Vector3.zero
		BallService:onTouched(slab)
		expect(respawnsWithin(STRANDED - 1)).toBe(false)
		expect(BallService:step(1, {}).respawned).toBe(true)
	end)

	it("never respawns a ball rolling there, hanging still over it, or resting there in shorter spells", function()
		spawnResting(false)
		local ball = BallService.part
		-- Kept rolling (as a slope keeps a ball rolling against the rolling slow-down, #311).
		local respawned = false
		for _ = 1, 2 * STRANDED do
			ball.AssemblyLinearVelocity = Vector3.new(config.Ball.restSpeed, 0, 0)
			respawned = BallService:step(1, {}).respawned or respawned
		end
		expect(respawned).toBe(false)
		-- A ball's width over it, still (only for an instant at the top of a throw).
		ball.AssemblyLinearVelocity = Vector3.zero
		ball.CFrame = CFrame.new(ON_TRACK + Vector3.new(0, 2 * config.Ball.radius, 0))
		expect(respawnsWithin(2 * STRANDED)).toBe(false)
		-- Resting, rolling a moment, resting again: each spell short of the wait.
		ball.CFrame = CFrame.new(ON_TRACK)
		expect(respawnsWithin(STRANDED - 1)).toBe(false)
		ball.AssemblyLinearVelocity = Vector3.new(0, 0, 2 * config.Ball.restSpeed)
		expect(respawnsWithin(1)).toBe(false)
		ball.AssemblyLinearVelocity = Vector3.zero
		expect(respawnsWithin(STRANDED - 1)).toBe(false)
	end)

	it("lets a carrier stand still anywhere with the ball", function()
		spawnResting(false)
		local rig = Fixtures.rig(folder, "A", CFrame.new(ON_TRACK))
		BallService:step(1 / 60, { holder("A", rig) })
		expect(BallService.state.carrier).toBe("A")
		expect(respawnsWithin(2 * STRANDED, { holder("A", rig) })).toBe(false)
		expect(BallService.state.carrier).toBe("A")
	end)

	it("keeps the ball in its own model, sent whole to every client and never streamed out", function()
		BallService:spawn()
		expect(BallService.part.Parent == BallService.model).toBe(true)
		expect(BallService.model.ModelStreamingMode).toBe(Enum.ModelStreamingMode.Persistent)
	end)

	it("rebuilds the ball if Roblox destroys it, and puts it back in play", function()
		BallService:spawn()
		local old = BallService.part
		old:Destroy()
		local frame = BallService:step(1 / 60, {})
		expect(frame.respawned).toBe(true)
		expect(BallService.part).never.toBe(old)
		expect(BallService.part.Parent == BallService.model).toBe(true)
		-- Dressed like the first (#400).
		expect(Look.of(BallService.part)).never.toBeNil()
		expect(ballAt()).toBe("Workspace")
		expect(isDropInStart(BallService.part.Position)).toBe(true)
		expect(BallService.state.status).toBe("Loose")
	end)

	it("parks a dead ball that leaves the arena", function()
		BallService:spawn()
		BallService:kill()
		BallService:step(1 / 60, {})
		BallService.part.CFrame = CFrame.new(OUTSIDE)
		BallService:step(1 / 60, {})
		expect(ballAt()).toBe("ServerStorage")
	end)

	it("takes the ball back from a carrier who leaves the arena and puts it in play", function()
		local rig = caughtBy("A")
		rig:PivotTo(CFrame.new(OUTSIDE))
		local frame = BallService:step(1 / 60, { holder("A", rig) })
		expect(frame.respawned).toBe(true)
		expect(BallService.state.carrier).toBeNil()
		expect(BallService.state.status).toBe("Loose")
		expect(isDropInStart(BallService.part.Position)).toBe(true)
	end)

	it("drops the ball loose where its carrier is", function()
		local rig = caughtBy("A")
		local carriedAt = BallService.part.Position
		BallService:drop()
		expect(BallService.state.status).toBe("Loose")
		expect(BallService.state.carrier).toBeNil()
		expect(BallService.part.CanCollide).toBe(true)
		expect(BallService.part.CanTouch).toBe(true)
		rig:PivotTo(rig:GetPivot() + Vector3.new(10, 0, 0))
		Fixtures.expectNear(BallService.part.Position, carriedAt)
	end)

	it("drops the ball with the carrier's momentum", function()
		caughtBy("A")
		BallService:drop(Vector3.new(30, 0, 0))
		expect(BallService.state.status).toBe("Loose")
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.new(30, 0, 0))
	end)

	it("lets the ball pass through the player who let go of it until it is clear of them", function()
		local rig = caughtBy("A")
		SkaterBody.build(rig, config.Movement)
		local root = Fixtures.root(rig)
		local collider = rig:FindFirstChild(SkaterRig.collider) :: BasePart
		local touch = config.Ball.radius + config.Movement.colliderDiameter / 2 + config.Network.pickupLagToleranceStuds
		local function passesThroughA(): boolean
			local grace = BallService.part:FindFirstChildOfClass("NoCollisionConstraint")
			if grace then
				return grace.Enabled and grace.Part0 == BallService.part and grace.Part1 == collider
			end
			return false
		end
		local function ballAtDistance(distance: number)
			BallService.part.CFrame = CFrame.new(root.Position + Vector3.xAxis * distance)
			BallService:step(1 / 60, { holder("A", rig) })
		end
		-- Thrown across A's body: it leaves from A's side, inside touch distance.
		BallService:throw("A", Vector3.new(-90, 0, 0))
		expect(passesThroughA()).toBe(true)
		ballAtDistance(touch - 0.5)
		expect(passesThroughA()).toBe(true)
		-- Clear of A, it can hit A again (a rebound off a wall).
		ballAtDistance(touch + 0.5)
		expect(passesThroughA()).toBe(false)
		-- Caught again after the rethrow delay, then dropped: the same.
		BallService.part.CFrame = CFrame.new(root.Position)
		BallService:step(config.Ball.rethrowPickupDelay, { holder("A", rig) })
		expect(BallService.state.carrier).toBe("A")
		BallService:drop()
		expect(passesThroughA()).toBe(true)
	end)

	it("lets a released ball move no faster than the movement guard allows", function()
		local limit = config.Movement.hardCap * config.Network.speedTolerance
		local rig = caughtBy("A")
		local root = Fixtures.root(rig)
		-- The carrier's client sets its own assembly's velocity, the ball's included.
		root.AssemblyLinearVelocity = Vector3.new(10000, 0, 0)
		BallService:drop()
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.new(limit, 0, 0))
		-- A given velocity too.
		BallService.part.CFrame = CFrame.new(root.Position)
		BallService:step(1 / 60, { holder("A", rig) })
		expect(BallService.state.carrier).toBe("A")
		BallService:drop(Vector3.new(0, 0, -10000))
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.new(0, 0, -limit))
	end)

	-- A pass leads its receiver (#315) at its steady speed (#346, Q175): each step it turns toward where their chest
	-- will be when it gets there (Homing.lead), at most turnAccel sideways, from their velocity as their client
	-- reports it, held to what the movement guard allows.
	it("turns a pass at its steady speed toward where its target's chest will be when it gets there", function()
		local a = caughtBy("A")
		local b = Fixtures.rig(folder, "B", CFrame.new(BallService.part.Position + Vector3.new(20, 0, -30)))
		BallService:pass("A", Vector3.new(0, 0, -PASS.speed), "B")
		expect(BallService.state.status).toBe("Flying")
		local root = Fixtures.root(b)
		local up = Vector3.new(0, PASS.aimHeight, 0)
		-- The heading turned toward `toward` by at most turnAccel / speed x dt radians, at the pass's speed.
		local function turned(velocity: Vector3, toward: Vector3, dt: number): Vector3
			local heading = velocity.Unit
			local most = PASS.turnAccel / PASS.speed * dt
			if math.atan2(heading:Cross(toward).Magnitude, heading:Dot(toward)) <= most then
				return toward.Unit * PASS.speed
			end
			local side = (toward - heading * toward:Dot(heading)).Unit
			return (heading * math.cos(most) + side * math.sin(most)) * PASS.speed
		end
		-- Standing still, 33.7 deg off the heading: turned 0.2 rad toward their chest.
		local position = BallService.part.Position
		BallService:step(0.1, { holder("A", a), holder("B", b) })
		local first = turned(Vector3.new(0, 0, -PASS.speed), root.Position + up - position, 0.1)
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, first, 1e-3)
		local limit = MovementCheck.speedLimit(config.Movement, config.Network)
		for _, run in { Vector3.new(30, 0, 0), Vector3.new(10000, 0, 0) } do
			position = BallService.part.Position
			-- Slowed by anything, it still leads them at its own speed and comes back to it.
			local velocity = BallService.part.AssemblyLinearVelocity * 0.6
			BallService.part.AssemblyLinearVelocity = velocity
			root.AssemblyLinearVelocity = run
			local seen = run.Unit * math.min(run.Magnitude, limit)
			local meet = Homing.lead(position, PASS.speed, root.Position + up, seen)
			BallService:step(0.1, { holder("A", a), holder("B", b) })
			local now = BallService.part.AssemblyLinearVelocity
			Fixtures.expectNear(now, turned(velocity, meet - position, 0.1), 1e-3)
			expect(now.Magnitude).toBeCloseTo(PASS.speed, 3)
		end
	end)

	it("stops homing when the target can no longer catch", function()
		local a = caughtBy("A")
		local b = Fixtures.rig(folder, "B", CFrame.new(BallService.part.Position + Vector3.new(20, 0, -30)))
		BallService:pass("A", Vector3.new(0, 0, -90), "B")
		BallService:step(0.1, { holder("A", a), holder("B", b, false) })
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.new(0, 0, -90))
		-- For good: back on their feet, they are no longer homed on.
		BallService:step(0.1, { holder("A", a), holder("B", b) })
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.new(0, 0, -90))
	end)

	it("stops homing when its target is gone", function()
		local a = caughtBy("A")
		local b = Fixtures.rig(folder, "B", CFrame.new(BallService.part.Position + Vector3.new(20, 0, -30)))
		BallService:pass("A", Vector3.new(0, 0, -90), "B")
		BallService:step(0.1, { holder("A", a) })
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.new(0, 0, -90))
		-- For good: back among the holders, they are no longer homed on.
		BallService:step(0.1, { holder("A", a), holder("B", b) })
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.new(0, 0, -90))
	end)

	it("flies a pass flat against gravity until it lands, and a plain throw falls", function()
		local a = caughtBy("A")
		local b = Fixtures.rig(folder, "B", CFrame.new(Fixtures.root(a).Position + Vector3.new(0, 0, -100)))
		expect(weightless()).toBe(false)
		BallService:pass("A", Vector3.new(0, 0, -90), "B")
		expect(weightless()).toBe(true)
		-- As strong as the free ball's weight in the world's gravity (#279), upward, at its center (a welded massless
		-- part weighs 0 by GetMass).
		local lift = BallService.part:FindFirstChildOfClass("VectorForce") :: VectorForce
		Fixtures.expectNear(lift.Force, Vector3.new(0, BallService.part:GetMass() * config.World.gravity, 0))
		expect(lift.RelativeTo).toBe(Enum.ActuatorRelativeTo.World)
		expect(lift.ApplyAtCenterOfMass).toBe(true)
		BallService:step(1 / 60, { holder("A", a), holder("B", b) })
		expect(weightless()).toBe(true)
		local wall = Instance.new("Part")
		wall.Parent = folder
		BallService:onTouched(wall)
		expect(weightless()).toBe(false)
		-- A throw is not a pass.
		BallService.part.CFrame = CFrame.new(Fixtures.root(a).Position)
		BallService:step(config.Ball.rethrowPickupDelay, { holder("A", a) })
		expect(BallService.state.carrier).toBe("A")
		BallService:throw("A", Vector3.new(0, 0, -90))
		expect(weightless()).toBe(false)
	end)

	it("lets a pass fall once it is caught, touches a body, loses its receiver, or leaves play", function()
		local a = caughtBy("A")
		local aRoot = Fixtures.root(a)
		local b = Fixtures.rig(folder, "B", CFrame.new(aRoot.Position + Vector3.new(0, 0, -30)))
		local bRoot = Fixtures.root(b)
		local c = Fixtures.rig(folder, "C", CFrame.new(aRoot.Position + Vector3.new(0, 0, 30)))
		local cRoot = Fixtures.root(c)
		local function passFromA()
			BallService.part.CFrame = CFrame.new(aRoot.Position)
			BallService:step(config.Ball.rethrowPickupDelay, { holder("A", a) })
			assert(BallService.state.carrier == "A", "A should carry the ball")
			BallService:pass("A", Vector3.new(0, 0, -90), "B")
			assert(weightless(), "a pass should fly flat")
		end
		-- Caught by its receiver.
		passFromA()
		BallService.part.CFrame = CFrame.new(bRoot.Position)
		BallService:step(1 / 60, { holder("A", a), holder("B", b) })
		expect(BallService.state.carrier).toBe("B")
		expect(weightless()).toBe(false)
		-- Touching a knocked-down body on its way to A.
		BallService:pass("B", Vector3.new(0, 0, 90), "A")
		BallService.part.CFrame = CFrame.new(cRoot.Position + Vector3.new(3, 0, 0))
		BallService:step(1 / 60, { holder("A", a), holder("B", b), holder("C", c, false) })
		expect(weightless()).toBe(false)
		-- Its receiver knocked down.
		passFromA()
		BallService:step(1 / 60, { holder("A", a), holder("B", b, false) })
		expect(weightless()).toBe(false)
		-- Back in play from a spawn: a drop, homing on no one (#321).
		passFromA()
		BallService:spawn()
		BallService:step(0.1, { holder("A", a), holder("B", b) })
		local dropping = BallService.part
		local dropVelocity = DropIn.velocity(config.Arena, config.Ball, dropping.Position)
		Fixtures.expectNear(dropping.AssemblyLinearVelocity, dropVelocity)
		-- Dead after a point, or hidden for a kickoff.
		passFromA()
		BallService:kill()
		expect(weightless()).toBe(false)
		BallService:spawn()
		passFromA()
		BallService:hide()
		expect(weightless()).toBe(false)
	end)

	it("reports a knocked-down defender's touch even beside the thrower", function()
		local a = caughtBy("A")
		local aRoot = Fixtures.root(a)
		BallService:throw("A", Vector3.new(0, 0, -30))
		local at = aRoot.Position + Vector3.new(2.5, 0, 0)
		local b = Fixtures.rig(folder, "B", CFrame.new(at + Vector3.new(3.5, 0, 0)))
		BallService.part.CFrame = CFrame.new(at)
		local frame = BallService:step(1 / 60, { holder("A", a), holder("B", b, false) })
		expect(frame.picker).toBeNil()
		expect(frame.toucher).toBe("B")
	end)

	it("lets a knocked-down player not catch, but reports their touch", function()
		BallService:spawn()
		local at = BallService.part.Position
		BallService.part.AssemblyLinearVelocity = Vector3.new(0, 0, 12)
		local down = Fixtures.rig(folder, "B", CFrame.new(at + Vector3.new(2, 0, 0)))
		local far = Fixtures.rig(folder, "A", CFrame.new(at + Vector3.new(20, 0, 0)))
		local frame = BallService:step(1 / 60, { holder("A", far), holder("B", down, false) })
		expect(frame.picker).toBeNil()
		expect(frame.toucher).toBe("B")
		Fixtures.expectNear(frame.touchPosition, at)
		Fixtures.expectNear(frame.touchVelocity, Vector3.new(0, 0, 12))

		far:PivotTo(CFrame.new(at + Vector3.new(6, 0, 0)))
		frame = BallService:step(1 / 60, { holder("A", far), holder("B", down, false) })
		expect(frame.picker).toBe("A")
		expect(frame.toucher).toBeNil()
	end)

	it("lands a thrown ball when it touches the arena, not a player", function()
		local rig = caughtBy("A")
		BallService:throw("A", Vector3.new(0, 10, 0))
		BallService:onTouched(Fixtures.root(rig))
		expect(BallService.state.status).toBe("Flying")
		local floor = Instance.new("Part")
		floor.Parent = folder
		BallService:onTouched(floor)
		expect(BallService.state.status).toBe("Loose")
	end)

	it("hides the ball and refuses every catch until it spawns again", function()
		BallService:spawn()
		local rig = Fixtures.rig(folder, "A", CFrame.new(BallService.part.Position))
		BallService:hide()
		expect(ballAt()).toBe("ServerStorage")
		expect(BallService.state.status).toBe("Dead")
		local frame = BallService:step(1 / 60, { holder("A", rig) })
		expect(frame.picker).toBeNil()
		expect(frame.moved).toBe(false)
	end)

	it("keeps a dead ball where it is but lets nobody pick it up", function()
		BallService:spawn()
		local rig = Fixtures.rig(folder, "A", CFrame.new(BallService.part.Position))
		BallService:kill()
		expect(ballAt()).toBe("Workspace")
		expect(BallService:step(1 / 60, { holder("A", rig) }).picker).toBeNil()
	end)

	-- The owner (Q91, #311): a loose ball within a body length of a skater's middle is theirs at once (the server
	-- decides; each screen draws the pull into the hand, BallView).
	it(
		"hands a loose ball to a skater within reach of their middle, on the floor and in the air, never beyond",
		function()
			-- On the floor the ball's centre is a radius up and the skater's middle hoverHeight up.
			local rise = config.Movement.hoverHeight - config.Ball.radius
			local across = math.sqrt(REACH * REACH - rise * rise)
			local cases: { { offset: Vector3, caught: boolean } } = {
				{ offset = Vector3.new(across - 0.01, -rise, 0), caught = true },
				{ offset = Vector3.new(across + 0.01, -rise, 0), caught = false },
				{ offset = Vector3.new(0, 0, REACH - 0.01), caught = true },
				{ offset = Vector3.new(0, 0, REACH + 0.01), caught = false },
				{ offset = Vector3.new(0, REACH - 0.01, 0), caught = true },
				{ offset = Vector3.new(0, REACH + 0.01, 0), caught = false },
			}
			local rig = Fixtures.rig(folder, "A", CFrame.new(ON_TRACK))
			for index, case in cases do
				BallService:kill()
				BallService:spawn()
				BallService.part.CFrame = CFrame.new(ON_TRACK + case.offset)
				BallService.part.AssemblyLinearVelocity = Vector3.zero
				local picker = BallService:step(1 / 60, { holder("A", rig) }).picker
				expect(`{index}: {picker ~= nil}`).toBe(`{index}: {case.caught}`)
			end
		end
	)

	it("welds a caught ball at the carry spot at once: each screen draws the pull from where it showed it", function()
		local rig = caughtBy("A")
		local weld = BallService.part:FindFirstChildOfClass("Weld") :: Weld
		Fixtures.expectNear(weld.C0.Position, config.Ball.carryOffset)
		Fixtures.expectNear(BallService.part.Position, Fixtures.root(rig).CFrame * config.Ball.carryOffset)
	end)

	-- The owner (Q124, Q128, #311): a loose ball slows like a coasting skater; Roblox gives a rolling ball none.
	it(
		"slows a loose ball along the surface under it by the skaters' rolling friction, its spin too, to rest",
		function()
			spawnResting(true)
			local ball = BallService.part
			local slowed = 20 - config.Movement.rollingFriction * 0.5
			ball.AssemblyLinearVelocity = Vector3.new(20, -3, 0)
			ball.AssemblyAngularVelocity = Vector3.new(0, 0, -20)
			BallService:step(0.5, {})
			-- Only along the floor: the push into it is physics' own.
			Fixtures.expectNear(ball.AssemblyLinearVelocity, Vector3.new(slowed, -3, 0))
			Fixtures.expectNear(ball.AssemblyAngularVelocity, Vector3.new(0, 0, -20) * (slowed / 20))
			ball.AssemblyLinearVelocity = Vector3.new(0, 0, config.Movement.rollingFriction / 2)
			BallService:step(1, {})
			Fixtures.expectNear(ball.AssemblyLinearVelocity, Vector3.zero)
		end
	)

	it("never slows a ball in the air, nor a pass or a drop-in while it flies flat", function()
		spawnResting(true)
		local ball = BallService.part
		-- Two radii over the floor: nothing within its reach.
		ball.CFrame = CFrame.new(ON_TRACK + Vector3.new(0, 2 * config.Ball.radius, 0))
		ball.AssemblyLinearVelocity = Vector3.new(20, 0, 0)
		BallService:step(0.5, {})
		Fixtures.expectNear(ball.AssemblyLinearVelocity, Vector3.new(20, 0, 0))
		-- A pass skimming the floor, its weight cancelled, turning toward a receiver far along its way.
		local rig = Fixtures.rig(folder, "A", CFrame.new(ON_TRACK))
		BallService:step(1 / 60, { holder("A", rig) })
		BallService:pass("A", Vector3.new(30, 0, 0), "B")
		local receiver = Fixtures.rig(folder, "B", CFrame.new(ball.Position + Vector3.new(300, 0, 0)))
		local chest = Fixtures.root(receiver).Position + Vector3.new(0, PASS.aimHeight, 0)
		local steered = (chest - ball.Position).Unit * PASS.speed
		BallService:step(0.5, { holder("B", receiver) })
		Fixtures.expectNear(ball.AssemblyLinearVelocity, steered, 1e-3)
	end)

	-- RC (Q105): a pass into glass bounces off and is loose. Its centre crossing the pane in one frame, the ball goes
	-- back where it was, bounced off it, and the pass's lift and homing end (the anti-tunnel guard of #311).
	it("ends a pass that meets glass on its way: bounced off it, loose, homing on no one", function()
		local a = caughtBy("A")
		local ball = BallService.part
		local b = Fixtures.rig(folder, "B", CFrame.new(Fixtures.root(a).Position + Vector3.new(0, 0, -40)))
		local glass = Instance.new("Part")
		glass.Name = "Glass"
		glass.Anchored = true
		glass.Size = Vector3.new(40, 40, 0.5)
		glass.CFrame = CFrame.new(Fixtures.root(a).Position + Vector3.new(0, 0, -20))
		glass.Parent = arena
		BallService:pass("A", Vector3.new(0, 0, -100), "B")
		local holders = { holder("A", a), holder("B", b) }
		BallService:step(1 / 60, holders)
		local before = ball.Position
		-- One frame carries its centre through the pane.
		ball.CFrame = CFrame.new(before + Vector3.new(0, 0, -25))
		BallService:step(1 / 60, holders)
		Fixtures.expectNear(ball.Position, before)
		expect(ball.AssemblyLinearVelocity.Z).toBeGreaterThan(0)
		expect(weightless()).toBe(false)
		expect(BallService.state.status).toBe("Loose")
		local bounced = ball.AssemblyLinearVelocity
		BallService:step(0.1, holders)
		Fixtures.expectNear(ball.AssemblyLinearVelocity, bounced)
	end)

	-- Roblox's physics lets a fast small ball through a thin part (measured for #311: a 1-stud ball crossed the 1-stud
	-- floor at 260 studs/s and the closed goal panel at 300).
	it("puts a loose ball whose centre went through a solid face back where it was, bounced off that face", function()
		BallService:spawn()
		local ball = BallService.part
		-- Clear of the floor's reach (which would slow it rolling).
		local above = ON_TRACK + Vector3.new(0, 2 * config.Ball.radius, 0)
		ball.CFrame = CFrame.new(above)
		BallService:step(1 / 60, {})
		slabUnder(ON_TRACK, true)
		-- One frame of the fastest throw straight down carries its centre right through the 1-stud floor.
		ball.CFrame = CFrame.new(above - Vector3.new(0, FASTEST_THROW / 60, 0))
		ball.AssemblyLinearVelocity = Vector3.new(10, -FASTEST_THROW, 0)
		local frame = BallService:step(1 / 60, {})
		Fixtures.expectNear(ball.Position, above)
		Fixtures.expectNear(ball.AssemblyLinearVelocity, Vector3.new(10, FASTEST_THROW * config.Ball.elasticity, 0))
		-- Its movement ends where it was: nothing past the face counts (a gate, the ring).
		expect(frame.moved).toBe(true)
		Fixtures.expectNear(frame.from, above)
		Fixtures.expectNear(frame.to, above)
		-- It touched the face, though Roblox may never say so: the drop-in it was falling in is over.
		expect(weightless()).toBe(false)
		-- Already turned back by physics, it keeps its way.
		ball.CFrame = CFrame.new(above - Vector3.new(0, FASTEST_THROW / 60, 0))
		ball.AssemblyLinearVelocity = Vector3.new(0, 40, 0)
		BallService:step(1 / 60, {})
		Fixtures.expectNear(ball.Position, above)
		Fixtures.expectNear(ball.AssemblyLinearVelocity, Vector3.new(0, 40, 0))
		-- A throw through it lands there.
		local rig = Fixtures.rig(folder, "A", CFrame.new(above))
		BallService:step(1 / 60, { holder("A", rig) })
		BallService:throw("A", Vector3.new(0, -FASTEST_THROW, 0))
		BallService:step(1 / 60, {})
		ball.CFrame = CFrame.new(ball.Position - Vector3.new(0, FASTEST_THROW / 60, 0))
		BallService:step(1 / 60, {})
		expect(BallService.state.status).toBe("Loose")
	end)

	it("lets a ball through what nothing hits (an open goal's panel), and a carrier anywhere", function()
		BallService:spawn()
		local ball = BallService.part
		local above = ON_TRACK + Vector3.new(0, 2 * config.Ball.radius, 0)
		ball.CFrame = CFrame.new(above)
		BallService:step(1 / 60, {})
		local panel = slabUnder(ON_TRACK, false)
		panel.CanCollide = false
		panel.CanQuery = false
		local below = above - Vector3.new(0, FASTEST_THROW / 60, 0)
		ball.CFrame = CFrame.new(below)
		BallService:step(1 / 60, {})
		Fixtures.expectNear(ball.Position, below)
		-- A carrier's ball goes where they go.
		panel.CanCollide = true
		panel.CanQuery = true
		local rig = caughtBy("A")
		BallService:step(1 / 60, {})
		rig:PivotTo(CFrame.new(ON_TRACK - Vector3.new(0, 4, 0)))
		BallService:step(1 / 60, {})
		Fixtures.expectNear(Fixtures.root(rig).Position, ON_TRACK - Vector3.new(0, 4, 0))
		Fixtures.expectNear(ball.Position, Fixtures.root(rig).CFrame * config.Ball.carryOffset)
	end)
end)

-- #316 (Q101): the server-owned ball reached each screen 0.19 s late and unevenly (measured); every screen now draws
-- the loose ball from the server's own states.
describe("BallService: the loose ball's state for every screen", function()
	local FRAME = 1 / 60
	local REST = config.Network.ballStream.restSeconds

	it("gives the loose ball's state each frame it moves: where, how fast, its spin, whether borne, when", function()
		-- Parked until it spawns: nothing to draw.
		expect(BallService:streamState(FRAME)).toBeNil()
		BallService:spawn()
		BallService:step(FRAME, {})
		serverNow = 42.5
		-- Its spin, from Roblox's physics, turns its look on every screen (#401, Q276).
		BallService.part.AssemblyAngularVelocity = Vector3.new(0, 3, -4)
		local state = BallService:streamState(FRAME) :: BallService.BallStream
		Fixtures.expectNear(state.position, BallService.part.Position)
		Fixtures.expectNear(state.velocity, BallService.part.AssemblyLinearVelocity)
		Fixtures.expectNear(state.spin, Vector3.new(0, 3, -4))
		-- A drop-in falls with its weight cancelled by its lift (#321).
		expect(state.supported).toBe(true)
		expect(state.time).toBe(42.5)
		expect(BallService:streamState(FRAME)).never.toBeNil()
		BallService:hide()
		expect(BallService:streamState(FRAME)).toBeNil()
	end)

	it("gives a resting ball's state every ballStream.restSeconds, and none between", function()
		spawnResting(true)
		BallService:step(FRAME, {})
		local state = BallService:streamState(FRAME) :: BallService.BallStream
		-- The floor bears it (#337).
		expect(state.supported).toBe(true)
		expect(BallService:streamState(REST / 2)).toBeNil()
		expect(BallService:streamState(REST / 2)).never.toBeNil()
		-- Rolling a little slower than Ball.restSpeed is resting; at it, moving.
		BallService.part.AssemblyLinearVelocity = Vector3.new(config.Ball.restSpeed * 0.99, 0, 0)
		expect(BallService:streamState(FRAME)).toBeNil()
		BallService.part.AssemblyLinearVelocity = Vector3.new(config.Ball.restSpeed, 0, 0)
		expect(BallService:streamState(FRAME)).never.toBeNil()
	end)

	-- #337 (the owner's video, 2026-11-01): every screen carried a resting ball's state on falling, and drew it sinking
	-- into the floor and popping back up. The ground it lies or rolls on bears its weight, as a lift does; a screen
	-- carries a borne ball on without gravity.
	it("says the ground bears a ball lying or rolling on it, after a point too, and nothing in the air", function()
		spawnResting(true)
		BallService:step(FRAME, {})
		expect((BallService:streamState(FRAME) :: BallService.BallStream).supported).toBe(true)
		-- Moved 30 studs over the floor, rolling: nothing bears it.
		BallService.part.CFrame = CFrame.new(ON_TRACK + Vector3.new(0, 30, 0))
		BallService.part.AssemblyLinearVelocity = Vector3.new(10, 0, 0)
		BallService:jumped()
		BallService:step(FRAME, {})
		expect((BallService:streamState(FRAME) :: BallService.BallStream).supported).toBe(false)
		-- Out of play after a point, back on the floor: it still shows until the kickoff, borne by the floor.
		BallService:kill()
		BallService.part.CFrame = CFrame.new(ON_TRACK)
		BallService:jumped()
		BallService:step(FRAME, {})
		expect((BallService:streamState(FRAME) :: BallService.BallStream).supported).toBe(true)
	end)

	it("gives nothing while the ball is carried, and its state at once when it is let go, even still", function()
		spawnResting(true)
		BallService:step(FRAME, {})
		expect(BallService:streamState(FRAME)).never.toBeNil()
		local rig = Fixtures.rig(folder, "A", CFrame.new(ON_TRACK))
		BallService:step(FRAME, { holder("A", rig) })
		expect(BallService.state.carrier).toBe("A")
		expect(BallService:streamState(FRAME)).toBeNil()
		BallService:dropAt(ON_TRACK)
		BallService:step(FRAME, {})
		expect(BallService:streamState(FRAME)).never.toBeNil()
	end)
end)
