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
local ControlLabels = require(Client.ControlLabels)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local InputController = require(Client.InputController)
local SkateController = require(Client.SkateController)

local config = Config.defaults()
local labels = config.UI.controlLabels
local LOCAL_ID = "1"
local DT = 1 / 60

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
	-- Every row stays and greys what does nothing now, as RC's do (#368, the owner's Q220; Videos 10-11).
	it("names what each control does now, with or without the ball, in the air, behind a teammate, greying", function()
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
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			expect(greyed(control)).toBe(false)
		end

		BallCarrier:set(LOCAL_ID)
		expect(now("tackle")).toBe(labels.Dodge)
		-- Roll Ball works only while a throw charges (#312): greyed until then.
		expect(now("uppercut")).toBe(labels.RollBall)
		expect(greyed("uppercut")).toBe(true)
		expect(now("pass")).toBe(labels.Pass)
		expect(now("throw")).toBe(labels.ChargeThrow)

		-- In the air the jump button strikes the Air Pose, once until landing (#218), and the tackle button tackles
		-- without the ball, then dives in the tackle's follow-up window (#240).
		local skater = SkateController.skater :: any
		skater.mode = "Airborne"
		expect(now("jump")).toBe(labels.AirPose)
		expect(greyed("jump")).toBe(false)
		expect(now("tackle")).toBe(labels.Dodge)
		-- The skates push and brake only on the ground: greyed in the air.
		expect(greyed("pump")).toBe(true)
		expect(greyed("brake")).toBe(true)
		BallCarrier:set(nil)
		expect(now("tackle")).toBe(labels.Tackle)
		-- The Uppercut starts only from a surface (#262): greyed in the air.
		expect(now("uppercut")).toBe(labels.Uppercut)
		expect(greyed("uppercut")).toBe(true)
		Fixtures.intoDiveWindow(config)
		expect(now("tackle")).toBe(labels.Dive)
		skater.airPoseReady = false
		expect(now("jump")).toBe(labels.AirPose)
		expect(greyed("jump")).toBe(true)

		SkateController.attachable = true
		expect(now("attach")).toBe(labels.Attach)
		-- Attached, the leader pulls them: the skates jump, push and brake nothing (SkateController follows).
		skater.mode = "Attached"
		expect(now("jump")).toBe(labels.Jump)
		local skating: { Config.TouchControl } = { "jump", "pump", "brake" }
		for _, control: Config.TouchControl in skating do
			expect(greyed(control)).toBe(true)
		end
		expect(greyed("attach")).toBe(false)

		-- The character is gone: nothing does anything.
		rig:Destroy()
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			expect(now(control)).toBeNil()
		end
	end)

	-- RC's hints while a throw charges (#312, Video 32 at 3.2 s): Throw, Cancel & Dodge and Roll Ball, with Pump and
	-- Magnetic Pass greyed (Q106, Q140), as ours are (#368).
	it("names Cancel & Dodge and Roll Ball while a throw charges, and greys the pump and the pass", function()
		BallCarrier:set(LOCAL_ID)
		ActionController:step(1 / 60) -- the throw key seen up while holding the ball
		Fixtures.scriptedBinding(InputController.context, "Throw"):Fire(true)
		ActionController:step(1 / 60)
		expect(ActionController:chargeSeconds() ~= nil).toBe(true)
		expect(now("throw")).toBe(labels.ChargeThrow)
		expect(now("tackle")).toBe(labels.CancelDodge)
		expect(now("uppercut")).toBe(labels.RollBall)
		expect(greyed("uppercut")).toBe(false)
		expect(now("pass")).toBe(labels.Pass)
		expect(greyed("pass")).toBe(true)
		expect(now("pump")).toBe(labels.Pump)
		expect(greyed("pump")).toBe(true)
		expect(now("jump")).toBe(labels.Jump)
		expect(now("brake")).toBe(labels.Brake)
		expect(greyed("brake")).toBe(false)
		-- In the air the uppercut key rolls nothing (#262).
		local skater = SkateController.skater :: any
		skater.mode = "Airborne"
		expect(now("uppercut")).toBe(labels.RollBall)
		expect(greyed("uppercut")).toBe(true)
		expect(now("tackle")).toBe(labels.CancelDodge)
		expect(greyed("tackle")).toBe(false)
		-- A charge goes on through a carrier's belly slide (#314), where no Dodge starts.
		local skate: any = SkateController
		skate.knockedDown = true
		expect(now("tackle")).toBe(labels.CancelDodge)
		expect(greyed("tackle")).toBe(true)
		skate.knockedDown = false
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
		-- Every other control works, but Roll Ball, which waits for a charge (#368).
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			expect(greyed(control)).toBe(control == "pass" or control == "uppercut")
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
	-- lit, every other row greyed (#368). Nothing else works there: the skating takes no input (SkateMath) and no
	-- other action starts.
	it("greys every row but the carrier's throw while diving or down, and keeps Ball Focus without the ball", function()
		BallCarrier:set(LOCAL_ID)
		local skate: any = SkateController
		local carrying: { [string]: string? } = {
			jump = labels.Jump,
			pump = labels.Pump,
			brake = labels.Brake,
			attach = nil,
			tackle = labels.Dodge,
			uppercut = labels.RollBall,
			pass = labels.Pass,
			throw = labels.ChargeThrow,
		}
		for _, field in { "diving", "knockedDown" } do
			skate[field] = true
			for _, control: Config.TouchControl in ControlLabels.CONTROLS do
				expect(now(control)).toBe(carrying[control])
				expect(greyed(control)).toBe(control ~= "throw" and control ~= "attach")
			end
			skate[field] = false
		end
		BallCarrier:set(nil)
		skate.knockedDown = true
		expect(now("throw")).toBe(labels.BallFocus)
		expect(greyed("throw")).toBe(false)
		expect(now("tackle")).toBe(labels.Tackle)
		expect(greyed("tackle")).toBe(true)
		skate.knockedDown = false
		-- A diver flies: the jump key reads the Air Pose, which does nothing through the dive either.
		local skater = SkateController.skater :: any
		skater.mode = "Airborne"
		skate.diving = true
		expect(now("jump")).toBe(labels.AirPose)
		expect(greyed("jump")).toBe(true)
		skate.diving = false
	end)

	-- The owner (#368, Q220): the row stays through the leap, greyed, sweeping its cooldown.
	it("names the Uppercut, greyed, cooling, through its leap", function()
		local runner = ActionController.runner
		expect(runner:start("Uppercut", { hasBall = false, knockedDown = false })).toBe("Started")
		local skater = SkateController.skater :: any
		skater.mode = "Airborne"
		expect(now("uppercut")).toBe(labels.Uppercut)
		expect(greyed("uppercut")).toBe(true)
		local left, share = ControlLabels.cooldown("uppercut", config, ActionController)
		expect(left).toBeCloseTo(config.Actions.Uppercut.cooldown, 6)
		expect(share).toBeCloseTo(1, 6)
	end)

	-- A dive outlives its run: a long flight, and the touchdown's knockdown stops it (as the server stops it) while the
	-- belly slide goes on until it stops (#242). The row stays the Dive's for all of it (#368, Q222).
	it("names the Dive through its flight and belly slide, then the key's usual action", function()
		local function frame()
			SkateController:step(DT)
			ActionController:step(DT)
		end
		local function reads(label: string, isGreyed: boolean)
			expect(now("tackle")).toBe(label)
			expect(greyed("tackle")).toBe(isGreyed)
		end
		Fixtures.intoDiveWindow(config)
		local tackleKey = Fixtures.scriptedBinding(InputController.context, "Tackle")
		tackleKey:Fire(true)
		task.wait() -- Pressed is deferred
		tackleKey:Fire(false)
		frame()
		expect(SkateController.diving).toBe(true)
		reads(labels.Dive, true)
		-- The Dive names only its own key's row.
		expect(now("uppercut")).toBe(labels.Uppercut)
		local left, share = ControlLabels.cooldown("tackle", config, ActionController)
		expect(left).toBeCloseTo(config.Actions.Dive.cooldown, 6)
		expect(share).toBeCloseTo(1, 6)

		-- Still flying once its run is over.
		ActionController.runner:cancel("Dive", false)
		reads(labels.Dive, true)

		-- The touchdown: the server's knockdown ends the hold and the slide goes on.
		rig:SetAttribute(Attributes.KnockedDown, "Dive")
		frame()
		expect(SkateController.diving).toBe(false)
		reads(labels.Dive, true)
		left = ControlLabels.cooldown("tackle", config, ActionController)
		expect(left).toBeCloseTo(config.Actions.Dive.cooldown - DT, 6)

		-- Another knockdown is no dive: the key's usual action, sweeping its own cooldown.
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		frame()
		reads(labels.Tackle, true)
		local since = (config.Actions.Tackle.followUp :: Config.FollowUp).from + 0.02 + 3 * DT
		left = ControlLabels.cooldown("tackle", config, ActionController)
		expect(left).toBeCloseTo(config.Actions.Tackle.cooldown - since, 6)

		rig:SetAttribute(Attributes.KnockedDown, nil)
		frame()
		reads(labels.Tackle, false)
	end)
end)
