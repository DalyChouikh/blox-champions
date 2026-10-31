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

	-- Roll Ball (#312): the aim's way across the ground at the charge's speed, plus half the carrier's velocity along
	-- the ground. Aimed (3, 4, -4) on the flat: (3, 0, -4) / 5 x 160 = (96, 0, -128), plus (10, 0, 0) / 2.
	it("rolls the aim's way across the ground at the charge's speed, plus half the carrier's along it", function()
		local up, facing = Vector3.yAxis, -Vector3.zAxis
		local carrier = Vector3.new(10, 6, 0)
		local aim = Vector3.new(3, 4, -4)
		Fixtures.expectNear(Throw.rolled(throw, aim, 1, carrier, up, facing), Vector3.new(101, 0, -128))
		-- Half a charge: 110 studs/s.
		Fixtures.expectNear(Throw.rolled(throw, aim, 0.5, carrier, up, facing), Vector3.new(71, 0, -88))
		-- Aimed straight up (the camera under the skater) or down: along the facing.
		Fixtures.expectNear(Throw.rolled(throw, Vector3.new(0, 2, 0), 1, carrier, up, facing), Vector3.new(5, 0, -160))
		Fixtures.expectNear(Throw.rolled(throw, Vector3.new(0, -1, 0), 0, carrier, up, facing), Vector3.new(5, 0, -60))
		-- Riding up a wall whose face looks along +X: across that face, whatever leans into it.
		local wall = Vector3.xAxis
		Fixtures.expectNear(
			Throw.rolled(throw, Vector3.new(1, 0, -1), 1, Vector3.new(20, 30, 0), wall, Vector3.yAxis),
			Vector3.new(0, 15, -160)
		)
	end)
end)
