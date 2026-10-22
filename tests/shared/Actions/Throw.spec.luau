--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it = JestGlobals.describe, JestGlobals.it

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Throw = require(ReplicatedStorage.Shared.Actions.Throw)

local actions = Config.defaults().Actions
local throw = actions.ChargeThrow.throw :: Config.ThrowSettings
local pass = actions.Pass.pass :: Config.PassSettings

describe("Throw", function()
	it("throws faster the longer the charge, plus half the carrier's velocity", function()
		local aim = Vector3.new(0, 0, -1)
		local carrier = Vector3.new(10, 0, 0)
		Fixtures.expectNear(Throw.charged(throw, aim, 0, carrier), Vector3.new(5, 0, -60))
		Fixtures.expectNear(Throw.charged(throw, aim, 1, carrier), Vector3.new(5, 0, -160))
		Fixtures.expectNear(Throw.charged(throw, aim, 0.5, carrier), Vector3.new(5, 0, -110))
		Fixtures.expectNear(Throw.charged(throw, aim, 2, carrier), Vector3.new(5, 0, -160))
		-- The aim's length does not matter.
		Fixtures.expectNear(Throw.charged(throw, aim * 4, 1, carrier), Vector3.new(5, 0, -160))
	end)

	it("passes at passSpeed toward the target, or along the aim without one", function()
		local aim = Vector3.new(2, 0, 0)
		Fixtures.expectNear(Throw.pass(pass, Vector3.zero, aim, Vector3.new(0, 0, -30)), Vector3.new(0, 0, -90))
		Fixtures.expectNear(Throw.pass(pass, Vector3.zero, aim, nil), Vector3.new(90, 0, 0))
		-- A target exactly at the passer gives no direction: along the aim.
		Fixtures.expectNear(Throw.pass(pass, Vector3.zero, aim, Vector3.zero), Vector3.new(90, 0, 0))
	end)
end)
