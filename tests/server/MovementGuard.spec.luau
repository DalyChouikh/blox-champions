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

local folder: Folder
local rig: Model
local holders: { { player: string, root: BasePart } }
local characterService: any
local logs: { string }
local now: number

-- Advances the fake clock by one sample and runs the guard's step.
local function tick()
	now += SAMPLE
	MovementGuard:step(SAMPLE)
end

local function moveTo(z: number)
	rig:PivotTo(CFrame.new(0, 3, z))
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "MovementGuardTest"
	folder.Parent = workspace
	rig = Fixtures.rig(folder, "Skater", CFrame.new(0, 3, 0))
	holders = { { player = "1", root = rig.PrimaryPart :: BasePart } }
	characterService = {
		holders = function(): { { player: string, root: BasePart } }
			return holders
		end,
		placed = Signal.new(),
		characterRemoved = Signal.new(),
	}
	logs = {}
	now = 0
	MovementGuard:init({
		Config = config,
		CharacterService = characterService,
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
		-- 30 studs a sample is the most skating allows; 50 studs a sample is three strikes.
		moveTo(-30)
		tick()
		moveTo(-80)
		tick()
		moveTo(-130)
		tick()
		moveTo(-180)
		tick()
		expect((rig.PrimaryPart :: BasePart).Position.Z).toBeCloseTo(-30, 3)
		expect(#logs).toBe(1)
		expect(string.find(logs[1], "1", 1, true) ~= nil).toBe(true)
	end)

	it("leaves frozen skaters alone and trusts the server's placements", function()
		local root = rig.PrimaryPart :: BasePart
		root.Anchored = true
		moveTo(500)
		tick()
		expect(#logs).toBe(0)

		root.Anchored = false
		characterService.placed:Fire("1")
		moveTo(1000)
		tick()
		expect(#logs).toBe(0)
	end)

	it("forgets a character that is gone", function()
		characterService.characterRemoved:Fire("1")
		moveTo(500)
		tick()
		expect(#logs).toBe(0)
	end)
end)
