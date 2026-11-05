--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Style)
local ScoreTab = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.ScoreTab)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

local config = Fixtures.config()
local hud = config.UI.hud
local look = hud.look
local text = HudText.new(config)
local NAMES = { ["1"] = "Ana", ["2"] = "Rex", ["3"] = "Kai", ["-4"] = "Bot" }

local folder: Folder
-- The HUD's whole area, the whole screen in its pixels, and the board's pop and fade, as the Hud's bindings give them.
local area: React.Binding<Vector2>, setArea: (Vector2) -> ()
local screen: React.Binding<Rect>, setScreen: (Rect) -> ()
local pop: React.Binding<number>, setPop: (number) -> ()
local leave: React.Binding<number>, setLeave: (number) -> ()

-- Ana (Blue) leads with 5, Kai (Blue) has 2, Rex (Orange) 4: by team, then score, as the server sends them.
local function stats(): Types.MatchStats
	local ana = Fixtures.playerStats("1", "Blue")
	ana.score, ana.goals, ana.assists, ana.saves, ana.steals = 5, 2, 1, 0, 3
	local kai = Fixtures.playerStats("3", "Blue")
	kai.score = 2
	local rex = Fixtures.playerStats("2", "Orange")
	rex.score, rex.saves = 4, 2
	return { scores = { Blue = 3, Orange = 1 }, players = { ana, kai, rex } }
end

local function noop() end

-- The board with `options` over its usual props (Ana's, on desktop, open), mounted.
local function tab(options: { [string]: any }?): Frame
	local props: { [string]: any } = {
		config = config,
		text = text,
		stats = stats(),
		names = NAMES,
		localId = "1",
		compact = false,
		touch = false,
		open = true,
		scale = pop,
		leave = leave,
		area = area,
		screen = screen,
		boardBottom = 0,
	}
	local given: { [string]: any } = options or {}
	for key, value in given do
		props[key] = value
	end
	local mounted = Fixtures.mount(
		React.createElement(React.Fragment, nil, { ScoreTab = React.createElement(ScoreTab, props :: any) }),
		folder
	)
	return mounted:FindFirstChild("ScoreTab") :: Frame
end

-- The part called `name` anywhere in `frame`.
local function find(frame: Instance, name: string): any
	return frame:FindFirstChild(name, true)
end

-- A row's cell: the label of its column called `column` (a bar's: its name or score).
local function cell(frame: Frame, row: string, column: string): TextLabel
	return find(frame, row):FindFirstChild(column, true) :: TextLabel
end

-- `players` of a team each, alternating Blue and Orange (Fixtures.roster).
local function roster(players: number): Types.MatchStats
	return { scores = { Blue = 0, Orange = 0 }, players = Fixtures.roster(players) }
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ScoreTabTest"
	folder.Parent = workspace
	area, setArea = React.createBinding(Vector2.zero)
	screen, setScreen = React.createBinding(Rect.new(0, 0, 0, 0))
	pop, setPop = React.createBinding(1)
	leave, setLeave = React.createBinding(0)
end)

afterEach(function()
	Fixtures.unmountAll()
	folder:Destroy()
end)

