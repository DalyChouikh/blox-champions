--!strict
-- The carrier's beam (Arena spec §5.4): a tall thin glowing strip on the outer glass's face, from the solid wall's top
-- up to where the lip starts, beside the ball while someone carries it, in the colour of the team with the ball. It
-- hides while the ball is loose (from the moment the local player throws it), while there is no ball, and until the
-- HUD knows whose ball it is. Each client draws its own: the part stays on this client, and nothing hits, sees or
-- touches it. Stepped before each frame is drawn (FrameController), after the arena's glow: a step moves the part by
-- its Position and Orientation, writes Color and Transparency only when they change, and allocates nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallCarrier = require(script.Parent.BallCarrier)
local BallPart = require(script.Parent.BallPart)
local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local HudStore = require(script.Parent.HudStore)
local Profile = require(ReplicatedStorage.Shared.Arena.Geometry.Profile)

-- The beam shows fully, or not at all.
local SHOWN, HIDDEN = 0, 1

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type CarrierBeam = {
	name: string,
	dependencies: { string },
	init: (self: CarrierBeam, deps: { [string]: any }) -> (),
	start: (self: CarrierBeam) -> (),
	step: (self: CarrierBeam, dt: number) -> (),
	-- Removes the part start built (tests).
	destroy: (self: CarrierBeam) -> (),
	-- The beam, built at start.
	part: BasePart,
	_config: Config.GameConfig,
	_carrier: BallCarrier.BallCarrier,
	_ballPart: BallPart.BallPart,
	_store: HudStore.HudStore,
	_parent: Instance,
	-- Where the beam's centre stands: across the track from the inner glass's face, and above the lowest floor.
	_lateral: number,
	_height: number,
	-- What was last written.
	_color: Color3?,
	_transparency: number,
}

local function show(self: CarrierBeam, transparency: number)
	if transparency ~= self._transparency then
		self._transparency = transparency
		self.part.Transparency = transparency
	end
end

local CarrierBeam: CarrierBeam = {
	name = "CarrierBeam",
	dependencies = { "Config", "BallCarrier", "BallPart", "HudStore" },
	part = nil :: any,
	_config = nil :: any,
	_carrier = nil :: any,
	_ballPart = nil :: any,
	_store = nil :: any,
	_parent = nil :: any,
	_lateral = 0,
	_height = 0,
	_color = nil,
	_transparency = HIDDEN,

	-- deps.Parent replaces the workspace in tests.
	init = function(self: CarrierBeam, deps: { [string]: any })
		self._config = deps.Config
		self._carrier = deps.BallCarrier
		self._ballPart = deps.BallPart
		self._store = deps.HudStore
		self._parent = deps.Parent or workspace
		self._color = nil
		self._transparency = HIDDEN
	end,

	start = function(self: CarrierBeam)
		local arena, glow = self._config.Arena, self._config.UI.arenaGlow
		-- The vertical outer glass, which the beam covers, its back on the glass's face.
		local bottom, top = arena.outerWallHeight, Profile.lipStart(arena)
		self._lateral = arena.trackWidth - glow.beam.thickness / 2
		self._height = (bottom + top) / 2
		local part = Instance.new("Part")
		part.Name = "CarrierBeam"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = glow.material
		-- Across the track, up the glass, along the track.
		part.Size = Vector3.new(glow.beam.thickness, top - bottom, glow.beam.width)
		part.Transparency = HIDDEN
		part.Parent = self._parent
		self.part = part
	end,

	step = function(self: CarrierBeam, _dt: number)
		local ball = self._ballPart:get()
		local match = self._store.state.match
		local team = if match ~= nil then match.possessingTeam else nil
		if self._carrier.carrier == nil or ball == nil or team == nil then
			show(self, HIDDEN)
			return
		end
		local arena = self._config.Arena
		local position, yaw =
			Centerline.pose(arena, Centerline.distanceOf(arena, ball.Position), self._lateral, self._height)
		local part = self.part
		part.Position = position
		part.Orientation = Vector3.new(0, math.deg(yaw), 0)
		local color = self._config.UI.teamColors[team]
		if color ~= self._color then
			self._color = color
			part.Color = color
		end
		show(self, SHOWN)
	end,

	destroy = function(self: CarrierBeam)
		self.part:Destroy()
	end,
}

return CarrierBeam
