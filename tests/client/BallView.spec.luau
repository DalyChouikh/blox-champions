--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local BallView = require(Client.BallView)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Look = require(ReplicatedStorage.Shared.Ball.Look)
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

-- The ball's look (#400) under `part`, as the server dresses each ball.
local function newLook(part: Part): MeshPart
	local look = Instance.new("MeshPart")
	look.Name = Look.NAME
	look.Anchored = true
	look.Parent = part
	return look
end

local function init(overrides: { [string]: any }?)
	BallView:init({
		Config = Fixtures.config(overrides),
		BallPart = {
			get = function(_self: any): BasePart?
				return ball
			end,
			look = function(_self: any): BasePart?
				return if ball ~= nil then Look.of(ball) else nil
			end,
		},
		RideSurfaces = { solid = solid },
		ServerClock = function(): number
			return now
		end,
	})
end

-- Where this screen draws the ball after a step from `shown` toward a state `age` seconds old, carried on falling
-- unless something bears its weight (`supported`: a lift, or the ground it lies on).
local function drawn(shown: Vector3, position: Vector3, velocity: Vector3, supported: boolean, age: number): Vector3
	local target, moving = Shown.predict(position, velocity, if supported then Vector3.zero else GRAVITY, age)
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
	it("draws the ball where the server's last state says it is now, falling unless something bears it", function()
		local part = ball :: Part
		local start = Vector3.new(0, 20, 0)
		part.Position = start
		-- No state yet: the ball is drawn where Roblox puts it.
		BallView:step(DT)
		Fixtures.expectNear(part.Position, start)
		BallView:receive(start, Vector3.new(90, 0, 0), false, now - 0.05, Vector3.zero)
		BallView:step(DT)
		local falling = drawn(start, start, Vector3.new(90, 0, 0), false, 0.05)
		Fixtures.expectNear(part.Position, falling)
		-- A pass flies flat: the next state's weight is cancelled.
		now += DT
		BallView:receive(falling, Vector3.new(90, 0, 0), true, now - 0.05, Vector3.zero)
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
			BallView:receive(start, Vector3.new(30, 0, 0), true, now - 5, Vector3.zero)
			BallView:step(DT)
			Fixtures.expectNear(part.Position, drawn(start, start, Vector3.new(30, 0, 0), true, STREAM.maxAgeSeconds))
		end
	)

	it("keeps the newest state, and drops one from before the catch it last saw", function()
		local part = ball :: Part
		local start = Vector3.new(0, 20, 0)
		part.Position = start
		BallView:step(DT)
		BallView:receive(Vector3.new(4, 20, 0), Vector3.zero, true, now, Vector3.zero)
		-- Older than the last one: unreliable messages may arrive out of order.
		BallView:receive(Vector3.new(-4, 20, 0), Vector3.zero, true, now - 0.01, Vector3.zero)
		BallView:step(DT)
		local shown = drawn(start, Vector3.new(4, 20, 0), Vector3.zero, true, 0)
		Fixtures.expectNear(part.Position, shown)
		-- Caught, then a state from before the catch arrives, then the ball is thrown: nothing to draw it from yet, so
		-- it stays where the weld last put it.
		local holder = root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		local weld = catch(holder)
		BallView:step(SECONDS)
		BallView:receive(Vector3.new(40, 20, 0), Vector3.zero, true, now - 0.01, Vector3.zero)
		weld:Destroy()
		local held = part.Position
		now += DT
		BallView:step(DT)
		Fixtures.expectNear(part.Position, held)
		-- The throw's first state.
		BallView:receive(held, Vector3.new(0, 50, 0), false, now, Vector3.zero)
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
		BallView:receive(Vector3.new(4, 20, 0), Vector3.new(90, 0, 0), true, now - 0.05, Vector3.zero)
		BallView:step(DT)
		Fixtures.expectNear(part.Position, Vector3.new(4.5 - RADIUS, 20, 0))
		-- A drop-in starting across the arena: drawn there at once.
		now += DT
		BallView:receive(Vector3.new(30, 20, 0), Vector3.zero, true, now, Vector3.zero)
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
		BallView:receive(Vector3.new(20, 3, 4), Vector3.zero, true, now, Vector3.zero)
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
		BallView:receive(Vector3.new(0, 30, 0), Vector3.zero, true, now, Vector3.zero)
		local rebuilt = Instance.new("Part")
		rebuilt.Position = Vector3.new(0, 9, 0)
		rebuilt.Parent = folder
		ball = rebuilt
		BallView:step(DT)
		Fixtures.expectNear(rebuilt.Position, Vector3.new(0, 9, 0))
	end)
end)

