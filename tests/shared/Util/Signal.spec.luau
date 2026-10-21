--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

describe("Signal", function()
	it("calls handlers in connection order with the fired arguments", function()
		local log = {}
		local signal: Signal.Signal<string, string> = Signal.new()
		signal:Connect(function(a, b)
			table.insert(log, "first:" .. a .. b)
		end)
		signal:Connect(function(a, b)
			table.insert(log, "second:" .. a .. b)
		end)
		signal:Fire("x", "y")
		expect(log).toEqual({ "first:xy", "second:xy" })
	end)

	it("stops calling a disconnected handler and marks it disconnected", function()
		local calls = 0
		local signal: Signal.Signal<()> = Signal.new()
		local connection = signal:Connect(function()
			calls += 1
		end)
		signal:Fire()
		connection:Disconnect()
		connection:Disconnect()
		signal:Fire()
		expect(calls).toBe(1)
		expect(connection.Connected).toBe(false)
	end)

	it("runs a Once handler only one time", function()
		local calls = 0
		local signal: Signal.Signal<()> = Signal.new()
		local connection = signal:Once(function()
			calls += 1
		end)
		signal:Fire()
		signal:Fire()
		expect(calls).toBe(1)
		expect(connection.Connected).toBe(false)
	end)

	it("skips a handler disconnected during the same fire", function()
		local log = {}
		local signal: Signal.Signal<()> = Signal.new()
		local second: any
		signal:Connect(function()
			table.insert(log, "first")
			second:Disconnect()
		end)
		second = signal:Connect(function()
			table.insert(log, "second")
		end)
		signal:Fire()
		expect(log).toEqual({ "first" })
	end)

	it("does not call a handler connected during fire until the next fire", function()
		local log = {}
		local signal: Signal.Signal<()> = Signal.new()
		local added = false
		signal:Connect(function()
			table.insert(log, "outer")
			if not added then
				added = true
				signal:Connect(function()
					table.insert(log, "inner")
				end)
			end
		end)
		signal:Fire()
		expect(log).toEqual({ "outer" })
		signal:Fire()
		expect(log).toEqual({ "outer", "outer", "inner" })
	end)

	it("keeps calling remaining handlers when one errors and reports the error", function()
		local reported = {}
		local signal: Signal.Signal<()> = Signal.new(function(message: string)
			table.insert(reported, message)
		end)
		local reachedSecond = false
		signal:Connect(function()
			error("boom")
		end)
		signal:Connect(function()
			reachedSecond = true
		end)
		signal:Fire()
		expect(reachedSecond).toBe(true)
		expect(#reported).toBe(1)
		expect(string.find(reported[1], "boom", 1, true) ~= nil).toBe(true)
	end)

	it("DisconnectAll disconnects every handler", function()
		local calls = 0
		local signal: Signal.Signal<()> = Signal.new()
		local a = signal:Connect(function()
			calls += 1
		end)
		local b = signal:Connect(function()
			calls += 1
		end)
		signal:DisconnectAll()
		signal:Fire()
		expect(calls).toBe(0)
		expect(a.Connected).toBe(false)
		expect(b.Connected).toBe(false)
	end)
end)
