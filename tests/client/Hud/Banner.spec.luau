--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Banner = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Banner)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Style)

-- Banners of this spec's own (#356): 40 px headlines, GOAL! 60, a lap 30, the message 20, a 3 px team ring over a
-- 2 px ink outline (5 px of ink), a 4 px shadow, floating up half their size as they leave; on a phone 24 to 14.
local config = Fixtures.config({
	UI = {
		hud = {
			screenMargin = 8,
			look = { shadow = 4, textOutline = 2, groupRoom = 3 },
			layout = {
				banner = {
					bottom = 20,
					rise = 0.5,
					sizes = { headline = 40, goal = 60, lap = 30, message = 20, edge = 3 },
					compactSizes = { headline = 24, goal = 36, lap = 18, message = 14, edge = 2 },
				},
			},
		},
	},
})
local text = HudText.new(config)
local FONT = config.UI.hud.look.bannerFont

local folder: Folder
-- The stage, as the Hud's binding gives it; the banner's pop and how far it has left, as its tracks give them.
local area: React.Binding<Vector2>, setArea: (Vector2) -> ()
local scale: React.Binding<number>, setScale: (number) -> ()
local leave: React.Binding<number>, setLeave: (number) -> ()

-- The banner keyed as App keys it: on the banner line `line` px down the stage, or (nil) the goal message.
local function banner(shown: HudState.Banner?, line: number?, compact: boolean?): React.ReactElement
	return React.createElement(React.Fragment, nil, {
		Banner = React.createElement(Banner, {
			config = config,
			text = text,
			banner = shown,
			compact = compact == true,
			line = line,
			scale = scale,
			leave = leave,
			area = area,
		}),
	})
end

-- The holder's size for `words` at `size` px: the text and 5 px of ink each side, the 4 px shadow under it.
local function box(words: string, size: number): Vector2
	return Vector2.new(Style.textWidth(config, words, size, FONT) + 10, size + 14)
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "BannerTest"
	folder.Parent = workspace
	area, setArea = React.createBinding(Vector2.new(1920, 1000))
	scale, setScale = React.createBinding(1)
	leave, setLeave = React.createBinding(0)
end)

afterEach(function()
	Fixtures.unmountAll()
	folder:Destroy()
end)

