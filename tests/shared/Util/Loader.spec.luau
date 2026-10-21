--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Loader = require(ReplicatedStorage.Shared.Util.Loader)

-- Returns `any` so strict mode accepts the extra `receivedDeps` field when passed as a LoadableModule.
local function recorder(log: { string }, name: string, dependencies: { string }?): any
	return {
		name = name,
		dependencies = dependencies,
		receivedDeps = nil :: any,
		init = function(self, deps)
			self.receivedDeps = deps
			table.insert(log, name .. ".init")
		end,
		start = function(_self)
			table.insert(log, name .. ".start")
		end,
	}
end

-- pcall instead of toThrow: Jest's toThrow keeps only the text after the first "file:line:" in a string
-- error, which would drop the "Loader: module ..." prefix that wraps the inner error.
local function captureError(callback: () -> any): (boolean, string)
	local ok, err = pcall(callback)
	return ok, tostring(err)
end

describe("Loader.start", function()
	it("inits every module in order, then starts every module in order", function()
		local log = {}
		Loader.start({ recorder(log, "A"), recorder(log, "B") })
		expect(log).toEqual({ "A.init", "B.init", "A.start", "B.start" })
	end)

	it("passes only declared dependencies, including provided values", function()
		local log = {}
		local a = recorder(log, "A")
		local c = recorder(log, "C")
		local b = recorder(log, "B", { "A", "Config" })
		local config = { value = 1 }
		Loader.start({ a, c, b }, { Config = config })
		expect(b.receivedDeps.A).toBe(a)
		expect(b.receivedDeps.Config).toBe(config)
		expect(b.receivedDeps.C).toBeNil()
	end)

	it("returns the modules by name", function()
		local log = {}
		local a = recorder(log, "A")
		local registry = Loader.start({ a })
		expect(registry.A).toBe(a)
	end)

	it("accepts modules without init or start", function()
		expect(function()
			Loader.start({ { name = "Plain" } })
		end).never.toThrow()
	end)

	it("rejects duplicate names", function()
		expect(function()
			Loader.start({ { name = "A" }, { name = "A" } })
		end).toThrow('Loader: duplicate module name "A"')
	end)

	it("rejects a module name that collides with a provided value", function()
		expect(function()
			Loader.start({ { name = "Config" } }, { Config = {} })
		end).toThrow('Loader: module name "Config" collides with a provided value')
	end)

	it("rejects unknown dependencies", function()
		expect(function()
			Loader.start({ { name = "A", dependencies = { "Missing" } } })
		end).toThrow('Loader: module "A" depends on unknown module "Missing"')
	end)

	it("rejects dependencies declared later in the list", function()
		expect(function()
			Loader.start({ { name = "A", dependencies = { "B" } }, { name = "B" } })
		end).toThrow('Loader: module "A" depends on "B", which is declared after it')
	end)

	it("names the module that fails in init and starts nothing", function()
		local log = {}
		local broken = {
			name = "Broken",
			init = function()
				error("bad init")
			end,
		}
		local ok, message = captureError(function()
			return Loader.start({ recorder(log, "A"), broken })
		end)
		expect(ok).toBe(false)
		expect(string.find(message, 'Loader: module "Broken" failed in init: ', 1, true) ~= nil).toBe(true)
		expect(string.find(message, "bad init", 1, true) ~= nil).toBe(true)
		expect(log).toEqual({ "A.init" })
	end)

	it("names the module that fails in start", function()
		local broken = {
			name = "Broken",
			start = function()
				error("bad start")
			end,
		}
		local ok, message = captureError(function()
			return Loader.start({ broken })
		end)
		expect(ok).toBe(false)
		expect(string.find(message, 'Loader: module "Broken" failed in start: ', 1, true) ~= nil).toBe(true)
		expect(string.find(message, "bad start", 1, true) ~= nil).toBe(true)
	end)
end)
