--!strict
-- Who plays for which team (spec §10.1, §13). Newcomers take the team with fewer players (an injected tie-breaker
-- settles a tie), up to teamSize each; everyone else spectates in arrival order. A player who leaves and comes back
-- in the same match returns to their old team, or spectates while it is full: the rules engine counts a player for
-- one team per match. A new match forgets all of that and reseats everyone present.

local Team = require(script.Parent.Team)
local Types = require(script.Parent.Types)

type Team = Team.Team
type PlayerId = Types.PlayerId

export type Seat = { player: PlayerId, team: Team }

local Roster = {}
Roster.__index = Roster

type Fields = {
	_teamSize: number,
	_tieBreak: () -> Team,
	-- A record, not a [Team] indexer, so both `.Blue` and `[team]` type-check.
	_members: { Blue: { PlayerId }, Orange: { PlayerId } },
	_spectators: { PlayerId },
	_teamOf: { [PlayerId]: Team },
	-- Players who left this match, by the team they played for.
	_formerTeam: { [PlayerId]: Team },
	-- When each seated player took their seat, so a new match reseats them in that order.
	_seatedAt: { [PlayerId]: number },
	_seatCount: number,
}

export type Roster = typeof(setmetatable({} :: Fields, Roster))

local function hasRoom(self: Roster, team: Team): boolean
	return #self._members[team] < self._teamSize
end

local function seat(self: Roster, player: PlayerId, team: Team)
	table.insert(self._members[team], player)
	self._teamOf[player] = team
	self._formerTeam[player] = nil
	self._seatCount += 1
	self._seatedAt[player] = self._seatCount
end

-- The team a newcomer joins, or nil when both are full.
local function newcomerTeam(self: Roster): Team?
	local blue, orange = #self._members.Blue, #self._members.Orange
	if blue == orange then
		return if blue < self._teamSize then self._tieBreak() else nil
	end
	return if blue < orange then "Blue" else "Orange"
end

local function isPresent(self: Roster, player: PlayerId): boolean
	return self._teamOf[player] ~= nil or table.find(self._spectators, player) ~= nil
end

function Roster.new(teamSize: number, tieBreak: () -> Team): Roster
	local self: Roster = setmetatable(
		{
			_teamSize = teamSize,
			_tieBreak = tieBreak,
			_members = { Blue = {}, Orange = {} },
			_spectators = {},
			_teamOf = {},
			_formerTeam = {},
			_seatedAt = {},
			_seatCount = 0,
		} :: Fields,
		Roster
	)
	return self
end

-- The player's team, or nil when they spectate.
function Roster.join(self: Roster, player: PlayerId): Team?
	if isPresent(self, player) then
		error(`Roster: player "{player}" already joined`, 0)
	end
	local former: Team? = self._formerTeam[player]
	local team: Team? = if former ~= nil then (if hasRoom(self, former) then former else nil) else newcomerTeam(self)
	if team == nil then
		table.insert(self._spectators, player)
		return nil
	end
	seat(self, player, team)
	return team
end

-- Frees the player's seat or place in line. Returns the spectators seated into the freed seat.
function Roster.leave(self: Roster, player: PlayerId): { Seat }
	local team: Team? = self._teamOf[player]
	if team == nil then
		local index = table.find(self._spectators, player)
		if index == nil then
			error(`Roster: unknown player "{player}"`, 0)
		end
		table.remove(self._spectators, index)
		return {}
	end

	local members = self._members[team]
	table.remove(members, table.find(members, player) :: number)
	self._teamOf[player] = nil
	self._seatedAt[player] = nil
	self._formerTeam[player] = team

	local promoted: { Seat } = {}
	for index, waiting in self._spectators do
		local waitingFormer: Team? = self._formerTeam[waiting]
		if waitingFormer == nil or waitingFormer == team then
			table.remove(self._spectators, index)
			seat(self, waiting, team)
			table.insert(promoted, { player = waiting, team = team })
			break
		end
	end
	return promoted
end

function Roster.teamOf(self: Roster, player: PlayerId): Team?
	return self._teamOf[player]
end

-- The team's players in the order they took their seats (the index is their spawn slot).
function Roster.members(self: Roster, team: Team): { PlayerId }
	return table.clone(self._members[team])
end

-- How many players hold a seat, without copying any list (the match checks it every frame while waiting).
function Roster.seatedCount(self: Roster): number
	return #self._members.Blue + #self._members.Orange
end

function Roster.spectators(self: Roster): { PlayerId }
	return table.clone(self._spectators)
end

function Roster.newMatch(self: Roster): { Seat }
	local present: { PlayerId } = {}
	for _, team: Team in Team.list do
		for _, player in self._members[team] do
			table.insert(present, player)
		end
	end
	table.sort(present, function(a: PlayerId, b: PlayerId): boolean
		return self._seatedAt[a] < self._seatedAt[b]
	end)
	for _, player in self._spectators do
		table.insert(present, player)
	end

	self._members = { Blue = {}, Orange = {} }
	self._spectators = {}
	self._teamOf = {}
	self._formerTeam = {}
	self._seatedAt = {}

	local seats: { Seat } = {}
	for _, player in present do
		local team: Team? = self:join(player)
		if team ~= nil then
			table.insert(seats, { player = player, team = team })
		end
	end
	return seats
end

return Roster
