--!strict
-- Every string the HUD shows (spec §11.1), written from Config.UI.text. The clock and the speedometer change every
-- frame, so their strings are cached per whole second and per km/h: once seen, a value costs no allocation.

local Config = require(script.Parent.Parent.Config)
local HudState = require(script.Parent.HudState)
local MatchEngine = require(script.Parent.Parent.Rules.MatchEngine)
local Team = require(script.Parent.Parent.Rules.Team)
local Types = require(script.Parent.Parent.Rules.Types)

type PlayerId = Types.PlayerId

local HudText = {}
HudText.__index = HudText

type Fields = {
	_config: Config.GameConfig,
	_clocks: { [number]: string },
	_speeds: { [number]: string },
}

export type HudText = typeof(setmetatable({} :: Fields, HudText))

function HudText.new(config: Config.GameConfig): HudText
	return setmetatable({ _config = config, _clocks = {}, _speeds = {} } :: Fields, HudText)
end

-- Whole seconds as minutes and seconds.
function HudText.clock(self: HudText, seconds: number): string
	local whole = math.max(math.floor(seconds), 0)
	local cached = self._clocks[whole]
	if cached == nil then
		cached = string.format(self._config.UI.text.clock, whole // 60, whole % 60)
		self._clocks[whole] = cached
	end
	return cached
end

-- A speed in studs per second as the speedometer reads it (spec §7.2: × Movement.speedometerScale, in km/h).
function HudText.speed(self: HudText, studsPerSecond: number): string
	local shown = math.floor(studsPerSecond * self._config.Movement.speedometerScale + 0.5)
	local cached = self._speeds[shown]
	if cached == nil then
		cached = string.format(self._config.UI.text.speed, shown)
		self._speeds[shown] = cached
	end
	return cached
end

-- The possessing team's laps toward opening the goal, or their streak once it has opened it; nil while neutral. A
-- point closes the goal, but the streak that opened it stays until the kickoff (or the match's end), so it is still
-- the streak then.
function HudText.lap(self: HudText, match: MatchEngine.Snapshot): string?
	if match.possessingTeam == nil then
		return nil
	end
	local text, rules = self._config.UI.text, self._config.Match
	if match.streak >= rules.lapsToOpenGoal then
		return string.format(text.streak, match.streak, rules.lapsForStreakPoint)
	end
	return string.format(text.lap, match.streak, rules.lapsToOpenGoal)
end

-- The period named under the clock for as long as it lasts: OVERTIME or LAST CHANCE; nil in regulation.
function HudText.period(self: HudText, match: MatchEngine.Snapshot): string?
	local text = self._config.UI.text
	local period = match.period
	if period == "Overtime" then
		return text.overtime
	elseif period == "LastChance" then
		return text.lastChance
	end
	return nil
end

function HudText.banner(self: HudText, banner: HudState.Banner): string
	local text = self._config.UI.text
	local kind = banner.kind
	if kind == "Countdown" then
		return tostring(banner.value)
	elseif kind == "Goal" then
		return text.goal
	elseif kind == "StreakPoint" then
		return text.streakPoint
	elseif kind == "Denied" then
		return text.denied
	elseif kind == "ClockWarning" then
		return string.format(text.clockWarning, banner.value :: number)
	elseif kind == "LastChance" then
		return text.lastChance
	end
	return text.overtime
end

function HudText.name(self: HudText, player: PlayerId, names: { [PlayerId]: string }): string
	return names[player] or self._config.UI.text.unknownPlayer
end

function HudText.team(self: HudText, team: Team.Team): string
	return self._config.UI.teamNames[team]
end

-- The end screen's headline: the winning team.
function HudText.wins(self: HudText, team: Team.Team): string
	return string.format(self._config.UI.text.wins, self:team(team))
end

function HudText.feed(self: HudText, entry: HudState.FeedEntry, names: { [PlayerId]: string }): string
	local text = self._config.UI.text
	local kind = entry.kind
	if kind == "Lap" then
		return string.format(text.lapCompleted, entry.value :: number)
	elseif kind == "GoalOpen" then
		return string.format(text.goalOpen, self:team(entry.team))
	end
	local name = self:name(entry.player :: PlayerId, names)
	if kind == "Possession" then
		return string.format(text.possession, name)
	elseif kind == "Goal" then
		return string.format(text.scored, name)
	end
	return string.format(text.scoredStreak, name)
end

return HudText
