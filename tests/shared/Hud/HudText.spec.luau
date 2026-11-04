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

local function entry(kind: HudState.FeedKind, team: "Blue" | "Orange", player: string): HudState.FeedEntry
	return { id = 1, kind = kind, team = team, player = player, timeLeft = 1, replaced = false }
end

describe("HudText", function()
	-- A key cooling down (#354, Q186): its seconds left to a tenth, rounded as the page's were, in this spec's own
	-- template; one string per tenth.
	it("writes a cooling key's seconds left to a tenth", function()
		local cooling = HudText.new(Fixtures.config({ UI = { text = { cooldown = "%.1fs" } } }))
		expect(cooling:cooldown(1.24)).toBe("1.2s")
		expect(cooling:cooldown(1.16)).toBe("1.2s")
		expect(cooling:cooldown(0.96)).toBe("1.0s")
		expect(cooling:cooldown(0.04)).toBe("0.0s")
		expect(cooling:cooldown(1.5)).toBe("1.5s")
	end)

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
		expect(text:banner({ kind = "Lap", team = "Blue", value = 3 })).toBe("LAP 3 COMPLETED")
		expect(text:banner({ kind = "GoalOpen", team = "Orange" })).toBe("ORANGE GOAL IS ACTIVE!")
		expect(text:feed(entry("Possession", "Blue", "1"), NAMES)).toBe("Ana has the ball")
		expect(text:feed(entry("Goal", "Orange", "2"), NAMES)).toBe("Rex scored!")
		expect(text:feed(entry("Possession", "Blue", "77"), NAMES)).toBe("Player has the ball")
		-- In the banners' capitals (#358, Q243).
		expect(text:result("Orange")).toBe("ORANGE WINS!")
		expect(text:result(nil)).toBe("DRAW")
	end)

	-- The end screen's MVP card and team totals (#358, the owner's Q243).
	it("writes the MVP's numbers and a team's total for the end screen", function()
		expect(text:mvpLine(320, 2, 3)).toBe("Score 320 \u{B7} Goals 2 \u{B7} Steals 3")
		expect(text:teamTotal("Blue", 5)).toBe("BLUE 5")
	end)

	-- The feed's chips (#369, the owner's Q221): the name in a colour by Roblox's rich text, the rest as written, and
	-- rich text's own characters shown as they are, in a name (a player's own) or a template (the config's).
	it("marks the player's name in a colour for a rich-text line, escaping rich text's characters", function()
		local blue = Color3.fromRGB(61, 139, 255)
		local orange = Color3.fromRGB(255, 154, 60)
		expect(text:feedMarked(entry("Possession", "Blue", "1"), NAMES, blue)).toBe(
			'<font color="#3d8bff">Ana</font> has the ball'
		)
		expect(text:feedMarked(entry("Goal", "Orange", "2"), NAMES, orange)).toBe(
			'<font color="#ff9a3c">Rex</font> scored!'
		)
		local marked = { ["3"] = `A<b>&'"` }
		expect(text:feedMarked(entry("Possession", "Blue", "3"), marked, blue)).toBe(
			'<font color="#3d8bff">A&lt;b&gt;&amp;&apos;&quot;</font> has the ball'
		)
		local own = HudText.new(Fixtures.config({ UI = { text = { scored = "%s & co scored!" } } }))
		expect(own:feedMarked(entry("Goal", "Blue", "1"), NAMES, blue)).toBe(
			'<font color="#3d8bff">Ana</font> &amp; co scored!'
		)
	end)

	-- Each row of the TAB board (#357): a Roblox user's headshot (a PlayerId is their decimal UserId); none for any
	-- other id (a Studio test player's negative one, a bot's), whose circle stays plain.
	it("gives a Roblox user's headshot for their avatar, and none for any other id", function()
		expect(text:avatar("156")).toBe("rbxthumb://type=AvatarHeadShot&id=156&w=48&h=48")
		for _, other in { "-1", "0", "07", "1.5", "bot", "" } do
			expect(`{other}: {text:avatar(other)}`).toBe(`{other}: nil`)
		end
		local own = HudText.new(
			Fixtures.config({ UI = { hud = { avatarImage = "rbxthumb://type=Avatar&id=%s&w=150&h=150" } } })
		)
		expect(own:avatar("7")).toBe("rbxthumb://type=Avatar&id=7&w=150&h=150")
	end)

	-- A team's bar on the TAB board names it in capitals, as the design page drew it (#357).
	it("names a team in capitals for its bar on the TAB board", function()
		expect(text:teamBar("Blue")).toBe("BLUE")
		local own = HudText.new(Fixtures.config({ UI = { teamNames = { Orange = "Les Oranges" } } }))
		expect(own:teamBar("Orange")).toBe("LES ORANGES")
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