describe("ScoreTab", function()
	-- One compact table (the owner, Q236, Q237): a header of column names, then a bar per team, the viewer's first.
	it("lists the viewer's team first under its bar, then the other's, each by score", function()
		local frame = tab()
		local columns = config.UI.text.columns
		local header: { string } = {}
		for _, column in { "Name", "Score", "Goals", "Assists", "Saves", "Steals" } do
			table.insert(header, cell(frame, "Header", column).Text)
		end
		expect(header).toEqual({
			columns.player,
			columns.score,
			columns.goals,
			columns.assists,
			columns.saves,
			columns.steals,
		})
		local ana: { string } = {}
		for _, column in { "Name", "Score", "Goals", "Assists", "Saves", "Steals" } do
			table.insert(ana, cell(frame, "1", column).Text)
		end
		expect(ana).toEqual({ "Ana", "5", "2", "1", "0", "3" })
		expect(cell(frame, "2", "Saves").Text).toBe("2")
		-- Each bar names its team in capitals and gives its score.
		expect(cell(frame, "Blue", "Name").Text).toBe("BLUE")
		expect(cell(frame, "Blue", "Score").Text).toBe("3")
		expect(cell(frame, "Orange", "Score").Text).toBe("1")
		local orders: { number } = {}
		for _, name in { "Blue", "1", "3", "Orange", "2" } do
			table.insert(orders, find(frame, name).LayoutOrder)
		end
		expect(orders).toEqual({ 1, 2, 3, 4, 5 })
		-- Rex's board: Orange first.
		Fixtures.unmountAll()
		local rex = tab({ localId = "2" })
		expect(find(rex, "Orange").LayoutOrder < find(rex, "Blue").LayoutOrder).toBe(true)
		expect(find(rex, "2").LayoutOrder < find(rex, "1").LayoutOrder).toBe(true)
	end)

	it("lists a spectator's board in the teams' own order, and both bars over a team with no one", function()
		local listed: Types.MatchStats =
			{ scores = { Blue = 0, Orange = 2 }, players = { Fixtures.playerStats("2", "Orange") } }
		local frame = tab({ stats = listed, localId = "9" })
		expect(find(frame, "Blue").LayoutOrder < find(frame, "Orange").LayoutOrder).toBe(true)
		expect(cell(frame, "Orange", "Score").Text).toBe("2")
		expect(find(frame, "2").LayoutOrder > find(frame, "Orange").LayoutOrder).toBe(true)
	end)

	-- Look C (Q184): the board a box in look.box, the lettering inked, each bar in the HUD's team colour over an ink
	-- line; every row solid, a leaver being off it (#309).
	it("draws look C: inked white lettering on a look C box, each bar in its team's HUD colour", function()
		local frame = tab()
		local name = cell(frame, "3", "Name")
		expect(name.TextColor3 == hud.textColor).toBe(true)
		expect(name.TextTransparency).toBe(0)
		expect(name.Font).toBe(look.font)
		expect(name.TextTruncate).toBe(Enum.TextTruncate.AtEnd)
		expect((name:FindFirstChild("Ink") :: UIStroke).Color == look.ink).toBe(true)
		expect(cell(frame, "3", "Score").TextXAlignment).toBe(Enum.TextXAlignment.Center)
		local bar = find(frame, "Orange") :: Frame
		expect((bar:FindFirstChild("Fill") :: Frame).BackgroundColor3 == look.teamColors.Orange).toBe(true)
		expect((bar:FindFirstChild("Line") :: Frame).BackgroundColor3 == look.ink).toBe(true)
		expect((bar:FindFirstChild("Line") :: Frame).Size.Y.Offset).toBe(look.outline)
		-- The box's ink drops look.shadow under its fill.
		local box = find(frame, "Box") :: Frame
		expect(box:FindFirstChild("Ink1") ~= nil and box:FindFirstChild("Fill1") ~= nil).toBe(true)
	end)

	-- RC's rows: an avatar circle before each name (Q190), a Roblox user's headshot, a plain circle for any other id.
	it(
		"puts each player's headshot in a circle before their name, a plain circle for an id that is no user's",
		function()
			local listed = stats()
			table.insert(listed.players, Fixtures.playerStats("-4", "Orange"))
			local frame = tab({ stats = listed })
			local avatar = find(frame, "1"):FindFirstChild("Avatar", true):FindFirstChild("Disc") :: ImageLabel
			expect(avatar.Image).toBe(text:avatar("1") :: string)
			expect(avatar.BackgroundColor3 == hud.textColor).toBe(true)
			expect(avatar.Size).toEqual(
				UDim2.fromOffset(hud.layout.scoreTab.sizes.avatar, hud.layout.scoreTab.sizes.avatar)
			)
			expect((avatar:FindFirstChild("Ink") :: UIStroke).Thickness).toBe(look.textOutline)
			local bot = find(frame, "-4"):FindFirstChild("Avatar", true):FindFirstChild("Disc") :: ImageLabel
			expect(bot.Image).toBe("")
			expect(cell(frame, "-4", "Name").Text).toBe("Bot")
			-- The header keeps the avatar's column, empty, its names not inked.
			expect(cell(frame, "Header", "Name"):FindFirstChild("Ink")).toBeNil()
			expect(find(frame, "Header"):FindFirstChild("Avatar", true):FindFirstChild("Disc")).toBeNil()
		end
	)

	it("outlines the viewer's row in the key colour, inside it, and no other", function()
		local frame = tab()
		local you = find(frame, "1"):FindFirstChild("You") :: Frame
		local stroke = you:FindFirstChild("Stroke") :: UIStroke
		expect(stroke.Color == look.key).toBe(true)
		expect(stroke.Thickness).toBe(look.outline)
		expect(you.Position).toEqual(UDim2.fromOffset(look.outline, look.outline))
		expect(you.Size).toEqual(UDim2.new(1, -2 * look.outline, 1, -2 * look.outline))
		expect(find(frame, "3"):FindFirstChild("You")).toBeNil()
		expect(find(frame, "2"):FindFirstChild("You")).toBeNil()
	end)

	-- The design page's sizes (#357): 19 px rows on desktop, 17 on a phone.
	it("sizes its rows, header and bars from the desktop's sizes, or the phone's", function()
		for _, compact in { false, true } do
			Fixtures.unmountAll()
			local sizes = HudScreen.tabSizes(config, compact)
			local frame = tab({ compact = compact })
			local box = find(frame, "Box") :: Frame
			expect(box.Size.X.Offset).toBe(sizes.width)
			expect(find(frame, "1").Size.Y.Offset).toBe(sizes.rowHeight)
			expect(cell(frame, "1", "Name").TextSize).toBe(sizes.textSize)
			expect(cell(frame, "1", "Score").Size.X.Offset).toBe(sizes.column)
			expect(find(frame, "Header").Size.Y.Offset).toBe(sizes.headHeight)
			expect(cell(frame, "Header", "Score").TextSize).toBe(sizes.headSize)
			expect(find(frame, "Blue").Size.Y.Offset).toBe(sizes.barHeight)
			expect(cell(frame, "Blue", "Name").TextSize).toBe(sizes.barSize)
			-- The cells `gap` apart, the avatar's slot its circle and ink in whole pixels.
			local layout = find(frame, "1"):FindFirstChild("Layout", true) :: UIListLayout
			expect(layout.Padding.Offset).toBe(sizes.gap)
			local slot = find(frame, "1"):FindFirstChild("Avatar", true) :: Frame
			expect(slot.Size).toEqual(UDim2.new(0, sizes.avatar + 2 * math.ceil(look.textOutline), 1, 0))
			-- The name takes what the avatar, the numbers and their gaps leave, `side` in from each edge.
			local padding = find(frame, "1"):FindFirstChild("Padding", true) :: UIPadding
			expect(padding.PaddingLeft.Offset).toBe(sizes.side)
			expect(padding.PaddingRight.Offset).toBe(sizes.side)
			local ink = math.ceil(look.textOutline)
			local taken = sizes.avatar + 2 * ink + 6 * sizes.gap + 5 * sizes.column
			expect(cell(frame, "1", "Name").Size).toEqual(UDim2.new(1, -taken, 1, 0))
		end
	end)

	-- The owner (Q117, Q118, #310): under the board, its key and "Switch team", greyed while a switch can't happen.
	it("offers Switch team under the board with its key on look C's cap, greyed while a switch can't happen", function()
		local frame = tab({ switchTeam = { open = true, key = { text = "T" }, onActivated = noop } })
		local button = find(frame, "SwitchTeam") :: TextButton
		expect(button:IsA("TextButton")).toBe(true)
		expect(button.Selectable).toBe(false)
		local row = button:FindFirstChild("Row") :: CanvasGroup
		expect(row.GroupTransparency).toBe(0)
		local cap = row:FindFirstChild("Key") :: Frame
		expect((find(cap, "Legend") :: TextLabel).Text).toBe("T")
		expect(cap.Size.Y.Offset).toBe(hud.layout.hints.cap.height)
		local label = row:FindFirstChild("Label") :: TextLabel
		expect(label.Text).toBe(config.UI.text.switchTeam)
		expect(label.TextSize).toBe(hud.layout.scoreTab.sizes.switchSize)
		expect(label.Font).toBe(look.font)
		-- Its words as wide as they are measured, switchGap after the cap; the row as tall as the cap.
		expect(label.Size).toEqual(
			UDim2.fromOffset(Style.textWidth(config, label.Text, label.TextSize), label.TextSize)
		)
		expect((row:FindFirstChild("Layout") :: UIListLayout).Padding.Offset).toBe(hud.layout.scoreTab.sizes.switchGap)
		expect(button.Size.Y.Offset).toBe(
			HudScreen.tabSwitch(config, false, "Key") - hud.layout.scoreTab.sizes.switchGap
		)
		-- Under the box's ink, switchGap below it.
		local sizes = hud.layout.scoreTab.sizes
		local box = find(frame, "Box") :: Frame
		local under = box.Position.Y.Offset + box.Size.Y.Offset + look.outline + look.shadow + sizes.switchGap
		expect(button.Position.Y.Offset).toBe(under)
		Fixtures.unmountAll()
		local greyed = tab({ switchTeam = { open = false, key = { image = "rbxasset://glyph" }, onActivated = noop } })
		local grey = find(greyed, "SwitchTeam"):FindFirstChild("Row") :: CanvasGroup
		expect(grey.GroupTransparency).toBeCloseTo(hud.dimTransparency, 5)
		expect(find(grey, "Glyph") ~= nil).toBe(true)
	end)

	it("shows no Switch team where none is offered, and only its label on touch", function()
		expect(find(tab(), "SwitchTeam")).toBeNil()
		Fixtures.unmountAll()
		local touch =
			find(tab({ touch = true, compact = true, switchTeam = { open = true, onActivated = noop } }), "Row")
		expect(touch:FindFirstChild("Label") ~= nil).toBe(true)
		expect(touch:FindFirstChild("Label").TextSize).toBe(hud.layout.scoreTab.compactSizes.switchSize)
		expect(touch:FindFirstChild("Key")).toBeNil()
		expect(touch:FindFirstChild("Glyph")).toBeNil()
	end)

	-- Off touch its key is held, so nothing could scroll it: it shrinks to fit, as the HUD's panels do.
	it("shrinks to fit a screen too small for it off touch, all its rows showing", function()
		setArea(Vector2.new(750, 323))
		local frame = tab({
			stats = roster(12),
			compact = true,
			switchTeam = { open = true, key = { text = "T" }, onActivated = noop },
		})
		local scale, rows = HudScreen.tabFit(config, true, false, Vector2.new(750, 323), 12, "Key")
		expect(scale < 1).toBe(true)
		expect((find(frame, "Fit") :: UIScale).Scale).toBeCloseTo(scale, 5)
		local teams = find(frame, "Teams") :: ScrollingFrame
		expect(teams.Size.Y.Offset).toBe(rows)
		expect(teams.CanvasSize.Y.Offset).toBe(HudScreen.tabBody(config, true, 12))
		expect(frame.Position.Y.Offset).toBe(0)
		setArea(Vector2.new(1920, 1000))
		expect((find(frame, "Fit") :: UIScale).Scale).toBe(1)
	end)

	-- On a phone (Q234, Q236): the whole screen under the SCORES button, taking the touches there while open (over the
	-- touch buttons, which reach the screen's corner past the HUD's area, #355), its rows scrolling where they do not
	-- fit (Q190).
	it("on touch, sits under the SCORES button, takes the touches there while open, and scrolls its rows", function()
		setArea(Vector2.new(750, 323))
		-- A notched phone's whole screen, 62 px past the HUD's area each side and 78 above it.
		setScreen(Rect.new(-62, -78, 812, 323))
		local top = HudScreen.tabTop(config, true, 0)
		local touchSwitch = { open = true, onActivated = noop }
		local frame = tab({ stats = roster(12), compact = true, touch = true, switchTeam = touchSwitch })
		expect(frame.Position).toEqual(UDim2.fromOffset(0, top))
		expect(frame.Size).toEqual(UDim2.new(1, 0, 1, -top))
		local shield = frame:FindFirstChild("Shield") :: Frame
		expect(shield.Active).toBe(true)
		expect(shield.BackgroundTransparency).toBe(1)
		-- The whole screen's width, from the board's top to the screen's bottom.
		expect(shield.Position).toEqual(UDim2.fromOffset(-62, 0))
		expect(shield.Size).toEqual(UDim2.fromOffset(874, 323 - top))
		-- Under the board, whose Switch team button and rows take their own touches.
		expect(shield.ZIndex < (find(frame, "Board") :: Frame).ZIndex).toBe(true)
		local scale, rows = HudScreen.tabFit(config, true, true, Vector2.new(750, 323 - top), 12, "Label")
		expect(scale).toBe(1)
		expect((find(frame, "Fit") :: UIScale).Scale).toBe(1)
		local teams = find(frame, "Teams") :: ScrollingFrame
		expect(teams.Size.Y.Offset).toBe(rows)
		expect(teams.CanvasSize.Y.Offset > rows).toBe(true)
		-- The box as tall as its header and the teams shown, the board as its box, the box's ink and Switch team.
		local sizes = hud.layout.scoreTab.compactSizes
		local box = find(frame, "Box") :: Frame
		expect(box.Size).toEqual(UDim2.fromOffset(sizes.width, sizes.headHeight + rows))
		local ink = 2 * look.outline + look.shadow
		local switch = HudScreen.tabSwitch(config, true, "Label")
		expect((find(frame, "Board") :: Frame).Size).toEqual(
			UDim2.fromOffset(sizes.width + 2 * look.outline, ink + sizes.headHeight + rows + switch)
		)
		expect(teams.ScrollingDirection).toBe(Enum.ScrollingDirection.Y)
		expect(teams.ScrollBarThickness).toBe(hud.layout.scoreTab.scrollBar)
		expect(teams.ScrollBarImageColor3 == hud.textColor).toBe(true)
		-- Three a side fits whole.
		Fixtures.unmountAll()
		local three = tab({ stats = roster(6), compact = true, touch = true, switchTeam = touchSwitch })
		local whole = find(three, "Teams") :: ScrollingFrame
		expect(whole.Size.Y.Offset).toBe(whole.CanvasSize.Y.Offset)
		-- Fading out after it closed, it lets touches through to the buttons again.
		Fixtures.unmountAll()
		local closing = tab({ compact = true, touch = true, open = false })
		expect((closing:FindFirstChild("Shield") :: Frame).Active).toBe(false)
		-- Off touch it never takes them: clicks keep reaching the game.
		Fixtures.unmountAll()
		local desktop = tab()
		expect((desktop:FindFirstChild("Shield") :: Frame).Active).toBe(false)
		expect(desktop.Active).toBe(false)
	end)

	-- It never covers the scoreboard (Q203's rule): its area starts under the scoreboard's ink, its margin clear of it,
	-- on touch under the SCORES button where that is lower.
	it(
		"starts its area under the scoreboard's ink, and on touch under the SCORES button where that is lower",
		function()
			-- A 600 px area: 12 rows fit it whole, but not the 523 px under the scoreboard, so the board shrinks.
			setArea(Vector2.new(1556, 600))
			local frame = tab({ stats = roster(12), boardBottom = 76.5 })
			expect(frame.Position).toEqual(UDim2.fromOffset(0, 77))
			expect(frame.Size).toEqual(UDim2.new(1, 0, 1, -77))
			local whole = HudScreen.tabFit(config, false, false, Vector2.new(1556, 600), 12, nil)
			expect(whole).toBe(1)
			local scale = HudScreen.tabFit(config, false, false, Vector2.new(1556, 600 - 77), 12, nil)
			expect(scale < 1).toBe(true)
			expect((find(frame, "Fit") :: UIScale).Scale).toBeCloseTo(scale, 5)
			Fixtures.unmountAll()
			local button = HudScreen.tabTop(config, true, 0)
			expect(tab({ touch = true, boardBottom = button - 10 }).Position).toEqual(UDim2.fromOffset(0, button))
			Fixtures.unmountAll()
			expect(tab({ touch = true, boardBottom = button + 10 }).Position).toEqual(UDim2.fromOffset(0, button + 10))
		end
	)

	-- Every HUD change animates (the owner, Q194): it pops in as it opens and fades out whole as it closes (Reveal).
	it("pops in and fades out whole through its bindings", function()
		local frame = tab({ switchTeam = { open = true, key = { text = "T" }, onActivated = noop } })
		local group = find(frame, "Group") :: CanvasGroup
		local scale = group:FindFirstChild("Pop") :: UIScale
		setPop(0.5)
		expect(scale.Scale).toBe(0.5)
		setLeave(0.25)
		expect(group.GroupTransparency).toBe(0.25)
		-- Switch team goes with it.
		expect(find(group, "SwitchTeam") ~= nil).toBe(true)
	end)

	-- Over the HUD's stage (Style.above), so it covers the banners, the end screen and the rest.
	it("draws above the HUD's stage", function()
		expect(tab().ZIndex).toBe(3)
	end)
end)
