--!strict
-- Lets the test run give way to the engine now and then (#404, the owner's Q286). Jest Roblox runs test after test
-- without yielding (it yields between spec files), so a file of synchronous tests is one long stretch for the server's
-- watchdog, which stops a script that runs too long without yielding ("Script timeout: exhausted allowed execution
-- time"): in slow cloud runs it stopped a Match test and left Jest waiting until the task's 300 s limit. The longest
-- stretch measured in Studio was 5.47 s, around Match.spec. After each test (Setup registers it for every spec file),
-- it waits a frame once the stretch since its last wait, or since the file loaded, reaches `limit`.

local YieldGuard = {
	-- Seconds: far under the watchdog, and a frame's wait only now and then (a full run is about 20 s in Studio).
	limit = 1,
}

local lastYield = os.clock()

-- After a test: a frame's wait once the stretch reaches the limit.
function YieldGuard.afterEach()
	if os.clock() - lastYield >= YieldGuard.limit then
		task.wait()
		lastYield = os.clock()
	end
end

return YieldGuard
