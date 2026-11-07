--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local React = require(ReplicatedStorage.Packages.React)
local Speedometer = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Speedometer)

local config = Fixtures.config()
local hud = config.UI.hud
local place = hud.layout.speedometer
-- The team's Orange (one pair for the world and the HUD, the owner's Q318).
local ORANGE = config.UI.teamColors.Orange

local folder: Folder?

afterEach(function()
	Fixtures.unmountAll()
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
end)

describe("Speedometer", function()
	it("shows big digits in the team's colour over a small KM/H, bottom right, and nothing for a spectator", function()
		local parent = Instance.new("Folder")
		parent.Name = "SpeedometerTest"
		parent.Parent = workspace
		folder = parent
		local speed, setSpeed = React.createBinding("120")
		local function meter(touch: boolean, compact: boolean, visible: boolean): React.ReactElement
			return React.createElement(React.Fragment, nil, {
				Speedometer = React.createElement(Speedometer, {
					config = config,
					speed = speed,
					color = ORANGE,
					touch = touch,
					compact = compact,
					visible = visible,
				}),
			})
		end
		local mounted, rerender = Fixtures.mount(meter(false, false, true), parent)
		local frame = mounted:FindFirstChild("Speedometer") :: Frame
		local digits = frame:FindFirstChild("Speed") :: TextLabel
		local unit = frame:FindFirstChild("Unit") :: TextLabel
		expect(frame.Visible).toBe(true)
		expect(frame.Position == place.position and frame.AnchorPoint == Vector2.one).toBe(true)
		expect(digits.Text).toBe("120")
		expect(digits.Font).toBe(hud.look.font)
		expect(digits.TextColor3 == ORANGE).toBe(true)
		expect(digits.TextSize).toBe(place.textSizes.speed)
		expect(digits:FindFirstChildOfClass("UIStroke") ~= nil).toBe(true)
		expect(unit.Text).toBe("KM/H")
		expect(unit.TextSize).toBe(place.textSizes.unit)
		expect(unit.TextColor3 == hud.textColor).toBe(true)
		-- Digits over the unit, both against the right edge.
		expect(digits.LayoutOrder < unit.LayoutOrder).toBe(true)
		local layout = frame:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		expect(layout.HorizontalAlignment).toBe(Enum.HorizontalAlignment.Right)
		setSpeed("96")
		expect(digits.Text).toBe("96")
		-- On touch, in the top-left corner: the right side holds the touch buttons and the score button; small on a
		-- phone.
		rerender(meter(true, true, true))
		expect(frame.Position == place.touchPosition and frame.AnchorPoint == Vector2.zero).toBe(true)
		expect(layout.HorizontalAlignment).toBe(Enum.HorizontalAlignment.Left)
		expect(digits.TextSize).toBe(place.compactTextSizes.speed)
		expect(unit.TextSize).toBe(place.compactTextSizes.unit)
		rerender(meter(false, false, false))
		expect(frame.Visible).toBe(false)
	end)
end)
