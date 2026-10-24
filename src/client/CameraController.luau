--!strict
-- The camera (spec §8.4), rendered before each frame is drawn (FrameController). It takes Roblox's camera over
-- (Scriptable turns Roblox's own camera off) and sits `distance` behind and `height` above the skater along its own up,
-- which rolls with the surface the skater rides (ChaseCamera). The look input turns it; on a gamepad or touch it swings
-- back behind the skater once the look rests; its view widens with speed. Two rays through the ride surfaces keep it
-- inside the arena: the point it looks past stops below a roof, and the camera stops in front of a wall, so it never
-- sees through either, however close that brings it (the owner's choice). With a mouse it keeps the mouse locked to the
-- screen's center, except while the controls are paused (Roblox's menu or Developer Console is open). At a kickoff, and
-- for a new character, it starts behind the skater's facing, at its resting view. Ball Focus (§8.2) turns it toward the
-- ball while the player doesn't carry it: held on PC and gamepad, toggled by a tap on touch (Config.Input). A player
-- with no character (or whose character is gone before the next is bound) watches the ball, from the spectator's
-- distance and height above it; with no ball either, the camera holds still.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BallCarrier = require(script.Parent.BallCarrier)
local BallPart = require(script.Parent.BallPart)
local ChaseCamera = require(ReplicatedStorage.Shared.Camera.ChaseCamera)
local Config = require(ReplicatedStorage.Shared.Config)
local InputController = require(script.Parent.InputController)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local RideSurfaces = require(script.Parent.RideSurfaces)
local SkateController = require(script.Parent.SkateController)
local SkateMath = require(ReplicatedStorage.Shared.Skate.SkateMath)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type PlayerId = Types.PlayerId

-- What the controller sets on the camera and the mouse: workspace.CurrentCamera and UserInputService, or fakes.
type CameraLike = { CFrame: CFrame, FieldOfView: number, CameraType: Enum.CameraType }
type MouseLike = { MouseBehavior: Enum.MouseBehavior, MouseIconEnabled: boolean }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type CameraController = {
	name: string,
	dependencies: { string },
	init: (self: CameraController, deps: { [string]: any }) -> (),
	start: ((self: CameraController) -> ())?,
	step: (self: CameraController, dt: number) -> (),
	chase: ChaseCamera.ChaseCamera,
	-- Whether Ball Focus is on, as the last step applied it (the touch throw button rings while it is).
	focusing: boolean,
	_config: Config.GameConfig,
	_input: InputController.InputController,
	_surfaces: RideSurfaces.RideSurfaces,
	_skate: SkateController.SkateController,
	_carrier: BallCarrier.BallCarrier,
	_camera: CameraLike,
	_mouse: MouseLike,
	_preferredInput: () -> Enum.PreferredInput,
	_raycast: (origin: Vector3, direction: Vector3, params: RaycastParams) -> RaycastResult?,
	_ballPart: BallPart.BallPart,
	_localId: PlayerId,
	-- Records reused every step.
	_keys: InputController.CameraKeys,
	_target: ChaseCamera.Target,
	-- The root the camera last followed: a new one starts behind its skater.
	_root: BasePart?,
	-- Ball Focus turned on by a tap (toggle mode).
	_focusToggled: boolean,
}

-- The mouse stays at the screen's center while a mouse plays, so it turns the camera; it is free otherwise and
-- while the controls are paused: Roblox's menu or Developer Console is open (InputController). The cursor hides while
-- it is locked (the HUD's reticle marks the center).
local function lockMouse(self: CameraController, usingMouse: boolean)
	local locked = usingMouse and not self._input.paused
	local behavior = if locked then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	local mouse = self._mouse
	if mouse.MouseBehavior ~= behavior then
		mouse.MouseBehavior = behavior
	end
	if mouse.MouseIconEnabled == locked then
		mouse.MouseIconEnabled = not locked
	end
end

-- Whether Ball Focus is on this step. Hold mode follows the key; toggle mode flips on each press. Carrying the ball
-- switches it off.
local function focusing(self: CameraController, device: Enum.PreferredInput): boolean
	if self._carrier.carrier == self._localId then
		self._focusToggled = false
		return false
	end
	local input = self._config.Input
	local mode: Config.FocusMode = if device == Enum.PreferredInput.Touch
		then input.touchBallFocusMode
		else input.ballFocusMode
	local keys = self._keys
	if mode == "Hold" then
		self._focusToggled = false
		return keys.ballFocus
	end
	if keys.ballFocusPressed then
		self._focusToggled = not self._focusToggled
	end
	return self._focusToggled
end

-- Steps the chase toward `up` with this frame's look input, turning toward `aimAt` or swinging back behind `travel`.
local function follow(
	self: CameraController,
	up: Vector3,
	travel: Vector3,
	speed: number,
	aimAt: Vector3?,
	recenter: boolean,
	dt: number
)
	local target = self._target
	target.up = up
	target.travel = travel
	target.look = self._keys.look
	target.recenter = recenter
	target.aimAt = aimAt
	target.speed = speed
	self.chase:step(target, dt)
end

-- How far along a ray from `origin` the camera may go before a ride surface: `desired`, or pulled in front of a hit.
local function reach(self: CameraController, origin: Vector3, direction: Vector3, desired: number): number
	local hit = self._raycast(origin, direction * desired, self._surfaces.params)
	return ChaseCamera.pullIn(self._config.Camera, desired, if hit ~= nil then hit.Distance else nil)
end

-- Sets the camera `distance` behind the point `height` above `anchor`. Two rays keep both inside the arena: the
-- point stops in front of any ride surface above the anchor (a roof over a leaping skater), and the camera in front
-- of any behind the point.
local function place(self: CameraController, anchor: Vector3, height: number, distance: number)
	local chase = self.chase
	local up = chase.up
	local focus = anchor + up * reach(self, anchor, up, height)
	local look = chase:lookVector()
	local camera = self._camera
	camera.CFrame = CFrame.lookAlong(focus - look * reach(self, focus, -look, distance), look, up)
	camera.FieldOfView = chase.fov
end

local CameraController: CameraController = {
	name = "CameraController",
	dependencies = { "Config", "InputController", "RideSurfaces", "SkateController", "BallCarrier", "BallPart" },
	chase = nil :: any,
	focusing = false,
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
	_raycast = function(_origin: Vector3, _direction: Vector3, _params: RaycastParams): RaycastResult?
		return nil
	end,
	_ballPart = nil :: any,
	_localId = "",
	_keys = nil :: any,
	_target = nil :: any,
	_root = nil,
	_focusToggled = false,

	-- deps.Camera, deps.Mouse, deps.PreferredInput, deps.Raycast and deps.LocalId replace the live game in tests.
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
		self._raycast = deps.Raycast
			or function(origin: Vector3, direction: Vector3, params: RaycastParams): RaycastResult?
				return workspace:Raycast(origin, direction, params)
			end
		self._ballPart = deps.BallPart
		self._localId = deps.LocalId or PlayerIds.of(Players.LocalPlayer :: Player)
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
		self._focusToggled = false
		self.focusing = false
	end,

	step = function(self: CameraController, dt: number)
		local camera = self._camera
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		local device = self._preferredInput()
		local usingMouse = device == Enum.PreferredInput.KeyboardAndMouse
		lockMouse(self, usingMouse)
		self._input:readCamera(self._keys)
		local focused = focusing(self, device)
		self.focusing = focused
		local ball = self._ballPart:get()
		local settings = self._config.Camera

		local skate = self._skate
		if not skate:hasSkater() then
			-- A spectator, or a player whose character is gone before the next is bound, watches the ball, upright;
			-- with no ball either, the camera holds still.
			self._root = nil
			if ball ~= nil then
				follow(self, Vector3.yAxis, ball.AssemblyLinearVelocity, 0, nil, not usingMouse, dt)
				place(self, ball.Position, settings.spectator.height, settings.spectator.distance)
			end
			return
		end
		local skater, root = skate.skater :: SkateMath.Skater, skate.root :: BasePart
		local chase = self.chase
		if root ~= self._root or skate.frozen then
			self._root = root
			chase:reset(skater.up, skater.forward)
		end
		if not skate.frozen then
			local aimAt = if focused and ball ~= nil
				then ball.Position - (root.Position + chase.up * settings.height)
				else nil
			follow(self, skater.up, skater.velocity, skater.velocity.Magnitude, aimAt, not usingMouse, dt)
		end
		place(self, root.Position, settings.height, settings.distance)
	end,
}

return CameraController
