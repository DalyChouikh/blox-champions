--!strict
-- Seated players' characters (spec §4.5, §10.1): loaded only for players with a seat (spectators watch without
-- one), stood on their team spawn slot at kickoff and held still through the countdown, and loaded again after a
-- death. Loading yields, so it always runs on its own thread: whoever seats a player never waits for it. The loaded
-- character is registered by that thread, not by CharacterAdded: Roblox defers that event until after the load has
-- returned. Each loaded character gets its skater body (SkaterBody) and is stood with its root at
-- Movement.hoverHeight above its spawn, where its own client's skating takes over. It lists every seated living
-- character, marking who can catch (not while knocked down), for the ball, the actions and the movement guard, and
-- announces any that goes away so a carrier's ball drops.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallService = require(script.Parent.BallService)
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local NetService = require(script.Parent.NetService)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Schemas = require(ReplicatedStorage.Shared.Net.Schemas)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local SkaterBody = require(script.Parent.SkaterBody)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)
local TeamService = require(script.Parent.TeamService)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type PlayerId = Types.PlayerId

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type CharacterService = {
	name: string,
	dependencies: { string },
	init: (self: CharacterService, deps: { [string]: any }) -> (),
	start: (self: CharacterService) -> (),
	requestLoad: (self: CharacterService, player: PlayerId) -> (),
	adopt: (self: CharacterService, player: PlayerId, character: Model) -> (),
	onDied: (self: CharacterService, player: PlayerId, character: Model) -> (),
	place: (self: CharacterService, player: PlayerId, frozen: boolean) -> (),
	placeAll: (self: CharacterService, frozen: boolean) -> (),
	freezeAll: (self: CharacterService, frozen: boolean) -> (),
	holders: (self: CharacterService) -> { BallService.Holder },
	-- A seated player's pump, brake and Air Pose, shown on their character for every client to pose.
	setSkateState: (self: CharacterService, player: PlayerId, pump: boolean, brake: boolean, airPose: boolean) -> (),
	-- A registered character that died or was destroyed.
	characterRemoved: Signal.Signal<PlayerId>,
	-- The server moved a character to its spawn: a jump the movement guard must not judge.
	placed: Signal.Signal<PlayerId>,
	_config: Config.GameConfig,
	_teamSpawns: { [string]: { CFrame } },
	_teams: TeamService.TeamService,
	-- Loads the player's character and returns it, or nil when the player is gone (Player:LoadCharacterAsync; a fake
	-- in tests).
	_loadCharacter: (player: PlayerId) -> Model?,
	-- Whether kickoff placement currently freezes characters, so one that loads mid-countdown is frozen too.
	_frozen: boolean,
	_loading: { [PlayerId]: boolean },
	-- One respawn wait per player: a later death starts it over.
	_respawns: { [PlayerId]: thread },
	_characters: { [PlayerId]: Model },
	-- Adoption order, so the catch candidates are listed the same way every frame.
	_order: { PlayerId },
	_watchers: { [PlayerId]: { RBXScriptConnection } },
	_holders: { BallService.Holder },
}

local function rootOf(character: Model): BasePart?
	return character:FindFirstChild(SkaterRig.root) :: BasePart?
end

local function forget(self: CharacterService, player: PlayerId)
	local watchers = self._watchers[player]
	if watchers ~= nil then
		for _, connection in watchers do
			connection:Disconnect()
		end
	end
	self._watchers[player] = nil
	self._characters[player] = nil
	local index = table.find(self._order, player)
	if index ~= nil then
		table.remove(self._order, index)
	end
end

-- Forgets the player's character and announces it, unless a newer one has replaced it.
local function removed(self: CharacterService, player: PlayerId, character: Model)
	if self._characters[player] == character then
		forget(self, player)
		self.characterRemoved:Fire(player)
	end
end

