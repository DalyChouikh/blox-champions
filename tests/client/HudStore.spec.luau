--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach = JestGlobals.beforeEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudStore = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.HudStore)

beforeEach(function()
	HudStore:init({ Config = Fixtures.config() })
end)

describe("HudStore", function()
	it("applies each snapshot and each batch of rule events to the HUD's state", function()
		HudStore:onSnapshot(Fixtures.matchSnapshot())
		local state = HudStore.state
		expect((state.match :: any).state).toBe("Live")
		HudStore:onEvents({ { name = "GoalScored", team = "Blue", scorer = "1" } })
		expect(state.banner and state.banner.kind).toBe("Goal")
	end)

	it("counts the HUD's clocks on each step", function()
		HudStore:onSnapshot(Fixtures.matchSnapshot({ secondsLeft = 100 }))
		HudStore:step(1)
		expect((HudStore.state.match :: any).secondsLeft).toBe(99)
	end)
end)
