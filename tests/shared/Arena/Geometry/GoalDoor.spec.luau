--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local GoalDoor = require(ReplicatedStorage.Shared.Arena.Geometry.GoalDoor)

local arena = Config.defaults().Arena
-- The default door (Q324): 10 bars a half over the opening's 18 studs, each 1.8 tall, reaching 0.25 past it.
local RADIUS, BARS, PAST = 9, 10, 0.25
local HEIGHT = 2 * RADIUS / BARS

-- How long a bar is whose row is widest `nearest` from the middle.
local function length(nearest: number): number
	return math.sqrt(RADIUS * RADIUS - nearest * nearest) + PAST
end

describe("GoalDoor.bars", function()
	it("stacks each half's bars over the opening, the right half's from the bottom up, then the left half's", function()
		local bars = GoalDoor.bars(arena)
		expect(#bars).toBe(2 * BARS)
		for index, bar in bars do
			local row = (index - 1) % BARS + 1
			expect(bar.shape).toBe("Block")
			expect(bar.cframe.Position.Y).toBeCloseTo(-RADIUS + (row - 0.5) * HEIGHT, 5)
			expect(bar.cframe.Position.Z).toBeCloseTo(0, 5)
			expect(bar.size.Y).toBeCloseTo(HEIGHT, 5)
			expect(bar.size.Z).toBe(arena.goal.panelThickness)
		end
	end)

	it("reaches from the middle to its row's widest chord, past the opening", function()
		local bars = GoalDoor.bars(arena)
		-- The bottom row (-9 to -7.2) is widest at its top, the top row at its bottom; the two middle rows at the
		-- middle.
		expect(bars[1].size.X).toBeCloseTo(length(RADIUS - HEIGHT), 5)
		expect(bars[2].size.X).toBeCloseTo(length(RADIUS - 2 * HEIGHT), 5)
		expect(bars[5].size.X).toBeCloseTo(length(0), 5)
		expect(bars[6].size.X).toBeCloseTo(length(0), 5)
		expect(bars[10].size.X).toBeCloseTo(length(RADIUS - HEIGHT), 5)
		for row = 1, BARS do
			expect(bars[BARS + row].size.X).toBeCloseTo(bars[row].size.X, 5)
		end
	end)

	-- ArenaGlow opens every bar the same way: from its inner end, along its own +X.
	it("points every bar's +X away from the middle, its inner end on the middle", function()
		for index, bar in GoalDoor.bars(arena) do
			local side = if index <= BARS then 1 else -1
			expect(bar.cframe.RightVector.X).toBeCloseTo(side, 5)
			expect(bar.cframe.UpVector.Y).toBeCloseTo(1, 5)
			expect((bar.cframe * Vector3.new(-bar.size.X / 2, 0, 0)).X).toBeCloseTo(0, 5)
		end
	end)

	it("follows the door's settings", function()
		local bars = GoalDoor.bars(Fixtures.config({ Arena = { goal = { door = { bars = 4, past = 0 } } } }).Arena)
		expect(#bars).toBe(8)
		expect(bars[1].size.Y).toBeCloseTo(4.5, 5)
		expect(bars[1].size.X).toBeCloseTo(math.sqrt(RADIUS * RADIUS - 4.5 * 4.5), 5)
		expect(bars[2].size.X).toBeCloseTo(RADIUS, 5)
		-- An odd number of bars: the middle row spans the middle, widest there.
		local odd = GoalDoor.bars(Fixtures.config({ Arena = { goal = { door = { bars = 3, past = 0 } } } }).Arena)
		expect(odd[2].size.X).toBeCloseTo(RADIUS, 5)
		expect(odd[1].size.X).toBeCloseTo(math.sqrt(RADIUS * RADIUS - 3 * 3), 5)
	end)
end)

describe("GoalDoor.reach", function()
	it("is the farthest any bar's corner lies from the opening's centre", function()
		-- The bottom and top rows' outer corners: their length across, the opening's radius up or down.
		expect(GoalDoor.reach(arena)).toBeCloseTo(math.sqrt(length(RADIUS - HEIGHT) ^ 2 + RADIUS ^ 2), 5)
	end)
end)
