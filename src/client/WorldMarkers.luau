--!strict
-- The ball's team colour and the ball's marks in the world (spec §9.4, §11.1), stepped before each frame is drawn
-- (FrameController):
-- - the ball itself in the colour of the team that last held it, carried, flying or loose, and in its skin's own colour
--   until a team has since the kickoff (the owner, #327, Q158, Q159: Roller Champions', Video 31), painted on its look
--   (#400: what draws the unseen ball part, Ball/Look; the skin's picture lies over that colour). A client's write
--   stays on its client and the server never writes the colour again, so it is written when the look or the colour
--   changes (a respawn's new ball arrives in its skin's);
-- - a ring around the ball, seen through walls (a BillboardGui, AlwaysOnTop), as wide as the ball plus ringSize pixels;
-- - a line from the ball down to a disc on the ground below it (one ray through the ride surfaces), both hidden when
--   nothing lies within groundProbe studs.
-- The marks take the colour of the team that last held the ball, or the HUD's text colour until a team has (the match
-- keeps its possessing team through throws, passes, drops and respawns until a kickoff), and hide while there is no
-- ball. The screen's markers, for the ball off the screen and the carrier's next gate, are the HUD's (#376). A
-- property is written only when it changes; a step allocates only the disc's frame and the ray's result.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallPart = require(script.Parent.BallPart)
local BallSkins = require(ReplicatedStorage.Shared.Skins.BallSkins)
local Config = require(ReplicatedStorage.Shared.Config)
local DrawOnly = require(ReplicatedStorage.Shared.Util.DrawOnly)
local HudStore = require(script.Parent.HudStore)
local RideSurfaces = require(script.Parent.RideSurfaces)
local Style = require(script.Parent.Hud.Style)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

type Team = Team.Team

-- Spelled out so the module is a Loader.LoadableModule and callers see its members.
export type WorldMarkers = {
	name: string,
	dependencies: { string },
	init: (self: WorldMarkers, deps: { [string]: any }) -> (),
	start: (self: WorldMarkers) -> (),
	step: (self: WorldMarkers, dt: number) -> (),
	ring: BillboardGui,
	ground: Part,
	line: Beam,
	_config: Config.GameConfig,
	_surfaces: RideSurfaces.RideSurfaces,
	_ballPart: BallPart.BallPart,
	_store: HudStore.HudStore,
	-- workspace:Raycast, or a fake.
	_raycast: (origin: Vector3, direction: Vector3, params: RaycastParams) -> RaycastResult?,
	-- The line's ends: on the ball (moved to it each step) and on the disc.
	_top: Attachment,
	_stroke: UIStroke,
	-- The ball's colour until a team holds it: its skin's.
	_neutral: Color3,
	-- What was last written: the marks' colour, and the ball's look given a colour and that colour.
	_color: Color3?,
	_worn: BasePart?,
	_wornColor: Color3?,
	_hasBall: boolean,
	_grounded: boolean,
}

-- Down, for the ray from the ball to the ground.
local DOWN = -Vector3.yAxis

-- Every mark in `color`, written when it changes.
local function paint(self: WorldMarkers, color: Color3)
	if color == self._color then
		return
	end
	self._color = color
	self._stroke.Color = color
	self.ground.Color = color
	self.line.Color = ColorSequence.new(color)
end

-- The ball's look in `team`'s colour, or its skin's with no team, written when the look or the colour changes.
local function wear(self: WorldMarkers, look: BasePart?, team: Team?)
	local color = if team ~= nil then self._config.UI.teamColors[team] else self._neutral
	if look ~= nil and (look ~= self._worn or color ~= self._wornColor) then
		look.Color = color
		self._worn = look
		self._wornColor = color
	end
end

-- The disc and the line, shown while the ray below the ball hits a ride surface.
local function setGrounded(self: WorldMarkers, grounded: boolean)
	if grounded == self._grounded then
		return
	end
	self._grounded = grounded
	self.ground.Transparency = if grounded then self._config.UI.markers.groundMarkerTransparency else 1
	self.line.Enabled = grounded
end

local function placeBall(self: WorldMarkers, ball: BasePart?)
	local hasBall = ball ~= nil
	if hasBall ~= self._hasBall then
		self._hasBall = hasBall
		self.ring.Enabled = hasBall
	end
	if ball == nil then
		setGrounded(self, false)
		return
	end
	if self.ring.Adornee ~= ball then
		self.ring.Adornee = ball
	end
	local markers = self._config.UI.markers
	local position = ball.Position
	local hit = self._raycast(position, DOWN * markers.groundProbe, self._surfaces.params)
	setGrounded(self, hit ~= nil)
	if hit ~= nil then
		-- The disc lies flat on the surface: its axis (a cylinder's X) along the surface's normal.
		local normal = hit.Normal
		local side = normal:Cross(if math.abs(normal.Z) < 0.9 then Vector3.zAxis else Vector3.xAxis).Unit
		self.ground.CFrame =
			CFrame.fromMatrix(hit.Position + normal * (markers.groundMarkerThickness / 2), normal, side)
		self._top.WorldPosition = position
	end
end

local WorldMarkers: WorldMarkers = {
	name = "WorldMarkers",
	dependencies = { "Config", "RideSurfaces", "BallPart", "HudStore" },
	ring = nil :: any,
	ground = nil :: any,
	line = nil :: any,
	_config = nil :: any,
	_surfaces = nil :: any,
	_ballPart = nil :: any,
	_store = nil :: any,
	_raycast = function(_origin: Vector3, _direction: Vector3, _params: RaycastParams): RaycastResult?
		return nil
	end,
	_top = nil :: any,
	_stroke = nil :: any,
	_neutral = Color3.new(),
	_color = nil,
	_worn = nil,
	_wornColor = nil,
	_hasBall = false,
	_grounded = false,

	-- deps.Parent keeps the ring out of the local player's PlayerGui in tests, and deps.World the disc out of the
	-- workspace; deps.Raycast replaces the live game there.
	init = function(self: WorldMarkers, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		local markers = config.UI.markers
		self._config = config
		self._surfaces = deps.RideSurfaces
		self._ballPart = deps.BallPart
		self._store = deps.HudStore
		self._raycast = deps.Raycast
			or function(origin: Vector3, direction: Vector3, params: RaycastParams): RaycastResult?
				return workspace:Raycast(origin, direction, params)
			end
		self._neutral = BallSkins.get(BallSkins.DEFAULT).color
		self._color = nil
		self._worn = nil
		self._wornColor = nil
		self._hasBall = false
		self._grounded = false
		local parent = deps.Parent or (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

		local ring = Instance.new("BillboardGui")
		ring.Name = "BallRing"
		ring.AlwaysOnTop = true
		ring.ResetOnSpawn = false
		-- A billboard's Size scale is in studs (Roblox's guide), so the ring stays as wide as the ball at any distance;
		-- the offset keeps it ringSize pixels wider, around the ball.
		local width = 2 * config.Ball.radius
		ring.Size = UDim2.new(width, markers.ringSize, width, markers.ringSize)
		ring.Enabled = false
		local circle = Instance.new("Frame")
		circle.Name = "Circle"
		circle.Size = UDim2.fromScale(1, 1)
		circle.BackgroundTransparency = 1
		circle.Parent = ring
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = circle
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Stroke"
		stroke.Thickness = markers.ringThickness
		stroke.Parent = circle
		ring.Parent = parent
		self.ring = ring
		self._stroke = stroke

		-- The disc touches nothing and no ray finds it.
		local ground = Instance.new("Part")
		DrawOnly(ground)
		ground.Name = "BallGround"
		ground.Shape = Enum.PartType.Cylinder
		ground.Size = Vector3.new(markers.groundMarkerThickness, markers.groundMarkerSize, markers.groundMarkerSize)
		ground.Anchored = true
		ground.CastShadow = false
		ground.Transparency = 1
		local top = Instance.new("Attachment")
		top.Name = "Top"
		top.Parent = ground
		local bottom = Instance.new("Attachment")
		bottom.Name = "Bottom"
		bottom.Parent = ground
		local line = Instance.new("Beam")
		line.Name = "BallLine"
		line.Attachment0 = top
		line.Attachment1 = bottom
		line.Width0 = markers.lineWidth
		line.Width1 = markers.lineWidth
		line.FaceCamera = true
		line.Segments = 1
		line.Enabled = false
		line.Parent = ground
		ground.Parent = deps.World or workspace
		self.ground = ground
		self.line = line
		self._top = top
	end,

	start = function(_self: WorldMarkers) end,

	step = function(self: WorldMarkers, _dt: number)
		local match = self._store.state.match
		local team: Team? = if match ~= nil then match.possessingTeam else nil
		local ball = self._ballPart:get()
		paint(self, Style.teamColor(self._config, team))
		wear(self, self._ballPart:look(), team)
		placeBall(self, ball)
	end,
}

return WorldMarkers
