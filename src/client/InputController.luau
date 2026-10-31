--!strict
-- The controls (spec §8.3) on Roblox's Input Action System, built from Config.Input. One context sits above Roblox's
-- own character controls and sinks the keys it binds, so their defaults never fire on ours. SkateController reads the
-- skating keys once per physics step, ActionController the action keys, and CameraController the look and Ball Focus.
-- A press is counted when it happens, so one that starts and ends between two reads still counts; a hold is read as
-- it is now, and the look as the rate Roblox's own camera reads (turn = state × dt). Touch controls hook their stick
-- pad and buttons in here. Every key stops while Roblox's menu or its Developer Console is open (also when the menu is
-- open as this starts): the keys fire then too (measured), and a hold lets go. The menu has signals; the console has
-- none, so watchOverlays reads it once a frame. `paused` tells the skating and the actions that a hold let go because
-- of Roblox's menu or console, not the player, and the camera to free the cursor. The HUD reads the score tab's key as
-- held, and Switch team's as a press (#310).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)

-- One read of the keys: the move stick (x right, y forward) and the buttons. `jump` is a press since the last read,
-- `jumpHeld` the jump key held now (the Air Pose lasts while it is, #245).
export type SkateKeys = {
	move: Vector2,
	pump: boolean,
	brake: boolean,
	attach: boolean,
	jump: boolean,
	jumpHeld: boolean,
}
-- One read of the action keys: a press since the last read for each, and the throw held now.
export type ActionKeys = { tackle: boolean, uppercut: boolean, pass: boolean, throw: boolean }
-- One read of the camera keys: the look (radians per second), Ball Focus held now, and pressed since the last read.
export type CameraKeys = { look: Vector2, ballFocus: boolean, ballFocusPressed: boolean }

-- The pressed (not held) buttons, each counted on its own.
type Presses = { jump: number, tackle: number, uppercut: number, pass: number, ballFocus: number, switchTeam: number }
type Pressed = "jump" | "tackle" | "uppercut" | "pass" | "ballFocus" | "switchTeam"
type LookBindings = { mouse: InputBinding, stick: InputBinding, touch: InputBinding }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type InputController = {
	name: string,
	dependencies: { string },
	init: (self: InputController, deps: { [string]: any }) -> (),
	start: ((self: InputController) -> ())?,
	context: InputContext,
	newKeys: () -> SkateKeys,
	read: (self: InputController, into: SkateKeys) -> (),
	newActionKeys: () -> ActionKeys,
	readActions: (self: InputController, into: ActionKeys) -> (),
	newCameraKeys: () -> CameraKeys,
	readCamera: (self: InputController, into: CameraKeys) -> (),
	-- The player's Roblox settings: mouse and gamepad sensitivity, and an inverted look.
	setLookSettings: (self: InputController, mouse: number, stick: number, invertY: boolean) -> (),
	-- A touch button that works the control as its keys do.
	bindButton: (self: InputController, control: Config.Control, button: GuiButton) -> (),
	-- The touch position while a touch that began on `pad` lasts, (-1, -1) once it ends.
	bindTouchStick: (self: InputController, pad: GuiButton) -> InputAction,
	-- The touch stick, as a move (x right, y forward, length 0..1).
	setStick: (self: InputController, stick: Vector2) -> (),
	-- Reads whether Roblox's Developer Console is open, once a frame (FrameController), and pauses while it is.
	watchOverlays: (self: InputController) -> (),
	-- The score tab's key (Tab, or Select) held now.
	scoreTabHeld: (self: InputController) -> boolean,
	-- Whether Switch team's key (T, or D-pad Up) was pressed since its last read.
	switchTeamPressed: (self: InputController) -> boolean,
	-- Roblox's menu or Developer Console is open: every key is stopped.
	paused: boolean,
	destroy: (self: InputController) -> (),
	_input: Config.InputConfig,
	_move: InputAction,
	_jump: InputAction,
	_pump: InputAction,
	_brake: InputAction,
	_attach: InputAction,
	_throw: InputAction,
	_look: InputAction,
	_ballFocus: InputAction,
	_scoreTab: InputAction,
	_lookBindings: LookBindings,
	_stick: InputBinding,
	_presses: Presses,
	_connections: { RBXScriptConnection },
	-- The Roblox look settings last applied, and where they are read.
	_lookSettings: () -> (number, number, boolean),
	_mouseSensitivity: number,
	_stickSensitivity: number,
	_invertY: boolean,
	-- Which of Roblox's overlays are open, and where the console's state is read.
	_menuOpen: boolean,
	_consoleOpen: boolean,
	-- StarterGui:GetCore, which errors for a key Roblox's own scripts have not registered yet.
	_getCore: (key: string) -> any,
}

-- No presses counted yet.
local function noPresses(): Presses
	return { jump = 0, tackle = 0, uppercut = 0, pass = 0, ballFocus = 0, switchTeam = 0 }
end

local function getCore(key: string): any
	return StarterGui:GetCore(key)
end

-- Whether Roblox's Developer Console is open. StarterGui:GetCore errors until Roblox's own scripts register the key,
-- which counts as closed. Measured in a Studio client (2026-10-24): it answered without yielding, in about 2
-- microseconds a call.
local function devConsoleVisible(self: InputController): boolean
	local ok, visible = pcall(self._getCore, "DevConsoleVisible")
	return ok and visible == true
end

-- Pauses while either of Roblox's overlays is open.
local function pauseForOverlays(self: InputController)
	local paused = self._menuOpen or self._consoleOpen
	self.paused = paused
	self.context.Enabled = not paused
end

-- Every action's name in the context, spelled once.
local NAMES = {
	move = "Move",
	jump = "Jump",
	pump = "Pump",
	brake = "Brake",
	attach = "Attach",
	tackle = "Tackle",
	uppercut = "Uppercut",
	pass = "Pass",
	throw = "Throw",
	look = "Look",
	ballFocus = "BallFocus",
	scoreTab = "ScoreTab",
	switchTeam = "SwitchTeam",
	touchMove = "TouchMove",
	touchStick = "TouchStick",
}

local function newAction(context: InputContext, name: string, actionType: Enum.InputActionType): InputAction
	local action = Instance.new("InputAction")
	action.Name = name
	action.Type = actionType
	action.Parent = context
	return action
end

local function bindKeys(action: InputAction, keys: { Enum.KeyCode })
	for _, key in keys do
		local binding = Instance.new("InputBinding")
		binding.KeyCode = key
		binding.Parent = action
	end
end

local function newButton(context: InputContext, name: string, keys: { Enum.KeyCode }): InputAction
	local action = newAction(context, name, Enum.InputActionType.Bool)
	bindKeys(action, keys)
	return action
end

-- A button whose presses are counted under `pressed` until the next read.
local function newPressButton(
	self: InputController,
	name: string,
	keys: { Enum.KeyCode },
	pressed: Pressed
): InputAction
	local action = newButton(self.context, name, keys)
	table.insert(
		self._connections,
		action.Pressed:Connect(function()
			self._presses[pressed] += 1
		end)
	)
	return action
end

-- Whether `pressed` was pressed since its last read; the count starts over.
local function takePress(self: InputController, pressed: Pressed): boolean
	local presses = self._presses
	local any = presses[pressed] > 0
	presses[pressed] = 0
	return any
end

local function lookBinding(action: InputAction, look: Config.LookBinding): InputBinding
	local binding = Instance.new("InputBinding")
	binding.KeyCode = look.key
	binding.ResponseCurve = look.responseCurve
	binding.Parent = action
	return binding
end

-- A look binding's scale in radians, its y turned over when the player inverts the look.
local function lookScale(look: Config.LookBinding, invertY: boolean): Vector2
	local degrees = look.degPerUnit
	return Vector2.new(math.rad(degrees.X), math.rad(if invertY then -degrees.Y else degrees.Y))
end

-- The player's settings as Roblox's own camera reads them, from its UserGameSettings (looked up once).
local function lookSettingsOf(settings: UserGameSettings): () -> (number, number, boolean)
	return function(): (number, number, boolean)
		return settings.MouseSensitivity, settings.GamepadCameraSensitivity, settings:GetCameraYInvertValue() < 0
	end
end

local InputController: InputController = {
	name = "InputController",
	dependencies = { "Config" },
	context = nil :: any,
	paused = false,
	_input = nil :: any,
	_move = nil :: any,
	_jump = nil :: any,
	_pump = nil :: any,
	_brake = nil :: any,
	_attach = nil :: any,
	_throw = nil :: any,
	_look = nil :: any,
	_ballFocus = nil :: any,
	_scoreTab = nil :: any,
	_lookBindings = nil :: any,
	_stick = nil :: any,
	_presses = noPresses(),
	_connections = {},
	_lookSettings = function(): (number, number, boolean)
		return 1, 1, false
	end,
	_mouseSensitivity = 1,
	_stickSensitivity = 1,
	_invertY = false,
	_menuOpen = false,
	_consoleOpen = false,
	_getCore = getCore,

	-- deps.Parent keeps the context out of the local player's PlayerScripts in tests; deps.GuiService (its menu
	-- signals), deps.GetCore (StarterGui:GetCore) and deps.LookSettings replace the live game there.
	init = function(self: InputController, deps: { [string]: any })
		local input: Config.InputConfig = (deps.Config :: Config.GameConfig).Input
		self._input = input
		local context = Instance.new("InputContext")
		context.Name = "SkateControls"
		context.Priority = input.contextPriority
		context.Sink = true
		self.context = context
		self._presses = noPresses()
		self._connections = {}
		self._lookSettings = deps.LookSettings or lookSettingsOf(UserSettings():GetService("UserGameSettings"))

		local move = newAction(context, NAMES.move, Enum.InputActionType.Direction2D)
		for _, composite in input.move.composites do
			local binding = Instance.new("InputBinding")
			binding.Up = composite.up
			binding.Down = composite.down
			binding.Left = composite.left
			binding.Right = composite.right
			binding.Parent = move
		end
		bindKeys(move, input.move.sticks)
		local stick = Instance.new("InputBinding")
		stick.Name = NAMES.touchStick
		stick.Type = Enum.InputBindingType.Scriptable
		stick.Parent = move
		self._move = move
		self._stick = stick
		self._jump = newPressButton(self, NAMES.jump, input.jump, "jump")
		self._pump = newButton(context, NAMES.pump, input.pump)
		self._brake = newButton(context, NAMES.brake, input.brake)
		self._attach = newButton(context, NAMES.attach, input.attach)
		newPressButton(self, NAMES.tackle, input.tackle, "tackle")
		newPressButton(self, NAMES.uppercut, input.uppercut, "uppercut")
		newPressButton(self, NAMES.pass, input.pass, "pass")
		self._throw = newButton(context, NAMES.throw, input.throw)
		self._ballFocus = newPressButton(self, NAMES.ballFocus, input.ballFocus, "ballFocus")
		self._scoreTab = newButton(context, NAMES.scoreTab, input.scoreTab)
		newPressButton(self, NAMES.switchTeam, input.switchTeam, "switchTeam")

		local look = newAction(context, NAMES.look, Enum.InputActionType.Direction2D)
		self._look = look
		self._lookBindings = {
			mouse = lookBinding(look, input.look.mouse),
			stick = lookBinding(look, input.look.stick),
			touch = lookBinding(look, input.look.touch),
		}
		self._mouseSensitivity, self._stickSensitivity, self._invertY = 1, 1, false
		self:setLookSettings(1, 1, false)

		local menu = deps.GuiService or GuiService
		table.insert(
			self._connections,
			menu.MenuOpened:Connect(function()
				self._menuOpen = true
				pauseForOverlays(self)
			end)
		)
		table.insert(
			self._connections,
			menu.MenuClosed:Connect(function()
				self._menuOpen = false
				pauseForOverlays(self)
			end)
		)
		self._getCore = deps.GetCore or getCore
		self._menuOpen = menu.MenuIsOpen == true
		self._consoleOpen = false
		pauseForOverlays(self)
		context.Parent = deps.Parent or (Players.LocalPlayer :: Player):WaitForChild("PlayerScripts")
	end,

	newKeys = function(): SkateKeys
		return { move = Vector2.zero, pump = false, brake = false, attach = false, jump = false, jumpHeld = false }
	end,

	read = function(self: InputController, into: SkateKeys)
		into.move = self._move:GetState() :: Vector2
		into.pump = self._pump:GetState() :: boolean
		into.brake = self._brake:GetState() :: boolean
		into.attach = self._attach:GetState() :: boolean
		into.jump = takePress(self, "jump")
		into.jumpHeld = self._jump:GetState() :: boolean
	end,

	newActionKeys = function(): ActionKeys
		return { tackle = false, uppercut = false, pass = false, throw = false }
	end,

	readActions = function(self: InputController, into: ActionKeys)
		into.tackle = takePress(self, "tackle")
		into.uppercut = takePress(self, "uppercut")
		into.pass = takePress(self, "pass")
		into.throw = self._throw:GetState() :: boolean
	end,

	newCameraKeys = function(): CameraKeys
		return { look = Vector2.zero, ballFocus = false, ballFocusPressed = false }
	end,

	-- Also follows the player's Roblox settings, read each time as Roblox's own camera reads them.
	readCamera = function(self: InputController, into: CameraKeys)
		local mouse, stick, invertY = self._lookSettings()
		if mouse ~= self._mouseSensitivity or stick ~= self._stickSensitivity or invertY ~= self._invertY then
			self:setLookSettings(mouse, stick, invertY)
		end
		into.look = self._look:GetState() :: Vector2
		into.ballFocus = self._ballFocus:GetState() :: boolean
		into.ballFocusPressed = takePress(self, "ballFocus")
	end,

	setLookSettings = function(self: InputController, mouse: number, stick: number, invertY: boolean)
		local looks, bindings = self._input.look, self._lookBindings
		bindings.mouse.Scale = mouse
		bindings.stick.Scale = stick
		bindings.mouse.Vector2Scale = lookScale(looks.mouse, invertY)
		bindings.stick.Vector2Scale = lookScale(looks.stick, invertY)
		bindings.touch.Vector2Scale = lookScale(looks.touch, invertY)
		self._mouseSensitivity, self._stickSensitivity, self._invertY = mouse, stick, invertY
	end,

	bindButton = function(self: InputController, control: Config.Control, button: GuiButton)
		local binding = Instance.new("InputBinding")
		binding.UIButton = button
		binding.Parent = self.context:FindFirstChild(NAMES[control]) :: InputAction
	end,

	bindTouchStick = function(self: InputController, pad: GuiButton): InputAction
		local action = newAction(self.context, NAMES.touchMove, Enum.InputActionType.ViewportPosition)
		local binding = Instance.new("InputBinding")
		binding.KeyCode = Enum.KeyCode.TouchPosition
		binding.UIModifier = pad
		binding.Parent = action
		return action
	end,

	setStick = function(self: InputController, stick: Vector2)
		self._stick:Fire(stick)
	end,

	scoreTabHeld = function(self: InputController): boolean
		return self._scoreTab:GetState() :: boolean
	end,

	switchTeamPressed = function(self: InputController): boolean
		return takePress(self, "switchTeam")
	end,

	watchOverlays = function(self: InputController)
		local open = devConsoleVisible(self)
		if open ~= self._consoleOpen then
			self._consoleOpen = open
			pauseForOverlays(self)
		end
	end,

	destroy = function(self: InputController)
		for _, connection in self._connections do
			connection:Disconnect()
		end
		table.clear(self._connections)
		self.context:Destroy()
	end,
}

return InputController
