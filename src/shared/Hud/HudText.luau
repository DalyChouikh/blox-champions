--!strict
-- Every string the HUD shows (spec §11.1), written from Config.UI.text. The clock, the speedometer and a cooling key's
-- seconds change every frame, so their strings are cached per whole second, per km/h and per tenth of a second, and
-- the goal's worth per value: once seen, a value costs no allocation.

local Config = require(script.Parent.Parent.Config)
local GoalJudge = require(script.Parent.Parent.Rules.GoalJudge)
local HudState = require(script.Parent.HudState)
local MatchEngine = require(script.Parent.Parent.Rules.MatchEngine)
local Team = require(script.Parent.Parent.Rules.Team)
local Types = require(script.Parent.Parent.Rules.Types)

type PlayerId = Types.PlayerId

-- Rich text's own characters, as its markup writes them.
local ESCAPES: { [string]: string } = table.freeze({
	["&"] = "&amp;",
	["<"] = "&lt;",
	[">"] = "&gt;",
	['"'] = "&quot;",
	["'"] = "&apos;",
})

local HudText = {}
HudText.__index = HudText

type Fields = {
	_config: Config.GameConfig,
	_clocks: { [number]: string },
	_speeds: { [number]: string },
	_worths: { [number]: string },
	_cooldowns: { [number]: string },
}

export type HudText = typeof(setmetatable({} :: Fields, HudText))

function HudText.new(config: Config.GameConfig): HudText
	return setmetatable(
		{ _config = config, _clocks = {}, _speeds = {}, _worths = {}, _cooldowns = {} } :: Fields,
		HudText
	)
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

-- A speed in studs per second as the speedometer's digits read it (spec §7.2: × Movement.speedometerScale, in km/h).
function HudText.speed(self: HudText, studsPerSecond: number): string
	local shown = math.floor(studsPerSecond * self._config.Movement.speedometerScale + 0.5)
	local cached = self._speeds[shown]
	if cached == nil then
		cached = string.format(self._config.UI.text.speed, shown)
		self._speeds[shown] = cached
	end
	return cached
end

-- A key's seconds left to cool down (#354), to the nearest tenth, as the page wrote them.
function HudText.cooldown(self: HudText, seconds: number): string
	local tenths = math.floor(seconds * 10 + 0.5)
	local cached = self._cooldowns[tenths]
	if cached == nil then
		cached = string.format(self._config.UI.text.cooldown, tenths / 10)
		self._cooldowns[tenths] = cached
	end
	return cached
end

-- What a goal is worth while the goal is open (GoalJudge.worth of the streak that opened it), for the scoreboard's
-- chip; nil while it is closed.
function HudText.worth(self: HudText, match: MatchEngine.Snapshot): string?
	if match.goalOpenFor == nil then
		return nil
	end
	local worth = GoalJudge.worth(self._config.Match.goalPointsByLap, match.streak)
	local cached = self._worths[worth]
	if cached == nil then
		cached = string.format(self._config.UI.text.goalWorth, worth)
		self._worths[worth] = cached
	end
	return cached
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
	elseif kind == "Go" then
		return string.format(text.go, string.upper(self:team(banner.team :: Team.Team)))
	elseif kind == "Goal" then
		return text.goal
	elseif kind == "Denied" then
		return text.denied
	elseif kind == "ClockWarning" then
		return string.format(text.clockWarning, banner.value :: number)
	elseif kind == "LastChance" then
		return text.lastChance
	elseif kind == "Overtime" then
		return text.overtime
	elseif kind == "Lap" then
		return string.format(text.lapCompleted, banner.value :: number)
	elseif kind == "GoalOpen" then
		return string.format(text.goalOpen, string.upper(self:team(banner.team :: Team.Team)))
	end
	-- HudState.BannerKind has only the kinds above: any other is a wiring bug.
	error(`HudText: no banner text for kind "{kind}"`, 0)
end

function HudText.name(self: HudText, player: PlayerId, names: { [PlayerId]: string }): string
	return names[player] or self._config.UI.text.unknownPlayer
end

function HudText.team(self: HudText, team: Team.Team): string
	return self._config.UI.teamNames[team]
end

-- The end screen's headline: the winning team, or a draw (nil) when overtime ran out.
function HudText.result(self: HudText, winner: Team.Team?): string
	if winner == nil then
		return self._config.UI.text.draw
	end
	return string.format(self._config.UI.text.wins, self:team(winner))
end

-- What a feed line says, with %s for its player.
local function feedTemplate(self: HudText, kind: HudState.FeedKind): string
	local text = self._config.UI.text
	if kind == "Possession" then
		return text.possession
	elseif kind == "Goal" then
		return text.scored
	end
	-- HudState.FeedKind has only the kinds above: any other is a wiring bug.
	error(`HudText: no feed text for kind "{kind}"`, 0)
end

function HudText.feed(self: HudText, entry: HudState.FeedEntry, names: { [PlayerId]: string }): string
	return string.format(feedTemplate(self, entry.kind), self:name(entry.player, names))
end

-- The same line for a rich-text label (Hud/Feed, #369): the player's name in `color`, and rich text's own characters
-- written so that they show as they are.
function HudText.feedMarked(
	self: HudText,
	entry: HudState.FeedEntry,
	names: { [PlayerId]: string },
	color: Color3
): string
	local function escaped(words: string): string
		return (string.gsub(words, "[&<>\"']", ESCAPES))
	end
	local name = escaped(self:name(entry.player, names))
	return string.format(escaped(feedTemplate(self, entry.kind)), `<font color="#{color:ToHex()}">{name}</font>`)
end

return HudText
