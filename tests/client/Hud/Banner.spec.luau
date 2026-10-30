--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Banner = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Banner)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)

local config = Fixtures.config()
local text = HudText.new(config)

local folder: Folder
-- The HUD's area, as the Hud's binding gives it.
local area: React.Binding<Vector2>, setArea: (Vector2) -> ()

-- The banner keyed as App keys it, which names its label.
local function banner(shown: HudState.Banner?): React.ReactElement
	return React.createElement(React.Fragment, nil, {
		Banner = React.createElement(Banner, { config = config, text = text, banner = shown, area = area }),
	})
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "BannerTest"
	folder.Parent = workspace
	area, setArea = React.createBinding(Vector2.zero)
end)

afterEach(function()
	Fixtures.unmountAll()
	folder:Destroy()
end)

describe("Banner", function()
	it("shows the banner's text in its team's colour, and nothing without one", function()
		local mounted, rerender = Fixtures.mount(banner({ kind = "Goal", team = "Blue" }), folder)
		local label = mounted:FindFirstChild("Banner") :: TextLabel
		expect(label.Visible).toBe(true)
		expect(label.Text).toBe("GOAL!")
		expect(label.TextColor3 == config.UI.teamColors.Blue).toBe(true)
		expect(label.TextSize).toBe(config.UI.hud.bannerSize)
		rerender(banner(nil))
		expect(label.Visible).toBe(false)
	end)

	-- The owner (Q108, Q110): RC's count, a digit inside a ring, both in the player's own team colour.
	it("shows the kickoff count's digit inside a ring, both in its team's colour, and the ring only then", function()
		local countdown = config.UI.hud.countdown
		local mounted, rerender = Fixtures.mount(banner({ kind = "Countdown", team = "Orange", value = 2 }), folder)
		local label = mounted:FindFirstChild("Banner") :: TextLabel
		expect(label.Text).toBe("2")
		expect(label.TextSize).toBe(countdown.textSize)
		expect(label.TextColor3 == config.UI.teamColors.Orange).toBe(true)
		local ring = label:FindFirstChild("Ring") :: Frame
		expect(ring.Visible).toBe(true)
		expect(ring.Size).toEqual(UDim2.fromOffset(countdown.ringSize, countdown.ringSize))
		local stroke = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Thickness).toBe(countdown.ringThickness)
		expect(stroke.Color == config.UI.teamColors.Orange).toBe(true)
		rerender(banner({ kind = "Go", team = "Orange" }))
		expect(label.Text).toBe("GO ORANGE TEAM!")
		expect(label.TextSize).toBe(config.UI.hud.bannerSize)
		expect(ring.Visible).toBe(false)
	end)

	it("fits every banner's text on its label", function()
		local hud = config.UI.hud
		local size = hud.layout.banner.size
		local banners: { HudState.Banner } = {
			{ kind = "Goal" },
			{ kind = "Denied" },
			{ kind = "LastChance" },
			{ kind = "Overtime" },
			{ kind = "Go", team = "Blue" },
			{ kind = "Go", team = "Orange" },
		}
		for _, seconds in config.UI.clockWarnings do
			table.insert(banners, { kind = "ClockWarning", value = seconds })
		end
		for digit = 1, config.Match.kickoffCountdownSeconds do
			table.insert(banners, { kind = "Countdown", value = digit })
		end
		local tooBig: { string } = {}
		for _, shown in banners do
			local written = text:banner(shown)
			local textSize = if shown.kind == "Countdown" then hud.countdown.textSize else hud.bannerSize
			local bounds = TextService:GetTextSize(written, textSize, hud.font, Vector2.new(math.huge, math.huge))
			if bounds.X > size.X.Offset or bounds.Y > size.Y.Offset then
				table.insert(tooBig, written)
			end
		end
		expect(tooBig).toEqual({})
	end)

	it("shrinks to fit a screen narrower than itself", function()
		-- (480 - 2 margins) / 720.
		setArea(Vector2.new(480, 323))
		local mounted = Fixtures.mount(banner({ kind = "Goal", team = "Blue" }), folder)
		local fit = (mounted:FindFirstChild("Banner") :: TextLabel):FindFirstChild("Fit") :: UIScale
		expect(fit.Scale).toBeCloseTo(464 / 720, 4)
		setArea(Vector2.new(1920, 1000))
		expect(fit.Scale).toBe(1)
	end)
end)