describe("Banner", function()
	it("letters the banner in look C at its kind's size, in its team's colour, and nothing without one", function()
		local mounted, rerender = Fixtures.mount(banner({ kind = "Goal", team = "Blue" }, 100), folder)
		local holder = mounted:FindFirstChild("Banner") :: Frame
		local group = holder:FindFirstChild("Group", true) :: CanvasGroup
		local front = group:FindFirstChild("Front") :: TextLabel
		expect(holder.Visible).toBe(true)
		expect(front.Text).toBe("GOAL!")
		expect(front.TextSize).toBe(60)
		local edge = group:FindFirstChild("Edge") :: TextLabel
		expect(edge.TextColor3 == config.UI.hud.look.teamColors.Blue).toBe(true)
		rerender(banner({ kind = "Lap", team = "Orange", value = 2 }, 100))
		expect(front.Text).toBe("LAP 2 COMPLETED")
		expect(front.TextSize).toBe(30)
		rerender(banner({ kind = "Go", team = "Orange" }, 100, true))
		expect(front.TextSize).toBe(24)
		rerender(banner(nil, 100))
		expect(holder.Visible).toBe(false)
	end)

	-- The kickoff count sits a third down in its own part (Hud/Countdown, #353, the owner's Q185).
	it("leaves the kickoff count to the Countdown, a third down", function()
		local mounted = Fixtures.mount(banner({ kind = "Countdown", team = "Orange", value = 2 }, 100), folder)
		expect((mounted:FindFirstChild("Banner") :: Frame).Visible).toBe(false)
	end)

	-- One line for the big banners and a completed lap (the owner, Q210): the text's centre on it.
	it("puts its text's centre on the banner line", function()
		local mounted = Fixtures.mount(banner({ kind = "Goal", team = "Blue" }, 100), folder)
		local holder = mounted:FindFirstChild("Banner") :: Frame
		local size = box("GOAL!", 60)
		expect(holder.Size).toEqual(UDim2.fromOffset(size.X, size.Y))
		expect(holder.Position).toEqual(UDim2.new(0.5, 0, 0, 100))
		-- The text's centre is 5 + 30 px down its holder.
		expect(holder.AnchorPoint.X).toBe(0.5)
		expect(holder.AnchorPoint.Y).toBeCloseTo(35 / size.Y, 6)
	end)

	-- The goal message where the feed was, RC's bottom centre (Video 4 at 7:23; Q211).
	it("puts the goal message's text messageBottom above the stage's bottom", function()
		local mounted = Fixtures.mount(banner({ kind = "GoalOpen", team = "Orange" }), folder)
		local holder = mounted:FindFirstChild("Banner") :: Frame
		local front = (holder:FindFirstChild("Group", true) :: CanvasGroup):FindFirstChild("Front") :: TextLabel
		expect(front.Text).toBe("ORANGE GOAL IS ACTIVE!")
		expect(front.TextSize).toBe(20)
		local size = box("ORANGE GOAL IS ACTIVE!", 20)
		expect(holder.Position).toEqual(UDim2.new(0.5, 0, 1, -HudScreen.messageBottom(config, false)))
		-- The text's bottom is 5 + 20 px down its holder.
		expect(holder.AnchorPoint.Y).toBeCloseTo(25 / size.Y, 6)
	end)

	-- Each pops in with a quick overshoot, holds, then floats up as it fades (the owner, Q191, Q194).
	it("pops round its text's centre, and fades whole while it leaves, floating up in whole pixels", function()
		local mounted = Fixtures.mount(banner({ kind = "Goal", team = "Blue" }, 100), folder)
		-- The lift is anchored on the text's centre, and the group that fades and pops is centred on the letters
		-- (the holder above the shadow), so the pop grows round the text's centre too.
		local lift = (mounted:FindFirstChild("Banner") :: Frame):FindFirstChild("Lift") :: Frame
		local group = lift:FindFirstChild("Group", true) :: CanvasGroup
		local size = box("GOAL!", 60)
		expect(lift.AnchorPoint.Y).toBeCloseTo(35 / size.Y, 6)
		expect((lift:FindFirstChild("Letters") :: Frame).Size).toEqual(UDim2.new(1, 0, 1, -4))
		expect(group.AnchorPoint).toEqual(Vector2.new(0.5, 0.5))
		expect(group.Position).toEqual(UDim2.fromScale(0.5, 0.5))
		setScale(1.1)
		expect((group:FindFirstChild("Pop") :: UIScale).Scale).toBeCloseTo(1.1, 4)
		expect(group.GroupTransparency).toBe(0)
		expect(lift.Position.Y.Offset).toBe(0)
		-- Half gone: half see-through, and up half of its 30 px rise; nearly gone, up 29 of the 30.
		setLeave(0.5)
		expect(group.GroupTransparency).toBeCloseTo(0.5, 4)
		expect(lift.Position.Y.Offset).toBe(-15)
		setLeave(0.97)
		expect(lift.Position.Y.Offset).toBe(-29)
		expect(lift.Position.Y.Scale).toBeCloseTo(35 / size.Y, 6)
	end)

	it("shrinks to fit a stage narrower than itself", function()
		local size = box("GOAL!", 60)
		setArea(Vector2.new(120, 323))
		local mounted = Fixtures.mount(banner({ kind = "Goal", team = "Blue" }, 100), folder)
		local fit = (mounted:FindFirstChild("Banner") :: Frame):FindFirstChild("Fit") :: UIScale
		expect(fit.Scale).toBeCloseTo((120 - 16) / size.X, 4)
		setArea(Vector2.new(1920, 1000))
		expect(fit.Scale).toBe(1)
	end)
end)

-- The game's own settings: every banner the game shows fits the phone's stage left of the touch buttons (504 px on
-- the phone emulator, TouchArea.stage) at its phone size, without shrinking.
describe("Banner's settings", function()
	it("fit every banner on a phone's stage at its size", function()
		local game = Fixtures.config()
		local gameText = HudText.new(game)
		local banners: { HudState.Banner } = {
			{ kind = "Goal" },
			{ kind = "Denied" },
			{ kind = "LastChance" },
			{ kind = "Overtime" },
			{ kind = "Lap", value = 9 },
		}
		for _, team: any in { "Blue", "Orange" } do
			table.insert(banners, { kind = "Go", team = team })
			table.insert(banners, { kind = "GoalOpen", team = team })
		end
		for _, seconds in game.UI.clockWarnings do
			table.insert(banners, { kind = "ClockWarning", value = seconds })
		end
		local room = 504 - 2 * game.UI.hud.screenMargin
		local ink = HudScreen.bannerInk(game, true)
		local tooWide: { string } = {}
		for _, shown in banners do
			local words = gameText:banner(shown)
			local size = HudScreen.bannerSize(game, true, shown.kind)
			if Style.textWidth(game, words, size, game.UI.hud.look.bannerFont) + 2 * ink > room then
				table.insert(tooWide, words)
			end
		end
		expect(tooWide).toEqual({})
	end)
end)

-- The banner as Roblox lays it out (a ScreenGui under StarterGui is laid out in Edit, after a frame).
describe("Banner, laid out", function()
	local gui: ScreenGui?

	afterEach(function()
		if gui ~= nil then
			gui:Destroy()
			gui = nil
		end
	end)

	-- A group cuts off the ink that reaches past its edges (#386, the owner's Q257).
	it("keeps look.groupRoom round its letters' ink inside the group that fades it", function()
		local layer = Instance.new("ScreenGui")
		layer.Name = "BannerLaidOutTest"
		layer.Parent = game:GetService("StarterGui")
		gui = layer
		setArea(Vector2.new(1556, 735))
		local mounted = Fixtures.mount(banner({ kind = "Goal", team = "Blue" }, 100), layer)
		task.wait()
		local group = mounted:FindFirstChild("Group", true) :: CanvasGroup
		-- Centred on the letters, the group reaches the shadow's 4 px above them too.
		expect(Fixtures.inkRoom(group)).toEqual({ left = 3, top = 7, right = 3, bottom = 3 })
	end)
end)
