--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ActionController = require(Client.ActionController)
local BallCarrier = require(Client.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local InputController = require(Client.InputController)
local RideSurfaces = require(Client.RideSurfaces)
local SkateController = require(Client.SkateController)
local SkaterBody = require(ServerScriptService.Server.SkaterBody)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)
local TouchControls = require(Client.TouchControls)

local config = Config.defaults()
local touch = config.Input.touch
local labels = config.UI.controlLabels
local style = config.UI.touchStyle
local movement = config.Movement
local DT = 1 / 60
local LOCAL_ID = "1"
-- Each touch button's control, and the input action it works.
local ACTIONS: { { control: Config.TouchControl, action: string } } = {
	{ control = "jump", action = "Jump" },
	{ control = "pump", action = "Pump" },
	{ control = "brake", action = "Brake" },
	{ control = "attach", action = "Attach" },
	{ control = "tackle", action = "Tackle" },
	{ control = "uppercut", action = "Uppercut" },
	{ control = "pass", action = "Pass" },
	{ control = "throw", action = "Throw" },
}

local folder: Folder
local preferred: Enum.PreferredInput
local screen: Vector2

-- Whether a binding of the input action `action` reads `button`.
local function bound(action: string, button: GuiButton): boolean
	for _, binding in (InputController.context:FindFirstChild(action) :: InputAction):GetChildren() do
		if binding:IsA("InputBinding") and binding.UIButton == button then
			return true
		end
	end
	return false
end

-- A touch on the stick pad, as Roblox reports it: its screen position, or (-1, -1) once it ends.
local function touchAt(binding: InputBinding, position: Vector2)
	binding:Fire(position)
	task.wait() -- StateChanged is deferred
end

local function move(): Vector2
	local keys = InputController.newKeys()
	InputController:read(keys)
	return keys.move
end

local function button(control: Config.TouchControl): TextButton
	return TouchControls.buttons[control]
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "TouchControlsTest"
	folder.Parent = workspace
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(400, 1, 400)
	floor.CFrame = CFrame.new(0, -0.5, 0)
	floor.Parent = folder
	floor:AddTag(Tags.RideSurface)
	preferred = Enum.PreferredInput.Touch
	screen = Vector2.new(800, 400)
	InputController:init({ Config = config, Parent = folder })
	BallCarrier:init({})
	RideSurfaces:init({})
	SkateController:init({
		Config = config,
		InputController = InputController,
		RideSurfaces = RideSurfaces,
		Camera = { CFrame = CFrame.lookAt(Vector3.new(0, 5, 10), Vector3.new(0, 5, 0)) },
		Skaters = function(): { any }
			return {}
		end,
		SendSkateState = function() end,
		Gravity = Fixtures.GRAVITY,
		Team = function(): string?
			return "Blue"
		end,
	})
	local rig = Fixtures.rig(folder, "Skater", CFrame.new(0, movement.hoverHeight, 0))
	SkaterBody.build(rig, movement)
	SkateController:bind(rig)
	ActionController:init({
		Config = config,
		InputController = InputController,
		BallCarrier = BallCarrier,
		SkateController = SkateController,
		Camera = { CFrame = CFrame.new() },
		SendRequest = function() end,
		LocalId = LOCAL_ID,
	})
	TouchControls:init({
		Config = config,
		InputController = InputController,
		ActionController = ActionController,
		SkateController = SkateController,
		Parent = folder,
		PreferredInput = function(): Enum.PreferredInput
			return preferred
		end,
		ScreenSize = function(): Vector2
			return screen
		end,
	})
end)

afterEach(function()
	InputController:destroy()
	folder:Destroy()
end)

