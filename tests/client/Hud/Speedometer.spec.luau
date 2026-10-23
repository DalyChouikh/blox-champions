--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local React = require(ReplicatedStorage.Packages.React)
local Speedometer = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Speedometer)

local config = Fixtures.config()
local place = config.UI.hud.layout.speedometer

local folder: Folder?

afterEach(function()
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
end)

describe("Speedometer", function()
	it("shows the speed in km/h, and nothing for a spectator", function()
		local parent = Instance.new("Folder")
		parent.Name = "SpeedometerTest"
		parent.Parent = workspace
		folder = parent
		local speed, setSpeed = React.createBinding("120 km/h")
		local function meter(device: Enum.PreferredInput, visible: boolean): React.ReactElement
			return React.createElement(React.Fragment, nil, {
				Speedometer = React.createElement(
					Speedometer,
					{ config = config, speed = speed, device = device, visible = visible }
				),
			})
		end
		local mounted, rerender = Fixtures.mount(meter(Enum.PreferredInput.KeyboardAndMouse, true), parent)
		local label = mounted:FindFirstChild("Speedometer") :: TextLabel
		expect(label.Visible).toBe(true)
		expect(label.Text).toBe("120 km/h")
		expect(label.Position == place.position).toBe(true)
		setSpeed("96 km/h")
		expect(label.Text).toBe("96 km/h")
		-- Above the touch buttons on touch.
		rerender(meter(Enum.PreferredInput.Touch, true))
		expect(label.Position == place.touchPosition).toBe(true)
		rerender(meter(Enum.PreferredInput.KeyboardAndMouse, false))
		expect(label.Visible).toBe(false)
	end)
end)
