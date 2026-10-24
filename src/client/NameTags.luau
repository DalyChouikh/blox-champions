--!strict
-- Name tags (spec §11.1), stepped before each frame is drawn (FrameController), last:
-- - over every other player with a seat (the Team attribute) and a character, their display name in their team's
--   colour, seen through walls (the owner's choice: a BillboardGui, AlwaysOnTop) at any distance;
-- - above the name, a raised hand while a teammate calls for the ball (their character's CallingPass), never over an
--   opponent.
-- The local player has no tag (the plan's decision 12). A tag follows its player to a new character or team, and is
-- dropped once they leave, lose their character or their seat. Each tag sits straight under PlayerGui with
-- ResetOnSpawn off, as a respawn deleted a folder there (probed in Play). A property is written only when it changes,
-- so a steady step allocates nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local PlayerList = require(ReplicatedStorage.Shared.Util.PlayerList)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

type Team = Team.Team

-- One player's tag, with what was last written to it.
type Tag = {
	gui: BillboardGui,
	name: TextLabel,
	call: TextLabel,
	root: BasePart,
	team: Team,
	calling: boolean,
	-- The step that last found its player.
	seen: number,
}

-- Spelled out so the module is a Loader.LoadableModule and callers see its members.
export type NameTags = {
	name: string,
	dependencies: { string },
	init: (self: NameTags, deps: { [string]: any }) -> (),
	start: (self: NameTags) -> (),
	step: (self: NameTags, dt: number) -> (),
	_config: Config.GameConfig,
	-- Where the tags go, each named by its player's PlayerId.
	_parent: Instance,
	-- The game's players and the local one, or fakes.
	_players: () -> { Player },
	_localPlayer: Player,
	_playerList: PlayerList.PlayerList?,
	_tags: { [Player]: Tag },
	_stepId: number,
}

-- Who a step walks before start.
local NO_PLAYERS: { Player } = table.freeze({})

local function newLabel(name: string, text: string, size: number, color: Color3, config: Config.GameConfig): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Font = config.UI.hud.font
	label.TextSize = size
	label.TextColor3 = color
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, size)
	return label
end

local function newTag(self: NameTags, player: Player, root: BasePart, team: Team): Tag
	local config = self._config
	local settings = config.UI.nameTag
	local gui = Instance.new("BillboardGui")
	gui.Name = PlayerIds.of(player)
	gui.AlwaysOnTop = true
	gui.ResetOnSpawn = false
	gui.Size = settings.size
	gui.StudsOffset = settings.studsOffset
	gui.Adornee = root
	-- The name sits at the tag's bottom, nearest the player, and the hand above it.
	local name = newLabel("Name", player.DisplayName, settings.textSize, config.UI.teamColors[team], config)
	name.AnchorPoint = Vector2.new(0, 1)
	name.Position = UDim2.fromScale(0, 1)
	name.Parent = gui
	local call = newLabel("Call", config.UI.text.callPass, settings.callSize, config.UI.hud.textColor, config)
	call.Visible = false
	call.Parent = gui
	gui.Parent = self._parent
	local tag: Tag = { gui = gui, name = name, call = call, root = root, team = team, calling = false, seen = 0 }
	self._tags[player] = tag
	return tag
end

-- Writes what changed since the tag was last shown.
local function show(self: NameTags, tag: Tag, root: BasePart, team: Team, calling: boolean)
	if root ~= tag.root then
		tag.root = root
		tag.gui.Adornee = root
	end
	if team ~= tag.team then
		tag.team = team
		tag.name.TextColor3 = self._config.UI.teamColors[team]
	end
	if calling ~= tag.calling then
		tag.calling = calling
		tag.call.Visible = calling
	end
end

local NameTags: NameTags = {
	name = "NameTags",
	dependencies = { "Config" },
	_config = nil :: any,
	_parent = nil :: any,
	_players = function(): { Player }
		return NO_PLAYERS
	end,
	_localPlayer = nil :: any,
	_playerList = nil,
	_tags = {},
	_stepId = 0,

	-- deps.Parent keeps the tags out of the local player's PlayerGui in tests; deps.Players and deps.LocalPlayer
	-- replace the game's players there.
	init = function(self: NameTags, deps: { [string]: any })
		self._config = deps.Config
		self._players = deps.Players
			or function(): { Player }
				local playerList = self._playerList
				return if playerList ~= nil then playerList.list else NO_PLAYERS
			end
		self._localPlayer = deps.LocalPlayer or Players.LocalPlayer :: Player
		self._parent = deps.Parent or self._localPlayer:WaitForChild("PlayerGui")
		self._tags = {}
		self._stepId = 0
	end,

	start = function(self: NameTags)
		self._playerList = PlayerList.new(Players)
	end,

	step = function(self: NameTags, _dt: number)
		local stepId = self._stepId + 1
		self._stepId = stepId
		local localPlayer = self._localPlayer
		local localTeam = localPlayer:GetAttribute(Attributes.Team)
		local tags = self._tags
		for _, player in self._players() do
			if player ~= localPlayer then
				local team: Team? = player:GetAttribute(Attributes.Team) :: Team?
				local character = player.Character
				local root = if character ~= nil then character:FindFirstChild(SkaterRig.root) :: BasePart? else nil
				if team ~= nil and character ~= nil and root ~= nil then
					local tag = tags[player] or newTag(self, player, root, team)
					tag.seen = stepId
					local calling = team == localTeam and character:GetAttribute(Attributes.CallingPass) == true
					show(self, tag, root, team, calling)
				end
			end
		end
		-- Clearing a field while walking a table is allowed.
		for player, tag in tags do
			if tag.seen ~= stepId then
				tag.gui:Destroy()
				tags[player] = nil
			end
		end
	end,
}

return NameTags
