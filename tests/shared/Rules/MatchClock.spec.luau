--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
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

	it("runs while play is live, and through kickoffs and celebrations only when they don't pause it", function()
		local paused = Fixtures.config().Match
		expect(MatchClock.runs(paused, "Live")).toBe(true)
		expect(MatchClock.runs(paused, "Kickoff")).toBe(false)
		expect(MatchClock.runs(paused, "Celebration")).toBe(false)
		expect(MatchClock.runs(paused, "Waiting")).toBe(false)
		expect(MatchClock.runs(paused, "Ended")).toBe(false)
		local running = Fixtures.config({ Match = { clockPausesDuringKickoff = false } }).Match
		expect(MatchClock.runs(running, "Kickoff")).toBe(true)
		expect(MatchClock.runs(running, "Celebration")).toBe(true)
		expect(MatchClock.runs(running, "Waiting")).toBe(false)
		expect(MatchClock.runs(running, "Ended")).toBe(false)
	end)

	-- The owner (Q95, Q107): overtime counts its own length down to a draw, with regulation's warnings again.
	it("counts overtime down from its own length, warns again, and runs out once", function()
		local clock = MatchClock.new(300, { 60, 30 })
		local warnings, onWarning = collector()
		expect(clock:advance(300, onWarning)).toBe(true)
		clock:startOvertime(180)
		expect(clock.secondsLeft).toBe(180)
		expect(clock:advance(119, onWarning)).toBe(false)
		expect(warnings).toEqual({ 60, 30 })
		expect(clock:advance(1, onWarning)).toBe(false)
		expect(warnings).toEqual({ 60, 30, 60 })
		expect(clock:advance(70, onWarning)).toBe(true)
		expect(warnings).toEqual({ 60, 30, 60, 30 })
		expect(clock.secondsLeft).toBe(0)
		expect(clock:advance(1, onWarning)).toBe(false)
	end)
end)
