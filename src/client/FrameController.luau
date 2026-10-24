--!strict
-- The client's frame, in one fixed order. Each physics step: the skating, then the actions, which read the skater as
-- the skating just left it, then the poses, which read both. Before each frame is drawn: the camera, which shows the
-- skater where physics left them, then the touch controls, which show what each button does now, then the HUD's
-- state, whose clocks count on, then the HUD, which shows it, then the world's markers and the arena's glow, which
-- read that state too. Roblox gives RunService handlers no documented order (they ran in reverse of their connection
-- order when measured), so only this module connects them, one per phase.

local RunService = game:GetService("RunService")

-- Anything stepped once per physics step.
type Steppable = { step: (self: any, dt: number) -> () }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type FrameController = {
	name: string,
	dependencies: { string },
	init: (self: FrameController, deps: { [string]: any }) -> (),
	start: (self: FrameController) -> (),
	step: (self: FrameController, dt: number) -> (),
	render: (self: FrameController, dt: number) -> (),
	_skate: Steppable,
	_actions: Steppable,
	_poses: Steppable,
	_camera: Steppable,
	_touch: Steppable,
	_hudStore: Steppable,
	_hud: Steppable,
	_worldMarkers: Steppable,
	_arenaGlow: Steppable,
}

local FrameController: FrameController = {
	name = "FrameController",
	dependencies = {
		"SkateController",
		"ActionController",
		"PoseController",
		"CameraController",
		"TouchControls",
		"HudStore",
		"Hud",
		"WorldMarkers",
		"ArenaGlow",
	},
	_skate = nil :: any,
	_actions = nil :: any,
	_poses = nil :: any,
	_camera = nil :: any,
	_touch = nil :: any,
	_hudStore = nil :: any,
	_hud = nil :: any,
	_worldMarkers = nil :: any,
	_arenaGlow = nil :: any,

	init = function(self: FrameController, deps: { [string]: any })
		self._skate = deps.SkateController
		self._actions = deps.ActionController
		self._poses = deps.PoseController
		self._camera = deps.CameraController
		self._touch = deps.TouchControls
		self._hudStore = deps.HudStore
		self._hud = deps.Hud
		self._worldMarkers = deps.WorldMarkers
		self._arenaGlow = deps.ArenaGlow
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
	end,

	render = function(self: FrameController, dt: number)
		self._camera:step(dt)
		self._touch:step(dt)
		self._hudStore:step(dt)
		self._hud:step(dt)
		self._worldMarkers:step(dt)
		self._arenaGlow:step(dt)
	end,
}

return FrameController
