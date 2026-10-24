--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fit = require(ReplicatedStorage.Shared.Hud.Fit)

local PANEL = UDim2.fromOffset(640, 360)
local MARGIN = 8

describe("Fit", function()
	it("leaves a panel that fits as it is, never larger", function()
		expect(Fit.scale(Vector2.new(1920, 1000), PANEL, MARGIN)).toBe(1)
		expect(Fit.scale(Vector2.new(656, 376), PANEL, MARGIN)).toBe(1)
	end)

	it("shrinks a panel to fit inside the area's margins, keeping its shape", function()
		-- A phone's safe area: the height decides, (323 - 16) / 360.
		expect(Fit.scale(Vector2.new(750, 323), PANEL, MARGIN)).toBeCloseTo(0.85278, 4)
		-- A narrow area: the width decides, (500 - 16) / 640.
		expect(Fit.scale(Vector2.new(500, 1000), PANEL, MARGIN)).toBeCloseTo(0.75625, 4)
	end)

	it("leaves a panel as it is while the area is not known, and never turns it inside out", function()
		expect(Fit.scale(Vector2.zero, PANEL, MARGIN)).toBe(1)
		expect(Fit.scale(Vector2.new(10, 10), PANEL, MARGIN)).toBe(0)
	end)
end)
