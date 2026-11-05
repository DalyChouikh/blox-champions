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
-- The controls with a touch button: every control but Ball Focus, which the throw button also works.
export type TouchControl = "jump" | "pump" | "brake" | "attach" | "tackle" | "uppercut" | "pass" | "throw"
-- The controls that start actions.
export type ActionKey = "tackle" | "uppercut" | "pass" | "throw"
-- A look input and how far it turns the camera: degrees per pixel for a mouse or a swipe, per second at full tilt for
-- a stick. A negative y turns the other way. A stick's responseCurve (1..10) gives finer control near its center.
export type LookBinding = { key: Enum.KeyCode, degPerUnit: Vector2, responseCurve: number }
-- Ball Focus while held, or switched on and off by presses.
export type FocusMode = "Hold" | "Toggle"
-- One touch button: its centre (`place`, pixels from the whole screen's bottom-right corner, its physical one, as
-- Roblox places its own jump button), how wide it is across its ink (`size`, pixels), and how tall its words may be
-- (textSize, pixels; longer words shrink to fit).
export type TouchButton = { place: UDim2, size: number, textSize: number }
export type TouchButtons = {
	jump: TouchButton,
	pump: TouchButton,
	brake: TouchButton,
	attach: TouchButton,
	tackle: TouchButton,
	uppercut: TouchButton,
	pass: TouchButton,
	throw: TouchButton,
}
export type TouchLayout = {
	-- Anchored bottom-left: a touch that starts here grows the stick under the thumb.
	stickArea: UDim2,
	-- Pixels: the stick reads nothing within stickDeadZone of where the touch began, and full tilt at stickRadius.
	stickDeadZone: number,
	stickRadius: number,
	-- Pixels: the ring drawn where the touch began, and the knob under the thumb.
	stickRingSize: number,
	stickKnobSize: number,
	-- On a screen whose shorter side exceeds bigScreenSide pixels, the stick is bigScreenStickScale times larger and
	-- the buttons (their sizes and places) bigScreenButtonScale times, as Roblox grows its own stick and jump button.
	bigScreenSide: number,
	bigScreenStickScale: number,
	bigScreenButtonScale: number,
	buttons: TouchButtons,
}

