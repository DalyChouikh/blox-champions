--!strict
-- The thrower's predicted arc (spec §9.4, #313; the owner, Q98). While a throw charges, on this screen only, dots along
-- the path the ball would fly if it were let go now (ActionController:throwVelocity: what the server will make of the
-- release) from where this screen draws it in the hand, under the world's gravity: a dot every
-- UI.trajectory.arc.spacing studs of the launch speed (Trajectory.path), ending where the ball would first touch the
-- arena (a sphere of the ball's size cast along each chord through RideSurfaces.solid: skaters and the goal's ring are
-- never in the way), in a ring there. From the chase camera a throw flies almost straight away, so the path shows as a
-- thin line up through the thrower's own skater: every dot and the ring are drawn over everything at a fixed size on
-- screen (the owner, Q145), each a BillboardGui at an attachment of one invisible part. All of it is made once at
-- start and stays on this client; nothing hits, sees or touches it. Stepped before each frame is drawn
-- (FrameController), after the camera, whose view the aim goes through: a step moves the attachments by their
-- WorldPosition and switches only the markers whose state changed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallPart = require(script.Parent.BallPart)
local Config = require(ReplicatedStorage.Shared.Config)
local Trajectory = require(ReplicatedStorage.Shared.Ball.Trajectory)

-- What the arc reads of the actions and of the arena (fakes in tests).
type Actions = { throwVelocity: (self: any) -> Vector3? }
type Surfaces = { solid: RaycastParams }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type ThrowArc = {
	name: string,
	dependencies: { string },
	init: (self: ThrowArc, deps: { [string]: any }) -> (),
	start: (self: ThrowArc) -> (),
	step: (self: ThrowArc, dt: number) -> (),
	-- Removes what start made (tests).
	destroy: (self: ThrowArc) -> (),
	-- The invisible part whose attachments the markers stand at, made at start.
	anchor: BasePart,
	-- The dots (UI.trajectory.arc.maxDots of them) and the ring where the ball would first touch, made at start.
	dots: { BillboardGui },
	ring: BillboardGui,
	-- How many dots show now, from the first.
	shown: number,
	_config: Config.GameConfig,
	_actions: Actions,
	_ballPart: BallPart.BallPart,
	_surfaces: Surfaces,
	_parent: Instance,
	_gravity: Vector3,
	-- Where each dot and the ring stand.
	_spots: { Attachment },
	_ringSpot: Attachment,
	-- The path's points, reused every step.
	_points: { Vector3 },
	-- Trajectory.path's check of each chord against the arena, made once.
	_cast: Trajectory.Cast,
}

-- A marker drawn over everything, `size` pixels across, at a new attachment of `anchor`; hidden.
local function marker(anchor: BasePart, name: string, size: number): (BillboardGui, Attachment)
	local spot = Instance.new("Attachment")
	spot.Name = name
	spot.Parent = anchor
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = spot
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(size, size)
	gui.Enabled = false
	gui.Parent = spot
	return gui, spot
end

-- A round face filling `parent`, outlined `thickness` pixels wide in `color`, on no background; and its outline.
local function face(parent: Instance, name: string, color: Color3, thickness: number): (Frame, UIStroke)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = frame
	frame.Parent = parent
	return frame, stroke
end

-- Shows the first `count` dots and hides the rest, switching only the dots whose state changes.
local function show(self: ThrowArc, count: number)
	local shown, dots = self.shown, self.dots
	for i = count + 1, shown do
		dots[i].Enabled = false
	end
	for i = shown + 1, count do
		dots[i].Enabled = true
	end
	self.shown = count
end

local ThrowArc: ThrowArc = {
	name = "ThrowArc",
	dependencies = { "Config", "ActionController", "BallPart", "RideSurfaces" },
	anchor = nil :: any,
	dots = {},
	ring = nil :: any,
	shown = 0,
	_config = nil :: any,
	_actions = nil :: any,
	_ballPart = nil :: any,
	_surfaces = nil :: any,
	_parent = nil :: any,
	_gravity = Vector3.zero,
	_spots = {},
	_ringSpot = nil :: any,
	_points = {},
	_cast = function(_from: Vector3, _to: Vector3): Vector3?
		return nil
	end,

	-- deps.Parent (where the anchor goes) replaces the workspace in tests.
	init = function(self: ThrowArc, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._config = config
		self._actions = deps.ActionController
		self._ballPart = deps.BallPart
		self._surfaces = deps.RideSurfaces
		self._parent = deps.Parent or workspace
		self._gravity = Config.gravity(config)
		self._points = {}
		local radius = config.Ball.radius
		-- Where the ball's centre stops: as far along the chord as a sphere its size travels before it touches.
		self._cast = function(from: Vector3, to: Vector3): Vector3?
			local direction = to - from
			local hit = workspace:Spherecast(from, radius, direction, self._surfaces.solid)
			return if hit ~= nil then from + direction.Unit * hit.Distance else nil
		end
	end,

	start = function(self: ThrowArc)
		local arc = self._config.UI.trajectory.arc
		local anchor = Instance.new("Part")
		anchor.Name = "ThrowArc"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Transparency = 1
		self.dots, self._spots, self.shown = {}, {}, 0
		for i = 1, arc.maxDots do
			local dot, spot = marker(anchor, "Dot", arc.dotSize)
			local disc = face(dot, "Dot", arc.edgeColor, arc.edgeThickness)
			disc.BackgroundColor3 = arc.color
			disc.BackgroundTransparency = arc.transparency
			self.dots[i], self._spots[i] = dot, spot
		end
		-- The ring in the arc's colour inside a dark edge: the edge's outline starts edgeThickness inside the
		-- ring's and runs edgeThickness past it, and the ring's is drawn over it.
		local ring, spot = marker(anchor, "Ring", arc.ringSize)
		local edge = face(ring, "Edge", arc.edgeColor, arc.ringThickness + 2 * arc.edgeThickness)
		edge.Size = UDim2.new(1, -2 * arc.edgeThickness, 1, -2 * arc.edgeThickness)
		edge.Position = UDim2.fromOffset(arc.edgeThickness, arc.edgeThickness)
		local band, outline = face(ring, "Ring", arc.color, arc.ringThickness)
		band.ZIndex = 2
		outline.Transparency = arc.transparency
		self.ring, self._ringSpot = ring, spot
		anchor.Parent = self._parent
		self.anchor = anchor
	end,

	step = function(self: ThrowArc, _dt: number)
		local velocity = self._actions:throwVelocity()
		local ball = self._ballPart:get()
		local count, touched = 0, false
		if velocity ~= nil and ball ~= nil then
			local arc = self._config.UI.trajectory.arc
			local points, spots = self._points, self._spots
			count, touched =
				Trajectory.path(ball.Position, velocity, self._gravity, arc.spacing, arc.maxDots, self._cast, points)
			for i = 1, count do
				spots[i].WorldPosition = points[i]
			end
			if touched then
				self._ringSpot.WorldPosition = points[count]
			end
		end
		show(self, count)
		local ring = self.ring
		if ring.Enabled ~= touched then
			ring.Enabled = touched
		end
	end,

	destroy = function(self: ThrowArc)
		self.anchor:Destroy()
		self.dots, self._spots, self.shown = {}, {}, 0
	end,
}

return ThrowArc
