--!strict
-- Name tags (spec §11.1), stepped before each frame is drawn (FrameController), last:
-- - over every other player with a seat (the Team attribute) and a character, their display name in their team's
--   colour, seen through walls (the owner's choice: a BillboardGui, AlwaysOnTop) at any distance;
-- - above the name, a row: a raised hand while a teammate calls for the ball (their character's CallingPass), never
--   over an opponent; and over the teammate a pass would go to (ActionController:passTarget, #315), the pass key's cap,
--   as Roller Champions floats the pass key's letter there (Video 34 at 41.6 s): the key as the HUD's hint shows it
--   (Hud.passKey), drawn by the HUD's own Style.key through one small React root and moved from row to row, right of
--   the hand while they call, else alone in the row's middle.
-- The local player has no tag (the plan's decision 12). A tag follows its player to a new character or team, and is
-- dropped once they leave, lose their character or their seat. Each tag sits straight under PlayerGui with
-- ResetOnSpawn off, as a respawn deleted a folder there (probed in Play). A property is written only when it changes,
-- and the cap is drawn again only when its key does, so a steady step allocates nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local PlayerList = require(ReplicatedStorage.Shared.Util.PlayerList)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)
local Style = require(script.Parent.Hud.Style)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type Team = Team.Team

-- One player's tag, with what was last written to it.
type Tag = {
	gui: BillboardGui,
	name: TextLabel,
	-- The row above the name: the hand, and the pass key's cap while they are a pass's target.
	row: Frame,
	call: TextLabel,
	root: BasePart,
	team: Team,
	player: Types.PlayerId,
	calling: boolean,
	-- The step that last found its player.
	seen: number,
}

-- What the tags read of the actions and the HUD (ActionController and Hud; fakes in tests).
type PassAim = { passTarget: (self: any) -> Types.PlayerId? }
type PassKey = { passKey: Style.KeyView? }

-- Spelled out so the module is a Loader.LoadableModule and callers see its members.
export type NameTags = {
	name: string,
	dependencies: { string },
	init: (self: NameTags, deps: { [string]: any }) -> (),
	start: (self: NameTags) -> (),
	step: (self: NameTags, dt: number) -> (),
	-- Unmounts the pass key's React root (tests).
	destroy: (self: NameTags) -> (),
	_config: Config.GameConfig,
	_actions: PassAim,
	_hud: PassKey,
	-- Where the tags go, each named by its player's PlayerId.
	_parent: Instance,
	-- The game's players and the local one, or fakes.
	_players: () -> { Player },
	_localPlayer: Player,
	_playerList: PlayerList.PlayerList?,
	_tags: { [Player]: Tag },
	_stepId: number,
	-- The pass key's cap: its holder, the React root that draws it there, the key it last drew, and the row it sits
	-- in (none while no pass would go anywhere).
	_key: Frame,
	_keyRoot: ReactRoblox.RootType,
	_keyShown: Style.KeyView?,
	_keyRow: Frame?,
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

-- The row above the name, `height` pixels tall: its parts side by side in their LayoutOrder, centred, the HUD's
-- spacing apart; one hidden takes no room.
local function newRow(config: Config.GameConfig, height: number): Frame
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, height)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, config.UI.hud.spacing)
	layout.Parent = row
	return row
end

local function newTag(self: NameTags, player: Player, root: BasePart, team: Team): Tag
	local config = self._config
	local settings = config.UI.nameTag
	local id = PlayerIds.of(player)
	local gui = Instance.new("BillboardGui")
	gui.Name = id
	gui.AlwaysOnTop = true
	gui.ResetOnSpawn = false
	gui.Size = settings.size
	gui.StudsOffset = settings.studsOffset
	gui.Adornee = root
	-- The name sits at the tag's bottom, nearest the player, and the row above it.
	local name = newLabel("Name", player.DisplayName, settings.textSize, config.UI.teamColors[team], config)
	name.AnchorPoint = Vector2.new(0, 1)
	name.Position = UDim2.fromScale(0, 1)
	name.Parent = gui
	local row = newRow(config, settings.callSize)
	-- As wide as the hand itself, first in the row.
	local call = newLabel("Call", config.UI.text.callPass, settings.callSize, config.UI.hud.textColor, config)
	call.Size = UDim2.fromOffset(0, settings.callSize)
	call.AutomaticSize = Enum.AutomaticSize.X
	call.LayoutOrder = 1
	call.Visible = false
	call.Parent = row
	row.Parent = gui
	gui.Parent = self._parent
	local tag: Tag = {
		gui = gui,
		name = name,
		row = row,
		call = call,
		root = root,
		team = team,
		player = id,
		calling = false,
		seen = 0,
	}
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

-- Puts the pass key's cap in `tag`'s row, showing `view` as tall as the hand, or takes it out of every row for no tag
-- or no key. It is drawn again only when the key changes (another device).
local function placeKey(self: NameTags, tag: Tag?, view: Style.KeyView?)
	local row: Frame? = nil
	if tag ~= nil and view ~= nil then
		row = tag.row
		local shown = self._keyShown
		if shown == nil or shown.text ~= view.text or shown.image ~= view.image then
			self._keyShown = view
			local name, key = Style.key(self._config, view, self._config.UI.nameTag.callSize, 1)
			local children: { [string]: React.Node } = { [name] = key }
			self._keyRoot:render(React.createElement(React.Fragment, nil, children))
		end
	end
	if row ~= self._keyRow then
		self._keyRow = row
		self._key.Parent = row
	end
end

local NameTags: NameTags = {
	name = "NameTags",
	dependencies = { "Config", "ActionController", "Hud" },
	_config = nil :: any,
	_actions = nil :: any,
	_hud = nil :: any,
	_parent = nil :: any,
	_players = function(): { Player }
		return NO_PLAYERS
	end,
	_localPlayer = nil :: any,
	_playerList = nil,
	_tags = {},
	_stepId = 0,
	_key = nil :: any,
	_keyRoot = nil :: any,
	_keyShown = nil,
	_keyRow = nil,

	-- deps.Parent keeps the tags out of the local player's PlayerGui in tests; deps.Players and deps.LocalPlayer
	-- replace the game's players there.
	init = function(self: NameTags, deps: { [string]: any })
		self._config = deps.Config
		self._actions = deps.ActionController
		self._hud = deps.Hud
		self._players = deps.Players
			or function(): { Player }
				local playerList = self._playerList
				return if playerList ~= nil then playerList.list else NO_PLAYERS
			end
		self._localPlayer = deps.LocalPlayer or Players.LocalPlayer :: Player
		self._parent = deps.Parent or self._localPlayer:WaitForChild("PlayerGui")
		self._tags = {}
		self._stepId = 0
		-- After the hand in its row, sized to the cap it holds.
		local key = Instance.new("Frame")
		key.Name = "PassKey"
		key.BackgroundTransparency = 1
		key.AutomaticSize = Enum.AutomaticSize.XY
		key.LayoutOrder = 2
		self._key = key
		self._keyRoot = ReactRoblox.createLegacyRoot(key)
		self._keyShown = nil
		self._keyRow = nil
	end,

	start = function(self: NameTags)
		self._playerList = PlayerList.new(Players)
	end,

	destroy = function(self: NameTags)
		self._keyRoot:unmount()
		self._key:Destroy()
	end,

	step = function(self: NameTags, _dt: number)
		local stepId = self._stepId + 1
		self._stepId = stepId
		local localPlayer = self._localPlayer
		local localTeam = localPlayer:GetAttribute(Attributes.Team)
		local view = self._hud.passKey
		local target = if view ~= nil then self._actions:passTarget() else nil
		local targetTag: Tag? = nil
		local tags = self._tags
		for _, player in self._players() do
			if player ~= localPlayer then
				local team: Team? = player:GetAttribute(Attributes.Team) :: Team?
				local character = player.Character
				local root = if character ~= nil then character:FindFirstChild(SkaterRig.root) :: BasePart? else nil
				if team ~= nil and character ~= nil and root ~= nil then
					local tag = tags[player] or newTag(self, player, root, team)
					tag.seen = stepId
					local teammate = team == localTeam
					show(self, tag, root, team, teammate and character:GetAttribute(Attributes.CallingPass) ~= nil)
					if teammate and tag.player == target then
						targetTag = tag
					end
				end
			end
		end
		-- Before any tag goes: the cap never goes with one.
		placeKey(self, targetTag, view)
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
