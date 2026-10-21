--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local MatchEngine = require(ReplicatedStorage.Shared.Rules.MatchEngine)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

local ZERO = Vector3.zero
local ON_TARGET_POSITION, ON_TARGET_VELOCITY = Vector3.new(190, 15, 0), Vector3.new(100, 0, 0)
local SHORT_STREAK = { Match = { lapsToOpenGoal = 1, lapsForStreakPoint = 2 } }

local function newEngine(overrides: { [string]: any }?): MatchEngine.MatchEngine
	local engine = MatchEngine.new({
		config = Fixtures.config(overrides),
		arena = Fixtures.arena(),
		gravity = Fixtures.GRAVITY,
	})
	engine:addPlayer("B1", "Blue")
	engine:addPlayer("B2", "Blue")
	engine:addPlayer("O1", "Orange")
	engine:addPlayer("O2", "Orange")
	return engine
end

local function liveEngine(overrides: { [string]: any }?): MatchEngine.MatchEngine
	local engine = newEngine(overrides)
	engine:start()
	engine:tick(3)
	engine:drainEvents()
	return engine
end

local function names(events: { Types.Event }): { string }
	local result = {}
	for _, event in events do
		table.insert(result, event.name)
	end
	return result
end

local function crossGates(engine: MatchEngine.MatchEngine, gates: { number })
	for _, index in gates do
		engine:ballMoved(Fixtures.throughGate(index))
	end
end

local function lap(engine: MatchEngine.MatchEngine)
	crossGates(engine, { 1, 2, 3, 4 })
end

-- Typed so each expected event is checked against the Event union.
local function expectEvents(engine: MatchEngine.MatchEngine, expected: { Types.Event })
	expect(engine:drainEvents()).toEqual(expected)
end

-- Needs lapsToOpenGoal = 1: picks up, laps once, throws through the ring.
local function scoreGoal(engine: MatchEngine.MatchEngine, player: string)
	engine:pickedUp(player, ZERO, ZERO)
	lap(engine)
	engine:ballMoved(Fixtures.throughRing())
end

local function resumePlay(engine: MatchEngine.MatchEngine)
	engine:tick(3) -- celebration
	engine:tick(3) -- kickoff countdown
end

-- Orange leads 1-0, Blue has the ball, and the clock has just hit 0:00.
local function lastChanceEngine(overrides: { [string]: any }?): MatchEngine.MatchEngine
	local engine = liveEngine(overrides or SHORT_STREAK)
	scoreGoal(engine, "O1")
	resumePlay(engine)
	engine:pickedUp("B1", ZERO, ZERO)
	engine:tick(300)
	engine:drainEvents()
	return engine
end

-- Blue's goal is open, B1 has thrown the ball at it, and O1 has blocked it; nothing is drained yet after the block.
local function blockedEngine(): MatchEngine.MatchEngine
	local engine = liveEngine(SHORT_STREAK)
	engine:pickedUp("B1", ZERO, ZERO)
	lap(engine)
	engine:thrown("B1")
	engine:drainEvents()
	engine:touched("O1", ON_TARGET_POSITION, ON_TARGET_VELOCITY)
	return engine
end

