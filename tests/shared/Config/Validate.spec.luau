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

	it("validates booleans and strings with oneOf", function()
		expect(Validate.boolean()(1, "B")).toEqual({ "B: expected boolean, got number" })
		local s = Validate.string({ oneOf = { "Hold", "Toggle" } })
		expect(s("Hold", "Input.mode")).toEqual({})
		expect(s("Press", "Input.mode")).toEqual({ 'Input.mode: must be one of Hold, Toggle (got "Press")' })
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
end)
