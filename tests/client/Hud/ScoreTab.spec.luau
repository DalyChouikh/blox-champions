--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local ScoreTab = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.ScoreTab)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

local config = Fixtures.config()
local colors = config.UI.teamColors
local text = HudText.new(config)
local NAMES = { ["1"] = "Ana", ["2"] = "Rex", ["3"] = "Kai", ["9"] = "Gone" }

local folder: Folder
-- The HUD's area, as the Hud's binding gives it.
local area: React.Binding<Vector2>, setArea: (Vector2) -> ()

-- Ana (Blue) leads with 5, Kai (Blue) has 2, Rex (Orange) 4, and Gone (Blue) left: by team, then score.
local function stats(): Types.MatchStats
	local ana = Fixtures.playerStats("1", "Blue", true)
	ana.score, ana.goals, ana.assists, ana.saves, ana.steals = 5, 2, 1, 0, 3
	local kai = Fixtures.playerStats("3", "Blue", true)
	kai.score = 2
	local gone = Fixtures.playerStats("9", "Blue", false)
	local rex = Fixtures.playerStats("2", "Orange", true)
	rex.score, rex.saves = 4, 2
	return { scores = { Blue = 3, Orange = 1 }, players = { ana, kai, gone, rex } }
end

local function tab(): Frame
	local mounted = Fixtures.mount(
		React.createElement(React.Fragment, nil, {
			ScoreTab = React.createElement(
				ScoreTab,
				{ config = config, text = text, stats = stats(), names = NAMES, localId = "1", area = area }
			),
		}),
		folder
	)
	return mounted:FindFirstChild("ScoreTab") :: Frame
end

-- A row's cell: the text of its column called `column`.
local function cell(frame: Frame, row: string, column: string): TextLabel
	return (frame:FindFirstChild(row, true) :: Frame):FindFirstChild(column) :: TextLabel
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ScoreTabTest"
	folder.Parent = workspace
	area, setArea = React.createBinding(Vector2.zero)
end)

afterEach(function()
	folder:Destroy()
end)

describe("ScoreTab", function()
	it("lists every player by team, highest score first, with goals, assists, saves and steals", function()
		local frame = tab()
		local columns = config.UI.text.columns
		expect(cell(frame, "Header", "Name").Text).toBe(columns.player)
		expect(cell(frame, "Header", "Steals").Text).toBe(columns.steals)
		local texts: { string } = {}
		for _, column in { "Name", "Score", "Goals", "Assists", "Saves", "Steals" } do
			table.insert(texts, cell(frame, "1", column).Text)
		end
		expect(texts).toEqual({ "Ana", "5", "2", "1", "0", "3" })
		expect(cell(frame, "1", "Name").TextColor3 == colors.Blue).toBe(true)
		expect(cell(frame, "2", "Saves").Text).toBe("2")
		expect(cell(frame, "2", "Name").TextColor3 == colors.Orange).toBe(true)
		local orders: { number } = {}
		for _, id in { "1", "3", "9", "2" } do
			table.insert(orders, (frame:FindFirstChild(id, true) :: Frame).LayoutOrder)
		end
		expect(orders).toEqual({ 1, 2, 3, 4 })
	end)

	it("shrinks to fit a screen smaller than itself", function()
		-- A phone's safe area: (323 - 2 margins) / 360.
		setArea(Vector2.new(750, 323))
		local fit = tab():FindFirstChild("Fit") :: UIScale
		expect(fit.Scale).toBeCloseTo(307 / 360, 4)
		setArea(Vector2.new(1920, 1000))
		expect(fit.Scale).toBe(1)
	end)

	it("dims players who left and marks the local player", function()
		local frame = tab()
		expect(cell(frame, "9", "Name").TextTransparency).toBeCloseTo(config.UI.hud.dimTransparency, 5)
		expect(cell(frame, "9", "Score").TextTransparency).toBeCloseTo(config.UI.hud.dimTransparency, 5)
		expect(cell(frame, "3", "Name").TextTransparency).toBe(0)
		expect((frame:FindFirstChild("1", true) :: Frame):FindFirstChild("You") ~= nil).toBe(true)
		expect((frame:FindFirstChild("3", true) :: Frame):FindFirstChild("You")).toBeNil()
	end)
end)
