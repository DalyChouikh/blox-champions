--!strict
-- Ordered list of server modules started by Main. Later phases append services here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Util.Loader)

local modules: { Loader.LoadableModule } = {}

return modules
