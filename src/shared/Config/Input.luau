--!strict
-- The controls (spec §8.3): the skating and action keys for keyboard and gamepad, the camera's look and Ball Focus,
-- which action each action key may start, and the touch stick and buttons, all bound through Roblox's Input Action
-- System. Bindings, touch layout and on-screen labels come from here and Config.UI only.

local Actions = require(script.Parent.Actions)
local Validate = require(script.Parent.Validate)

-- Four keys that make one direction, like WASD.
export type Composite = { up: Enum.KeyCode, down: Enum.KeyCode, left: Enum.KeyCode, right: Enum.KeyCode }
-- Every control a key or a touch button drives.
export type Control = "jump" | "pump" | "brake" | "attach" | "tackle" | "uppercut" | "pass" | "throw" | "ballFocus"
-- The controls that start actions.
export type ActionKey = "tackle" | "uppercut" | "pass" | "throw"
-- A look input and how far it turns the camera: degrees per pixel for a mouse or a swipe, per second at full tilt for
-- a stick. A negative y turns the other way.
export type LookBinding = { key: Enum.KeyCode, degPerUnit: Vector2 }
-- Ball Focus while held, or switched on and off by presses.
export type FocusMode = "Hold" | "Toggle"
export type TouchButtons = {
	jump: UDim2,
	pump: UDim2,
	brake: UDim2,
	attach: UDim2,
	tackle: UDim2,
	uppercut: UDim2,
	pass: UDim2,
	throw: UDim2,
}
export type TouchLayout = {
	-- Anchored bottom-left: a touch that starts here grows the stick under the thumb.
	stickArea: UDim2,
	-- Pixels: the stick reads nothing within stickDeadZone of where the touch began, and full tilt at stickRadius.
	stickDeadZone: number,
	stickRadius: number,
	buttonSize: UDim2,
	-- Each button's center, as a fraction of the screen.
	buttons: TouchButtons,
}

export type InputConfig = {
	-- Above Roblox's own character controls (priority 150), whose defaults on our keys this context sinks.
	contextPriority: number,
	move: { composites: { Composite }, sticks: { Enum.KeyCode } },
	jump: { Enum.KeyCode },
	pump: { Enum.KeyCode },
	brake: { Enum.KeyCode },
	attach: { Enum.KeyCode },
	-- Tackle, a Dive during a tackle, or a Dodge with the ball.
	tackle: { Enum.KeyCode },
	uppercut: { Enum.KeyCode },
	-- A Pass with the ball, a Call Pass without.
	pass: { Enum.KeyCode },
	-- Held to charge a throw, released to throw.
	throw: { Enum.KeyCode },
	look: { mouse: LookBinding, stick: LookBinding, touch: LookBinding },
	-- Without the ball; it may share Charge Throw's keys, which act only with the ball.
	ballFocus: { Enum.KeyCode },
	ballFocusMode: FocusMode,
	touchBallFocusMode: FocusMode,
	-- The actions each action key may start, in order: the first whose requires.ball fits is the one.
	actions: {
		tackle: { Actions.ActionName },
		uppercut: { Actions.ActionName },
		pass: { Actions.ActionName },
		throw: { Actions.ActionName },
	},
	touch: TouchLayout,
}

local defaults: InputConfig = {
	contextPriority = 1000,
	move = {
		composites = { { up = Enum.KeyCode.W, down = Enum.KeyCode.S, left = Enum.KeyCode.A, right = Enum.KeyCode.D } },
		sticks = { Enum.KeyCode.Thumbstick1 },
	},
	jump = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA },
	pump = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonR2 },
	brake = { Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonR1 },
	attach = { Enum.KeyCode.F, Enum.KeyCode.ButtonL1 },
	tackle = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
	uppercut = { Enum.KeyCode.Q, Enum.KeyCode.ButtonB },
	pass = { Enum.KeyCode.R, Enum.KeyCode.ButtonY },
	throw = { Enum.KeyCode.MouseLeftButton, Enum.KeyCode.ButtonL2 },
	-- Roblox's own camera scales.
	look = {
		mouse = { key = Enum.KeyCode.MouseDelta, degPerUnit = Vector2.new(0.5, 0.385) },
		stick = { key = Enum.KeyCode.Thumbstick2, degPerUnit = Vector2.new(240, -185) },
		touch = { key = Enum.KeyCode.TouchDelta, degPerUnit = Vector2.new(1, 0.66) },
	},
	ballFocus = { Enum.KeyCode.MouseRightButton, Enum.KeyCode.ButtonL2 },
	ballFocusMode = "Hold",
	touchBallFocusMode = "Toggle",
	actions = {
		tackle = { "Tackle", "Dodge" },
		uppercut = { "Uppercut" },
		pass = { "Pass", "CallPass" },
		throw = { "ChargeThrow" },
	},
	-- Roblox's own stick area and sizes; the buttons as the owner chose them (2026-10-23).
	touch = {
		stickArea = UDim2.fromScale(0.4, 2 / 3),
		stickDeadZone = 2,
		stickRadius = 20,
		buttonSize = UDim2.fromOffset(72, 72),
		buttons = {
			uppercut = UDim2.fromScale(0.92, 0.42),
			pass = UDim2.fromScale(0.81, 0.52),
			tackle = UDim2.fromScale(0.92, 0.62),
			attach = UDim2.fromScale(0.7, 0.7),
			throw = UDim2.fromScale(0.81, 0.7),
			brake = UDim2.fromScale(0.7, 0.88),
			pump = UDim2.fromScale(0.81, 0.88),
			jump = UDim2.fromScale(0.92, 0.82),
		},
	},
}

