--!strict
-- Seats players on the two teams (spec §10.1) with Rules/Roster, marks each seated player's team in a replicated
-- Player attribute, and announces every change so the match and the characters follow it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local Roster = require(ReplicatedStorage.Shared.Rules.Roster)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type PlayerId = Types.PlayerId
type Team = Team.Team

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type TeamService = {
	name: string,
	dependencies: { string },
	init: (self: TeamService, deps: { [string]: any }) -> (),
	start: (self: TeamService) -> (),
	join: (self: TeamService, player: Player) -> (),
	leave: (self: TeamService, player: Player) -> (),
	newMatch: (self: TeamService) -> (),
	teamOf: (self: TeamService, player: PlayerId) -> Team?,
	slotOf: (self: TeamService, player: PlayerId) -> (Team?, number?),
	seatedCount: (self: TeamService) -> number,
	-- Every player who joins, seated or not (the match sends them a snapshot).
	joined: Signal.Signal<PlayerId>,
	seated: Signal.Signal<PlayerId, Team>,
	unseated: Signal.Signal<PlayerId>,
	_roster: Roster.Roster,
	_players: { [PlayerId]: Player },
}

-- Marks each seat on its player and announces it.
local function announceSeats(self: TeamService, seats: { Roster.Seat })
	for _, seat in seats do
		local player: Player? = self._players[seat.player]
		if player ~= nil then
			player:SetAttribute(Attributes.Team, seat.team)
		end
		self.seated:Fire(seat.player, seat.team)
	end
end

local TeamService: TeamService = {
	name = "TeamService",
	dependencies = { "Config" },
	joined = Signal.new(),
	seated = Signal.new(),
	unseated = Signal.new(),
	_roster = nil :: any,
	_players = {},

	init = function(self: TeamService, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		local random = Random.new()
		self._roster = Roster.new(config.Match.teamSize, function(): Team
			return Team.list[random:NextInteger(1, #Team.list)]
		end)
		self._players = {}
		self.joined = Signal.new()
		self.seated = Signal.new()
		self.unseated = Signal.new()
	end,

	start = function(self: TeamService)
		Players.PlayerAdded:Connect(function(player: Player)
			self:join(player)
		end)
		Players.PlayerRemoving:Connect(function(player: Player)
			self:leave(player)
		end)
		for _, player in Players:GetPlayers() do
			self:join(player)
		end
	end,

	-- A second session of the same user (joining before the old one has left) replaces it.
	join = function(self: TeamService, player: Player)
		local id = PlayerIds.of(player)
		local current: Player? = self._players[id]
		if current ~= nil and current ~= player then
			self:leave(current)
		end
		self._players[id] = player
		local team: Team? = self._roster:join(id)
		player:SetAttribute(Attributes.Team, team)
		self.joined:Fire(id)
		if team ~= nil then
			self.seated:Fire(id, team)
		end
	end,

	-- A session that a newer one already replaced changes nothing.
	leave = function(self: TeamService, player: Player)
		local id = PlayerIds.of(player)
		if self._players[id] ~= player then
			return
		end
		local wasSeated = self._roster:teamOf(id) ~= nil
		local promoted = self._roster:leave(id)
		player:SetAttribute(Attributes.Team, nil)
		self._players[id] = nil
		if wasSeated then
			self.unseated:Fire(id)
		end
		announceSeats(self, promoted)
	end,

	newMatch = function(self: TeamService)
		local before: { PlayerId } = {}
		for _, team: Team in Team.list do
			for _, id in self._roster:members(team) do
				table.insert(before, id)
			end
		end
		local seats = self._roster:newMatch()
		announceSeats(self, seats)
		for _, id in before do
			if self._roster:teamOf(id) == nil then
				local player: Player? = self._players[id]
				if player ~= nil then
					player:SetAttribute(Attributes.Team, nil)
				end
				self.unseated:Fire(id)
			end
		end
	end,

	teamOf = function(self: TeamService, player: PlayerId): Team?
		return self._roster:teamOf(player)
	end,

	-- The player's team and 1-based place in its seat order: their spawn slot.
	slotOf = function(self: TeamService, player: PlayerId): (Team?, number?)
		local team: Team? = self._roster:teamOf(player)
		if team == nil then
			return nil, nil
		end
		return team, table.find(self._roster:members(team), player)
	end,

	seatedCount = function(self: TeamService): number
		return #self._roster:members("Blue") + #self._roster:members("Orange")
	end,
}

return TeamService
