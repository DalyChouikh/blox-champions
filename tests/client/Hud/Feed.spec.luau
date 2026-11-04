--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Animator = require(Client.Hud.Animator)
local BannerMotion = require(Client.Hud.BannerMotion)
local Feed = require(Client.Hud.Feed)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local TextService = game:GetService("TextService")

local BOX = Color3.fromRGB(40, 50, 60)
-- This spec's own: a 2 px outline and a 3 px drop shadow, no shade, team colours of its own (#0a141e, #c86428); chips
-- 20 px tall, 6 px each side of the words at 14, 4 px of the game between them; on a phone 16 px tall, the words at 11.
-- So a chip's ink stands 27 px tall, 31 px from the next.
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
-- The chips' motion, seated for each feed drawn, and what moves it.
local animator: Animator.Animator
local motion: BannerMotion.BannerMotion

local function entry(id: number, kind: HudState.FeedKind, team: "Blue" | "Orange", player: string, replaced: boolean?)
	local made: HudState.FeedEntry =
		{ id = id, kind = kind, team = team, player = player, timeLeft = 1, replaced = replaced == true }
	return made
end

-- The feed keyed as App keys it, which names its frame; `lines`: how many rows it stands, all of `entries` by default.
local function feed(entries: { HudState.FeedEntry }, compact: boolean?, lines: number?): React.ReactElement
	motion:watch({ feed = entries } :: any)
	return React.createElement(React.Fragment, nil, {
		Feed = React.createElement(Feed, {
			config = config,
			text = text,
			feed = entries,
			lines = lines or #entries,
			chips = motion.chips,
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
	animator = Animator.new(config.UI.hud.motion)
	motion = BannerMotion.new(config.UI.hud.motion, animator, 8)
end)

afterEach(function()
	Fixtures.unmountAll()
	folder:Destroy()
end)

describe("Feed", function()
	-- Banner style's chips (#369, the owner's Q221), with no team edge (Q226): the name alone says the team.
	it("draws each line as a look C chip in look.box, the name in its team's colour", function()
		local mounted =
			Fixtures.mount(feed({ entry(3, "Possession", "Blue", "1"), entry(4, "Goal", "Orange", "2") }), folder)
		local frame = child(mounted, "Feed") :: Frame
		local first, second = child(frame, "3"), child(frame, "4")
		-- Each with room for its ink: a chip's outlines each side, its shadow below.
		expect(first.Size).toEqual(UDim2.fromOffset(chipWidth("Ana has the ball", 14, 6) + 2 * 2, 27))
		expect(second.Size).toEqual(UDim2.fromOffset(chipWidth("Rex scored!", 14, 6) + 2 * 2, 27))

		local chip = first.Group.Chip
		expect(chip.Position).toEqual(UDim2.fromOffset(2, 2))
		expect(chip.Size).toEqual(UDim2.fromOffset(chipWidth("Ana has the ball", 14, 6), 20))
		-- Style.box's fill: one colour whichever the team, with its corners, and nothing over it but the words.
		expect(shadeOf(chip.Fill1.Shade) == BOX).toBe(true)
		expect(shadeOf(second.Group.Chip.Fill1.Shade) == BOX).toBe(true)
		expect(chip.Fill1.Corner.CornerRadius).toEqual(UDim.new(0, 5))

		local label = chip.Content.Label :: TextLabel
		expect(label.RichText).toBe(true)
		expect(label.Text).toBe('<font color="#0a141e">Ana</font> has the ball')
		expect(label.Font).toBe(look.font)
		expect(label.TextSize).toBe(14)
		expect(label.TextColor3 == config.UI.hud.textColor).toBe(true)
		expect(label.Size).toEqual(UDim2.fromScale(1, 1))
		expect(child(label, "Ink").Thickness).toBe(2)
		expect(second.Group.Chip.Content.Label.Text).toBe('<font color="#c86428">Rex</font> scored!')
	end)

	-- Whole, in one group, as the banners do (the owner, Q227).
	it("pops each chip by its own scale and fades it whole by how far it has left", function()
		local entries = { entry(3, "Possession", "Blue", "1"), entry(4, "Goal", "Orange", "2") }
		local frame = child(Fixtures.mount(feed(entries), folder), "Feed") :: Frame
		local group = child(frame, "3").Group :: CanvasGroup
		local other = child(frame, "4").Group :: CanvasGroup
		expect(group.ClassName).toBe("CanvasGroup")
		expect(group.AnchorPoint == Vector2.new(0.5, 0.5)).toBe(true)
		expect(group.Position).toEqual(UDim2.fromScale(0.5, 0.5))
		expect(group.Size).toEqual(UDim2.fromScale(1, 1))
		-- Seated and popping from nothing: the HUD's motion moves it from here.
		expect(child(group, "Pop").Scale).toBeCloseTo(0, 4)
		animator:step(config.UI.hud.motion.pop.seconds)
		expect(child(group, "Pop").Scale).toBe(1)
		expect(group.GroupTransparency).toBe(0)
		entries[1].timeLeft = config.UI.hud.motion.easeSeconds / 2
		motion:step({ feed = entries, bannerLeft = 0, messageLeft = 0 } :: any)
		expect(group.GroupTransparency > 0).toBe(true)
		expect(other.GroupTransparency).toBe(0)
	end)

	it("keeps an entry's chip when older ones leave", function()
		local mounted, rerender =
			Fixtures.mount(feed({ entry(6, "Goal", "Blue", "1"), entry(7, "Possession", "Orange", "2") }), folder)
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
		-- Each centred on its row, the older one row up: 27 + 4 from the top.
		expect(child(frame, "1").AnchorPoint == Vector2.new(0.5, 0)).toBe(true)
		expect(child(frame, "1").Position).toEqual(UDim2.fromScale(0.5, 0))
		expect(child(frame, "2").Position).toEqual(UDim2.new(0.5, 0, 0, 31))
	end)

	-- The owner's Q227: the old ball line fades where the new one pops in, moving nothing else.
	it("fades a replaced ball line in the new one's row, beneath it, and takes no row for it", function()
		local entries = {
			entry(1, "Possession", "Blue", "1", true),
			entry(2, "Goal", "Blue", "1"),
			entry(3, "Possession", "Blue", "1", true),
			entry(4, "Possession", "Orange", "2"),
		}
		local frame = child(Fixtures.mount(feed(entries, false, 2), folder), "Feed") :: Frame
		expect(frame.Size.Y.Offset).toBe(58)
		expect(child(frame, "4").Position).toEqual(UDim2.new(0.5, 0, 0, 31))
		expect(child(frame, "3").Position).toEqual(UDim2.new(0.5, 0, 0, 31))
		expect(child(frame, "1").Position).toEqual(UDim2.new(0.5, 0, 0, 31))
		expect(child(frame, "2").Position).toEqual(UDim2.fromScale(0.5, 0))
		expect(child(frame, "4").ZIndex > child(frame, "3").ZIndex).toBe(true)
		expect(child(frame, "3").ZIndex > child(frame, "1").ZIndex).toBe(true)
	end)

	-- The ball line need not be the bottom row: a line about points may have come since.
	it("fades a replaced ball line in the row of the live one, wherever that is", function()
		local entries = {
			entry(1, "Possession", "Blue", "1", true),
			entry(2, "Possession", "Orange", "2"),
			entry(3, "Goal", "Blue", "1"),
		}
		local frame = child(Fixtures.mount(feed(entries, false, 2), folder), "Feed") :: Frame
		expect(child(frame, "3").Position).toEqual(UDim2.new(0.5, 0, 0, 31))
		expect(child(frame, "2").Position).toEqual(UDim2.fromScale(0.5, 0))
		expect(child(frame, "1").Position).toEqual(UDim2.fromScale(0.5, 0))
	end)

	-- As wide as the widest, even one on its way out: a chip keeps its place until it has gone.
	it("is as wide as a replaced line too", function()
		local entries = { entry(1, "Possession", "Blue", "1", true), entry(2, "Goal", "Orange", "2") }
		local frame = child(Fixtures.mount(feed(entries, false, 1), folder), "Feed") :: Frame
		expect(frame.Size.X.Offset).toBe(chipWidth("Ana has the ball", 14, 6) + 2 * 2)
	end)

	it("is as wide as its widest chip wherever that sits", function()
		local entries = { entry(1, "Goal", "Orange", "2"), entry(2, "Possession", "Blue", "1") }
		local frame = child(Fixtures.mount(feed(entries), folder), "Feed") :: Frame
		expect(frame.Size.X.Offset).toBe(chipWidth("Ana has the ball", 14, 6) + 2 * 2)
	end)

	it("takes a phone's sizes on a phone's screen", function()
		local mounted = Fixtures.mount(feed({ entry(1, "Goal", "Blue", "1") }, true), folder)
		local frame = child(mounted, "Feed") :: Frame
		local row = child(frame, "1")
		-- 16 + 2 x 2 + 3.
		expect(row.Size).toEqual(UDim2.fromOffset(chipWidth("Ana scored!", 11, 5) + 2 * 2, 23))
		expect(row.Group.Chip.Size).toEqual(UDim2.fromOffset(chipWidth("Ana scored!", 11, 5), 16))
		expect(row.Group.Chip.Content.Label.TextSize).toBe(11)
		expect(row.Group.Chip.Fill1.Corner.CornerRadius).toEqual(UDim.new(0, 4))
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
