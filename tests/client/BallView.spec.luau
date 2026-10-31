--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local BallView = require(Client.BallView)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Pull = require(ReplicatedStorage.Shared.Ball.Pull)
local Shown = require(ReplicatedStorage.Shared.Ball.Shown)

local config = Fixtures.config()
local SECONDS = config.Ball.pickupPullSeconds
local CARRY = config.Ball.carryOffset
local RADIUS = config.Ball.radius
local STREAM = config.Network.ballStream
local GRAVITY = Config.gravity(config)
local DT = SECONDS / 4

local folder: Folder
-- The arena's solid parts in a test: what the drawn ball never passes through.
local arena: Folder
local solid: RaycastParams
local ball: Part?
-- The server's time as this screen reads it.
local now = 0

-- A carrier's root, standing at `position` facing `look` (anchored, as the server's weld holds the ball to it).
local function root(name: string, position: Vector3, look: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CFrame = CFrame.lookAlong(position, look)
	part.Parent = folder
	return part
end

-- The server's catch as it reaches this screen: a weld holding the ball at the carry spot of `holder`'s root.
local function catch(holder: BasePart): Weld
	local weld = Instance.new("Weld")
	weld.Part0 = holder
	weld.Part1 = ball :: Part
	weld.C0 = CFrame.new(CARRY)
	weld.Parent = ball
	return weld
end

local function init(overrides: { [string]: any }?)
	BallView:init({
		Config = Fixtures.config(overrides),
		BallPart = {
			get = function(_self: any): BasePart?
				return ball
			end,
		},
		RideSurfaces = { solid = solid },
		ServerClock = function(): number
			return now
		end,
	})
end

-- Where this screen draws the ball after a step from `shown` toward a state `age` seconds old.
local function drawn(shown: Vector3, position: Vector3, velocity: Vector3, lifted: boolean, age: number): Vector3
	local target, moving = Shown.predict(position, velocity, if lifted then Vector3.zero else GRAVITY, age)
	return (Shown.follow(shown, target, moving, DT, STREAM.correctionSeconds, STREAM.snapStuds))
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "BallViewTest"
	folder.Parent = workspace
	arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = folder
	solid = RaycastParams.new()
	solid.FilterType = Enum.RaycastFilterType.Include
	solid.FilterDescendantsInstances = { arena }
	local part = Instance.new("Part")
	part.Name = "Ball"
	part.Shape = Enum.PartType.Ball
	part.Parent = folder
	ball = part
	now = 100
	init()
end)

afterEach(function()
	folder:Destroy()
	ball = nil
end)