describe("TouchControls", function()
	it("lays out a button for every control from Config.Input.touch", function()
		expect(TouchControls.gui.Name).toBe("TouchControls")
		expect(TouchControls.gui.ResetOnSpawn).toBe(false)
		for _, entry in ACTIONS do
			local made = button(entry.control)
			expect(made.Name).toBe(entry.control)
			expect(made.Position).toEqual(touch.buttons[entry.control])
			expect(made.Size).toEqual(touch.buttonSize)
			expect(made.AnchorPoint).toEqual(Vector2.new(0.5, 0.5))
			-- Short labels capped at textSize, long ones shrunk to fit inside the padding.
			expect(made.TextScaled).toBe(true)
			local cap = made:FindFirstChildOfClass("UITextSizeConstraint")
			expect(cap and cap.MaxTextSize).toBe(style.textSize)
			local padding = made:FindFirstChildOfClass("UIPadding")
			expect(padding and padding.PaddingLeft).toEqual(UDim.new(0, style.textPadding))
			expect(padding and padding.PaddingRight).toEqual(UDim.new(0, style.textPadding))
		end
		local pad = TouchControls.pad
		expect(pad.Size).toEqual(touch.stickArea)
		expect(pad.AnchorPoint).toEqual(Vector2.new(0, 1))
		expect(pad.Position).toEqual(UDim2.fromScale(0, 1))
		expect(pad.ImageTransparency).toBe(1)
		expect(pad.BackgroundTransparency).toBe(1)
	end)

	it("binds each button to its control, and the throw button to Ball Focus too", function()
		for _, entry in ACTIONS do
			expect(`{entry.action} {bound(entry.action, button(entry.control))}`).toBe(`{entry.action} true`)
		end
		expect(bound("BallFocus", button("throw"))).toBe(true)
	end)

	it("moves the skater with a touch that starts on the stick pad, and draws the stick there", function()
		local finger = Fixtures.scriptedBinding(InputController.context, "TouchMove")
		touchAt(finger, Vector2.new(100, 300))
		touchAt(finger, Vector2.new(100, 280))
		Fixtures.expectNear2(move(), Vector2.new(0, 1))
		expect(TouchControls.ring.Visible).toBe(true)
		expect(TouchControls.knob.Visible).toBe(true)
		expect(TouchControls.ring.Size).toEqual(UDim2.fromOffset(touch.stickRingSize, touch.stickRingSize))

		touchAt(finger, Vector2.new(-1, -1))
		Fixtures.expectNear2(move(), Vector2.zero)
		expect(TouchControls.ring.Visible).toBe(false)
		expect(TouchControls.knob.Visible).toBe(false)
	end)

	it("doubles the stick on a big screen, as Roblox's own stick does", function()
		screen = Vector2.new(1280, 800)
		local finger = Fixtures.scriptedBinding(InputController.context, "TouchMove")
		touchAt(finger, Vector2.new(100, 300))
		touchAt(finger, Vector2.new(100, 280))
		Fixtures.expectNear2(move(), Vector2.new(0, 0.5))
		local ring = touch.stickRingSize * touch.bigScreenScale
		expect(TouchControls.ring.Size).toEqual(UDim2.fromOffset(ring, ring))
	end)

	it("names and shows each button for what it does now", function()
		TouchControls:step(DT)
		expect(button("jump").Text).toBe(labels.Jump)
		expect(button("tackle").Text).toBe(labels.Tackle)
		expect(button("pass").Text).toBe(labels.CallPass)
		expect(button("throw").Text).toBe(labels.BallFocus)
		expect(button("uppercut").Visible).toBe(true)
		expect(button("attach").Visible).toBe(false)

		BallCarrier:set(LOCAL_ID)
		TouchControls:step(DT)
		expect(button("tackle").Text).toBe(labels.Dodge)
		expect(button("pass").Text).toBe(labels.Pass)
		expect(button("throw").Text).toBe(labels.ChargeThrow)
		expect(button("uppercut").Visible).toBe(false)

		-- Into the tackle's active phase, past its 0.05 s windup: the button would dive.
		BallCarrier:set(nil)
		local tackle = Fixtures.scriptedBinding(InputController.context, "Tackle")
		tackle:Fire(true)
		task.wait() -- Pressed is deferred
		tackle:Fire(false)
		for _ = 1, 5 do
			SkateController:step(DT)
			ActionController:step(DT)
		end
		TouchControls:step(DT)
		expect(button("tackle").Text).toBe(labels.Dive)

		SkateController.attachable = true
		TouchControls:step(DT)
		expect(button("attach").Visible).toBe(true)
	end)

	it("shows only on touch", function()
		TouchControls:step(DT)
		expect(TouchControls.gui.Enabled).toBe(true)
		preferred = Enum.PreferredInput.KeyboardAndMouse
		TouchControls:step(DT)
		expect(TouchControls.gui.Enabled).toBe(false)
		preferred = Enum.PreferredInput.Gamepad
		TouchControls:step(DT)
		expect(TouchControls.gui.Enabled).toBe(false)
	end)

	it("steps in under 0.1 ms", function()
		local total = 0
		for step = 1, 600 do
			-- The ball changes hands every 100 steps.
			if step % 100 == 1 then
				BallCarrier:set(if BallCarrier.carrier == nil then LOCAL_ID else nil)
			end
			local started = os.clock()
			TouchControls:step(DT)
			total += os.clock() - started
		end
		expect(total / 600).toBeLessThan(0.0001)
	end)
end)
