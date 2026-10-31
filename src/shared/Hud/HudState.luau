--!strict
-- What the HUD shows (spec §11.1), kept from the server's match snapshots and rule events. It never touches an
-- Instance. A snapshot replaces the match; between snapshots the clock counts on by the engine's own rule
-- (MatchClock.runs), and each ClockWarning sets it. Events raise banners (the kickoff's count while it lasts, then GO
-- and the others for UI.hud.bannerSeconds of play, held through a celebration so GOAL! lasts until the count; a new
-- one replaces the last) and add feed entries (each for UI.hud.feedSeconds, at most UI.hud.feedMaxEntries, oldest
-- first). The kickoff's count and GO are the viewer's team's. The end of a match shows from MatchEnded, or from a
-- snapshot of the ended match for a player who joins then, until the next match's first snapshot. `version` grows
-- whenever anything it shows changes, but not as the clocks count, so the HUD redraws only then; stepping allocates
-- nothing.

local Config = require(script.Parent.Parent.Config)
local MatchClock = require(script.Parent.Parent.Rules.MatchClock)
local MatchEngine = require(script.Parent.Parent.Rules.MatchEngine)
local Payloads = require(script.Parent.Parent.Net.Payloads)
local Team = require(script.Parent.Parent.Rules.Team)
local TeamSwitch = require(script.Parent.Parent.Rules.TeamSwitch)
local Types = require(script.Parent.Parent.Rules.Types)

type Team = Team.Team
type PlayerId = Types.PlayerId

export type BannerKind = "Countdown" | "Go" | "Goal" | "Denied" | "ClockWarning" | "LastChance" | "Overtime"
-- `team`: whose colour it shows (the viewer's for the kickoff's count and GO); `value`: the count's digit, or the
-- seconds a clock warning marks.
export type Banner = { kind: BannerKind, team: Team?, value: number? }
export type FeedKind = "Possession" | "Lap" | "GoalOpen" | "Goal"
-- `id`: a running number, the entry's stable key; `value`: a completed lap's streak.
export type FeedEntry = { id: number, kind: FeedKind, team: Team, player: PlayerId?, value: number?, timeLeft: number }
-- `winner`: nil after a draw.
export type Ended = { winner: Team?, mvp: PlayerId?, stats: Types.MatchStats }

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
	-- The player this HUD belongs to: the kickoff's count and GO are their team's.
	_viewer: PlayerId,
	-- How long the banner still shows outside celebrations (not the countdown's, which lasts while the kickoff does).
	_bannerLeft: number,
	_lastId: number,
}

export type HudState = typeof(setmetatable({} :: Fields, HudState))

function HudState.new(config: Config.GameConfig, viewer: PlayerId): HudState
	return setmetatable(
		{
			match = nil,
			names = {},
			banner = nil,
			feed = {},
			ended = nil,
			version = 0,
			_config = config,
			_viewer = viewer,
			_bannerLeft = 0,
			_lastId = 0,
		} :: Fields,
		HudState
	)
end

-- The count's digit: 5, 4, 3, 2, 1, never 0 while the kickoff waits for the server to end it.
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

-- What the end screen shows, from MatchEnded or from a snapshot of the ended match.
local function endedOf(winner: Team?, mvp: PlayerId?, stats: Types.MatchStats): Ended
	return { winner = winner, mvp = mvp, stats = stats }
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

-- The viewer's team in the current match, nil while it does not list them.
local function viewerTeam(self: HudState): Team?
	return HudState.teamOf(self.match, self._viewer)
end

-- The score tab's Switch team button (spec §10.1; the owner, Q104, Q118, #310): nil while it has none (the mode offers
-- no switching, the match doesn't list the viewer, or it is over), else whether a switch works now, with `carrier`
-- holding the ball; greyed while it doesn't. The match lists exactly the players with a seat (#309), so its rows count
-- the other team's seats.
function HudState.switchOffer(self: HudState, carrier: PlayerId?): boolean?
	local rules = self._config.Match
	local match = self.match
	local team: Team? = viewerTeam(self)
	if not rules.teamSwitching or self.ended ~= nil or match == nil or team == nil then
		return nil
	end
	local other: Team = Team.opponent(team)
	local seated = 0
	for _, stats in match.stats.players do
		if stats.team == other then
			seated += 1
		end
	end
	return TeamSwitch.allowed(rules, seated, carrier == self._viewer)
end

-- The kickoff's count at `secondsLeft`, in the viewer's team's colour (the owner, Q110).
local function countdown(self: HudState, secondsLeft: number): Banner
	return { kind = "Countdown", team = viewerTeam(self), value = digit(secondsLeft) }
end

function HudState.applySnapshot(self: HudState, payload: Payloads.MatchSnapshot)
	local match = payload.match
	self.match = match
	self.names = payload.names
	self.ended = if match.state == "Ended" then endedOf(match.winner, match.mvp, match.stats) else nil
	local banner = self.banner
	if match.state == "Kickoff" then
		if banner == nil or banner.kind ~= "Countdown" then
			self.banner = countdown(self, match.phaseSecondsLeft)
		else
			banner.team = viewerTeam(self)
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
			self.banner = countdown(self, event.countdownSeconds)
		elseif event.name == "KickoffEnded" then
			-- GO <their team> TEAM! as the ball comes into play (the owner, Q109); none for a viewer with no team.
			local team: Team? = viewerTeam(self)
			if team ~= nil then
				showBanner(self, "Go", team, nil)
			else
				local banner = self.banner
				if banner ~= nil and banner.kind == "Countdown" then
					self.banner = nil
				end
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
			self.ended = endedOf(event.winner, event.mvp, event.stats)
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
			match.secondsLeft = math.max(match.secondsLeft - dt, 0)
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

-- The whole seconds the clock shows: left in regulation (0 through Last Chance), then in overtime; the match's full
-- length before the first snapshot.
function HudState.clockSeconds(self: HudState): number
	local match = self.match
	if match == nil then
		return self._config.Match.durationSeconds
	end
	return math.ceil(match.secondsLeft)
end

return HudState
