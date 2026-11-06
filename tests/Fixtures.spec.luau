--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

-- #404 (the owner's Q286): a slow cloud run failed the HUD's step-time test (0.144 and 0.166 ms against 0.1 ms) with
-- nothing changed in the HUD. Each budget stretches by how much slower this machine runs a fixed workload than Studio.
describe("Fixtures: step-time budgets", function()
	it("stretch a budget by how much slower the workload ran, and never shrink one", function()
		local reference = Fixtures.REFERENCE_SECONDS
		expect(Fixtures.budgetScale(reference * 2.5)).toBeCloseTo(2.5, 6)
		expect(Fixtures.budgetScale(reference)).toBe(1)
		expect(Fixtures.budgetScale(reference * 0.4)).toBe(1)
	end)

	it("time the workload by its fastest round, so a round the machine was interrupted in does not count", function()
		local rounds = { 0.003, 0.001, 0.002, 0.005, 0.004 }
		local calls = 0
		local fastest = Fixtures.fastest(#rounds, function(): number
			calls += 1
			return rounds[calls]
		end)
		expect(fastest).toBe(0.001)
		expect(calls).toBe(#rounds)
	end)

	describe("measuring this machine", function()
		local fastest: (rounds: number, measure: () -> number) -> number
		local asked: { number }
		beforeEach(function()
			fastest = Fixtures.fastest
			asked = {}
			Fixtures.fastest = function(rounds: number, measure: () -> number): number
				table.insert(asked, rounds)
				return fastest(rounds, measure)
			end
		end)
		afterEach(function()
			Fixtures.fastest = fastest
		end)

		-- The first test in this file to measure: each spec file measures afresh (Jest loads its modules anew).
		it("happens once per spec file, by the fastest of its rounds, and never reads faster than Studio", function()
			local first = Fixtures.slowness()
			expect(Fixtures.slowness()).toBe(first)
			expect(asked).toEqual({ Fixtures.REFERENCE_ROUNDS })
			expect(first >= 1).toBe(true)
		end)
	end)

	describe("on a machine three times slower than Studio", function()
		local measured: () -> number
		beforeEach(function()
			measured = Fixtures.slowness
			Fixtures.slowness = function(): number
				return 3
			end
		end)
		afterEach(function()
			Fixtures.slowness = measured
		end)

		it("pass a time within three times the budget and fail one past it", function()
			expect(function()
				Fixtures.expectWithinBudget(0.0029, 0.001)
			end).never.toThrow()
			expect(function()
				Fixtures.expectWithinBudget(0.0031, 0.001)
			end).toThrow()
		end)
	end)
end)
