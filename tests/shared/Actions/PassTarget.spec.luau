--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local PassTarget = require(ReplicatedStorage.Shared.Actions.PassTarget)
local Reach = require(ReplicatedStorage.Shared.Actions.Reach)

local actions = Config.defaults().Actions
local pass = actions.Pass.pass :: Config.PassSettings
local WINDOW = actions.callPassWindow
local AIM = Vector3.new(0, 0, -1)
local NOW = 3

local function choose(teammates: { Reach.Candidate }, calls: { [string]: number }): string?
	return PassTarget.choose(pass, WINDOW, Vector3.zero, AIM, teammates, calls, NOW)
end

describe("PassTarget.choose", function()
	it("passes to the latest caller within the window, wherever they are", function()
		local teammates: { Reach.Candidate } = {
			{ player = "Ahead", position = Vector3.new(0, 0, -40) },
			{ player = "Behind", position = Vector3.new(0, 0, 40) },
		}
		expect(choose(teammates, { Ahead = 1, Behind = 2 })).toBe("Behind")
	end)

	it("ignores calls older than the window", function()
		local teammates: { Reach.Candidate } = {
			{ player = "Ahead", position = Vector3.new(0, 0, -40) },
			{ player = "Behind", position = Vector3.new(0, 0, 40) },
		}
		expect(choose(teammates, { Behind = -0.5 })).toBe("Ahead")
	end)

	it("scores teammates by angle and distance inside the cone and range", function()
		-- A: angle 0, 100 studs → 0.6 + 0.0667 = 0.667. B: 45°, 42.4 studs → 0.214 + 0.259 = 0.473.
		local a: Reach.Candidate = { player = "A", position = Vector3.new(0, 0, -100) }
		local b: Reach.Candidate = { player = "B", position = Vector3.new(30, 0, -30) }
		-- Beyond maxRange (120).
		local c: Reach.Candidate = { player = "C", position = Vector3.new(0, 0, -130) }
		expect(choose({ b, a }, {})).toBe("A")
		expect(choose({ b }, {})).toBe("B")
		expect(choose({ c }, {})).toBeNil()
	end)

	it("finds no target outside the cone", function()
		-- 84° off the aim, past the 70° cone.
		local wide: { Reach.Candidate } = { { player = "Wide", position = Vector3.new(100, 0, -10) } }
		expect(choose(wide, {})).toBeNil()
	end)
end)
