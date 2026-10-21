--!strict
-- Client entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bootstrap = require(ReplicatedStorage.Shared.Util.Bootstrap)
local NormalChampions = require(ReplicatedStorage.Shared.Modes.NormalChampions)
local modules = require(script.Parent.Modules)

Bootstrap.run({
	realm = "Client",
	mode = NormalChampions,
	modules = modules,
})
