--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ActionController = require(Client.ActionController)
local BallCarrier = require(Client.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local ControlLabels = require(Client.ControlLabels)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local InputController = require(Client.InputController)
local SkateController = require(Client.SkateController)

local config = Config.defaults()
local labels = config.UI.controlLabels
local LOCAL_ID = "1"

local folder: Folder
local rig: Model

-- What each control's button or hint reads now, nil for one that does nothing.
local function now(control: Config.TouchControl): string?
	return ControlLabels.label(control, config, ActionController, SkateController)
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ControlLabelsTest"
	folder.Parent = workspace
	Fixtures.floor(folder)
	Fixtures.startSkating(folder, config, LOCAL_ID)
	rig = Fixtures.spawnSkater(folder, config)
end)

afterEach(function()
	InputController:destroy()
	folder:Destroy()
end)

describe("ControlLabels", function()
	it("names what each control does now, with or without the ball, in the air, behind a teammate", function()
		expect(ControlLabels.CONTROLS).toEqual({
			"jump",
			"pump",
			"brake",
			"attach",
			"tackle",
			"uppercut",
			"pass",
			"throw",
		})
		expect(now("jump")).toBe(labels.Jump)
		expect(now("pump")).toBe(labels.Pump)
		expect(now("brake")).toBe(labels.Brake)
		expect(now("attach")).toBeNil()
		expect(now("tackle")).toBe(labels.Tackle)
		expect(now("uppercut")).toBe(labels.Uppercut)
		expect(now("pass")).toBe(labels.CallPass)
		expect(now("throw")).toBe(labels.BallFocus)

		BallCarrier:set(LOCAL_ID)
		expect(now("tackle")).toBe(labels.Dodge)
		expect(now("uppercut")).toBeNil()
		expect(now("pass")).toBe(labels.Pass)
		expect(now("throw")).toBe(labels.ChargeThrow)

		-- In the air the jump button strikes the Air Pose, once until landing (#218), and the tackle button tackles
		-- without the ball, then dives in the tackle's follow-up window (#240).
		local skater = SkateController.skater :: any
		skater.mode = "Airborne"
		expect(now("jump")).toBe(labels.AirPose)
		expect(now("tackle")).toBe(labels.Dodge)
		BallCarrier:set(nil)
		expect(now("tackle")).toBe(labels.Tackle)
		Fixtures.intoDiveWindow(config)
		expect(now("tackle")).toBe(labels.Dive)
		skater.airPoseReady = false
		expect(now("jump")).toBeNil()

		SkateController.attachable = true
		expect(now("attach")).toBe(labels.Attach)

		-- The character is gone: nothing does anything.
		rig:Destroy()
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			expect(now(control)).toBeNil()
		end
	end)

	-- RC's hints while a throw charges (#312, Video 32 at 3.2 s): Throw, Cancel & Dodge and Roll Ball, with Pump and
	-- Magnetic Pass greyed (Q106, Q140); ours shows nothing for a control that does nothing.
	it("names Cancel & Dodge and Roll Ball while a throw charges, and nothing for the pump and the pass", function()
		BallCarrier:set(LOCAL_ID)
		ActionController:step(1 / 60) -- the throw key seen up while holding the ball
		Fixtures.scriptedBinding(InputController.context, "Throw"):Fire(true)
		ActionController:step(1 / 60)
		expect(ActionController:chargeSeconds() ~= nil).toBe(true)
		expect(now("throw")).toBe(labels.ChargeThrow)
		expect(now("tackle")).toBe(labels.CancelDodge)
		expect(now("uppercut")).toBe(labels.RollBall)
		expect(now("pass")).toBeNil()
		expect(now("pump")).toBeNil()
		expect(now("jump")).toBe(labels.Jump)
		expect(now("brake")).toBe(labels.Brake)
		-- In the air the uppercut key rolls nothing (#262).
		local skater = SkateController.skater :: any
		skater.mode = "Airborne"
		expect(now("uppercut")).toBeNil()
		expect(now("tackle")).toBe(labels.CancelDodge)
	end)

	-- RC's Dodge row reads "Dive" for ~1 s after a dodge with the ball (#314, Video 32 at 4.6-5.6 s).
	it("names the Dive on the tackle button in a dodge's follow-up window, with the ball", function()
		BallCarrier:set(LOCAL_ID)
		expect(now("tackle")).toBe(labels.Dodge)
		Fixtures.intoDiveWindow(config, "Dodge")
		expect(now("tackle")).toBe(labels.Dive)
	end)

	-- RC's hints through a carrier's dive and belly slide (#314, Q154, Video 33 at 17.6-19.0 s): only Charge Throw
	-- lit. Nothing else works there: the skating takes no input (SkateMath) and no other action starts.
	it("names only the carrier's throw while diving or down, and Ball Focus without the ball", function()
		BallCarrier:set(LOCAL_ID)
		local skate: any = SkateController
		for _, field in { "diving", "knockedDown" } do
			skate[field] = true
			for _, control: Config.TouchControl in ControlLabels.CONTROLS do
				expect(now(control)).toBe(if control == "throw" then labels.ChargeThrow else nil)
			end
			skate[field] = false
		end
		BallCarrier:set(nil)
		skate.knockedDown = true
		expect(now("throw")).toBe(labels.BallFocus)
		expect(now("tackle")).toBeNil()
		skate.knockedDown = false
	end)
end)
