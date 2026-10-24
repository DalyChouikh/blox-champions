--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- The banner keyed as App keys it, which names its label.
local function banner(shown: HudState.Banner?): React.ReactElement
	return React.createElement(React.Fragment, nil, {
		Banner = React.createElement(Banner, { config = config, text = text, banner = shown }),
	})
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "BannerTest"
	folder.Parent = workspace
end)

afterEach(function()
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

	it("shows the countdown's digit in the HUD's text colour", function()
		local mounted = Fixtures.mount(banner({ kind = "Countdown", value = 2 }), folder)
		local label = mounted:FindFirstChild("Banner") :: TextLabel
		expect(label.Text).toBe("2")
		expect(label.TextColor3 == config.UI.hud.textColor).toBe(true)
	end)
end)