local CharacterService: CharacterService = {
	name = "CharacterService",
	dependencies = { "Config", "ArenaService", "TeamService", "NetService" },
	characterRemoved = Signal.new(),
	placed = Signal.new(),
	_config = nil :: any,
	_teamSpawns = {},
	_teams = nil :: any,
	_loadCharacter = function(_player: PlayerId): Model?
		return nil
	end,
	_frozen = false,
	_loading = {},
	_respawns = {},
	_characters = {},
	_order = {},
	_watchers = {},
	_holders = {},

	-- deps.LoadCharacter replaces the Roblox character load in tests.
	init = function(self: CharacterService, deps: { [string]: any })
		self._config = deps.Config
		self._teamSpawns = deps.ArenaService.arena.teamSpawns
		self._teams = deps.TeamService
		self._loadCharacter = deps.LoadCharacter
			or function(id: PlayerId): Model?
				local player = PlayerIds.player(id)
				if player == nil then
					return nil
				end
				player:LoadCharacterAsync()
				return player.Character
			end
		self._frozen = false
		self._loading = {}
		self._respawns = {}
		self._characters = {}
		self._order = {}
		self._watchers = {}
		self._holders = {}
		self.characterRemoved = Signal.new()
		self.placed = Signal.new()
		local net: NetService.NetService = deps.NetService
		net:listen(
			Remotes.names.SkateState,
			Schemas.SkateState,
			self._config.Network.maxSkateStatesPerSecond,
			function(player: PlayerId, payload: any)
				self:setSkateState(player, payload.pump, payload.brake, payload.airPose)
			end
		)
	end,

	start = function(self: CharacterService)
		SkaterBody.registerGroups(PhysicsService)
		Players.CharacterAutoLoads = false
		self._teams.seated:Connect(function(id: PlayerId)
			self:requestLoad(id)
		end)
		self._teams.unseated:Connect(function(id: PlayerId)
			local character: Model? = self._characters[id]
			if character ~= nil then
				character:Destroy()
			end
		end)
		-- Players TeamService seated before this module started listening.
		for _, player in Players:GetPlayers() do
			local id = PlayerIds.of(player)
			if self._teams:teamOf(id) ~= nil then
				self:requestLoad(id)
			end
		end
	end,

	-- Loads the player's character unless they have one or it is already loading, then stands it on its spawn,
	-- frozen while a kickoff countdown runs. Never yields the caller.
	requestLoad = function(self: CharacterService, player: PlayerId)
		local existing: Model? = self._characters[player]
		if existing ~= nil or self._loading[player] then
			return
		end
		self._loading[player] = true
		task.spawn(function()
			local character = self._loadCharacter(player)
			self._loading[player] = nil
			if character ~= nil then
				-- In the resumption the load returns in, before the client can start the default animations.
				SkaterBody.build(character, self._config.Movement)
				self:adopt(player, character)
				self:place(player, self._frozen)
			end
		end)
	end,

	adopt = function(self: CharacterService, player: PlayerId, character: Model)
		forget(self, player)
		self._characters[player] = character
		table.insert(self._order, player)
		local watchers = {
			character.Destroying:Connect(function()
				removed(self, player, character)
			end),
		}
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil then
			table.insert(
				watchers,
				humanoid.Died:Connect(function()
					self:onDied(player, character)
				end)
			)
		end
		self._watchers[player] = watchers
	end,

	-- A dead character stops counting at once (a carrier's ball drops); a player who still has a seat gets a new one
	-- on their team spawn after Match.respawnSeconds.
	onDied = function(self: CharacterService, player: PlayerId, character: Model)
		removed(self, player, character)
		local pending = self._respawns[player]
		if pending ~= nil then
			task.cancel(pending)
		end
		self._respawns[player] = task.delay(self._config.Match.respawnSeconds, function()
			self._respawns[player] = nil
			if self._teams:teamOf(player) ~= nil then
				self:requestLoad(player)
			end
		end)
	end,

	place = function(self: CharacterService, player: PlayerId, frozen: boolean)
		local character: Model? = self._characters[player]
		local team, slot = self._teams:slotOf(player)
		if
			character == nil
			or team == nil
			or slot == nil
			or character:FindFirstChildOfClass("Humanoid") == nil
			or rootOf(character) == nil
		then
			return
		end
		local spawn = self._teamSpawns[team][slot]
		character:PivotTo(spawn * CFrame.new(0, self._config.Movement.hoverHeight, 0))
		local root = rootOf(character)
		if root ~= nil then
			root.Anchored = frozen
		end
		self.placed:Fire(player)
	end,

	placeAll = function(self: CharacterService, frozen: boolean)
		self._frozen = frozen
		for _, player in table.clone(self._order) do
			self:place(player, frozen)
		end
	end,

	freezeAll = function(self: CharacterService, frozen: boolean)
		self._frozen = frozen
		for _, character in self._characters do
			local root = rootOf(character)
			if root ~= nil then
				root.Anchored = frozen
			end
		end
	end,

	setSkateState = function(self: CharacterService, player: PlayerId, pump: boolean, brake: boolean, airPose: boolean)
		local character: Model? = self._characters[player]
		if character ~= nil and self._teams:teamOf(player) ~= nil then
			character:SetAttribute(Attributes.Pumping, pump)
			character:SetAttribute(Attributes.Braking, brake)
			character:SetAttribute(Attributes.AirPosing, airPose)
		end
	end,

	-- Every seated player's living character with a root, in adoption order, each marked `canCatch` unless knocked
	-- down; one reused list of reused records. Only seated players: a catch the match would not count leaves the ball
	-- in the wrong hands.
	holders = function(self: CharacterService): { BallService.Holder }
		local holders = self._holders
		local count = 0
		for _, player in self._order do
			local character = self._characters[player]
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = rootOf(character)
			local team = self._teams:teamOf(player)
			if team ~= nil and humanoid ~= nil and humanoid.Health > 0 and root ~= nil then
				count += 1
				local holder = holders[count]
				local canCatch = character:GetAttribute(Attributes.KnockedDown) == nil
				if holder == nil then
					holders[count] = { player = player, root = root, canCatch = canCatch }
				else
					holder.player = player
					holder.root = root
					holder.canCatch = canCatch
				end
			end
		end
		for index = #holders, count + 1, -1 do
			holders[index] = nil
		end
		return holders
	end,
}

return CharacterService
