--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Scoreboard = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Scoreboard)

local config = Fixtures.config()
local colors = config.UI.teamColors
local text = HudText.new(config)

local folder: Folder
local clock: React.Binding<string>
local setClock: (string) -> ()

-- The scoreboard keyed as App keys it, which names its frame.
local function board(overrides: { [string]: any }?, carrier: string?): React.ReactElement
	local snapshot = Fixtures.matchSnapshot(overrides)
	return React.createElement(React.Fragment, nil, {
		Scoreboard = React.createElement(Scoreboard, {
			config = config,
			text = text,
			match = snapshot.match,
			names = snapshot.names,
			carrier = carrier,
			clock = clock,
		}),
	})
end

-- The scoreboard's part called `name`, wherever it sits inside.
local function part(mounted: Folder, name: string): any
	return (mounted:FindFirstChild("Scoreboard") :: Instance):FindFirstChild(name, true)
end

-- How many frames `container` holds, and how many of them are filled in `color`.
local function filled(container: Instance, color: Color3): (number, number)
	local count, full = 0, 0
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			count += 1
			if child.BackgroundTransparency == 0 and child.BackgroundColor3 == color then
				full += 1
			end
		end
	end
	return count, full
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ScoreboardTest"
	folder.Parent = workspace
	clock, setClock = React.createBinding("4:59")
end)

afterEach(function()
	Fixtures.unmountAll()
	folder:Destroy()
end)

describe("Scoreboard", function()
	it("shows both scores, a pip per point to win, and the clock", function()
		local mounted = Fixtures.mount(board({ scores = { Blue = 2, Orange = 1 } }), folder)
		expect(part(mounted, "BlueScore").Text).toBe("2")
		expect(part(mounted, "OrangeScore").Text).toBe("1")
		local bluePips, blueFull = filled(part(mounted, "BluePips"), colors.Blue)
		expect(bluePips).toBe(config.Match.pointsToWin)
		expect(blueFull).toBe(2)
		local orangePips, orangeFull = filled(part(mounted, "OrangePips"), colors.Orange)
		expect(orangePips).toBe(config.Match.pointsToWin)
		expect(orangeFull).toBe(1)
		expect(part(mounted, "Clock").Text).toBe("4:59")
		-- A binding writes the label at once, with no new render.
		setClock("4:58")
		expect(part(mounted, "Clock").Text).toBe("4:58")
	end)

	it("names the carrier in their team's colour, and nobody while the ball is loose", function()
		local mounted, rerender = Fixtures.mount(board(nil, "2"), folder)
		local carrier = part(mounted, "Carrier")
		expect(carrier.Visible).toBe(true)
		expect(carrier.Text).toBe("Rex")
		expect(carrier.TextColor3 == colors.Orange).toBe(true)
		rerender(board(nil, nil))
		expect(carrier.Visible).toBe(false)
	end)

	it(
		"fills a segment per gate crossed this lap, labels laps or the goal's worth, glows while the goal is open",
		function()
			local mounted, rerender =
				Fixtures.mount(board({ possessingTeam = "Blue", lapProgress = 2, streak = 0 }), folder)
			local lapBar = part(mounted, "LapBar")
			local glow = part(mounted, "Glow")
			local segments, full = filled(part(mounted, "Segments"), colors.Blue)
			expect(lapBar.Visible).toBe(true)
			expect(segments).toBe(4)
			expect(full).toBe(2)
			expect(part(mounted, "LapLabel").Text).toBe("Lap 0")
			expect(glow.Enabled).toBe(false)

			rerender(board({ possessingTeam = "Blue", streak = 5, goalOpenFor = "Blue" }))
			expect(part(mounted, "LapLabel").Text).toBe("Lap 5: goal +5")
			expect(glow.Enabled).toBe(true)
			expect(glow.Color == colors.Blue).toBe(true)

			-- The other team's goal being open is not this team's glow.
			rerender(board({ possessingTeam = "Blue", streak = 2, goalOpenFor = "Orange" }))
			expect(glow.Enabled).toBe(false)

			rerender(board(nil))
			expect(lapBar.Visible).toBe(false)
		end
	)

	it("says OVERTIME in overtime", function()
		local mounted, rerender = Fixtures.mount(board({ period = "Overtime" }), folder)
		local period = part(mounted, "Period")
		expect(period.Visible).toBe(true)
		expect(period.Text).toBe("OVERTIME")
		rerender(board({ period = "Regulation" }))
		expect(period.Visible).toBe(false)
	end)

	it("says LAST CHANCE through Last Chance, in the trailing team's colour", function()
		local mounted, rerender =
			Fixtures.mount(board({ period = "LastChance", trailingTeam = "Orange", secondsLeft = 0 }), folder)
		local period = part(mounted, "Period")
		expect(period.Visible).toBe(true)
		expect(period.Text).toBe("LAST CHANCE")
		expect(period.TextColor3 == colors.Orange).toBe(true)
		-- A trailing team that equalises plays overtime, which is no team's.
		rerender(board({ period = "Overtime" }))
		expect(period.Text).toBe("OVERTIME")
		expect(period.TextColor3 == config.UI.hud.textColor).toBe(true)
	end)
end)
