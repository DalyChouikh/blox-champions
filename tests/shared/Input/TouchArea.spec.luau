--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local TouchArea = require(ReplicatedStorage.Shared.Input.TouchArea)

local touch = Config.defaults().Input.touch

-- The emulated iPhone 17 Pro in landscape (probed in Play): the HUD's area (CoreUISafeInsets) and the touch
-- controls' (DeviceSafeInsets), which also spans Roblox's 58 px top bar.
local PHONE_HUD = Rect.new(0, 0, 750, 323)
local PHONE_CONTROLS = Rect.new(0, -58, 750, 323)

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
		expect(TouchArea.stage(touch, PHONE_HUD, PHONE_CONTROLS)).toEqual(Vector2.new(504, 323))
		-- A touch area that ends 50 px before the HUD's right edge: the buttons sit 50 px further in.
		expect(TouchArea.stage(touch, PHONE_HUD, Rect.new(0, -58, 700, 323))).toEqual(Vector2.new(454, 323))
		-- A big screen (its touch area 1280 x 800): the buttons grow 1.5 times.
		local big = TouchArea.stage(touch, Rect.new(0, 0, 1280, 742), Rect.new(0, -58, 1280, 742))
		expect(big).toEqual(Vector2.new(911, 742))
		-- Not known yet.
		expect(TouchArea.stage(touch, Rect.new(0, 0, 0, 0), Rect.new(0, 0, 0, 0))).toEqual(Vector2.zero)
	end)
end)
