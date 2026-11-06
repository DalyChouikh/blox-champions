--!strict
-- Runs before every spec file's tests (jest.config's setupFilesAfterEnv): the hooks every spec file shares.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local YieldGuard = require(script.Parent.YieldGuard)

JestGlobals.afterEach(YieldGuard.afterEach)

-- A ModuleScript returns one value; nothing reads this one.
return nil
