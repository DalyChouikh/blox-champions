--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Schemas = require(ReplicatedStorage.Shared.Net.Schemas)

describe("Schemas", function()
	it("accepts a skate state and rejects malformed ones", function()
		expect(#Schemas.SkateState({ pump = true, brake = false }, "SkateState")).toBe(0)
		local malformed: { any } = {
			{ pump = "yes", brake = false },
			{ pump = true },
			{ pump = true, brake = false, speed = 999 },
			"x",
		}
		for _, payload in malformed do
			expect(#Schemas.SkateState(payload, "SkateState") > 0).toBe(true)
		end
	end)
end)
