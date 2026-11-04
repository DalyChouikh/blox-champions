--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Hud = game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud
local Animator = require(Hud.Animator)
local BoardMotion = require(Hud.BoardMotion)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Scoreboard = require(Hud.Scoreboard)

local config = Fixtures.config()
-- The HUD's own team colours (look C, the owner: Q201).
local colors = config.UI.hud.look.teamColors
local layout = config.UI.hud.layout
local text = HudText.new(config)

local folder: Folder
local clock: React.Binding<string>
local setClock: (string) -> ()
local animator: Animator.Animator
local motion: BoardMotion.BoardMotion

-- The scoreboard keyed as App keys it, which names its frame, after its motion has watched the same match; drawn from
-- `own` settings where a test gives its own.
local function board(
	overrides: { [string]: any }?,
	compact: boolean?,
	top: number?,
	own: Config.GameConfig?
): React.ReactElement
	local match = Fixtures.matchSnapshot(overrides).match
	motion:watch(match)
	return React.createElement(React.Fragment, nil, {
		Scoreboard = React.createElement(Scoreboard, {
			config = own or config,
			text = text,
			match = match,
			compact = compact == true,
			top = top or 8,
			clock = clock,
			motion = motion,
		}),
	})
end

-- The scoreboard's part called `name`, wherever it sits inside.
local function part(mounted: Instance, name: string): any
	return (mounted:FindFirstChild("Scoreboard") :: Instance):FindFirstChild(name, true)
end

-- A look C box's colour: its fill's shade at the top.
local function boxColor(box: Instance): Color3
	local gradient = (box:FindFirstChild("Fill1") :: Instance):FindFirstChildOfClass("UIGradient") :: UIGradient
	return gradient.Color.Keypoints[1].Value
end

local function near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 1e-3 and math.abs(a.G - b.G) < 1e-3 and math.abs(a.B - b.B) < 1e-3
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ScoreboardTest"
	folder.Parent = workspace
	clock, setClock = React.createBinding("4:59")
	animator = Animator.new(config.UI.hud.motion)
	motion = BoardMotion.new(text, animator)
end)

afterEach(function()
	Fixtures.unmountAll()
	folder:Destroy()
end)

