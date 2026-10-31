--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local MatchEngine = require(ReplicatedStorage.Shared.Rules.MatchEngine)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

local ZERO = Vector3.zero
local ON_TARGET_POSITION, ON_TARGET_VELOCITY = Vector3.new(190, 15, 0), Vector3.new(100, 0, 0)
local DEFAULTS = Fixtures.config()
local DURATION, OVERTIME = DEFAULTS.Match.durationSeconds, DEFAULTS.Match.overtimeSeconds
local KICKOFF, CELEBRATION = DEFAULTS.Match.kickoffCountdownSeconds, DEFAULTS.Match.celebrationSeconds
-- Every streak starts at the goal's gate (spec §4.2), so a lap runs from it round to the gate before it.
local GOAL_GATE = DEFAULTS.Arena.goalGateIndex
local GATE_COUNT = Fixtures.GATE_COUNT
local LAP: { number } = table.create(GATE_COUNT)
for offset = 0, GATE_COUNT - 1 do
	LAP[offset + 1] = (GOAL_GATE + offset - 1) % GATE_COUNT + 1
end

local function newEngine(overrides: { [string]: any }?): MatchEngine.MatchEngine
	local engine = MatchEngine.new({
		config = Fixtures.config(overrides),
		arena = Fixtures.arena(),
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
	engine:tick(KICKOFF)
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
	crossGates(engine, LAP)
end

-- Typed so each expected event is checked against the Event union.
local function expectEvents(engine: MatchEngine.MatchEngine, expected: { Types.Event })
	expect(engine:drainEvents()).toEqual(expected)
end

-- Picks up, laps once (the goal opens: +1) and throws through the ring.
local function scoreGoal(engine: MatchEngine.MatchEngine, player: string)
	engine:pickedUp(player, ZERO, ZERO)
	lap(engine)
	engine:ballMoved(Fixtures.throughRing())
end

local function resumePlay(engine: MatchEngine.MatchEngine)
	engine:tick(CELEBRATION)
	engine:tick(KICKOFF)
end

-- Orange leads 1-0, Blue has the ball, and the clock has just hit 0:00.
local function lastChanceEngine(overrides: { [string]: any }?): MatchEngine.MatchEngine
	local engine = liveEngine(overrides)
	scoreGoal(engine, "O1")
	resumePlay(engine)
	engine:pickedUp("B1", ZERO, ZERO)
	engine:tick(DURATION)
	engine:drainEvents()
	return engine
end

-- Blue's goal is open, B1 has thrown the ball at it, and O1 has blocked it; nothing is drained yet after the block.
local function blockedEngine(): MatchEngine.MatchEngine
	local engine = liveEngine()
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

describe("MatchEngine options", function()
	local function creating(arena: any): () -> ()
		return function()
			MatchEngine.new({ config = Fixtures.config(), arena = arena })
		end
	end

	it("rejects an invalid arena layout, naming the field", function()
		local ring = Fixtures.ring()
		local thinGates = Fixtures.gates()
		thinGates[3] = { frame = thinGates[3].frame, width = 0, height = 40 }
		expect(creating({ gates = {}, goal = ring })).toThrow("arena.gates: must contain at least one gate")
		expect(creating({ gates = thinGates, goal = ring })).toThrow("arena.gates[3].width: must be > 0")
		local nanRing = { frame = ring.frame, radius = 0 / 0 }
		expect(creating({ gates = Fixtures.gates(), goal = nanRing })).toThrow("arena.goal.radius: must not be NaN")
		expect(creating({ gates = Fixtures.gates(), goal = { frame = "ring", radius = 3 } })).toThrow(
			"arena.goal.frame: expected CFrame, got string"
		)
	end)

	it("keeps its own frozen copy of the arena, so later changes to the caller's tables have no effect", function()
		local arena = Fixtures.arena()
		local engine = MatchEngine.new({ config = Fixtures.config(), arena = arena })
		engine:addPlayer("B1", "Blue")
		engine:start()
		engine:tick(KICKOFF)
		table.insert(arena.gates, Fixtures.gate(500))
		arena.gates[1] = Fixtures.gate(9999)
		expect(table.isfrozen(arena.gates)).toBe(false)
		engine:pickedUp("B1", ZERO, ZERO)
		engine:drainEvents()
		lap(engine)
		expect(engine:drainEvents()[5]).toMatchObject({ name = "LapCompleted", streak = 1 })
	end)
end)

describe("MatchEngine flow", function()
	it("starts with a kickoff countdown and goes live when it ends", function()
		local engine = newEngine()
		engine:start()
		expectEvents(engine, {
			{ name = "MatchStarted" },
			{ name = "KickoffStarted", countdownSeconds = KICKOFF },
		})
		engine:tick(KICKOFF - 0.5)
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

	it("rejects a second start and a negative, NaN or infinite tick", function()
		local engine = newEngine()
		engine:start()
		expect(function()
			engine:start()
		end).toThrow("MatchEngine: start() called in state Kickoff")
		for _, dt in { -1, 0 / 0, math.huge } do
			expect(function()
				engine:tick(dt)
			end).toThrow("MatchEngine: dt must be a finite non-negative number")
		end
	end)

	it("reports the kickoff or celebration time left and the Last Chance team in snapshots", function()
		local engine = newEngine()
		engine:start()
		engine:tick(1)
		expect(engine:snapshot()).toMatchObject({ state = "Kickoff", phaseSecondsLeft = KICKOFF - 1 })
		local lastChance = lastChanceEngine()
		expect(lastChance:snapshot()).toMatchObject({
			period = "LastChance",
			trailingTeam = "Blue",
			phaseSecondsLeft = 0,
		})
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
		crossGates(engine, { LAP[1], LAP[2] })
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

	it("reports the score tab, the gate count and the next gate in its snapshot", function()
		local engine = liveEngine()
		local snapshot = engine:snapshot()
		expect(snapshot.stats).toEqual(engine:stats())
		expect(snapshot.gateCount).toBe(GATE_COUNT)
		expect(snapshot.nextGate).toBe(GOAL_GATE)
		engine:pickedUp("B1", ZERO, ZERO)
		crossGates(engine, { GOAL_GATE })
		expect(engine:snapshot().nextGate).toBe(LAP[2])
	end)

	it("counts gates only for a possessing team, in order, crossed either way", function()
		local engine = liveEngine()
		engine:ballMoved(Fixtures.throughGate(GOAL_GATE))
		expectEvents(engine, {})
		engine:pickedUp("B1", ZERO, ZERO)
		engine:drainEvents()
		-- The gate after the goal's counts nothing before it; then one out of order; then the next one crossed
		-- backwards counts (the owner, 2026-10-27: a gate counts from its back as from its front).
		crossGates(engine, { LAP[2], LAP[1], LAP[3], LAP[2] })
		local from, to = Fixtures.throughGate(LAP[3])
		engine:ballMoved(to, from)
		expectEvents(engine, {
			{ name = "GateCrossed", team = "Blue", gateIndex = LAP[1], progress = 1 },
			{ name = "GateCrossed", team = "Blue", gateIndex = LAP[2], progress = 2 },
			{ name = "GateCrossed", team = "Blue", gateIndex = LAP[3], progress = 3 },
		})
	end)

	it("lets a carrier just past the goal's gate turn back through it: the lap starts there", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:drainEvents()
		-- Back through the goal's gate: its first marker.
		local from, to = Fixtures.throughGate(GOAL_GATE)
		engine:ballMoved(to, from)
		expectEvents(engine, { { name = "GateCrossed", team = "Blue", gateIndex = GOAL_GATE, progress = 1 } })
		-- Forward through it again counts nothing (it is no longer the next gate); the next gate follows.
		engine:ballMoved(from, to)
		crossGates(engine, { LAP[2] })
		expectEvents(engine, { { name = "GateCrossed", team = "Blue", gateIndex = LAP[2], progress = 2 } })
	end)

	it("starts every streak at the goal's gate, after the kickoff and after a steal", function()
		-- Not the default goal gate, so an engine that ignores goalGateIndex fails.
		local goalGate = GOAL_GATE % GATE_COUNT + 1
		local engine = liveEngine({ Arena = { goalGateIndex = goalGate } })
		expect(engine:snapshot().nextGate).toBe(goalGate)
		engine:pickedUp("B1", ZERO, ZERO)
		engine:drainEvents()
		crossGates(engine, { GOAL_GATE, goalGate })
		expectEvents(engine, { { name = "GateCrossed", team = "Blue", gateIndex = goalGate, progress = 1 } })
		engine:pickedUp("O1", ZERO, ZERO)
		local snapshot = engine:snapshot()
		expect(snapshot.nextGate).toBe(goalGate)
		expect(snapshot.lapProgress).toBe(0)
	end)

	it("completes a lap after four gates in order, crediting the last holder", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:thrown("B1")
		engine:pickedUp("B2", ZERO, ZERO)
		engine:drainEvents()
		lap(engine)
		local events = engine:drainEvents()
		expect(names(events)).toEqual({
			"GateCrossed",
			"GateCrossed",
			"GateCrossed",
			"GateCrossed",
			"LapCompleted",
			"GoalOpened",
		})
		expect(events[5]).toEqual({ name = "LapCompleted", team = "Blue", streak = 1, holder = "B2" })
		expect(engine:stats().players[1]).toMatchObject({ player = "B2", score = 10 })
	end)
end)

describe("MatchEngine goals and points", function()
	-- The owner (#305): the goal opens after 4 markers, a lap from the goal's gate, and a goal then is worth +1.
	it("opens the goal after a lap and scores a +1 goal through it with an assist", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:thrown("B1")
		engine:pickedUp("B2", ZERO, ZERO)
		engine:drainEvents()
		lap(engine)
		local events = engine:drainEvents()
		expect(events[#events]).toEqual({ name = "GoalOpened", team = "Blue" })
		engine:ballMoved(Fixtures.throughRing())
		expectEvents(engine, {
			{ name = "GoalScored", team = "Blue", scorer = "B2", assister = "B1", points = 1 },
			{ name = "AssistAwarded", player = "B1" },
			{ name = "GoalClosed" },
		})
		local snapshot = engine:snapshot()
		expect(snapshot.scores).toEqual({ Blue = 1, Orange = 0 })
		expect(snapshot.state).toBe("Celebration")
	end)

	it("credits the attacking team when a defender deflects the ball in", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		engine:touched("O1", ZERO, ZERO)
		engine:drainEvents()
		engine:ballMoved(Fixtures.throughRing())
		expect(engine:drainEvents()[1]).toEqual({ name = "GoalScored", team = "Blue", scorer = "B1", points = 1 })
	end)

	-- The owner, 2026-10-27: the goal scores from behind as from the front.
	it("scores a ball passing back-to-front through the open ring", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		engine:drainEvents()
		local from, to = Fixtures.throughRing()
		engine:ballMoved(to, from)
		expect(engine:drainEvents()[1]).toEqual({ name = "GoalScored", team = "Blue", scorer = "B1", points = 1 })
	end)

	it("judges the ring before the gates a segment crosses, so the lap that opens the goal cannot score", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		crossGates(engine, table.move(LAP, 1, GATE_COUNT - 1, 1, {}))
		engine:drainEvents()
		-- The lap ends at the gate before the goal's, and the ring hangs in the goal gate's plane: one segment from
		-- before that last gate through the ring completes the lap that opens the goal, and still does not score.
		local lastGate = LAP[GATE_COUNT]
		local beforeLast = Fixtures.throughGate(lastGate)
		local ringFrom, ringTo = Fixtures.throughRing()
		engine:ballMoved(Vector3.new(beforeLast.X, ringFrom.Y, ringFrom.Z), ringTo)
		expectEvents(engine, {
			{ name = "GateCrossed", team = "Blue", gateIndex = lastGate, progress = GATE_COUNT },
			{ name = "LapCompleted", team = "Blue", streak = 1, holder = "B1" },
			{ name = "GoalOpened", team = "Blue" },
			{ name = "GateCrossed", team = "Blue", gateIndex = GOAL_GATE, progress = 1 },
		})
		engine:ballMoved(Fixtures.throughRing())
		expect(names(engine:drainEvents())).toEqual({ "GoalScored", "GoalClosed" })
	end)

	-- The owner (#305): +3 after 8 markers, +5 after 12 and more; laps alone score nothing (no streak point).
	it("scores a goal at +3 after two laps and +5 after three or more, and never for laps alone", function()
		local values = {}
		for laps = 2, 4 do
			local engine = liveEngine({ Match = { pointsToWin = 99 } })
			engine:pickedUp("B1", ZERO, ZERO)
			for _ = 1, laps do
				lap(engine)
			end
			engine:drainEvents()
			engine:ballMoved(Fixtures.throughRing())
			local goal: any = engine:drainEvents()[1]
			table.insert(values, goal.points)
			expect(engine:snapshot().scores).toEqual({ Blue = goal.points, Orange = 0 })
		end
		expect(values).toEqual({ 3, 5, 5 })
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		for _ = 1, 12 do
			lap(engine)
		end
		expect(table.find(names(engine:drainEvents()), "GoalScored")).toBeNil()
		expect(engine:snapshot()).toMatchObject({ state = "Live", scores = { Blue = 0, Orange = 0 } })
	end)

	-- The owner (#305), RC's "first team to 5 points wins instantly": one +5 goal does it from 0.
	it("ends the match at once on a +5 goal from 0", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		for _ = 1, 3 do
			lap(engine)
		end
		engine:ballMoved(Fixtures.throughRing())
		expect(lastEvent(engine)).toMatchObject({ name = "MatchEnded", winner = "Blue" })
	end)

	it("resets for a kickoff after the celebration and ignores play during it", function()
		local engine = liveEngine()
		scoreGoal(engine, "B1")
		engine:drainEvents()
		engine:pickedUp("O1", ZERO, ZERO)
		engine:tick(CELEBRATION - 0.5)
		expectEvents(engine, {})
		engine:tick(0.5)
		expectEvents(engine, { { name = "KickoffStarted", countdownSeconds = KICKOFF } })
		local snapshot = engine:snapshot()
		expect(snapshot.state).toBe("Kickoff")
		expect(snapshot.possessingTeam).toBeNil()
		expect(snapshot.lastHolder).toBeNil()
		expect(snapshot.streak).toBe(0)
		expect(snapshot.goalOpenFor).toBeNil()
	end)

	it("ends the match as soon as a team reaches pointsToWin", function()
		local engine = liveEngine({ Match = { pointsToWin = 1 } })
		engine:pickedUp("B1", ZERO, ZERO)
		engine:thrown("B1")
		engine:pickedUp("B2", ZERO, ZERO)
		lap(engine)
		engine:drainEvents()
		expect(engine:snapshot().winner).toBeNil()
		engine:ballMoved(Fixtures.throughRing())
		local events = engine:drainEvents()
		expect(names(events)).toEqual({ "GoalScored", "AssistAwarded", "GoalClosed", "MatchEnded" })
		local ended: any = events[4]
		expect(ended.winner).toBe("Blue")
		expect(ended.mvp).toBe("B2")
		expect(ended.stats.scores).toEqual({ Blue = 1, Orange = 0 })
		-- A player who joins now learns the result from the snapshot.
		expect(engine:snapshot()).toMatchObject({ state = "Ended", winner = "Blue", mvp = "B2" })
		engine:tick(10)
		engine:pickedUp("O1", ZERO, ZERO)
		expectEvents(engine, {})
	end)
end)

describe("MatchEngine saves and knockdowns", function()
	it("holds a block until the danger has passed, counting one save however often defenders touch", function()
		local engine = liveEngine()
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

	-- The danger is judged on the world's pull (#279). From (180, 15, 0) at (50, 26.16, 0) the ball meets the ring's
	-- plane (x 200) 0.4 s later: at 130.8 back at y 15, the ring's centre; at 196.2 at y 9.77, below its rim (3).
	it("predicts a block on the world's gravity", function()
		local function blocks(overrides: { [string]: any }): boolean
			local engine = liveEngine(overrides)
			engine:pickedUp("B1", ZERO, ZERO)
			lap(engine)
			engine:thrown("B1")
			engine:drainEvents()
			engine:touched("O1", Vector3.new(180, 15, 0), Vector3.new(50, 26.16, 0))
			engine:tick(1.5)
			return table.find(names(engine:drainEvents()), "SaveMade") ~= nil
		end
		expect(blocks({})).toBe(true)
		-- At Roblox's gravity the Uppercut's leap reaches 25.3 studs by its strike's end, so its bend may not go past
		-- that (Config's rule, Q89).
		local roblox = { gravity = 196.2 }
		local uppercut = { seek = { bend = { range = 25 } } }
		expect(blocks({ World = roblox, Actions = { Uppercut = uppercut } })).toBe(false)
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

	it("confirms a block when the match ends at 0:00", function()
		-- Orange leads 2-0 and still has the ball at 0:00, so it wins at once.
		local engine = liveEngine()
		scoreGoal(engine, "O1")
		resumePlay(engine)
		scoreGoal(engine, "O1")
		resumePlay(engine)
		engine:tick(DURATION - 1)
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
		local engine = liveEngine()
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
	it("rejects an unknown id in every player input", function()
		local engine = liveEngine()
		local inputs: { () -> () } = {
			function()
				engine:pickedUp("Ghost", ZERO, ZERO)
			end,
			function()
				engine:touched("Ghost", ZERO, ZERO)
			end,
			function()
				engine:thrown("Ghost")
			end,
			function()
				engine:knockedDown("Ghost", "B1")
			end,
			function()
				engine:knockedDown("B1", "Ghost")
			end,
			function()
				engine:removePlayer("Ghost")
			end,
		}
		for _, input in inputs do
			expect(input).toThrow('MatchEngine: unknown player "Ghost"')
		end
	end)

	it("rejects a throw by a player who is not the last holder", function()
		local engine = liveEngine()
		expect(function()
			engine:thrown("B1")
		end).toThrow('MatchEngine: player "B1" threw the ball without holding it')
		engine:pickedUp("B1", ZERO, ZERO)
		expect(function()
			engine:thrown("B2")
		end).toThrow('MatchEngine: player "B2" threw the ball without holding it')
	end)

	it("ignores departed players, keeping their stats", function()
		local engine = liveEngine()
		engine:knockedDown("O1", "B1")
		engine:removePlayer("O1")
		-- Blue's goal is open and a thrown ball is on target, so every input below would count if O1 were present.
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		engine:thrown("B1")
		engine:drainEvents()
		engine:touched("O1", ON_TARGET_POSITION, ON_TARGET_VELOCITY)
		engine:pickedUp("O1", ON_TARGET_POSITION, ON_TARGET_VELOCITY)
		engine:thrown("O1")
		engine:knockedDown("O1", "B2")
		engine:tick(1.5)
		expectEvents(engine, {})
		expect(engine:snapshot().possessingTeam).toBe("Blue")
		-- Off the score tab (#309) until they return, with their stats.
		local function lineOf(player: string): Types.PlayerStats?
			for _, entry in engine:stats().players do
				if entry.player == player then
					return entry
				end
			end
			return nil
		end
		expect(lineOf("O1")).toBeNil()
		engine:addPlayer("O1", "Orange")
		expect(lineOf("O1")).toMatchObject({ score = 10 })
	end)
end)

describe("MatchEngine clock", function()
	it("runs the clock only during live play by default", function()
		local engine = newEngine()
		engine:start()
		engine:tick(KICKOFF)
		expect(engine:snapshot().secondsLeft).toBe(DURATION)
		engine:tick(10)
		scoreGoal(engine, "B1")
		resumePlay(engine)
		expect(engine:snapshot().secondsLeft).toBe(DURATION - 10)
	end)

	it("also runs the clock during kickoffs when clockPausesDuringKickoff is false", function()
		local engine = newEngine({ Match = { clockPausesDuringKickoff = false } })
		engine:start()
		engine:tick(2)
		expect(engine:snapshot().secondsLeft).toBe(DURATION - 2)
	end)

	it("emits a ClockWarning at each configured threshold", function()
		local engine = liveEngine()
		engine:tick(DURATION - 60)
		expectEvents(engine, { { name = "ClockWarning", secondsLeft = 60 } })
		engine:tick(30)
		expectEvents(engine, { { name = "ClockWarning", secondsLeft = 30 } })
	end)
end)

describe("MatchEngine end of regulation", function()
	it("goes to overtime on a tie without a kickoff, counting its own clock down, and the next goal wins", function()
		local engine = liveEngine()
		engine:tick(DURATION)
		expect(names(engine:drainEvents())).toEqual({ "ClockWarning", "ClockWarning", "OvertimeStarted" })
		local snapshot = engine:snapshot()
		expect(snapshot.state).toBe("Live")
		expect(snapshot.period).toBe("Overtime")
		expect(snapshot.secondsLeft).toBe(OVERTIME)
		engine:tick(5)
		expect(engine:snapshot().secondsLeft).toBe(OVERTIME - 5)
		scoreGoal(engine, "O1")
		expect(lastEvent(engine)).toMatchObject({ name = "MatchEnded", winner = "Orange" })
	end)

	-- The owner (Q95, Q107): overtime warns like regulation, and its 0:00 is a draw whoever has the ball.
	it("ends overtime in a draw at 0:00, after its warnings, with or without a team holding the ball", function()
		local function overtimeRunsOut(engine: MatchEngine.MatchEngine)
			engine:knockedDown("O1", "B1") -- the match's only points, so O1 is the draw's MVP
			engine:tick(DURATION)
			engine:drainEvents()
			engine:tick(OVERTIME)
			local events = engine:drainEvents()
			expect(names(events)).toEqual({ "ClockWarning", "ClockWarning", "MatchEnded" })
			expect(events[3]).toEqual({ name = "MatchEnded", mvp = "O1", stats = engine:stats() })
			local snapshot = engine:snapshot()
			expect(snapshot).toMatchObject({ state = "Ended", period = "Overtime", mvp = "O1" })
			expect(snapshot.winner).toBeNil()
		end
		overtimeRunsOut(liveEngine())
		local held = liveEngine()
		held:pickedUp("B1", ZERO, ZERO)
		overtimeRunsOut(held)
	end)

	it("lets the leader win at 0:00 when the trailing team does not have the ball", function()
		local engine = liveEngine()
		scoreGoal(engine, "O1")
		resumePlay(engine)
		engine:drainEvents()
		engine:tick(DURATION)
		expect(lastEvent(engine)).toMatchObject({ name = "MatchEnded", winner = "Orange" })
	end)

	it(
		"gives the trailing team with the ball a Last Chance; tying sends the match to overtime after a kickoff",
		function()
			local engine = liveEngine()
			scoreGoal(engine, "O1")
			resumePlay(engine)
			engine:pickedUp("B1", ZERO, ZERO)
			engine:drainEvents()
			engine:tick(DURATION)
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
			expect(snapshot.secondsLeft).toBe(OVERTIME)
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

	-- The owner (Q94): one attack at any deficit, so a goal that leaves the trailing team behind ends it too.
	it("gives Last Chance at any deficit, and the leaders win when its goal leaves the trailing team behind", function()
		local engine = liveEngine()
		scoreGoal(engine, "O1")
		resumePlay(engine)
		scoreGoal(engine, "O1")
		resumePlay(engine)
		engine:pickedUp("B1", ZERO, ZERO)
		engine:drainEvents()
		engine:tick(DURATION)
		expect(lastEvent(engine)).toEqual({ name = "LastChanceStarted", team = "Blue" })
		lap(engine)
		engine:drainEvents()
		engine:ballMoved(Fixtures.throughRing())
		local events = engine:drainEvents()
		expect(names(events)).toEqual({ "GoalScored", "GoalClosed", "MatchEnded" })
		expect(events[3]).toMatchObject({ winner = "Orange" })
		expect(engine:snapshot().scores).toEqual({ Blue = 1, Orange = 2 })
	end)

	it("lets the trailing team win when a Last Chance point puts it ahead", function()
		-- Orange leads 1-0, then Blue's +3 goal (two laps) after 0:00 makes it 3-1.
		local engine = liveEngine()
		scoreGoal(engine, "O1")
		resumePlay(engine)
		engine:pickedUp("B1", ZERO, ZERO)
		engine:tick(DURATION)
		expect(engine:snapshot().period).toBe("LastChance")
		lap(engine)
		lap(engine)
		engine:ballMoved(Fixtures.throughRing())
		expect(lastEvent(engine)).toMatchObject({ name = "MatchEnded", winner = "Blue" })
	end)

	it("resolves 0:00 during a kickoff when the clock keeps running", function()
		local engine = liveEngine({
			Match = { clockPausesDuringKickoff = false },
		})
		-- liveEngine's kickoff already ran the clock: a celebration from here ends with 1 s left.
		engine:tick(DURATION - KICKOFF - CELEBRATION - 1)
		scoreGoal(engine, "O1")
		engine:tick(CELEBRATION)
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
				Match = { clockPausesDuringKickoff = false },
			})
			scoreGoal(engine, "O1")
			resumePlay(engine)
			scoreGoal(engine, "O1")
			resumePlay(engine)
			-- liveEngine's kickoff and two celebration + kickoff pairs ran the clock: 1 s left.
			engine:tick(DURATION - KICKOFF - 2 * (CELEBRATION + KICKOFF) - 1)
			scoreGoal(engine, "B1")
			engine:drainEvents()
			engine:tick(CELEBRATION) -- 0:00 during Blue's celebration
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
		lap(engine) -- opens the goal, so the ring is checked every tick too
		engine:drainEvents()
		-- Crosses Gate 1's plane outside its rectangle, so every gate and ring check runs and nothing counts.
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
