--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local TextWidths = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.TextWidths)

local FREDOKA, LUCKIEST = Enum.Font.FredokaOne, Enum.Font.LuckiestGuy
-- "Space" at 17 px in Source Sans, the font Roblox draws in until a font loads, and in Fredoka One (measured in
-- Studio, #364): a hint's key cap 52 px wide instead of 59.
local FALLBACK_SPACE, FREDOKA_SPACE = 36, 43

-- Roblox's own wait, put back after the tests that stand in for it.
local waitForFont = TextWidths.waitForFont

afterEach(function()
	TextWidths.waitForFont = waitForFont
end)

describe("TextWidths", function()
	it("measures a text once per font, size and text, in whole pixels rounded up", function()
		local calls = 0
		local widths = TextWidths.new(function(text: string, size: number, font: Enum.Font): number
			calls += 1
			return #text * size * (if font == FREDOKA then 0.5 else 0.6) + 0.2
		end)
		expect(widths:width("Space", 17, FREDOKA)).toBe(43)
		expect(widths:width("Space", 17, FREDOKA)).toBe(43)
		expect(calls).toBe(1)
		expect(widths:width("Space", 20, FREDOKA)).toBe(51)
		expect(widths:width("Space", 17, LUCKIEST)).toBe(52)
		expect(widths:width("Ctrl", 17, FREDOKA)).toBe(35)
		expect(calls).toBe(4)
		expect(widths.measures).toBe(4)
	end)

	it("forgets every width it kept, so one measured before its font loaded is measured again", function()
		local loaded = false
		local widths = TextWidths.new(function(_text: string, _size: number, _font: Enum.Font): number
			return if loaded then FREDOKA_SPACE else FALLBACK_SPACE
		end)
		expect(widths:width("Space", 17, FREDOKA)).toBe(FALLBACK_SPACE)
		expect(widths:width("Space", 17, LUCKIEST)).toBe(FALLBACK_SPACE)
		loaded = true
		expect(widths:width("Space", 17, FREDOKA)).toBe(FALLBACK_SPACE)
		widths:forget()
		expect(widths:width("Space", 17, FREDOKA)).toBe(FREDOKA_SPACE)
		expect(widths:width("Space", 17, LUCKIEST)).toBe(FREDOKA_SPACE)
		expect(widths.measures).toBe(4)
	end)

	it("calls back once every font has loaded, in its own thread, waiting on each in turn", function()
		local fonts = { Font.fromEnum(FREDOKA), Font.fromEnum(LUCKIEST) }
		local waited: { Font } = {}
		local loading: thread? = nil
		TextWidths.waitForFont = function(font: Font)
			table.insert(waited, font)
			-- The banners' font is still loading: its wait yields until the test lets it go.
			if font == fonts[2] then
				loading = coroutine.running()
				coroutine.yield()
			end
		end
		local calls = 0
		TextWidths.load(fonts, function()
			calls += 1
		end)
		expect(waited).toEqual(fonts)
		expect(calls).toBe(0)
		task.spawn(loading :: thread)
		expect(calls).toBe(1)
		expect(#waited).toBe(2)
	end)

	it("counts a font that cannot load as loaded, and still waits on the rest", function()
		local fonts = { Font.fromEnum(FREDOKA), Font.fromEnum(LUCKIEST) }
		local waited: { Font } = {}
		TextWidths.waitForFont = function(font: Font)
			table.insert(waited, font)
			if font == fonts[1] then
				error("Temp read failed.")
			end
		end
		local calls = 0
		TextWidths.load(fonts, function()
			calls += 1
		end)
		expect(waited).toEqual(fonts)
		expect(calls).toBe(1)
	end)

	-- A font with no family is one GetTextBoundsAsync refuses without a word in the output (probed; a missing file or
	-- asset prints a line).
	it("waits through Roblox's GetTextBoundsAsync, which throws for a font it cannot load", function()
		waitForFont(Font.fromEnum(FREDOKA))
		expect(function()
			waitForFont(Font.new(""))
		end).toThrow()
	end)
end)
