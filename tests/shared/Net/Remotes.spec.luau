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
	it("creates one RemoteEvent per name and one UnreliableRemoteEvent per stream in a Remotes folder", function()
		local folder = Remotes.create(parent)
		expect(folder.Name).toBe("Remotes")
		expect(#folder:GetChildren()).toBe(9)
		for _, name in Remotes.names do
			expect((folder:FindFirstChild(name) :: Instance).ClassName).toBe("RemoteEvent")
		end
		for _, name in Remotes.streams do
			expect((folder:FindFirstChild(name) :: Instance).ClassName).toBe("UnreliableRemoteEvent")
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

	-- #316: the loose ball's state each frame it moves; a lost one is followed by the next, so it is unreliable.
	it("finds a stream by name and rejects an unknown one", function()
		Remotes.create(parent)
		expect(Remotes.getStream(parent, Remotes.streams.BallState).Name).toBe("BallState")
		expect(function()
			Remotes.getStream(parent, Remotes.names.BallCarrier)
		end).toThrow('Remotes: unknown stream "BallCarrier"')
	end)
end)