local key = Validate.enumItem(Enum.KeyCode)
local keys = Validate.list(key)
local udim2 = Validate.datatype("UDim2")
local lookBinding = Validate.record({ key = key, degPerUnit = Validate.datatype("Vector2") })
local focusMode = Validate.string({ oneOf = { "Hold", "Toggle" } })
local actionList = Validate.check(
	Validate.list(Validate.check(Validate.string(), function(name: string): boolean
		return Actions.nameOf(name) ~= nil
	end, "must name an action")),
	function(names: { string }): boolean
		return #names > 0
	end,
	"must name at least one action"
)

local fields = Validate.record({
	contextPriority = Validate.number({ min = 0, integer = true }),
	move = Validate.record({
		composites = Validate.list(Validate.record({ up = key, down = key, left = key, right = key })),
		sticks = keys,
	}),
	jump = keys,
	pump = keys,
	brake = keys,
	attach = keys,
	tackle = keys,
	uppercut = keys,
	pass = keys,
	throw = keys,
	look = Validate.record({ mouse = lookBinding, stick = lookBinding, touch = lookBinding }),
	ballFocus = keys,
	ballFocusMode = focusMode,
	touchBallFocusMode = focusMode,
	actions = Validate.record({ tackle = actionList, uppercut = actionList, pass = actionList, throw = actionList }),
	touch = Validate.check(
		Validate.record({
			stickArea = udim2,
			stickDeadZone = Validate.number({ min = 0 }),
			stickRadius = Validate.number({ above = 0 }),
			buttonSize = udim2,
			buttons = Validate.record({
				jump = udim2,
				pump = udim2,
				brake = udim2,
				attach = udim2,
				tackle = udim2,
				uppercut = udim2,
				pass = udim2,
				throw = udim2,
			}),
		}),
		function(touch: TouchLayout): boolean
			return touch.stickRadius > touch.stickDeadZone
		end,
		"stickRadius must be above stickDeadZone"
	),
})

-- Every key the bindings use, in order. A Ball Focus key that Charge Throw also binds is counted once: the throw
-- acts only with the ball and Ball Focus only without it.
local function boundKeys(input: InputConfig): { Enum.KeyCode }
	local all: { Enum.KeyCode } = {}
	for _, composite in input.move.composites do
		table.insert(all, composite.up)
		table.insert(all, composite.down)
		table.insert(all, composite.left)
		table.insert(all, composite.right)
	end
	local lists = {
		input.move.sticks,
		input.jump,
		input.pump,
		input.brake,
		input.attach,
		input.tackle,
		input.uppercut,
		input.pass,
		input.throw,
		{ input.look.mouse.key, input.look.stick.key, input.look.touch.key },
	}
	for _, list in lists do
		for _, bound in list do
			table.insert(all, bound)
		end
	end
	for _, bound in input.ballFocus do
		if table.find(input.throw, bound) == nil then
			table.insert(all, bound)
		end
	end
	return all
end

-- One key for one action: the first key bound twice is reported by name.
local function schema(value: any, path: string): { string }
	local errors = fields(value, path)
	if #errors > 0 then
		return errors
	end
	local seen: { [Enum.KeyCode]: boolean } = {}
	for _, bound in boundKeys(value) do
		if seen[bound] then
			return { `{path}: {bound.Name} is bound to more than one action` }
		end
		seen[bound] = true
	end
	return {}
end

return {
	defaults = defaults,
	schema = schema,
}
