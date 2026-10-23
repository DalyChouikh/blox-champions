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

	it("accepts each action's exact shape and rejects anything else", function()
		local accepted: { any } = {
			{ action = "Tackle" },
			{ action = "CallPass" },
			{ action = "Pass", aim = Vector3.new(0, 0, -1) },
			{ action = "ChargeThrow", aim = Vector3.new(1, 0, 0), charge = 0.5 },
		}
		for _, payload in accepted do
			expect(Schemas.ActionRequest(payload, "ActionRequest")).toEqual({})
		end
		local rejected: { any } = {
			{ action = "Tackle", aim = Vector3.zero },
			{ action = "Pass" },
			{ action = "Pass", aim = Vector3.zero },
			{ action = "ChargeThrow", aim = Vector3.new(0 / 0, 0, 0), charge = 0.5 },
			{ action = "ChargeThrow", aim = Vector3.xAxis, charge = 5 },
			{ action = "Fly" },
			"Tackle",
		}
		for _, payload in rejected do
			expect(#Schemas.ActionRequest(payload, "ActionRequest") > 0).toBe(true)
		end
	end)
end)
