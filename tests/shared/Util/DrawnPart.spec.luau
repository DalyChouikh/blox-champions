--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local DrawnPart = require(ReplicatedStorage.Shared.Util.DrawnPart)

describe("DrawnPart", function()
	it("makes a part in its shape that only draws, anchored, casting no shadow, hidden until shown", function()
		local part = DrawnPart("Glow", Enum.PartType.Ball)
		expect(part.Name).toBe("Glow")
		expect(part.Shape).toBe(Enum.PartType.Ball)
		expect(part.Anchored).toBe(true)
		expect(part.CastShadow).toBe(false)
		expect(part.Transparency).toBe(1)
		expect(part.CanCollide or part.CanQuery or part.CanTouch).toBe(false)
		-- Where it goes is the caller's.
		expect(part.Parent).toBeNil()
		part:Destroy()
	end)
end)
