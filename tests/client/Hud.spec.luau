--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ActionController = require(Client.ActionController)
local ArenaParts = require(Client.ArenaParts)
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local BallCarrier = require(Client.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local ControlLabels = require(Client.ControlLabels)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Hud = require(Client.Hud)
local HudStore = require(Client.HudStore)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local InputController = require(Client.InputController)
local SkateController = require(Client.SkateController)
local Style = require(Client.Hud.Style)
local TouchArea = require(ReplicatedStorage.Shared.Input.TouchArea)

local config = Config.defaults()
local LOCAL_ID = "1"
local DT = 1 / 60

local PHONE, BIG = Fixtures.PHONE, Fixtures.BIG_SCREEN

local folder: Folder
-- The ball, where the fake camera puts it and every other point (the gates'), and the last other point it was asked
-- about: where the next gate's marker aims (#376).
type OnScreen = { point: Vector3, onScreen: boolean }
local ball: Part?
local ballScreen: OnScreen
local gateScreen: OnScreen
local gateAimed: Vector3?
local arena: Fixtures.HudArena
-- The other skaters the skating sees, reset before each test.
local skaters: { any }
local preferred: Enum.PreferredInput
local screen: Fixtures.Screen
-- The Switch team requests the Hud sent.
local switches = 0
-- The fonts the Hud asked to load, and what it asked to be called once they have (deps.LoadFonts).
local loadingFonts: { Font } = {}
local fontsLoaded = function() end
-- The touch controls' hit buttons, which the Hud draws each face into (TouchControls.buttons, #355).
local touchButtons: { [string]: TextButton }
-- The lines the Hud logged (deps.Log): a part hidden after its render threw (#379).
local logged: { string }

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

-- A touch button's look C face (#355), drawn into its hit button; nil while none is drawn.
local function face(control: string): any
	return touchButtons[control]:FindFirstChild("Face")
end

-- What a touch button's face reads: its seconds while it cools, else its words.
local function faceText(control: string): string
	local front = face(control)
	local seconds = front:FindFirstChild("Seconds", true) :: TextLabel
	return if seconds.Visible then seconds.Text else (front:FindFirstChild("Words", true) :: TextLabel).Text
end

local function near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 1e-3 and math.abs(a.G - b.G) < 1e-3 and math.abs(a.B - b.B) < 1e-3
end

-- Lets what is closing (the Get Up prompt, the score tab) fade out and go: the fade's time, then a step that renders
-- without it.
local function fadeOut()
	Hud:step(config.UI.hud.motion.easeSeconds)
	Hud:step(0)
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "HudTest"
	folder.Parent = workspace
	preferred = Enum.PreferredInput.KeyboardAndMouse
	screen = PHONE
	switches = 0
	skaters = {}
	logged = {}
	Fixtures.startSkating(folder, config, LOCAL_ID, skaters)
	local ballPart = Instance.new("Part")
	ballPart.Name = "Ball"
	ballPart.Anchored = true
	ballPart.Position = Vector3.new(0, 10, 0)
	ballPart.Parent = folder
	ball = ballPart
	ballScreen = { point = Vector3.new(300, 200, 10), onScreen = true }
	-- On the phone's screen, below the scoreboard and clear of every HUD part there.
	gateScreen = { point = Vector3.new(600, 200, 20), onScreen = true }
	gateAimed = nil
	arena = Fixtures.hudArena(folder)
	ArenaParts:init({})
	ArenaParts:refresh()
	touchButtons = {}
	for _, control: Config.TouchControl in ControlLabels.CONTROLS do
		local button = Instance.new("TextButton")
		button.Name = control
		button.Parent = folder
		touchButtons[control] = button
	end
	HudStore:init({ Config = config, LocalId = LOCAL_ID })
	HudStore:onSnapshot(Fixtures.matchSnapshot())
	Hud:init({
		Config = config,
		HudStore = HudStore,
		InputController = InputController,
		SkateController = SkateController,
		ActionController = ActionController,
		BallCarrier = BallCarrier,
		BallPart = {
			get = function(_self: any): BasePart?
				return ball
			end,
		},
		ArenaParts = ArenaParts,
		Project = function(position: Vector3): (Vector3, boolean)
			local current = ball
			if current ~= nil and position == current.Position then
				return ballScreen.point, ballScreen.onScreen
			end
			gateAimed = position
			return gateScreen.point, gateScreen.onScreen
		end,
		TouchControls = { buttons = touchButtons },
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
		LoadFonts = function(fonts: { Font }, loaded: () -> ())
			loadingFonts, fontsLoaded = fonts, loaded
		end,
		Log = function(line: string)
			table.insert(logged, line)
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
	ArenaParts:destroy()
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
		-- Over the touch controls' gui (Roblox's default order, 0), so the open TAB board covers their buttons (#357).
		for _, each in { gui, centre, top } do
			expect(`{each.Name} {each.DisplayOrder}`).toBe(`{each.Name} {config.UI.hud.displayOrder}`)
		end
		-- The end screen's dim: the whole screen, under the HUD's own guis, over the touch controls' and the
		-- markers' (0): level with them, which draws on top would be left to the engine.
		local dim = Hud.dim
		expect(dim.Name).toBe("HudDim")
		expect(dim.ResetOnSpawn).toBe(false)
		expect(dim.ScreenInsets).toBe(Enum.ScreenInsets.None)
		expect(dim.Parent == folder).toBe(true)
		expect(dim.DisplayOrder).toBe(config.UI.hud.displayOrder - 1)
		expect(dim.DisplayOrder > 0).toBe(true)
		-- None clipped to the device's safe area: SCORES lines up with the touch buttons past it (#355, Q250), and the
		-- dim covers the whole screen.
		for _, each in { gui, centre, top, dim } do
			expect(`{each.Name} {each.ClipToDeviceSafeArea}`).toBe(`{each.Name} false`)
		end
	end)

	-- One rule for every part (#352): a phone's screen by size (HudScreen.compact), S5 there and S2 elsewhere.
	it(
		"draws the phone's scoreboard on a phone's screen and the desktop's on a big one, rendering on a change",
		function()
			Hud:step(0)
			expect(part("BlueChip") ~= nil and part("BlueShield") == nil).toBe(true)
			-- Told to the name tags (#358), which draw at the screen's sizes too.
			expect(Hud.compact).toBe(true)
			local renders = Hud.renders
			screen = BIG
			Hud:resize()
			Hud:step(0)
			expect(part("BlueShield") ~= nil and part("BlueChip") == nil).toBe(true)
			expect(Hud.compact).toBe(false)
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

	-- A width measured before its font has loaded is the fallback font's, narrower (#364: Space's cap 52 px, not 59).
	it("measures its text again once look C's fonts have loaded, rendering again then", function()
		local look = config.UI.hud.look
		expect(loadingFonts).toEqual({ Font.fromEnum(look.font), Font.fromEnum(look.bannerFont) })
		Fixtures.spawnSkater(folder, config)
		Hud:step(0)
		Hud:step(0)
		expect(Hud.renders).toBe(1)
		local measured = Style.widths.measures
		fontsLoaded()
		-- Every hint's label and key were measured again, with the fonts in.
		Hud:step(0)
		expect(Hud.renders).toBe(2)
		expect(Style.widths.measures > measured).toBe(true)
		measured = Style.widths.measures
		Hud:step(0)
		expect(Hud.renders).toBe(2)
		expect(Style.widths.measures).toBe(measured)
	end)

	it("shows the banner and the feed from the HUD's state", function()
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } }))
		Hud:step(0)
		local banner = part("Banner") :: Frame
		expect(banner.Visible).toBe(true)
		expect((banner:FindFirstChild("Front", true) :: TextLabel).Text).toBe("GOAL!")
		local feed = part("Feed") :: Frame
		local line = feed:FindFirstChild("Label", true) :: TextLabel
		expect(string.find(line.Text, "Ana</font> scored!", 1, true) ~= nil).toBe(true)
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
		local group = banner:FindFirstChild("Group", true) :: CanvasGroup
		expect(group.GroupTransparency).toBeCloseTo(0.875, 4)
		expect((message:FindFirstChild("Group", true) :: CanvasGroup).GroupTransparency).toBe(0)
	end)

	-- #379 (the owner's Q242): in session 78 a probe's lap event with no streak broke the banner's render, and React
	-- took the whole HUD down with it until the next Play. Each part is behind its own error boundary now.
	it("keeps the rest of the HUD when one part's render throws, that part hidden until the next match", function()
		local function shown(): string
			local names: { string } = {}
			for _, name in { "Scoreboard", "Banner", "Message", "Feed", "ControlHints", "Speedometer" } do
				if part(name) ~= nil then
					table.insert(names, name)
				end
			end
			return table.concat(names, " ")
		end
		Fixtures.spawnSkater(folder, config)
		Hud:step(0)
		local noStreak = { name = "LapCompleted", team = "Blue", holder = "1" } :: any
		local reports = Fixtures.reactReports(function()
			HudStore:onEvents(Fixtures.ruleEvents({ noStreak }))
			Hud:step(DT)
			-- A ball line renders the HUD again: the banner stays hidden and is not tried again.
			HudStore:onEvents(Fixtures.ruleEvents({ { name = "PossessionChanged", team = "Blue", player = "1" } }, 2))
			Hud:step(DT)
			Hud:step(DT)
		end)
		expect(#reports).toBe(1)
		-- Logged once, naming the part, the error and where it was thrown.
		expect(#logged).toBe(1)
		local head = "[BloxChampions] Hud: Banner hidden until the next match: invalid argument #2 to 'format'"
		expect(string.sub(logged[1], 1, #head)).toBe(head)
		expect(string.find(logged[1], "Hud.HudText", 1, true) ~= nil).toBe(true)
		expect(shown()).toBe("Scoreboard Message Feed ControlHints Speedometer")
		expect(Hud.renders).toBe(3)
		endMatch()
		Hud:step(0)
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3 }, 3))
		Hud:step(0)
		expect(shown()).toBe("Scoreboard Banner Message Feed ControlHints Speedometer")
		HudStore:onEvents(
			Fixtures.ruleEvents({ { name = "LapCompleted", team = "Blue", streak = 1, holder = "1" } }, 4)
		)
		Hud:step(0)
		expect(((part("Banner") :: Frame):FindFirstChild("Front", true) :: TextLabel).Text).toBe("LAP 1 COMPLETED")
	end)

	-- App's own code is behind one too: there a throw hides the whole HUD, and the Hud keeps stepping.
	it("hides the whole HUD when its own render throws, still stepping, until the next match", function()
		preferred = Enum.PreferredInput.Touch
		-- A touch button TouchControls did not make: its face has nowhere to be drawn.
		local jump = touchButtons.jump
		touchButtons.jump = nil :: any
		local reports = Fixtures.reactReports(function()
			Hud:step(0)
			HudStore:onEvents(Fixtures.ruleEvents({ { name = "PossessionChanged", team = "Blue", player = "1" } }))
			Hud:step(DT)
		end)
		expect(#reports).toBe(1)
		local head = "[BloxChampions] Hud: App hidden until the next match: Target container is not a Roblox Instance."
		expect(#logged).toBe(1)
		expect(string.sub(logged[1], 1, #head)).toBe(head)
		expect(part("Speedometer")).toBeNil()
		expect(part("Scoreboard")).toBeNil()
		expect(Hud.renders).toBe(2)
		-- Mended, it waits for the next match: not over the end screen, but at the next kickoff.
		touchButtons.jump = jump
		endMatch()
		Hud:step(0)
		expect(part("EndScreen")).toBeNil()
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3 }, 2))
		Hud:step(0)
		expect(part("Scoreboard") ~= nil).toBe(true)
		expect(face("jump") ~= nil).toBe(true)
	end)

	-- A part on the screen from one match to the next, the kickoff's count, waits for the next match too.
	it("tries a broken part that stays on the screen again in the next match, not before", function()
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3 }))
		-- The count's text, broken for one render.
		local banner = HudText.banner
		HudText.banner = function(): string
			error("the count's text is broken", 0)
		end
		local ok = pcall(Fixtures.reactReports, function()
			Hud:step(0)
		end)
		HudText.banner = banner
		expect(ok).toBe(true)
		expect(part("Countdown")).toBeNil()
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "PossessionChanged", team = "Blue", player = "1" } }))
		Hud:step(0)
		expect(part("Countdown")).toBeNil()
		endMatch()
		Hud:step(0)
		expect(part("Countdown")).toBeNil()
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3 }, 2))
		Hud:step(0)
		expect(part("Countdown") ~= nil).toBe(true)
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
		-- A tap: pressed and let go before the next frame.
		local function tap(action: string)
			local key = Fixtures.scriptedBinding(context, action)
			key:Fire(true)
			key:Fire(false)
			task.wait() -- Pressed is deferred
		end
		tap("Pump")
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
		tap("Throw")
		Hud:step(0)
		expect(hint("throw").mark.Visible).toBe(false)
		tap("BallFocus")
		Hud:step(0)
		expect(hint("throw").mark.Visible).toBe(true)
		-- Catching the ball gives the row the throw's keys: their earlier presses pop nothing.
		Hud:step(press.seconds)
		tap("Throw")
		Hud:step(0)
		BallCarrier:set(LOCAL_ID)
		Hud:step(0)
		expect(hint("throw").mark.Visible).toBe(false)
	end)

	-- The owner (#367, Q219): every key shows pressed for as long as it is held; a tap still pops for the press's time.
	it("keeps a held key's row pressed, with its mark, until the key is let go", function()
		local press = config.UI.hud.motion.press
		local look = config.UI.hud.look
		Fixtures.spawnSkater(folder, config)
		Hud:step(0)
		local pump = hint("pump")
		local scale = pump.face:FindFirstChildOfClass("UIScale") :: UIScale
		local key = Fixtures.scriptedBinding(InputController.context, "Pump")
		key:Fire(true)
		task.wait() -- Pressed is deferred
		Hud:step(0)
		Hud:step(4 * press.seconds)
		-- The pop is over; the hold is not.
		expect(scale.Scale).toBe(1)
		expect(pump.mark.Visible).toBe(true)
		expect(pump.face.BackgroundColor3 == look.pressed).toBe(true)
		key:Fire(false)
		task.wait()
		Hud:step(0)
		expect(pump.mark.Visible).toBe(false)
		expect(pump.face.BackgroundColor3 == look.key).toBe(true)
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

	-- #355 (the owner's Q187, Q193, Q245): no hint column on touch; each button's look C face reads what its control
	-- does now, through the hint rows' own bindings, at its own size and words.
	it("draws each touch button's look C face into its button on touch, reading what its control does now", function()
		local labels, touch, style = config.UI.controlLabels, config.Input.touch, config.UI.touchStyle
		Fixtures.spawnSkater(folder, config)
		Hud:step(0)
		expect(face("jump")).toBeNil()
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		expect(part("ControlHints")).toBeNil()
		expect(faceText("jump")).toBe(labels.Jump)
		expect(faceText("pass")).toBe(labels.CallPass)
		expect(faceText("throw")).toBe(labels.BallFocus)
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			local button = touch.buttons[control]
			local front = face(control)
			local words = front:FindFirstChild("Words", true) :: TextLabel
			local fit = words:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
			expect(`{control} {fit.MaxTextSize}`).toBe(`{control} {button.textSize}`)
			-- Its fill inside its outline: the sweep's square.
			local inner = button.size - 2 * config.UI.hud.look.outline
			expect((front:FindFirstChild("Sweep", true) :: Frame).Size).toEqual(UDim2.fromOffset(inner, inner))
			-- Jump in its own orange, the rest in the buttons' fill.
			local fill = (front:FindFirstChild("Box", true) :: Frame):FindFirstChild("Fill1") :: Frame
			local keys = (fill:FindFirstChildOfClass("UIGradient") :: UIGradient).Color.Keypoints
			local gradient = if control == "jump" then style.jumpFill else style.fill
			expect(`{control} {near(keys[1].Value, gradient.top)}`).toBe(`{control} true`)
		end
		BallCarrier:set(LOCAL_ID)
		Hud:step(0)
		expect(faceText("pass")).toBe(labels.Pass)
		expect(faceText("throw")).toBe(labels.ChargeThrow)
		preferred = Enum.PreferredInput.KeyboardAndMouse
		Hud:step(0)
		expect(face("jump")).toBeNil()
	end)

	-- As the desktop's hints (the owner's Q186): a press pops, a cooling button shows its seconds, a greyed one fades.
	it("pops, cools and greys a touch button's face as its hint row would", function()
		local press = config.UI.hud.motion.press
		local cooldown = config.Actions.CallPass.cooldown
		preferred = Enum.PreferredInput.Touch
		Fixtures.spawnSkater(folder, config)
		Hud:step(0)
		local pump = face("pump")
		local pop = pump:FindFirstChildOfClass("UIScale") :: UIScale
		local pressed = pump:FindFirstChild("Pressed", true) :: Frame
		local key = Fixtures.scriptedBinding(InputController.context, "Pump")
		key:Fire(true)
		key:Fire(false)
		task.wait() -- Pressed is deferred
		Hud:step(0)
		expect(pressed.Visible).toBe(true)
		Hud:step(press.seconds / 3)
		expect(pop.Scale).toBeCloseTo(press.scale, 4)
		expect(pressed.Visible).toBe(true)
		Hud:step(press.seconds)
		expect(pop.Scale).toBe(1)
		expect(pressed.Visible).toBe(false)
		-- A call cools: its seconds stand in for its word.
		local runner = ActionController.runner
		runner:start("CallPass", { hasBall = false, knockedDown = false })
		Hud:step(0)
		expect(faceText("pass")).toBe(string.format(config.UI.text.cooldown, cooldown))
		runner:step(cooldown)
		Hud:step(0)
		expect(faceText("pass")).toBe(config.UI.controlLabels.CallPass)
		-- Magnetic Pass with nobody in the aim fades whole, at the HUD's dim.
		BallCarrier:set(LOCAL_ID)
		ActionController:step(DT)
		Hud:step(0)
		Hud:step(config.UI.hud.motion.easeSeconds)
		local group = face("pass"):FindFirstChild("Group") :: CanvasGroup
		expect(group.GroupTransparency).toBeCloseTo(config.UI.hud.dimTransparency, 4)
		expect((face("throw"):FindFirstChild("Group") :: CanvasGroup).GroupTransparency).toBe(0)
	end)

	-- S2 (#355, the owner's Q250): its right edge lined up with the touch buttons' (Jump's, 22 px from the whole
	-- screen's edge), 16 px under Roblox's top bar, in look C; a tap pops it.
	it("lines SCORES up with the touch buttons, under Roblox's top bar, in look C, popping when tapped", function()
		local press = config.UI.hud.motion.press
		local place = config.UI.hud.layout.scoreButton
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		local button = part("ScoreButton") :: TextButton
		expect(button.AnchorPoint).toEqual(Vector2.new(1, 0))
		-- This phone's whole screen ends 62 px right of the HUD's area: 812 - 22.
		expect(button.Position).toEqual(UDim2.fromOffset(790, place.top))
		expect(button.Position.X.Offset).toBe(TouchArea.lineUp(config.Input.touch, PHONE.hud, PHONE.whole))
		expect(button.Size).toEqual(place.size)
		expect(button.BackgroundTransparency).toBe(1)
		expect(button.Text).toBe("")
		-- Its face shows the press: no tint of Roblox's own.
		expect(button.AutoButtonColor).toBe(false)
		local front = button:FindFirstChild("Face") :: Frame
		local words = front:FindFirstChild("Words", true) :: TextLabel
		expect(words.Text).toBe(config.UI.text.scores)
		local fit = words:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
		expect(fit.MaxTextSize).toBe(place.textSize)
		local fill = (front:FindFirstChild("Box", true) :: Frame):FindFirstChild("Fill1") :: Frame
		expect((fill:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(place.corner)
		local keys = (fill:FindFirstChildOfClass("UIGradient") :: UIGradient).Color.Keypoints
		expect(near(keys[1].Value, config.UI.touchStyle.fill.top)).toBe(true)
		-- A tap pops it, pressed while it pops.
		local pop = front:FindFirstChildOfClass("UIScale") :: UIScale
		local pressed = front:FindFirstChild("Pressed", true) :: Frame
		Hud:toggleScoreTab()
		Hud:step(press.seconds / 3)
		expect(pop.Scale).toBeCloseTo(press.scale, 4)
		expect(pressed.Visible).toBe(true)
		Hud:step(press.seconds)
		expect(pop.Scale).toBe(1)
		expect(pressed.Visible).toBe(false)
		-- A big screen: the buttons grow, and SCORES follows their edge, 33 px in.
		screen = BIG
		Hud:resize()
		expect(button.Position).toEqual(UDim2.fromOffset(1247, place.top))
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

	-- The key NameTags shows with the word Attach over the teammate to attach behind (#381, the owner's Q246, Q247):
	-- the Attach hint's own key; on touch, where no key shows, none (the word stands alone).
	it("names the Attach key as the hints show it, for the mark over the teammate to attach behind", function()
		Hud:step(0)
		expect(Hud.attachKey).toBeNil()
		Fixtures.spawnSkater(folder, config)
		Hud:step(0)
		expect(Hud.attachKey).toEqual({ text = "F" })
		preferred = Enum.PreferredInput.Gamepad
		Hud:step(0)
		expect(Hud.attachKey).toEqual({ image = keyImage(Enum.KeyCode.ButtonL1) })
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		expect(Hud.attachKey).toBeNil()
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
		expect(prompt.Parent.Name).toBe("Stage")
		expect(prompt.Group.Front.Text).toBe(config.UI.controlLabels.GetUp)
		-- It pops in from nothing (the owner, Q221; a UIScale holds its smallest, 1e-7, for 0).
		expect(prompt.Group.Pop.Scale).toBeCloseTo(0, 4)
		Hud:step(config.UI.hud.motion.pop.seconds)
		expect(prompt.Group.Pop.Scale).toBe(1)
		-- The default WASD composite, up, left, down, right, as the player's keyboard names them.
		local caps = prompt.Group.Keys
		local keys = {
			caps.Key1.Face.Legend.Text,
			caps.Key2.Face.Legend.Text,
			caps.Key3.Face.Legend.Text,
			caps.Key4.Face.Legend.Text,
		}
		expect(keys).toEqual({ "W", "A", "S", "D" })
		preferred = Enum.PreferredInput.Gamepad
		Hud:step(0)
		expect(part("GetUp").Group.Keys.Glyph1.Face.Image).toBe(keyImage(Enum.KeyCode.Thumbstick1))
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		expect(part("GetUp").Group.Keys.Key1.Face.Legend.Text).toBe(config.UI.text.touchMove)

		-- Up: it fades out whole, keeps the keys while it does, then goes.
		knockedDown(nil)
		expect(part("GetUp").Group.GroupTransparency).toBe(0)
		Hud:step(config.UI.hud.motion.easeSeconds / 2)
		local fading = part("GetUp").Group.GroupTransparency
		expect(fading > 0 and fading < 1).toBe(true)
		expect(part("GetUp").Group.Keys.Key1.Face.Legend.Text).toBe(config.UI.text.touchMove)
		fadeOut()
		expect(part("GetUp")).toBeNil()
		knockedDown("Hit")
		expect(part("GetUp").Group.GroupTransparency).toBe(0)
		-- A diver gets up when the slide stops, not by moving (#242): no prompt. A hard landing's knockdown has one.
		knockedDown(nil)
		fadeOut()
		knockedDown("Dive")
		expect(part("GetUp")).toBeNil()
		knockedDown("Fall")
		expect(part("GetUp") ~= nil).toBe(true)
		rig:Destroy()
		Hud:step(0)
		fadeOut()
		expect(part("GetUp")).toBeNil()
	end)

	-- The prompt stands clear of the feed's lines, on this phone (#369): one line reaches past its place.
	it("raises the Get Up prompt over the feed's lines", function()
		local rig = Fixtures.spawnSkater(folder, config)
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		SkateController:step(DT)
		Hud:step(0)
		expect(part("GetUp").Position.Y.Offset).toBe(-HudScreen.getUpBottom(config, true, 0))
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "GoalScored", team = "Blue", scorer = "1", points = 1 } }))
		Hud:step(0)
		expect(HudStore.state.feed[1] ~= nil).toBe(true)
		expect(part("GetUp").Position.Y.Offset).toBe(-HudScreen.getUpBottom(config, true, 1))
		expect(HudScreen.getUpBottom(config, true, 1) > HudScreen.getUpBottom(config, true, 0)).toBe(true)
	end)

	-- Five lines pushed the prompt into the banner line on this phone (Q230): the feed's most no longer can, even under
	-- GOAL!, the tallest banner.
	it("keeps the Get Up prompt clear of the banner line at the feed's most lines, on this phone", function()
		preferred = Enum.PreferredInput.Touch
		local rig = Fixtures.spawnSkater(folder, config)
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		SkateController:step(DT)
		Hud:step(0)
		local scored: { any } = {}
		for _ = 1, config.UI.hud.feedMaxEntries do
			table.insert(scored, { name = "GoalScored", team = "Blue", scorer = "1", points = 1 })
		end
		HudStore:onEvents(Fixtures.ruleEvents(scored))
		Hud:step(0)
		expect(#HudStore.state.feed).toBe(config.UI.hud.feedMaxEntries)
		local prompt, banner = part("GetUp") :: Frame, part("Banner") :: Frame
		expect(banner.Visible).toBe(true)
		-- Both in the stage's pixels from its top.
		local promptTop = part("Stage").Size.Y.Offset + prompt.Position.Y.Offset - prompt.Size.Y.Offset
		local bannerBottom = banner.Position.Y.Offset + (1 - banner.AnchorPoint.Y) * banner.Size.Y.Offset
		expect(bannerBottom + config.UI.hud.layout.banner.clearance <= promptTop).toBe(true)
	end)

	-- A replaced ball line takes no row, so the prompt over the feed stays put as the carrier changes (the owner,
	-- Q227).
	it("does not move the Get Up prompt when a ball line is replaced", function()
		local rig = Fixtures.spawnSkater(folder, config)
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		SkateController:step(DT)
		Hud:step(0)
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "PossessionChanged", team = "Blue", player = "1" } }))
		Hud:step(0)
		local place = part("GetUp").Position
		HudStore:onEvents(Fixtures.ruleEvents({
			{ name = "PossessionChanged", team = "Orange", player = "1", previousTeam = "Blue" },
		}))
		Hud:step(0)
		expect(#HudStore.state.feed).toBe(2)
		expect(part("GetUp").Position).toEqual(place)
		expect(part("Feed").Size.Y.Offset).toBe(HudScreen.feedHeight(config, true, 1))
	end)

	-- The pop on the Hud's clock, the fade on the line's time left, as the banners'.
	it("pops a feed line in and fades it out through the Hud", function()
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "PossessionChanged", team = "Blue", player = "1" } }))
		Hud:step(0)
		local id = tostring(HudStore.state.feed[1].id)
		local group = part("Feed"):FindFirstChild(id).Group :: CanvasGroup
		local pop = group:FindFirstChild("Pop") :: UIScale
		expect(pop.Scale).toBeCloseTo(0, 4)
		Hud:step(config.UI.hud.motion.pop.seconds)
		expect(pop.Scale).toBe(1)
		expect(group.GroupTransparency).toBe(0)
		HudStore:step(config.UI.hud.feedSeconds - config.UI.hud.motion.easeSeconds / 2)
		Hud:step(0)
		expect(group.GroupTransparency > 0).toBe(true)
		HudStore:step(config.UI.hud.motion.easeSeconds)
		Hud:step(0)
		expect(part("Feed"):FindFirstChild(id)).toBeNil()
	end)

	-- The prompt's own spec holds the rule; this holds its wire to the stage the Hud measures.
	it("shrinks the Get Up prompt to fit a stage too narrow for it", function()
		local rig = Fixtures.spawnSkater(folder, config)
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		SkateController:step(DT)
		Hud:step(0)
		local fit = part("GetUp"):FindFirstChild("Fit") :: UIScale
		expect(fit.Scale).toBe(1)
		screen =
			{ whole = PHONE.whole, hud = Rect.new(0, 0, 200, 323), controls = PHONE.controls, topbar = PHONE.topbar }
		Hud:resize()
		expect(fit.Scale < 1).toBe(true)
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
		fadeOut()
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
		fadeOut()
		expect(part("ScoreTab")).toBeNil()
		-- A toggle left on closes once the device stops being touch.
		Hud:toggleScoreTab()
		Hud:step(0)
		preferred = Enum.PreferredInput.KeyboardAndMouse
		Hud:step(0)
		fadeOut()
		expect(part("ScoreTab")).toBeNil()
		expect(part("ScoreButton")).toBeNil()
	end)

	-- Every HUD change animates (the owner, Q194): the board pops in as it opens and fades out whole as it closes.
	it("pops the score tab in as it opens and fades it out whole as it closes, rendering only then", function()
		local held = Fixtures.scriptedBinding(InputController.context, "ScoreTab")
		Hud:step(0)
		local renders = Hud.renders
		held:Fire(true)
		Hud:step(0)
		expect(Hud.renders).toBe(renders + 1)
		local group = part("ScoreTab"):FindFirstChild("Group", true) :: CanvasGroup
		local pop = part("ScoreTab"):FindFirstChild("Pop", true) :: UIScale
		-- A UIScale holds its smallest, 1e-7, for 0.
		expect(pop.Scale).toBeCloseTo(0, 4)
		Hud:step(config.UI.hud.motion.pop.seconds)
		expect(pop.Scale).toBe(1)
		expect(Hud.renders).toBe(renders + 1)
		held:Fire(false)
		Hud:step(0)
		expect(group.GroupTransparency).toBe(0)
		Hud:step(config.UI.hud.motion.easeSeconds / 2)
		expect(group.GroupTransparency > 0 and group.GroupTransparency < 1).toBe(true)
		fadeOut()
		expect(part("ScoreTab")).toBeNil()
		expect(Hud.renders).toBe(renders + 3)
	end)

	-- The owner's Q235: the open board would cut them in half (Q230); they come back once it has gone, the chips' time
	-- counting on meanwhile, and moving still gets the skater up.
	it("hides the Get Up prompt and the feed's chips while the score tab shows, and brings them back after", function()
		local rig = Fixtures.spawnSkater(folder, config)
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		SkateController:step(DT)
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "PossessionChanged", team = "Blue", player = "1" } }))
		Hud:step(0)
		expect(part("GetUp") ~= nil and part("Feed") ~= nil).toBe(true)
		local held = Fixtures.scriptedBinding(InputController.context, "ScoreTab")
		held:Fire(true)
		Hud:step(0)
		expect(part("ScoreTab") ~= nil).toBe(true)
		expect(part("GetUp")).toBeNil()
		expect(part("Feed")).toBeNil()
		local left = HudStore.state.feed[1].timeLeft
		HudStore:step(1)
		expect(HudStore.state.feed[1].timeLeft).toBe(left - 1)
		-- Closed, they stay hidden while the board fades over their place, then come back.
		held:Fire(false)
		Hud:step(0)
		expect(part("GetUp")).toBeNil()
		fadeOut()
		expect(part("GetUp") ~= nil).toBe(true)
		expect(part("Feed"):FindFirstChild(tostring(HudStore.state.feed[1].id)) ~= nil).toBe(true)
	end)

	-- The owner's Q238: the open board cut them too (a phone's goal message under its edge, a desktop's banner at 5 a
	-- side); they hide while it shows and come back once it has gone, their time counting on meanwhile.
	it("hides the banner line and the goal message while the score tab shows, and brings them back after", function()
		HudStore:onEvents(Fixtures.ruleEvents({
			{ name = "LapCompleted", team = "Blue", streak = 1, holder = "1" },
			{ name = "GoalOpened", team = "Blue" },
		}))
		Hud:step(0)
		expect(part("Banner") ~= nil and part("Message") ~= nil).toBe(true)
		local held = Fixtures.scriptedBinding(InputController.context, "ScoreTab")
		held:Fire(true)
		Hud:step(0)
		expect(part("Banner")).toBeNil()
		expect(part("Message")).toBeNil()
		local left = HudStore.state.bannerLeft
		HudStore:step(1)
		expect(HudStore.state.bannerLeft).toBe(left - 1)
		held:Fire(false)
		Hud:step(0)
		expect(part("Message")).toBeNil()
		fadeOut()
		local words = HudText.new(config)
		local state = HudStore.state
		expect(part("Banner"):FindFirstChild("Front", true).Text).toBe(words:banner(state.banner :: any))
		expect(part("Message"):FindFirstChild("Front", true).Text).toBe(words:banner(state.message :: any))
	end)

	-- Over all the HUD draws, its stage too, on the HUD's whole area under the scoreboard (#357); off touch, clicks
	-- reach the game. On this phone's screen S5 sits in Roblox's bar, but its worth chip's pop reaches below it.
	it("draws the score tab above the stage, over the HUD's whole area under the scoreboard", function()
		Fixtures.scriptedBinding(InputController.context, "ScoreTab"):Fire(true)
		Hud:step(0)
		local tab = part("ScoreTab") :: Frame
		expect((tab.Parent :: Instance).Name).toBe("Root")
		expect(tab.ZIndex > (part("Stage") :: Frame).ZIndex).toBe(true)
		local boardTop = HudScreen.boardTop(config, true, 750, PHONE.topbar)
		local under = math.ceil(HudScreen.boardBottom(config, true, boardTop, false) - 58)
		expect(under > 0).toBe(true)
		expect(tab.Position).toEqual(UDim2.fromOffset(0, under))
		expect(tab.Size).toEqual(UDim2.new(1, 0, 1, -under))
		expect(tab.Active).toBe(false)
		-- OVERTIME under S5's row reaches lower still.
		HudStore:onSnapshot(Fixtures.matchSnapshot({ period = "Overtime" }, 1))
		Hud:step(0)
		local overtime = math.ceil(HudScreen.boardBottom(config, true, boardTop, true) - 58)
		expect(overtime > under).toBe(true)
		expect(tab.Position).toEqual(UDim2.fromOffset(0, overtime))
	end)

	-- On a phone (Q234, Q236): the whole screen under the SCORES button, which stays above it, and over the touch
	-- buttons, whose touches it takes while open.
	it("on touch, puts the score tab under the SCORES button, taking the touches there while it is open", function()
		preferred = Enum.PreferredInput.Touch
		Hud:toggleScoreTab()
		Hud:step(0)
		local tab = part("ScoreTab") :: Frame
		expect((tab.Parent :: Instance).Name).toBe("Root")
		local top = HudScreen.tabTop(config, true, 0)
		expect(tab.Position.Y.Offset).toBe(top)
		expect(tab.Size).toEqual(UDim2.new(1, 0, 1, -top))
		-- Its shield spans this phone's whole screen (62 px past the HUD's area each side), over the touch buttons.
		local shield = tab:FindFirstChild("Shield") :: Frame
		expect(shield.Active).toBe(true)
		expect(shield.Position).toEqual(UDim2.fromOffset(-62, 0))
		expect(shield.Size).toEqual(UDim2.fromOffset(874, 323 - top))
		-- Measured from the HUD's area, wherever GuiService's rects start: the same screen, both 10 px right, 5 down.
		screen = {
			whole = Rect.new(-52, -73, 822, 328),
			hud = Rect.new(10, 5, 760, 328),
			controls = Rect.new(10, -53, 760, 328),
			topbar = PHONE.topbar,
		}
		Hud:resize()
		expect(shield.Position).toEqual(UDim2.fromOffset(-62, 0))
		expect(shield.Size).toEqual(UDim2.fromOffset(874, 323 - top))
		-- The SCORES button stays clear above it.
		local button = part("ScoreButton") :: TextButton
		local place = config.UI.hud.layout.scoreButton
		expect(place.top + place.size.Y.Offset <= tab.Position.Y.Offset).toBe(true)
		expect(button.Parent == tab.Parent).toBe(true)
		Hud:toggleScoreTab()
		Hud:step(0)
		expect(shield.Active).toBe(false)
	end)

	-- It never covers the scoreboard (Q203's rule): on this desktop S2 hangs into the HUD's area, 58 px under the safe
	-- area's top, so the board's area starts under its deepest ink in play; on a big touch screen too, where that is
	-- lower than the SCORES button, but not once the match is over, as the end screen has no scoreboard.
	it("starts the score tab's area under the scoreboard's ink, where the scoreboard shows", function()
		screen = BIG
		Hud:resize()
		local held = Fixtures.scriptedBinding(InputController.context, "ScoreTab")
		held:Fire(true)
		Hud:step(0)
		local boardTop = HudScreen.boardTop(config, false, 1280, BIG.topbar)
		local under = math.ceil(HudScreen.boardBottom(config, false, boardTop, false) - 58)
		local button = HudScreen.tabTop(config, true, 0)
		expect(under > button).toBe(true)
		expect((part("ScoreTab") :: Frame).Position).toEqual(UDim2.fromOffset(0, under))
		held:Fire(false)
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		fadeOut()
		Hud:toggleScoreTab()
		Hud:step(0)
		expect((part("ScoreTab") :: Frame).Position).toEqual(UDim2.fromOffset(0, under))
		-- The match's end closes it; opened again in the end screen's place.
		endMatch()
		Hud:step(0)
		fadeOut()
		Hud:toggleScoreTab()
		Hud:step(0)
		expect((part("ScoreTab") :: Frame).Position).toEqual(UDim2.fromOffset(0, button))
	end)

	-- The board fits the HUD's whole area, over the touch buttons (Q236), not the stage left of them, at the screen's
	-- sizes; when the screen changes it fits the new one.
	it("fits the score tab to the HUD's whole area at the screen's sizes, and again when the screen changes", function()
		preferred = Enum.PreferredInput.Touch
		local players = Fixtures.roster(12)
		HudStore:onSnapshot(
			Fixtures.matchSnapshot({ stats = { scores = { Blue = 0, Orange = 0 }, players = players } }, 1)
		)
		Hud:toggleScoreTab()
		Hud:step(0)
		local function board(): (Frame, UIScale, ScrollingFrame)
			local tab = part("ScoreTab") :: Frame
			local box = tab:FindFirstChild("Box", true) :: Frame
			return box, tab:FindFirstChild("Fit", true) :: UIScale, tab:FindFirstChild("Teams", true) :: ScrollingFrame
		end
		-- The phone's 750 px hold its 610 px box at its size (the 548 px stage would not); 12 rows scroll.
		local box, fit, teams = board()
		expect(box.Size.X.Offset).toBe(config.UI.hud.layout.scoreTab.compactSizes.width)
		expect(fit.Scale).toBe(1)
		expect(teams.Size.Y.Offset < HudScreen.tabBody(config, true, 12)).toBe(true)
		-- A big screen: the desktop's sizes, every row showing.
		screen = BIG
		Hud:resize()
		Hud:step(0)
		box, fit, teams = board()
		expect(box.Size.X.Offset).toBe(config.UI.hud.layout.scoreTab.sizes.width)
		expect(fit.Scale).toBe(1)
		expect(teams.Size.Y.Offset).toBe(HudScreen.tabBody(config, false, 12))
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
		local row = button:FindFirstChild("Row") :: CanvasGroup
		local key = row:FindFirstChild("Key") :: Frame
		expect((key:FindFirstChild("Legend", true) :: TextLabel).Text).toBe("T")
		expect((row:FindFirstChild("Label") :: TextLabel).Text).toBe(config.UI.text.switchTeam)
		pressKey()
		expect(switches).toBe(1)
		preferred = Enum.PreferredInput.Gamepad
		Hud:step(0)
		local glyph = part("SwitchTeam"):FindFirstChild("Row"):FindFirstChild("Glyph"):FindFirstChild("Face")
		expect((glyph :: ImageLabel).Image).toBe(keyImage(Enum.KeyCode.DPadUp))
		-- On touch it is tapped (its Activated calls switchTeam; a test cannot fire it), with no key shown.
		preferred = Enum.PreferredInput.Touch
		held:Fire(false)
		Hud:toggleScoreTab()
		Hud:step(0)
		expect(part("SwitchTeam"):FindFirstChild("Row"):FindFirstChild("Key")).toBeNil()
		Hud:switchTeam()
		expect(switches).toBe(2)
	end)

	-- The owner (Q104, Q118): greyed while a switch can't happen, and then it asks nothing.
	it("greys Switch team while the local player holds the ball or the other team is full", function()
		local dim = config.UI.hud.dimTransparency
		local function row(): CanvasGroup
			return part("SwitchTeam"):FindFirstChild("Row") :: CanvasGroup
		end
		Fixtures.scriptedBinding(InputController.context, "ScoreTab"):Fire(true)
		BallCarrier:set(LOCAL_ID)
		Hud:step(0)
		expect(row().GroupTransparency).toBeCloseTo(dim, 5)
		Hud:switchTeam()
		expect(switches).toBe(0)
		BallCarrier:set(nil)
		Hud:step(0)
		expect(row().GroupTransparency).toBe(0)
		Hud:switchTeam()
		expect(switches).toBe(1)
		local players = { Fixtures.playerStats("1", "Blue") }
		for _, id in { "2", "3", "4" } do
			table.insert(players, Fixtures.playerStats(id, "Orange"))
		end
		local orangeFull = { scores = { Blue = 0, Orange = 0 }, players = players }
		HudStore:onSnapshot(Fixtures.matchSnapshot({ stats = orangeFull }, 1))
		Hud:step(0)
		expect(row().GroupTransparency).toBeCloseTo(dim, 5)
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

	it("on touch, keeps the score button through the end screen and opens the full score tab in its place", function()
		preferred = Enum.PreferredInput.Touch
		Hud:toggleScoreTab()
		Hud:step(0)
		expect(part("ScoreTab") ~= nil).toBe(true)
		-- The match ends: the tab toggled on before closes, the button stays, and the end screen has no full table.
		endMatch()
		Hud:step(0)
		fadeOut()
		expect(part("ScoreTab")).toBeNil()
		expect(part("ScoreButton") ~= nil).toBe(true)
		local endScreen = part("EndScreen") :: Frame
		expect(endScreen:FindFirstChild("Table", true)).toBeNil()
		-- A tap opens the full score tab above the stage; the end screen goes meanwhile, as the board would cut it,
		-- the result's top sticking out above the board's (seen in Play on the phone).
		local stage = endScreen.Parent :: Frame
		Hud:toggleScoreTab()
		Hud:step(0)
		expect(part("ScoreTab") ~= nil).toBe(true)
		expect((part("ScoreTab") :: Frame).ZIndex > stage.ZIndex).toBe(true)
		expect(part("EndScreen")).toBeNil()
		-- Closed, it comes back once the board has faded, at rest: it does not pop a second time.
		Hud:toggleScoreTab()
		Hud:step(0)
		expect(part("EndScreen")).toBeNil()
		fadeOut()
		expect(part("ScoreTab")).toBeNil()
		expect((part("EndScreen"):FindFirstChild("Pop", true) :: UIScale).Scale).toBe(1)
		-- Open again when the next match starts: the tab closes, so it never pops open then.
		Hud:toggleScoreTab()
		Hud:step(0)
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3 }))
		Hud:step(0)
		fadeOut()
		expect(part("ScoreTab")).toBeNil()
		expect(part("EndScreen")).toBeNil()
		expect(part("ScoreButton") ~= nil).toBe(true)
	end)

	it("puts the end screen, the banner and the feed on a stage above the rest, left of the touch buttons", function()
		local function fit(panel: string): number
			return (part(panel):FindFirstChild("Fit") :: UIScale).Scale
		end
		Hud:step(0)
		for _, name in { "Banner", "Feed" } do
			expect(`{name} in {part(name).Parent.Name}`).toBe(`{name} in Stage`)
		end
		-- The solid end screen covers the scoreboard, the hints and the speedometer.
		local stage = part("Stage") :: Frame
		for _, other in part("Root"):GetChildren() do
			if other ~= stage and other:IsA("GuiObject") then
				expect(`{other.Name} below: {other.ZIndex < stage.ZIndex}`).toBe(`{other.Name} below: true`)
			end
		end
		-- With a keyboard the stage is the whole HUD area; on touch it ends where the buttons begin.
		expect(part("Stage").Size).toEqual(UDim2.fromOffset(750, 323))
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		-- The buttons sit at the whole screen's corner (#355), 62 px past the HUD's area: 812 - 264.
		expect(part("Stage").Size).toEqual(UDim2.fromOffset(548, 323))
		expect(fit("Banner")).toBe(1)
		expect(fit("Feed")).toBe(1)
		-- The end screen fits the stage too: on touch, without its table, the MVP's card is the widest part, wider
		-- than the 354 px stage the buttons leave on a whole screen that ends at 618.
		screen =
			{ whole = Rect.new(-62, -78, 618, 323), hud = PHONE.hud, controls = PHONE.controls, topbar = PHONE.topbar }
		Hud:resize()
		endMatch()
		Hud:step(0)
		expect(part("EndScreen").Parent.Name).toBe("Stage")
		local stack = part("Stack") :: Frame
		local margin = 2 * config.UI.hud.screenMargin
		local wide = (stage.Size.X.Offset - margin) / stack.Size.X.Offset
		expect(wide < 1).toBe(true)
		expect(fit("Stack")).toBeCloseTo(math.min(wide, (stage.Size.Y.Offset - margin) / stack.Size.Y.Offset), 4)
	end)

	-- As the page drew it (Q243): the game under a half-see-through ink over the whole screen, fading in with the
	-- screen's pop; so the HUD's other parts go while it shows, or they would show through.
	it("dims the whole screen under the end screen, the HUD's other parts gone, until the next match", function()
		local function bright(): string
			local shown: { string } = {}
			for _, name in { "Banner", "Message", "Feed", "ControlHints" } do
				if part(name) ~= nil then
					table.insert(shown, name)
				end
			end
			if part("Speedometer").Visible then
				table.insert(shown, "Speedometer")
			end
			return table.concat(shown, " ")
		end
		Fixtures.spawnSkater(folder, config)
		SkateController:step(DT)
		Hud:step(0)
		expect(Hud.dim:FindFirstChild("Dim")).toBeNil()
		expect(bright()).toBe("Banner Message Feed ControlHints Speedometer")
		endMatch()
		Hud:step(0)
		local dim = Hud.dim:FindFirstChild("Dim") :: Frame
		expect(dim.Size).toEqual(UDim2.fromScale(1, 1))
		expect(dim.BackgroundColor3 == config.UI.hud.look.ink).toBe(true)
		expect(dim.BackgroundTransparency).toBeCloseTo(1, 4)
		Hud:step(config.UI.hud.motion.pop.seconds)
		expect(dim.BackgroundTransparency).toBeCloseTo(config.UI.hud.layout.endScreen.dim, 4)
		expect(bright()).toBe("")
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3 }))
		Hud:step(0)
		expect(Hud.dim:FindFirstChild("Dim")).toBeNil()
		expect(bright()).toBe("Banner Message Feed ControlHints Speedometer")
	end)

	-- They would show through the dim too (#358): the count of a kickoff the match ended in, a skater's Get Up.
	it("hides the kickoff's count and the Get Up prompt under the end screen", function()
		local rig = Fixtures.spawnSkater(folder, config)
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		SkateController:step(DT)
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3 }))
		Hud:step(0)
		local count = Hud.centre:FindFirstChild("Countdown") :: Frame
		expect(count.Visible).toBe(true)
		expect(part("GetUp") ~= nil).toBe(true)
		endMatch()
		SkateController:step(DT)
		Hud:step(0)
		expect(count.Visible).toBe(false)
		expect(part("GetUp")).toBeNil()
	end)

	-- The name tags read the form from their first step: a desktop's until the screen is measured.
	it("has a desktop's form until the screen is measured", function()
		expect(Hud.compact).toBe(false)
		Hud:resize()
		expect(Hud.compact).toBe(true)
	end)

	-- The owner's Q243 (#358): at the screen's own sizes (a phone's here, played with a keyboard), with the TAB
	-- board's table off touch; it pops in whole as the match ends (Q194).
	it("pops the end screen in at the screen's sizes, with the table off touch", function()
		endMatch()
		Hud:step(0)
		local endScreen = part("EndScreen") :: Frame
		local pop = endScreen:FindFirstChild("Pop", true) :: UIScale
		expect(pop.Scale).toBeCloseTo(0, 4)
		Hud:step(config.UI.hud.motion.pop.seconds)
		expect(pop.Scale).toBe(1)
		expect(endScreen:FindFirstChild("Table", true) ~= nil).toBe(true)
		local result = endScreen:FindFirstChild("Result", true) :: Frame
		expect((result:FindFirstChild("Front", true) :: TextLabel).TextSize).toBe(
			HudScreen.bannerSize(config, true, "Goal")
		)
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
		-- Back once the board has faded off it.
		held:Fire(false)
		Hud:step(0)
		expect(reticle()).toBe(false)
		fadeOut()
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
		expect(part("Stage").Size).toEqual(UDim2.fromOffset(548, 323))
		-- A big screen: the buttons grow 1.5 times and reach 396 px in.
		screen = BIG
		Hud:resize()
		expect(part("Stage").Size).toEqual(UDim2.fromOffset(884, 742))
		preferred = Enum.PreferredInput.KeyboardAndMouse
		Hud:step(0)
		expect(part("Stage").Size).toEqual(UDim2.fromOffset(1280, 742))
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		expect(part("Stage").Size).toEqual(UDim2.fromOffset(884, 742))
	end)

	it("unmounts its React root when destroyed, the reticle with it", function()
		Hud:step(0)
		Hud:destroy()
		expect(Hud.gui:FindFirstChild("Root")).toBeNil()
		expect(Hud.centre:FindFirstChild("Reticle")).toBeNil()
	end)

	it("takes its ScreenGuis with it when destroyed, wherever they were moved", function()
		local elsewhere = Instance.new("Folder")
		elsewhere.Parent = workspace
		local guis = { Hud.gui, Hud.centre, Hud.top, Hud.dim }
		for _, gui in guis do
			gui.Parent = elsewhere
		end
		Hud:destroy()
		local left = #elsewhere:GetChildren()
		elsewhere:Destroy()
		expect(left).toBe(0)
		for _, gui in guis do
			expect(gui.Parent).toBeNil()
		end
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

describe("Hud, the screen markers", function()
	-- The phone's screen (Fixtures.PHONE): the whole screen 874 x 401, its centre (437, 200.5); the safe area from (62,
	-- 20) to (812, 401) in its pixels.
	local markers = config.UI.hud.layout.markers

	local function marker(name: string): Frame?
		return Hud.centre:FindFirstChild(name, true) :: Frame?
	end

	it(
		"marks the ball while it is off the screen, pinned inside the safe area, and hides it on the screen or gone",
		function()
			Hud:step(0)
			local badge = marker("BallMarker") :: Frame
			expect(badge.Visible).toBe(false)
			ballScreen = { point = Vector3.new(2000, 200.5, 10), onScreen = false }
			Hud:step(0)
			expect(badge.Visible).toBe(true)
			-- Dark before a team has held the ball, in the HUD's colour of the team that last has after.
			local ring = badge:FindFirstChild("Ring") :: Frame
			expect(ring.BackgroundColor3).toEqual(config.UI.hud.look.ink)
			HudStore:onSnapshot(Fixtures.matchSnapshot({ possessingTeam = "Orange" }, 1))
			Hud:step(0)
			expect(ring.BackgroundColor3).toEqual(Style.teamColor(config, "Orange"))
			local reach = HudScreen.markerReach(config, Hud.compact, "Badge")
			expect(badge.Position).toEqual(UDim2.fromOffset(math.round(812 - markers.edgeGap - reach), 201))
			expect((badge:FindFirstChild("Pointer") :: Frame).Rotation).toBeCloseTo(90, 3)
			ballScreen = { point = Vector3.new(300, 200, 10), onScreen = true }
			Hud:step(0)
			expect(badge.Visible).toBe(false)
			ballScreen = { point = Vector3.new(2000, 200.5, 10), onScreen = false }
			Hud:step(0)
			ball = nil
			Hud:step(0)
			expect(badge.Visible).toBe(false)
		end
	)

	it("slides the ball's marker along the edge clear of the scoreboard, still pointing at the ball", function()
		-- Straight above the screen's centre: the path's top meets the line in the board's middle.
		ballScreen = { point = Vector3.new(437, -5000, 10), onScreen = false }
		Hud:step(0)
		local badge = marker("BallMarker") :: Frame
		local reach, body = HudScreen.markerReach(config, Hud.compact, "Badge")
		expect(badge.Position.Y.Offset).toBe(math.round(20 + markers.edgeGap + reach))
		local half = HudScreen.boardReach(config, Hud.compact) + config.UI.hud.look.outline
		expect(math.abs(badge.Position.X.Offset - 437) >= half + body + markers.clearance - 1).toBe(true)
		expect((badge:FindFirstChild("Pointer") :: Frame).Rotation).toBeCloseTo(0, 3)
	end)

	it("marks the carrier's next gate, over it on the screen and at the edge off it, for nobody else", function()
		local chevron = function(): Frame
			return marker("GateMarker") :: Frame
		end
		BallCarrier:set(LOCAL_ID)
		HudStore:onSnapshot(Fixtures.matchSnapshot({ possessingTeam = "Blue", nextGate = 3 }))
		Hud:step(0)
		expect(chevron().Visible).toBe(true)
		expect(chevron().Position).toEqual(UDim2.fromOffset(600, 200))
		-- In the viewer's colour: the local player plays for Blue in the fixture.
		local bar = (chevron():FindFirstChild("Arrow") :: Frame):FindFirstChild("Right") :: Frame
		expect(bar.BackgroundColor3).toEqual(Style.teamColor(config, "Blue"))
		-- Pointing down at it, at its gate panel's pivot: its wall's middle.
		expect((chevron():FindFirstChild("Arrow") :: Frame).Rotation).toBeCloseTo(180, 3)
		Fixtures.expectNear(gateAimed :: Vector3, arena.markers[3]:GetPivot().Position)
		gateScreen = { point = Vector3.new(-3000, 200.5, 20), onScreen = false }
		Hud:step(0)
		local reach = HudScreen.markerReach(config, Hud.compact, "Chevron")
		expect(chevron().Position).toEqual(UDim2.fromOffset(math.round(62 + markers.edgeGap + reach), 201))
		BallCarrier:set("2")
		Hud:step(0)
		expect(chevron().Visible).toBe(false)
		-- Every streak starts at the goal's gate (the snapshot fixture's next gate): the marker shows from the pickup.
		BallCarrier:set(LOCAL_ID)
		HudStore:onSnapshot(Fixtures.matchSnapshot({ possessingTeam = "Blue" }, 1))
		Hud:step(0)
		expect(chevron().Visible).toBe(true)
		Fixtures.expectNear(gateAimed :: Vector3, arena.markers[config.Arena.goalGateIndex]:GetPivot().Position)
	end)

	-- The owner's Q255: once the carrier's streak has counted its last lap, no gate is next, so no chevron shows.
	it("marks no gate once the carrier's streak has counted its last lap", function()
		BallCarrier:set(LOCAL_ID)
		HudStore:onSnapshot(Fixtures.matchSnapshot({ possessingTeam = "Blue", nextGate = 3 }))
		Hud:step(0)
		local chevron = marker("GateMarker") :: Frame
		expect(chevron.Visible).toBe(true)
		HudStore:onSnapshot(Fixtures.lapCapped("Blue", 1))
		Hud:step(0)
		expect(chevron.Visible).toBe(false)
	end)

	it("hides the chevron over an on-screen gate where a HUD part would cover it, as at the edge (Q267)", function()
		BallCarrier:set(LOCAL_ID)
		HudStore:onSnapshot(Fixtures.matchSnapshot({ possessingTeam = "Blue", nextGate = 3 }))
		-- Behind the scoreboard: the phone's board is centred across its safe area (x 437 of the whole screen), at its
		-- top.
		gateScreen = { point = Vector3.new(437, 40, 20), onScreen = true }
		Hud:step(0)
		local chevron = marker("GateMarker") :: Frame
		expect(chevron.Visible).toBe(false)
		gateScreen = { point = Vector3.new(600, 200, 20), onScreen = true }
		Hud:step(0)
		expect(chevron.Visible).toBe(true)
		expect(chevron.Position).toEqual(UDim2.fromOffset(600, 200))
	end)

	it("keeps the ball's marker off the boxes the hints' column and the speedometer report, laid out", function()
		-- Laid out as Roblox lays a gui out under StarterGui, on the screen the HUD's whole-screen gui is laid out on:
		-- the editor's in Studio, 800 x 600 on a server with no screen (the cloud's run), where the camera's viewport
		-- reads 1 x 1 (probed). The Hud's destroy takes the guis back out after the test, passed or failed.
		local starter = game:GetService("StarterGui")
		for _, gui in { Hud.gui, Hud.centre } do
			gui.Parent = starter
		end
		local view = Hud.centre.AbsoluteSize
		local whole = Rect.new(0, 0, view.X, view.Y)
		screen = { whole = whole, hud = whole, controls = whole, topbar = Rect.new(164, 0, view.X, 58) }
		Hud:resize()
		local rig = Fixtures.spawnSkater(folder, config)
		Hud:step(0)
		-- Reading a part's box lays it out at once, and Roblox tells its Change handlers at the next resumption point
		-- (deferred events): a frame later the Hud has heard both boxes. Probed: a frame without the read was not
		-- always enough, Studio's editor laying a gui out only when it draws.
		local column = part("ControlHints") :: Frame
		local meter = part("Speedometer") :: Frame
		local _, _ = column.AbsoluteSize, meter.AbsoluteSize
		task.wait()
		-- In the markers' pixels: the whole screen's, from the markers' gui's corner.
		local origin = Hud.centre.AbsolutePosition
		local top = column.AbsolutePosition.Y - origin.Y
		local bottom = top + column.AbsoluteSize.Y
		local reach, body = HudScreen.markerReach(config, Hud.compact, "Badge")
		local keep = body + markers.clearance
		-- The marker's path, edgeGap and its reach inside the screen, and a ball off the screen on the line from the
		-- screen's centre through the point (x, y) of it.
		local inset = markers.edgeGap + reach
		local pathRight, pathBottom = view.X - inset, view.Y - inset
		local function beyond(x: number, y: number): OnScreen
			return {
				point = Vector3.new(view.X / 2 + (x - view.X / 2) * 10, view.Y / 2 + (y - view.Y / 2) * 10, 10),
				onScreen = false,
			}
		end
		-- The line to the ball meets the right edge at the column's middle: the marker slides above or below it.
		local middle = (top + bottom) / 2
		ballScreen = beyond(pathRight, middle)
		Hud:step(0)
		local badge = marker("BallMarker") :: Frame
		local y = badge.Position.Y.Offset
		expect(y <= top - keep + 1 or y >= bottom + keep - 1).toBe(true)
		-- On the bottom edge just inside the speedometer's box: it slides left, clear of it.
		local left = meter.AbsolutePosition.X - origin.X
		expect(left + 1 < pathRight).toBe(true)
		ballScreen = beyond(left + 1, pathBottom)
		Hud:step(0)
		expect(badge.Position.X.Offset <= left - keep + 1).toBe(true)
		-- Without a skater the column and the speedometer go, and so do their boxes: back on its line.
		rig:Destroy()
		ballScreen = beyond(pathRight, middle)
		Hud:step(0)
		Hud:step(0)
		expect(part("ControlHints")).toBeNil()
		-- On the whole pixel nearest the line's point (the column's middle can be a half pixel).
		expect(math.abs(badge.Position.Y.Offset - middle) <= 0.5 + 1e-6).toBe(true)
		ballScreen = beyond(left + 1, pathBottom)
		Hud:step(0)
		expect(math.abs(badge.Position.X.Offset - (left + 1)) <= 0.5 + 1e-6).toBe(true)
	end)

	it("hides both markers while the TAB board or the end screen shows, as the crosshair does", function()
		ballScreen = { point = Vector3.new(2000, 200.5, 10), onScreen = false }
		BallCarrier:set(LOCAL_ID)
		Hud:step(0)
		expect(marker("BallMarker") ~= nil and marker("GateMarker") ~= nil).toBe(true)
		local held = Fixtures.scriptedBinding(InputController.context, "ScoreTab")
		held:Fire(true)
		Hud:step(0)
		expect(marker("BallMarker")).toBeNil()
		expect(marker("GateMarker")).toBeNil()
		held:Fire(false)
		fadeOut()
		expect(marker("BallMarker") ~= nil).toBe(true)
		endMatch()
		Hud:step(0)
		expect(marker("BallMarker")).toBeNil()
		expect(marker("GateMarker")).toBeNil()
	end)
end)
