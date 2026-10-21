--!strict
-- Ordered list of client modules started by Main. Later phases append controllers here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Util.Loader)

local modules: { Loader.LoadableModule } = {}

return modules
