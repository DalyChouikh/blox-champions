--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach = JestGlobals.beforeEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudStore = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.HudStore)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

beforeEach(function()
	HudStore:init({ Config = Fixtures.config(), LocalId = "1" })
end)

describe("HudStore", function()
	it("applies each snapshot and each batch of rule events to the HUD's state", function()
		HudStore:onSnapshot(Fixtures.matchSnapshot())
		local state = HudStore.state
		expect((state.match :: any).state).toBe("Live")
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } }))
		expect(state.banner and state.banner.kind).toBe("Goal")
	end)

	it("drops a batch from a frame the latest snapshot already holds", function()
		-- What a joiner gets while it loads: the snapshots first, then the batches (one remote at a time).
		local goal: { Types.Event } = { { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } }
		HudStore:onSnapshot(Fixtures.matchSnapshot(nil, 5))
		HudStore:onEvents(Fixtures.ruleEvents(goal, 4))
		HudStore:onEvents(Fixtures.ruleEvents(goal, 5))
		expect(HudStore.state.banner).toBeNil()
		HudStore:onEvents(Fixtures.ruleEvents(goal, 6))
		local banner = HudStore.state.banner
		expect(banner and banner.kind).toBe("Goal")
	end)

	-- The kickoff's count is the local player's team's (the owner, Q110): Ana, "1", plays for Blue.
	it("shows the kickoff's count for the local player's team", function()
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 5 }))
		local banner = HudStore.state.banner
		expect(banner and banner.team).toBe("Blue")
	end)

	it("counts the HUD's clocks on each step", function()
		HudStore:onSnapshot(Fixtures.matchSnapshot({ secondsLeft = 100 }))
		HudStore:step(1)
		expect((HudStore.state.match :: any).secondsLeft).toBe(99)
	end)
end)
