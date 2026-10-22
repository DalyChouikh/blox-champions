--!strict
-- Seated players' characters (spec §4.5, §10.1): loaded only for players with a seat (spectators watch without
-- one), stood on their team spawn slot at kickoff and held still through the countdown, and loaded again after a
-- death. It lists the characters that can catch the ball, and announces any that goes away so a carrier's ball drops.
-- Phase 5 adds the skating collider, hover and poses here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallService = require(script.Parent.BallService)
local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type PlayerId = Types.PlayerId

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type CharacterService = {
	name: string,
	dependencies: { string },
	init: (self: CharacterService, deps: { [string]: any }) -> (),
	start: (self: CharacterService) -> (),
	adopt: (self: CharacterService, player: PlayerId, character: Model) -> (),
	place: (self: CharacterService, player: PlayerId, frozen: boolean) -> (),
	placeAll: (self: CharacterService, frozen: boolean) -> (),
	freezeAll: (self: CharacterService, frozen: boolean) -> (),
	holders: (self: CharacterService) -> { BallService.Holder },
	standingHeight: (character: Model) -> number,
	-- A registered character that died or was destroyed.
	characterRemoved: Signal.Signal<PlayerId>,
	_config: Config.GameConfig,
	_teamSpawns: { [string]: { CFrame } },
	_teams: any,
	_characters: { [PlayerId]: Model },
	-- Adoption order, so the catch candidates are listed the same way every frame.
	_order: { PlayerId },
	_watchers: { [PlayerId]: { RBXScriptConnection } },
	_holders: { BallService.Holder },
}

local function rootOf(character: Model): BasePart?
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function handOf(character: Model): BasePart?
	return (
		character:FindFirstChild("RightHand")
		or character:FindFirstChild("Right Arm")
		or rootOf(character)
	) :: BasePart?
end

-- The root's height above the floor when standing (Roblox: R15 and R6 measure HipHeight differently).
local function standingHeight(character: Model): number
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = rootOf(character) :: BasePart
	local height = 0.5 * root.Size.Y + humanoid.HipHeight
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = character:FindFirstChild("Left Leg") :: BasePart?
		if leg ~= nil then
			height += leg.Size.Y
		end
	end
	return height
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

local CharacterService: CharacterService = {
	name = "CharacterService",
	dependencies = { "Config", "ArenaService", "TeamService" },
	characterRemoved = Signal.new(),
	_config = nil :: any,
	_teamSpawns = {},
	_teams = nil,
	_characters = {},
	_order = {},
	_watchers = {},
	_holders = {},

	init = function(self: CharacterService, deps: { [string]: any })
		self._config = deps.Config
		self._teamSpawns = deps.ArenaService.arena.teamSpawns
		self._teams = deps.TeamService
		self._characters = {}
		self._order = {}
		self._watchers = {}
		self._holders = {}
		self.characterRemoved = Signal.new()
	end,

	start = function(self: CharacterService)
		Players.CharacterAutoLoads = false
		local function load(id: PlayerId)
			local userId = tonumber(id)
			local player = if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
			if player ~= nil and self._teams:teamOf(id) ~= nil then
				player:LoadCharacter()
			end
		end
		local function watch(player: Player)
			local id = tostring(player.UserId)
			player.CharacterAdded:Connect(function(character: Model)
				self:adopt(id, character)
				self:place(id, false)
				local humanoid = character:WaitForChild("Humanoid") :: Humanoid
				humanoid.Died:Connect(function()
					task.delay(self._config.Match.respawnSeconds, load, id)
				end)
			end)
		end
		Players.PlayerAdded:Connect(watch)
		for _, player in Players:GetPlayers() do
			watch(player)
		end
		self._teams.seated:Connect(function(id: PlayerId)
			local existing: Model? = self._characters[id]
			if existing == nil then
				load(id)
			end
		end)
		self._teams.unseated:Connect(function(id: PlayerId)
			local character: Model? = self._characters[id]
			if character ~= nil then
				character:Destroy()
			end
		end)
	end,

	adopt = function(self: CharacterService, player: PlayerId, character: Model)
		forget(self, player)
		self._characters[player] = character
		table.insert(self._order, player)
		local function removed()
			if self._characters[player] == character then
				forget(self, player)
				self.characterRemoved:Fire(player)
			end
		end
		local watchers = { character.Destroying:Connect(removed) }
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil then
			table.insert(watchers, humanoid.Died:Connect(removed))
		end
		self._watchers[player] = watchers
	end,

	place = function(self: CharacterService, player: PlayerId, frozen: boolean)
		local character: Model? = self._characters[player]
		local team, slot = self._teams:slotOf(player)
		if character == nil or team == nil or slot == nil then
			return
		end
		local spawn = self._teamSpawns[team][slot]
		character:PivotTo(spawn * CFrame.new(0, standingHeight(character), 0))
		local root = rootOf(character)
		if root ~= nil then
			root.Anchored = frozen
		end
	end,

	placeAll = function(self: CharacterService, frozen: boolean)
		for _, player in table.clone(self._order) do
			self:place(player, frozen)
		end
	end,

	freezeAll = function(self: CharacterService, frozen: boolean)
		for _, character in self._characters do
			local root = rootOf(character)
			if root ~= nil then
				root.Anchored = frozen
			end
		end
	end,

	-- Living characters with a root and a hand, in adoption order; one reused list of reused records.
	holders = function(self: CharacterService): { BallService.Holder }
		local holders = self._holders
		local count = 0
		for _, player in self._order do
			local character = self._characters[player]
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root, hand = rootOf(character), handOf(character)
			if humanoid ~= nil and humanoid.Health > 0 and root ~= nil and hand ~= nil then
				count += 1
				local holder = holders[count]
				if holder == nil then
					holders[count] = { player = player, root = root, hand = hand }
				else
					holder.player = player
					holder.root = root
					holder.hand = hand
				end
			end
		end
		for index = #holders, count + 1, -1 do
			holders[index] = nil
		end
		return holders
	end,

	standingHeight = standingHeight,
}

return CharacterService