export type InputConfig = {
	-- Above Roblox's own character controls (priority 150), whose defaults on our keys this context sinks.
	contextPriority: number,
	-- How long the client waits for Roblox's own input contexts (its PlayerModule's) to switch them off.
	robloxContextsWaitSeconds: number,
	move: { composites: { Composite }, sticks: { Enum.KeyCode } },
	jump: { Enum.KeyCode },
	pump: { Enum.KeyCode },
	brake: { Enum.KeyCode },
	attach: { Enum.KeyCode },
	-- A Tackle, or a Dodge with the ball, which drops a charge (Cancel & Dodge, #312); then a Dive just after either
	-- (#240, #314), with the hands that move had (Q178).
	tackle: { Enum.KeyCode },
	-- An Uppercut without the ball, Roll Ball while a throw charges (#312).
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
	-- Held to show the score tab.
	scoreTab: { Enum.KeyCode },
	-- Pressed while the score tab is open, to switch team (#310).
	switchTeam: { Enum.KeyCode },
	-- The actions each action key may start, in order: the first that may start now (its requires fit the ball, the
	-- ground or the air; a follow-up only in its window, #240) is the one.
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
	robloxContextsWaitSeconds = 10,
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
	-- Degrees per pixel (the mouse, touch) and per second at full tilt (the stick). The mouse at a fifth of Roblox's
	-- own scale (the owner, #275, Q35: in RC "I need to do more drag movement to do a 360", Video 18; played at a half
	-- and a quarter, Q49 and Q52: "still decrease the camera sensitivity by a little bit more"): 3,600 px a full turn
	-- at Roblox's default sensitivity, which players still scale in Roblox's settings. The stick and touch are
	-- Roblox's own.
	look = {
		mouse = { key = Enum.KeyCode.MouseDelta, degPerUnit = Vector2.new(0.1, 0.077), responseCurve = 1 },
		stick = { key = Enum.KeyCode.Thumbstick2, degPerUnit = Vector2.new(240, -185), responseCurve = 2 },
		touch = { key = Enum.KeyCode.TouchDelta, degPerUnit = Vector2.new(1, 0.66), responseCurve = 1 },
	},
	ballFocus = { Enum.KeyCode.MouseRightButton, Enum.KeyCode.ButtonL2 },
	ballFocusMode = "Hold",
	touchBallFocusMode = "Toggle",
	scoreTab = { Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect },
	-- The owner (Q117, #310): the score tab shows only while its key is held, with the mouse locked, so its Switch team
	-- button names a key to press meanwhile.
	switchTeam = { Enum.KeyCode.T, Enum.KeyCode.DPadUp },
	actions = {
		tackle = { "Dive", "Tackle", "Dodge" },
		uppercut = { "Uppercut", "RollBall" },
		pass = { "Pass", "CallPass" },
		throw = { "ChargeThrow" },
	},
	-- Roblox's own stick area and sizes. The buttons in arrangement A, sized by use (#355, the owner's Q245: their Q187
	-- drawing with Uppercut and Attach added), at the physical corner, as played (Q246, Q249): Jump 22 px from each
	-- edge. Grown 1.5 times, the buttons' top (254 px from the bottom) and Roblox's 58 px top bar still fit any big
	-- screen.
	touch = {
		stickArea = UDim2.fromScale(0.4, 2 / 3),
		stickDeadZone = 2,
		stickRadius = 20,
		stickRingSize = 74,
		stickKnobSize = 36,
		bigScreenSide = 500,
		bigScreenStickScale = 2,
		bigScreenButtonScale = 1.5,
		buttons = {
			jump = { place = UDim2.new(1, -70, 1, -70), size = 96, textSize = 18 },
			throw = { place = UDim2.new(1, -163, 1, -53), size = 70, textSize = 16 },
			tackle = { place = UDim2.new(1, -150, 1, -132), size = 64, textSize = 15 },
			pump = { place = UDim2.new(1, -72, 1, -160), size = 64, textSize = 15 },
			pass = { place = UDim2.new(1, -225, 1, -133), size = 64, textSize = 13 },
			uppercut = { place = UDim2.new(1, -150, 1, -206), size = 64, textSize = 13 },
			brake = { place = UDim2.new(1, -235, 1, -59), size = 58, textSize = 14 },
			attach = { place = UDim2.new(1, -77, 1, -229), size = 50, textSize = 12 },
		},
	},
}

local key = Validate.enumItem(Enum.KeyCode)
local keys = Validate.list(key)
local udim2 = Validate.datatype("UDim2")
local lookBinding = Validate.record({
	key = key,
	degPerUnit = Validate.datatype("Vector2"),
	responseCurve = Validate.number({ min = 1, max = 10 }),
})
local focusMode = Validate.string({ oneOf = { "Hold", "Toggle" } })
-- Whole pixels: a UDim's offset drops a fraction (probed).
local touchButton = Validate.record({
	place = udim2,
	size = Validate.number({ min = 1, integer = true }),
	textSize = Validate.textSize(),
})
local actionList = Validate.check(
	Validate.list(Validate.check(Validate.string(), function(name: string): boolean
		return Actions.nameOf(name) ~= nil
	end, "must name an action")),
	function(names: { string }): boolean
		return #names > 0
	end,
	"must name at least one action"
)

-- Every touch button, one each: the rules below and the buttons' reach (Input/TouchArea) read them.
local function buttonList(touch: TouchLayout): { TouchButton }
	local b = touch.buttons
	return { b.jump, b.pump, b.brake, b.attach, b.tackle, b.uppercut, b.pass, b.throw }
end

-- Whether every button sits at the bottom-right corner (scales 1, 1), as TouchButton documents: the buttons' reach is
-- measured from there.
local function fromCorner(touch: TouchLayout): boolean
	for _, button in buttonList(touch) do
		local place = button.place
		if place.X.Scale ~= 1 or place.Y.Scale ~= 1 then
			return false
		end
	end
	return true
end

-- Whether two buttons, both placed from the corner, have centres nearer than half of both their sizes both across and
-- down: their hit areas, squares whatever a face's shape, would cover each other.
local function buttonsOverlap(touch: TouchLayout): boolean
	local all = buttonList(touch)
	for first = 1, #all - 1 do
		local p = all[first]
		for second = first + 1, #all do
			local q = all[second]
			local apart = (p.size + q.size) / 2
			if
				math.abs(p.place.X.Offset - q.place.X.Offset) < apart
				and math.abs(p.place.Y.Offset - q.place.Y.Offset) < apart
			then
				return true
			end
		end
	end
	return false
end

local fields = Validate.record({
	contextPriority = Validate.number({ min = 0, integer = true }),
	robloxContextsWaitSeconds = Validate.number({ above = 0 }),
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
	scoreTab = keys,
	switchTeam = keys,
	actions = Validate.record({ tackle = actionList, uppercut = actionList, pass = actionList, throw = actionList }),
	touch = Validate.checkAll(
		Validate.record({
			stickArea = udim2,
			stickDeadZone = Validate.number({ min = 0 }),
			stickRadius = Validate.number({ above = 0 }),
			stickRingSize = Validate.number({ above = 0 }),
			stickKnobSize = Validate.number({ above = 0 }),
			bigScreenSide = Validate.number({ above = 0 }),
			bigScreenStickScale = Validate.number({ above = 0 }),
			bigScreenButtonScale = Validate.number({ above = 0 }),
			buttons = Validate.record({
				jump = touchButton,
				pump = touchButton,
				brake = touchButton,
				attach = touchButton,
				tackle = touchButton,
				uppercut = touchButton,
				pass = touchButton,
				throw = touchButton,
			}),
		}),
		{
			{
				message = "stickRadius must be above stickDeadZone",
				holds = function(touch: TouchLayout): boolean
					return touch.stickRadius > touch.stickDeadZone
				end,
			},
			{
				message = "buttons must sit at the bottom-right corner (scales 1, 1)",
				holds = fromCorner,
			},
			{
				message = "buttons must not overlap",
				holds = function(touch: TouchLayout): boolean
					return not buttonsOverlap(touch)
				end,
			},
		}
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
		input.scoreTab,
		input.switchTeam,
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
	buttonList = buttonList,
}
