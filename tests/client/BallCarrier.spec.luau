--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local BallCarrier = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.BallCarrier)

describe("BallCarrier", function()
	it("remembers who carries the ball", function()
		BallCarrier:init({})
		expect(BallCarrier.carrier).toBeNil()
		BallCarrier:set("A")
		expect(BallCarrier.carrier).toBe("A")
		BallCarrier:set(nil)
		expect(BallCarrier.carrier).toBeNil()
	end)
end)
