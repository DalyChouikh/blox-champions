--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local MatchClock = require(ReplicatedStorage.Shared.Rules.MatchClock)

local function collector(): ({ number }, (secondsLeft: number) -> ())
	local warnings: { number } = {}
	return warnings, function(secondsLeft: number)
		table.insert(warnings, secondsLeft)
	end
end

describe("MatchClock", function()
	it("counts down from the duration", function()
		local clock = MatchClock.new(300, { 60, 30 })
		local _, onWarning = collector()
		expect(clock.secondsLeft).toBe(300)
		expect(clock:advance(10, onWarning)).toBe(false)
		expect(clock.secondsLeft).toBe(290)
	end)

	it("reports each warning once, when the clock reaches it", function()
		local clock = MatchClock.new(300, { 60, 30 })
		local warnings, onWarning = collector()
		clock:advance(239, onWarning)
		expect(warnings).toEqual({})
		clock:advance(1, onWarning)
		expect(warnings).toEqual({ 60 })
		clock:advance(0.5, onWarning)
		clock:advance(29.5, onWarning)
		expect(warnings).toEqual({ 60, 30 })
	end)

	it("reports several warnings crossed in one step, highest first, from a frozen list in any order", function()
		local clock = MatchClock.new(300, table.freeze({ 30, 60 }))
		local warnings, onWarning = collector()
		clock:advance(280, onWarning)
		expect(warnings).toEqual({ 60, 30 })
	end)

	it("never reports a warning at or above the duration", function()
		local clock = MatchClock.new(60, { 60, 30 })
		local warnings, onWarning = collector()
		clock:advance(60, onWarning)
		expect(warnings).toEqual({ 30 })
	end)

	it("returns true once when time runs out and stops at zero", function()
		local clock = MatchClock.new(300, {})
		local _, onWarning = collector()
		expect(clock:advance(299, onWarning)).toBe(false)
		expect(clock:advance(5, onWarning)).toBe(true)
		expect(clock.secondsLeft).toBe(0)
		expect(clock:advance(1, onWarning)).toBe(false)
		expect(clock.secondsLeft).toBe(0)
	end)

	it("counts up in overtime without warnings", function()
		local clock = MatchClock.new(300, { 60, 30 })
		local warnings, onWarning = collector()
		clock:advance(300, onWarning)
		clock:startOvertime()
		expect(clock.inOvertime).toBe(true)
		expect(clock:advance(12.5, onWarning)).toBe(false)
		expect(clock.overtimeSeconds).toBe(12.5)
		expect(warnings).toEqual({ 60, 30 })
	end)
end)
