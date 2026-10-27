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
local InputController = require(Client.InputController)
local SkateController = require(Client.SkateController)

local config = Config.defaults()
local LOCAL_ID = "1"
local DT = 1 / 60

local PHONE, BIG = Fixtures.PHONE, Fixtures.BIG_SCREEN

local folder: Folder
local preferred: Enum.PreferredInput
local screen: Fixtures.Screen

-- A gamepad's button or stick: Roblox names each by its KeyCode and gives it a glyph (probed).
local function gamepadKey(name: string): boolean
	return string.sub(name, 1, 6) == "Button" or string.sub(name, 1, 10) == "Thumbstick"
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

-- The HUD's part called `name`, wherever it sits; nil while it is not drawn.
local function part(name: string): any
	return Hud.gui:FindFirstChild(name, true)
end

-- Ends the match as the server's MatchEnded does: Blue wins, Ana the MVP.
local function endMatch()
	local stats = (HudStore.state.match :: any).stats
	HudStore:onEvents(Fixtures.ruleEvents({ { name = "MatchEnded", winner = "Blue", mvp = "1", stats = stats } }))
end

-- The key a hint row shows: its key's text, or its glyph.
local function hintKey(control: string): (string?, string?)
	local row = part("ControlHints"):FindFirstChild(control)
	local key, glyph = row:FindFirstChild("Key"), row:FindFirstChild("Glyph")
	return if key ~= nil then key.Text else nil, if glyph ~= nil then glyph.Image else nil
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "HudTest"
	folder.Parent = workspace
	preferred = Enum.PreferredInput.KeyboardAndMouse
	screen = PHONE
	Fixtures.startSkating(folder, config, LOCAL_ID)
	HudStore:init({ Config = config })
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
		InsetArea = function(insets: Enum.ScreenInsets): Rect
			if insets == Enum.ScreenInsets.CoreUISafeInsets then
				return screen.hud
			end
			expect(insets).toBe(Enum.ScreenInsets.DeviceSafeInsets)
			return screen.controls
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
		expect(centre.Parent == folder).toBe(true)
		expect(centre:FindFirstChild("Reticle") ~= nil).toBe(true)
	end)

	it("renders again only when what it shows changes", function()
		Hud:step(0)
		Hud:step(0)
		expect(Hud.renders).toBe(1)
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "GoalScored", team = "Blue", scorer = "1" } }))
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
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "GoalScored", team = "Blue", scorer = "1" } }))
		Hud:step(0)
		local banner = part("Banner") :: TextLabel
		expect(banner.Visible).toBe(true)
		expect(banner.Text).toBe("GOAL!")
		local feed = part("Feed") :: Frame
		expect((feed:FindFirstChild("1") :: TextLabel).Text).toBe("Ana scored!")
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
		expect(part("ControlHints").tackle.Label.Text).toBe(config.UI.controlLabels.Tackle)
		expect(part("ControlHints").attach.Visible).toBe(false)
		-- Without the ball the throw's row works Ball Focus, on its own key; with it, the throw's.
		expect((hintKey("throw"))).toBe("RMB")
		BallCarrier:set(LOCAL_ID)
		Hud:step(0)
		expect((hintKey("throw"))).toBe("LMB")

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

	-- Roller Champions' Get Up (#220): moving gets a knocked-down skater up sooner.
	it("shows a Get Up prompt with the device's movement keys only while the skater is knocked down", function()
		local rig = Fixtures.spawnSkater(folder, config)
		local function knockedDown(down: boolean)
			rig:SetAttribute(Attributes.KnockedDown, if down then true else nil)
			SkateController:step(DT)
			Hud:step(0)
		end
		Hud:step(0)
		expect(part("GetUp")).toBeNil()
		knockedDown(true)
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

		knockedDown(false)
		expect(part("GetUp")).toBeNil()
		knockedDown(true)
		expect(part("GetUp") ~= nil).toBe(true)
		rig:Destroy()
		Hud:step(0)
		expect(part("GetUp")).toBeNil()
	end)

	it("shows the skater's speed in km/h, and none without a character", function()
		Hud:step(0)
		local speedometer = part("Speedometer") :: TextLabel
		expect(speedometer.Visible).toBe(false)
		Fixtures.spawnSkater(folder, config)
		local skater = SkateController.skater :: any
		skater.velocity = Vector3.new(0, 0, -100)
		Hud:step(0)
		expect(speedometer.Visible).toBe(true)
		expect(speedometer.Text).toBe("120 km/h")
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
		-- On touch it ends where the buttons begin: (504 - 2 margins) / 640 for the tab and the banner.
		preferred = Enum.PreferredInput.Touch
		Hud:step(0)
		expect(part("Stage").Size).toEqual(UDim2.fromOffset(504, 323))
		expect(fit("ScoreTab")).toBeCloseTo(488 / 640, 4)
		expect(fit("Banner")).toBeCloseTo(488 / 640, 4)
		expect(fit("Feed")).toBe(1)
		-- The compact end screen is as tall as its parts, so its width decides: (504 - 2 margins) / 720.
		endMatch()
		Hud:step(0)
		expect(part("EndScreen").Parent.Name).toBe("Stage")
		expect(fit("EndScreen")).toBeCloseTo(488 / 720, 4)
	end)

	it("hides the reticle while the score tab or the end screen shows", function()
		local function reticle(): boolean
			return (Hud.centre:FindFirstChild("Reticle") :: Frame).Visible
		end
		local held = Fixtures.scriptedBinding(InputController.context, "ScoreTab")
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
