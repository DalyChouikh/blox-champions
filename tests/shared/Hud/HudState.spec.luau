--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

local config = Fixtures.config()
-- The player this HUD belongs to: Ana, Blue, in Fixtures.matchSnapshot.
local VIEWER = "1"

local function liveState(overrides: { [string]: any }?): HudState.HudState
	local state = HudState.new(config, VIEWER)
	state:applySnapshot(Fixtures.matchSnapshot(overrides))
	return state
end

local function match(state: HudState.HudState): any
	return state.match :: any
end

describe("HudState", function()
	it("starts from a snapshot taken mid-match, names and score tab included", function()
		local snapshot = Fixtures.matchSnapshot({ secondsLeft = 120.5 })
		snapshot.names["9"] = "Gone"
		table.insert(snapshot.match.stats.players, Fixtures.playerStats("9", "Blue", false))
		local state = HudState.new(config, VIEWER)
		state:applySnapshot(snapshot)
		expect(state.names["9"]).toBe("Gone")
		expect(#match(state).stats.players).toBe(3)
		expect(state:clockSeconds()).toBe(121)
		expect(state.version).toBe(1)
	end)

	it("counts the clock down while live and holds it through kickoffs and celebrations", function()
		local live = liveState()
		live:step(1)
		expect(match(live).secondsLeft).toBeCloseTo(119, 6)

		local kickoff = liveState({ state = "Kickoff", phaseSecondsLeft = 3 })
		kickoff:step(1)
		expect(match(kickoff).secondsLeft).toBe(120)
		expect(match(kickoff).phaseSecondsLeft).toBeCloseTo(2, 6)

		local celebration = liveState({ state = "Celebration", phaseSecondsLeft = 3 })
		celebration:step(1)
		expect(match(celebration).secondsLeft).toBe(120)

		local running = HudState.new(Fixtures.config({ Match = { clockPausesDuringKickoff = false } }), VIEWER)
		running:applySnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3 }))
		running:step(1)
		expect(match(running).secondsLeft).toBeCloseTo(119, 6)
	end)

	it("counts overtime down like regulation, and holds 0:00 in Last Chance", function()
		local overtime = liveState({ period = "Overtime", secondsLeft = 180 })
		overtime:step(2.5)
		expect(match(overtime).secondsLeft).toBeCloseTo(177.5, 6)
		expect(overtime:clockSeconds()).toBe(178)

		local lastChance = liveState({ period = "LastChance", secondsLeft = 0, trailingTeam = "Orange" })
		lastChance:step(1)
		expect(lastChance:clockSeconds()).toBe(0)
	end)

	-- The owner (Q92, Q108-Q110): RC's 5-4-3-2-1 in the player's own team colour, then GO <their team> TEAM!.
	it("counts the kickoff down 5-4-3-2-1 for the viewer's team, then says GO to it for bannerSeconds", function()
		local state = liveState()
		state:applyEvents({ { name = "KickoffStarted", countdownSeconds = 5 } })
		expect(state.banner).toEqual({ kind = "Countdown", team = "Blue", value = 5 })
		state:applySnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 5 }))
		expect(state.banner).toEqual({ kind = "Countdown", team = "Blue", value = 5 })
		local version = state.version
		state:step(1.2)
		expect(state.banner).toEqual({ kind = "Countdown", team = "Blue", value = 4 })
		expect(state.version).toBe(version + 1)
		state:step(3)
		expect(state.banner).toEqual({ kind = "Countdown", team = "Blue", value = 1 })
		state:applyEvents({ { name = "KickoffEnded" } })
		expect(state.banner).toEqual({ kind = "Go", team = "Blue" })
		state:step(config.UI.hud.bannerSeconds - 0.01)
		expect(state.banner).toEqual({ kind = "Go", team = "Blue" })
		state:step(0.02)
		expect(state.banner).toBeNil()
	end)

	-- A player who joins as a match starts may hear of its first kickoff before any snapshot lists them.
	it("colours a count raised before the match listed the viewer once a snapshot does", function()
		local state = HudState.new(config, VIEWER)
		state:applyEvents({ { name = "KickoffStarted", countdownSeconds = 5 } })
		expect(state.banner).toEqual({ kind = "Countdown", value = 5 })
		state:applySnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 4.5 }))
		expect(state.banner).toEqual({ kind = "Countdown", team = "Blue", value = 5 })
	end)

	it("counts in no team's colour and says no GO to a viewer the match does not list", function()
		local state = HudState.new(config, "9")
		state:applySnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 5 }))
		expect(state.banner).toEqual({ kind = "Countdown", value = 5 })
		state:applyEvents({ { name = "KickoffEnded" } })
		expect(state.banner).toBeNil()
	end)

	it("shows GOAL!, DENIED!, the clock warnings, LAST CHANCE and OVERTIME for bannerSeconds", function()
		local seconds = config.UI.hud.bannerSeconds
		local cases: { { event: Types.Event, banner: HudState.Banner } } = {
			{
				event = { name = "GoalScored", team = "Blue", scorer = "1", points = 1 },
				banner = { kind = "Goal", team = "Blue" },
			},
			{
				event = { name = "SaveMade", player = "2", kind = "Block" },
				banner = { kind = "Denied", team = "Orange" },
			},
			{ event = { name = "ClockWarning", secondsLeft = 30 }, banner = { kind = "ClockWarning", value = 30 } },
			{
				event = { name = "LastChanceStarted", team = "Orange" },
				banner = { kind = "LastChance", team = "Orange" },
			},
			{ event = { name = "OvertimeStarted" }, banner = { kind = "Overtime" } },
		}
		for _, case in cases do
			local state = liveState()
			state:applyEvents({ case.event })
			expect(state.banner).toEqual(case.banner)
			state:step(seconds - 0.01)
			expect(state.banner).toEqual(case.banner)
			state:step(0.02)
			expect(state.banner).toBeNil()
		end
		local replaced = liveState()
		replaced:applyEvents({ { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } })
		replaced:applyEvents({ { name = "OvertimeStarted" } })
		expect(replaced.banner).toEqual({ kind = "Overtime" })
	end)

	it("holds GOAL! through the celebration, until the kickoff's count replaces it", function()
		local seconds = config.UI.hud.bannerSeconds
		local state = liveState()
		state:applyEvents({ { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } })
		state:applySnapshot(Fixtures.matchSnapshot({ state = "Celebration", phaseSecondsLeft = seconds + 1 }))
		state:step(seconds + 0.5)
		expect(state.banner).toEqual({ kind = "Goal", team = "Blue" })
		state:applyEvents({ { name = "KickoffStarted", countdownSeconds = 5 } })
		expect(state.banner).toEqual({ kind = "Countdown", team = "Blue", value = 5 })
	end)

	it("lists possession changes, laps, the goal opening and points in the feed, newest last", function()
		local state = liveState()
		state:applyEvents({
			{ name = "PossessionChanged", team = "Blue", player = "1" },
			{ name = "LapCompleted", team = "Blue", streak = 1, holder = "1" },
			{ name = "GoalOpened", team = "Blue" },
			{ name = "GoalScored", team = "Blue", scorer = "1", points = 1 },
			{ name = "GoalScored", team = "Orange", scorer = "2", points = 1 },
			{ name = "PossessionChanged", team = "Orange", player = "2", previousTeam = "Blue" },
		})
		local kinds: { string } = {}
		local ids: { number } = {}
		for _, entry in state.feed do
			table.insert(kinds, entry.kind)
			table.insert(ids, entry.id)
		end
		-- feedMaxEntries is 5: the oldest of the six is gone.
		expect(kinds).toEqual({ "Lap", "GoalOpen", "Goal", "Goal", "Possession" })
		expect(ids).toEqual({ 2, 3, 4, 5, 6 })
		expect(state.feed[1].value).toBe(1)
		expect(state.feed[3].player).toBe("1")
		expect(state.feed[5]).toEqual({
			id = 6,
			kind = "Possession",
			team = "Orange",
			player = "2",
			timeLeft = config.UI.hud.feedSeconds,
		})
		state:step(config.UI.hud.feedSeconds + 0.01)
		expect(#state.feed).toBe(0)
	end)

	it("shows the end of the match until the next match starts", function()
		local state = liveState()
		state:applyEvents({ { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } })
		local stats = (match(state) :: any).stats
		state:applyEvents({ { name = "MatchEnded", winner = "Blue", mvp = "1", stats = stats } })
		expect((state.ended :: HudState.Ended).winner).toBe("Blue")
		expect((state.ended :: HudState.Ended).mvp).toBe("1")
		expect(state.banner).toBeNil()
		state:applySnapshot(Fixtures.matchSnapshot({ state = "Ended", winner = "Blue", mvp = "1" }))
		expect(state.ended ~= nil).toBe(true)
		state:applySnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3 }))
		expect(state.ended).toBeNil()
	end)

	it("shows the end screen to a player who joins after the match ended", function()
		local state = HudState.new(config, VIEWER)
		state:applySnapshot(Fixtures.matchSnapshot({ state = "Ended", winner = "Orange", mvp = "2" }))
		local ended = state.ended :: HudState.Ended
		expect(ended ~= nil).toBe(true)
		expect(ended.winner).toBe("Orange")
		expect(ended.mvp).toBe("2")
		expect(ended.stats == match(state).stats).toBe(true)
	end)

	-- The owner (Q95): overtime's 0:00 is a draw, which has no winner.
	it("shows a draw from MatchEnded and from a snapshot of the ended match", function()
		local state = liveState()
		local stats = (match(state) :: any).stats
		state:applyEvents({ { name = "MatchEnded", mvp = "1", stats = stats } })
		local ended = state.ended :: HudState.Ended
		expect(ended ~= nil).toBe(true)
		expect(ended.winner).toBeNil()
		expect(ended.mvp).toBe("1")

		local joined = HudState.new(config, VIEWER)
		joined:applySnapshot(Fixtures.matchSnapshot({ state = "Ended", period = "Overtime", mvp = "2" }))
		local shown = joined.ended :: HudState.Ended
		expect(shown ~= nil).toBe(true)
		expect(shown.winner).toBeNil()
		expect(shown.mvp).toBe("2")
	end)

	it("changes its version only when something it shows changes", function()
		local state = liveState()
		local version = state.version
		state:step(0.1)
		expect(state.version).toBe(version)
		expect(match(state).secondsLeft).toBeCloseTo(119.9, 6)
		state:applyEvents({ { name = "GateCrossed", team = "Blue", gateIndex = 1, progress = 1 } })
		expect(state.version).toBe(version)
		-- A batch counts once, however many of its events change what shows.
		state:applyEvents({
			{ name = "GoalOpened", team = "Blue" },
			{ name = "GateCrossed", team = "Blue", gateIndex = 2, progress = 2 },
		})
		expect(state.version).toBe(version + 1)
	end)

	it("sets the clock at each warning", function()
		local state = liveState({ secondsLeft = 61.3 })
		state:applyEvents({ { name = "ClockWarning", secondsLeft = 60 } })
		expect(match(state).secondsLeft).toBe(60)
	end)
end)
