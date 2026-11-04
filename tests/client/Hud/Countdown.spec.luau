--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local Countdown = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Countdown)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)

-- Round sizes of this spec's own: a 2 px ink; on a desktop's screen a 60 px digit in a 120 px ring with an 8 px stroke
-- (its ink reaching 124 across), on a phone's 30 in 60 with 4; the crosshair 30% down; the banner font's digits
-- drawn 0.15 of their size above their line's middle.
local config = Fixtures.config({
	UI = {
		hud = {
			look = { ink = Color3.fromRGB(10, 20, 30), textOutline = 2, bannerDigitRise = 0.15 },
			layout = {
				reticle = { height = 0.3 },
				countdown = {
					sizes = { textSize = 60, ringSize = 120, ringThickness = 8 },
					compactSizes = { textSize = 30, ringSize = 60, ringThickness = 4 },
				},
			},
		},
	},
})
local text = HudText.new(config)

local folder: Folder?

afterEach(function()
	Fixtures.unmountAll()
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
end)

type Shown = { compact: boolean?, visible: boolean?, drop: number? }

-- The count keyed as App keys it.
local function element(banner: HudState.Banner?, shown: Shown?): React.ReactElement
	local options: Shown = shown or {}
	return React.createElement(React.Fragment, nil, {
		Countdown = React.createElement(Countdown, {
			config = config,
			text = text,
			banner = banner,
			compact = options.compact == true,
			visible = options.visible ~= false,
			drop = options.drop or 0,
		}),
	})
end

local function mount(banner: HudState.Banner?, shown: Shown?): (Frame, (element: any) -> ())
	local parent = Instance.new("Folder")
	parent.Name = "CountdownTest"
	parent.Parent = workspace
	folder = parent
	local mounted, rerender = Fixtures.mount(element(banner, shown), parent)
	return mounted:FindFirstChild("Countdown") :: Frame, rerender
end

local function digitIn(count: Frame): TextLabel
	return count:FindFirstChild("Digit", true) :: TextLabel
end

local function stroke(count: Frame, name: string): UIStroke
	return (count:FindFirstChild(name) :: Instance):FindFirstChildOfClass("UIStroke") :: UIStroke
end

describe("Countdown", function()
	-- RC's count a third down, where the crosshair sits once someone carries (the owner, Q185; Video 31 at 17.0 s), its
	-- digit inside a ring, both in the player's own team colour (Q108, Q110), in look C (#353).
	it("shows the count's digit inside a ring at the crosshair's place, both in its team's colour over ink", function()
		local count = mount({ kind = "Countdown", team = "Orange", value = 3 })
		local orange = config.UI.hud.look.teamColors.Orange
		expect(count.Visible).toBe(true)
		expect(count.AnchorPoint == Vector2.new(0.5, 0.5)).toBe(true)
		expect(count.Position).toEqual(UDim2.fromScale(0.5, 0.3))
		expect(count.Size).toEqual(UDim2.fromOffset(124, 124))
		expect(stroke(count, "Line").Thickness).toBe(8)
		expect(stroke(count, "Line").Color == orange).toBe(true)
		expect(stroke(count, "Ink").Color == Color3.fromRGB(10, 20, 30)).toBe(true)
		local digit = digitIn(count)
		expect(digit.Text).toBe("3")
		expect(digit.Font).toBe(config.UI.hud.look.bannerFont)
		expect(digit.TextSize).toBe(60)
		expect(digit.TextColor3 == orange).toBe(true)
		expect(digit.Size).toEqual(UDim2.fromScale(1, 1))
		-- 0.15 x 60 = 9 px lower, so the digit's drawn shape sits at the ring's centre (the owner, Q204).
		expect(digit.Position).toEqual(UDim2.fromOffset(0, 9))
		expect((digit:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness).toBe(2)
	end)

	-- It aims nothing, so where its ring would touch the scoreboard it moves down rather than shrink (Q203).
	it("sits its drop lower, as HudScreen.countDrop gives it", function()
		local count = mount({ kind = "Countdown", team = "Blue", value = 2 }, { drop = 18 })
		expect(count.Position).toEqual(UDim2.new(0.5, 0, 0.3, 18))
	end)

	it("draws a phone's sizes on a phone's screen", function()
		local count = mount({ kind = "Countdown", team = "Blue", value = 1 }, { compact = true })
		expect(count.Size).toEqual(UDim2.fromOffset(64, 64))
		expect(stroke(count, "Line").Thickness).toBe(4)
		expect(digitIn(count).TextSize).toBe(30)
		-- 0.15 x 30 = 4.5 px lower, rounded to whole pixels (an offset holds whole pixels).
		expect(digitIn(count).Position).toEqual(UDim2.fromOffset(0, 5))
	end)

	it("hides without a count, for any other banner, and while told to hide", function()
		local count, rerender = mount(nil)
		expect(count.Visible).toBe(false)
		rerender(element({ kind = "Go", team = "Blue" }))
		expect(count.Visible).toBe(false)
		rerender(element({ kind = "Countdown", team = "Blue", value = 4 }, { visible = false }))
		expect(count.Visible).toBe(false)
		rerender(element({ kind = "Countdown", team = "Blue", value = 4 }))
		expect(count.Visible).toBe(true)
		expect(digitIn(count).Text).toBe("4")
	end)
end)
