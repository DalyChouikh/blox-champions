--!strict
-- Team scores and the score tab (spec §6.1, §6.4, §6.5), kept by applying the engine's events in order, so
-- the match score has a single source of truth. Players who leave keep their stats.

local Config = require(script.Parent.Parent.Config)
local Team = require(script.Parent.Team)
local Types = require(script.Parent.Types)

type PlayerStats = Types.PlayerStats

local ScoreKeeper = {}
ScoreKeeper.__index = ScoreKeeper

type Fields = {
	_config: Config.GameConfig,
	_scores: { [Team.Team]: number },
	_players: { [Types.PlayerId]: PlayerStats },
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

local function entry(self: ScoreKeeper, player: Types.PlayerId): PlayerStats
	local stats = self._players[player]
	if stats == nil then
		error(`ScoreKeeper: unknown player "{player}"`, 0)
	end
	return stats
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
		if existing.team ~= team then
			error(`ScoreKeeper: player "{player}" played for {existing.team} and can only return to {existing.team}`, 0)
		end
		existing.present = true
		return
	end
	self._joined += 1
	self._players[player] = {
		player = player,
		team = team,
		joinOrder = self._joined,
		present = true,
		score = 0,
		goals = 0,
		assists = 0,
		saves = 0,
		steals = 0,
	}
end

function ScoreKeeper.removePlayer(self: ScoreKeeper, player: Types.PlayerId)
	entry(self, player).present = false
end

-- The live entry (read-only by convention), or nil for a player never added.
function ScoreKeeper.player(self: ScoreKeeper, player: Types.PlayerId): PlayerStats?
	return self._players[player]
end

function ScoreKeeper.apply(self: ScoreKeeper, event: Types.Event)
	local points = self._config.Scoring.points
	if event.name == "GoalScored" then
		self._scores[event.team] += self._config.Match.pointValue.goal
		local scorer = entry(self, event.scorer)
		scorer.score += points.goal
		scorer.goals += 1
	elseif event.name == "StreakPointScored" then
		self._scores[event.team] += self._config.Match.pointValue.streak
		entry(self, event.holder).score += points.streakPoint
	elseif event.name == "AssistAwarded" then
		local assister = entry(self, event.player)
		assister.score += points.assist
		assister.assists += 1
	elseif event.name == "SaveMade" then
		local saver = entry(self, event.player)
		saver.score += points.save
		saver.saves += 1
	elseif event.name == "Steal" then
		local stealer = entry(self, event.player)
		stealer.score += points.steal
		stealer.steals += 1
	elseif event.name == "LapCompleted" then
		entry(self, event.holder).score += points.lapCompleted
	elseif event.name == "TackleKnockdown" then
		entry(self, event.attacker).score += points.tackleKnockdown
	end
end

function ScoreKeeper.teamScores(self: ScoreKeeper): { [Team.Team]: number }
	return table.clone(self._scores)
end

function ScoreKeeper.stats(self: ScoreKeeper): Types.MatchStats
	local players: { PlayerStats } = {}
	for _, stats in self._players do
		table.insert(players, table.clone(stats))
	end
	table.sort(players, scoreTabOrder)
	return { scores = self:teamScores(), players = players }
end

function ScoreKeeper.mvp(self: ScoreKeeper, team: Team.Team): Types.PlayerId?
	local best: PlayerStats? = nil
	for _, stats in self._players do
		if stats.present and stats.team == team and (best == nil or ranksAbove(stats, best)) then
			best = stats
		end
	end
	return if best ~= nil then best.player else nil
end

return ScoreKeeper
