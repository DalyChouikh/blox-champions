--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local parent: Folder
beforeEach(function()
	parent = Instance.new("Folder")
	parent.Name = "RemotesTest"
	parent.Parent = ReplicatedStorage
end)
afterEach(function()
	parent:Destroy()
end)

describe("Remotes", function()
	it("creates one RemoteEvent per name in a Remotes folder", function()
		local folder = Remotes.create(parent)
		expect(folder.Name).toBe("Remotes")
		expect(#folder:GetChildren()).toBe(8)
		for _, name in Remotes.names do
			expect((folder:FindFirstChild(name) :: Instance).ClassName).toBe("RemoteEvent")
		end
	end)

	it("refuses to create the remotes twice", function()
		Remotes.create(parent)
		expect(function()
			Remotes.create(parent)
		end).toThrow(`Remotes: already created under {parent:GetFullName()}`)
	end)

	it("finds a remote by name and rejects an unknown one", function()
		Remotes.create(parent)
		expect(Remotes.get(parent, Remotes.names.BallCarrier).Name).toBe("BallCarrier")
		expect(Remotes.get(parent, Remotes.names.ActionRequest).Name).toBe("ActionRequest")
		expect(Remotes.get(parent, Remotes.names.GetUp).Name).toBe("GetUp")
		expect(Remotes.get(parent, Remotes.names.SwitchTeam).Name).toBe("SwitchTeam")
		expect(function()
			Remotes.get(parent, "Ghost")
		end).toThrow('Remotes: unknown remote "Ghost"')
	end)
end)
