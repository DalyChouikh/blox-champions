--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)

-- Round sizes of this spec's own: S2 reaches (2 x 100 + 120 + 2 x 10) / 2 = 170 px either side of its centre; S5's
-- row (2 x 50 + 80 + 2 x 10) / 2 = 100, and the worth chip 10 + 40 more beside either end: 150. Look C's boxes ink 2 px
-- round them and 3 more below (5 below a box), lettering 2; the worth chip at most 1.5 times its size.
local config = Fixtures.config({
	UI = {
		hud = {
			look = { outline = 2, shadow = 3, textOutline = 2 },
			motion = { pop = { overshoot = 0.1 }, bounce = { scale = 1.5 } },
			layout = {
				compactBelow = 500,
				scoreboard = {
					position = UDim2.new(0.5, 0, 0, 8),
					shield = UDim2.fromOffset(100, 60),
					clock = UDim2.fromOffset(120, 50),
					worth = UDim2.fromOffset(60, 40),
					lapChip = 20,
					gap = 10,
					chipClearance = 4,
					textSizes = { score = 40, clock = 30, worth = 20, period = 20 },
				},
				compactScoreboard = {
					position = UDim2.new(0.5, 0, 0, 8),
					score = UDim2.fromOffset(50, 40),
					clock = UDim2.fromOffset(80, 40),
					worth = UDim2.fromOffset(40, 30),
					gap = 10,
					textSizes = { score = 30, clock = 30, worth = 20, period = 16 },
				},
				reticle = {
					height = 0.3,
					clearance = 3,
					sizes = { carry = 50, charge = 100, thickness = 4 },
					compactSizes = { carry = 24, charge = 40, thickness = 3 },
				},
				countdown = {
					sizes = { textSize = 60, ringSize = 120, ringThickness = 8 },
					compactSizes = { textSize = 30, ringSize = 60, ringThickness = 4 },
				},
			},
		},
	},
})

-- Our desktop Play view's top bar (probed: GuiService.TopbarInset, Roblox's buttons left of 164 px).
local DESKTOP_BAR = Rect.new(164, 0, 1556, 58)

-- A desktop board of this spec's sizes with its own `motion` and lap chips `lapChip` pixels across.
local function desktopBoard(motion: { [string]: any }, lapChip: number)
	return Fixtures.config({
		UI = {
			hud = {
				look = { outline = 2, shadow = 3, textOutline = 2 },
				motion = motion,
				layout = {
					scoreboard = {
						shield = UDim2.fromOffset(100, 60),
						clock = UDim2.fromOffset(120, 50),
						worth = UDim2.fromOffset(60, 40),
						lapChip = lapChip,
						gap = 10,
						chipClearance = 4,
						textSizes = { score = 40, clock = 30, worth = 20, period = 20 },
					},
				},
			},
		},
	})
