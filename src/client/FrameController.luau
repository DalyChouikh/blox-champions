--!strict
-- The client's frame, in one fixed order. Each physics step: the skating, then the actions, which read the skater as
-- the skating just left it, then the poses, which read both, then a caught ball's pull into the hand (BallPull), so
-- the spot it writes is the one drawn and read before the frame. Before each frame is drawn: whether Roblox's
-- Developer Console is open (InputController, which pauses the controls), then the camera, which shows the skater where
-- physics left them, then the touch controls, which show what each button does now, then the HUD's state, whose clocks
-- count on, then the HUD, which shows it, then the world's markers, the arena's glow and the carrier's beam, which read
-- that state too, then the name tags. Roblox gives RunService handlers no documented order (they ran in reverse of
-- their connection order when measured), so only this module connects them, one per phase.

local RunService = game:GetService("RunService")

-- Anything stepped once per physics step.
type Steppable = { step: (self: any, dt: number) -> () }
-- What reads Roblox's overlays once a frame.
type OverlayWatcher = { watchOverlays: (self: any) -> () }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type FrameController = {
	name: string,
	dependencies: { string },
	init: (self: FrameController, deps: { [string]: any }) -> (),
	start: (self: FrameController) -> (),
	step: (self: FrameController, dt: number) -> (),
	render: (self: FrameController, dt: number) -> (),
	_input: OverlayWatcher,
	_skate: Steppable,
	_actions: Steppable,
	_poses: Steppable,
	_ballPull: Steppable,
	_camera: Steppable,
	_touch: Steppable,
	_hudStore: Steppable,
	_hud: Steppable,
	_worldMarkers: Steppable,
	_arenaGlow: Steppable,
	_carrierBeam: Steppable,
	_nameTags: Steppable,
}

local FrameController: FrameController = {
	name = "FrameController",
	dependencies = {
		"InputController",
		"SkateController",
		"ActionController",
		"PoseController",
		"BallPull",
		"CameraController",
		"TouchControls",
		"HudStore",
		"Hud",
		"WorldMarkers",
		"ArenaGlow",
		"CarrierBeam",
		"NameTags",
	},
	_input = nil :: any,
	_skate = nil :: any,
	_actions = nil :: any,
	_poses = nil :: any,
	_ballPull = nil :: any,
	_camera = nil :: any,
	_touch = nil :: any,
	_hudStore = nil :: any,
	_hud = nil :: any,
	_worldMarkers = nil :: any,
	_arenaGlow = nil :: any,
	_carrierBeam = nil :: any,
	_nameTags = nil :: any,

	init = function(self: FrameController, deps: { [string]: any })
		self._input = deps.InputController
		self._skate = deps.SkateController
		self._actions = deps.ActionController
		self._poses = deps.PoseController
		self._ballPull = deps.BallPull
		self._camera = deps.CameraController
		self._touch = deps.TouchControls
		self._hudStore = deps.HudStore
		self._hud = deps.Hud
		self._worldMarkers = deps.WorldMarkers
		self._arenaGlow = deps.ArenaGlow
		self._carrierBeam = deps.CarrierBeam
		self._nameTags = deps.NameTags
	end,

	start = function(self: FrameController)
		RunService.PreSimulation:Connect(function(dt: number)
			self:step(dt)
		end)
		RunService.PreRender:Connect(function(dt: number)
			self:render(dt)
		end)
	end,

	step = function(self: FrameController, dt: number)
		self._skate:step(dt)
		self._actions:step(dt)
		self._poses:step(dt)
		self._ballPull:step(dt)
	end,

	render = function(self: FrameController, dt: number)
		self._input:watchOverlays()
		self._camera:step(dt)
		self._touch:step(dt)
		self._hudStore:step(dt)
		self._hud:step(dt)
		self._worldMarkers:step(dt)
		self._arenaGlow:step(dt)
		self._carrierBeam:step(dt)
		self._nameTags:step(dt)
	end,
}

return FrameController
