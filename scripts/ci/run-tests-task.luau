--!strict
-- CI's cloud test task. scripts/ci/cloud_tests.py runs this script through Open Cloud Luau Execution in the test place
-- it uploaded (built from test.project.json); the task's output is what the script returns, so CI reads RunTests'
-- summary of the whole suite from it.

return require(game:GetService("ServerStorage").RunTests)()
