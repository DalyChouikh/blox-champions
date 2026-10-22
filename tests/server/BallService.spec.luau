--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local BallService = require(game:GetService("ServerScriptService").Server.BallService)
local BallSkins = require(ReplicatedStorage.Shared.Skins.BallSkins)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

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

local function near(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude).toBeLessThan(1e-3)
end

local function holder(name: string, rig: Model): BallService.Holder
	return { player = name, root = rig:FindFirstChild("HumanoidRootPart") :: BasePart }
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
		near(frame.from, start)
		near(frame.to, start + Vector3.new(4, 0, 0))
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
		near(frame.pickupPosition, at)
		near(frame.pickupVelocity, Vector3.new(20, 0, 0))
		expect(BallService.state.carrier).toBe("Near")
		expect(BallService.part.CanCollide).toBe(false)
		expect(BallService.part.CanTouch).toBe(false)
		expect(BallService.part.Massless).toBe(true)
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
		closest:PivotTo(closest:GetPivot() + Vector3.new(10, 0, 0))
		local root = closest:FindFirstChild("HumanoidRootPart") :: BasePart
		near(BallService.part.Position, root.CFrame:PointToWorldSpace(config.Ball.carryOffset))
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
		near(BallService.part.AssemblyLinearVelocity, Vector3.new(0, 0, 30))
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
		near(out.to, Vector3.new(0, 5, -90))
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
		near(BallService.part.Position, carriedAt)
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