local function lastEvent(engine: MatchEngine.MatchEngine): any
	local events = engine:drainEvents()
	return events[#events]
end

describe("MatchEngine flow", function()
	it("starts with a kickoff countdown and goes live when it ends", function()
		local engine = newEngine()
		engine:start()
		expectEvents(engine, {
			{ name = "MatchStarted" },
			{ name = "KickoffStarted", countdownSeconds = 3 },
		})
		engine:tick(2.5)
		expectEvents(engine, {})
		engine:tick(0.5)
		expectEvents(engine, { { name = "KickoffEnded" } })
		expect(engine:snapshot().state).toBe("Live")
	end)

	it("ignores ball facts before the kickoff ends", function()
		local engine = newEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:start()
		engine:drainEvents()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:ballMoved(Fixtures.throughGate(1))
		expectEvents(engine, {})
		expect(engine:snapshot().possessingTeam).toBeNil()
	end)

	it("rejects a second start and a negative or NaN tick", function()
		local engine = newEngine()
		engine:start()
		expect(function()
			engine:start()
		end).toThrow("MatchEngine: start() called in state Kickoff")
		expect(function()
			engine:tick(-1)
		end).toThrow("MatchEngine: dt must be a non-negative number")
		expect(function()
			engine:tick(0 / 0)
		end).toThrow("MatchEngine: dt must be a non-negative number")
	end)

	it("returns the same frozen empty list when nothing happened", function()
		local engine = liveEngine()
		engine:tick(1)
		local first = engine:drainEvents()
		expect(first).toBe(engine:drainEvents())
		expect(table.isfrozen(first)).toBe(true)
	end)
end)

describe("MatchEngine possession and laps", function()
	it("gives possession on the first pickup and makes an opponent pickup a steal that resets the streak", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		expectEvents(engine, { { name = "PossessionChanged", team = "Blue", player = "B1" } })
		crossGates(engine, { 1, 2 })
		engine:drainEvents()
		engine:pickedUp("O1", ZERO, ZERO)
		expectEvents(engine, {
			{ name = "PossessionChanged", team = "Orange", player = "O1", previousTeam = "Blue" },
			{ name = "Steal", player = "O1", fromTeam = "Blue" },
		})
		local snapshot = engine:snapshot()
		expect(snapshot.streak).toBe(0)
		expect(snapshot.lapProgress).toBe(0)
	end)

	it("keeps possession through a pass", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:drainEvents()
		engine:thrown("B1")
		engine:pickedUp("B2", ZERO, ZERO)
		expectEvents(engine, {})
		local snapshot = engine:snapshot()
		expect(snapshot.possessingTeam).toBe("Blue")
		expect(snapshot.lastHolder).toBe("B2")
	end)

	it("counts gates only for a possessing team, forward and in order", function()
		local engine = liveEngine()
		engine:ballMoved(Fixtures.throughGate(1))
		expectEvents(engine, {})
		engine:pickedUp("B1", ZERO, ZERO)
		engine:drainEvents()
		crossGates(engine, { 2, 4, 3 })
		local from, to = Fixtures.throughGate(4)
		engine:ballMoved(to, from)
		expectEvents(engine, {
			{ name = "GateCrossed", team = "Blue", gateIndex = 2, progress = 1 },
			{ name = "GateCrossed", team = "Blue", gateIndex = 3, progress = 2 },
		})
	end)

	it("completes a lap after four gates in order, crediting the last holder", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:thrown("B1")
		engine:pickedUp("B2", ZERO, ZERO)
		engine:drainEvents()
		lap(engine)
		local events = engine:drainEvents()
		expect(names(events)).toEqual({ "GateCrossed", "GateCrossed", "GateCrossed", "GateCrossed", "LapCompleted" })
		expect(events[5]).toEqual({ name = "LapCompleted", team = "Blue", streak = 1, holder = "B2" })
		expect(engine:stats().players[1]).toMatchObject({ player = "B2", score = 10 })
	end)
end)

describe("MatchEngine goals and points", function()
	it("opens the goal after lapsToOpenGoal laps and scores a goal through it with an assist", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:thrown("B1")
		engine:pickedUp("B2", ZERO, ZERO)
		for _ = 1, 3 do
			lap(engine)
		end
		engine:drainEvents()
		lap(engine)
		local events = engine:drainEvents()
		expect(events[#events]).toEqual({ name = "GoalOpened", team = "Blue" })
		engine:ballMoved(Fixtures.throughRing())
		expectEvents(engine, {
			{ name = "GoalScored", team = "Blue", scorer = "B2", assister = "B1" },
			{ name = "AssistAwarded", player = "B1" },
			{ name = "GoalClosed" },
		})
		local snapshot = engine:snapshot()
		expect(snapshot.scores).toEqual({ Blue = 1, Orange = 0 })
		expect(snapshot.state).toBe("Celebration")
	end)

	it("credits the attacking team when a defender deflects the ball in", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		engine:touched("O1", ZERO, ZERO)
		engine:drainEvents()
		engine:ballMoved(Fixtures.throughRing())
		expect(engine:drainEvents()[1]).toEqual({ name = "GoalScored", team = "Blue", scorer = "B1" })
	end)

	it("never scores a ball passing back-to-front through the ring", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		engine:drainEvents()
		local from, to = Fixtures.throughRing()
		engine:ballMoved(to, from)
		expectEvents(engine, {})
	end)

	it("judges the ring before the gates a segment crosses, so the lap that opens the goal cannot score", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		for _ = 1, 3 do
			crossGates(engine, { 3, 4, 1, 2 })
		end
		crossGates(engine, { 3, 4, 1 })
		engine:drainEvents()
		engine:ballMoved(Fixtures.throughRing())
		expectEvents(engine, {
			{ name = "GateCrossed", team = "Blue", gateIndex = 2, progress = 4 },
			{ name = "LapCompleted", team = "Blue", streak = 4, holder = "B1" },
			{ name = "GoalOpened", team = "Blue" },
		})
		crossGates(engine, { 3, 4, 1 })
		engine:drainEvents()
		engine:ballMoved(Fixtures.throughRing())
		expect(names(engine:drainEvents())).toEqual({ "GoalScored", "GoalClosed" })
	end)

	it("scores a streak point at lapsForStreakPoint and closes the goal", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		engine:drainEvents()
		lap(engine)
		local events = engine:drainEvents()
		expect(names(events)).toEqual({
			"GateCrossed",
			"GateCrossed",
			"GateCrossed",
			"GateCrossed",
			"LapCompleted",
			"StreakPointScored",
			"GoalClosed",
		})
		expect(events[6]).toEqual({ name = "StreakPointScored", team = "Blue", holder = "B1" })
		expect(engine:snapshot().scores).toEqual({ Blue = 1, Orange = 0 })
		expect(engine:stats().players[1]).toMatchObject({ player = "B1", score = 120 })
	end)

	it("resets for a kickoff after the celebration and ignores play during it", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		lap(engine)
		engine:drainEvents()
		engine:pickedUp("O1", ZERO, ZERO)
		engine:tick(2.5)
		expectEvents(engine, {})
		engine:tick(0.5)
		expectEvents(engine, { { name = "KickoffStarted", countdownSeconds = 3 } })
		local snapshot = engine:snapshot()
		expect(snapshot.state).toBe("Kickoff")
		expect(snapshot.possessingTeam).toBeNil()
		expect(snapshot.lastHolder).toBeNil()
		expect(snapshot.streak).toBe(0)
		expect(snapshot.goalOpenFor).toBeNil()
	end)

	it("ends the match as soon as a team reaches pointsToWin", function()
		local engine = liveEngine({ Match = { pointsToWin = 1, lapsToOpenGoal = 1, lapsForStreakPoint = 2 } })
		engine:pickedUp("B1", ZERO, ZERO)
		engine:thrown("B1")
		engine:pickedUp("B2", ZERO, ZERO)
		lap(engine)
		engine:drainEvents()
		engine:ballMoved(Fixtures.throughRing())
		local events = engine:drainEvents()
		expect(names(events)).toEqual({ "GoalScored", "AssistAwarded", "GoalClosed", "MatchEnded" })
		local ended: any = events[4]
		expect(ended.winner).toBe("Blue")
		expect(ended.mvp).toBe("B2")
		expect(ended.stats.scores).toEqual({ Blue = 1, Orange = 0 })
		expect(engine:snapshot().state).toBe("Ended")
		engine:tick(10)
		engine:pickedUp("O1", ZERO, ZERO)
		expectEvents(engine, {})
	end)
end)

describe("MatchEngine saves and knockdowns", function()
	it("holds a block until the danger has passed, counting one save however often defenders touch", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		engine:thrown("B1")
		engine:drainEvents()
		engine:touched("B2", ON_TARGET_POSITION, ON_TARGET_VELOCITY)
		engine:touched("O1", ON_TARGET_POSITION, ON_TARGET_VELOCITY)
		engine:touched("O1", ON_TARGET_POSITION, ON_TARGET_VELOCITY)
		engine:touched("O2", ON_TARGET_POSITION, ON_TARGET_VELOCITY)
		engine:tick(1)
		expectEvents(engine, {})
		engine:tick(0.5)
		expectEvents(engine, { { name = "SaveMade", player = "O1", kind = "Block" } })
	end)

	it("drops a block when the ball still goes in", function()
		local engine = blockedEngine()
		engine:ballMoved(Fixtures.throughRing())
		expect(names(engine:drainEvents())).toEqual({ "GoalScored", "GoalClosed" })
		expect(engine:stats().players[1]).toMatchObject({ player = "B1", goals = 1 })
	end)

	it("confirms a block at the next pickup, and counts a block then the blocker's pickup as one save", function()
		local engine = blockedEngine()
		engine:pickedUp("O1", ZERO, ZERO)
		expectEvents(engine, {
			{ name = "SaveMade", player = "O1", kind = "Block" },
			{ name = "PossessionChanged", team = "Orange", player = "O1", previousTeam = "Blue" },
			{ name = "Steal", player = "O1", fromTeam = "Blue" },
			{ name = "GoalClosed" },
		})
	end)

	it("confirms a block when a streak point stops play", function()
		local engine = blockedEngine()
		lap(engine)
		local events = engine:drainEvents()
		expect(names(events)).toEqual({
			"GateCrossed",
			"GateCrossed",
			"GateCrossed",
			"GateCrossed",
			"LapCompleted",
			"StreakPointScored",
			"SaveMade",
			"GoalClosed",
		})
	end)

	it("confirms a block when the match ends at 0:00", function()
		local engine = liveEngine(SHORT_STREAK)
		scoreGoal(engine, "B1")
		resumePlay(engine)
		scoreGoal(engine, "B1")
		resumePlay(engine)
		engine:tick(299)
		engine:pickedUp("O1", ZERO, ZERO)
		lap(engine)
		engine:thrown("O1")
		engine:drainEvents()
		engine:touched("B1", ON_TARGET_POSITION, ON_TARGET_VELOCITY)
		engine:tick(1)
		local events = engine:drainEvents()
		expect(names(events)).toEqual({ "SaveMade", "MatchEnded" })
		expect(events[1]).toEqual({ name = "SaveMade", player = "B1", kind = "Block" })
	end)

	it("makes a defender's pickup at an open goal a steal save, counted once when it is also a block", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		engine:drainEvents()
		engine:pickedUp("O1", ZERO, ZERO)
		expectEvents(engine, {
			{ name = "SaveMade", player = "O1", kind = "Steal" },
			{ name = "PossessionChanged", team = "Orange", player = "O1", previousTeam = "Blue" },
			{ name = "Steal", player = "O1", fromTeam = "Blue" },
			{ name = "GoalClosed" },
		})
		lap(engine)
		engine:thrown("O1")
		engine:drainEvents()
		engine:pickedUp("B1", ON_TARGET_POSITION, ON_TARGET_VELOCITY)
		local events = engine:drainEvents()
		expect(names(events)).toEqual({ "SaveMade", "PossessionChanged", "Steal", "GoalClosed" })
		expect(events[1]).toEqual({ name = "SaveMade", player = "B1", kind = "Block" })
	end)

	it("scores knockdowns between opponents and ignores teammates", function()
		local engine = liveEngine()
		engine:knockedDown("O1", "B1")
		engine:knockedDown("B1", "B2")
		expectEvents(engine, { { name = "TackleKnockdown", attacker = "O1", victim = "B1" } })
	end)
end)

describe("MatchEngine players", function()
	it("rejects unknown players and ignores departed ones, keeping their stats", function()
		local engine = liveEngine()
		expect(function()
			engine:pickedUp("Ghost", ZERO, ZERO)
		end).toThrow('MatchEngine: unknown player "Ghost"')
		engine:knockedDown("O1", "B1")
		engine:removePlayer("O1")
		engine:pickedUp("O1", ZERO, ZERO)
		engine:knockedDown("O1", "B2")
		expectEvents(engine, { { name = "TackleKnockdown", attacker = "O1", victim = "B1" } })
		expect(engine:snapshot().possessingTeam).toBeNil()
		local departed: Types.PlayerStats? = nil
		for _, entry in engine:stats().players do
			if entry.player == "O1" then
				departed = entry
			end
		end
		expect(departed).toMatchObject({ present = false, score = 10 })
	end)
end)

describe("MatchEngine clock", function()
	it("runs the clock only during live play by default", function()
		local engine = newEngine(SHORT_STREAK)
		engine:start()
		engine:tick(3)
		expect(engine:snapshot().secondsLeft).toBe(300)
		engine:tick(10)
		scoreGoal(engine, "B1")
		resumePlay(engine)
		expect(engine:snapshot().secondsLeft).toBe(290)
	end)

	it("also runs the clock during kickoffs when clockPausesDuringKickoff is false", function()
		local engine = newEngine({ Match = { clockPausesDuringKickoff = false } })
		engine:start()
		engine:tick(2)
		expect(engine:snapshot().secondsLeft).toBe(298)
	end)

	it("emits a ClockWarning at each configured threshold", function()
		local engine = liveEngine()
		engine:tick(240)
		expectEvents(engine, { { name = "ClockWarning", secondsLeft = 60 } })
		engine:tick(30)
		expectEvents(engine, { { name = "ClockWarning", secondsLeft = 30 } })
	end)
end)

describe("MatchEngine end of regulation", function()
	it("goes to golden-goal overtime on a tie without a kickoff, and the next point wins", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:tick(300)
		expect(names(engine:drainEvents())).toEqual({ "ClockWarning", "ClockWarning", "OvertimeStarted" })
		local snapshot = engine:snapshot()
		expect(snapshot.state).toBe("Live")
		expect(snapshot.period).toBe("Overtime")
		engine:tick(5)
		expect(engine:snapshot().overtimeSeconds).toBe(5)
		scoreGoal(engine, "O1")
		expect(lastEvent(engine)).toMatchObject({ name = "MatchEnded", winner = "Orange" })
	end)

	it("lets the leader win at 0:00 when the trailing team does not have the ball", function()
		local engine = liveEngine(SHORT_STREAK)
		scoreGoal(engine, "O1")
		resumePlay(engine)
		engine:drainEvents()
		engine:tick(300)
		expect(lastEvent(engine)).toMatchObject({ name = "MatchEnded", winner = "Orange" })
	end)

	it(
		"gives the trailing team with the ball a Last Chance; tying sends the match to overtime after a kickoff",
		function()
			local engine = liveEngine(SHORT_STREAK)
			scoreGoal(engine, "O1")
			resumePlay(engine)
			engine:pickedUp("B1", ZERO, ZERO)
			engine:drainEvents()
			engine:tick(300)
			expect(engine:drainEvents()[3]).toEqual({ name = "LastChanceStarted", team = "Blue" })
			expect(engine:snapshot().period).toBe("LastChance")
			lap(engine)
			engine:drainEvents()
			engine:ballMoved(Fixtures.throughRing())
			expect(names(engine:drainEvents())).toEqual({ "GoalScored", "GoalClosed", "OvertimeStarted" })
			resumePlay(engine)
			expect(names(engine:drainEvents())).toEqual({ "KickoffStarted", "KickoffEnded" })
			local snapshot = engine:snapshot()
			expect(snapshot.state).toBe("Live")
			expect(snapshot.period).toBe("Overtime")
		end
	)

	it("ends Last Chance with a win for the leader when a leading-team player picks up the ball", function()
		local engine = lastChanceEngine()
		engine:pickedUp("O1", ZERO, ZERO)
		local events = engine:drainEvents()
		expect(names(events)).toEqual({ "PossessionChanged", "Steal", "MatchEnded" })
		expect(events[3]).toMatchObject({ winner = "Orange" })
	end)

	it("keeps Last Chance going while the trailing team keeps the ball, even when it is loose", function()
		local engine = lastChanceEngine()
		engine:thrown("B1")
		engine:touched("O1", ZERO, ZERO)
		engine:pickedUp("B2", ZERO, ZERO)
		engine:tick(5)
		expectEvents(engine, {})
		local snapshot = engine:snapshot()
		expect(snapshot.state).toBe("Live")
		expect(snapshot.period).toBe("LastChance")
		expect(snapshot.secondsLeft).toBe(0)
	end)

	it("with maxDeficit 2, keeps Last Chance after a point that leaves the team behind", function()
		local engine =
			liveEngine({ Match = { lapsToOpenGoal = 1, lapsForStreakPoint = 2, lastChance = { maxDeficit = 2 } } })
		scoreGoal(engine, "O1")
		resumePlay(engine)
		scoreGoal(engine, "O1")
		resumePlay(engine)
		engine:pickedUp("B1", ZERO, ZERO)
		engine:tick(300)
		scoreGoal(engine, "B1")
		resumePlay(engine)
		expect(table.find(names(engine:drainEvents()), "OvertimeStarted")).toBeNil()
		expect(engine:snapshot().period).toBe("LastChance")
		engine:pickedUp("O1", ZERO, ZERO)
		expect(lastEvent(engine)).toMatchObject({ name = "MatchEnded", winner = "Orange" })
	end)

	it("lets the trailing team win when a Last Chance point puts it ahead", function()
		-- Streak points are worth 1 and goals 2: Orange leads 1-0, then Blue's goal after 0:00 makes it 2-1.
		local engine = liveEngine({
			Match = { lapsToOpenGoal = 1, lapsForStreakPoint = 2, pointValue = { goal = 2, streak = 1 } },
		})
		engine:pickedUp("O1", ZERO, ZERO)
		lap(engine)
		lap(engine)
		resumePlay(engine)
		engine:pickedUp("B1", ZERO, ZERO)
		engine:tick(300)
		expect(engine:snapshot().period).toBe("LastChance")
		scoreGoal(engine, "B1")
		expect(lastEvent(engine)).toMatchObject({ name = "MatchEnded", winner = "Blue" })
	end)

	it("resolves 0:00 during a kickoff when the clock keeps running", function()
		local engine = liveEngine({
			Match = { lapsToOpenGoal = 1, lapsForStreakPoint = 2, clockPausesDuringKickoff = false },
		})
		engine:tick(293) -- liveEngine's kickoff already used 3 s: 4 s left
		scoreGoal(engine, "O1")
		engine:tick(3) -- celebration ends with 1 s left
		engine:drainEvents()
		engine:tick(1)
		local events = engine:drainEvents()
		expect(names(events)).toEqual({ "MatchEnded" })
		expect(events[1]).toMatchObject({ winner = "Orange" })
	end)
end)

describe("MatchEngine 0:00 outside live play", function()
	it(
		"judges 0:00 during a celebration with no possessing team, so the team that just scored gets no Last Chance",
		function()
			local engine = liveEngine({
				Match = { lapsToOpenGoal = 1, lapsForStreakPoint = 2, clockPausesDuringKickoff = false },
			})
			scoreGoal(engine, "O1")
			resumePlay(engine)
			scoreGoal(engine, "O1")
			resumePlay(engine)
			engine:tick(284) -- liveEngine's kickoff and two celebration + kickoff pairs used 15 s: 1 s left
			scoreGoal(engine, "B1")
			engine:drainEvents()
			engine:tick(3) -- 0:00 during Blue's celebration
			local events = engine:drainEvents()
			expect(names(events)).toEqual({ "MatchEnded" })
			expect(events[1]).toMatchObject({ winner = "Orange" })
		end
	)
end)

describe("MatchEngine performance", function()
	it("keeps a live tick with ball movement far below the 1 ms server budget", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:drainEvents()
		-- Crosses Gate 1's plane outside its rectangle, so every geometry check runs and nothing counts.
		local from, to = Vector3.new(99, 0, 50), Vector3.new(101, 0, 50)
		local iterations = 10000
		local started = os.clock()
		for _ = 1, iterations do
			engine:tick(1 / 60)
			engine:ballMoved(from, to)
		end
		local averageMilliseconds = (os.clock() - started) / iterations * 1000
		expect(averageMilliseconds).toBeLessThan(0.05)
		expectEvents(engine, {})
	end)
end)
