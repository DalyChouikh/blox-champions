--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local BallService = require(game:GetService("ServerScriptService").Server.BallService)
local BallSkins = require(ReplicatedStorage.Shared.Skins.BallSkins)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local SkaterBody = require(game:GetService("ServerScriptService").Server.SkaterBody)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)

local config = Fixtures.config()
local SPAWNS = { CFrame.new(-140, 6, 0), CFrame.new(140, 6, 0) }

local folder: Folder
beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "BallServiceTest"
	folder.Parent = workspace
	BallService:init({ Config = config, ArenaService = { arena = { ballSpawns = SPAWNS } } })
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
		root = rig:FindFirstChild("HumanoidRootPart") :: BasePart,
		canCatch = canCatch ~= false,
	}
end

-- Whether the ball's lift is on: a pass flies against gravity.
local function flyingFlat(): boolean
	local lift = BallService.part:FindFirstChildOfClass("VectorForce")
	if lift then
		return lift.Enabled
	end
	return false
end

local function isSpawn(position: Vector3): boolean
	for _, spawn in SPAWNS do
		if (spawn.Position - position).Magnitude < 1e-3 then
			return true
		end
	end
	return false
end

-- Spawns the ball and has a rig standing on it catch it.
local function caughtBy(name: string): Model
	BallService:spawn()
	local rig = Fixtures.rig(folder, name, CFrame.new(BallService.part.Position))
	BallService:step(1 / 60, { holder(name, rig) })
	return rig
end

