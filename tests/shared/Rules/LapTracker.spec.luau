--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local LapTracker = require(ReplicatedStorage.Shared.Rules.LapTracker)

describe("LapTracker", function()
	it("starts the sequence at the first gate crossed, then accepts only the next gate in order", function()
		local laps = LapTracker.new(Fixtures.gates())
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
		local laps = LapTracker.new(Fixtures.gates())
		for _ = 1, 2 do
			for gate = 1, 4 do
				laps:accept(gate)
			end
		end
		expect(laps.streak).toBe(2)
		expect(laps:accept(2)).toBeNil()
		expect(laps:accept(1)).toBe(1)
	end)

	it("names the next gate once a streak's first gate is crossed", function()
		local laps = LapTracker.new(Fixtures.gates())
		expect(laps.nextGate).toBeNil()
		laps:accept(3)
		expect(laps.nextGate).toBe(4)
		laps:accept(4)
		expect(laps.nextGate).toBe(1)
	end)

	it("clears the streak, progress and sequence on reset", function()
		local laps = LapTracker.new(Fixtures.gates())
		for gate = 1, 4 do
			laps:accept(gate)
		end
		laps:accept(1)
		laps:reset()
		expect(laps.streak).toBe(0)
		expect(laps.progress).toBe(0)
		expect(laps:accept(3)).toBe(1)
	end)

	it("lists the gates a segment crosses forward, in the order the segment meets them", function()
		local laps = LapTracker.new(Fixtures.gates())
		expect(laps:crossedGates(Fixtures.throughGate(2))).toEqual({ 2 })
		expect(laps:crossedGates(Vector3.new(50, 0, 0), Vector3.new(450, 0, 0))).toEqual({ 1, 2, 3, 4 })
		expect(laps:crossedGates(Vector3.new(110, 0, 0), Vector3.new(190, 0, 0))).toBeNil()
		local from, to = Fixtures.throughGate(2)
		expect(laps:crossedGates(to, from)).toBeNil()

		local reversed = LapTracker.new({ Fixtures.gate(300), Fixtures.gate(100) })
		expect(reversed:crossedGates(Vector3.new(50, 0, 0), Vector3.new(350, 0, 0))).toEqual({ 2, 1 })
	end)

	it("reuses one result list between calls, so reporting crossings never allocates", function()
		local laps = LapTracker.new(Fixtures.gates())
		local first = laps:crossedGates(Fixtures.throughGate(1))
		local second = laps:crossedGates(Fixtures.throughGate(2))
		expect(second).toBe(first)
		expect(second).toEqual({ 2 })
	end)

	it("requires at least one gate", function()
		expect(function()
			LapTracker.new({})
		end).toThrow("LapTracker: at least one gate is required")
	end)
end)
