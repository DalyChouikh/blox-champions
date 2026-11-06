--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local EndScreen = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.EndScreen)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Style)

local config = Fixtures.config()
local hud = config.UI.hud
local look = hud.look
local text = HudText.new(config)
local NAMES = { ["1"] = "Ana", ["2"] = "Rex" }

local folder: Folder
-- The HUD's stage, and the screen's pop, as the Hud's bindings give them.
local area: React.Binding<Vector2>, setArea: (Vector2) -> ()
local pop: React.Binding<number>, setPop: (number) -> ()

-- Blue won 5-3 (or, with `draw`, overtime ran out at 3-3): Ana (Blue) scored 5 and stole 2, Rex (Orange) 3; or
-- `players` instead of them. `options` over the screen's usual props (a desktop's screen, off touch).
local function screen(mvp: string?, options: { [string]: any }?): React.ReactElement
	local given: { [string]: any } = options or {}
	local ana = Fixtures.playerStats("1", "Blue")
	ana.score, ana.goals, ana.steals = 5, 5, 2
	local rex = Fixtures.playerStats("2", "Orange")
	rex.score = 3
	local draw = given.draw == true
	local ended: HudState.Ended = {
		winner = if draw then nil else "Blue",
		mvp = mvp,
		stats = {
			scores = if draw then { Blue = 3, Orange = 3 } else { Blue = 5, Orange = 3 },
			players = given.players or { ana, rex },
		},
	}
	return React.createElement(React.Fragment, nil, {
		EndScreen = React.createElement(EndScreen, {
			config = given.config or config,
			text = given.text or text,
			ended = ended,
			names = given.names or NAMES,
			localId = "2",
			area = area,
			compact = given.compact == true,
			touch = given.touch == true,
			scale = pop,
		}),
	})
end

local function mount(mvp: string?, options: { [string]: any }?): Frame
	local mounted = Fixtures.mount(screen(mvp, options), folder)
	return mounted:FindFirstChild("EndScreen") :: Frame
end

-- The part called `name` anywhere in `frame`.
local function find(frame: Instance, name: string): any
	return frame:FindFirstChild(name, true)
end

-- The words a banner or chip shows: its front lettering's, else its first label's.
local function words(part: Instance): string
	local front = part:FindFirstChild("Front", true) or part:FindFirstChildWhichIsA("TextLabel", true)
	return (front :: TextLabel).Text
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "EndScreenTest"
	folder.Parent = workspace
	area, setArea = React.createBinding(Vector2.zero)
	pop, setPop = React.createBinding(1)
end)

afterEach(function()
	Fixtures.unmountAll()
	folder:Destroy()
end)

