--!strict
-- The rules of one match composed into a deterministic state machine (spec §4.6). Callers feed it facts — time
-- passing, the ball's per-tick movement, pickups, touches, throws, knockdowns — and drain the ordered events
-- (spec §4.7) once per tick. It never touches an Instance, so the same inputs always produce the same events.

local AssistTracker = require(script.Parent.AssistTracker)
local Config = require(script.Parent.Parent.Config)
local Crossing = require(script.Parent.Crossing)
local GoalJudge = require(script.Parent.GoalJudge)
local LapTracker = require(script.Parent.LapTracker)
local MatchClock = require(script.Parent.MatchClock)
local MatchOutcome = require(script.Parent.MatchOutcome)
local Possession = require(script.Parent.Possession)
local SaveDetector = require(script.Parent.SaveDetector)
local ScoreKeeper = require(script.Parent.ScoreKeeper)
local Team = require(script.Parent.Team)
local Types = require(script.Parent.Types)

type Team = Team.Team
type PlayerId = Types.PlayerId
type Event = Types.Event

export type ArenaLayout = { gates: { Crossing.Rectangle }, goal: Crossing.Disc }

export type EngineOptions = { config: Config.GameConfig, arena: ArenaLayout, gravity: Vector3 }

export type Snapshot = {
	state: Types.MatchState,
	period: Types.Period,
	secondsLeft: number,
	overtimeSeconds: number,
	scores: { [Team]: number },
	possessingTeam: Team?,
	lastHolder: PlayerId?,
	streak: number,
	lapProgress: number,
	goalOpenFor: Team?,
}

-- Returned on quiet ticks so draining never allocates.
local NO_EVENTS: { Event } = {}
table.freeze(NO_EVENTS)

local MatchEngine = {}
MatchEngine.__index = MatchEngine

type Fields = {
	_config: Config.GameConfig,
	_state: Types.MatchState,
	_period: Types.Period,
	_phaseTimeLeft: number,
	_now: number,
	_ballThrown: boolean,
	_events: { Event },
	_possession: Possession.Possession,
	_laps: LapTracker.LapTracker,
	_goal: GoalJudge.GoalJudge,
	_clock: MatchClock.MatchClock,
	_assists: AssistTracker.AssistTracker,
	_saves: SaveDetector.SaveDetector,
	_scores: ScoreKeeper.ScoreKeeper,
}

export type MatchEngine = typeof(setmetatable({} :: Fields, MatchEngine))

-- Every event goes to the score keeper as it is emitted, so scores are current for the next rule check.
local function emit(self: MatchEngine, event: Event)
	table.insert(self._events, event)
	self._scores:apply(event)
end

-- The player's team, or nil for a player who left. An id that was never added is a wiring bug: fail fast.
local function activeTeam(self: MatchEngine, player: PlayerId): Team?
	local stats = self._scores:player(player)
	if stats == nil then
		error(`MatchEngine: unknown player "{player}"`, 0)
	end
	return if stats.present then stats.team else nil
end

local function closeGoal(self: MatchEngine)
	if self._goal:close() then
		emit(self, { name = "GoalClosed" })
	end
end

local function kickoff(self: MatchEngine)
	self._possession:reset()
	self._laps:reset()
	self._assists:reset()
	closeGoal(self)
	self._ballThrown = false
	self._state = "Kickoff"
	self._phaseTimeLeft = self._config.Match.kickoffCountdownSeconds
	emit(self, { name = "KickoffStarted", countdownSeconds = self._phaseTimeLeft })
end

local function endMatch(self: MatchEngine, winner: Team)
	self._state = "Ended"
	emit(self, { name = "MatchEnded", winner = winner, mvp = self._scores:mvp(winner), stats = self._scores:stats() })
end

local function pointScored(self: MatchEngine, team: Team)
	closeGoal(self)
	local match = self._config.Match
	local winner: Team? = MatchOutcome.afterPoint(self._period, self._scores:teamScores(), team, match.pointsToWin)
	if winner ~= nil then
		endMatch(self, winner)
		return
	end
	self._state = "Celebration"
	self._phaseTimeLeft = match.celebrationSeconds
end

local function goalScored(self: MatchEngine)
	-- The goal only opens for the possessing team, which always has a last holder.
	local team: Team = self._possession.team :: Team
	local scorer: PlayerId = self._possession.lastHolder :: PlayerId
	local assister = self._assists:assister(scorer, self._now)
	emit(self, { name = "GoalScored", team = team, scorer = scorer, assister = assister })
	if assister ~= nil then
		emit(self, { name = "AssistAwarded", player = assister })
	end
	pointScored(self, team)
end

-- Returns true when the lap earned the streak point, which stops play.
local function lapCompleted(self: MatchEngine, team: Team): boolean
	local streak = self._laps.streak
	local holder = self._possession.lastHolder :: PlayerId
	emit(self, { name = "LapCompleted", team = team, streak = streak, holder = holder })
	if self._goal:lapCompleted(team, streak) then
		emit(self, { name = "GoalOpened", team = team })
	end
	if streak >= self._config.Match.lapsForStreakPoint then
		emit(self, { name = "StreakPointScored", team = team, holder = holder })
		pointScored(self, team)
		return true
	end
	return false
end

