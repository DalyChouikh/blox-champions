--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local React = require(ReplicatedStorage.Packages.React)
local Reticle = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Reticle)

local config = Fixtures.config()

local folder: Folder?

afterEach(function()
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
end)

describe("Reticle", function()
	it("draws a dot at the screen's centre", function()
		local parent = Instance.new("Folder")
		parent.Name = "ReticleTest"
		parent.Parent = workspace
		folder = parent
		local mounted = Fixtures.mount(
			React.createElement(React.Fragment, nil, { Reticle = React.createElement(Reticle, { config = config }) }),
			parent
		)
		local dot = mounted:FindFirstChild("Reticle") :: Frame
		local size = config.UI.hud.layout.reticle.size
		expect(dot.AnchorPoint == Vector2.new(0.5, 0.5)).toBe(true)
		expect(dot.Position == UDim2.fromScale(0.5, 0.5)).toBe(true)
		expect(dot.Size == UDim2.fromOffset(size, size)).toBe(true)
		expect(dot.BackgroundColor3 == config.UI.hud.textColor).toBe(true)
	end)
end)
