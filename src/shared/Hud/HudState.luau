--!strict
-- What the HUD shows (spec §11.1), kept from the server's match snapshots and rule events. It never touches an
-- Instance. A snapshot replaces the match; between snapshots the clock counts on by the engine's own rule
-- (MatchClock.runs), and each ClockWarning sets it. Events raise banners (the kickoff's 3-2-1 while the countdown
-- lasts, the others for UI.hud.bannerSeconds of play, held through a celebration so GOAL! lasts until the 3-2-1; a new
-- one replaces the last) and add feed entries (each for UI.hud.feedSeconds, at most UI.hud.feedMaxEntries, oldest
-- first). The end of a match shows until the next match's first snapshot. `version` grows whenever anything it shows
-- changes, but not as the clocks count, so the HUD redraws only then; stepping allocates nothing.

local Config = require(script.Parent.Parent.Config)
local MatchClock = require(script.Parent.Parent.Rules.MatchClock)
local MatchEngine = require(script.Parent.Parent.Rules.MatchEngine)
local Payloads = require(script.Parent.Parent.Net.Payloads)
local Team = require(script.Parent.Parent.Rules.Team)
local Types = require(script.Parent.Parent.Rules.Types)

type Team = Team.Team
type PlayerId = Types.PlayerId

export type BannerKind = "Countdown" | "Goal" | "StreakPoint" | "Denied" | "ClockWarning" | "LastChance" | "Overtime"
-- `value`: the countdown's digit, or the seconds a clock warning marks.
export type Banner = { kind: BannerKind, team: Team?, value: number? }
export type FeedKind = "Possession" | "Lap" | "GoalOpen" | "Goal" | "StreakPoint"
-- `id`: a running number, the entry's stable key; `value`: a completed lap's streak.
export type FeedEntry = { id: number, kind: FeedKind, team: Team, player: PlayerId?, value: number?, timeLeft: number }
export type Ended = { winner: Team, mvp: PlayerId?, stats: Types.MatchStats }

local HudState = {}
HudState.__index = HudState

