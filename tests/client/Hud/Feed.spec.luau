--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Feed = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Feed)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)

local config = Fixtures.config()
local colors = config.UI.teamColors
local text = HudText.new(config)
local NAMES = { ["1"] = "Ana", ["2"] = "Rex" }

local folder: Folder
-- The HUD's area, as the Hud's binding gives it.
local area: React.Binding<Vector2>, setArea: (Vector2) -> ()

local function entry(id: number, kind: HudState.FeedKind, team: "Blue" | "Orange", player: string?, value: number?)
	local made: HudState.FeedEntry = { id = id, kind = kind, team = team, player = player, value = value, timeLeft = 1 }
	return made
end

-- The feed keyed as App keys it, which names its frame.
local function feed(entries: { HudState.FeedEntry }): React.ReactElement
	return React.createElement(React.Fragment, nil, {
		Feed = React.createElement(Feed, { config = config, text = text, feed = entries, names = NAMES, area = area }),
	})
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "FeedTest"
	folder.Parent = workspace
	area, setArea = React.createBinding(Vector2.zero)
end)

afterEach(function()
	folder:Destroy()
end)

describe("Feed", function()
	it("lists the feed's entries in order, each in its team's colour", function()
		local mounted =
			Fixtures.mount(feed({ entry(3, "Possession", "Blue", "1"), entry(4, "Lap", "Orange", "2", 2) }), folder)
		local frame = mounted:FindFirstChild("Feed") :: Frame
		local first = frame:FindFirstChild("3") :: TextLabel
		local second = frame:FindFirstChild("4") :: TextLabel
		expect(first.Text).toBe("Ana has the ball")
		expect(first.TextColor3 == colors.Blue).toBe(true)
		expect(second.Text).toBe("Lap 2 completed")
		expect(second.TextColor3 == colors.Orange).toBe(true)
		expect(first.LayoutOrder < second.LayoutOrder).toBe(true)
	end)

	it("keeps an entry's label when older ones leave", function()
		local mounted, rerender =
			Fixtures.mount(feed({ entry(6, "Possession", "Blue", "1"), entry(7, "Possession", "Orange", "2") }), folder)
		local frame = mounted:FindFirstChild("Feed") :: Frame
		local kept = frame:FindFirstChild("7")
		rerender(feed({ entry(7, "Possession", "Orange", "2") }))
		expect(frame:FindFirstChild("6") == nil).toBe(true)
		expect(kept ~= nil and frame:FindFirstChild("7") == kept).toBe(true)
	end)

	it("shrinks to fit a screen narrower than itself", function()
		-- (400 - 2 margins) / 460.
		setArea(Vector2.new(400, 323))
		local mounted = Fixtures.mount(feed({ entry(1, "Possession", "Blue", "1") }), folder)
		local fit = (mounted:FindFirstChild("Feed") :: Frame):FindFirstChild("Fit") :: UIScale
		expect(fit.Scale).toBeCloseTo(384 / 460, 4)
		setArea(Vector2.new(1920, 1000))
		expect(fit.Scale).toBe(1)
	end)
end)
