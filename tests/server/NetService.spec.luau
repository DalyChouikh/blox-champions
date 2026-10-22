--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local NetService = require(game:GetService("ServerScriptService").Server.NetService)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local parent: Folder
beforeEach(function()
	parent = Instance.new("Folder")
	parent.Name = "NetServiceTest"
	parent.Parent = ReplicatedStorage
end)
afterEach(function()
	parent:Destroy()
end)

describe("NetService", function()
	it("creates the remotes under its parent and removes them on destroy", function()
		NetService:init({ Parent = parent })
		expect(parent:FindFirstChild(Remotes.FOLDER)).never.toBeNil()
		NetService:destroy()
		expect(parent:FindFirstChild(Remotes.FOLDER)).toBeNil()
	end)

	it("rejects an unknown remote and skips a player who is not here", function()
		NetService:init({ Parent = parent })
		expect(function()
			NetService:fireAll("Ghost", {})
		end).toThrow('NetService: unknown remote "Ghost"')
		expect(function()
			NetService:fireTo("999999999", Remotes.names.MatchSnapshot, {})
		end).never.toThrow()
		NetService:destroy()
	end)
end)
