--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Feed = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Feed)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local TextService = game:GetService("TextService")

local BOX = Color3.fromRGB(40, 50, 60)
-- This spec's own: a 2 px outline and a 3 px drop shadow, no shade, team colours of its own (#0a141e, #c86428); chips
-- 20 px tall, 6 px each side of the words at 14, 4 px of the game between them; on a phone 16 px tall, the words at 11.
local config = Fixtures.config({
	UI = {
		hud = {
			screenMargin = 8,
			look = {
				outline = 2,
				shadow = 3,
				textOutline = 2,
				shade = 0,
				box = BOX,
				teamColors = { Blue = Color3.fromRGB(10, 20, 30), Orange = Color3.fromRGB(200, 100, 40) },
			},
			layout = {
				feed = {
					clearance = 4,
					sizes = { height = 20, corner = UDim.new(0, 5), inset = 6, textSize = 14 },
					compactSizes = { height = 16, corner = UDim.new(0, 4), inset = 5, textSize = 11 },
				},
			},
		},
	},
})
local look = config.UI.hud.look
local text = HudText.new(config)
local NAMES = { ["1"] = "Ana", ["2"] = "Rex" }
local UNBOUNDED = Vector2.new(math.huge, math.huge)

local folder: Folder
-- The HUD's area, as the Hud's binding gives it.
local area: React.Binding<Vector2>, setArea: (Vector2) -> ()

local function entry(id: number, kind: HudState.FeedKind, team: "Blue" | "Orange", player: string)
	local made: HudState.FeedEntry = { id = id, kind = kind, team = team, player = player, timeLeft = 1 }
	return made
end

-- The feed keyed as App keys it, which names its frame.
local function feed(entries: { HudState.FeedEntry }, compact: boolean?): React.ReactElement
	return React.createElement(React.Fragment, nil, {
		Feed = React.createElement(Feed, {
			config = config,
			text = text,
			feed = entries,
			names = NAMES,
			compact = compact == true,
			area = area,
		}),
	})
end

local function child(parent: Instance, name: string): any
	return parent:FindFirstChild(name)
end

-- A chip's width for `words` at `size`: its insets each side, the words whole pixels up.
local function chipWidth(words: string, size: number, inset: number): number
	return math.ceil(TextService:GetTextSize(words, size, look.font, UNBOUNDED).X) + 2 * inset
end

-- The colour a shade starts from (this spec has no shade: the whole of it).
local function shadeOf(shade: UIGradient): Color3
	return shade.Color.Keypoints[1].Value
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "FeedTest"
	folder.Parent = workspace
	area, setArea = React.createBinding(Vector2.zero)
end)

afterEach(function()
	Fixtures.unmountAll()
	folder:Destroy()
end)

