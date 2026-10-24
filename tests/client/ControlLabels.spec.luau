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

		local skater = SkateController.skater :: any
		skater.mode = "Airborne"
		expect(now("jump")).toBeNil()

		SkateController.attachable = true
		expect(now("attach")).toBe(labels.Attach)

		-- The character is gone: nothing does anything.
		rig:Destroy()
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			expect(now(control)).toBeNil()
		end
	end)
end)
