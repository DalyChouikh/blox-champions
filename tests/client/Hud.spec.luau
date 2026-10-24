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
local Hud = require(Client.Hud)
local HudStore = require(Client.HudStore)
local InputController = require(Client.InputController)
local SkateController = require(Client.SkateController)

local config = Config.defaults()
local LOCAL_ID = "1"
local DT = 1 / 60

local folder: Folder
local preferred: Enum.PreferredInput

-- Roblox's key names, as GetStringForKeyCode gives them: a letter key its letter, Space a space, a gamepad button its
-- KeyCode's name, and nothing for Shift, Ctrl, Tab or a mouse button.
local function keyString(key: Enum.KeyCode): string
	local name = key.Name
	if key == Enum.KeyCode.Space then
		return " "
	elseif #name == 1 or string.sub(name, 1, 6) == "Button" then
		return name
	end
	return ""
end

-- Roblox's glyphs, as GetImageForKeyCode gives them: one for each gamepad button, none for other keys.
local function keyImage(key: Enum.KeyCode): string
	local name = key.Name
	return if string.sub(name, 1, 6) == "Button"
		then `rbxasset://textures/ui/Controls/DefaultController/{name}@2x.png`
		else ""
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
	})
end)

afterEach(function()
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

	it("hides the touch score button behind the end screen, and forgets its toggle", function()
		preferred = Enum.PreferredInput.Touch
		Hud:toggleScoreTab()
		Hud:step(0)
		expect(part("ScoreTab") ~= nil).toBe(true)
		endMatch()
		Hud:step(0)
		expect(part("ScoreButton")).toBeNil()
		-- The tab toggled on before the end stays shut when the next match starts.
		HudStore:onSnapshot(Fixtures.matchSnapshot({ state = "Kickoff", phaseSecondsLeft = 3 }))
		Hud:step(0)
		expect(part("ScoreButton") ~= nil).toBe(true)
		expect(part("ScoreTab")).toBeNil()
	end)

	it("fits the score tab and the end screen to the HUD's area", function()
		local function fit(panel: string): number
			return (part(panel):FindFirstChild("Fit") :: UIScale).Scale
		end
		Fixtures.scriptedBinding(InputController.context, "ScoreTab"):Fire(true)
		Hud:step(0)
		-- A phone's safe area: each panel's height decides, less a margin at each side.
		Hud:resize(Vector2.new(750, 323))
		expect(fit("ScoreTab")).toBeCloseTo(307 / 360, 4)
		endMatch()
		Hud:step(0)
		expect(fit("EndScreen")).toBeCloseTo(307 / 520, 4)
		Hud:resize(Vector2.new(1920, 1000))
		expect(fit("EndScreen")).toBe(1)
	end)

	it("steps in under 0.1 ms", function()
		Fixtures.spawnSkater(folder, config)
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
