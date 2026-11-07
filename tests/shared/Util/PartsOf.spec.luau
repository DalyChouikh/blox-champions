--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local PartsOf = require(ReplicatedStorage.Shared.Util.PartsOf)

describe("PartsOf", function()
	it("lists a model's parts at any depth, a part with its own parts, and nothing else", function()
		local model = Instance.new("Model")
		local top = Instance.new("Part")
		top.Parent = model
		local folder = Instance.new("Folder")
		folder.Parent = model
		local deep = Instance.new("MeshPart")
		deep.Parent = folder
		Instance.new("Attachment").Parent = top
		local found = PartsOf(model)
		expect(#found).toBe(2)
		expect(table.find(found, top) ~= nil and table.find(found, deep) ~= nil).toBe(true)
		-- A part on its own (an art pass may tag one): itself first, then the parts under it.
		local inner = Instance.new("Part")
		inner.Parent = top
		local own = PartsOf(top)
		expect(#own).toBe(2)
		expect(own[1] == top and own[2] == inner).toBe(true)
		expect(#PartsOf(folder)).toBe(1)
		expect(#PartsOf(Instance.new("Folder"))).toBe(0)
		model:Destroy()
	end)
end)
