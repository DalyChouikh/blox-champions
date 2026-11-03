--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ActionController = require(Client.ActionController)
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local BallCarrier = require(Client.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Hud = require(Client.Hud)
local HudStore = require(Client.HudStore)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local InputController = require(Client.InputController)
local SkateController = require(Client.SkateController)

local config = Config.defaults()
local LOCAL_ID = "1"
local DT = 1 / 60

local PHONE, BIG = Fixtures.PHONE, Fixtures.BIG_SCREEN

local folder: Folder
-- The other skaters the skating sees, reset before each test.
local skaters: { any }
local preferred: Enum.PreferredInput
local screen: Fixtures.Screen
-- The Switch team requests the Hud sent.
local switches = 0

-- A gamepad's button, D-pad or stick: Roblox names each by its KeyCode and gives it a glyph (probed).
local function gamepadKey(name: string): boolean
	return string.sub(name, 1, 6) == "Button"
		or string.sub(name, 1, 4) == "DPad"
		or string.sub(name, 1, 10) == "Thumbstick"
end

-- Roblox's key names, as GetStringForKeyCode gives them: a letter key its letter, Space a space, a gamepad's button or
-- stick its KeyCode's name, and nothing for Shift, Ctrl, Tab or a mouse button.
local function keyString(key: Enum.KeyCode): string
	local name = key.Name
	if key == Enum.KeyCode.Space then
		return " "
	elseif #name == 1 or gamepadKey(name) then
		return name
	end
	return ""
end

-- Roblox's glyphs, as GetImageForKeyCode gives them: one for each gamepad button and stick, none for other keys.
local function keyImage(key: Enum.KeyCode): string
	local name = key.Name
	return if gamepadKey(name) then `rbxasset://textures/ui/Controls/DefaultController/{name}@2x.png` else ""
end

-- The HUD's part called `name`, wherever it sits (the reticle in the full-screen gui, the scoreboard in the safe
-- area's); nil while it is not drawn.
local function part(name: string): any
	return Hud.gui:FindFirstChild(name, true)
		or Hud.centre:FindFirstChild(name, true)
		or Hud.top:FindFirstChild(name, true)
end

-- Ends the match as the server's MatchEnded does: Blue wins, Ana the MVP.
local function endMatch()
	local stats = (HudStore.state.match :: any).stats
	HudStore:onEvents(Fixtures.ruleEvents({ { name = "MatchEnded", winner = "Blue", mvp = "1", stats = stats } }))
end

-- A hint row's parts (#354, look C): the row, its fading group, its key's slot, cap face and legend, its label and
-- its mark.
local function hint(control: string): any
	local row = part("ControlHints"):FindFirstChild(control)
	local line = row.Group.Line
	local slot = line:FindFirstChild("Key") or line:FindFirstChild("Glyph")
	return {
		row = row,
		group = row.Group,
		slot = slot,
		face = slot.Face,
		legend = slot.Face.Legend,
		label = line.Label,
		mark = row.Mark,
	}
end

-- Which button a hint row's key cap inks on its mouse (#354, Q207): "Left" or "Right"; nil for a key with none.
local function mouseButton(control: string): string?
	local mouse: any = hint(control).face:FindFirstChild("Mouse")
	if mouse == nil then
		return nil
	end
	return if mouse.Body.Button.Position.X.Scale == 0 then "Left" else "Right"
end

-- The key a hint row shows: its cap's legend, or its glyph.
local function hintKey(control: string): (string?, string?)
	local parts = hint(control)
	local keyboard = parts.slot.Name == "Key"
	return if keyboard then parts.legend.Text else nil, if keyboard then nil else parts.face.Image
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "HudTest"
	folder.Parent = workspace
	preferred = Enum.PreferredInput.KeyboardAndMouse
	screen = PHONE
	switches = 0
	skaters = {}
	Fixtures.startSkating(folder, config, LOCAL_ID, skaters)
	HudStore:init({ Config = config, LocalId = LOCAL_ID })
	HudStore:onSnapshot(Fixtures.matchSnapshot())
	Hud:init({
		Config = config,
		HudStore = HudStore,
		InputController = InputController,
		SkateController = SkateController,
		ActionController = ActionController,
		BallCarrier = BallCarrier,
		Parent = folder,
		LocalId = LOCAL_ID,
		PreferredInput = function(): Enum.PreferredInput
			return preferred
		end,
		KeyString = keyString,
		KeyImage = keyImage,
		SendSwitchTeam = function()
			switches += 1
		end,
		-- The whole screen only for the crosshair's aim: a notched phone's reaches past its safe area, where Roblox's
		-- top bar and our scoreboard are (probed).
		InsetArea = function(insets: Enum.ScreenInsets): Rect
			if insets == Enum.ScreenInsets.CoreUISafeInsets then
				return screen.hud
			elseif insets == Enum.ScreenInsets.None then
				return screen.whole
			end
			expect(insets).toBe(Enum.ScreenInsets.DeviceSafeInsets)
			return screen.controls
		end,
		TopbarInset = function(): Rect
			return screen.topbar
		end,
	})
end)

afterEach(function()
	Hud:destroy()
	InputController:destroy()
	folder:Destroy()
end)

