--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local MovementGuard = require(ServerScriptService.Server.MovementGuard)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local config = Config.defaults()
local SAMPLE = config.Network.guardSampleSeconds
-- Down the middle of a straight of the default arena, 60 studs from its long axis, 3 studs over the floor.
local LANE_Z = 60
local START_X = -75

local folder: Folder
local rig: Model
local holders: { { player: string, root: BasePart } }
local characterService: any
local logs: { string }
-- Who the guard asked CharacterService to place on their spawn, and frozen or not.
local placements: { { player: string, frozen: boolean } }
local now: number
-- A fake BallService: who carries the ball, and what the guard asked of it.
local ball: { state: { carrier: string? }, drops: { Vector3 }, jumps: number }

-- Advances the fake clock by one sample and runs the guard's step.
local function tick()
	now += SAMPLE
	MovementGuard:step(SAMPLE)
end

-- Along the straight, inside the arena.
local function moveTo(x: number)
	rig:PivotTo(CFrame.new(x, 3, LANE_Z))
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "MovementGuardTest"
	folder.Parent = workspace
	rig = Fixtures.rig(folder, "Skater", CFrame.new(START_X, 3, LANE_Z))
	holders = { { player = "1", root = Fixtures.root(rig) } }
	placements = {}
	characterService = {
		holders = function(): { { player: string, root: BasePart } }
			return holders
		end,
		place = function(_self: any, player: string, frozen: boolean)
			table.insert(placements, { player = player, frozen = frozen })
		end,
		placed = Signal.new(),
		characterRemoved = Signal.new(),
	}
	logs = {}
	now = 0
	ball = { state = { carrier = nil }, drops = {}, jumps = 0 }
	local fakeBall = {
		state = ball.state,
		dropAt = function(_self: any, position: Vector3)
			table.insert(ball.drops, position)
			ball.state.carrier = nil
		end,
		jumped = function(_self: any)
			ball.jumps += 1
		end,
	}
	MovementGuard:init({
		Config = config,
		CharacterService = characterService,
		BallService = fakeBall,
		Log = function(line: string)
			table.insert(logs, line)
		end,
		Clock = function(): number
			return now
		end,
	})
	-- The first sample of a skater is a reset: the guard learns where they stand.
	tick()
end)
afterEach(function()
	folder:Destroy()
end)

describe("MovementGuard", function()
	it("returns a cheater to their last valid place and logs it", function()
		-- 36.3 studs a sample is the most skating allows (121 × 1.2 × 0.25); 50 studs a sample is three strikes.
		moveTo(START_X + 30)
		tick()
		moveTo(START_X + 80)
		tick()
		moveTo(START_X + 130)
		tick()
		moveTo(START_X + 180)
		tick()
		expect(Fixtures.root(rig).Position.X).toBeCloseTo(START_X + 30, 3)
		expect(#logs).toBe(1)
		expect(string.find(logs[1], "1", 1, true) ~= nil).toBe(true)
		expect(#placements).toBe(0)
	end)

	-- Any way out the game has not ruled out (#181, the owner's safety net): a skater stuck far under the arena was
	-- never brought back (#177).
	it("puts a skater found outside the arena back on their team's spawn, and logs it", function()
		-- Within guardOutsideMargin (2) of the floor: still inside.
		rig:PivotTo(CFrame.new(START_X, -1.5, LANE_Z))
		tick()
		expect(#placements).toBe(0)
		-- 13 studs under the floor: a fall, which the speed rule never judges.
		rig:PivotTo(CFrame.new(START_X, -10, LANE_Z))
		tick()
		expect(placements).toEqual({ { player = "1", frozen = false } })
		expect(#logs).toBe(1)
		expect(string.find(logs[1], "1", 1, true) ~= nil).toBe(true)
		expect(string.find(logs[1], "outside the arena", 1, true) ~= nil).toBe(true)
	end)

	it("returns a carrier with the ball, telling the ball the server moved it", function()
		ball.state.carrier = "1"
		moveTo(START_X + 30)
		tick()
		moveTo(START_X + 200)
		tick()
		expect(Fixtures.root(rig).Position.X).toBeCloseTo(START_X + 30, 3)
		expect(ball.jumps).toBe(1)
		expect(ball.state.carrier).toBe("1")
	end)

	-- The owner's choice (2026-10-25): the ball stays where its carrier left the arena, so leaving on purpose never
	-- takes the ball home.
	it("drops a carrier's ball where they were last inside the arena before placing them on their spawn", function()
		ball.state.carrier = "1"
		moveTo(START_X + 20)
		tick()
		rig:PivotTo(CFrame.new(START_X + 20, -10, LANE_Z))
		tick()
		expect(#ball.drops).toBe(1)
		Fixtures.expectNear(ball.drops[1], Vector3.new(START_X + 20, 3, LANE_Z))
		expect(placements).toEqual({ { player = "1", frozen = false } })
		expect(ball.jumps).toBe(0)
	end)

	it(
		"drops the ball where the carrier is when they leave the arena before a sample inside since a placement",
		function()
			moveTo(START_X + 20)
			tick()
			characterService.placed:Fire("1")
			ball.state.carrier = "1"
			rig:PivotTo(CFrame.new(START_X, -10, LANE_Z))
			tick()
			Fixtures.expectNear(ball.drops[1], Vector3.new(START_X, -10, LANE_Z))
		end
	)

	it(
		"judges a jump out of the arena by the speed rule first, returning the skater instead of placing them",
		function()
			-- 100 studs sideways in one sample, past the outer wall: beyond guardTeleportFactor times the allowance.
			rig:PivotTo(CFrame.new(START_X, 3, LANE_Z + 100))
			tick()
			expect(#placements).toBe(0)
			expect(Fixtures.root(rig).Position.Z).toBeCloseTo(LANE_Z, 3)
			expect(#logs).toBe(1)
		end
	)

	it("leaves frozen skaters alone, wherever they are, and trusts the server's placements", function()
		local root = Fixtures.root(rig)
		root.Anchored = true
		moveTo(500)
		tick()
		expect(#logs).toBe(0)
		expect(#placements).toBe(0)

		root.Anchored = false
		characterService.placed:Fire("1")
		-- On the other straight: far, but inside the arena.
		rig:PivotTo(CFrame.new(0, 3, -LANE_Z))
		tick()
		expect(#logs).toBe(0)
	end)

	it("forgets a character that is gone", function()
		characterService.characterRemoved:Fire("1")
		rig:PivotTo(CFrame.new(0, 3, -LANE_Z))
		tick()
		expect(#logs).toBe(0)
	end)
end)
