--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Validate = require(ReplicatedStorage.Shared.Config.Validate)

describe("Validate", function()
	it("accepts valid numbers and reports type mismatches", function()
		local v = Validate.number()
		expect(v(3, "Match.pointsToWin")).toEqual({})
		expect(v("5", "Match.pointsToWin")).toEqual({ "Match.pointsToWin: expected number, got string" })
	end)

	it("rejects NaN and infinite numbers", function()
		local v = Validate.number()
		expect(v(0 / 0, "X.n")).toEqual({ "X.n: must not be NaN" })
		expect(v(math.huge, "X.n")).toEqual({ "X.n: must be finite" })
	end)

	it("enforces min, max and integer", function()
		local v = Validate.number({ min = 1, max = 6, integer = true })
		expect(v(0, "Match.teamSize")).toEqual({ "Match.teamSize: must be >= 1 (got 0)" })
		expect(v(7, "Match.teamSize")).toEqual({ "Match.teamSize: must be <= 6 (got 7)" })
		expect(v(2.5, "Match.teamSize")).toEqual({ "Match.teamSize: must be an integer (got 2.5)" })
	end)

	it("enforces an exclusive lower bound with above", function()
		local v = Validate.number({ above = 0 })
		expect(v(0.5, "A.size")).toEqual({})
		expect(v(0, "A.size")).toEqual({ "A.size: must be > 0 (got 0)" })
	end)

	-- A slope short of upright (wallAngle, pumpFlatSlopeDeg, the incline): one rule, not three copies (#303).
	it("enforces an exclusive upper bound with below", function()
		local v = Validate.number({ min = 0, below = 90 })
		expect(v(89.9, "A.deg")).toEqual({})
		expect(v(90, "A.deg")).toEqual({ "A.deg: must be < 90 (got 90)" })
	end)

	it("validates booleans and strings with oneOf", function()
		expect(Validate.boolean()(1, "B")).toEqual({ "B: expected boolean, got number" })
		local s = Validate.string({ oneOf = { "Hold", "Toggle" } })
		expect(s("Hold", "Input.mode")).toEqual({})
		expect(s("Press", "Input.mode")).toEqual({ 'Input.mode: must be one of Hold, Toggle (got "Press")' })
	end)

	it("rejects empty strings when nonEmpty is set", function()
		local s = Validate.string({ nonEmpty = true })
		expect(s("NormalChampions", "Mode.id")).toEqual({})
		expect(s("", "Mode.id")).toEqual({ "Mode.id: must not be empty" })
	end)

	it("accepts any table for Validate.table and rejects non-tables", function()
		expect(Validate.table()({ anything = 1 }, "Mode.overrides")).toEqual({})
		expect(Validate.table()(1, "Mode.overrides")).toEqual({ "Mode.overrides: expected table, got number" })
	end)

	it("requires exact record keys and collects every error", function()
		local v = Validate.record({ a = Validate.number(), b = Validate.boolean() })
		local errors = v({ a = "x", c = 1 }, "Root")
		table.sort(errors)
		expect(errors).toEqual({
			"Root.a: expected number, got string",
			"Root.b: missing",
			"Root.c: unknown key",
		})
	end)

	it("uses bare keys when the path is empty", function()
		local v = Validate.record({ Match = Validate.record({}) })
		expect(v({ Mtach = {} }, "")).toEqual({ "Match: missing", "Mtach: unknown key" })
	end)

	it("applies a check only when the inner validator passes", function()
		local inner = Validate.record({ low = Validate.number(), high = Validate.number() })
		local v = Validate.check(inner, function(value)
			return value.high > value.low
		end, "high must be greater than low")
		expect(v({ low = 1, high = 2 }, "R")).toEqual({})
		expect(v({ low = 3, high = 2 }, "R")).toEqual({ "R: high must be greater than low" })
		expect(v({ low = 3 }, "R")).toEqual({ "R.high: missing" })
	end)

	it("applies a list of rules in order and reports only the first that fails", function()
		local inner = Validate.record({ low = Validate.number(), high = Validate.number() })
		local v = Validate.checkAll(inner, {
			{
				message = "high must be greater than low",
				holds = function(value: any): boolean
					return value.high > value.low
				end,
			},
			{
				message = "high must be below 10",
				holds = function(value: any): boolean
					return value.high < 10
				end,
			},
		})
		expect(v({ low = 1, high = 2 }, "R")).toEqual({})
		expect(v({ low = 3, high = 20 }, "R")).toEqual({ "R: high must be below 10" })
		expect(v({ low = 30, high = 20 }, "R")).toEqual({ "R: high must be greater than low" })
		expect(v({ low = 3 }, "R")).toEqual({ "R.high: missing" })
	end)

	it("assertValid throws a message listing every error, and passes silently when valid", function()
		local v = Validate.record({ a = Validate.number(), b = Validate.number() })
		expect(function()
			Validate.assertValid({ a = "x", b = "y" }, v, "Cfg")
		end).toThrow(
			"Invalid config:\n  - Cfg.a: expected number, got string\n  - Cfg.b: expected number, got string"
		)
		expect(function()
			Validate.assertValid({ a = 1, b = 2 }, v, "Cfg")
		end).never.toThrow()
	end)

	it("assertValid can name what is invalid with a custom heading", function()
		local v = Validate.record({ a = Validate.number() })
		expect(function()
			Validate.assertValid({ a = "x" }, v, "Opts", "MatchEngine: invalid options")
		end).toThrow("MatchEngine: invalid options:\n  - Opts.a: expected number, got string")
	end)

	it("checks Roblox value types by name", function()
		local v = Validate.datatype("Vector3")
		expect(v(Vector3.zero, "G")).toEqual({})
		expect(v(CFrame.identity, "G")).toEqual({ "G: expected Vector3, got CFrame" })
	end)

	it("accepts a size in pixels, and rejects a scale or an offset of 0 or less", function()
		local v = Validate.pixels()
		local message = "S: must be in pixels (scales 0, offsets > 0)"
		expect(v(UDim2.fromOffset(640, 110), "S")).toEqual({})
		expect(v(UDim2.new(0.5, 0, 0, 110), "S")).toEqual({ message })
		expect(v(UDim2.new(0, 640, 0.1, 110), "S")).toEqual({ message })
		expect(v(UDim2.fromOffset(0, 110), "S")).toEqual({ message })
		expect(v(UDim2.fromOffset(640, -1), "S")).toEqual({ message })
		expect(v(Vector2.new(640, 110), "S")).toEqual({ "S: expected UDim2, got Vector2" })
	end)

	it("validates every item of a list with an indexed path", function()
		local v = Validate.list(Validate.number({ min = 1 }))
		expect(v({}, "UI.clockWarnings")).toEqual({})
		expect(v({ 3, 0 }, "UI.clockWarnings")).toEqual({ "UI.clockWarnings[2]: must be >= 1 (got 0)" })
	end)

	it("checks Enum items by their enum", function()
		local key = Validate.enumItem(Enum.KeyCode)
		expect(key(Enum.KeyCode.F, "k")).toEqual({})
		expect(key(Enum.UserInputType.Touch, "k")).toEqual({ "k: must be a KeyCode (got Enum.UserInputType.Touch)" })
		expect(key("F", "k")).toEqual({ 'k: must be a KeyCode (got "F")' })
	end)

	it("tagged picks the variant named by the tag", function()
		local v = Validate.tagged("kind", {
			A = Validate.record({ kind = Validate.string() }),
			B = Validate.record({ kind = Validate.string(), n = Validate.number() }),
		})
		expect(v({ kind = "A" }, "M")).toEqual({})
		expect(v({ kind = "B", n = 1 }, "M")).toEqual({})
		expect(v({ kind = "A", n = 1 }, "M")).toEqual({ "M.n: unknown key" })
		expect(v({ kind = "B" }, "M")).toEqual({ "M.n: missing" })
	end)

	it("tagged rejects a missing or unknown tag by name", function()
		local v = Validate.tagged("kind", { A = Validate.record({ kind = Validate.string() }) })
		expect(v({}, "M")).toEqual({ "M.kind: must be one of A (got nil)" })
		expect(v({ kind = "Fly" }, "M")).toEqual({ 'M.kind: must be one of A (got "Fly")' })
		expect(v(5, "M")).toEqual({ "M: expected table, got number" })
	end)

	it("rejects non-tables and tables that are not lists", function()
		local v = Validate.list(Validate.number())
		expect(v(5, "L")).toEqual({ "L: expected table, got number" })
		expect(v({ a = 1 }, "L")).toEqual({ "L: must be a list" })
		expect(v({ [1] = 1, [3] = 3 }, "L")).toEqual({ "L: must be a list" })
	end)
end)
