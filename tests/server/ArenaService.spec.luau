--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local ArenaService = require(game:GetService("ServerScriptService").Server.ArenaService)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

describe("ArenaService", function()
	it("builds the arena into the workspace at init and exposes its tagged layout", function()
		ArenaService:init({ Config = Fixtures.config() })
		local model = ArenaService.model :: Model
		local ok, message = pcall(function()
			expect(model.Parent).toBe(workspace)
			expect(#(ArenaService.arena :: any).layout.gates).toBe(4)
		end)
		model:Destroy()
		if not ok then
			error(message, 0)
		end
	end)
end)
