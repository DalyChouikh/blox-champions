--!strict
-- Shared test data. Not a spec file, so Jest never runs it as a test.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Fixtures = {}

function Fixtures.mode(overrides: { [string]: any }?): Config.Mode
	return { id = "Test", displayName = "Test", itemsEnabled = false, overrides = overrides or {} }
end

function Fixtures.config(overrides: { [string]: any }?): Config.GameConfig
	return Config.forMode(Fixtures.mode(overrides))
end

return Fixtures
