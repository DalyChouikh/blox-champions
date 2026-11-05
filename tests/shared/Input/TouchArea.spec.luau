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

	it("measures how far the buttons reach in from the screen's right edge, each by its own size", function()
		-- Brake, the leftmost, is centred 235 px in and 58 px wide.
		expect(TouchArea.reach(touch, 1)).toBe(264)
		expect(TouchArea.reach(touch, 1.5)).toBe(396)
		-- A wider Pass (80 px, centred 225 px in) reaches further, though Brake's centre is further in.
		local wide = Fixtures.config({ Input = { touch = { buttons = { pass = { size = 80 } } } } }).Input.touch
		expect(TouchArea.reach(wide, 1)).toBe(265)
	end)

	it("measures how far in from the screen's right edge the buttons start", function()
		-- Jump, centred 70 px in and 96 px wide (the owner's Q249: 22 px from the edge).
		expect(TouchArea.inset(touch, 1)).toBe(22)
		expect(TouchArea.inset(touch, 1.5)).toBe(33)
		-- A wider Pump (110 px, centred 60 px in, up above Attach) starts nearer the edge than Jump.
		local wide = Fixtures.config({
			Input = { touch = { buttons = { pump = { place = UDim2.new(1, -60, 1, -330), size = 110 } } } },
		}).Input.touch
		expect(TouchArea.inset(wide, 1)).toBe(5)
	end)

	-- The buttons sit at the whole screen's corner (#355, the owner's Q246, Q249), past a notched phone's safe area.
	it("gives the stage: the HUD's area left of the touch buttons", function()
		-- The whole phone screen ends 62 px right of the HUD's area: 812 - 264 = 548.
		expect(TouchArea.stage(touch, PHONE.hud, PHONE.whole)).toEqual(Vector2.new(548, 323))
		-- A screen that ends 50 px nearer: the buttons sit 50 px further in.
		expect(TouchArea.stage(touch, PHONE.hud, Rect.new(-62, -78, 762, 323))).toEqual(Vector2.new(498, 323))
		-- A HUD's area starting 10 px in: the stage starts there too.
		expect(TouchArea.stage(touch, Rect.new(10, 0, 750, 323), PHONE.whole)).toEqual(Vector2.new(538, 323))
		-- A big screen, measured whole (1280 x 800): the buttons grow 1.5 times.
		expect(TouchArea.stage(touch, BIG.hud, BIG.whole)).toEqual(Vector2.new(884, 742))
		-- Big by its size (1012 x 623), though its bottom-right corner sits at (812, 323): 812 - 396.
		expect(TouchArea.stage(touch, PHONE.hud, Rect.new(-200, -300, 812, 323))).toEqual(Vector2.new(416, 323))
		-- A wide screen whose buttons leave more than the HUD's area: the whole of that area, 740 px from its left
		-- edge.
		local wide = Rect.new(-62, -78, 1100, 323)
		expect(TouchArea.stage(touch, Rect.new(10, 0, 750, 323), wide)).toEqual(Vector2.new(740, 323))
		-- Not known yet.
		expect(TouchArea.stage(touch, Rect.new(0, 0, 0, 0), Rect.new(0, 0, 0, 0))).toEqual(Vector2.zero)
	end)

	-- SCORES lines up with the buttons' right edge (#355, the owner's Q250), though it sits in the HUD's area.
	it("gives where the buttons' right edge sits across the HUD's area", function()
		expect(TouchArea.lineUp(touch, PHONE.hud, PHONE.whole)).toBe(790)
		expect(TouchArea.lineUp(touch, Rect.new(10, 0, 750, 323), PHONE.whole)).toBe(780)
		expect(TouchArea.lineUp(touch, BIG.hud, BIG.whole)).toBe(1247)
	end)
end)