end

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

	it("steps a box under another so their inks stay a clearance apart", function()
		-- The upper ink reaches 2 + 3 below its box, the lower's 2 above its own: 4 px clear at an 11 px step.
		expect(HudScreen.under(config, 4)).toBe(11)
		expect(HudScreen.under(config, 0)).toBe(7)
	end)

	-- The 3D view and the reticle's gui are centred on the whole screen; a notched phone's safe area starts 20 px below
	-- its top (probed: GetInsetArea None (-62, -78, 812, 323), DeviceSafeInsets (0, -58, 750, 323)).
	it("finds the crosshair's aim from the safe area's top, a share of the way down the whole screen", function()
		-- 0.3 of 401 = 120.3 down the whole screen, which starts 20 above the safe area.
		local phone = HudScreen.aim(config, Rect.new(-62, -78, 812, 323), Rect.new(0, -58, 750, 323))
		expect(phone).toBeCloseTo(100.3, 4)
		-- On a desktop both are the same: 0.3 of 793.
		expect(HudScreen.aim(config, Rect.new(0, -58, 1556, 735), Rect.new(0, -58, 1556, 735))).toBeCloseTo(237.9, 4)
	end)

	it("gives the crosshair's and the count's sizes for a phone's screen or a desktop's", function()
		local layout = config.UI.hud.layout
		expect(HudScreen.rings(config, false)).toEqual(layout.reticle.sizes)
		expect(HudScreen.rings(config, true)).toEqual(layout.reticle.compactSizes)
		expect(HudScreen.count(config, false)).toEqual(layout.countdown.sizes)
		expect(HudScreen.count(config, true)).toEqual(layout.countdown.compactSizes)
	end)

	-- S2 here: shields 60 + 5 = 65 deep; in play the lap chips 60 + 11 + 20 + 5 = 96 and the worth chip, centred
	-- 50 + 10 + 20 down, 1.5 x (20 + 5) below that: 117.5; the period under the clock 50 + 10 + 20 + 2 = 82, or in
	-- play under the worth chip's place 50 + 10 + 40 + 10 + 20 + 2 = 132.
	it("knows how deep the desktop's board reaches at a kickoff and in play, with the period or without", function()
		expect(HudScreen.boardDepth(config, false, false, false)).toBe(65)
		expect(HudScreen.boardDepth(config, false, true, false)).toBe(82)
		expect(HudScreen.boardDepth(config, false, false, true)).toBe(117.5)
		expect(HudScreen.boardDepth(config, false, true, true)).toBe(132)
		-- A pop that overshoots more than the bounce grows the worth chip widest: 80 + 1.2 x 25 = 110.
		local popping = desktopBoard({ pop = { overshoot = 0.2 }, bounce = { scale = 1 } }, 20)
		expect(HudScreen.boardDepth(popping, false, false, true)).toBeCloseTo(110, 6)
		-- Lap chips 50 px across reach deepest: 60 + 11 + 50 + 5 = 126, past the worth chip's 117.5.
		local tallChips = desktopBoard({ pop = { overshoot = 0.1 }, bounce = { scale = 1.5 } }, 50)
		expect(HudScreen.boardDepth(tallChips, false, false, true)).toBe(126)
	end)

	-- S5 here: the row 40 + 5 = 45 deep; in play the worth chip beside it, centred 20 down, 1.5 x (15 + 5) below that:
	-- 50; the period under the row 40 + 10 + 16 + 2 = 68.
	it("knows how deep the phone's board reaches at a kickoff and in play, with the period or without", function()
		expect(HudScreen.boardDepth(config, true, false, false)).toBe(45)
		expect(HudScreen.boardDepth(config, true, true, false)).toBe(68)
		expect(HudScreen.boardDepth(config, true, false, true)).toBe(50)
		expect(HudScreen.boardDepth(config, true, true, true)).toBe(68)
	end)

	-- The charge ring's ink reaches 100 / 2 + 2 = 52 px round the dot here (the phone's 40 / 2 + 2 = 22); the room is
	-- from the board's lowest ink in play to the aim, less a 3 px clearance.
	it("shrinks the crosshair's rings just enough to clear the board in play, the dot staying put", function()
		-- 237.9 - 8 - 117.5 - 3 = 109.4 px: room to spare.
		expect(HudScreen.ringScale(config, false, 8, 237.9, false)).toBe(1)
		-- A short window: 160 - 8 - 117.5 - 3 = 31.5 px, and 17 with the period showing.
		expect(HudScreen.ringScale(config, false, 8, 160, false)).toBeCloseTo(31.5 / 52, 6)
		expect(HudScreen.ringScale(config, false, 8, 160, true)).toBeCloseTo(17 / 52, 6)
		-- The phone: 100.3 - 8 - 50 - 3 = 39.3 px, but 21.3 with the period under the row.
		expect(HudScreen.ringScale(config, true, 8, 100.3, false)).toBe(1)
		expect(HudScreen.ringScale(config, true, 8, 100.3, true)).toBeCloseTo(21.3 / 22, 6)
		-- A board reaching past the aim leaves no room.
		expect(HudScreen.ringScale(config, false, 8, 100, false)).toBe(0)
	end)

	-- The count's ring ink reaches 120 / 2 + 2 = 62 px round its centre here (the phone's 60 / 2 + 2 = 32); the room is
	-- from the board's lowest ink at a kickoff to the aim, less the clearance. It aims nothing, so it moves down
	-- (the owner, Q203).
	it("moves the kickoff count down just enough to clear the board, and not at all where it fits", function()
		-- 237.9 - 8 - 65 - 3 = 161.9 px: no move.
		expect(HudScreen.countDrop(config, false, 8, 237.9, false)).toBe(0)
		-- 120 - 8 - 65 - 3 = 44 px: 18 lower; with the period 120 - 8 - 82 - 3 = 27: 35 lower.
		expect(HudScreen.countDrop(config, false, 8, 120, false)).toBe(18)
		expect(HudScreen.countDrop(config, false, 8, 120, true)).toBe(35)
		-- The phone at an overtime kickoff: 100.3 - 8 - 68 - 3 = 21.3 px: 10.7 lower, whole pixels rounded up (an
		-- offset holds whole pixels); in regulation 44.3: no move.
		expect(HudScreen.countDrop(config, true, 8, 100.3, true)).toBe(11)
		expect(HudScreen.countDrop(config, true, 8, 100.3, false)).toBe(0)
	end)
end)
