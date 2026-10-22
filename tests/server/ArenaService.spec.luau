--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect, jest = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.jest

local ArenaService = require(game:GetService("ServerScriptService").Server.ArenaService)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local TaggedLayout = require(ReplicatedStorage.Shared.Arena.TaggedLayout)

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

	it("removes the arena again and reports why when its tags cannot be read", function()
		local read = jest.spyOn(TaggedLayout, "read")
		read.mockImplementation(function()
			error("TaggedLayout: unreadable on purpose", 0)
		end)
		local ok, message = pcall(function()
			ArenaService:init({ Config = Fixtures.config() })
		end)
		read.mockRestore()
		local leftover = workspace:FindFirstChild("Arena")
		if leftover then
			leftover:Destroy()
		end
		expect(ok).toBe(false)
		expect((string.find(tostring(message), "TaggedLayout: unreadable on purpose", 1, true))).never.toBeNil()
		expect(leftover).toBeNil()
	end)
end)
