--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)

-- Round sizes of this spec's own: S2 reaches (2 x 100 + 120 + 2 x 10) / 2 = 170 px either side of its centre; S5's
-- row (2 x 50 + 80 + 2 x 10) / 2 = 100, and the worth chip 10 + 40 more beside either end: 150. Look C's boxes ink 2 px
-- round them and 3 more below (5 below a box), lettering 2; the worth chip at most 1.5 times its size. A banner's
-- ink reaches 2 + 3 = 5 px round its text on a desktop (2 + 2 = 4 on a phone), its shadow 3 px lower.
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
				banner = {
					height = 0.2,
					clearance = 3,
					bottom = 20,
					sizes = { headline = 40, goal = 60, lap = 30, message = 20, edge = 3 },
					compactSizes = { headline = 24, goal = 36, lap = 18, message = 14, edge = 2 },
				},
				feed = {
					clearance = 4,
					sizes = { height = 20, corner = UDim.new(0, 5), inset = 5, textSize = 12 },
					compactSizes = { height = 16, corner = UDim.new(0, 4), inset = 4, textSize = 10 },
				},
				-- The TAB board: a desktop box 500 + 2 x 2 px wide with its ink, a phone's 400 + 4; under a SCORES
				-- button 10 px down and 30 tall on touch; a key cap 30 px tall for Switch team.
				scoreTab = {
					margin = 4,
					sizes = {
						width = 500,
						side = 10,
						gap = 5,
						avatar = 20,
						column = 50,
						rowHeight = 30,
						textSize = 20,
						headHeight = 20,
						headSize = 12,
						barHeight = 25,
						barSize = 15,
						switchGap = 10,
						switchSize = 16,
					},
					compactSizes = {
						width = 400,
						side = 8,
						gap = 4,
						avatar = 16,
						column = 40,
						rowHeight = 20,
						textSize = 16,
						headHeight = 12,
						headSize = 10,
						barHeight = 22,
						barSize = 14,
						switchGap = 4,
						switchSize = 12,
					},
				},
				scoreButton = { top = 10, size = UDim2.fromOffset(80, 30), corner = UDim.new(0, 5), textSize = 14 },
				hints = { cap = { height = 30 } },
				getUp = {
					sizes = {
						bottom = 90,
						gap = 5,
						wordsGap = 10,
						textSize = 30,
						cap = { height = 40, padding = 5, corner = UDim.new(0, 8), textSize = 20, dropShadow = true },
					},
					compactSizes = {
						bottom = 60,
						gap = 4,
						wordsGap = 8,
						textSize = 20,
						cap = { height = 30, padding = 4, corner = UDim.new(0, 6), textSize = 14, dropShadow = true },
					},
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

	-- What the banner line and the TAB board keep clear of: the board's deepest ink in play, from the safe area's top.
	it("tells how far down the safe area the board's ink reaches in play, with the period or without", function()
		-- S2 8 px down: 8 + 117.5, or 8 + 132 with the period; S5: 8 + 50, or 8 + 68.
		expect(HudScreen.boardBottom(config, false, 8, false)).toBe(125.5)
		expect(HudScreen.boardBottom(config, false, 8, true)).toBe(140)
		expect(HudScreen.boardBottom(config, true, 8, false)).toBe(58)
		expect(HudScreen.boardBottom(config, true, 8, true)).toBe(76)
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

	-- #356 (the owner, Q210): GOAL! big, a completed lap and the goal message smaller, the rest at the headline's.
	it("gives each banner its text size on a phone's screen or a desktop's", function()
		local banner = config.UI.hud.layout.banner
		expect(HudScreen.banners(config, false)).toEqual(banner.sizes)
		expect(HudScreen.banners(config, true)).toEqual(banner.compactSizes)
		expect(HudScreen.bannerSize(config, false, "Goal")).toBe(60)
		expect(HudScreen.bannerSize(config, false, "Lap")).toBe(30)
		expect(HudScreen.bannerSize(config, false, "GoalOpen")).toBe(20)
		for _, kind: any in { "Go", "Denied", "ClockWarning", "LastChance", "Overtime" } do
			expect(HudScreen.bannerSize(config, false, kind)).toBe(40)
		end
		expect(HudScreen.bannerSize(config, true, "Goal")).toBe(36)
		expect(HudScreen.bannerSize(config, true, "Go")).toBe(24)
	end)

	-- RC's GO a fifth of the way down (Video 31), lower where a banner's ink would come within 3 px of the board's
	-- deepest ink in play (Q203's rule; Q210).
	it("centres the banner line a share down the whole screen, lower just enough to clear the board", function()
		-- 0.2 of 793; on the phone 0.2 of the whole 401 px, which starts 20 px above the safe area.
		local desktop = Rect.new(0, -58, 1556, 735)
		expect(HudScreen.bannerAt(config, desktop, desktop)).toBeCloseTo(158.6, 4)
		expect(HudScreen.bannerAt(config, Rect.new(-62, -78, 812, 323), Rect.new(0, -58, 750, 323))).toBeCloseTo(
			60.2,
			4
		)
		-- At 158.6, rounded up; the board in play needs 8 + 117.5 + 3 + 5 + 40 / 2 = 153.5: no move.
		expect(HudScreen.bannerLine(config, false, 158.6, 8, false, 40)).toBe(159)
		-- GOAL!'s 60 px: 8 + 117.5 + 3 + 5 + 30 = 163.5, rounded up; with the period 8 + 132 + 3 + 5 + 20 = 168.
		expect(HudScreen.bannerLine(config, false, 158.6, 8, false, 60)).toBe(164)
		expect(HudScreen.bannerLine(config, false, 158.6, 8, true, 40)).toBe(168)
		-- The phone at 60.2: S5 in play needs 8 + 50 + 3 + 4 + 12 = 77.
		expect(HudScreen.bannerLine(config, true, 60.2, 8, false, 24)).toBe(77)
	end)

	-- The goal message where the feed was, the feed above it (the owner, Q211).
	it("puts the goal message at the stage's bottom and the feed above it, a clearance apart", function()
		-- Its text's bottom: 20 + the shadow's 3 + the ink's 5 = 28 up; the feed's: 28 + 20 + 5 + 3 = 56.
		expect(HudScreen.messageBottom(config, false)).toBe(28)
		expect(HudScreen.feedBottom(config, false)).toBe(56)
		-- The phone's: 20 + 3 + 4 = 27, and 27 + 14 + 4 + 3 = 48.
		expect(HudScreen.messageBottom(config, true)).toBe(27)
		expect(HudScreen.feedBottom(config, true)).toBe(48)
	end)

	-- The feed's chips (#369, the owner's Q221): each a box and its ink (outline each side, shadow below), `clearance`
	-- apart. Over no lines the feed takes no room.
	it("tells how tall the feed's chips stand, on each kind of screen", function()
		expect(HudScreen.feedSizes(config, false).height).toBe(20)
		expect(HudScreen.feedSizes(config, true).height).toBe(16)
		expect(HudScreen.feedHeight(config, false, 0)).toBe(0)
		-- 20 + 2 × 2 + 3 = 27 a chip.
		expect(HudScreen.feedHeight(config, false, 1)).toBe(27)
		-- 3 × 27 + 2 × 4.
		expect(HudScreen.feedHeight(config, false, 3)).toBe(89)
		-- 16 + 2 × 2 + 3 = 23 a chip: 2 × 23 + 4.
		expect(HudScreen.feedHeight(config, true, 2)).toBe(50)
	end)

	-- The prompt stays where it is drawn until the feed's chips reach it, then stands clear above them: it never covers
	-- them (a plain place would, with a line or two).
	it("puts the Get Up prompt at its place, or just over the feed where that reaches higher", function()
		expect(HudScreen.getUpSizes(config, false).textSize).toBe(30)
		expect(HudScreen.getUpSizes(config, true).textSize).toBe(20)
		-- No line: 56 + 0 + 4 = 60, under the prompt's 90. One: 56 + 27 + 4 = 87, still under it. Two: 56 + 58 + 4.
		expect(HudScreen.getUpBottom(config, false, 0)).toBe(90)
		expect(HudScreen.getUpBottom(config, false, 1)).toBe(90)
		expect(HudScreen.getUpBottom(config, false, 2)).toBe(118)
		-- The phone: no line 48 + 4 = 52, under its 60; one: 48 + 23 + 4 = 75.
		expect(HudScreen.getUpBottom(config, true, 0)).toBe(60)
		expect(HudScreen.getUpBottom(config, true, 1)).toBe(75)
	end)

	-- The end screen (#358, the owner's Q243): the result in GOAL!'s lettering, the MVP's card, the totals, then the
	-- TAB board's table, a gap apart.
	it("knows the end screen's sizes and how tall its parts stand, a gap apart", function()
		expect(HudScreen.endSizes(config, false)).toEqual(config.UI.hud.layout.endScreen.sizes)
		expect(HudScreen.endSizes(config, true)).toEqual(config.UI.hud.layout.endScreen.compactSizes)
		-- GOAL!'s 60 in its 5 px ink and 3 px shadow: 73; the card 44 + 2 x 12 in its 7 px of ink: 75; the totals
		-- 34 + 7: 41; the table's header 20 and six rows' 230, + 7: 257; three 16 px gaps.
		expect(HudScreen.endHeight(config, false, 6, true, true)).toBe(494)
		-- No MVP and no table: 73 + 16 + 41.
		expect(HudScreen.endHeight(config, false, 6, false, false)).toBe(130)
		-- A phone's: 36 + 2 x 4 + 3, then 40 + 2 x 10 + 7 and 28 + 7, two gaps.
		expect(HudScreen.endHeight(config, true, 2, true, false)).toBe(181)
		-- With a keyboard there, the table too at the desktop's sizes: 181 + 16 + 20 + 110 + 7.
		expect(HudScreen.endHeight(config, true, 2, true, true)).toBe(334)
	end)

	-- The end screen's dim (the page's half-see-through ink) fades in with its pop, staying put through the overshoot.
	it("fades the end screen's dim in with its pop", function()
		local dim = config.UI.hud.layout.endScreen.dim
		expect(HudScreen.endDim(config, 0)).toBe(1)
		expect(HudScreen.endDim(config, 0.5)).toBeCloseTo(1 - (1 - dim) / 2, 6)
		expect(HudScreen.endDim(config, 1)).toBeCloseTo(dim, 6)
		expect(HudScreen.endDim(config, 1.08)).toBeCloseTo(dim, 6)
	end)

	-- One compact table on either kind of screen, at its own sizes (#357, the owner's Q237).
	it("gives the TAB board's sizes for a phone's screen or a desktop's", function()
		expect(HudScreen.tabSizes(config, false).width).toBe(500)
		expect(HudScreen.tabSizes(config, true).width).toBe(400)
	end)

	-- Under the scoreboard, whose ink it never covers (Q203's rule; its margin keeps the clearance), and on a phone
	-- under the SCORES button too, which stays above it (Q234, Q236).
	it("puts the TAB board's area under the scoreboard's ink, and on touch under the SCORES button too", function()
		-- The board's ink 12.5 px into the HUD's area: whole pixels, rounded up; above the area (or none), its top.
		expect(HudScreen.tabTop(config, false, 12.5)).toBe(13)
		expect(HudScreen.tabTop(config, false, -20)).toBe(0)
		-- The SCORES button 10 px down and 30 tall, unless the board's ink reaches lower.
		expect(HudScreen.tabTop(config, true, 12.5)).toBe(40)
		expect(HudScreen.tabTop(config, true, 44.5)).toBe(45)
	end)

	it("knows how tall the TAB board's teams and its Switch team row stand", function()
		-- Both bars always, then the rows: 2 x 25 + 6 x 30; on the phone 2 x 22 + 3 x 20.
		expect(HudScreen.tabBody(config, false, 6)).toBe(230)
		expect(HudScreen.tabBody(config, true, 3)).toBe(104)
		expect(HudScreen.tabBody(config, false, 0)).toBe(50)
		-- None; the label alone (touch) in its ink, 10 + 16 + 2 x 2; a key cap beside it, 10 + 30.
		expect(HudScreen.tabSwitch(config, false, nil)).toBe(0)
		expect(HudScreen.tabSwitch(config, false, "Label")).toBe(30)
		expect(HudScreen.tabSwitch(config, false, "Key")).toBe(40)
		-- The phone: 4 + 12 + 4; with a key 4 + 30.
		expect(HudScreen.tabSwitch(config, true, "Label")).toBe(20)
		expect(HudScreen.tabSwitch(config, true, "Key")).toBe(34)
		-- Words taller than the key's cap: the row stands as tall as the words in their ink, 10 + 36 + 2 x 2.
		local tall = Fixtures.config({
			UI = {
				hud = {
					look = { textOutline = 2 },
					layout = { hints = { cap = { height = 30 } }, scoreTab = { sizes = { switchSize = 36 } } },
				},
			},
		})
		expect(HudScreen.tabSwitch(tall, false, "Key")).toBe(50)
	end)

	-- The owner's Q190: on phones the board scrolls when its rows do not fit. Off touch its key is held, so nothing
	-- could scroll it: it shrinks to fit, as the HUD's other panels do.
	it("shrinks the TAB board only to fit off touch, and scrolls its rows on touch where they do not fit", function()
		-- Desktop, six rows and the key: 7 px of ink + the 20 px header + 40 for Switch team, over 230 of teams, in a
		-- 504 px box with its ink; 4 px kept clear of each edge.
		local scale, rows = HudScreen.tabFit(config, false, false, Vector2.new(1000, 600), 6, "Key")
		expect(scale).toBe(1)
		expect(rows).toBe(230)
		scale, rows = HudScreen.tabFit(config, false, false, Vector2.new(1000, 250), 6, "Key")
		expect(scale).toBeCloseTo(242 / 297, 5)
		expect(rows).toBe(230)
		scale = HudScreen.tabFit(config, false, false, Vector2.new(400, 600), 6, "Key")
		expect(scale).toBeCloseTo(392 / 504, 5)
		-- A phone, six rows and the label: 7 + 12 + 20 fixed over 164 of teams. 200 px tall shows 192 - 39 of them.
		scale, rows = HudScreen.tabFit(config, true, true, Vector2.new(750, 200), 6, "Label")
		expect(scale).toBe(1)
		expect(rows).toBe(153)
		scale, rows = HudScreen.tabFit(config, true, true, Vector2.new(750, 300), 6, "Label")
		expect(scale).toBe(1)
		expect(rows).toBe(164)
		-- Too narrow for its 404 px: it shrinks to (300 - 8) / 404, which leaves room for every row.
		scale, rows = HudScreen.tabFit(config, true, true, Vector2.new(300, 200), 6, "Label")
		expect(scale).toBeCloseTo(292 / 404, 5)
		expect(rows).toBe(164)
		-- Not even its fixed parts fit: it shrinks to them, and shows no rows.
		scale, rows = HudScreen.tabFit(config, true, true, Vector2.new(750, 30), 6, "Label")
		expect(scale).toBeCloseTo(22 / 39, 5)
		expect(rows).toBeCloseTo(0, 5)
		-- Not even its margins fit: nothing shows.
		scale, rows = HudScreen.tabFit(config, true, true, Vector2.new(750, 8), 6, "Label")
		expect(scale).toBe(0)
		expect(rows).toBe(0)
		-- Shrunk for its width, the room its teams get falls between pixels: whole pixels of it, (120 - 8) / (292 /
		-- 404) - 39 = 115.96 -> 115.
		scale, rows = HudScreen.tabFit(config, true, true, Vector2.new(300, 120), 6, "Label")
		expect(scale).toBeCloseTo(292 / 404, 5)
		expect(rows).toBe(115)
		-- Before the area is known: its own size, every row.
		scale, rows = HudScreen.tabFit(config, true, true, Vector2.zero, 6, "Label")
		expect(scale).toBe(1)
		expect(rows).toBe(164)
	end)

	-- The defaults the page drew (#357): a 3-a-side board fits a phone's screen under SCORES without scrolling, at its
	-- full size; at 6 a side its rows scroll; on our desktop Play view 6 a side fits whole.
	it("fits the default TAB board under a phone's SCORES at 3 a side, scrolling at 6, and whole on desktop", function()
		local defaults = Fixtures.config()
		-- The phone emulator's HUD area, 750 x 323, under the SCORES button.
		local height = 323 - HudScreen.tabTop(defaults, true, 0)
		local area = Vector2.new(750, height)
		local scale, rows = HudScreen.tabFit(defaults, true, true, area, 6, "Label")
		expect(scale).toBe(1)
		expect(rows).toBe(HudScreen.tabBody(defaults, true, 6))
		scale, rows = HudScreen.tabFit(defaults, true, true, area, 12, "Label")
		expect(scale).toBe(1)
		expect(rows < HudScreen.tabBody(defaults, true, 12)).toBe(true)
		-- Switch team's words in look C's 2.5 px ink, whole pixels each side: 4 + 15 + 2 x 3.
		expect(HudScreen.tabSwitch(defaults, true, "Label")).toBe(25)
		-- Our desktop Play view, 1556 x 793 under Roblox's 58 px top bar.
		scale, rows = HudScreen.tabFit(defaults, false, false, Vector2.new(1556, 735), 12, "Key")
		expect(scale).toBe(1)
		expect(rows).toBe(HudScreen.tabBody(defaults, false, 12))
	end)
end)
