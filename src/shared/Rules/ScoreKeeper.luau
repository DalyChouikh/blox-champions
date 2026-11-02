--!strict
-- Team scores and the score tab (spec §6.1, §6.4, §6.5), kept by applying the engine's events in order, so
-- the match score has a single source of truth. A player who leaves keeps their stats, off the score tab, until
-- they return (#309).

local Config = require(script.Parent.Parent.Config)
local Team = require(script.Parent.Team)
local Types = require(script.Parent.Types)

type PlayerStats = Types.PlayerStats

-- A player's stats and whether they are still in the match: a leaver's entry waits for their return.
export type Entry = { stats: PlayerStats, present: boolean }

local ScoreKeeper = {}
ScoreKeeper.__index = ScoreKeeper

type Fields = {
	_config: Config.GameConfig,
	_scores: { [Team.Team]: number },
	_players: { [Types.PlayerId]: Entry },
	_joined: number,
}

export type ScoreKeeper = typeof(setmetatable({} :: Fields, ScoreKeeper))

local teamOrder: { [Team.Team]: number } = {}
for index, team: Team.Team in Team.list do
	teamOrder[team] = index
end

-- Score tab order: teams in Team.list order, then highest score, then earliest join.
local function scoreTabOrder(a: PlayerStats, b: PlayerStats): boolean
	if a.team ~= b.team then
		return teamOrder[a.team] < teamOrder[b.team]
	end
	if a.score ~= b.score then
		return a.score > b.score
	end
	return a.joinOrder < b.joinOrder
end

-- MVP tie-breakers (spec §6.5): score, goals, saves, assists, then earliest join.
local function ranksAbove(a: PlayerStats, b: PlayerStats): boolean
	if a.score ~= b.score then
		return a.score > b.score
	end
	if a.goals ~= b.goals then
		return a.goals > b.goals
	end
	if a.saves ~= b.saves then
		return a.saves > b.saves
	end
	if a.assists ~= b.assists then
		return a.assists > b.assists
	end
	return a.joinOrder < b.joinOrder
end

local function entry(self: ScoreKeeper, player: Types.PlayerId): Entry
	local known = self._players[player]
	if known == nil then
		error(`ScoreKeeper: unknown player "{player}"`, 0)
	end
	return known
end

function ScoreKeeper.new(config: Config.GameConfig): ScoreKeeper
	local scores: { [Team.Team]: number } = {}
	for _, team: Team.Team in Team.list do
		scores[team] = 0
	end
	return setmetatable({ _config = config, _scores = scores, _players = {}, _joined = 0 } :: Fields, ScoreKeeper)
end

-- Adds a player, or brings back one who left, keeping their stats and join order. A returning player must
-- rejoin the team they played for: their stats, and any ball they last held, belong to that team.
function ScoreKeeper.addPlayer(self: ScoreKeeper, player: Types.PlayerId, team: Team.Team)
	if not Team.is(team) then
		error(`ScoreKeeper: unknown team "{tostring(team)}"`, 0)
	end
	local existing = self._players[player]
	if existing ~= nil then
		if existing.present then
			error(`ScoreKeeper: player "{player}" is already in the match`, 0)
		end
		local played: Team.Team = existing.stats.team
		if played ~= team then
			error(`ScoreKeeper: player "{player}" played for {played} and can only return to {played}`, 0)
		end
		existing.present = true
		return
	end
	self._joined += 1
	self._players[player] = {
		stats = {
			player = player,
			team = team,
			joinOrder = self._joined,
			score = 0,
			goals = 0,
			assists = 0,
			saves = 0,
			steals = 0,
		},
		present = true,
	}
end

function ScoreKeeper.removePlayer(self: ScoreKeeper, player: Types.PlayerId)
	entry(self, player).present = false
end

-- The live entry (read-only by convention), or nil for a player never added.
function ScoreKeeper.player(self: ScoreKeeper, player: Types.PlayerId): Entry?
	return self._players[player]
end

function ScoreKeeper.apply(self: ScoreKeeper, event: Types.Event)
	local points = self._config.Scoring.points
	if event.name == "GoalScored" then
		self._scores[event.team] += event.points
		local scorer = entry(self, event.scorer).stats
		scorer.score += points.goal
		scorer.goals += 1
	elseif event.name == "AssistAwarded" then
		local assister = entry(self, event.player).stats
		assister.score += points.assist
		assister.assists += 1
	elseif event.name == "SaveMade" then
		local saver = entry(self, event.player).stats
		saver.score += points.save
		saver.saves += 1
	elseif event.name == "Steal" then
		local stealer = entry(self, event.player).stats
		stealer.score += points.steal
		stealer.steals += 1
	elseif event.name == "LapCompleted" then
		entry(self, event.holder).stats.score += points.lapCompleted
	elseif event.name == "TackleKnockdown" then
		entry(self, event.attacker).stats.score += points.tackleKnockdown
	end
end

function ScoreKeeper.teamScores(self: ScoreKeeper): { [Team.Team]: number }
	return table.clone(self._scores)
end

-- The score tab: every player still in the match (#309), by team, then score.
function ScoreKeeper.stats(self: ScoreKeeper): Types.MatchStats
	local players: { PlayerStats } = {}
	for _, known in self._players do
		if known.present then
			table.insert(players, table.clone(known.stats))
		end
	end
	table.sort(players, scoreTabOrder)
	return { scores = self:teamScores(), players = players }
end

-- The best present player of the winning `team`, or of both teams after a draw (nil: ruling, #306).
function ScoreKeeper.mvp(self: ScoreKeeper, team: Team.Team?): Types.PlayerId?
	local best: PlayerStats? = nil
	for _, known in self._players do
		local stats = known.stats
		local counts = known.present and (team == nil or stats.team == team)
		if counts and (best == nil or ranksAbove(stats, best)) then
			best = stats
		end
	end
	return if best ~= nil then best.player else nil
end

return ScoreKeeper
