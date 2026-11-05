--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ActionController = require(Client.ActionController)
local BallCarrier = require(Client.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local InputController = require(Client.InputController)
local SkateController = require(Client.SkateController)
local TouchControls = require(Client.TouchControls)

local config = Config.defaults()
local touch = config.Input.touch
local style = config.UI.touchStyle
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
-- The other skaters the skating sees, reset before each test.
local others: { any }
local preferred: Enum.PreferredInput
local screen: Vector2
-- The camera as TouchControls reads it: whether Ball Focus is on.
local camera: { focusing: boolean }

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
	Fixtures.floor(folder)
	preferred = Enum.PreferredInput.Touch
	screen = Vector2.new(800, 400)
	camera = { focusing = false }
	others = {}
	Fixtures.startSkating(folder, config, LOCAL_ID, others)
	Fixtures.spawnSkater(folder, config)
	TouchControls:init({
		Config = config,
		InputController = InputController,
		ActionController = ActionController,
		SkateController = SkateController,
		CameraController = camera,
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
	-- The stick as Roblox's own, in the device's safe area; the buttons at the whole screen's corner, past it (#355,
	-- the owner's Q246, Q249), each an invisible hit area the Hud draws its look C face into (Hud/TouchButton).
	it("lays out the stick in the safe area and a hit button per control at the whole screen's corner", function()
		local gui, buttons = TouchControls.gui, TouchControls.buttonGui
		expect(gui.Name).toBe("TouchControls")
		expect(gui.ResetOnSpawn).toBe(false)
		expect(gui.ScreenInsets).toBe(Enum.ScreenInsets.DeviceSafeInsets)
		expect(TouchControls.pad.Parent == gui).toBe(true)
		expect(buttons.Name).toBe("TouchButtons")
		expect(buttons.ResetOnSpawn).toBe(false)
		expect(buttons.ScreenInsets).toBe(Enum.ScreenInsets.None)
		expect(buttons.ClipToDeviceSafeArea).toBe(false)
		expect(buttons.ZIndexBehavior).toBe(Enum.ZIndexBehavior.Sibling)
		expect(buttons.Parent == folder).toBe(true)
		for _, entry in ACTIONS do
			local made = button(entry.control)
			local place = touch.buttons[entry.control]
			expect(made.Name).toBe(entry.control)
			expect(made.Parent == buttons).toBe(true)
			expect(made.Position).toEqual(place.place)
			expect(made.Size).toEqual(UDim2.fromOffset(place.size, place.size))
			expect(made.AnchorPoint).toEqual(Vector2.new(0.5, 0.5))
			expect((made:FindFirstChild("Grow") :: UIScale).Scale).toBe(1)
			-- Its face draws it: no background, no text, no tint of Roblox's own.
			expect(made.BackgroundTransparency).toBe(1)
			expect(made.Text).toBe("")
			expect(made.AutoButtonColor).toBe(false)
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
		expect(TouchControls.knob.BackgroundTransparency).toBe(style.knobTransparency)

		touchAt(finger, Vector2.new(-1, -1))
		Fixtures.expectNear2(move(), Vector2.zero)
		expect(TouchControls.ring.Visible).toBe(false)
		expect(TouchControls.knob.Visible).toBe(false)
	end)

	-- Each button grows whole by its UIScale, the face drawn into it too (ink and words).
	it("grows the stick and the buttons on a big screen, as Roblox's own controls do", function()
		screen = Vector2.new(1280, 800)
		TouchControls:layout()
		local grow = touch.bigScreenButtonScale
		local jump = touch.buttons.jump
		local place = jump.place
		expect((button("jump"):FindFirstChild("Grow") :: UIScale).Scale).toBe(grow)
		expect(button("jump").Size).toEqual(UDim2.fromOffset(jump.size, jump.size))
		expect(button("jump").Position).toEqual(
			UDim2.new(place.X.Scale, place.X.Offset * grow, place.Y.Scale, place.Y.Offset * grow)
		)
		local finger = Fixtures.scriptedBinding(InputController.context, "TouchMove")
		touchAt(finger, Vector2.new(100, 300))
		touchAt(finger, Vector2.new(100, 280))
		Fixtures.expectNear2(move(), Vector2.new(0, 0.5))
		local ring = touch.stickRingSize * touch.bigScreenStickScale
		expect(TouchControls.ring.Size).toEqual(UDim2.fromOffset(ring, ring))
		touchAt(finger, Vector2.new(-1, -1))

		-- Back on a phone-sized screen (a window resized, a device turned).
		screen = Vector2.new(800, 400)
		TouchControls:layout()
		expect((button("jump"):FindFirstChild("Grow") :: UIScale).Scale).toBe(1)
		expect(button("jump").Position).toEqual(place)
	end)

	it("lets go of the stick when the touch controls hide mid-touch", function()
		TouchControls:step(DT)
		local finger = Fixtures.scriptedBinding(InputController.context, "TouchMove")
		touchAt(finger, Vector2.new(100, 300))
		touchAt(finger, Vector2.new(100, 280))
		Fixtures.expectNear2(move(), Vector2.new(0, 1))
		-- A gamepad plugged in while the thumb is still down.
		preferred = Enum.PreferredInput.Gamepad
		TouchControls:step(DT)
		Fixtures.expectNear2(move(), Vector2.zero)
		expect(TouchControls.ring.Visible).toBe(false)
	end)

	-- What each button reads, and its greying, are its face's (the Hud's, Hud.spec): here, only whether it shows.
	it("shows each button only while its control has a label", function()
		TouchControls:step(DT)
		expect(button("jump").Visible).toBe(true)
		expect(button("uppercut").Visible).toBe(true)
		-- Attach with no teammate ahead.
		expect(button("attach").Visible).toBe(false)
		-- Roll Ball waits for a charge: the button stays, greyed by its face (#368, the owner's Q220).
		BallCarrier:set(LOCAL_ID)
		TouchControls:step(DT)
		expect(button("uppercut").Visible).toBe(true)
		SkateController.attachable = true
		TouchControls:step(DT)
		expect(button("attach").Visible).toBe(true)
		-- A spectator has no skater, and no buttons.
		SkateController.skater = nil
		TouchControls:step(DT)
		for _, entry in ACTIONS do
			expect(`{entry.control} {button(entry.control).Visible}`).toBe(`{entry.control} false`)
		end
	end)

	-- Over the button's face (drawn into it, under this ring), all round, its shadow too.
	it("rings the throw button while Ball Focus is on", function()
		TouchControls:step(DT)
		local ring = button("throw"):FindFirstChild("Focus") :: Frame
		expect(ring.Size).toEqual(UDim2.fromScale(1, 1))
		expect(ring.BackgroundTransparency).toBe(1)
		expect(ring.ZIndex).toBe(2)
		expect((ring:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(style.corner)
		local stroke = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Thickness).toBe(config.UI.hud.glowThickness)
		expect(stroke.Color == style.foreground).toBe(true)
		expect(ring.Visible).toBe(false)
		camera.focusing = true
		TouchControls:step(DT)
		expect(ring.Visible).toBe(true)
		camera.focusing = false
		TouchControls:step(DT)
		expect(ring.Visible).toBe(false)
	end)

	it("shows only on touch", function()
		TouchControls:step(DT)
		expect(TouchControls.gui.Enabled).toBe(true)
		expect(TouchControls.buttonGui.Enabled).toBe(true)
		preferred = Enum.PreferredInput.KeyboardAndMouse
		TouchControls:step(DT)
		expect(TouchControls.gui.Enabled).toBe(false)
		expect(TouchControls.buttonGui.Enabled).toBe(false)
		preferred = Enum.PreferredInput.Gamepad
		TouchControls:step(DT)
		expect(TouchControls.gui.Enabled).toBe(false)
		expect(TouchControls.buttonGui.Enabled).toBe(false)
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
