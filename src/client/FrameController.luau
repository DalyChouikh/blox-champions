--!strict
-- The client's frame, in one fixed order. Each physics step: the skating, then the actions, which read the skater as
-- the skating just left it, then the poses, which read both. Before each frame is drawn: whether Roblox's Developer
-- Console is open (InputController, which pauses the controls), then where the ball is drawn (BallView: the loose ball
-- from the server's state, a catch's pull into the hand), so everything after reads the spot drawn, then the camera,
-- which shows the skater where physics left them, then the touch controls, which show what each button does now, then
-- the HUD's state, whose clocks count on, then the HUD, which shows it, then the world's markers, the arena's glow, the
-- goal's worth and the fire lines, which read that state too, then the ball's trail, then the name tags. Roblox gives
-- RunService handlers no documented order (they ran in reverse of their connection order when measured), so only this
-- module connects them, one per phase. Each module's step is guarded (#392, the owner's Q263): an error in one (a HUD
-- binding's update, say) no longer skips the steps after it that frame; the first is reported, naming the module and
-- where it was thrown, never every frame, and the module is still stepped each frame, so one that recovers goes on.

local RunService = game:GetService("RunService")

-- How a phase steps one module: its step(dt), or the watch of Roblox's overlays.
type Stepper = (module: any, dt: number) -> ()
-- One module of a phase, made once: the module, how it is stepped, and xpcall's handler for its step, which runs only
-- when the step throws.
type Step = { module: any, step: Stepper, failed: (problem: any) -> () }

-- Each phase's modules by dependency name, in their order: the overlays first in each frame, then the drawn modules.
local OVERLAYS = "InputController"
local PHYSICS: { string } = { "SkateController", "ActionController", "PoseController" }
local DRAWN: { string } = {
	"BallView",
	"CameraController",
	"TouchControls",
	"HudStore",
	"Hud",
	"WorldMarkers",
	"ArenaGlow",
	"GoalWorth",
	"FireLines",
	"BallTrail",
	"NameTags",
}

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type FrameController = {
	name: string,
	dependencies: { string },
	init: (self: FrameController, deps: { [string]: any }) -> (),
	start: (self: FrameController) -> (),
	step: (self: FrameController, dt: number) -> (),
	render: (self: FrameController, dt: number) -> (),
	_physics: { Step },
	_frame: { Step },
	-- Where a failed step is reported: the Output, or a fake in tests.
	_log: (line: string) -> (),
}

local function joined(...: { string }): { string }
	local all: { string } = {}
	for _, names in { ... } do
		table.move(names, 1, #names, #all + 1, all)
	end
	return all
end

local function logLine(line: string)
	warn(line)
end

local function watchOverlays(input: any, _dt: number)
	input:watchOverlays()
end

-- This module's name as the stack's lines give it.
local SOURCE: string = debug.info(1, "s") :: any

-- The report of a module's failed step: its name, the error, and where it was thrown: the stack's first line outside
-- this module (a fixed depth would shift with the compiler's inlining and the stack's unnamed engine frames).
local function failure(name: string, problem: any): string
	local at = "?"
	for line in string.gmatch(debug.traceback(), "[^\n]+") do
		if string.sub(line, 1, #SOURCE) ~= SOURCE then
			at = line
			break
		end
	end
	return `[BloxChampions] FrameController: {name}'s step failed: {tostring(problem)} ({at})`
end

-- A phase's steps, made once, so a frame makes no table or closure.
local function phase(self: FrameController, deps: { [string]: any }, names: { string }): { Step }
	local steps: { Step } = table.create(#names)
	for _, name in names do
		local module = deps[name]
		local reported = false
		table.insert(steps, {
			module = module,
			step = if name == OVERLAYS then watchOverlays else module.step,
			failed = function(problem: any)
				if not reported then
					reported = true
					self._log(failure(name, problem))
				end
			end,
		})
	end
	return steps
end

local function run(steps: { Step }, dt: number)
	for _, entry in steps do
		xpcall(entry.step, entry.failed, entry.module, dt)
	end
end

local FrameController: FrameController = {
	name = "FrameController",
	dependencies = joined({ OVERLAYS }, PHYSICS, DRAWN),
	_physics = {},
	_frame = {},
	_log = logLine,

	-- deps.Log replaces the Output in tests.
	init = function(self: FrameController, deps: { [string]: any })
		self._log = deps.Log or logLine
		self._physics = phase(self, deps, PHYSICS)
		self._frame = phase(self, deps, joined({ OVERLAYS }, DRAWN))
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
		run(self._physics, dt)
	end,

	render = function(self: FrameController, dt: number)
		run(self._frame, dt)
	end,
}

return FrameController