-- #400: the ball part, the one that bounces and rolls, is unseen; its look (the mesh in its skin) is what each screen
-- shows. The server never moves the look, and this screen's writes to the ball part don't carry a part joined to it
-- (measured in Play: 19 studs apart), so the look is drawn here, where the ball is.
describe("BallView: the ball's look", function()
	it("draws the look where it draws the ball: with no state, loose, pulled into the hand and carried", function()
		local look = newLook(ball :: Part)
		local part = ball :: Part
		part.Position = Vector3.new(30, 3, 4)
		BallView:step(DT)
		expect(look.Position).toEqual(part.Position)
		BallView:receive(Vector3.new(20, 3, 4), Vector3.new(30, 0, 0), true, now, Vector3.zero)
		BallView:step(DT)
		expect(look.Position).toEqual(part.Position)
		local holder = root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		catch(holder)
		BallView:step(DT)
		expect(look.Position).toEqual(part.Position)
		BallView:step(SECONDS)
		expect(look.Position).toEqual(part.Position)
		holder.CFrame += Vector3.new(5, 0, 0)
		BallView:step(DT)
		expect(look.Position).toEqual(part.Position)
	end)

	-- Roblox fires no change for a property set to the value it has, so a write is told by moving the look away: while
	-- the ball is drawn where it was, the look is not written again.
	it("writes the look only when the ball is drawn somewhere new", function()
		local look = newLook(ball :: Part)
		local part = ball :: Part
		part.Position = Vector3.new(30, 3, 4)
		BallView:step(DT)
		local away = Vector3.new(0, 50, 0)
		look.Position = away
		BallView:step(DT)
		BallView:step(DT)
		expect(look.Position).toEqual(away)
		part.Position = Vector3.new(31, 3, 4)
		BallView:step(DT)
		expect(look.Position).toEqual(part.Position)
	end)

	it("draws a look that comes after its ball, and a rebuilt ball's", function()
		local part = ball :: Part
		part.Position = Vector3.new(30, 3, 4)
		expect(function()
			BallView:step(DT)
		end).never.toThrow()
		local look = newLook(part)
		BallView:step(DT)
		expect(look.Position).toEqual(part.Position)
		-- A new look on the same ball, which has not moved.
		look:Destroy()
		local another = newLook(part)
		BallView:step(DT)
		expect(another.Position).toEqual(part.Position)
		local rebuilt = Instance.new("Part")
		rebuilt.Position = Vector3.new(0, 9, 0)
		rebuilt.Parent = folder
		local rebuiltLook = newLook(rebuilt)
		ball = rebuilt
		BallView:step(DT)
		expect(rebuiltLook.Position).toEqual(rebuilt.Position)
	end)
end)

