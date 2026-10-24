--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local React = require(ReplicatedStorage.Packages.React)

local folder: Folder?

afterEach(function()
	Fixtures.unmountAll()
	if folder then
		folder:Destroy()
		folder = nil
	end
end)

local function label(text: string): React.ReactElement
	return React.createElement(React.Fragment, nil, {
		Label = React.createElement("TextLabel", { Text = text }),
	})
end

describe("React Luau", function()
	it("renders at once with React Luau's legacy root, naming each instance by its key", function()
		local parent = Instance.new("Folder")
		parent.Name = "ReactLuauTest"
		parent.Parent = workspace
		folder = parent

		local mounted, rerender, unmount = Fixtures.mount(label("hi"), parent)
		local shown = mounted:FindFirstChild("Label") :: TextLabel?
		expect(shown ~= nil and shown.Text).toBe("hi")
		rerender(label("bye"))
		expect(shown ~= nil and shown.Text).toBe("bye")
		unmount()
		expect(#mounted:GetChildren()).toBe(0)
	end)

	it("unmounts every root the fixtures mounted, as each component spec does after a test", function()
		local parent = Instance.new("Folder")
		parent.Name = "ReactLuauTest"
		parent.Parent = workspace
		folder = parent

		local first = Fixtures.mount(label("a"), parent)
		local second = Fixtures.mount(label("b"), parent)
		Fixtures.unmountAll()
		expect(#first:GetChildren() + #second:GetChildren()).toBe(0)
	end)
end)