describe("Scoreboard, S2 Shields on desktop", function()
	it("shows each team's score on its shield either side of the clock, at the top centre", function()
		local mounted = Fixtures.mount(board({ scores = { Blue = 2, Orange = 1 } }, false, 66), folder)
		local frame = mounted:FindFirstChild("Scoreboard") :: Frame
		local sizes = layout.scoreboard
		expect(frame.AnchorPoint == Vector2.new(0.5, 0)).toBe(true)
		expect(frame.Position).toEqual(UDim2.new(0.5, 0, 0, 66))
		expect(part(mounted, "BlueScore").Text).toBe("2")
		expect(part(mounted, "OrangeScore").Text).toBe("1")
		expect(part(mounted, "BlueScore").Font).toBe(config.UI.hud.look.font)
		expect(part(mounted, "BlueScore").TextSize).toBe(sizes.textSizes.score)
		local blue, orange = part(mounted, "BlueShield"), part(mounted, "OrangeShield")
		expect(blue.Size).toEqual(sizes.shield)
		expect(near(boxColor(blue), colors.Blue) and near(boxColor(orange), colors.Orange)).toBe(true)
		-- Blue left of the clock, Orange right of it.
		expect(part(mounted, "Blue").LayoutOrder < part(mounted, "Middle").LayoutOrder).toBe(true)
		expect(part(mounted, "Middle").LayoutOrder < part(mounted, "Orange").LayoutOrder).toBe(true)
		expect(part(mounted, "Clock").Text).toBe("4:59")
		expect(part(mounted, "ClockBox").Size).toEqual(sizes.clock)
		expect(near(boxColor(part(mounted, "ClockBox")), config.UI.hud.look.box)).toBe(true)
		-- A binding writes the label at once, with no new render.
		setClock("4:58")
		expect(part(mounted, "Clock").Text).toBe("4:58")
	end)

	it("shapes each shield from a body with the look's corners over a round tip", function()
		local mounted = Fixtures.mount(board(), folder)
		local shield = part(mounted, "BlueShield")
		-- 94 x 89: the round tip's radius is half the shorter side, 44.5, so the body covers the top 44.5 px.
		expect((shield:FindFirstChild("Fill1") :: Frame).Size.Y.Scale).toBeCloseTo(0.5, 6)
		local tip = (shield:FindFirstChild("Fill2") :: Frame):FindFirstChildOfClass("UICorner") :: UICorner
		expect(tip.CornerRadius).toEqual(UDim.new(0.5, 0))
	end)

	it("bounces a score through its scale as it rises", function()
		local mounted, rerender = Fixtures.mount(board({ scores = { Blue = 0, Orange = 0 } }), folder)
		rerender(board({ scores = { Blue = 1, Orange = 0 } }))
		local scale = part(mounted, "BlueScore"):FindFirstChildOfClass("UIScale") :: UIScale
		animator:step(config.UI.hud.motion.bounce.seconds / 3)
		expect(scale.Scale).toBeCloseTo(config.UI.hud.motion.bounce.scale, 4)
		expect((part(mounted, "OrangeScore"):FindFirstChildOfClass("UIScale") :: UIScale).Scale).toBe(1)
	end)

	it("puts a square lap chip per gate under the team with the ball, each filling from its motion", function()
		local mounted, rerender = Fixtures.mount(board({ possessingTeam = "Orange", lapProgress = 2 }), folder)
		local chips = part(mounted, "LapChips")
		expect(chips.Parent.Name).toBe("Orange")
		local count = 0
		for _, chip in chips:GetChildren() do
			if chip:IsA("Frame") then
				count += 1
				expect(chip.Size).toEqual(UDim2.fromOffset(layout.scoreboard.lapChip, layout.scoreboard.lapChip))
			end
		end
		expect(count).toBe(4)
		local function lit(index: number): Frame
			return (chips:FindFirstChild(tostring(index)) :: Instance):FindFirstChild("Lit", true) :: Frame
		end
		-- How far a chip's lit square has grown, to a millionth: Roblox holds a UIScale at no less than 1e-7 (probed),
		-- and an empty chip's square hides.
		local function grow(index: number): number
			local scale = (lit(index):FindFirstChildOfClass("UIScale") :: UIScale).Scale
			return math.floor(scale * 1e6 + 0.5) / 1e6
		end
		expect({ grow(1), grow(2), grow(3), grow(4) }).toEqual({ 1, 1, 0, 0 })
		expect({ lit(1).Visible, lit(2).Visible, lit(3).Visible, lit(4).Visible }).toEqual({ true, true, false, false })
		local shade = (lit(1):FindFirstChildOfClass("UIGradient") :: UIGradient).Color.Keypoints[1].Value
		expect(near(shade, colors.Orange)).toBe(true)
		-- The next gate eases its chip full.
		rerender(board({ possessingTeam = "Orange", lapProgress = 3 }))
		animator:step(config.UI.hud.motion.easeSeconds)
		expect(grow(3)).toBe(1)
		expect(lit(3).Visible).toBe(true)
		-- Under Blue's shield once Blue has the ball; none while it is loose.
		rerender(board({ possessingTeam = "Blue", lapProgress = 1 }))
		expect(part(mounted, "LapChips").Parent.Name).toBe("Blue")
		rerender(board(nil))
		expect(part(mounted, "LapChips")).toBeNil()
	end)

	it("hangs the lap chips chipClearance clear of the shield's drop shadow (the owner, Q200)", function()
		-- A clearance of this test's own, 5 px: the shield's ink reaches outline + shadow below it (3 + 4) and the
		-- chips' outline 3 above them, so the chips start 15 px under the 94 x 89 shield.
		local own = Fixtures.config({ UI = { hud = { layout = { scoreboard = { chipClearance = 5 } } } } })
		local mounted = Fixtures.mount(board({ possessingTeam = "Orange", lapProgress = 2 }, false, 8, own), folder)
		local column = part(mounted, "Orange")
		expect((column:FindFirstChildOfClass("UIListLayout") :: UIListLayout).Padding).toEqual(UDim.new(0, 15))
		expect(column.Size).toEqual(UDim2.fromOffset(94, 89 + 15 + 17))
	end)

	it("shows the goal's worth in a chip under the clock while the goal is open, in that team's colour", function()
		local mounted, rerender = Fixtures.mount(board({ possessingTeam = "Blue", streak = 0 }), folder)
		local worth = part(mounted, "Worth")
		expect(worth.Parent.Name).toBe("Middle")
		expect(worth.Visible).toBe(false)
		rerender(board({ possessingTeam = "Blue", streak = 2, goalOpenFor = "Blue" }))
		animator:step(config.UI.hud.motion.pop.seconds)
		expect(worth.Visible).toBe(true)
		expect(part(mounted, "WorthText").Text).toBe("+3")
		expect(part(mounted, "WorthText").Font).toBe(config.UI.hud.look.bannerFont)
		expect(near(boxColor(part(mounted, "WorthChip")), colors.Blue)).toBe(true)
		-- Glowing from the moment it opened: its white veil thinnest halfway through a cycle.
		animator:step(config.UI.hud.motion.glow.seconds / 2 - config.UI.hud.motion.pop.seconds)
		local veil = part(mounted, "Glow").BackgroundTransparency
		expect(veil).toBeCloseTo(config.UI.hud.motion.glow.transparency, 4)
		-- A goal closes it: it shrinks away, then hides.
		rerender(board({ possessingTeam = "Blue", streak = 2, scores = { Blue = 3, Orange = 0 } }))
		animator:step(config.UI.hud.motion.easeSeconds)
		expect(worth.Visible).toBe(false)
	end)

	it("says OVERTIME under the clock in overtime, and LAST CHANCE in the trailing team's colour", function()
		local mounted, rerender = Fixtures.mount(board({ period = "Overtime" }), folder)
		local period = part(mounted, "Period")
		expect(period.Parent.Name).toBe("Middle")
		expect(period.Visible).toBe(true)
		expect(period.Text).toBe("OVERTIME")
		expect(period.TextColor3 == config.UI.hud.textColor).toBe(true)
		rerender(board({ period = "LastChance", trailingTeam = "Orange", secondsLeft = 0 }))
		expect(period.Text).toBe("LAST CHANCE")
		expect(period.TextColor3 == colors.Orange).toBe(true)
		rerender(board({ period = "Regulation" }))
		expect(period.Visible).toBe(false)
	end)
end)

