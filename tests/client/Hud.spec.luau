--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local BallCarrier = require(Client.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Hud = require(Client.Hud)
local HudStore = require(Client.HudStore)
local InputController = require(Client.InputController)
local RideSurfaces = require(Client.RideSurfaces)
local SkateController = require(Client.SkateController)
local SkaterBody = require(ServerScriptService.Server.SkaterBody)

local config = Config.defaults()
local LOCAL_ID = "1"

local folder: Folder
local preferred: Enum.PreferredInput

-- The local player's skater, built as the server builds it and taken by the skating.
local function spawnSkater()
	local rig = Fixtures.rig(folder, "Skater", CFrame.new(0, config.Movement.hoverHeight, 0))
	SkaterBody.build(rig, config.Movement)
	SkateController:bind(rig)
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "HudTest"
	folder.Parent = workspace
	preferred = Enum.PreferredInput.KeyboardAndMouse
	InputController:init({ Config = config, Parent = folder })
	BallCarrier:init({})
	RideSurfaces:init({})
	SkateController:init({
		Config = config,
		InputController = InputController,
		RideSurfaces = RideSurfaces,
		Camera = { CFrame = CFrame.new() },
		Skaters = function(): { any }
			return {}
		end,
		SendSkateState = function() end,
		Gravity = Fixtures.GRAVITY,
		Team = function(): string?
			return "Blue"
		end,
	})
	HudStore:init({ Config = config })
	HudStore:onSnapshot(Fixtures.matchSnapshot())
	Hud:init({
		Config = config,
		HudStore = HudStore,
		SkateController = SkateController,
		BallCarrier = BallCarrier,
		Parent = folder,
		LocalId = LOCAL_ID,
		PreferredInput = function(): Enum.PreferredInput
			return preferred
		end,
	})
end)

afterEach(function()
	InputController:destroy()
	folder:Destroy()
end)

describe("Hud", function()
	it("renders the HUD into its own ScreenGui as soon as it steps", function()
		local gui = Hud.gui
		expect(gui.Name).toBe("Hud")
		expect(gui.ResetOnSpawn).toBe(false)
		expect(gui.ScreenInsets).toBe(Enum.ScreenInsets.CoreUISafeInsets)
		expect(gui.Parent == folder).toBe(true)
		Hud:step(0)
		local root = gui:FindFirstChild("Root")
		expect(root ~= nil and root.ClassName).toBe("Frame")
	end)

	it("renders again only when what it shows changes", function()
		Hud:step(0)
		Hud:step(0)
		expect(Hud.renders).toBe(1)
		HudStore:onEvents({ { name = "GoalScored", team = "Blue", scorer = "1" } })
		Hud:step(0)
		expect(Hud.renders).toBe(2)
		preferred = Enum.PreferredInput.Gamepad
		Hud:step(0)
		expect(Hud.renders).toBe(3)
		BallCarrier:set("1")
		Hud:step(0)
		expect(Hud.renders).toBe(4)
		spawnSkater()
		Hud:step(0)
		expect(Hud.renders).toBe(5)
		Hud:step(0)
		expect(Hud.renders).toBe(5)
	end)

	it("counts the clock down on the scoreboard without rendering again", function()
		Hud:step(0)
		local clock = Hud.gui:FindFirstChild("Clock", true) :: TextLabel
		expect(clock.Text).toBe("2:00")
		HudStore:step(1)
		Hud:step(1)
		expect(clock.Text).toBe("1:59")
		expect(Hud.renders).toBe(1)
	end)
end)