type Fields = {
	-- The latest snapshot, its clocks counted on since; nil before the first.
	match: MatchEngine.Snapshot?,
	names: { [PlayerId]: string },
	banner: Banner?,
	feed: { FeedEntry },
	ended: Ended?,
	version: number,
	_config: Config.GameConfig,
	-- How long the banner still shows outside celebrations (not the countdown's, which lasts while the kickoff does).
	_bannerLeft: number,
	_lastId: number,
}

export type HudState = typeof(setmetatable({} :: Fields, HudState))

function HudState.new(config: Config.GameConfig): HudState
	return setmetatable(
		{
			match = nil,
			names = {},
			banner = nil,
			feed = {},
			ended = nil,
			version = 0,
			_config = config,
			_bannerLeft = 0,
			_lastId = 0,
		} :: Fields,
		HudState
	)
end

-- The countdown's digit: 3, 2, 1, never 0 while the kickoff waits for the server to end it.
local function digit(secondsLeft: number): number
	return math.max(math.ceil(secondsLeft), 1)
end

local function showBanner(self: HudState, kind: BannerKind, team: Team?, value: number?)
	self.banner = { kind = kind, team = team, value = value }
	self._bannerLeft = self._config.UI.hud.bannerSeconds
end

local function addEntry(self: HudState, kind: FeedKind, team: Team, player: PlayerId?, value: number?)
	self._lastId += 1
	local feed = self.feed
	table.insert(feed, {
		id = self._lastId,
		kind = kind,
		team = team,
		player = player,
		value = value,
		timeLeft = self._config.UI.hud.feedSeconds,
	})
	while #feed > self._config.UI.hud.feedMaxEntries do
		table.remove(feed, 1)
	end
end

-- The team `player` plays for in `match`'s score tab; nil without a match or for a player it doesn't list.
function HudState.teamOf(match: MatchEngine.Snapshot?, player: PlayerId): Team?
	if match ~= nil then
		for _, stats in match.stats.players do
			if stats.player == player then
				return stats.team
			end
		end
	end
	return nil
end

function HudState.applySnapshot(self: HudState, payload: Payloads.MatchSnapshot)
	local match = payload.match
	self.match = match
	self.names = payload.names
	if match.state ~= "Ended" then
		self.ended = nil
	end
	local banner = self.banner
	if match.state == "Kickoff" then
		if banner == nil or banner.kind ~= "Countdown" then
			self.banner = { kind = "Countdown", value = digit(match.phaseSecondsLeft) }
		else
			banner.value = digit(match.phaseSecondsLeft)
		end
	elseif banner ~= nil and banner.kind == "Countdown" then
		self.banner = nil
	end
	self.version += 1
end

function HudState.applyEvents(self: HudState, events: { Types.Event })
	local changed = false
	for _, event in events do
		local shown = true
		if event.name == "KickoffStarted" then
			self.banner = { kind = "Countdown", value = digit(event.countdownSeconds) }
		elseif event.name == "KickoffEnded" then
			local banner = self.banner
			if banner ~= nil and banner.kind == "Countdown" then
				self.banner = nil
			end
		elseif event.name == "PossessionChanged" then
			addEntry(self, "Possession", event.team, event.player, nil)
		elseif event.name == "LapCompleted" then
			addEntry(self, "Lap", event.team, event.holder, event.streak)
		elseif event.name == "GoalOpened" then
			addEntry(self, "GoalOpen", event.team, nil, nil)
		elseif event.name == "GoalScored" then
			showBanner(self, "Goal", event.team, nil)
			addEntry(self, "Goal", event.team, event.scorer, nil)
		elseif event.name == "StreakPointScored" then
			showBanner(self, "StreakPoint", event.team, nil)
			addEntry(self, "StreakPoint", event.team, event.holder, nil)
		elseif event.name == "SaveMade" then
			showBanner(self, "Denied", HudState.teamOf(self.match, event.player), nil)
		elseif event.name == "ClockWarning" then
			showBanner(self, "ClockWarning", nil, event.secondsLeft)
			local match = self.match
			if match ~= nil then
				match.secondsLeft = event.secondsLeft
			end
		elseif event.name == "LastChanceStarted" then
			showBanner(self, "LastChance", event.team, nil)
		elseif event.name == "OvertimeStarted" then
			showBanner(self, "Overtime", nil, nil)
		elseif event.name == "MatchEnded" then
			self.ended = { winner = event.winner, mvp = event.mvp, stats = event.stats }
			self.banner = nil
		else
			shown = false
		end
		changed = changed or shown
	end
	if changed then
		self.version += 1
	end
end

function HudState.step(self: HudState, dt: number)
	local changed = false
	local match = self.match
	if match ~= nil then
		local state: Types.MatchState = match.state
		if MatchClock.runs(self._config.Match, state) then
			if match.period == "Overtime" then
				match.overtimeSeconds += dt
			else
				match.secondsLeft = math.max(match.secondsLeft - dt, 0)
			end
		end
		if state == "Kickoff" or state == "Celebration" then
			match.phaseSecondsLeft = math.max(match.phaseSecondsLeft - dt, 0)
		end
	end

	local banner = self.banner
	if banner ~= nil then
		if banner.kind == "Countdown" then
			if match ~= nil and match.state == "Kickoff" then
				local value = digit(match.phaseSecondsLeft)
				if value ~= banner.value then
					banner.value = value
					changed = true
				end
			end
		elseif match == nil or match.state ~= "Celebration" then
			self._bannerLeft -= dt
			if self._bannerLeft <= 0 then
				self.banner = nil
				changed = true
			end
		end
	end

	local feed = self.feed
	for index = #feed, 1, -1 do
		local entry = feed[index]
		entry.timeLeft -= dt
		if entry.timeLeft <= 0 then
			table.remove(feed, index)
			changed = true
		end
	end

	if changed then
		self.version += 1
	end
end

-- The whole seconds the clock shows: left in regulation (0 through Last Chance), counted up in overtime; the match's
-- full length before the first snapshot.
function HudState.clockSeconds(self: HudState): number
	local match = self.match
	if match == nil then
		return self._config.Match.durationSeconds
	end
	if match.period == "Overtime" then
		return math.floor(match.overtimeSeconds)
	end
	return math.ceil(match.secondsLeft)
end

return HudState
