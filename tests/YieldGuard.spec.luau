--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeAll, afterAll = JestGlobals.beforeAll, JestGlobals.afterAll

local YieldGuard = require(ReplicatedStorage.Tests.YieldGuard)

-- A short limit for these tests, so they wait a few frames' worth instead of the run's.
local LIMIT = 0.05

-- Busy for `seconds` without yielding, as a long synchronous test is; returns how many times it looked at the clock.
local function busy(seconds: number): number
	local started = os.clock()
	local looks = 0
	while os.clock() - started < seconds do
		looks += 1
	end
	return looks
end

-- #404 (the owner's Q286): Jest Roblox runs test after test without yielding, so a run of synchronous specs was one
-- long stretch for the cloud server's watchdog, which killed a Match test in a slow run and left Jest waiting until
-- the task's 300 s limit. Every spec file yields once a test ends past the limit since its last yield.
describe("YieldGuard", function()
	local saved: number
	beforeAll(function()
		saved = YieldGuard.limit
		YieldGuard.limit = LIMIT
	end)
	afterAll(function()
		YieldGuard.limit = saved
	end)

	local ranAfterLong = false
	local ranAfterShort = false

	it("lets a test run past the limit", function()
		task.delay(0, function()
			ranAfterLong = true
		end)
		busy(LIMIT * 1.5)
	end)

	it("yields after a test that ended past the limit, so the engine runs in between", function()
		expect(ranAfterLong).toBe(true)
	end)

	it("lets a short test run", function()
		task.delay(0, function()
			ranAfterShort = true
		end)
	end)

	it("does not yield after a test that ended within the limit", function()
		expect(ranAfterShort).toBe(false)
	end)
end)
