--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local InputController = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.InputController)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

-- The player's Roblox look settings as a player who never changed them has them.
local function defaultLookSettings(): (number, number, boolean)
	return 1, 1, false
end

local folder: Folder
beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "InputControllerTest"
	folder.Parent = ReplicatedStorage
	InputController:init({ Config = Fixtures.config(), Parent = folder, LookSettings = defaultLookSettings })
end)
afterEach(function()
	InputController:destroy()
	folder:Destroy()
end)

-- The look scales are small (radians per pixel), so they are compared this closely.
local EXACT = 1e-6

-- The Look action's bindings by the key they read.
local function lookBindings(): { [string]: InputBinding }
	local byKey: { [string]: InputBinding } = {}
	for _, child in (InputController.context:FindFirstChild("Look") :: InputAction):GetChildren() do
		local binding = child :: InputBinding
		byKey[binding.KeyCode.Name] = binding
	end
	return byKey
end

describe("InputController", function()
	it("builds one sinking context above Roblox's own controls, bound as Config.Input says", function()
		local context = InputController.context
		expect(context.Priority).toBe(1000)
		expect(context.Sink).toBe(true)
		local pump = context:FindFirstChild("Pump") :: InputAction
		expect(pump.Type).toBe(Enum.InputActionType.Bool)
		local keys: { string } = {}
		for _, binding in pump:GetChildren() do
			table.insert(keys, (binding :: InputBinding).KeyCode.Name)
		end
		table.sort(keys)
		expect(keys).toEqual({ "ButtonR2", "LeftShift" })
		local move = context:FindFirstChild("Move") :: InputAction
		expect(move.Type).toBe(Enum.InputActionType.Direction2D)
		expect(#move:GetChildren()).toBe(3) -- the WASD composite, the left stick and the touch stick
	end)

	it("reads the move stick and the held buttons", function()
		local context = InputController.context
		Fixtures.scriptedBinding(context, "Move"):Fire(Vector2.new(0.6, 0.8))
		Fixtures.scriptedBinding(context, "Brake"):Fire(true)
		local keys = InputController.newKeys()
		InputController:read(keys)
		expect(keys.move.X).toBeCloseTo(0.6, 5)
		expect(keys.move.Y).toBeCloseTo(0.8, 5)
		expect(keys.brake).toBe(true)
		expect(keys.pump).toBe(false)
		expect(keys.attach).toBe(false)
	end)

	it("counts a jump press once, however long it is held", function()
		local jump = Fixtures.scriptedBinding(InputController.context, "Jump")
		local keys = InputController.newKeys()
		jump:Fire(true)
		task.wait() -- Pressed is deferred
		InputController:read(keys)
		expect(keys.jump).toBe(true)
		InputController:read(keys)
		expect(keys.jump).toBe(false)
		jump:Fire(false)
		jump:Fire(true)
		task.wait()
		InputController:read(keys)
		expect(keys.jump).toBe(true)
	end)

	it("reads action presses once and the throw while held", function()
		local context = InputController.context
		local tackle = Fixtures.scriptedBinding(context, "Tackle")
		local pass = Fixtures.scriptedBinding(context, "Pass")
		local throw = Fixtures.scriptedBinding(context, "Throw")
		local actions = InputController.newActionKeys()
		tackle:Fire(true)
		pass:Fire(true)
		task.wait() -- Pressed is deferred
		InputController:readActions(actions)
		expect(actions).toEqual({ tackle = true, uppercut = false, pass = true, throw = false })
		InputController:readActions(actions)
		expect(actions).toEqual({ tackle = false, uppercut = false, pass = false, throw = false })
		-- A hold is read from the state, at once.
		throw:Fire(true)
		InputController:readActions(actions)
		expect(actions.throw).toBe(true)
		InputController:readActions(actions)
		expect(actions.throw).toBe(true)
		throw:Fire(false)
		InputController:readActions(actions)
		expect(actions.throw).toBe(false)
	end)

	it("reads the score tab held on Tab or Select", function()
		local context = InputController.context
		local action = context:FindFirstChild("ScoreTab") :: InputAction
		expect(action.Type).toBe(Enum.InputActionType.Bool)
		local keys: { string } = {}
		for _, binding in action:GetChildren() do
			table.insert(keys, (binding :: InputBinding).KeyCode.Name)
		end
		table.sort(keys)
		expect(keys).toEqual({ "ButtonSelect", "Tab" })
		local held = Fixtures.scriptedBinding(context, "ScoreTab")
		expect(InputController:scoreTabHeld()).toBe(false)
		held:Fire(true)
		expect(InputController:scoreTabHeld()).toBe(true)
		held:Fire(false)
		expect(InputController:scoreTabHeld()).toBe(false)
	end)

	it("keeps the skating keys and the action keys apart", function()
		local context = InputController.context
		local jump = Fixtures.scriptedBinding(context, "Jump")
		local tackle = Fixtures.scriptedBinding(context, "Tackle")
		local keys, actions = InputController.newKeys(), InputController.newActionKeys()
		jump:Fire(true)
		tackle:Fire(true)
		task.wait()
		InputController:readActions(actions)
		InputController:read(keys)
		expect(keys.jump).toBe(true)
		expect(actions.tackle).toBe(true)

		jump:Fire(false)
		tackle:Fire(false)
		jump:Fire(true)
		tackle:Fire(true)
		task.wait()
		InputController:read(keys)
		InputController:readActions(actions)
		expect(keys.jump).toBe(true)
		expect(actions.tackle).toBe(true)
	end)

	it("binds the look to the mouse, the right stick and touch, in radians", function()
		local look = InputController.context:FindFirstChild("Look") :: InputAction
		expect(look.Type).toBe(Enum.InputActionType.Direction2D)
		local byKey = lookBindings()
		Fixtures.expectNear2(byKey.MouseDelta.Vector2Scale, Vector2.new(math.rad(0.5), math.rad(0.385)), EXACT)
		Fixtures.expectNear2(byKey.Thumbstick2.Vector2Scale, Vector2.new(math.rad(240), math.rad(-185)), EXACT)
		Fixtures.expectNear2(byKey.TouchDelta.Vector2Scale, Vector2.new(math.rad(1), math.rad(0.66)), EXACT)
		expect(byKey.Thumbstick2.ResponseCurve).toBe(2)
		expect(byKey.MouseDelta.ResponseCurve).toBe(1)
	end)

	it("scales the look by the player's Roblox settings", function()
		local byKey = lookBindings()
		InputController:setLookSettings(2, 0.5, true)
		expect(byKey.MouseDelta.Scale).toBe(2)
		expect(byKey.Thumbstick2.Scale).toBe(0.5)
		expect(byKey.TouchDelta.Scale).toBe(1)
		Fixtures.expectNear2(byKey.MouseDelta.Vector2Scale, Vector2.new(math.rad(0.5), -math.rad(0.385)), EXACT)
		Fixtures.expectNear2(byKey.Thumbstick2.Vector2Scale, Vector2.new(math.rad(240), math.rad(185)), EXACT)
		Fixtures.expectNear2(byKey.TouchDelta.Vector2Scale, Vector2.new(math.rad(1), -math.rad(0.66)), EXACT)
		-- The same settings again change nothing; the defaults bring the defaults back.
		InputController:setLookSettings(2, 0.5, true)
		Fixtures.expectNear2(byKey.MouseDelta.Vector2Scale, Vector2.new(math.rad(0.5), -math.rad(0.385)), EXACT)
		InputController:setLookSettings(1, 1, false)
		expect(byKey.MouseDelta.Scale).toBe(1)
		Fixtures.expectNear2(byKey.MouseDelta.Vector2Scale, Vector2.new(math.rad(0.5), math.rad(0.385)), EXACT)

		-- Each read follows the settings as the player changes them.
		local mouse = 1
		InputController:destroy()
		InputController:init({
			Config = Fixtures.config(),
			Parent = folder,
			LookSettings = function(): (number, number, boolean)
				return mouse, 1, false
			end,
		})
		mouse = 3
		InputController:readCamera(InputController.newCameraKeys())
		expect(lookBindings().MouseDelta.Scale).toBe(3)
	end)

	it("reads the look and Ball Focus once per step", function()
		local context = InputController.context
		local look = Fixtures.scriptedBinding(context, "Look")
		local focus = Fixtures.scriptedBinding(context, "BallFocus")
		local keys = InputController.newCameraKeys()
		look:Fire(Vector2.new(2, -1))
		InputController:readCamera(keys)
		Fixtures.expectNear2(keys.look, Vector2.new(2, -1), EXACT)
		focus:Fire(true)
		task.wait() -- Pressed is deferred
		InputController:readCamera(keys)
		expect(keys.ballFocus).toBe(true)
		expect(keys.ballFocusPressed).toBe(true)
		InputController:readCamera(keys)
		expect(keys.ballFocus).toBe(true)
		expect(keys.ballFocusPressed).toBe(false)
		focus:Fire(false)
		InputController:readCamera(keys)
		expect(keys.ballFocus).toBe(false)
	end)

	it("moves with the touch stick, and makes a stick pad the touch's modifier", function()
		local pad = Instance.new("ImageButton")
		pad.Parent = folder
		local action = InputController:bindTouchStick(pad)
		expect(action.Name).toBe("TouchMove")
		expect(action.Type).toBe(Enum.InputActionType.ViewportPosition)
		local binding = action:FindFirstChildOfClass("InputBinding") :: InputBinding
		expect(binding.KeyCode).toBe(Enum.KeyCode.TouchPosition)
		expect(binding.UIModifier == pad).toBe(true)
		local keys = InputController.newKeys()
		InputController:setStick(Vector2.new(0, 1))
		InputController:read(keys)
		Fixtures.expectNear2(keys.move, Vector2.new(0, 1), EXACT)
		InputController:setStick(Vector2.zero)
		InputController:read(keys)
		Fixtures.expectNear2(keys.move, Vector2.zero, EXACT)
	end)

	it("binds a touch button to its control", function()
		local jump = Instance.new("TextButton")
		jump.Parent = folder
		local focus = Instance.new("TextButton")
		focus.Parent = folder
		InputController:bindButton("jump", jump)
		InputController:bindButton("ballFocus", focus)
		local function boundTo(actionName: string, button: GuiButton): boolean
			for _, child in (InputController.context:FindFirstChild(actionName) :: InputAction):GetChildren() do
				if (child :: InputBinding).UIButton == button then
					return true
				end
			end
			return false
		end
		expect(boundTo("Jump", jump)).toBe(true)
		expect(boundTo("BallFocus", focus)).toBe(true)
		expect(boundTo("Jump", focus)).toBe(false)
	end)

	it("stops every key while Roblox's menu is open, and lets go of every hold", function()
		InputController:destroy()
		local menu = { MenuOpened = Signal.new(), MenuClosed = Signal.new() }
		InputController:init({
			Config = Fixtures.config(),
			Parent = folder,
			LookSettings = defaultLookSettings,
			GuiService = menu,
		})
		local context = InputController.context
		local pump = Fixtures.scriptedBinding(context, "Pump")
		local tackle = Fixtures.scriptedBinding(context, "Tackle")
		local keys, actions = InputController.newKeys(), InputController.newActionKeys()
		pump:Fire(true)
		menu.MenuOpened:Fire()
		InputController:read(keys)
		expect(keys.pump).toBe(false)
		tackle:Fire(true)
		task.wait() -- Pressed is deferred
		InputController:readActions(actions)
		expect(actions.tackle).toBe(false)
		tackle:Fire(false)

		menu.MenuClosed:Fire()
		pump:Fire(false)
		pump:Fire(true)
		InputController:read(keys)
		expect(keys.pump).toBe(true)
	end)

	it("starts paused when Roblox's menu is already open", function()
		InputController:destroy()
		local menu = { MenuOpened = Signal.new(), MenuClosed = Signal.new(), MenuIsOpen = true }
		InputController:init({
			Config = Fixtures.config(),
			Parent = folder,
			LookSettings = defaultLookSettings,
			GuiService = menu,
		})
		expect(InputController.paused).toBe(true)
		expect(InputController.context.Enabled).toBe(false)
		menu.MenuClosed:Fire()
		expect(InputController.paused).toBe(false)
		expect(InputController.context.Enabled).toBe(true)
	end)
end)