-- #316 (Q101): the server-owned ball reached each screen 0.19 s late and unevenly (46-248 studs/s drawn for a steady
-- 90, measured), and other screens drew it still for 0.29 s after a throw. The server now sends its state each frame
-- it moves; each screen draws it there, carried on to now.
describe("BallView: the loose ball", function()
	it("draws the ball where the server's last state says it is now, falling unless its weight is cancelled", function()
		local part = ball :: Part
		local start = Vector3.new(0, 20, 0)
		part.Position = start
		-- No state yet: the ball is drawn where Roblox puts it.
		BallView:step(DT)
		Fixtures.expectNear(part.Position, start)
		BallView:receive(start, Vector3.new(90, 0, 0), false, now - 0.05)
		BallView:step(DT)
		local falling = drawn(start, start, Vector3.new(90, 0, 0), false, 0.05)
		Fixtures.expectNear(part.Position, falling)
		-- A pass flies flat: the next state's weight is cancelled.
		now += DT
		BallView:receive(falling, Vector3.new(90, 0, 0), true, now - 0.05)
		BallView:step(DT)
		Fixtures.expectNear(part.Position, drawn(falling, falling, Vector3.new(90, 0, 0), true, 0.05))
	end)

	it(
		"carries a state on for at most ballStream.maxAgeSeconds, so a stalled stream never flies the ball on",
		function()
			local part = ball :: Part
			local start = Vector3.new(0, 20, 0)
			part.Position = start
			BallView:step(DT)
			BallView:receive(start, Vector3.new(30, 0, 0), true, now - 5)
			BallView:step(DT)
			Fixtures.expectNear(part.Position, drawn(start, start, Vector3.new(30, 0, 0), true, STREAM.maxAgeSeconds))
		end
	)

	it("keeps the newest state, and drops one from before the catch it last saw", function()
		local part = ball :: Part
		local start = Vector3.new(0, 20, 0)
		part.Position = start
		BallView:step(DT)
		BallView:receive(Vector3.new(4, 20, 0), Vector3.zero, true, now)
		-- Older than the last one: unreliable messages may arrive out of order.
		BallView:receive(Vector3.new(-4, 20, 0), Vector3.zero, true, now - 0.01)
		BallView:step(DT)
		local shown = drawn(start, Vector3.new(4, 20, 0), Vector3.zero, true, 0)
		Fixtures.expectNear(part.Position, shown)
		-- Caught, then a state from before the catch arrives, then the ball is thrown: nothing to draw it from yet, so
		-- it stays where the weld last put it.
		local holder = root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		local weld = catch(holder)
		BallView:step(SECONDS)
		BallView:receive(Vector3.new(40, 20, 0), Vector3.zero, true, now - 0.01)
		weld:Destroy()
		local held = part.Position
		now += DT
		BallView:step(DT)
		Fixtures.expectNear(part.Position, held)
		-- The throw's first state.
		BallView:receive(held, Vector3.new(0, 50, 0), false, now)
		BallView:step(DT)
		Fixtures.expectNear(part.Position, drawn(held, held, Vector3.new(0, 50, 0), false, 0))
	end)

	it("never draws the ball through the arena, but jumps across it to a state past the snap distance", function()
		local wall = Instance.new("Part")
		wall.Anchored = true
		wall.Size = Vector3.new(1, 40, 40)
		wall.Position = Vector3.new(5, 20, 0)
		wall.Parent = arena
		local part = ball :: Part
		local start = Vector3.new(0, 20, 0)
		part.Position = start
		BallView:step(DT)
		-- A state from just before the server's ball bounced off the wall, carried on 0.05 s to 8.5, past the face:
		-- this screen does not know of the bounce yet, so it stops the ball a radius off the face.
		BallView:receive(Vector3.new(4, 20, 0), Vector3.new(90, 0, 0), true, now - 0.05)
		BallView:step(DT)
		Fixtures.expectNear(part.Position, Vector3.new(4.5 - RADIUS, 20, 0))
		-- A drop-in starting across the arena: drawn there at once.
		now += DT
		BallView:receive(Vector3.new(30, 20, 0), Vector3.zero, true, now)
		BallView:step(DT)
		Fixtures.expectNear(part.Position, Vector3.new(30, 20, 0))
	end)
end)