describe("Hud", function()
	it("renders the HUD into its own ScreenGuis, the reticle's spanning the whole screen", function()
		local gui = Hud.gui
		expect(gui.Name).toBe("Hud")
		expect(gui.ResetOnSpawn).toBe(false)
		expect(gui.ScreenInsets).toBe(Enum.ScreenInsets.CoreUISafeInsets)
		expect(gui.Parent == folder).toBe(true)
		Hud:step(0)
		local root = gui:FindFirstChild("Root")
		expect(root ~= nil and root.ClassName).toBe("Frame")
		-- Below the top bar the HUD's centre is not the screen's: the reticle has a gui without insets.
		local centre = Hud.centre
		expect(centre.Name).toBe("HudCentre")
		expect(centre.ResetOnSpawn).toBe(false)
		expect(centre.ScreenInsets).toBe(Enum.ScreenInsets.None)
		expect(centre.ZIndexBehavior).toBe(Enum.ZIndexBehavior.Sibling)
		expect(centre.Parent == folder).toBe(true)
		expect(centre:FindFirstChild("Reticle") ~= nil).toBe(true)
		-- The scoreboard is drawn from the top of the device's safe area, the frame GuiService.TopbarInset is measured
		-- in, so it can sit in the top bar's band beside Roblox's buttons (#352).
		local top = Hud.top
		expect(top.Name).toBe("HudTop")
		expect(top.ResetOnSpawn).toBe(false)
		expect(top.ScreenInsets).toBe(Enum.ScreenInsets.DeviceSafeInsets)
		expect(top.ZIndexBehavior).toBe(Enum.ZIndexBehavior.Sibling)
		expect(top.Parent == folder).toBe(true)
		expect(top:FindFirstChild("Scoreboard") ~= nil).toBe(true)
		expect(centre:FindFirstChild("Scoreboard")).toBeNil()
	end)

	-- One rule for every part (#352): a phone's screen by size (HudScreen.compact), S5 there and S2 elsewhere.
	it(
		"draws the phone's scoreboard on a phone's screen and the desktop's on a big one, rendering on a change",
		function()
			Hud:step(0)
			expect(part("BlueChip") ~= nil and part("BlueShield") == nil).toBe(true)
			local renders = Hud.renders
			screen = BIG
			Hud:resize()
			Hud:step(0)
			expect(part("BlueShield") ~= nil and part("BlueChip") == nil).toBe(true)
			expect(Hud.renders).toBe(renders + 1)
			Hud:step(0)
			expect(Hud.renders).toBe(renders + 1)
		end
	)

	it("tells a phone by the device's safe area, Roblox's top bar included", function()
		-- 900 x 520 with the bar, 900 x 462 under it: not a phone's (shorter side 500 or more).
		local safe = Rect.new(0, -58, 900, 462)
		screen = { whole = safe, hud = Rect.new(0, 0, 900, 462), controls = safe, topbar = BIG.topbar }
		Hud:resize()
		Hud:step(0)
		expect(part("BlueShield") ~= nil).toBe(true)
	end)

	it("puts the scoreboard in the top bar's band, and under the bar where Roblox's buttons reach it", function()
		screen = BIG
		Hud:resize()
		Hud:step(0)
		local board = part("Scoreboard") :: Frame
		expect(board.Position.Y.Offset).toBe(config.UI.hud.layout.scoreboard.position.Y.Offset)
		-- Buttons reaching 700 px in: the desktop board (640 +- 166) would cover them.
		screen = { whole = BIG.whole, hud = BIG.hud, controls = BIG.controls, topbar = Rect.new(700, 0, 1280, 58) }
		Hud:resize()
		Hud:step(0)
		expect(board.Position.Y.Offset).toBe(58 + config.UI.hud.layout.scoreboard.position.Y.Offset)
	end)

	-- A notched phone's whole screen reaches past its safe area, where Roblox's top bar and the touch controls are:
	-- the screen's form and the scoreboard's place come from the safe area alone (#352).
	it("decides a phone's screen and the scoreboard's place from the safe area, never the whole screen", function()
		-- 480 px tall inside a whole screen 520 tall: a phone's.
		local safe = Rect.new(0, -38, 1000, 442)
		screen = {
			whole = Rect.new(0, -58, 1000, 462),
			hud = Rect.new(0, 0, 1000, 442),
			controls = safe,
			topbar = BIG.topbar,
		}
		Hud:resize()
		Hud:step(0)
		expect(part("BlueChip") ~= nil).toBe(true)
		-- Roblox's buttons reaching 226 px into the phone's safe area: S5 centred on 375 reaches 156 either side, so it
		-- goes under the bar (centred on the whole screen's 437 it would clear them).
		screen = { whole = PHONE.whole, hud = PHONE.hud, controls = PHONE.controls, topbar = Rect.new(226, 0, 750, 58) }
		Hud:resize()
		Hud:step(0)
		expect(part("Scoreboard").Position.Y.Offset).toBe(58 + config.UI.hud.layout.compactScoreboard.position.Y.Offset)
	end)

	it("moves the scoreboard without rendering again: a score's bounce, a lap chip filling", function()
		screen = BIG
		Hud:resize()
		HudStore:onSnapshot(Fixtures.matchSnapshot({ possessingTeam = "Blue", lapProgress = 1 }, 1))
		Hud:step(0)
		local renders = Hud.renders
		HudStore:onSnapshot(
			Fixtures.matchSnapshot({ possessingTeam = "Blue", lapProgress = 2, scores = { Blue = 1, Orange = 0 } }, 2)
		)
		Hud:step(0)
		expect(Hud.renders).toBe(renders + 1)
		local bounce = part("BlueScore"):FindFirstChildOfClass("UIScale") :: UIScale
		local chip = (part("LapChips"):FindFirstChild("2") :: Instance):FindFirstChild("Grow", true) :: UIScale
		Hud:step(config.UI.hud.motion.bounce.seconds / 3)
		expect(bounce.Scale).toBeCloseTo(config.UI.hud.motion.bounce.scale, 4)
		expect(chip.Scale > 0).toBe(true)
		Hud:step(1)
		expect(bounce.Scale).toBe(1)
		expect(chip.Scale).toBe(1)
		expect(Hud.renders).toBe(renders + 1)
	end)

	it("renders again only when what it shows changes", function()
		Hud:step(0)
		Hud:step(0)
		expect(Hud.renders).toBe(1)
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } }))
		Hud:step(0)
		expect(Hud.renders).toBe(2)
		preferred = Enum.PreferredInput.Gamepad
		Hud:step(0)
		expect(Hud.renders).toBe(3)
		BallCarrier:set("1")
		Hud:step(0)
		expect(Hud.renders).toBe(4)
		Fixtures.spawnSkater(folder, config)
		Hud:step(0)
		expect(Hud.renders).toBe(5)
		Hud:step(0)
		expect(Hud.renders).toBe(5)
	end)

	it("shows the banner and the feed from the HUD's state", function()
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } }))
		Hud:step(0)
		local banner = part("Banner") :: Frame
		expect(banner.Visible).toBe(true)
		expect((banner:FindFirstChild("Front", true) :: TextLabel).Text).toBe("GOAL!")
		local feed = part("Feed") :: Frame
		expect((feed:FindFirstChild("1") :: TextLabel).Text).toBe("Ana scored!")
	end)

	-- One banner line under the scoreboard, the goal message at the stage's bottom (#356, the owner's Q210, Q211):
	-- on this phone the stage starts 58 px under the safe area's top, below Roblox's top bar.
	it("puts the banner line under the scoreboard and the goal message at the bottom, popping each in", function()
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "LapCompleted", team = "Blue", streak = 1, holder = "1" } }))
		Hud:step(0)
		local banner = part("Banner") :: Frame
		local at = HudScreen.bannerAt(config, PHONE.whole, PHONE.controls)
		local line = HudScreen.bannerLine(config, true, at, 8, false, HudScreen.bannerSize(config, true, "Lap"))
		expect(banner.Position).toEqual(UDim2.new(0.5, 0, 0, line - 58))
		expect((banner:FindFirstChild("Front", true) :: TextLabel).Text).toBe("LAP 1 COMPLETED")
		local pop = banner:FindFirstChild("Pop", true) :: UIScale
		expect(pop.Scale < 0.01).toBe(true)
		Hud:step(config.UI.hud.motion.pop.seconds)
		expect(pop.Scale).toBe(1)
		-- Then the goal opens: the message pops in on its own line, the lap's stays as it is.
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "GoalOpened", team = "Blue" } }, 2))
		Hud:step(0)
		local message = part("Message") :: Frame
		expect(message.Visible).toBe(true)
		expect(message.Position).toEqual(UDim2.new(0.5, 0, 1, -HudScreen.messageBottom(config, true)))
		expect((message:FindFirstChild("Front", true) :: TextLabel).Text).toBe("BLUE GOAL IS ACTIVE!")
		expect((message:FindFirstChild("Pop", true) :: UIScale).Scale < 0.01).toBe(true)
		expect(pop.Scale).toBe(1)
		-- The lap's last moments: it fades as it leaves; the message, shown longer, stays whole.
		HudStore:step(config.UI.hud.bannerSeconds.lap - config.UI.hud.motion.easeSeconds / 2)
		Hud:step(0)
		local group = banner:FindFirstChild("Group") :: CanvasGroup
		expect(group.GroupTransparency).toBeCloseTo(0.875, 4)
		expect((message:FindFirstChild("Group") :: CanvasGroup).GroupTransparency).toBe(0)
	end)

	it("counts the clock down on the scoreboard without rendering again", function()
		Hud:step(0)
		local clock = part("Clock") :: TextLabel
		expect(clock.Text).toBe("2:00")
		HudStore:step(1)
		Hud:step(1)
		expect(clock.Text).toBe("1:59")
		expect(Hud.renders).toBe(1)
	end)

	it("shows control hints with a keyboard or a gamepad, none on touch or without a character", function()
		Hud:step(0)
		expect(part("ControlHints")).toBeNil()

		local rig = Fixtures.spawnSkater(folder, config)
		Hud:step(0)
		expect((hintKey("pump"))).toBe("Shift")
		expect((hintKey("jump"))).toBe("Space")
		expect((hintKey("tackle"))).toBe("E")
		expect(hint("tackle").label.Text).toBe(config.UI.controlLabels.Tackle)
		expect(part("ControlHints").attach.Visible).toBe(false)
		-- Without the ball the throw's row works Ball Focus, on its own key; with it, the throw's: the mouse's right
		-- button, then its left, each drawn as a mouse with that button inked (Q207).
		expect(mouseButton("throw")).toBe("Right")
		expect(mouseButton("tackle")).toBeNil()
		BallCarrier:set(LOCAL_ID)
		Hud:step(0)
		expect(mouseButton("throw")).toBe("Left")

		preferred = Enum.PreferredInput.Gamepad
		Hud:step(0)
		local _, glyph = hintKey("tackle")
		expect(glyph).toBe(keyImage(Enum.KeyCode.ButtonX))

		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		expect(part("ControlHints")).toBeNil()

		preferred = Enum.PreferredInput.KeyboardAndMouse
		rig:Destroy()
		Hud:step(0)
		expect(part("ControlHints")).toBeNil()
	end)

	-- Magnetic Pass (#315, the owner: Q103): RC fades the whole row with nobody in the aim (Video 34 at 43.0 s); ours
	-- by the HUD's dim, as the score tab's greyed Switch team (Q118), easing over easeSeconds (Q194).
	it("greys the Magnetic Pass hint with nobody in the aim, and lights it with a teammate there", function()
		local dim = config.UI.hud.dimTransparency
		local ease = config.UI.hud.motion.easeSeconds
		Fixtures.spawnSkater(folder, config)
		BallCarrier:set(LOCAL_ID)
		ActionController:step(DT)
		Hud:step(0)
		local pass = hint("pass")
		expect(pass.row.Visible).toBe(true)
		expect(pass.label.Text).toBe(config.UI.controlLabels.Pass)
		expect(pass.group.GroupTransparency).toBe(0)
		Hud:step(ease / 2)
		expect(pass.group.GroupTransparency).toBeCloseTo(dim * 0.875, 4)
		Hud:step(ease / 2)
		expect(pass.group.GroupTransparency).toBeCloseTo(dim, 4)
		expect(hint("throw").group.GroupTransparency).toBe(0)
		table.insert(
			skaters,
			(Fixtures.otherSkater(folder, "2", Vector3.new(0, config.Movement.hoverHeight, -40), "Blue"))
		)
		ActionController:step(DT)
		Hud:step(0)
		Hud:step(ease)
		expect(pass.group.GroupTransparency).toBe(0)
		-- A gamepad's row fades the same way.
		table.clear(skaters)
		ActionController:step(DT)
		preferred = Enum.PreferredInput.Gamepad
		Hud:step(0)
		Hud:step(ease)
		expect(hint("pass").group.GroupTransparency).toBeCloseTo(dim, 4)
	end)

	-- The owner (Q186): the key pressed pops with RC's >> beside it for the press's time (motion.press).
	it("pops the key pressed for the press's time, with its mark, the throw's row on Ball Focus's keys", function()
		local press = config.UI.hud.motion.press
		local look = config.UI.hud.look
		local context = InputController.context
		Fixtures.spawnSkater(folder, config)
		Hud:step(0)
		local pump = hint("pump")
		local scale = pump.face:FindFirstChildOfClass("UIScale") :: UIScale
		expect(pump.mark.Visible).toBe(false)
		Fixtures.scriptedBinding(context, "Pump"):Fire(true)
		task.wait() -- Pressed is deferred
		Hud:step(0)
		expect(pump.mark.Visible).toBe(true)
		expect(pump.face.BackgroundColor3 == look.pressed).toBe(true)
		Hud:step(press.seconds / 3)
		expect(scale.Scale).toBeCloseTo(press.scale, 4)
		Hud:step(press.seconds)
		expect(pump.mark.Visible).toBe(false)
		expect(scale.Scale).toBe(1)
		expect(pump.face.BackgroundColor3 == look.key).toBe(true)
		-- Without the ball the throw's row is Ball Focus's: its key pops it, the throw's own does not.
		Fixtures.scriptedBinding(context, "Throw"):Fire(true)
		task.wait()
		Hud:step(0)
		expect(hint("throw").mark.Visible).toBe(false)
		Fixtures.scriptedBinding(context, "BallFocus"):Fire(true)
		task.wait()
		Hud:step(0)
		expect(hint("throw").mark.Visible).toBe(true)
		-- Catching the ball gives the row the throw's keys: their earlier presses pop nothing.
		Hud:step(press.seconds)
		local throw = Fixtures.scriptedBinding(context, "Throw")
		throw:Fire(false)
		throw:Fire(true)
		task.wait()
		Hud:step(0)
		BallCarrier:set(LOCAL_ID)
		Hud:step(0)
		expect(hint("throw").mark.Visible).toBe(false)
	end)

	-- The owner (Q186): a key on cooldown fills back clockwise with the seconds left on it.
	it("writes a cooling key's seconds left on its cap and sweeps it back clockwise", function()
		Fixtures.spawnSkater(folder, config)
		Hud:step(0)
		local pass = hint("pass")
		local key = pass.legend.Text
		local right = pass.face.Sweep.Right.Ink.Step :: UIGradient
		expect(right.Rotation).toBeCloseTo(360, 3)
		local runner = ActionController.runner
		runner:start("CallPass", { hasBall = false, knockedDown = false })
		Hud:step(0)
		local whole = config.Actions.CallPass.cooldown
		expect(pass.legend.Text).toBe(string.format(config.UI.text.cooldown, whole))
		expect(right.Rotation).toBeCloseTo(180, 3)
		runner:step(whole / 5)
		Hud:step(0)
		expect(pass.legend.Text).toBe(string.format(config.UI.text.cooldown, whole * 4 / 5))
		expect(right.Rotation).toBeCloseTo(252, 3)
		runner:step(whole)
		Hud:step(0)
		expect(pass.legend.Text).toBe(key)
		expect(right.Rotation).toBeCloseTo(360, 3)
	end)

	-- The letter NameTags shows over a pass's target (#315; RC Video 34 at 41.6 s): the pass hint's own key, or on
	-- touch, where no key shows, the touch mark.
	it("names the pass key as the hints show it, for the mark over a pass's target", function()
		Hud:step(0)
		expect(Hud.passKey).toBeNil()
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		expect(Hud.passKey).toBeNil()
		preferred = Enum.PreferredInput.KeyboardAndMouse
		Fixtures.spawnSkater(folder, config)
		Hud:step(0)
		expect(Hud.passKey).toEqual({ text = "R" })
		preferred = Enum.PreferredInput.Gamepad
		Hud:step(0)
		expect(Hud.passKey).toEqual({ image = keyImage(Enum.KeyCode.ButtonY) })
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		expect(Hud.passKey).toEqual({ text = config.UI.text.touchPassTarget })
	end)

	-- Roller Champions' Get Up (#220): moving gets a knocked-down skater up sooner.
	it("shows a Get Up prompt with the device's movement keys only while the skater is knocked down", function()
		local rig = Fixtures.spawnSkater(folder, config)
		-- Down for `kind` (the server's KnockedDown), or up for nil.
		local function knockedDown(kind: string?)
			rig:SetAttribute(Attributes.KnockedDown, kind)
			SkateController:step(DT)
			Hud:step(0)
		end
		Hud:step(0)
		expect(part("GetUp")).toBeNil()
		knockedDown("Hit")
		local prompt = part("GetUp")
		expect(prompt.Label.Text).toBe(config.UI.controlLabels.GetUp)
		-- The default WASD composite, up, left, down, right, as the player's keyboard names them.
		local keys = { prompt.Key1.Text, prompt.Key2.Text, prompt.Key3.Text, prompt.Key4.Text }
		expect(keys).toEqual({ "W", "A", "S", "D" })
		preferred = Enum.PreferredInput.Gamepad
		Hud:step(0)
		expect(part("GetUp").Glyph1.Image).toBe(keyImage(Enum.KeyCode.Thumbstick1))
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		expect(part("GetUp").Key1.Text).toBe(config.UI.text.touchMove)

		knockedDown(nil)
		expect(part("GetUp")).toBeNil()
		knockedDown("Hit")
		expect(part("GetUp") ~= nil).toBe(true)
		-- A diver gets up when the slide stops, not by moving (#242): no prompt. A hard landing's knockdown has one.
		knockedDown(nil)
		knockedDown("Dive")
		expect(part("GetUp")).toBeNil()
		knockedDown("Fall")
		expect(part("GetUp") ~= nil).toBe(true)
		rig:Destroy()
		Hud:step(0)
		expect(part("GetUp")).toBeNil()
	end)

	it("shows the skater's speed in km/h as the speedometer reads it, eased, and none without a character", function()
		Hud:step(0)
		local speedometer = part("Speedometer") :: Frame
		local digits = speedometer:FindFirstChild("Speed") :: TextLabel
		expect(speedometer.Visible).toBe(false)
		local rig = Fixtures.spawnSkater(folder, config)
		local skater = SkateController.skater :: any
		skater.velocity = Vector3.new(0, 0, -100)
		-- A skater that appears reads its own speed at once, in the local player's team colour (Ana plays Blue).
		Hud:step(0)
		expect(speedometer.Visible).toBe(true)
		expect(digits.Text).toBe("120")
		expect(digits.TextColor3 == config.UI.hud.look.teamColors.Blue).toBe(true)
		-- Gone, then back at 25 studs/s: read at once again, not eased from the last skater's speed.
		rig:Destroy()
		Hud:step(1 / 60)
		Fixtures.spawnSkater(folder, config)
		skater = SkateController.skater :: any
		skater.velocity = Vector3.new(0, 0, -25)
		Hud:step(1 / 60)
		expect(digits.Text).toBe("30")
		skater.velocity = Vector3.new(0, 0, -100)
		Hud:step(10)
		expect(digits.Text).toBe("120")
		-- Jumping at 50 studs/s: 50 x 1.2 across the ground, not the 78 km/h of |(0, 60, -50)| x 1.2 (#233), eased
		-- toward it at 6 a second: a sixth of a second on, 50 + 50 / e = 68.39 studs/s, read 82 km/h.
		skater.mode = "Airborne"
		skater.velocity = Vector3.new(0, 60, -50)
		expect(config.UI.hud.motion.speedRate).toBe(6)
		Hud:step(1 / 6)
		expect(digits.Text).toBe("82")
		Hud:step(10)
		expect(digits.Text).toBe("60")
	end)

	it("opens the score tab while its key is held, and toggles it with the touch button", function()
		local held = Fixtures.scriptedBinding(InputController.context, "ScoreTab")
		Hud:step(0)
		expect(part("ScoreTab")).toBeNil()
		expect(part("ScoreButton")).toBeNil()
		held:Fire(true)
		Hud:step(0)
		expect(part("ScoreTab") ~= nil).toBe(true)
		held:Fire(false)
		Hud:step(0)
		expect(part("ScoreTab")).toBeNil()

		-- On touch a button toggles it (the button's Activated calls toggleScoreTab; a test cannot fire it).
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		expect((part("ScoreButton") :: TextButton).Selectable).toBe(false)
		Hud:toggleScoreTab()
		Hud:step(0)
		expect(part("ScoreTab") ~= nil).toBe(true)
		Hud:toggleScoreTab()
		Hud:step(0)
		expect(part("ScoreTab")).toBeNil()
		-- A toggle left on closes once the device stops being touch.
		Hud:toggleScoreTab()
		Hud:step(0)
		preferred = Enum.PreferredInput.KeyboardAndMouse
		Hud:step(0)
		expect(part("ScoreTab")).toBeNil()
		expect(part("ScoreButton")).toBeNil()
	end)

	-- The owner (Q104, Q117, #310): the open score tab offers Switch team with the device's key; the key (or a tap on
	-- touch) asks for a switch.
	it("offers Switch team on the open score tab with the device's key, and asks for a switch on it", function()
		local held = Fixtures.scriptedBinding(InputController.context, "ScoreTab")
		local press = Fixtures.scriptedBinding(InputController.context, "SwitchTeam")
		local function pressKey()
			press:Fire(true)
			task.wait() -- Pressed is deferred
			Hud:step(0)
			press:Fire(false)
		end
		-- With the tab closed, the key asks nothing.
		pressKey()
		expect(part("SwitchTeam")).toBeNil()
		expect(switches).toBe(0)
		held:Fire(true)
		Hud:step(0)
		local button = part("SwitchTeam") :: TextButton
		expect(button.Selectable).toBe(false)
		expect((button:FindFirstChild("Key") :: TextLabel).Text).toBe("T")
		expect((button:FindFirstChild("Label") :: TextLabel).Text).toBe(config.UI.text.switchTeam)
		pressKey()
		expect(switches).toBe(1)
		preferred = Enum.PreferredInput.Gamepad
		Hud:step(0)
		local glyph = part("SwitchTeam"):FindFirstChild("Glyph") :: ImageLabel
		expect(glyph.Image).toBe(keyImage(Enum.KeyCode.DPadUp))
		-- On touch it is tapped (its Activated calls switchTeam; a test cannot fire it), with no key shown.
		preferred = Enum.PreferredInput.Touch
		held:Fire(false)
		Hud:toggleScoreTab()
		Hud:step(0)
		expect(part("SwitchTeam"):FindFirstChild("Key")).toBeNil()
		Hud:switchTeam()
		expect(switches).toBe(2)
	end)

	-- The owner (Q104, Q118): greyed while a switch can't happen, and then it asks nothing.
	it("greys Switch team while the local player holds the ball or the other team is full", function()
		local dim = config.UI.hud.dimTransparency
		local function label(): TextLabel
			return part("SwitchTeam"):FindFirstChild("Label") :: TextLabel
		end
		Fixtures.scriptedBinding(InputController.context, "ScoreTab"):Fire(true)
		BallCarrier:set(LOCAL_ID)
		Hud:step(0)
		expect(label().TextTransparency).toBeCloseTo(dim, 5)
		expect((part("SwitchTeam"):FindFirstChild("Key") :: TextLabel).TextTransparency).toBeCloseTo(dim, 5)
		Hud:switchTeam()
		expect(switches).toBe(0)
		BallCarrier:set(nil)
		Hud:step(0)
		expect(label().TextTransparency).toBe(0)
		Hud:switchTeam()
		expect(switches).toBe(1)
		local players = { Fixtures.playerStats("1", "Blue") }
		for _, id in { "2", "3", "4" } do
			table.insert(players, Fixtures.playerStats(id, "Orange"))
		end
		local orangeFull = { scores = { Blue = 0, Orange = 0 }, players = players }
		HudStore:onSnapshot(Fixtures.matchSnapshot({ stats = orangeFull }, 1))
		Hud:step(0)
		expect(label().TextTransparency).toBeCloseTo(dim, 5)
		Hud:switchTeam()
		expect(switches).toBe(1)
	end)

	it("offers no Switch team over the end screen, nor to a player the match doesn't list", function()
		preferred = Enum.PreferredInput.Touch
		endMatch()
		Hud:step(0)
		Hud:toggleScoreTab()
		Hud:step(0)
		expect(part("ScoreTab") ~= nil).toBe(true)
		expect(part("SwitchTeam")).toBeNil()
		Hud:switchTeam()
		expect(switches).toBe(0)
		local others = { scores = { Blue = 0, Orange = 0 }, players = { Fixtures.playerStats("2", "Orange") } }
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", stats = others }, 2))
		Hud:step(0)
		Hud:toggleScoreTab()
		Hud:step(0)
		expect(part("ScoreTab") ~= nil).toBe(true)
		expect(part("SwitchTeam")).toBeNil()
		Hud:switchTeam()
		expect(switches).toBe(0)
	end)

	it("shows the end screen in place of the scoreboard once the match ends, until the next starts", function()
		endMatch()
		Hud:step(0)
		expect(part("EndScreen") ~= nil).toBe(true)
		expect(part("Scoreboard")).toBeNil()
		-- Its own score tab stands in for the held one.
		Fixtures.scriptedBinding(InputController.context, "ScoreTab"):Fire(true)
		Hud:step(0)
		expect(part("ScoreTab")).toBeNil()
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3 }))
		Hud:step(0)
		expect(part("EndScreen")).toBeNil()
		expect(part("Scoreboard") ~= nil).toBe(true)
	end)

	it("on touch, keeps the score button through the end screen and opens the full score tab over it", function()
		preferred = Enum.PreferredInput.Touch
		Hud:toggleScoreTab()
		Hud:step(0)
		expect(part("ScoreTab") ~= nil).toBe(true)
		-- The match ends: the tab toggled on before closes, the button stays, and the end screen has no full table.
		endMatch()
		Hud:step(0)
		expect(part("ScoreTab")).toBeNil()
		expect(part("ScoreButton") ~= nil).toBe(true)
		local endScreen = part("EndScreen") :: Frame
		expect(endScreen:FindFirstChild("Table")).toBeNil()
		-- A tap opens the full score tab over it.
		Hud:toggleScoreTab()
		Hud:step(0)
		expect(part("ScoreTab") ~= nil).toBe(true)
		expect((part("ScoreTab") :: Frame).ZIndex > endScreen.ZIndex).toBe(true)
		expect(part("EndScreen") ~= nil).toBe(true)
		-- The next match starts: the tab closes, so it never pops open then.
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3 }))
		Hud:step(0)
		expect(part("ScoreTab")).toBeNil()
		expect(part("EndScreen")).toBeNil()
		expect(part("ScoreButton") ~= nil).toBe(true)
	end)

	it("puts the big panels, the banner and the feed on a stage above the rest, left of the touch buttons", function()
		local function fit(panel: string): number
			return (part(panel):FindFirstChild("Fit") :: UIScale).Scale
		end
		Fixtures.scriptedBinding(InputController.context, "ScoreTab"):Fire(true)
		Hud:step(0)
		for _, name in { "Banner", "Feed", "ScoreTab" } do
			expect(`{name} in {part(name).Parent.Name}`).toBe(`{name} in Stage`)
		end
		-- The solid score tab and end screen cover the scoreboard, the hints and the speedometer.
		local stage = part("Stage") :: Frame
		for _, other in part("Root"):GetChildren() do
			if other ~= stage and other:IsA("GuiObject") then
				expect(`{other.Name} below: {other.ZIndex < stage.ZIndex}`).toBe(`{other.Name} below: true`)
			end
		end
		-- With a keyboard the stage is the whole HUD area: the tab's height decides, less a margin at each side.
		expect(part("Stage").Size).toEqual(UDim2.fromOffset(750, 323))
		expect(fit("ScoreTab")).toBeCloseTo(307 / 360, 4)
		-- On touch it ends where the buttons begin: (504 - 2 margins) / 640 for the tab; the banner fits as it is.
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		expect(part("Stage").Size).toEqual(UDim2.fromOffset(504, 323))
		expect(fit("ScoreTab")).toBeCloseTo(488 / 640, 4)
		expect(fit("Banner")).toBe(1)
		expect(fit("Feed")).toBe(1)
		-- The compact end screen is as tall as its parts, so its width decides: (504 - 2 margins) / 720.
		endMatch()
		Hud:step(0)
		expect(part("EndScreen").Parent.Name).toBe("Stage")
		expect(fit("EndScreen")).toBeCloseTo(488 / 720, 4)
	end)

	-- RC's way (the owner, Q185): nothing at the screen's centre without the ball.
	it("shows the reticle only while the local player holds the ball", function()
		local function reticle(): boolean
			return (Hud.centre:FindFirstChild("Reticle") :: Frame).Visible
		end
		Hud:step(0)
		expect(reticle()).toBe(false)
		BallCarrier:set(LOCAL_ID)
		Hud:step(0)
		expect(reticle()).toBe(true)
		-- In the local player's team colour (Ana plays Blue).
		local dot = (Hud.centre:FindFirstChild("Reticle") :: any).Dot :: Frame
		expect(dot.BackgroundColor3 == config.UI.hud.look.teamColors.Blue).toBe(true)
		BallCarrier:set("2")
		Hud:step(0)
		expect(reticle()).toBe(false)
		BallCarrier:set(nil)
		Hud:step(0)
		expect(reticle()).toBe(false)
	end)

	-- The phone emulator's frames (probed): the aim 0.315 of the whole 401 px screen down, 126.3 px, which is 106.3
	-- below the safe area's top; S5 hangs from 8 px under it, OVERTIME under its row to 72.5 px below its top (44 + 8
	-- + 18 + 2.5). That leaves 106.3 - 8 - 72.5 - 3 = 22.8 px for the 46 px charge ring's 25.5 px reach.
	it(
		"shrinks the rings on a phone while OVERTIME hangs under the scoreboard, measured on the whole screen",
		function()
			BallCarrier:set(LOCAL_ID)
			Hud:step(0)
			local fit = ((Hud.centre:FindFirstChild("Reticle") :: any).Rings :: Frame):FindFirstChildOfClass(
					"UIScale"
				) :: UIScale
			expect(fit.Scale).toBe(1)
			HudStore:onSnapshot(Fixtures.matchSnapshot({ period = "Overtime" }, 1))
			Hud:step(0)
			local aim = 0.315 * 401 - 20
			expect(fit.Scale).toBeCloseTo((aim - 8 - 72.5 - 3) / 25.5, 4)
			expect(fit.Scale).toBeCloseTo(HudScreen.ringScale(config, true, 8, aim, true), 6)
		end
	)

	-- At overtime's kickoff (a Last Chance equaliser) the 76 px count's ring reaches 40.5 px round its centre, but only
	-- 22.8 px clear the board: it sits 18 px lower (17.7, up to whole pixels; the owner, Q203); in regulation
	-- 106.3 - 8 - 51 - 3 = 44.3 px are clear and it sits a third down.
	it("draws the kickoff count a third down, moved down just enough where the scoreboard would touch it", function()
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3 }, 1))
		Hud:step(0)
		local count = Hud.centre:FindFirstChild("Countdown") :: Frame
		expect(count.Visible).toBe(true)
		expect((count:FindFirstChild("Digit", true) :: TextLabel).Text).toBe("3")
		expect(count.Position).toEqual(UDim2.fromScale(0.5, config.UI.hud.layout.reticle.height))
		expect((part("Banner") :: Frame).Visible).toBe(false)
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3, period = "Overtime" }, 2))
		Hud:step(0)
		expect(count.Position.Y.Scale).toBeCloseTo(config.UI.hud.layout.reticle.height, 6)
		expect(count.Position.Y.Offset).toBe(math.ceil(40.5 - (0.315 * 401 - 20 - 8 - 72.5 - 3)))
		-- Covered by the score tab: hidden, as the reticle is.
		Fixtures.scriptedBinding(InputController.context, "ScoreTab"):Fire(true)
		Hud:step(0)
		expect(count.Visible).toBe(false)
	end)

	it("measures the crosshair's aim again when the screen changes, rendering again", function()
		BallCarrier:set(LOCAL_ID)
		HudStore:onSnapshot(Fixtures.matchSnapshot({ period = "Overtime" }, 1))
		Hud:step(0)
		local renders = Hud.renders
		-- A taller whole screen round the same safe area: the aim moves down, the rings fit.
		screen =
			{ whole = Rect.new(-62, -78, 812, 400), hud = PHONE.hud, controls = PHONE.controls, topbar = PHONE.topbar }
		Hud:resize()
		Hud:step(0)
		expect(Hud.renders).toBe(renders + 1)
		local fit = ((Hud.centre:FindFirstChild("Reticle") :: any).Rings :: Frame):FindFirstChildOfClass(
				"UIScale"
			) :: UIScale
		expect(fit.Scale).toBe(1)
		Hud:step(0)
		expect(Hud.renders).toBe(renders + 1)
	end)

	-- The banner line is a share of the whole screen like the aim, but its own share; the stage starts under
	-- Roblox's top bar (#356).
	it("places the banner line again when only the line's height or the stage's top moves", function()
		screen = BIG
		Hud:resize()
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "ClockWarning", secondsLeft = 30 } }))
		Hud:step(0)
		local banner = part("Banner") :: Frame
		local size = HudScreen.bannerSize(config, false, "ClockWarning")
		local function line(whole: Rect): number
			return HudScreen.bannerLine(config, false, HudScreen.bannerAt(config, whole, BIG.controls), 8, false, size)
		end
		-- On this desktop 0.22 of the 800 px screen decides the headline's place: 176 px down the safe area.
		expect(banner.Position).toEqual(UDim2.new(0.5, 0, 0, line(BIG.whole) - 58))
		-- A whole screen grown 31.5 px up and 68.5 down round the same safe area: the aim (0.315 down) stays where it
		-- was; the line (0.22 down) moves up, to where the scoreboard's clearance holds it.
		local whole = Rect.new(0, -89.5, 1280, 810.5)
		screen = { whole = whole, hud = BIG.hud, controls = BIG.controls, topbar = BIG.topbar }
		Hud:resize()
		Hud:step(0)
		expect(line(whole) < line(BIG.whole)).toBe(true)
		expect(banner.Position).toEqual(UDim2.new(0.5, 0, 0, line(whole) - 58))
		-- The stage starting 10 px lower (a taller top bar over the same safe area): the line keeps its place on the
		-- screen, so it sits 10 px higher in the stage.
		screen = { whole = whole, hud = Rect.new(0, 10, 1280, 742), controls = BIG.controls, topbar = BIG.topbar }
		Hud:resize()
		Hud:step(0)
		expect(banner.Position).toEqual(UDim2.new(0.5, 0, 0, line(whole) - 68))
	end)

	it("hides the reticle while the score tab or the end screen shows", function()
		local function reticle(): boolean
			return (Hud.centre:FindFirstChild("Reticle") :: Frame).Visible
		end
		local held = Fixtures.scriptedBinding(InputController.context, "ScoreTab")
		BallCarrier:set(LOCAL_ID)
		Hud:step(0)
		expect(reticle()).toBe(true)
		held:Fire(true)
		Hud:step(0)
		expect(reticle()).toBe(false)
		held:Fire(false)
		Hud:step(0)
		expect(reticle()).toBe(true)
		endMatch()
		Hud:step(0)
		expect(reticle()).toBe(false)
	end)

	-- RC's crosshair (#312): the ring builds round the dot from the throw's press, through a binding.
	it("builds the reticle's ring while a throw charges, without rendering again", function()
		Fixtures.spawnSkater(folder, config)
		BallCarrier:set(LOCAL_ID)
		Hud:step(DT)
		local ring = (Hud.centre:FindFirstChild("Reticle") :: any).Rings.Charge :: Frame
		expect(ring.Visible).toBe(false)
		local renders = Hud.renders
		ActionController:step(DT) -- the throw key seen up while holding the ball
		Fixtures.scriptedBinding(InputController.context, "Throw"):Fire(true)
		ActionController:step(DT)
		Hud:step(DT)
		expect(ring.Visible).toBe(true)
		expect(Hud.renders).toBe(renders)
	end)

	it("measures the stage again when the device changes or the screen turns", function()
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		expect(part("Stage").Size).toEqual(UDim2.fromOffset(504, 323))
		-- A big screen: the buttons grow 1.5 times and reach 369 px in.
		screen = BIG
		Hud:resize()
		expect(part("Stage").Size).toEqual(UDim2.fromOffset(911, 742))
		preferred = Enum.PreferredInput.KeyboardAndMouse
		Hud:step(0)
		expect(part("Stage").Size).toEqual(UDim2.fromOffset(1280, 742))
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		expect(part("Stage").Size).toEqual(UDim2.fromOffset(911, 742))
	end)

	it("unmounts its React root when destroyed, the reticle with it", function()
		Hud:step(0)
		Hud:destroy()
		expect(Hud.gui:FindFirstChild("Root")).toBeNil()
		expect(Hud.centre:FindFirstChild("Reticle")).toBeNil()
	end)

	it("steps in under 0.1 ms", function()
		Fixtures.spawnSkater(folder, config)
		-- Untimed: the first render of any React root in a fresh module registry does one-time work (measured: a
		-- separate root rendered first halves the timed mean). The loop measures the frames after it.
		Hud:step(DT)
		local total = 0
		for step = 1, 600 do
			-- The ball changes hands every 100 steps.
			if step % 100 == 1 then
				BallCarrier:set(if BallCarrier.carrier == nil then LOCAL_ID else nil)
			end
			local started = os.clock()
			Hud:step(DT)
			total += os.clock() - started
		end
		expect(total / 600).toBeLessThan(0.0001)
	end)
end)
