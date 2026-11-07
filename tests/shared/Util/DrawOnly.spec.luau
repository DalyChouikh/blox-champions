--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local DrawOnly = require(ReplicatedStorage.Shared.Util.DrawOnly)

describe("DrawOnly", function()
	it("leaves a part only drawing: nothing collides with it, touches it or finds it by a ray", function()
		local part = Instance.new("Part")
		expect(part.CanCollide and part.CanQuery and part.CanTouch).toBe(true)
		expect(DrawOnly(part)).toBe(part)
		expect(part.CanCollide).toBe(false)
		expect(part.CanQuery).toBe(false)
		expect(part.CanTouch).toBe(false)
		-- The rest of it is the caller's: it still shows, and stays as anchored as it was.
		expect(part.Transparency).toBe(0)
		expect(part.Anchored).toBe(false)
		part:Destroy()
	end)
end)
