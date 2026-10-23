--!strict
-- Our touch controls (spec §8.3, §11.1), shown only while the player plays by touch; Roblox's own are off
-- (RobloxDefaults). A touch that starts on the stick pad (the lower left) grows a stick under the thumb, with Roblox's
-- own stick math (TouchStick) and sizes. One button per control sits in the lower right, placed in pixels from the
-- corner (Config.Input.touch), each working its control through InputController as its keys do; the throw button also
-- works Ball Focus. On a big screen the stick and the buttons grow, as Roblox's own do, and they follow the screen's
-- size. Before each frame is drawn (FrameController), every action button reads what it would start now
-- (ActionController:keyAction): Tackle, Dive or Dodge; Pass or Call; Throw with the ball and Focus without. Uppercut
-- shows only when it can start, and Attach only right behind a teammate. A property is written only when it changes.
-- Hiding the controls under a thumb ends that touch.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ActionController = require(script.Parent.ActionController)
local Config = require(ReplicatedStorage.Shared.Config)
local InputController = require(script.Parent.InputController)
local SkateController = require(script.Parent.SkateController)
local TouchStick = require(ReplicatedStorage.Shared.Input.TouchStick)

-- Every control with a button, in the order the buttons are built.
local CONTROLS: { Config.TouchControl } = { "jump", "pump", "brake", "attach", "tackle", "uppercut", "pass", "throw" }
-- Where Roblox reports a touch on the pad that has ended (or none yet).
local NO_TOUCH = Vector2.new(-1, -1)

-- Spelled out so the module is a Loader.LoadableModule and callers see its members.
export type TouchControls = {
	name: string,
	dependencies: { string },
	init: (self: TouchControls, deps: { [string]: any }) -> (),
	start: (self: TouchControls) -> (),
	step: (self: TouchControls, dt: number) -> (),
	-- Sizes the stick and places and sizes the buttons for the screen: larger on a big one.
	layout: (self: TouchControls) -> (),
	gui: ScreenGui,
	-- Each control's button, by its name in Config.Input.touch.buttons.
	buttons: { [string]: TextButton },
	-- Invisible: a touch that begins here moves the skater.
	pad: ImageButton,
	-- Drawn while a touch on the pad lasts: the ring where it began, the knob under the thumb.
	ring: Frame,
	knob: Frame,
	_config: Config.GameConfig,
	_input: InputController.InputController,
	_actions: ActionController.ActionController,
	_skate: SkateController.SkateController,
	_preferredInput: () -> Enum.PreferredInput,
	_screenSize: () -> Vector2,
	-- What the gui and each button last showed, so a step writes only what changed.
	_enabled: boolean,
	_texts: { [string]: string },
	_shown: { [string]: boolean },
	-- The touch on the pad: where it began, nil while none lasts.
	_origin: Vector2?,
	-- How much larger than Config.Input.touch the stick and the buttons are on this screen.
	_stickScale: number,
	_buttonScale: number,
}

-- A rounded shape in the touch style's background.
local function disc(class: "Frame" | "TextButton", style: Config.TouchStyle): GuiObject
	local shape = Instance.new(class) :: GuiObject
	shape.AnchorPoint = Vector2.new(0.5, 0.5)
	shape.BackgroundColor3 = style.background
	shape.BackgroundTransparency = style.backgroundTransparency
	shape.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = style.corner
	corner.Parent = shape
	return shape
end

local function newButton(control: Config.TouchControl, config: Config.GameConfig, parent: Instance): TextButton
	local style = config.UI.touchStyle
	local button = disc("TextButton", style) :: TextButton
	button.Name = control
	button.Text = ""
	button.TextColor3 = style.foreground
	button.Font = style.font
	button.TextScaled = true
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = style.textSize
	cap.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, style.textPadding)
	padding.PaddingRight = UDim.new(0, style.textPadding)
	padding.Parent = button
	button.Parent = parent
	return button
end

-- Shows `control`'s button reading `label`, or hides it when there is none.
local function show(self: TouchControls, control: Config.TouchControl, label: string?)
	local visible = label ~= nil
	local button = self.buttons[control]
	if self._shown[control] ~= visible then
		self._shown[control] = visible
		button.Visible = visible
	end
	if label ~= nil and self._texts[control] ~= label then
		self._texts[control] = label
		button.Text = label
	end
end

-- The label of what `key` would start now; nil when it would start nothing.
local function actionLabel(self: TouchControls, key: Config.ActionKey): string?
	local action = self._actions:keyAction(key)
	return if action ~= nil then self._config.UI.controlLabels[action] else nil
end

-- A screen point as a place on the pad, as Roblox's own stick places its ring and knob.
local function onPad(self: TouchControls, point: Vector2): UDim2
	local offset = point + GuiService:GetInsetArea(Enum.ScreenInsets.None).Min - self.pad.AbsolutePosition
	return UDim2.fromOffset(offset.X, offset.Y)
end

-- `size` (pixels) times `scale`.
local function scaled(size: UDim2, scale: number): UDim2
	return UDim2.new(size.X.Scale, size.X.Offset * scale, size.Y.Scale, size.Y.Offset * scale)
end

-- A touch began on the pad at `position`: the stick is drawn there, sized for this screen.
local function startTouch(self: TouchControls, position: Vector2): Vector2
	local touch = self._config.Input.touch
	local scale = self._stickScale
	local ring, knob = self.ring, self.knob
	ring.Size = UDim2.fromOffset(touch.stickRingSize * scale, touch.stickRingSize * scale)
	knob.Size = UDim2.fromOffset(touch.stickKnobSize * scale, touch.stickKnobSize * scale)
	ring.Position = onPad(self, position)
	ring.Visible = true
	knob.Visible = true
	self._origin = position
	return position