describe("EndScreen", function()
	-- The owner's Q243 (#358): today's parts in look C, the result first in GOAL!'s lettering with the team's ring.
	it("headlines the winner in GOAL!'s lettering with their team's ring, a draw with none", function()
		local result = find(mount("1"), "Result")
		expect(words(result)).toBe("BLUE WINS!")
		expect((find(result, "Front") :: TextLabel).TextSize).toBe(HudScreen.bannerSize(config, false, "Goal"))
		expect((find(result, "Edge") :: TextLabel).TextColor3 == config.UI.teamColors.Blue).toBe(true)
		Fixtures.unmountAll()
		local draw = find(mount("1", { draw = true }), "Result")
		expect(words(draw)).toBe(config.UI.text.draw)
		expect(find(draw, "Edge")).toBeNil()
		-- A phone's screen: GOAL!'s phone size.
		Fixtures.unmountAll()
		local phone = find(mount("1", { compact = true }), "Result")
		expect((find(phone, "Front") :: TextLabel).TextSize).toBe(HudScreen.bannerSize(config, true, "Goal"))
		-- Its ring the phone's banner edge round look C's ink.
		local ring = (find(phone, "Edge") :: TextLabel):FindFirstChild("Ink") :: UIStroke
		expect(ring.Thickness).toBe(look.textOutline + HudScreen.banners(config, true).edge)
	end)

	it("shows the MVP's card: their avatar, name with the MVP chip, and their score, goals and steals", function()
		local card = find(mount("1"), "Mvp")
		local sizes = hud.layout.endScreen.sizes
		local disc = find(card, "Disc") :: ImageLabel
		expect(disc.Image).toBe(text:avatar("1") :: string)
		expect(disc.Size).toEqual(UDim2.fromOffset(sizes.avatar, sizes.avatar))
		local name = find(card, "Player") :: TextLabel
		expect(name.Text).toBe("Ana")
		expect(name.TextSize).toBe(sizes.nameSize)
		local chip = find(card, "Chip") :: Frame
		expect(words(chip)).toBe(config.UI.text.mvp)
		expect(chip.Size.Y.Offset).toBe(sizes.chipHeight)
		expect(chip.Size.X.Offset).toBe(Style.textWidth(config, config.UI.text.mvp, sizes.chipSize) + 2 * sizes.inset)
		local numbers = find(card, "Numbers") :: TextLabel
		expect(numbers.Text).toBe(text:mvpLine(5, 5, 2))
		expect(numbers.TextSize).toBe(sizes.statSize)
		-- In place: the avatar and the name `inset` in from the card's top, the chip in key yellow centred on the
		-- name's line within half a pixel, the numbers on the card's bottom inset.
		local textLeft = sizes.avatar + 2 * sizes.inset
		expect((find(card, "Avatar") :: Frame).Position).toEqual(UDim2.fromOffset(sizes.inset, sizes.inset))
		expect(name.Position).toEqual(UDim2.fromOffset(textLeft, sizes.inset))
		expect(chip.BackgroundColor3 == look.key).toBe(true)
		local off = chip.Position.Y.Offset + sizes.chipHeight / 2 - (sizes.inset + sizes.nameSize / 2)
		expect(math.abs(off) <= 0.5).toBe(true)
		expect(numbers.AnchorPoint).toEqual(Vector2.new(0, 1))
		expect(numbers.Position).toEqual(UDim2.new(0, textLeft, 1, -sizes.inset))
		-- No MVP (none of the winners still in the match): no card.
		Fixtures.unmountAll()
		expect(find(mount(nil), "Mvp")).toBeNil()
	end)

	-- A name too long for the card truncates where the MVP chip would pass the card's inset; a short one has the chip
	-- an inset after it.
	it("keeps a long name inside the card, where it gives way to the MVP chip", function()
		local sizes = hud.layout.endScreen.sizes
		local function parts(names: { [string]: string }): (TextLabel, Frame)
			local card = find(mount("1", { names = names }), "Mvp")
			return find(card, "Player") :: TextLabel, find(card, "Chip") :: Frame
		end
		local name, chip = parts(NAMES)
		expect(chip.Position.X.Offset).toBe(name.Position.X.Offset + name.Size.X.Offset + sizes.inset)
		Fixtures.unmountAll()
		local long, longChip = parts({ ["1"] = string.rep("W", 40) })
		expect(long.TextTruncate).toBe(Enum.TextTruncate.AtEnd)
		expect(longChip.Position.X.Offset + longChip.Size.X.Offset).toBe(sizes.cardWidth - sizes.inset)
		expect(longChip.Position.X.Offset).toBe(long.Position.X.Offset + long.Size.X.Offset + sizes.inset)
	end)

	it("shows each team's total on a chip in its HUD colour", function()
		local frame = mount("1")
		local blue, orange = find(frame, "BlueTotal") :: Frame, find(frame, "OrangeTotal") :: Frame
		expect(words(blue)).toBe(text:teamTotal("Blue", 5))
		expect(words(orange)).toBe(text:teamTotal("Orange", 3))
		expect((find(blue, "Shade") :: UIGradient).Color.Keypoints[1].Value == config.UI.teamColors.Blue).toBe(true)
		expect((blue:FindFirstChild("Box") :: Frame).Size.Y.Offset).toBe(hud.layout.endScreen.sizes.totalHeight)
		-- In the teams' own order (Team.list).
		expect(blue.LayoutOrder < orange.LayoutOrder).toBe(true)
		-- As wide as its words with an inset each side, in its ink.
		local sizes = hud.layout.endScreen.sizes
		local box = blue:FindFirstChild("Box") :: Frame
		local blueWords = text:teamTotal("Blue", 5)
		expect(box.Size.X.Offset).toBe(Style.textWidth(config, blueWords, sizes.totalSize) + 2 * sizes.inset)
		expect(box.Position).toEqual(UDim2.fromOffset(look.outline, look.outline))
	end)

	-- The TAB board's table (#357, Q243), every player still in the match, whole; none on touch, where SCORES opens the
	-- board over the screen (the owner's choice).
	it("puts the TAB board's table under them, every row showing, and leaves it out on touch", function()
		local box = find(mount("1"), "Table"):FindFirstChild("Box") :: Frame
		expect(find(box, "1") ~= nil and find(box, "2") ~= nil).toBe(true)
		expect((find(box, "Teams") :: ScrollingFrame).Size.Y.Offset).toBe(HudScreen.tabBody(config, false, 2))
		-- On a phone's screen played with a keyboard, at the desktop's sizes all the same (it shows off touch only).
		Fixtures.unmountAll()
		local phone = find(mount("1", { compact = true }), "Table"):FindFirstChild("Box") :: Frame
		expect((find(phone, "Teams") :: ScrollingFrame).Size.Y.Offset).toBe(HudScreen.tabBody(config, false, 2))
		expect(phone.Size.X.Offset).toBe(hud.layout.scoreTab.sizes.width)
		-- Its box in the frame's ink.
		expect(phone.Position).toEqual(UDim2.fromOffset(look.outline, look.outline))
		Fixtures.unmountAll()
		expect(find(mount("1", { touch = true }), "Table")).toBeNil()
	end)

	-- Its dim is the Hud's, over the whole screen.
	it("lines its parts up down the stage's middle, gap apart, with no panel of its own", function()
		local frame = mount("1")
		expect(frame.Size).toEqual(UDim2.fromScale(1, 1))
		expect(frame.BackgroundTransparency).toBe(1)
		expect((find(frame, "Group"):FindFirstChild("Layout") :: UIListLayout).Padding.Offset).toBe(
			hud.layout.endScreen.gap
		)
		local order: { number } = {}
		for _, name in { "Result", "Mvp", "Totals", "Table" } do
			table.insert(order, find(frame, name).LayoutOrder)
		end
		expect(order).toEqual({ 1, 2, 3, 4 })
	end)

	-- As tall as its parts (HudScreen.endHeight), as wide as the table or the card, shrunk to fit the stage.
	it("shrinks to fit a stage smaller than its parts", function()
		setArea(Vector2.new(750, 323))
		local stack = find(mount("1", { players = Fixtures.roster(12) }), "Stack") :: Frame
		local height = HudScreen.endHeight(config, false, 12, true, true)
		local width = hud.layout.scoreTab.sizes.width + 2 * look.outline
		expect(stack.Size).toEqual(UDim2.fromOffset(width, height))
		local margin = 2 * hud.screenMargin
		local fit = stack:FindFirstChild("Fit") :: UIScale
		expect(fit.Scale).toBeCloseTo(math.min((750 - margin) / width, (323 - margin) / height), 4)
		setArea(Vector2.new(1920, 1200))
		expect(fit.Scale).toBe(1)
		-- On touch only as wide as the card, and as tall as the parts but the table.
		Fixtures.unmountAll()
		local touch = find(mount("1", { touch = true, compact = true }), "Stack") :: Frame
		local cardWidth = hud.layout.endScreen.compactSizes.cardWidth + 2 * look.outline
		expect(touch.Size).toEqual(UDim2.fromOffset(cardWidth, HudScreen.endHeight(config, true, 2, true, false)))
	end)

	-- HudScreen.endHeight is its parts' own heights and the gaps between them, whichever parts show; and it is as
	-- wide as the widest of them (the totals' chips side by side), so it fits the stage whole: on touch at a
	-- desktop's sizes a long result or long totals outgrow the card.
	it("stands as tall as its parts and the gaps between them, as wide as the widest", function()
		local card = hud.layout.endScreen.sizes.cardWidth + 2 * look.outline
		local function check(label: string, mvp: string?, options: { [string]: any }?): number
			local frame = mount(mvp, options)
			local stack, group = find(frame, "Stack") :: Frame, find(frame, "Group") :: Frame
			local height, widest, parts = 0, 0, 0
			for _, part in group:GetChildren() do
				if part:IsA("GuiObject") then
					height += part.Size.Y.Offset
					widest = math.max(widest, part.Size.X.Offset)
					parts += 1
				end
			end
			local chips = -hud.spacing
			for _, chip in (find(frame, "Totals") :: Frame):GetChildren() do
				if chip:IsA("GuiObject") then
					chips += chip.Size.X.Offset + hud.spacing
				end
			end
			widest = math.max(widest, chips)
			local stands = height + (parts - 1) * hud.layout.endScreen.gap
			expect(`{label}: {stack.Size.X.Offset} x {stack.Size.Y.Offset}`).toBe(`{label}: {widest} x {stands}`)
			Fixtures.unmountAll()
			return widest
		end
		check("desktop", "1")
		check("no MVP", nil)
		check("phone, touch", "1", { compact = true, touch = true })
		check("phone, keyboard", "1", { compact = true })
		local function long(texts: { [string]: string }): { [string]: any }
			local wide = Fixtures.config({ UI = { text = texts } })
			return { touch = true, config = wide, text = HudText.new(wide) }
		end
		expect(check("a long result", "1", long({ wins = "%s WINS THE WHOLE MATCH!" })) > card).toBe(true)
		expect(check("long totals", "1", long({ teamTotal = "%s TEAM SCORED %d GOALS" })) > card).toBe(true)
	end)

	-- Every HUD change animates (Q194): it pops in as the match ends.
	it("pops in through its binding", function()
		local group = find(mount("1"), "Group") :: Frame
		setPop(0.5)
		expect((group:FindFirstChild("Pop") :: UIScale).Scale).toBe(0.5)
	end)
end)
