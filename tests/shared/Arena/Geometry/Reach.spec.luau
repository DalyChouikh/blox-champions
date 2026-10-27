--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Reach = require(ReplicatedStorage.Shared.Arena.Geometry.Reach)

local GRAVITY = Fixtures.GRAVITY.Magnitude

describe("Reach.skaterTop", function()
	it("reaches no higher than the higher top plus hardCap squared over twice gravity", function()
		-- The outer wall (28) is the higher top by default.
		expect(Reach.skaterTop(Fixtures.config(), GRAVITY)).toBeCloseTo(28 + 140 ^ 2 / (2 * GRAVITY), 6)
		-- A bank of 30 on a track wide enough for it is the higher top.
		local banked = Fixtures.config({ Arena = { innerBankHeight = 30, trackWidth = 80 } })
		expect(Reach.skaterTop(banked, GRAVITY)).toBeCloseTo(30 + 140 ^ 2 / (2 * GRAVITY), 6)
	end)
end)