describe("Scoreboard, S5 Compact chips on phones", function()
	it("shows the score chips round the clock in one row, and no lap chips", function()
		local overrides = { scores = { Blue = 2, Orange = 1 }, possessingTeam = "Blue", lapProgress = 2 }
		local mounted = Fixtures.mount(board(overrides, true), folder)
		local sizes = layout.compactScoreboard
		expect(part(mounted, "BlueScore").Text).toBe("2")
		expect(part(mounted, "BlueScore").TextSize).toBe(sizes.textSizes.score)
		expect(part(mounted, "OrangeScore").Text).toBe("1")
		expect(part(mounted, "BlueChip").Size).toEqual(sizes.score)
		expect(part(mounted, "ClockBox").Size).toEqual(sizes.clock)
		expect(part(mounted, "Clock").TextSize).toBe(sizes.textSizes.clock)
		expect(part(mounted, "BlueChip").LayoutOrder < part(mounted, "ClockBox").LayoutOrder).toBe(true)
		expect(part(mounted, "ClockBox").LayoutOrder < part(mounted, "OrangeChip").LayoutOrder).toBe(true)
		expect(part(mounted, "LapChips")).toBeNil()
	end)

	it("hangs the worth chip outside the row, beside the team the goal is open for", function()
		local mounted, rerender = Fixtures.mount(board({ streak = 1, goalOpenFor = "Blue" }, true), folder)
		local worth = part(mounted, "Worth")
		local gap = layout.compactScoreboard.gap
		expect(worth.Parent.Name).toBe("Scoreboard")
		expect(worth.Size).toEqual(layout.compactScoreboard.worth)
		-- Left of Blue's chip, the row's left end.
		expect(worth.AnchorPoint == Vector2.new(1, 0.5)).toBe(true)
		expect(worth.Position).toEqual(UDim2.new(0, -gap, 0.5, 0))
		rerender(board({ streak = 1, goalOpenFor = "Orange" }, true))
		expect(worth.AnchorPoint == Vector2.new(0, 0.5)).toBe(true)
		expect(worth.Position).toEqual(UDim2.new(1, gap, 0.5, 0))
		expect(part(mounted, "WorthText").TextSize).toBe(layout.compactScoreboard.textSizes.worth)
	end)

	it("says the period under the row", function()
		local mounted = Fixtures.mount(board({ period = "Overtime" }, true), folder)
		local period = part(mounted, "Period")
		expect(period.Parent.Name).toBe("Scoreboard")
		expect(period.Text).toBe("OVERTIME")
		expect(period.TextSize).toBe(layout.compactScoreboard.textSizes.period)
	end)
end)
