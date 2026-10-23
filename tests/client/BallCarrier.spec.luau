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

	it("predicts the ball leaving, and undoes it unless the server has spoken since", function()
		BallCarrier:init({})
		BallCarrier:set("A")
		BallCarrier:predictRelease()
		expect(BallCarrier.carrier).toBeNil()
		BallCarrier:undoPrediction()
		expect(BallCarrier.carrier).toBe("A")
		-- Undone once, nothing is left to undo.
		BallCarrier:set(nil)
		BallCarrier:undoPrediction()
		expect(BallCarrier.carrier).toBeNil()
		-- The server spoke in between: its word stands.
		BallCarrier:set("A")
		BallCarrier:predictRelease()
		BallCarrier:set("B")
		BallCarrier:undoPrediction()
		expect(BallCarrier.carrier).toBe("B")
	end)
end)
