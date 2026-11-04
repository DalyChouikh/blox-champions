--!strict
-- Name tags (spec §11.1), stepped before each frame is drawn (FrameController), last: over every other player with a
-- seat (the Team attribute) and a character, their display name, seen through walls (the owner's choice: a
-- BillboardGui, AlwaysOnTop) at any distance. Over a teammate, the call's badge while they call for the ball (their
-- character's CallingPass), and the pass key while a pass would go to them (ActionController:passTarget, #315), as
-- Roller Champions floats the pass key's letter there (Video 34 at 41.6 s), the key as the HUD's hint shows it
-- (Hud.passKey). Hud/NameTag draws them in look C (#358) at the Hud's screen's sizes.
-- The local player has no tag (the plan's decision 12). A tag follows its player to a new character or team, and is
-- dropped once they leave, lose their character or their seat. Each tag sits straight under PlayerGui with
-- ResetOnSpawn off, as a respawn deleted a folder there (probed in Play). A tag is drawn again only when what it shows
-- changes; while anyone calls, the call moves by writing the bindings every calling tag shares, from sizes made once
-- per screen, so a step allocates nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local CallBadge = require(ReplicatedStorage.Shared.Hud.CallBadge)
local Config = require(ReplicatedStorage.Shared.Config)
local NameTag = require(script.Parent.Hud.NameTag)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local PlayerList = require(ReplicatedStorage.Shared.Util.PlayerList)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)
local Style = require(script.Parent.Hud.Style)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type Team = Team.Team

-- One player's tag, with what it last drew.
type Tag = {
	gui: BillboardGui,
	drawing: ReactRoblox.RootType,
	adornee: BasePart,
	player: Types.PlayerId,
	-- The step that last found its player.
	seen: number,
	name: string,
	team: Team,
	calling: boolean,
	key: Style.KeyView?,
	sizes: Config.TagSizes,
	-- Style.widths' generation it measured its name in.
	generation: number,
}

-- What the tags read of the actions and the HUD (ActionController and Hud; fakes in tests).
type PassAim = { passTarget: (self: any) -> Types.PlayerId? }
type HudView = { passKey: Style.KeyView?, compact: boolean }

-- Spelled out so the module is a Loader.LoadableModule and callers see its members.
export type NameTags = {
	name: string,
	dependencies: { string },
	init: (self: NameTags, deps: { [string]: any }) -> (),
	start: (self: NameTags) -> (),
	step: (self: NameTags, dt: number) -> (),
	-- Unmounts every tag's drawing (tests).
	destroy: (self: NameTags) -> (),
	-- How many times a tag was drawn, and the call's bindings written (tests: none at rest).
	renders: number,
	writes: number,
	_config: Config.GameConfig,
	_actions: PassAim,
	_hud: HudView,
	-- Where the tags go, each named by its player's PlayerId.
	_parent: Instance,
	-- The game's players and the local one, or fakes.
	_players: () -> { Player },
	_localPlayer: Player,
	_playerList: PlayerList.PlayerList?,
	_tags: { [Player]: Tag },
	_stepId: number,
	-- The call's bindings, and how long it has run: from the first step anyone calls, since no one did.
	_call: NameTag.CallBindings,
	_setTurn: (number) -> (),
	_setRing: (UDim2) -> (),
	_setFade: (number) -> (),
	_callSeconds: number,
	-- The ring's sizes on each kind of screen, by how many pixels it has grown (a UDim2 made per frame would allocate).
	_rings: { [Config.TagSizes]: { UDim2 } },
}

-- Who a step walks before start.
local NO_PLAYERS: { Player } = table.freeze({})

-- Whether two keys draw alike: Hud.passKey makes a new one at each of its renders.
local function sameKey(a: Style.KeyView?, b: Style.KeyView?): boolean
	if a == nil or b == nil then
		return a == b
	end
	return a.text == b.text and a.image == b.image and a.mouse == b.mouse
end

-- The tag at `sizes`: its pill on its middle, lifted in pixels so the pill's ink and shadow rest on the studs point
-- over the head at any distance, where its middle on that point would cover the head from afar.
local function size(self: NameTags, gui: BillboardGui, sizes: Config.TagSizes)
	local look = self._config.UI.hud.look
	gui.Size = UDim2.fromOffset(sizes.width, sizes.height)
	gui.SizeOffset = Vector2.new(0, (sizes.pillHeight / 2 + look.outline + look.shadow) / sizes.height)
end

local function newTag(self: NameTags, player: Player, root: BasePart, team: Team, sizes: Config.TagSizes): Tag
	local id = PlayerIds.of(player)
	local gui = Instance.new("BillboardGui")
	gui.Name = id
	gui.AlwaysOnTop = true
	gui.ResetOnSpawn = false
	-- Look C's parts lie in ZIndex order among their siblings; a BillboardGui would compare them across the whole tag.
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	size(self, gui, sizes)
	gui.StudsOffset = self._config.UI.nameTag.studsOffset
	gui.Adornee = root
	gui.Parent = self._parent
	local tag: Tag = {
		gui = gui,
		drawing = ReactRoblox.createLegacyRoot(gui),
		adornee = root,
		player = id,
		seen = 0,
		-- Nothing drawn yet: the first `show` draws it.
		name = "",
		team = team,
		calling = false,
		key = nil,
		sizes = sizes,
		generation = -1,
	}
	self._tags[player] = tag
	return tag
end

-- Follows a new character; draws the tag again when what it shows has changed.
local function show(
	self: NameTags,
	tag: Tag,
	player: Player,
	root: BasePart,
	team: Team,
	calling: boolean,
	key: Style.KeyView?,
	sizes: Config.TagSizes
)
	if root ~= tag.adornee then
		tag.adornee = root
		tag.gui.Adornee = root
	end
	local name, generation = player.DisplayName, Style.widths.generation
	if
		name == tag.name
		and team == tag.team
		and calling == tag.calling
		and sameKey(key, tag.key)
		and sizes == tag.sizes
		and generation == tag.generation
	then
		return
	end
	if sizes ~= tag.sizes then
		size(self, tag.gui, sizes)
	end
	tag.name, tag.team, tag.calling, tag.key, tag.sizes, tag.generation = name, team, calling, key, sizes, generation
	self.renders += 1
	tag.drawing:render(React.createElement(NameTag, {
		config = self._config,
		sizes = sizes,
		name = name,
		color = Style.teamColor(self._config, team),
		passKey = key,
		calling = calling,
		call = self._call,
	}))
end

-- The ring's sizes on a screen of `sizes`, made the first time it is asked for.
local function ringsOf(self: NameTags, sizes: Config.TagSizes): { UDim2 }
	local rings = self._rings[sizes]
	if rings == nil then
		rings = table.create(sizes.ripple + 1)
		for grown = 0, sizes.ripple do
			local across = 2 * (sizes.badge + grown)
			rings[grown + 1] = UDim2.fromOffset(across, across)
		end
		self._rings[sizes] = rings
	end
	return rings
end

-- A step of the call: its glove's turn, its ring's size and fade.
local function moveCall(self: NameTags, sizes: Config.TagSizes, dt: number)
	local call = self._config.UI.nameTag.call
	local seconds = self._callSeconds + dt
	self._callSeconds = seconds
	local share = CallBadge.ripple(call, seconds)
	self._setTurn(CallBadge.wave(call, seconds))
	self._setRing(ringsOf(self, sizes)[math.floor(share * sizes.ripple) + 1])
	self._setFade(share)
	self.writes += 3
end

local function remove(tag: Tag)
	tag.drawing:unmount()
	tag.gui:Destroy()
end

local NameTags: NameTags = {
	name = "NameTags",
	dependencies = { "Config", "ActionController", "Hud" },
	renders = 0,
	writes = 0,
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
	_call = nil :: any,
	_setTurn = nil :: any,
	_setRing = nil :: any,
	_setFade = nil :: any,
	_callSeconds = 0,
	_rings = {},

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
		self.renders = 0
		self.writes = 0
		local turn, setTurn = React.createBinding(0)
		local ring, setRing = React.createBinding(UDim2.new())
		local fade, setFade = React.createBinding(0)
		self._call = { turn = turn, ring = ring, fade = fade }
		self._setTurn, self._setRing, self._setFade = setTurn, setRing, setFade
		self._callSeconds = 0
		self._rings = {}
	end,

	start = function(self: NameTags)
		self._playerList = PlayerList.new(Players)
	end,

	destroy = function(self: NameTags)
		for _, tag in self._tags do
			remove(tag)
		end
		table.clear(self._tags)
	end,

	step = function(self: NameTags, dt: number)
		local stepId = self._stepId + 1
		self._stepId = stepId
		local localPlayer = self._localPlayer
		local localTeam = localPlayer:GetAttribute(Attributes.Team)
		local hud = self._hud
		local nameTag = self._config.UI.nameTag
		local sizes = if hud.compact then nameTag.compactSizes else nameTag.sizes
		local view = hud.passKey
		local target = if view ~= nil then self._actions:passTarget() else nil
		local anyCalling = false
		local tags = self._tags
		for _, player in self._players() do
			if player ~= localPlayer then
				local team: Team? = player:GetAttribute(Attributes.Team) :: Team?
				local character = player.Character
				local root = if character ~= nil then character:FindFirstChild(SkaterRig.root) :: BasePart? else nil
				if team ~= nil and character ~= nil and root ~= nil then
					local tag = tags[player] or newTag(self, player, root, team, sizes)
					tag.seen = stepId
					local teammate = team == localTeam
					local calling = teammate and character:GetAttribute(Attributes.CallingPass) ~= nil
					anyCalling = anyCalling or calling
					show(
						self,
						tag,
						player,
						root,
						team,
						calling,
						if teammate and tag.player == target then view else nil,
						sizes
					)
				end
			end
		end
		if anyCalling then
			moveCall(self, sizes, dt)
		else
			self._callSeconds = 0
		end
		-- Clearing a field while walking a table is allowed.
		for player, tag in tags do
			if tag.seen ~= stepId then
				remove(tag)
				tags[player] = nil
			end
		end
	end,
}

return NameTags
