--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local BallPull = require(Client.BallPull)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Pull = require(ReplicatedStorage.Shared.Ball.Pull)

local config = Fixtures.config()
local SECONDS = config.Ball.pickupPullSeconds
local CARRY = config.Ball.carryOffset
local DT = SECONDS / 4

local folder: Folder
local ball: Part?

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

local function init(seconds: number)
	BallPull:init({
		Config = Fixtures.config({ Ball = { pickupPullSeconds = seconds } }),
		BallPart = {
			get = function(_self: any): BasePart?
				return ball
			end,
		},
	})
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "BallPullTest"
	folder.Parent = workspace
	local part = Instance.new("Part")
	part.Name = "Ball"
	part.Shape = Enum.PartType.Ball
	part.Parent = folder
	ball = part
	init(SECONDS)
end)

afterEach(function()
	folder:Destroy()
	ball = nil
end)

-- The owner (Q91, Q131, Q132, #311): the server decides a catch at once, but its weld can reach this screen while it
-- still shows the ball flying short of the hand (36.6 studs, measured): each screen draws the pull itself.
describe("BallPull", function()
	it("draws a catch from where this screen last showed the ball into the hand over the pull's time", function()
		local holder = root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		local shown = Vector3.new(30, 3, 4)
		local part = ball :: Part
		part.Position = shown
		BallPull:step(DT)
		local weld = catch(holder)
		local from = holder.CFrame:PointToObjectSpace(shown)
		BallPull:step(DT)
		Fixtures.expectNear(weld.C0.Position, Pull.offset(from, CARRY, DT, SECONDS))
		BallPull:step(DT)
		Fixtures.expectNear(weld.C0.Position, Pull.offset(from, CARRY, 2 * DT, SECONDS))
		BallPull:step(2 * DT)
		Fixtures.expectNear(weld.C0.Position, CARRY)
		-- Then the weld is the server's again: nothing more is written.
		weld.C0 = CFrame.new(1, 2, 3)
		BallPull:step(DT)
		Fixtures.expectNear(weld.C0.Position, Vector3.new(1, 2, 3))
	end)

	it("starts a catch from another carrier's hand where this screen showed it", function()
		local first = root("First", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		local second = root("Second", Vector3.new(-20, 3, 6), Vector3.new(0, 0, -1))
		local part = ball :: Part
		part.Position = Vector3.new(14, 3, 0)
		BallPull:step(DT)
		local weld = catch(first)
		BallPull:step(SECONDS)
		local shown = first.CFrame:PointToWorldSpace(CARRY)
		-- The first carrier lets go and the second catches before this screen draws the ball loose.
		weld:Destroy()
		local handOff = catch(second)
		BallPull:step(DT)
		local from = second.CFrame:PointToObjectSpace(shown)
		Fixtures.expectNear(handOff.C0.Position, Pull.offset(from, CARRY, DT, SECONDS))
	end)

	it("lets go of a pull whose ball was thrown mid-way, and draws a ball it never showed loose where it is", function()
		local holder = root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		local part = ball :: Part
		part.Position = Vector3.new(30, 3, 0)
		BallPull:step(DT)
		local weld = catch(holder)
		BallPull:step(DT)
		weld:Destroy()
		BallPull:step(DT)
		-- A new pull after a rebuild: the new ball part was never shown loose, so the server's spot stands.
		local rebuilt = Instance.new("Part")
		rebuilt.Parent = folder
		ball = rebuilt
		local later = catch(holder)
		BallPull:step(DT)
		Fixtures.expectNear(later.C0.Position, CARRY)
	end)

	it("leaves alone a weld that holds the ball to no carrier", function()
		local part = ball :: Part
		part.Position = Vector3.new(30, 3, 0)
		BallPull:step(DT)
		local weld = Instance.new("Weld")
		weld.Part1 = part
		weld.C0 = CFrame.new(CARRY)
		weld.Parent = part
		BallPull:step(DT)
		Fixtures.expectNear(weld.C0.Position, CARRY)
	end)

	it("puts a catch in the hand at once when the pull takes no time", function()
		init(0)
		local holder = root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		local part = ball :: Part
		part.Position = Vector3.new(30, 3, 0)
		BallPull:step(DT)
		local weld = catch(holder)
		BallPull:step(DT)
		Fixtures.expectNear(weld.C0.Position, CARRY)
	end)

	it("does nothing while there is no ball, and forgets a pull whose ball is gone", function()
		local holder = root("Root", Vector3.new(10, 3, 0), Vector3.new(1, 0, 0))
		local part = ball :: Part
		part.Position = Vector3.new(30, 3, 0)
		BallPull:step(DT)
		local weld = catch(holder)
		BallPull:step(DT)
		ball = nil
		expect(function()
			BallPull:step(DT)
		end).never.toThrow()
		-- Back with the same weld: its pull is over, the server's spot stands.
		ball = part
		weld.C0 = CFrame.new(CARRY)
		BallPull:step(DT)
		Fixtures.expectNear(weld.C0.Position, CARRY)
	end)
end)
