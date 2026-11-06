--!strict
-- The goal's worth in its open middle (#411, the owner's Q294 and Q306; Arena spec §5.3): once the goal's door has
-- opened (arenaGlow.doorSeconds after the goal opens), a see-through disc in the open team's colour fills the opening,
-- with the goal's worth (+1, +3 or +5, as the scoreboard's chip says it: HudText.worth) on both its faces in the
-- banners' lettering, each face read the right way from its own side. The number pops in as it shows and on each
-- change with the banners' pop (Motion.pop). It all hides at once when the goal shuts. Each client draws its own: the
-- parts stay on this client, UI.goalWorth.behind studs behind the door's plane, and nothing hits, sees or touches them.
-- Stepped before each frame is drawn (FrameController), after the arena's glow: a step writes only what changed, and
-- the pop's scale only while it pops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaParts = require(script.Parent.ArenaParts)
local Config = require(ReplicatedStorage.Shared.Config)
local Crossing = require(ReplicatedStorage.Shared.Rules.Crossing)
local DrawOnly = require(ReplicatedStorage.Shared.Util.DrawOnly)
local HudStore = require(script.Parent.HudStore)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local Motion = require(ReplicatedStorage.Shared.Hud.Motion)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

type Team = Team.Team

local HIDDEN = 1
-- TextScaled draws text at most 100 px tall (measured in Studio): each face gives the number exactly that many pixels,
-- its sharpest.
local MAX_TEXT_PIXELS = 100
-- How far each face stands off the disc's, so the text is never inside the disc.
local FACE_LIFT = 0.05
-- A cylinder's axis is its X: turned to lie along the goal's LookVector, it fills the opening.
local ACROSS_OPENING = CFrame.Angles(0, math.pi / 2, 0)

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type GoalWorth = {
	name: string,
	dependencies: { string },
	init: (self: GoalWorth, deps: { [string]: any }) -> (),
	start: (self: GoalWorth) -> (),
	step: (self: GoalWorth, dt: number) -> (),
	-- The disc and the faces, built at start.
	model: Model,
	_config: Config.GameConfig,
	_store: HudStore.HudStore,
	_arena: ArenaParts.ArenaParts,
	_parent: Instance,
	_text: HudText.HudText,
	_disc: BasePart,
	_face: BasePart,
	_guis: { SurfaceGui },
	_labels: { TextLabel },
	_scales: { UIScale },
	-- What was last acted on: where the goal was, the seconds since it opened (nil while shut), whether the worth
	-- shows, in whose colour, what it says, and the seconds into its pop (nil when not popping).
	_goal: Crossing.Disc?,
	_opened: number?,
	_shown: boolean,
	_team: Team?,
	_worth: string?,
	_popped: number?,
}

local function newPart(name: string, parent: Instance): Part
	local part = Instance.new("Part")
	DrawOnly(part)
	part.Name = name
	part.Anchored = true
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = HIDDEN
	part.Parent = parent
	return part
end

-- Puts the disc and the faces in `goal`'s opening, behind its door, sized by it.
local function place(self: GoalWorth, goal: Crossing.Disc)
	self._goal = goal
	local settings = self._config.UI.goalWorth
	local diameter = 2 * goal.radius * settings.fill
	local frame = goal.frame * CFrame.new(0, 0, -settings.behind)
	self._disc.Size = Vector3.new(settings.thickness, diameter, diameter)
	self._disc.CFrame = frame * ACROSS_OPENING
	self._face.Size = Vector3.new(diameter, diameter, settings.thickness + 2 * FACE_LIFT)
	self._face.CFrame = frame
	for _, gui in self._guis do
		gui.PixelsPerStud = MAX_TEXT_PIXELS / (diameter * settings.textHeight)
	end
end

local function hide(self: GoalWorth)
	if self._shown then
		self._shown = false
		self._disc.Transparency = HIDDEN
		for _, gui in self._guis do
			gui.Enabled = false
		end
	end
	-- The next showing pops in.
	self._worth = nil
	self._popped = nil
