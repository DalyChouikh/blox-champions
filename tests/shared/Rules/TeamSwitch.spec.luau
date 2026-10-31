--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local TeamSwitch = require(ReplicatedStorage.Shared.Rules.TeamSwitch)

local match = Fixtures.config().Match
local closed = Fixtures.config({ Match = { teamSwitching = false } }).Match

describe("TeamSwitch.allowed", function()
	-- The owner (Q104, #310): into any free seat, even if it leaves the teams uneven; never with the ball.
	it("lets a player switch into a free seat, never with the ball, and only where the mode offers it", function()
		expect(TeamSwitch.allowed(match, 0, false)).toBe(true)
		expect(TeamSwitch.allowed(match, match.teamSize - 1, false)).toBe(true)
		expect(TeamSwitch.allowed(match, match.teamSize, false)).toBe(false)
		expect(TeamSwitch.allowed(match, 0, true)).toBe(false)
		expect(TeamSwitch.allowed(closed, 0, false)).toBe(false)
	end)
end)
