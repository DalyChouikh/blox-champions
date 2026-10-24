--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local EndScreen = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.EndScreen)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

local config = Fixtures.config()
local colors = config.UI.teamColors
local text = HudText.new(config)
local NAMES = { ["1"] = "Ana", ["2"] = "Rex" }

local folder: Folder
-- The HUD's area, as the Hud's binding gives it.
local area: React.Binding<Vector2>, setArea: (Vector2) -> ()

-- Blue won 5-3: Ana (Blue) scored 5, Rex (Orange) 3; or `players` instead of them.
local function screen(mvp: string?, players: { Types.PlayerStats }?): React.ReactElement
	local ana = Fixtures.playerStats("1", "Blue", true)
	ana.score, ana.goals = 5, 5
	local rex = Fixtures.playerStats("2", "Orange", true)
	rex.score = 3
	local ended: HudState.Ended = {
		winner = "Blue",
		mvp = mvp,
		stats = { scores = { Blue = 5, Orange = 3 }, players = players or { ana, rex } },
	}
	return React.createElement(React.Fragment, nil, {
		EndScreen = React.createElement(
			EndScreen,
			{ config = config, text = text, ended = ended, names = NAMES, localId = "2", area = area }
		),
	})
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "EndScreenTest"
	folder.Parent = workspace
	area, setArea = React.createBinding(Vector2.zero)
end)

afterEach(function()
	folder:Destroy()
end)

describe("EndScreen", function()
	it("shows the winner, the MVP's card and both teams' totals", function()
		local mounted, rerender = Fixtures.mount(screen("1"), folder)
		local frame = mounted:FindFirstChild("EndScreen") :: Frame
		local winner = frame:FindFirstChild("Winner") :: TextLabel
		expect(winner.Text).toBe("Blue WINS")
		expect(winner.TextColor3 == colors.Blue).toBe(true)
		local blue = frame:FindFirstChild("BlueTotal", true) :: TextLabel
		local orange = frame:FindFirstChild("OrangeTotal", true) :: TextLabel
		expect(blue.Text).toBe("5")
		expect(blue.TextColor3 == colors.Blue).toBe(true)
		expect(orange.Text).toBe("3")
		local mvp = frame:FindFirstChild("Mvp") :: Frame
		expect(mvp.Visible).toBe(true)
		expect((mvp:FindFirstChild("Title") :: TextLabel).Text).toBe(config.UI.text.mvp)
		local card = mvp:FindFirstChild("1", true) :: Frame
		expect((card:FindFirstChild("Name") :: TextLabel).Text).toBe("Ana")
		expect((card:FindFirstChild("Goals") :: TextLabel).Text).toBe("5")
		expect(mvp:FindFirstChild("2", true)).toBeNil()
		-- The whole score tab below, everyone in it.
		local everyone = frame:FindFirstChild("Table") :: Frame
		expect(everyone:FindFirstChild("1") ~= nil and everyone:FindFirstChild("2") ~= nil).toBe(true)

		rerender(screen(nil))
		expect(mvp.Visible).toBe(false)
	end)

	it("shrinks to fit a screen smaller than itself", function()
		-- A phone's safe area: (323 - 2 margins) / 520.
		setArea(Vector2.new(750, 323))
		local mounted = Fixtures.mount(screen("1"), folder)
		local fit = (mounted:FindFirstChild("EndScreen") :: Frame):FindFirstChild("Fit") :: UIScale
		expect(fit.Scale).toBeCloseTo(307 / 520, 4)
		setArea(Vector2.new(1920, 1000))
		expect(fit.Scale).toBe(1)
	end)

	it("fits by its parts once they make it taller than its size", function()
		-- The winner, the totals, the MVP's title and card, and twelve rows under the header, spacing apart, inside the
		-- padding: 630 px with the defaults, as Edit lays it out.
		local hud = config.UI.hud
		local row, gap = hud.layout.scoreTab.rowHeight, hud.spacing
		local tall = 2 * gap + 3 * (hud.titleSize + gap) + (2 * row + gap) + gap + (13 * row + 12 * gap)
		setArea(Vector2.new(750, 323))
		local mounted = Fixtures.mount(screen("1", Fixtures.roster(12)), folder)
		local fit = (mounted:FindFirstChild("EndScreen") :: Frame):FindFirstChild("Fit") :: UIScale
		expect(fit.Scale).toBeCloseTo((323 - 2 * hud.screenMargin) / tall, 4)
	end)
end)
