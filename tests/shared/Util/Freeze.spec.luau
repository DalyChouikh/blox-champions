--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Freeze = require(ReplicatedStorage.Shared.Util.Freeze)

describe("Freeze.deep", function()
	it("freezes a table and every nested table, returning the same table", function()
		local t = { a = 1, nested = { b = 2, deeper = { c = 3 } }, list = { 1, 2 } }
		local result = Freeze.deep(t)
		expect(result).toBe(t)
		expect(table.isfrozen(t)).toBe(true)
		expect(table.isfrozen(t.nested)).toBe(true)
		expect(table.isfrozen(t.nested.deeper)).toBe(true)
		expect(table.isfrozen(t.list)).toBe(true)
	end)

	it("makes writes throw", function()
		local t: any = Freeze.deep({ a = 1 })
		expect(function()
			t.a = 2
		end).toThrow()
	end)

	it("returns non-table values unchanged", function()
		expect(Freeze.deep(5)).toBe(5)
		expect(Freeze.deep("x")).toBe("x")
		expect(Freeze.deep(true)).toBe(true)
	end)

	it("freezes children of a table that was already frozen", function()
		local child = { y = 2 }
		local t = Freeze.deep(table.freeze({ child = child }))
		expect(table.isfrozen(t)).toBe(true)
		expect(table.isfrozen(child)).toBe(true)
	end)

	it("handles cycles without infinite recursion", function()
		local a: any = {}
		a.self = a
		expect(function()
			Freeze.deep(a)
		end).never.toThrow()
		expect(table.isfrozen(a)).toBe(true)
	end)
end)
