--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)

local text = HudText.new(Fixtures.config())
local NAMES = { ["1"] = "Ana", ["2"] = "Rex" }

-- Only the fields HudText:worth reads.
local function worthOf(openFor: string?, streak: number): any
	return { goalOpenFor = openFor, streak = streak }
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

	-- Digits over the speedometer's own KM/H (#352, Q192).
	it("writes the speed in km/h, as the speedometer's digits", function()
		expect(text:speed(100)).toBe("120")
		expect(text:speed(0)).toBe("0")
	end)

	-- The owner (#305): the goal opens after a lap and is worth +1, +3, then +5; the scoreboard's chip says so while
	-- the goal is open (#352, Q188).
	it("writes what a goal is worth while the goal is open, and nothing while it is closed", function()
		expect(text:worth(worthOf(nil, 0))).toBeNil()
		expect(text:worth(worthOf(nil, 3))).toBeNil()
		expect(text:worth(worthOf("Blue", 1))).toBe("+1")
		expect(text:worth(worthOf("Orange", 2))).toBe("+3")
		expect(text:worth(worthOf("Blue", 5))).toBe("+5")
	end)

	it("names overtime and Last Chance under the clock, and nothing in regulation", function()
		expect(text:period(periodOf("Overtime"))).toBe("OVERTIME")
		expect(text:period(periodOf("LastChance"))).toBe("LAST CHANCE")
		expect(text:period(periodOf("Regulation"))).toBeNil()
	end)

	it("writes each banner and feed entry from Config.UI.text", function()
		expect(text:banner({ kind = "Goal", team = "Blue" })).toBe("GOAL!")
		expect(text:banner({ kind = "Denied", team = "Orange" })).toBe("DENIED!")
		expect(text:banner({ kind = "ClockWarning", value = 30 })).toBe("30 SECONDS")
		expect(text:banner({ kind = "LastChance", team = "Orange" })).toBe("LAST CHANCE")
		expect(text:banner({ kind = "Overtime" })).toBe("OVERTIME")
		expect(text:banner({ kind = "Countdown", value = 3 })).toBe("3")
		expect(text:banner({ kind = "Go", team = "Orange" })).toBe("GO ORANGE TEAM!")
		expect(text:feed(entry("Possession", "Blue", "1"), NAMES)).toBe("Ana has the ball")
		expect(text:feed(entry("Lap", "Blue", "1", 3), NAMES)).toBe("Lap 3 completed")
		expect(text:feed(entry("GoalOpen", "Orange"), NAMES)).toBe("Orange goal is active")
		expect(text:feed(entry("Goal", "Orange", "2"), NAMES)).toBe("Rex scored!")
		expect(text:feed(entry("Possession", "Blue", "77"), NAMES)).toBe("Player has the ball")
		expect(text:result("Orange")).toBe("Orange WINS")
		expect(text:result(nil)).toBe("DRAW")
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
