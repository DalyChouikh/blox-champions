--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)

-- Round sizes of this spec's own: S2 reaches (2 x 100 + 120 + 2 x 10) / 2 = 170 px either side of its centre; S5's
-- row (2 x 50 + 80 + 2 x 10) / 2 = 100, and the worth chip 10 + 40 more beside either end: 150.
local config = Fixtures.config({
	UI = {
		hud = {
			layout = {
				compactBelow = 500,
				scoreboard = {
					position = UDim2.new(0.5, 0, 0, 8),
					shield = UDim2.fromOffset(100, 90),
					clock = UDim2.fromOffset(120, 50),
					gap = 10,
				},
				compactScoreboard = {
					position = UDim2.new(0.5, 0, 0, 8),
					score = UDim2.fromOffset(50, 40),
					clock = UDim2.fromOffset(80, 40),
					worth = UDim2.fromOffset(40, 30),
					gap = 10,
				},
			},
		},
	},
})

-- Our desktop Play view's top bar (probed: GuiService.TopbarInset, Roblox's buttons left of 164 px).
local DESKTOP_BAR = Rect.new(164, 0, 1556, 58)

describe("HudScreen", function()
	it("calls a screen a phone's when its shorter side is under compactBelow", function()
		expect(HudScreen.compact(config, Vector2.new(750, 381))).toBe(true)
		expect(HudScreen.compact(config, Vector2.new(381, 750))).toBe(true)
		expect(HudScreen.compact(config, Vector2.new(1000, 499.9))).toBe(true)
		expect(HudScreen.compact(config, Vector2.new(1000, 500))).toBe(false)
		expect(HudScreen.compact(config, Vector2.new(1280, 800))).toBe(false)
	end)

	it("knows each scoreboard's width, and how far it reaches either side of its centre", function()
		expect(HudScreen.boardWidth(config, false)).toBe(340)
		expect(HudScreen.boardWidth(config, true)).toBe(200)
		expect(HudScreen.boardReach(config, false)).toBe(170)
		expect(HudScreen.boardReach(config, true)).toBe(150)
	end)

	it("puts the scoreboard in the top bar's free band while it clears Roblox's buttons, else under the bar", function()
		-- Centred on 778: 608..948, inside 164..1556.
		expect(HudScreen.boardTop(config, false, 1556, DESKTOP_BAR)).toBe(8)
		-- Touching the band's edge still clears it.
		expect(HudScreen.boardTop(config, false, 1556, Rect.new(608, 0, 1556, 58))).toBe(8)
		-- Buttons reaching past 608 on the left, or a band ending before 948 on the right: 58 + 8 down.
		expect(HudScreen.boardTop(config, false, 1556, Rect.new(609, 0, 1556, 58))).toBe(66)
		expect(HudScreen.boardTop(config, false, 1556, Rect.new(164, 0, 947, 58))).toBe(66)
		-- No top bar at all (Roblox reports an empty band): 8 from the top, under nothing.
		expect(HudScreen.boardTop(config, false, 1556, Rect.new(0, 0, 0, 0))).toBe(8)
		-- The phone's board, centred on 375: 225..525.
		expect(HudScreen.boardTop(config, true, 750, Rect.new(225, 0, 750, 58))).toBe(8)
		expect(HudScreen.boardTop(config, true, 750, Rect.new(226, 0, 750, 58))).toBe(66)
	end)

	it("centres the scoreboard where its position puts it across the screen", function()
		local moved = Fixtures.config({
			UI = { hud = { layout = { scoreboard = { position = UDim2.new(0.5, 20, 0, 4) } } } },
		})
		-- Centred on 798 with the defaults' 166-px reach (2 x 94 + 120 + 2 x 12, halved): 632..964.
		expect(HudScreen.boardTop(moved, false, 1556, Rect.new(632, 0, 1556, 58))).toBe(4)
		expect(HudScreen.boardTop(moved, false, 1556, Rect.new(633, 0, 1556, 58))).toBe(62)
	end)
end)
