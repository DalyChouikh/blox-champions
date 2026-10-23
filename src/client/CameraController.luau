--!strict
-- The camera (spec §8.4), rendered before each frame is drawn (FrameController). It takes Roblox's camera over
-- (Scriptable turns Roblox's own camera off) and sits `distance` behind and `height` above the skater along its own
-- up, which rolls with the surface the skater rides (ChaseCamera). The look input turns it; on a gamepad or touch it
-- swings back behind the skater once the look rests; its view widens with speed. One ray through the ride surfaces
-- pulls it in in front of the arena, so it never sees through a wall or the roof. With a mouse it keeps the mouse
-- locked to the screen's center, except while Roblox's menu is open. At a kickoff, and for a new character, it starts
-- behind the skater's facing.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BallCarrier = require(script.Parent.BallCarrier)
local ChaseCamera = require(ReplicatedStorage.Shared.Camera.ChaseCamera)
local Config = require(ReplicatedStorage.Shared.Config)
local InputController = require(script.Parent.InputController)
local RideSurfaces = require(script.Parent.RideSurfaces)
local SkateController = require(script.Parent.SkateController)

-- What the controller sets on the camera and the mouse: workspace.CurrentCamera and UserInputService, or fakes.
type CameraLike = { CFrame: CFrame, FieldOfView: number, CameraType: Enum.CameraType }
type MouseLike = { MouseBehavior: Enum.MouseBehavior }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type CameraController = {
	name: string,
	dependencies: { string },
	init: (self: CameraController, deps: { [string]: any }) -> (),
	start: ((self: CameraController) -> ())?,
	step: (self: CameraController, dt: number) -> (),
	chase: ChaseCamera.ChaseCamera,
	_config: Config.GameConfig,
	_input: InputController.InputController,
	_surfaces: RideSurfaces.RideSurfaces,
	_skate: SkateController.SkateController,
	_carrier: BallCarrier.BallCarrier,
	_camera: CameraLike,
	_mouse: MouseLike,
	_preferredInput: () -> Enum.PreferredInput,
	_menuOpen: () -> boolean,
	_raycast: (origin: Vector3, direction: Vector3, params: RaycastParams) -> RaycastResult?,
	-- Records reused every step.
	_keys: InputController.CameraKeys,
	_target: ChaseCamera.Target,
	-- The root the camera last followed: a new one starts behind its skater.
	_root: BasePart?,
}

-- The mouse stays at the screen's center while a mouse plays, so it turns the camera; it is free otherwise and
-- while Roblox's menu is open.
local function lockMouse(self: CameraController, usingMouse: boolean)
	local behavior = if usingMouse and not self._menuOpen()
		then Enum.MouseBehavior.LockCenter
		else Enum.MouseBehavior.Default
	if self._mouse.MouseBehavior ~= behavior then
		self._mouse.MouseBehavior = behavior
	end
end

-- Sets the camera `distance` behind the point `height` above `anchor`, pulled in in front of any ride surface.
local function place(self: CameraController, anchor: Vector3, distance: number)
	local settings = self._config.Camera
	local chase = self.chase
	local focus = anchor + chase.up * settings.height
	local look = chase:lookVector()
	local hit = self._raycast(focus, -look * distance, self._surfaces.params)
	local back = ChaseCamera.pullIn(settings, distance, if hit ~= nil then hit.Distance else nil)
	local camera = self._camera
	camera.CFrame = CFrame.lookAlong(focus - look * back, look, chase.up)
	camera.FieldOfView = chase.fov
end

local CameraController: CameraController = {
	name = "CameraController",
	dependencies = { "Config", "InputController", "RideSurfaces", "SkateController", "BallCarrier" },
	chase = nil :: any,
	_config = nil :: any,
	_input = nil :: any,
	_surfaces = nil :: any,
	_skate = nil :: any,
	_carrier = nil :: any,
	_camera = nil :: any,
	_mouse = nil :: any,
	_preferredInput = function(): Enum.PreferredInput
		return Enum.PreferredInput.KeyboardAndMouse
	end,
	_menuOpen = function(): boolean
		return false
	end,
	_raycast = function(_origin: Vector3, _direction: Vector3, _params: RaycastParams): RaycastResult?
		return nil
	end,
	_keys = nil :: any,
	_target = nil :: any,
	_root = nil,

	-- deps.Camera, deps.Mouse, deps.PreferredInput, deps.MenuOpen and deps.Raycast replace the live game in tests.
	init = function(self: CameraController, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._config = config
		self._input = deps.InputController
		self._surfaces = deps.RideSurfaces
		self._skate = deps.SkateController
		self._carrier = deps.BallCarrier
		self._camera = deps.Camera or workspace.CurrentCamera
		self._mouse = deps.Mouse or UserInputService
		self._preferredInput = deps.PreferredInput
			or function(): Enum.PreferredInput
				return UserInputService.PreferredInput
			end
		self._menuOpen = deps.MenuOpen or function(): boolean
			return GuiService.MenuIsOpen
		end
		self._raycast = deps.Raycast
			or function(origin: Vector3, direction: Vector3, params: RaycastParams): RaycastResult?
				return workspace:Raycast(origin, direction, params)
			end
		self.chase = ChaseCamera.new(config.Camera, config.Movement.hardCap, Vector3.yAxis, -Vector3.zAxis)
		self._keys = InputController.newCameraKeys()
		self._target = {
			up = Vector3.yAxis,
			travel = Vector3.zero,
			look = Vector2.zero,
			recenter = false,
			aimAt = nil,
			speed = 0,
		}
		self._root = nil
	end,

	step = function(self: CameraController, dt: number)
		local camera = self._camera
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		local usingMouse = self._preferredInput() == Enum.PreferredInput.KeyboardAndMouse
		lockMouse(self, usingMouse)
		local keys = self._keys
		self._input:readCamera(keys)

		local skate = self._skate
		local skater, root = skate.skater, skate.root
		if skater == nil or root == nil then
			self._root = nil
			return
		end
		local chase = self.chase
		if root ~= self._root or skate.frozen then
			self._root = root
			chase:reset(skater.up, skater.forward)
		end
		if not skate.frozen then
			local target = self._target
			target.up = skater.up
			target.travel = skater.velocity
			target.look = keys.look * dt
			target.recenter = not usingMouse
			target.speed = skater.velocity.Magnitude
			chase:step(target, dt)
		end
		place(self, root.Position, self._config.Camera.distance)
	end,
}

return CameraController