describe("BallService", function()
	it("makes a ball of the configured size, physics and skin, hidden until it spawns", function()
		local ball = BallService.part
		expect(ball.Shape).toBe(Enum.PartType.Ball)
		expect(ball.Size).toEqual(Vector3.one * 3)
		local physics = ball.CustomPhysicalProperties :: PhysicalProperties
		expect(physics.Density).toBeCloseTo(0.7, 4)
		expect(physics.Friction).toBeCloseTo(0.3, 4)
		expect(physics.Elasticity).toBeCloseTo(0.5, 4)
		expect(ball.Color).toEqual(BallSkins.get(BallSkins.DEFAULT).color)
		expect(ballAt()).toBe("ServerStorage")
		expect(BallService.state.status).toBe("Dead")
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
	end)

	it("spawns the ball loose at a ball spawn and reports only real movement", function()
		BallService:spawn()
		local ball = BallService.part
		expect(ballAt()).toBe("Workspace")
		expect(isSpawn(ball.Position)).toBe(true)
		expect(BallService.state.status).toBe("Loose")
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
		local start = ball.Position
		ball.CFrame = CFrame.new(start + Vector3.new(4, 0, 0))
		local frame = BallService:step(1 / 60, {})
		expect(frame.moved).toBe(true)
		Fixtures.expectNear(frame.from, start)
		Fixtures.expectNear(frame.to, start + Vector3.new(4, 0, 0))
	end)

	it("gives the ball to the nearest player in reach with its velocity from before the catch", function()
		BallService:spawn()
		local at = BallService.part.Position
		BallService.part.AssemblyLinearVelocity = Vector3.new(20, 0, 0)
		local closest = Fixtures.rig(folder, "Near", CFrame.new(at + Vector3.new(3, 0, 0)))
		local farther = Fixtures.rig(folder, "Far", CFrame.new(at + Vector3.new(6, 0, 0)))
		local outside = Fixtures.rig(folder, "Out", CFrame.new(at + Vector3.new(0, 0, 7.5)))
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
		local root = closest:FindFirstChild("HumanoidRootPart") :: BasePart
		Fixtures.expectNear(BallService.part.Position, root.CFrame * config.Ball.carryOffset)
	end)

	it("carries the ball at the carrier's side, clear of the floor", function()
		BallService:spawn()
		local rig = Fixtures.rig(folder, "A", CFrame.new(BallService.part.Position.X, 3, BallService.part.Position.Z))
		BallService:step(1 / 60, { holder("A", rig) })
		expect(BallService.state.carrier).toBe("A")
		expect(BallService.part.Position.Y - config.Ball.radius >= 0).toBe(true)
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

	it("respawns a ball that leaves the arena or lies untouched, without reporting the jump", function()
		BallService:spawn()
		BallService:step(1 / 60, {})
		BallService.part.CFrame = CFrame.new(0, 5, -90)
		local out = BallService:step(1 / 60, {})
		expect(out.moved).toBe(true)
		Fixtures.expectNear(out.to, Vector3.new(0, 5, -90))
		expect(out.respawned).toBe(true)
		expect(isSpawn(BallService.part.Position)).toBe(true)
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
		expect(BallService:step(15, {}).respawned).toBe(true)
		expect(BallService.state.looseSeconds).toBe(0)
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
		expect(ballAt()).toBe("Workspace")
		expect(isSpawn(BallService.part.Position)).toBe(true)
		expect(BallService.state.status).toBe("Loose")
	end)

	it("parks a dead ball that leaves the arena", function()
		BallService:spawn()
		BallService:kill()
		BallService:step(1 / 60, {})
		BallService.part.CFrame = CFrame.new(0, 5, -90)
		BallService:step(1 / 60, {})
		expect(ballAt()).toBe("ServerStorage")
	end)

	it("takes the ball back from a carrier who leaves the arena and puts it in play", function()
		local rig = caughtBy("A")
		rig:PivotTo(CFrame.new(0, 5, -90))
		local frame = BallService:step(1 / 60, { holder("A", rig) })
		expect(frame.respawned).toBe(true)
		expect(BallService.state.carrier).toBeNil()
		expect(BallService.state.status).toBe("Loose")
		expect(isSpawn(BallService.part.Position)).toBe(true)
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
		local root = rig:FindFirstChild(SkaterRig.root) :: BasePart
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
		local root = rig:FindFirstChild(SkaterRig.root) :: BasePart
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

	it("homes a pass on its target", function()
		local a = caughtBy("A")
		local b = Fixtures.rig(folder, "B", CFrame.new(BallService.part.Position + Vector3.new(20, 0, -30)))
		BallService:pass("A", Vector3.new(0, 0, -90), "B")
		expect(BallService.state.status).toBe("Flying")
		local root = b:FindFirstChild("HumanoidRootPart") :: BasePart
		local turn = (root.Position - BallService.part.Position).Unit * 60 * 0.1
		BallService:step(0.1, { holder("A", a), holder("B", b) })
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.new(0, 0, -90) + turn)
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
		expect(flyingFlat()).toBe(false)
		BallService:pass("A", Vector3.new(0, 0, -90), nil)
		expect(flyingFlat()).toBe(true)
		-- As strong as the free ball's weight, upward, at its center (a welded massless part weighs 0 by GetMass).
		local lift = BallService.part:FindFirstChildOfClass("VectorForce") :: VectorForce
		Fixtures.expectNear(lift.Force, Vector3.new(0, BallService.part:GetMass() * workspace.Gravity, 0))
		expect(lift.RelativeTo).toBe(Enum.ActuatorRelativeTo.World)
		expect(lift.ApplyAtCenterOfMass).toBe(true)
		BallService:step(1 / 60, { holder("A", a) })
		expect(flyingFlat()).toBe(true)
		local wall = Instance.new("Part")
		wall.Parent = folder
		BallService:onTouched(wall)
		expect(flyingFlat()).toBe(false)
		-- A throw is not a pass.
		BallService.part.CFrame = CFrame.new((a:FindFirstChild(SkaterRig.root) :: BasePart).Position)
		BallService:step(config.Ball.rethrowPickupDelay, { holder("A", a) })
		expect(BallService.state.carrier).toBe("A")
		BallService:throw("A", Vector3.new(0, 0, -90))
		expect(flyingFlat()).toBe(false)
	end)

	it("lets a pass fall once it is caught, touches a body, loses its receiver, or leaves play", function()
		local a = caughtBy("A")
		local aRoot = a:FindFirstChild(SkaterRig.root) :: BasePart
		local b = Fixtures.rig(folder, "B", CFrame.new(aRoot.Position + Vector3.new(0, 0, -30)))
		local bRoot = b:FindFirstChild(SkaterRig.root) :: BasePart
		local c = Fixtures.rig(folder, "C", CFrame.new(aRoot.Position + Vector3.new(0, 0, 30)))
		local cRoot = c:FindFirstChild(SkaterRig.root) :: BasePart
		local function passFromA(target: string?)
			BallService.part.CFrame = CFrame.new(aRoot.Position)
			BallService:step(config.Ball.rethrowPickupDelay, { holder("A", a) })
			assert(BallService.state.carrier == "A", "A should carry the ball")
			BallService:pass("A", Vector3.new(0, 0, -90), target)
			assert(flyingFlat(), "a pass should fly flat")
		end
		-- Caught by its receiver.
		passFromA("B")
		BallService.part.CFrame = CFrame.new(bRoot.Position)
		BallService:step(1 / 60, { holder("A", a), holder("B", b) })
		expect(BallService.state.carrier).toBe("B")
		expect(flyingFlat()).toBe(false)
		-- Touching a knocked-down body.
		BallService:pass("B", Vector3.new(0, 0, 90), nil)
		BallService.part.CFrame = CFrame.new(cRoot.Position + Vector3.new(3, 0, 0))
		BallService:step(1 / 60, { holder("B", b), holder("C", c, false) })
		expect(flyingFlat()).toBe(false)
		-- Its receiver knocked down.
		passFromA("B")
		BallService:step(1 / 60, { holder("A", a), holder("B", b, false) })
		expect(flyingFlat()).toBe(false)
		-- Back in play from a spawn, dead after a point, or hidden for a kickoff.
		passFromA(nil)
		BallService:spawn()
		expect(flyingFlat()).toBe(false)
		passFromA(nil)
		BallService:kill()
		expect(flyingFlat()).toBe(false)
		BallService:spawn()
		passFromA(nil)
		BallService:hide()
		expect(flyingFlat()).toBe(false)
	end)

	it("reports a knocked-down defender's touch even beside the thrower", function()
		local a = caughtBy("A")
		local aRoot = a:FindFirstChild(SkaterRig.root) :: BasePart
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
		BallService:onTouched(rig:FindFirstChild("HumanoidRootPart") :: BasePart)
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
end)