function MatchEngine.new(options: EngineOptions): MatchEngine
	local config = options.config
	local match = config.Match
	return setmetatable(
		{
			_config = config,
			_state = "Waiting",
			_period = "Regulation",
			_phaseTimeLeft = 0,
			_now = 0,
			_ballThrown = false,
			_events = {},
			_possession = Possession.new(),
			_laps = LapTracker.new(options.arena.gates),
			_goal = GoalJudge.new(options.arena.goal, match.lapsToOpenGoal),
			_clock = MatchClock.new(match.durationSeconds, config.UI.clockWarnings),
			_assists = AssistTracker.new(config.Scoring.assistWindowSeconds),
			_saves = SaveDetector.new(options.arena.goal, options.gravity, config.Scoring.saveLookaheadSeconds),
			_scores = ScoreKeeper.new(config),
		} :: Fields,
		MatchEngine
	)
end

function MatchEngine.addPlayer(self: MatchEngine, player: PlayerId, team: Team)
	self._scores:addPlayer(player, team)
end

function MatchEngine.removePlayer(self: MatchEngine, player: PlayerId)
	self._scores:removePlayer(player)
end

function MatchEngine.start(self: MatchEngine)
	if self._state ~= "Waiting" then
		error(`MatchEngine: start() called in state {self._state}`, 0)
	end
	emit(self, { name = "MatchStarted" })
	kickoff(self)
end

function MatchEngine.tick(self: MatchEngine, dt: number)
	-- Written so NaN fails too.
	if not (dt >= 0) then
		error("MatchEngine: dt must be a non-negative number", 0)
	end
	local state = self._state
	if state == "Waiting" or state == "Ended" then
		return
	end
	self._now += dt

	if state == "Kickoff" or state == "Celebration" then
		self._phaseTimeLeft -= dt
		if self._phaseTimeLeft <= 0 then
			if state == "Kickoff" then
				self._state = "Live"
				emit(self, { name = "KickoffEnded" })
			else
				kickoff(self)
			end
		end
	end
end

function MatchEngine.ballMoved(self: MatchEngine, from: Vector3, to: Vector3)
	if self._state ~= "Live" then
		return
	end
	-- The ring is judged with the goal's state before this segment's gate crossings: while closed, its panel
	-- stops the ball, even if the same segment completes the lap that opens it.
	if self._goal:scored(from, to) then
		goalScored(self)
		return
	end
	local team: Team? = self._possession.team
	if team == nil then
		return
	end
	local crossed = self._laps:crossedGates(from, to)
	if crossed == nil then
		return
	end
	for _, gateIndex in crossed do
		local progress = self._laps:accept(gateIndex)
		if progress ~= nil then
			emit(self, { name = "GateCrossed", team = team, gateIndex = gateIndex, progress = progress })
			if progress == self._laps.gateCount and lapCompleted(self, team) then
				return
			end
		end
	end
end

function MatchEngine.pickedUp(self: MatchEngine, player: PlayerId, ballPosition: Vector3, ballVelocity: Vector3)
	local team: Team? = activeTeam(self, player)
	if team == nil or self._state ~= "Live" then
		return
	end

	-- Judged on the state before the pickup changes it.
	local openFor = self._goal.openFor
	if openFor ~= nil and team ~= openFor then
		local kind: Types.SaveKind? = self._saves:classify("Pickup", self._ballThrown, ballPosition, ballVelocity)
		if kind ~= nil then
			emit(self, { name = "SaveMade", player = player, kind = kind })
		end
	end
	self._ballThrown = false

	local previous: Team? = self._possession.team
	if self._possession:pickUp(player, team) then
		self._laps:reset()
		self._assists:reset()
		emit(self, { name = "PossessionChanged", team = team, player = player, previousTeam = previous })
		if previous ~= nil then
			emit(self, { name = "Steal", player = player, fromTeam = previous })
		end
		closeGoal(self)
	end
	self._assists:pickedUp(player, self._now)
end

function MatchEngine.touched(self: MatchEngine, player: PlayerId, ballPosition: Vector3, ballVelocity: Vector3)
	local team: Team? = activeTeam(self, player)
	if team == nil or self._state ~= "Live" or not self._ballThrown then
		return
	end
	local openFor = self._goal.openFor
	if openFor == nil or team == openFor then
		return
	end
	if self._saves:classify("Touch", true, ballPosition, ballVelocity) == "Block" then
		-- One save per throw, however many ticks the defender stays in contact.
		self._ballThrown = false
		emit(self, { name = "SaveMade", player = player, kind = "Block" })
	end
end

function MatchEngine.thrown(self: MatchEngine, player: PlayerId)
	if activeTeam(self, player) ~= nil and self._state == "Live" then
		self._ballThrown = true
	end
end

function MatchEngine.knockedDown(self: MatchEngine, attacker: PlayerId, victim: PlayerId)
	local attackerTeam: Team? = activeTeam(self, attacker)
	local victimTeam: Team? = activeTeam(self, victim)
	if attackerTeam == nil or victimTeam == nil or attackerTeam == victimTeam or self._state ~= "Live" then
		return
	end
	emit(self, { name = "TackleKnockdown", attacker = attacker, victim = victim })
end

function MatchEngine.drainEvents(self: MatchEngine): { Event }
	local events = self._events
	if #events == 0 then
		return NO_EVENTS
	end
	self._events = {}
	return events
end

function MatchEngine.snapshot(self: MatchEngine): Snapshot
	return {
		state = self._state,
		period = self._period,
		secondsLeft = self._clock.secondsLeft,
		overtimeSeconds = self._clock.overtimeSeconds,
		scores = self._scores:teamScores(),
		possessingTeam = self._possession.team,
		lastHolder = self._possession.lastHolder,
		streak = self._laps.streak,
		lapProgress = self._laps.progress,
		goalOpenFor = self._goal.openFor,
	}
end

function MatchEngine.stats(self: MatchEngine): Types.MatchStats
	return self._scores:stats()
end

return MatchEngine