end

-- A touch on the pad began, moved or ended: the stick follows it from where it began.
local function onTouch(self: TouchControls, position: Vector2)
	if position == NO_TOUCH then
		self._origin = nil
		self.ring.Visible = false
		self.knob.Visible = false
		self._input:setStick(Vector2.zero)
		return
	end
	local origin = self._origin or startTouch(self, position)
	self.knob.Position = onPad(self, position)
	local touch, scale = self._config.Input.touch, self._stickScale
	self._input:setStick(TouchStick.vector(origin, position, touch.stickDeadZone * scale, touch.stickRadius * scale))
end

local TouchControls: TouchControls = {
	name = "TouchControls",
	dependencies = { "Config", "InputController", "ActionController", "SkateController" },
	gui = nil :: any,
	buttons = {},
	pad = nil :: any,
	ring = nil :: any,
	knob = nil :: any,
	_config = nil :: any,
	_input = nil :: any,
	_actions = nil :: any,
	_skate = nil :: any,
	_preferredInput = function(): Enum.PreferredInput
		return Enum.PreferredInput.KeyboardAndMouse
	end,
	_screenSize = function(): Vector2
		return Vector2.zero
	end,
	_enabled = false,
	_texts = {},
	_shown = {},
	_origin = nil,
	_stickScale = 1,
	_buttonScale = 0,

	-- deps.Parent keeps the gui out of the local player's PlayerGui in tests; deps.PreferredInput and deps.ScreenSize
	-- replace the live game there.
	init = function(self: TouchControls, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		local touch, style = config.Input.touch, config.UI.touchStyle
		self._config = config
		self._input = deps.InputController
		self._actions = deps.ActionController
		self._skate = deps.SkateController
		self._preferredInput = deps.PreferredInput
			or function(): Enum.PreferredInput
				return UserInputService.PreferredInput
			end
		self._screenSize = deps.ScreenSize or function(): Vector2
			return self.gui.AbsoluteSize
		end
		self._enabled = false
		self._texts = {}
		self._shown = {}
		self._origin = nil
		self._stickScale = 1
		self._buttonScale = 0

		-- As Roblox's own touch gui: kept across respawns, inside the device's safe area.
		local gui = Instance.new("ScreenGui")
		gui.Name = "TouchControls"
		gui.Enabled = false
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		gui.ClipToDeviceSafeArea = false
		self.gui = gui

		local pad = Instance.new("ImageButton")
		pad.Name = "StickPad"
		pad.AnchorPoint = Vector2.new(0, 1)
		pad.Position = UDim2.fromScale(0, 1)
		pad.Size = touch.stickArea
		pad.BackgroundTransparency = 1
		pad.ImageTransparency = 1
		pad.AutoButtonColor = false
		pad.Parent = gui
		self.pad = pad
		local ring = disc("Frame", style) :: Frame
		ring.Name = "StickRing"
		ring.Visible = false
		ring.Parent = pad
		self.ring = ring
		local knob = disc("Frame", style) :: Frame
		knob.Name = "StickKnob"
		knob.BackgroundColor3 = style.foreground
		knob.BackgroundTransparency = style.knobTransparency
		knob.ZIndex = ring.ZIndex + 1
		knob.Visible = false
		knob.Parent = pad
		self.knob = knob

		local input = self._input
		local buttons: { [string]: TextButton } = {}
		for _, control: Config.TouchControl in CONTROLS do
			local button = newButton(control, config, gui)
			buttons[control] = button
			input:bindButton(control, button)
		end
		input:bindButton("ballFocus", buttons.throw)
		self.buttons = buttons
		local labels = config.UI.controlLabels
		show(self, "jump", labels.Jump)
		show(self, "pump", labels.Pump)
		show(self, "brake", labels.Brake)
		show(self, "attach", nil)
		input:bindTouchStick(pad).StateChanged:Connect(function(position: Vector2)
			onTouch(self, position)
		end)
		gui.Parent = deps.Parent or (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
		self:layout()
	end,

	-- The screen's size changes when a window is resized or a device turned.
	start = function(self: TouchControls)
		self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:layout()
		end)
	end,

	layout = function(self: TouchControls)
		local touch = self._config.Input.touch
		local screen = self._screenSize()
		local big = math.min(screen.X, screen.Y) > touch.bigScreenSide
		self._stickScale = if big then touch.bigScreenStickScale else 1
		local scale = if big then touch.bigScreenButtonScale else 1
		if scale == self._buttonScale then
			return
		end
		self._buttonScale = scale
		local size = scaled(touch.buttonSize, scale)
		for _, control: Config.TouchControl in CONTROLS do
			local button = self.buttons[control]
			button.Position = scaled(touch.buttons[control], scale)
			button.Size = size
		end
	end,

	step = function(self: TouchControls, _dt: number)
		local enabled = self._preferredInput() == Enum.PreferredInput.Touch
		if enabled ~= self._enabled then
			self._enabled = enabled
			self.gui.Enabled = enabled
			-- Hidden under a thumb (a gamepad plugged in mid-touch): that touch ends here.
			if not enabled and self._origin ~= nil then
				onTouch(self, NO_TOUCH)
			end
		end
		if not enabled then
			return
		end
		local labels = self._config.UI.controlLabels
		show(self, "tackle", actionLabel(self, "tackle"))
		show(self, "uppercut", actionLabel(self, "uppercut"))
		show(self, "pass", actionLabel(self, "pass"))
		show(self, "throw", actionLabel(self, "throw") or labels.BallFocus)
		show(self, "attach", if self._skate.attachable then labels.Attach else nil)
	end,
}

return TouchControls
