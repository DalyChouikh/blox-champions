--!strict
-- The ball's and the next gate's markers (spec §9.4, §11.1), stepped before each frame is drawn (FrameController):
-- - a ring around the ball, seen through walls (a BillboardGui, AlwaysOnTop), as wide as the ball plus ringSize pixels;
-- - a line from the ball down to a disc on the ground below it (one ray through the ride surfaces), both hidden when
--   nothing lies within groundProbe studs;
-- - an arrow at the screen's edge pointing to the ball while it is off the screen (ScreenMarker);
-- - for the local player while they carry the ball, an arrow to their team's next gate: over its corner marker's pivot
--   (its glass wall's middle), or pinned to the screen's edge. None before their first gate (the owner's choice): the
--   snapshot's nextGate is nil.
-- All of them take the colour of the team with the ball, or the HUD's text colour while it is loose, and hide while
-- there is no ball. The arrows sit in a ScreenGui without insets, so their pixels are the camera's. A property is
-- written only when it changes; a step allocates only the disc's frame, the ray's result and a shown arrow's place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaParts = require(script.Parent.ArenaParts)
local BallCarrier = require(script.Parent.BallCarrier)
local BallPart = require(script.Parent.BallPart)
local Config = require(ReplicatedStorage.Shared.Config)
local HudStore = require(script.Parent.HudStore)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local RideSurfaces = require(script.Parent.RideSurfaces)
local ScreenMarker = require(ReplicatedStorage.Shared.Hud.ScreenMarker)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type PlayerId = Types.PlayerId

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
	ballArrow: Frame,
	gateArrow: Frame,
	_config: Config.GameConfig,
	_surfaces: RideSurfaces.RideSurfaces,
	_ballPart: BallPart.BallPart,
	_carrier: BallCarrier.BallCarrier,
	_store: HudStore.HudStore,
	_arena: ArenaParts.ArenaParts,
	_localId: PlayerId,
	-- Camera:WorldToViewportPoint, the camera's viewport size and workspace:Raycast, or fakes.
	_project: (position: Vector3) -> (Vector3, boolean),
	_viewportSize: () -> Vector2,
	_raycast: (origin: Vector3, direction: Vector3, params: RaycastParams) -> RaycastResult?,
	-- The camera's viewport size, kept by start() (no read each frame).
	_viewport: Vector2,
	_gui: ScreenGui,
	-- The line's ends: on the ball (moved to it each step) and on the disc.
	_top: Attachment,
	_strokes: { UIStroke },
	_images: { ImageLabel },
	-- What was last written.
	_color: Color3?,
	_hasBall: boolean,
	_grounded: boolean,
	_ballPlacement: ScreenMarker.Placement,
	_gatePlacement: ScreenMarker.Placement,
}

-- Down, for the ray from the ball to the ground.
local DOWN = -Vector3.yAxis

local function newArrow(name: string, config: Config.GameConfig, parent: Instance): (Frame, ImageLabel)
	local markers = config.UI.markers
	local arrow = Instance.new("Frame")
	arrow.Name = name
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(markers.arrowSize, markers.arrowSize)
	arrow.BackgroundTransparency = 1
	arrow.Visible = false
	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.Image = markers.arrowImage
	image.Parent = arrow
	arrow.Parent = parent
	return arrow, image
end

-- Shows `arrow` where `placement` puts it, or hides it.
local function showArrow(arrow: Frame, placement: ScreenMarker.Placement?)
	local visible = placement ~= nil
	if arrow.Visible ~= visible then
		arrow.Visible = visible
	end
	if placement ~= nil then
		arrow.Position = UDim2.fromOffset(placement.x, placement.y)
		local rotation = math.deg(placement.angle)
		if arrow.Rotation ~= rotation then
			arrow.Rotation = rotation
		end
	end
end

-- Every marker in `color`, written when it changes.
local function paint(self: WorldMarkers, color: Color3)
	if color == self._color then
		return
	end
	self._color = color
	for _, stroke in self._strokes do
		stroke.Color = color
	end
	for _, image in self._images do
		image.ImageColor3 = color
	end
	self.ground.Color = color
	self.line.Color = ColorSequence.new(color)
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
		showArrow(self.ballArrow, nil)
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
	local point, onScreen = self._project(position)
	if onScreen then
		showArrow(self.ballArrow, nil)
	else
		local placement = self._ballPlacement
		ScreenMarker.place(point, false, self._viewportSize(), markers.edgeMargin, placement)
		showArrow(self.ballArrow, placement)
	end
end

-- `nextGate`: the possessing team's next gate, nil before their first.
local function placeGate(self: WorldMarkers, nextGate: number?)
	local parts = self._arena.parts
	local gate = if nextGate ~= nil
			and parts ~= nil
			and self._carrier.carrier == self._localId
		then parts.markers[nextGate]
		else nil
	if gate == nil then
		showArrow(self.gateArrow, nil)
		return
	end
	local point, onScreen = self._project(gate.position)
	local placement = self._gatePlacement
	ScreenMarker.place(point, onScreen, self._viewportSize(), self._config.UI.markers.edgeMargin, placement)
	showArrow(self.gateArrow, placement)
end

local WorldMarkers: WorldMarkers = {
	name = "WorldMarkers",
	dependencies = { "Config", "RideSurfaces", "BallPart", "BallCarrier", "HudStore", "ArenaParts" },
	ring = nil :: any,
	ground = nil :: any,
	line = nil :: any,
	ballArrow = nil :: any,
	gateArrow = nil :: any,
	_config = nil :: any,
	_surfaces = nil :: any,
	_ballPart = nil :: any,
	_carrier = nil :: any,
	_store = nil :: any,
	_arena = nil :: any,
	_localId = "",
	_project = function(position: Vector3): (Vector3, boolean)
		return position, false
	end,
	_viewportSize = function(): Vector2
		return Vector2.zero
	end,
	_raycast = function(_origin: Vector3, _direction: Vector3, _params: RaycastParams): RaycastResult?
		return nil
	end,
	_viewport = Vector2.zero,
	_gui = nil :: any,
	_top = nil :: any,
	_strokes = {},
	_images = {},
	_color = nil,
	_hasBall = false,
	_grounded = false,
	_ballPlacement = ScreenMarker.newPlacement(),
	_gatePlacement = ScreenMarker.newPlacement(),

	-- deps.Parent keeps the guis out of the local player's PlayerGui in tests, and deps.World the disc out of the
	-- workspace; deps.Project, deps.ViewportSize, deps.Raycast and deps.LocalId replace the live game there.
	init = function(self: WorldMarkers, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		local markers = config.UI.markers
		self._config = config
		self._surfaces = deps.RideSurfaces
		self._ballPart = deps.BallPart
		self._carrier = deps.BallCarrier
		self._store = deps.HudStore
		self._arena = deps.ArenaParts
		self._localId = deps.LocalId or PlayerIds.of(Players.LocalPlayer :: Player)
		self._project = deps.Project
			or function(position: Vector3): (Vector3, boolean)
				return workspace.CurrentCamera:WorldToViewportPoint(position)
			end
		self._viewport = workspace.CurrentCamera.ViewportSize
		self._viewportSize = deps.ViewportSize or function(): Vector2
			return self._viewport
		end
		self._raycast = deps.Raycast
			or function(origin: Vector3, direction: Vector3, params: RaycastParams): RaycastResult?
				return workspace:Raycast(origin, direction, params)
			end
		self._color = nil
		self._hasBall = false
		self._grounded = false
		self._ballPlacement = ScreenMarker.newPlacement()
		self._gatePlacement = ScreenMarker.newPlacement()
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

		-- The disc touches nothing and no ray finds it.
		local ground = Instance.new("Part")
		ground.Name = "BallGround"
		ground.Shape = Enum.PartType.Cylinder
		ground.Size = Vector3.new(markers.groundMarkerThickness, markers.groundMarkerSize, markers.groundMarkerSize)
		ground.Anchored = true
		ground.CanCollide = false
		ground.CanQuery = false
		ground.CanTouch = false
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

		local gui = Instance.new("ScreenGui")
		gui.Name = "Markers"
		gui.ResetOnSpawn = false
		gui.ScreenInsets = Enum.ScreenInsets.None
		gui.Parent = parent
		self._gui = gui
		local ballArrow, ballImage = newArrow("BallArrow", config, gui)
		local gateArrow, gateImage = newArrow("GateArrow", config, gui)
		self.ballArrow = ballArrow
		self.gateArrow = gateArrow
		self._strokes = { stroke }
		self._images = { ballImage, gateImage }
	end,

	-- The viewport's size changes when the window is resized or the device turned.
	start = function(self: WorldMarkers)
		local camera = workspace.CurrentCamera
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self._viewport = camera.ViewportSize
		end)
	end,

	step = function(self: WorldMarkers, _dt: number)
		local match = self._store.state.match
		local team = if match ~= nil then match.possessingTeam else nil
		local ui = self._config.UI
		paint(self, if team ~= nil then ui.teamColors[team] else ui.hud.textColor)
		placeBall(self, self._ballPart:get())
		placeGate(self, if match ~= nil then match.nextGate else nil)
	end,
}

return WorldMarkers