end

local function show(self: GoalWorth, team: Team, worth: string, dt: number)
	if not self._shown then
		self._shown = true
		self._disc.Transparency = self._config.UI.goalWorth.transparency
		for _, gui in self._guis do
			gui.Enabled = true
		end
	end
	if team ~= self._team then
		self._team = team
		self._disc.Color = self._config.UI.teamColors[team]
	end
	if worth ~= self._worth then
		self._worth = worth
		for _, label in self._labels do
			label.Text = worth
		end
		self._popped = 0
	end
	local popped = self._popped
	if popped ~= nil then
		local motion = self._config.UI.hud.motion
		popped += dt
		local scale = Motion.pop(motion, popped)
		for _, uiScale in self._scales do
			uiScale.Scale = scale
		end
		self._popped = if popped < motion.pop.seconds then popped else nil
	end
end

local GoalWorth: GoalWorth = {
	name = "GoalWorth",
	dependencies = { "Config", "HudStore", "ArenaParts" },
	model = nil :: any,
	_config = nil :: any,
	_store = nil :: any,
	_arena = nil :: any,
	_parent = nil :: any,
	_text = nil :: any,
	_disc = nil :: any,
	_face = nil :: any,
	_guis = {},
	_labels = {},
	_scales = {},
	_goal = nil,
	_opened = nil,
	_shown = false,
	_team = nil,
	_worth = nil,
	_popped = nil,

	-- deps.Parent replaces the workspace in tests.
	init = function(self: GoalWorth, deps: { [string]: any })
		self._config = deps.Config
		self._store = deps.HudStore
		self._arena = deps.ArenaParts
		self._parent = deps.Parent or workspace
		self._text = HudText.new(deps.Config)
		self._goal = nil
		self._opened = nil
		self._shown = false
		self._team = nil
		self._worth = nil
		self._popped = nil
	end,

	start = function(self: GoalWorth)
		local look, settings = self._config.UI.hud.look, self._config.UI.goalWorth
		local model = Instance.new("Model")
		model.Name = "GoalWorth"
		local disc = newPart("Disc", model)
		-- Before Size, so the cylinder keeps the size it is given.
		disc.Shape = Enum.PartType.Cylinder
		local face = newPart("Face", model)
		local guis, labels, scales = {}, {}, {}
		for _, side in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Name = side.Name
			gui.Face = side
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.LightInfluence = 0
			gui.Enabled = false
			local label = Instance.new("TextLabel")
			label.Name = "Worth"
			label.BackgroundTransparency = 1
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromScale(0.5, 0.5)
			label.Size = UDim2.fromScale(1, settings.textHeight)
			label.Font = look.bannerFont
			label.TextColor3 = self._config.UI.hud.textColor
			label.TextScaled = true
			local stroke = Instance.new("UIStroke")
			stroke.Color = look.ink
			stroke.Thickness = look.textOutline
			stroke.Parent = label
			local uiScale = Instance.new("UIScale")
			uiScale.Parent = label
			label.Parent = gui
			gui.Parent = face
			table.insert(guis, gui)
			table.insert(labels, label)
			table.insert(scales, uiScale)
		end
		self._disc, self._face = disc, face
		self._guis, self._labels, self._scales = guis, labels, scales
		model.Parent = self._parent
		self.model = model
	end,

	step = function(self: GoalWorth, dt: number)
		local parts = self._arena.parts
		local match = self._store.state.match
		local team: Team? = if match ~= nil then match.goalOpenFor else nil
		if parts == nil or match == nil or team == nil then
			self._opened = nil
			hide(self)
			return
		end
		if parts.goal ~= self._goal then
			place(self, parts.goal)
		end
		local opened = (self._opened or 0) + dt
		self._opened = opened
		if opened < self._config.UI.arenaGlow.doorSeconds then
			hide(self)
			return
		end
		show(self, team, self._text:worth(match) :: string, dt)
	end,
}

return GoalWorth