describe("Feed", function()
	-- Banner style's chips (#369, the owner's Q221), with no team edge (Q226): the name alone says the team.
	it("draws each line as a look C chip in look.box, the name in its team's colour, in order", function()
		local mounted =
			Fixtures.mount(feed({ entry(3, "Possession", "Blue", "1"), entry(4, "Goal", "Orange", "2") }), folder)
		local frame = child(mounted, "Feed") :: Frame
		local first, second = child(frame, "3"), child(frame, "4")
		expect(first.LayoutOrder < second.LayoutOrder).toBe(true)
		expect(first.Size).toEqual(UDim2.fromOffset(chipWidth("Ana has the ball", 14, 6), 20))
		expect(second.Size).toEqual(UDim2.fromOffset(chipWidth("Rex scored!", 14, 6), 20))

		-- Style.box's fill: one colour whichever the team, with its corners, and nothing over it but the words.
		expect(shadeOf(first.Fill1.Shade) == BOX).toBe(true)
		expect(shadeOf(second.Fill1.Shade) == BOX).toBe(true)
		expect(first.Fill1.Corner.CornerRadius).toEqual(UDim.new(0, 5))
		expect(child(first.Content, "Body") == nil).toBe(true)

		local label = first.Content.Label :: TextLabel
		expect(label.RichText).toBe(true)
		expect(label.Text).toBe('<font color="#0a141e">Ana</font> has the ball')
		expect(label.Font).toBe(look.font)
		expect(label.TextSize).toBe(14)
		expect(label.TextColor3 == config.UI.hud.textColor).toBe(true)
		expect(label.Size).toEqual(UDim2.fromScale(1, 1))
		expect(child(label, "Ink").Thickness).toBe(2)
		expect(second.Content.Label.Text).toBe('<font color="#c86428">Rex</font> scored!')
	end)

	it("keeps an entry's chip when older ones leave", function()
		local mounted, rerender =
			Fixtures.mount(feed({ entry(6, "Possession", "Blue", "1"), entry(7, "Possession", "Orange", "2") }), folder)
		local frame = mounted:FindFirstChild("Feed") :: Frame
		local kept = frame:FindFirstChild("7")
		rerender(feed({ entry(7, "Possession", "Orange", "2") }))
		expect(frame:FindFirstChild("6") == nil).toBe(true)
		expect(kept ~= nil and frame:FindFirstChild("7") == kept).toBe(true)
	end)

	-- Over the goal message, which takes the feed's old place at the bottom (#356, the owner's Q211).
	it("sits over the goal message at the stage's bottom", function()
		local mounted, rerender = Fixtures.mount(feed({ entry(1, "Possession", "Blue", "1") }), folder)
		local frame = mounted:FindFirstChild("Feed") :: Frame
		expect(frame.Position).toEqual(UDim2.new(0.5, 0, 1, -HudScreen.feedBottom(config, false)))
		rerender(feed({ entry(1, "Possession", "Blue", "1") }, true))
		expect(frame.Position).toEqual(UDim2.new(0.5, 0, 1, -HudScreen.feedBottom(config, true)))
	end)

	-- As wide as its widest chip and its ink, as tall as its chips stand: what its fit and the prompt above it read.
	it("stands as tall and as wide as its chips and their ink, the newest at the bottom", function()
		local mounted =
			Fixtures.mount(feed({ entry(1, "Possession", "Blue", "1"), entry(2, "Goal", "Orange", "2") }), folder)
		local frame = child(mounted, "Feed") :: Frame
		-- 2 x (20 + 2 x 2 + 3) + 4.
		expect(frame.Size).toEqual(UDim2.fromOffset(chipWidth("Ana has the ball", 14, 6) + 2 * 2, 58))
		local layout = child(frame, "Layout") :: UIListLayout
		expect(layout.VerticalAlignment).toBe(Enum.VerticalAlignment.Bottom)
		-- The clearance past one chip's ink: its outlines and its shadow, and the next one's.
		expect(layout.Padding).toEqual(UDim.new(0, 4 + 2 * 2 + 3))
		local inset = child(frame, "Inset") :: UIPadding
		expect(inset.PaddingTop).toEqual(UDim.new(0, 2))
		expect(inset.PaddingBottom).toEqual(UDim.new(0, 2 + 3))
	end)

	it("takes a phone's sizes on a phone's screen", function()
		local mounted = Fixtures.mount(feed({ entry(1, "Goal", "Blue", "1") }, true), folder)
		local frame = child(mounted, "Feed") :: Frame
		local chip = child(frame, "1")
		expect(chip.Size).toEqual(UDim2.fromOffset(chipWidth("Ana scored!", 11, 5), 16))
		expect(chip.Content.Label.TextSize).toBe(11)
		expect(chip.Fill1.Corner.CornerRadius).toEqual(UDim.new(0, 4))
		-- 16 + 2 x 2 + 3.
		expect(frame.Size.Y.Offset).toBe(23)
	end)

	it("shrinks to fit a stage narrower than itself", function()
		setArea(Vector2.new(100, 323))
		local mounted = Fixtures.mount(feed({ entry(1, "Possession", "Blue", "1") }), folder)
		local frame = child(mounted, "Feed") :: Frame
		local fit = child(frame, "Fit") :: UIScale
		expect(fit.Scale).toBeCloseTo((100 - 2 * 8) / frame.Size.X.Offset, 4)
		setArea(Vector2.new(1920, 1000))
		expect(fit.Scale).toBe(1)
	end)
end)
