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
-- The other skaters the skating sees, reset before each test.
local others: { any }

-- What each control's button or hint reads now, nil for one that does nothing.
local function now(control: Config.TouchControl): string?
	return (ControlLabels.label(control, config, ActionController, SkateController))
end

-- Whether a control is greyed: shown, but doing nothing now (#315).
local function greyed(control: Config.TouchControl): boolean
	local _, shownGreyed = ControlLabels.label(control, config, ActionController, SkateController)
	return shownGreyed
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ControlLabelsTest"
	folder.Parent = workspace
	Fixtures.floor(folder)
	others = {}
	Fixtures.startSkating(folder, config, LOCAL_ID, others)
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

	-- Magnetic Pass (#315, the owner: Q103): with the ball the pass's control reads RC's "Magnetic Pass", lit while a
	-- teammate is in the crosshair's cone and range, greyed with nobody there (shown, but doing nothing: RC fades the
	-- row, Video 34 at 43.0 s). Every other control shown works.
	it("greys Magnetic Pass with nobody in the aim, and lights it with a teammate there", function()
		BallCarrier:set(LOCAL_ID)
		ActionController:step(1 / 60)
		expect(labels.Pass).toBe("Magnetic Pass")
		expect(now("pass")).toBe(labels.Pass)
		expect(greyed("pass")).toBe(true)
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			if control ~= "pass" then
				expect(greyed(control)).toBe(false)
			end
		end
		table.insert(
			others,
			(Fixtures.otherSkater(folder, "2", Vector3.new(0, config.Movement.hoverHeight, -40), "Blue"))
		)
		ActionController:step(1 / 60)
		expect(now("pass")).toBe(labels.Pass)
		expect(greyed("pass")).toBe(false)
		-- Without the ball the key calls for it.
		BallCarrier:set(nil)
		expect(now("pass")).toBe(labels.CallPass)
		expect(greyed("pass")).toBe(false)
	end)

	-- The HUD shows the key pressed (#354): the throw's row is worked by Ball Focus's keys while it starts no throw.
	it("names the control whose keys work each row now", function()
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			expect(ControlLabels.worked(control, ActionController)).toBe(
				if control == "throw" then "ballFocus" else control
			)
		end
		BallCarrier:set(LOCAL_ID)
		expect(ControlLabels.worked("throw", ActionController)).toBe("throw")
	end)

	-- A key cooling down (#354, Q186): the seconds left of the action its row names now, and their share of its
	-- cooldown; none for a row that starts no action, or an action with no cooldown.
	it("tells how long each row's action still cools down, and what share of its cooldown that is", function()
		local runner = ActionController.runner
		runner:start("CallPass", { hasBall = false, knockedDown = false })
		runner:start("Uppercut", { hasBall = false, knockedDown = false })
		runner:step(0.3)
		local left, share = ControlLabels.cooldown("pass", config, ActionController)
		expect(left).toBeCloseTo(config.Actions.CallPass.cooldown - 0.3, 6)
		expect(share).toBeCloseTo(1 - 0.3 / config.Actions.CallPass.cooldown, 6)
		left, share = ControlLabels.cooldown("uppercut", config, ActionController)
		expect(left).toBeCloseTo(config.Actions.Uppercut.cooldown - 0.3, 6)
		expect(share).toBeCloseTo(1 - 0.3 / config.Actions.Uppercut.cooldown, 6)
		local idle: { Config.TouchControl } = { "jump", "pump", "brake", "attach", "tackle", "throw" }
		for _, control: Config.TouchControl in idle do
			left, share = ControlLabels.cooldown(control, config, ActionController)
			expect(left).toBe(0)
			expect(share).toBe(0)
		end
		runner:step(1)
		left, share = ControlLabels.cooldown("pass", config, ActionController)
		expect(left).toBe(0)
		expect(share).toBe(0)
		-- With the ball the throw and the pass start actions with no cooldown at all.
		BallCarrier:set(LOCAL_ID)
		expect(config.Actions.ChargeThrow.cooldown).toBe(0)
		left, share = ControlLabels.cooldown("throw", config, ActionController)
		expect(left).toBe(0)
		expect(share).toBe(0)
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
