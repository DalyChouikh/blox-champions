--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)

local text = HudText.new(Fixtures.config())
local NAMES = { ["1"] = "Ana", ["2"] = "Rex" }

-- Only the fields HudText:lap reads.
local function lapOf(team: string?, streak: number): any
	return { possessingTeam = team, streak = streak }
end

-- Only the field HudText:period reads.
local function periodOf(period: string): any
	return { period = period }
end

local function entry(
	kind: HudState.FeedKind,
	team: "Blue" | "Orange",
	player: string?,
	value: number?
): HudState.FeedEntry
	return { id = 1, kind = kind, team = team, player = player, value = value, timeLeft = 1 }
end

describe("HudText", function()
	it("writes the clock as minutes and seconds", function()
		expect(text:clock(300)).toBe("5:00")
		expect(text:clock(65)).toBe("1:05")
		expect(text:clock(59)).toBe("0:59")
		expect(text:clock(0)).toBe("0:00")
	end)

	it("writes the speed in km/h", function()
		expect(text:speed(100)).toBe("120 km/h")
		expect(text:speed(0)).toBe("0 km/h")
	end)

	it("names the lap or the streak of the team with the ball", function()
		expect(text:lap(lapOf(nil, 0))).toBeNil()
		expect(text:lap(lapOf("Blue", 2))).toBe("Lap 2/4")
		-- From the lap that opens the goal on, and still once a point closes it: the streak stays until the kickoff.
		expect(text:lap(lapOf("Blue", 4))).toBe("Streak 4/12")
		expect(text:lap(lapOf("Blue", 5))).toBe("Streak 5/12")
	end)

	it("names overtime and Last Chance under the clock, and nothing in regulation", function()
		expect(text:period(periodOf("Overtime"))).toBe("OVERTIME")
		expect(text:period(periodOf("LastChance"))).toBe("LAST CHANCE")
		expect(text:period(periodOf("Regulation"))).toBeNil()
	end)

	it("writes each banner and feed entry from Config.UI.text", function()
		expect(text:banner({ kind = "Goal", team = "Blue" })).toBe("GOAL!")
		expect(text:banner({ kind = "StreakPoint", team = "Blue" })).toBe("STREAK POINT!")
		expect(text:banner({ kind = "Denied", team = "Orange" })).toBe("DENIED!")
		expect(text:banner({ kind = "ClockWarning", value = 30 })).toBe("30 SECONDS")
		expect(text:banner({ kind = "LastChance", team = "Orange" })).toBe("LAST CHANCE")
		expect(text:banner({ kind = "Overtime" })).toBe("OVERTIME")
		expect(text:banner({ kind = "Countdown", value = 3 })).toBe("3")
		expect(text:feed(entry("Possession", "Blue", "1"), NAMES)).toBe("Ana has the ball")
		expect(text:feed(entry("Lap", "Blue", "1", 3), NAMES)).toBe("Lap 3 completed")
		expect(text:feed(entry("GoalOpen", "Orange"), NAMES)).toBe("Orange goal is active")
		expect(text:feed(entry("Goal", "Orange", "2"), NAMES)).toBe("Rex scored!")
		expect(text:feed(entry("StreakPoint", "Blue", "1"), NAMES)).toBe("Ana scored a streak point!")
		expect(text:feed(entry("Possession", "Blue", "77"), NAMES)).toBe("Player has the ball")
		expect(text:wins("Orange")).toBe("Orange WINS")
	end)

	it("fails loudly on a banner or feed kind it has no text for", function()
		expect(function()
			text:banner({ kind = "Nope" } :: any)
		end).toThrow('HudText: no banner text for kind "Nope"')
		expect(function()
			text:feed(entry("Nope" :: any, "Blue", "1"), NAMES)
		end).toThrow('HudText: no feed text for kind "Nope"')
	end)
end)
