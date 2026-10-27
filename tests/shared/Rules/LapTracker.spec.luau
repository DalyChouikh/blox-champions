--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local LapTracker = require(ReplicatedStorage.Shared.Rules.LapTracker)

-- Any gate but the first, so a tracker that starts at gate 1 fails.
local START = 3

local function newTracker(): LapTracker.LapTracker
	return LapTracker.new(Fixtures.gates(), START)
end

describe("LapTracker", function()
	it("starts every streak at its start gate, then accepts only the next gate in order", function()
		local laps = newTracker()
		expect(laps:accept(1)).toBeNil()
		expect(laps:accept(4)).toBeNil()
		expect(laps:accept(3)).toBe(1)
		expect(laps:accept(1)).toBeNil()
		expect(laps:accept(4)).toBe(2)
		expect(laps:accept(4)).toBeNil()
		expect(laps:accept(1)).toBe(3)
		expect(laps.streak).toBe(0)
		expect(laps:accept(2)).toBe(4)
		expect(laps.streak).toBe(1)
		expect(laps.progress).toBe(0)
	end)

	it("keeps the sequence across laps", function()
		local laps = newTracker()
		for _ = 1, 2 do
			for _, gate in { 3, 4, 1, 2 } do
				laps:accept(gate)
			end
		end
		expect(laps.streak).toBe(2)
		expect(laps:accept(2)).toBeNil()
		expect(laps:accept(3)).toBe(1)
	end)

	it("names its start gate as the next gate from the start, then each next one in turn", function()
		local laps = newTracker()
		expect(laps.nextGate).toBe(START)
		laps:accept(3)
		expect(laps.nextGate).toBe(4)
		laps:accept(4)
		expect(laps.nextGate).toBe(1)
	end)

	it("starts again at its start gate on reset, clearing the streak and progress", function()
		local laps = newTracker()
		for _, gate in { 3, 4, 1, 2, 3 } do
			laps:accept(gate)
		end
		laps:reset()
		expect(laps.streak).toBe(0)
		expect(laps.progress).toBe(0)
		expect(laps.nextGate).toBe(START)
		expect(laps:accept(4)).toBeNil()
		expect(laps:accept(3)).toBe(1)
	end)

	it("lists the gates a segment crosses either way, in the order the segment meets them", function()
		local laps = newTracker()
		expect(laps:crossedGates(Fixtures.throughGate(2))).toEqual({ 2 })
		expect(laps:crossedGates(Vector3.new(50, 0, 0), Vector3.new(450, 0, 0))).toEqual({ 1, 2, 3, 4 })
		expect(laps:crossedGates(Vector3.new(110, 0, 0), Vector3.new(190, 0, 0))).toBeNil()
		local from, to = Fixtures.throughGate(2)
		expect(laps:crossedGates(to, from)).toEqual({ 2 })
		expect(laps:crossedGates(Vector3.new(450, 0, 0), Vector3.new(50, 0, 0))).toEqual({ 4, 3, 2, 1 })

		local reversed = LapTracker.new({ Fixtures.gate(300), Fixtures.gate(100) }, 1)
		expect(reversed:crossedGates(Vector3.new(50, 0, 0), Vector3.new(350, 0, 0))).toEqual({ 2, 1 })
	end)

	it("reuses one result list between calls, so reporting crossings never allocates", function()
		local laps = newTracker()
		local first = laps:crossedGates(Fixtures.throughGate(1))
		local second = laps:crossedGates(Fixtures.throughGate(2))
		expect(second).toBe(first)
		expect(second).toEqual({ 2 })
	end)

	it("requires at least one gate", function()
		expect(function()
			LapTracker.new({}, 1)
		end).toThrow("LapTracker: at least one gate is required")
	end)

	it("requires a start gate among its gates", function()
		for _, start in { 1, Fixtures.GATE_COUNT } do
			expect(LapTracker.new(Fixtures.gates(), start).nextGate).toBe(start)
		end
		for _, start in { 0, Fixtures.GATE_COUNT + 1, 1.5 } do
			expect(function()
				LapTracker.new(Fixtures.gates(), start)
			end).toThrow(`LapTracker: the start gate must be one of the {Fixtures.GATE_COUNT} gates (got {start})`)
		end
	end)
end)
