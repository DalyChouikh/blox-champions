--!strict
-- The local player's physics step, in one fixed order: the skating, then the actions, which read the skater as the
-- skating just left it, then the poses, which read both. Roblox gives RunService handlers no documented order (they
-- ran in reverse of their connection order when measured), so this one handler steps all three.

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
	_skate: Steppable,
	_actions: Steppable,
	_poses: Steppable,
}

local FrameController: FrameController = {
	name = "FrameController",
	dependencies = { "SkateController", "ActionController", "PoseController" },
	_skate = nil :: any,
	_actions = nil :: any,
	_poses = nil :: any,

	init = function(self: FrameController, deps: { [string]: any })
		self._skate = deps.SkateController
		self._actions = deps.ActionController
		self._poses = deps.PoseController
	end,

	start = function(self: FrameController)
		RunService.PreSimulation:Connect(function(dt: number)
			self:step(dt)
		end)
	end,

	step = function(self: FrameController, dt: number)
		self._skate:step(dt)
		self._actions:step(dt)
		self._poses:step(dt)
	end,
}

return FrameController
