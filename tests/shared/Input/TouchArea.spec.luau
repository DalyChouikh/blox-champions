--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local TouchArea = require(ReplicatedStorage.Shared.Input.TouchArea)

local touch = Config.defaults().Input.touch
local PHONE, BIG = Fixtures.PHONE, Fixtures.BIG_SCREEN

describe("TouchArea", function()
	it("grows the stick and the buttons only on a screen whose shorter side exceeds bigScreenSide", function()
		local phone, tablet, edge = Vector2.new(750, 381), Vector2.new(1280, 800), Vector2.new(1000, 500)
		expect(TouchArea.stickScale(touch, phone)).toBe(1)
		expect(TouchArea.buttonScale(touch, phone)).toBe(1)
		expect(TouchArea.stickScale(touch, tablet)).toBe(touch.bigScreenStickScale)
		expect(TouchArea.buttonScale(touch, tablet)).toBe(touch.bigScreenButtonScale)
		expect(TouchArea.stickScale(touch, edge)).toBe(1)
		expect(TouchArea.buttonScale(touch, edge)).toBe(1)
	end)

	it("measures how far the buttons reach in from the screen's right edge", function()
		-- The leftmost buttons (Attach, Brake) are centred 210 px in; each is 72 px wide.
		expect(TouchArea.reach(touch, 1)).toBe(246)
		expect(TouchArea.reach(touch, 1.5)).toBe(369)
	end)

	it("gives the stage: the HUD's area left of the touch buttons", function()
		expect(TouchArea.stage(touch, PHONE.hud, PHONE.controls)).toEqual(Vector2.new(504, 323))
		-- A touch area that ends 50 px before the HUD's right edge: the buttons sit 50 px further in.
		expect(TouchArea.stage(touch, PHONE.hud, Rect.new(0, -58, 700, 323))).toEqual(Vector2.new(454, 323))
		-- A big screen: the buttons grow 1.5 times.
		expect(TouchArea.stage(touch, BIG.hud, BIG.controls)).toEqual(Vector2.new(911, 742))
		-- Not known yet.
		expect(TouchArea.stage(touch, Rect.new(0, 0, 0, 0), Rect.new(0, 0, 0, 0))).toEqual(Vector2.zero)
	end)
end)
