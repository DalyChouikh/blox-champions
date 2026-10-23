--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it = JestGlobals.describe, JestGlobals.it

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local TouchStick = require(ReplicatedStorage.Shared.Input.TouchStick)

local ORIGIN = Vector2.new(100, 100)

describe("TouchStick", function()
	it("turns a touch's offset into a stick, with a dead zone and full speed at the radius", function()
		-- Screen y grows downward; the stick's y is forward.
		Fixtures.expectNear2(TouchStick.vector(ORIGIN, Vector2.new(100, 90), 2, 20), Vector2.new(0, 0.5))
		Fixtures.expectNear2(TouchStick.vector(ORIGIN, Vector2.new(100, 60), 2, 20), Vector2.new(0, 1))
		Fixtures.expectNear2(TouchStick.vector(ORIGIN, Vector2.new(101, 101), 2, 20), Vector2.zero)
		Fixtures.expectNear2(TouchStick.vector(ORIGIN, Vector2.new(115, 100), 2, 20), Vector2.new(0.75, 0))
	end)
end)
