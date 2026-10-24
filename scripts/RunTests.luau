--!strict
-- Runs the Jest Roblox suite inside Studio and returns a summary table.
-- Invoke from the Studio command bar or the Studio MCP `execute_luau` tool (Edit DataModel):
--   return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "Freeze" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type RunOptions = {
	testNamePattern: string?,
	testPathPattern: string?,
}

export type Summary = {
	success: boolean,
	numTotalTests: number,
	numPassedTests: number,
	numFailedTests: number,
	numFailedTestSuites: number,
	failureMessages: { string },
}

local REQUIRED_CHILDREN = { "Packages", "DevPackages", "Tests" }

local NO_TESTS_GUIDANCE = "No tests matched, or Jest could not start. If you passed testPathPattern or "
	.. "testNamePattern, check that it matches a test file or test name."

local function failedSummary(message: string): Summary
	return {
		success = false,
		numTotalTests = 0,
		numPassedTests = 0,
		numFailedTests = 0,
		numFailedTestSuites = 0,
		failureMessages = { message },
	}
end

local function execute(options: RunOptions?): Summary
	for _, childName in REQUIRED_CHILDREN do
		if ReplicatedStorage:FindFirstChild(childName) == nil then
			return failedSummary(
				`Test environment missing: {childName}. Run \`wally install\` and serve test.project.json with Rojo.`
			)
		end
	end

	local runOptions: RunOptions = options or {}
	local tests = (ReplicatedStorage :: any).Tests
	local Jest = require((ReplicatedStorage :: any).DevPackages.Jest) :: any

	local status, result = Jest.runCLI(tests, {
		ci = true,
		verbose = false,
		testNamePattern = runOptions.testNamePattern,
		testPathPattern = runOptions.testPathPattern,
	}, { tests }):awaitStatus()

	if status ~= "Resolved" then
		local summary = failedSummary(NO_TESTS_GUIDANCE)
		table.insert(summary.failureMessages, tostring(result))
		return summary
	end

	local results = result.results
	local failureMessages: { string } = {}
	if results.numTotalTests == 0 then
		table.insert(failureMessages, NO_TESTS_GUIDANCE)
	end
	for _, testResult in results.testResults do
		if type(testResult.failureMessage) == "string" and testResult.failureMessage ~= "" then
			table.insert(failureMessages, testResult.failureMessage)
		end
		if testResult.testExecError ~= nil and testResult.testExecError.message ~= nil then
			table.insert(failureMessages, tostring(testResult.testExecError.message))
		end
	end

	return {
		success = results.numFailedTestSuites == 0 and results.numFailedTests == 0 and results.numTotalTests > 0,
		numTotalTests = results.numTotalTests,
		numPassedTests = results.numPassedTests,
		numFailedTests = results.numFailedTests,
		numFailedTestSuites = results.numFailedTestSuites,
		failureMessages = failureMessages,
	}
end

local function firstLine(message: string): string
	local plain = string.gsub(message, "\27%[[%d;]*m", "")
	return string.match(plain, "^%s*([^\n]*)") or ""
end

local function runTests(options: RunOptions?): Summary
	local summary = execute(options)
	if summary.success then
		print(`[RunTests] PASS {summary.numPassedTests}/{summary.numTotalTests} tests`)
	else
		local headline = if #summary.failureMessages > 0 then firstLine(summary.failureMessages[1]) else ""
		warn(`[RunTests] FAIL {summary.numPassedTests}/{summary.numTotalTests} tests passed: {headline}`)
	end
	return summary
end

return runTests