-- #401 (the owner's Q276): the band turns as the ball rolls and spins. The server's ball spins by Roblox's physics,
-- but this screen's ball part never turns once it is drawn (measured in Play), so each state carries the server's spin
-- and the look is turned by it here; carried, the look turns with the hand.
describe("BallView: the ball's spin", function()
	local function expectTurn(look: BasePart, expected: CFrame)
		for _, axis in { "XVector", "YVector", "ZVector" } do
			local a: Vector3 = (look.CFrame :: any)[axis]
			local b: Vector3 = (expected :: any)[axis]
			expect((a - b).Magnitude).toBeLessThan(1e-3)
		end
	end

	it("turns the look by the state's spin while it draws the ball loose", function()
		local look = newLook(ball :: Part)
		look.Orientation = Vector3.new(0, 30, 0)
		local start = look.CFrame.Rotation
		-- The ball seen first, as on a screen: a state never carries over to a ball part seen after it.
		BallView:step(DT)
		local spin = Vector3.new(0, 0, -10)
		BallView:receive(Vector3.new(0, 20, 0), Vector3.new(10, 0, 0), true, now, spin)
		BallView:step(DT)
		expectTurn(look, CFrame.fromAxisAngle(spin.Unit, spin.Magnitude * DT) * start)
		BallView:step(DT)
		expectTurn(look, CFrame.fromAxisAngle(spin.Unit, spin.Magnitude * 2 * DT) * start)
		-- A new state's spin from then on.
		local after = look.CFrame.Rotation
		local other = Vector3.new(4, 0, 0)
		BallView:receive(Vector3.new(0, 20, 0), Vector3.zero, true, now + DT, other)
		BallView:step(DT)
		expectTurn(look, CFrame.fromAxisAngle(other.Unit, other.Magnitude * DT) * after)
	end)

	-- The owner's Q283/Q287: right after a Roll Ball the ball spins ~40 turns a second, too fast to follow; the band
	-- turns at most Ball.lookSpinLimit, about the spin's own axis.
	it("turns the look no faster than the ball's look spin limit", function()
		local look = newLook(ball :: Part)
		BallView:step(DT)
		local start = look.CFrame.Rotation
		local spin = Vector3.new(30, 0, -250)
		BallView:receive(Vector3.new(0, 20, 0), Vector3.new(250, 0, 30), true, now, spin)
		BallView:step(DT)
		expectTurn(look, CFrame.fromAxisAngle(spin.Unit, config.Ball.lookSpinLimit * DT) * start)
	end)

	it("turns the look with the hand while carried, and from there once let go", function()
		local look = newLook(ball :: Part)
		local holder = root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 1))
		local weld = catch(holder)
		BallView:step(SECONDS)
		BallView:step(DT)
		expectTurn(look, (ball :: Part).CFrame.Rotation)
		holder.CFrame = CFrame.lookAlong(Vector3.new(10, 3, 0), Vector3.new(-1, 0, 0.3))
		BallView:step(DT)
		expectTurn(look, (ball :: Part).CFrame.Rotation)
		local held = look.CFrame.Rotation
		weld:Destroy()
		local spin = Vector3.new(6, 0, 0)
		BallView:receive(Vector3.new(10, 3, 0), Vector3.zero, true, now + 1, spin)
		BallView:step(DT)
		expectTurn(look, CFrame.fromAxisAngle(spin.Unit, spin.Magnitude * DT) * held)
	end)

	-- The mesh can come while the ball is carried: BallLook then dresses the ball again, in a look built facing its own
	-- way, which takes the hand's turn at once.
	it("turns a look that replaces a carried ball's with the hand", function()
		local part = ball :: Part
		local first = newLook(part)
		catch(root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 1)))
		BallView:step(SECONDS)
		BallView:step(DT)
		first:Destroy()
		local dressed = newLook(part)
		dressed.Orientation = Vector3.new(0, -45, 0)
		BallView:step(DT)
		expectTurn(dressed, part.CFrame.Rotation)
	end)

	it("writes nothing while the ball rests where it was drawn with no spin", function()
		local part = ball :: Part
		local look = newLook(part)
		-- Built turned: a look with no turn would match a turn never kept.
		look.Orientation = Vector3.new(10, 20, 30)
		part.Position = Vector3.new(0, 20, 0)
		BallView:step(DT)
		BallView:receive(Vector3.new(0, 20, 0), Vector3.zero, true, now, Vector3.zero)
		for _ = 1, 3 do
			BallView:step(DT)
		end
		local away = CFrame.new(0, 60, 0) * CFrame.Angles(0.3, 0.2, 0.1)
		look.CFrame = away
		for _ = 1, 3 do
			BallView:step(DT)
		end
		expect(look.CFrame).toEqual(away)
	end)

	it("starts a rebuilt ball's look from the turn it was built with", function()
		local look = newLook(ball :: Part)
		BallView:step(DT)
		BallView:receive(Vector3.new(0, 20, 0), Vector3.zero, true, now, Vector3.new(0, 0, 20))
		BallView:step(DT)
		local rebuilt = Instance.new("Part")
		rebuilt.Parent = folder
		local rebuiltLook = newLook(rebuilt)
		rebuiltLook.Orientation = Vector3.new(0, -45, 0)
		local start = rebuiltLook.CFrame.Rotation
		ball = rebuilt
		-- The rebuilt ball seen first: nothing of the old ball's states carries over to it.
		BallView:step(DT)
		BallView:receive(Vector3.new(0, 20, 0), Vector3.zero, true, now + 1, Vector3.new(0, 5, 0))
		BallView:step(DT)
		expectTurn(rebuiltLook, CFrame.fromAxisAngle(Vector3.yAxis, 5 * DT) * start)
		expect(look.Parent).never.toBeNil()
	end)

	it("stops turning when its state is older than the stream carries on, as the ball stops", function()
		local look = newLook(ball :: Part)
		BallView:step(DT)
		BallView:receive(Vector3.new(0, 20, 0), Vector3.zero, true, now - 5, Vector3.new(0, 9, 0))
		BallView:step(DT)
		local stalled = look.CFrame.Rotation
		BallView:step(DT)
		expectTurn(look, stalled)
	end)

	it("still turns by a state exactly as old as the stream carries on", function()
		-- A carry-on a power of two long, so the state's age is exact.
		init({ Network = { ballStream = { maxAgeSeconds = 0.25 } } })
		local look = newLook(ball :: Part)
		BallView:step(DT)
		local start = look.CFrame.Rotation
		BallView:receive(Vector3.new(0, 20, 0), Vector3.zero, true, now - 0.25, Vector3.new(0, 9, 0))
		BallView:step(DT)
		expectTurn(look, CFrame.fromAxisAngle(Vector3.yAxis, 9 * DT) * start)
	end)
end)
