--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it = JestGlobals.describe, JestGlobals.it

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Homing = require(ReplicatedStorage.Shared.Ball.Homing)

describe("Homing.step", function()
	it("turns a pass toward its target at homingAccel", function()
		local velocity = Vector3.new(0, 0, -90)
		Fixtures.expectNear(
			Homing.step(Vector3.zero, velocity, Vector3.new(10, 0, 0), 60, 0.5),
			Vector3.new(30, 0, -90)
		)
		-- A ball already at its target keeps its velocity.
		Fixtures.expectNear(Homing.step(Vector3.zero, velocity, Vector3.zero, 60, 0.5), velocity)
	end)
end)