-- The owner (Q91, Q131, Q132, #311): the server decides a catch at once, but its weld can reach this screen while it
-- still shows the ball flying short of the hand (36.6 studs, measured): each screen draws the pull itself.
describe("BallView: a catch's pull into the hand", function()
	it("draws a catch from where this screen last drew the ball into the hand over the pull's time", function()
		local holder = root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		local part = ball :: Part
		part.Position = Vector3.new(30, 3, 4)
		BallView:step(DT)
		-- Drawn from the server's state, not where Roblox put the part.
		BallView:receive(Vector3.new(20, 3, 4), Vector3.zero, true, now)
		BallView:step(DT)
		local shown = part.Position
		local weld = catch(holder)
		local from = holder.CFrame:PointToObjectSpace(shown)
		BallView:step(DT)
		Fixtures.expectNear(weld.C0.Position, Pull.offset(from, CARRY, DT, SECONDS))
		BallView:step(DT)
		Fixtures.expectNear(weld.C0.Position, Pull.offset(from, CARRY, 2 * DT, SECONDS))
		BallView:step(2 * DT)
		Fixtures.expectNear(weld.C0.Position, CARRY)
		-- Then the weld is the server's again: nothing more is written.
		weld.C0 = CFrame.new(1, 2, 3)
		BallView:step(DT)
		Fixtures.expectNear(weld.C0.Position, Vector3.new(1, 2, 3))
	end)

	it("pulls a ball it never had a state for from where Roblox last showed it", function()
		local holder = root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		local part = ball :: Part
		part.Position = Vector3.new(30, 3, 0)
		BallView:step(DT)
		-- Roblox moves it, as for a player who joined while it rested: no state from the server yet.
		part.Position = Vector3.new(20, 3, 4)
		BallView:step(DT)
		local weld = catch(holder)
		BallView:step(DT)
		local from = holder.CFrame:PointToObjectSpace(Vector3.new(20, 3, 4))
		Fixtures.expectNear(weld.C0.Position, Pull.offset(from, CARRY, DT, SECONDS))
	end)

	it("starts a catch from another carrier's hand where this screen drew it", function()
		local first = root("First", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		local second = root("Second", Vector3.new(-20, 3, 6), Vector3.new(0, 0, -1))
		local part = ball :: Part
		part.Position = Vector3.new(14, 3, 0)
		BallView:step(DT)
		local weld = catch(first)
		BallView:step(SECONDS)
		local shown = first.CFrame:PointToWorldSpace(CARRY)
		-- The first carrier lets go and the second catches before this screen draws the ball loose.
		weld:Destroy()
		local handOff = catch(second)
		BallView:step(DT)
		local from = second.CFrame:PointToObjectSpace(shown)
		Fixtures.expectNear(handOff.C0.Position, Pull.offset(from, CARRY, DT, SECONDS))
	end)

	it("lets go of a pull whose ball was thrown mid-way, and draws a ball it never drew loose where it is", function()
		local holder = root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		local part = ball :: Part
		part.Position = Vector3.new(30, 3, 0)
		BallView:step(DT)
		local weld = catch(holder)
		BallView:step(DT)
		weld:Destroy()
		BallView:step(DT)
		-- A new pull after a rebuild: the new ball part was never drawn loose, so the server's spot stands.
		local rebuilt = Instance.new("Part")
		rebuilt.Parent = folder
		ball = rebuilt
		local later = catch(holder)
		BallView:step(DT)
		Fixtures.expectNear(later.C0.Position, CARRY)
	end)

	it("leaves alone a weld that holds the ball to no carrier", function()
		local part = ball :: Part
		part.Position = Vector3.new(30, 3, 0)
		BallView:step(DT)
		local weld = Instance.new("Weld")
		weld.Part1 = part
		weld.C0 = CFrame.new(CARRY)
		weld.Parent = part
		BallView:step(DT)
		Fixtures.expectNear(weld.C0.Position, CARRY)
	end)

	it("puts a catch in the hand at once when the pull takes no time", function()
		init({ Ball = { pickupPullSeconds = 0 } })
		local holder = root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		local part = ball :: Part
		part.Position = Vector3.new(30, 3, 0)
		BallView:step(DT)
		local weld = catch(holder)
		BallView:step(DT)
		Fixtures.expectNear(weld.C0.Position, CARRY)
	end)

	it("does nothing while there is no ball, and forgets a pull and a state whose ball is gone", function()
		local holder = root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		local part = ball :: Part
		part.Position = Vector3.new(30, 3, 0)
		BallView:step(DT)
		local weld = catch(holder)
		BallView:step(DT)
		ball = nil
		expect(function()
			BallView:step(DT)
		end).never.toThrow()
		-- Back with the same weld: its pull is over, the server's spot stands.
		ball = part
		weld.C0 = CFrame.new(CARRY)
		BallView:step(DT)
		Fixtures.expectNear(weld.C0.Position, CARRY)
		-- Thrown, a state arrives, then the ball is rebuilt: that state was the old ball's, so the new one is drawn
		-- where Roblox puts it.
		weld:Destroy()
		BallView:step(DT)
		BallView:receive(Vector3.new(0, 30, 0), Vector3.zero, true, now)
		local rebuilt = Instance.new("Part")
		rebuilt.Position = Vector3.new(0, 9, 0)
		rebuilt.Parent = folder
		ball = rebuilt
		BallView:step(DT)
		Fixtures.expectNear(rebuilt.Position, Vector3.new(0, 9, 0))
	end)
end)
