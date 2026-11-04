--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Style)

-- Look C with round numbers of this spec's own: a 2 px outline, a 5 px shadow, 10 px corners, half as bright at the
-- bottom, and team colours of its own.
local config = Fixtures.config({
	UI = {
		hud = {
			look = {
				ink = Color3.fromRGB(10, 20, 30),
				outline = 2,
				shadow = 5,
				textOutline = 1.5,
				corner = UDim.new(0, 10),
				shade = 0.5,
				teamColors = { Blue = Color3.fromRGB(0, 100, 250), Orange = Color3.fromRGB(250, 150, 0) },
			},
		},
	},
})
local RED = Color3.fromRGB(200, 100, 40)

local folder: Folder?

afterEach(function()
	Fixtures.unmountAll()
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
end)

local function mount(element: React.ReactElement): Instance
	local parent = Instance.new("Folder")
	parent.Name = "StyleTest"
	parent.Parent = workspace
	folder = parent
	return Fixtures.mount(React.createElement(React.Fragment, nil, { Box = element }), parent)
end

local function near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 1e-3 and math.abs(a.G - b.G) < 1e-3 and math.abs(a.B - b.B) < 1e-3
end

describe("Style (look C)", function()
	it("draws a box's ink once, grown by the outline and dropped by the shadow, under its shaded fill", function()
		local mounted = mount(Style.box(config, { Size = UDim2.fromOffset(80, 40) }, RED, {
			Label = React.createElement("TextLabel", { Text = "4:32" }),
		}))
		local box = mounted:FindFirstChild("Box") :: Frame
		local ink = box:FindFirstChild("Ink1") :: Frame
		local fill = box:FindFirstChild("Fill1") :: Frame
		-- 2 px each side, and 5 px more below: one shape for the outline and the shadow.
		expect(ink.Position).toEqual(UDim2.fromOffset(-2, -2))
		expect(ink.Size).toEqual(UDim2.new(1, 4, 1, 9))
		expect(ink.BackgroundColor3 == Color3.fromRGB(10, 20, 30)).toBe(true)
		expect((ink:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(UDim.new(0, 12))
		expect(fill.Size).toEqual(UDim2.fromScale(1, 1))
		expect((fill:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(UDim.new(0, 10))
		expect(ink.ZIndex < fill.ZIndex).toBe(true)
		-- The colour at the top, half as bright at the bottom.
		local keys = ((fill:FindFirstChildOfClass("UIGradient") :: UIGradient).Color).Keypoints
		expect(near(keys[1].Value, RED)).toBe(true)
		expect(near(keys[#keys].Value, Color3.fromRGB(100, 50, 20))).toBe(true)
		expect((fill:FindFirstChildOfClass("UIGradient") :: UIGradient).Rotation).toBe(90)
		-- What the box holds sits above all of it.
		local content = box:FindFirstChild("Content") :: Frame
		expect(content.ZIndex > fill.ZIndex).toBe(true)
		expect(content:FindFirstChild("Label") ~= nil).toBe(true)
	end)

	it("shades a box of several pieces as one, each piece by its share of the box's height", function()
		local pieces: { Style.Piece } = {
			{ top = 0, height = 0.5, corner = UDim.new(0, 10) },
			{ top = 0, height = 1, corner = Style.ROUND },
		}
		local mounted = mount(Style.box(config, { Size = UDim2.fromOffset(80, 80) }, RED, nil, pieces))
		local box = mounted:FindFirstChild("Box") :: Frame
		local top = box:FindFirstChild("Fill1") :: Frame
		local whole = box:FindFirstChild("Fill2") :: Frame
		expect(top.Size).toEqual(UDim2.fromScale(1, 0.5))
		-- Halfway down the box: 0.75 as bright, where the top piece ends.
		local topKeys = ((top:FindFirstChildOfClass("UIGradient") :: UIGradient).Color).Keypoints
		expect(near(topKeys[#topKeys].Value, Color3.fromRGB(150, 75, 30))).toBe(true)
		local wholeKeys = ((whole:FindFirstChildOfClass("UIGradient") :: UIGradient).Color).Keypoints
		expect(near(wholeKeys[#wholeKeys].Value, Color3.fromRGB(100, 50, 20))).toBe(true)
		-- A round piece stays round when grown into its ink.
		local ink = box:FindFirstChild("Ink2") :: Frame
		expect((ink:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(UDim.new(0.5, 2))
	end)

	it("letters text in the look's font, outlined in ink", function()
		local props = Style.lettering(config, { Text = "+3", TextSize = 22 })
		expect(props.Font).toBe(config.UI.hud.look.font)
		expect(props.TextColor3 == config.UI.hud.textColor).toBe(true)
		expect(props.TextSize).toBe(22)
		expect(props.BackgroundTransparency).toBe(1)
		local mounted = mount(React.createElement("TextLabel", props, { Ink = Style.inked(config) }))
		local stroke = (mounted:FindFirstChild("Box") :: Instance):FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Color == Color3.fromRGB(10, 20, 30)).toBe(true)
		expect(stroke.Thickness).toBe(1.5)
		-- On a text label a stroke rings the letters (Contextual), not the label's box.
		expect(stroke.ApplyStrokeMode).toBe(Enum.ApplyStrokeMode.Contextual)
	end)

	it("colours a team in the HUD's own pair, not the world's, and no team in the text colour", function()
		expect(Style.teamColor(config, "Blue") == Color3.fromRGB(0, 100, 250)).toBe(true)
		expect(Style.teamColor(config, "Orange") == Color3.fromRGB(250, 150, 0)).toBe(true)
		expect(Style.teamColor(config, nil) == config.UI.hud.textColor).toBe(true)
	end)

	it("steps a box under another so their inks stay a clearance apart", function()
		-- The upper ink reaches 2 + 5 below its box, the lower's 2 above its own: 4 px clear at a 13 px step.
		expect(Style.under(config, 4)).toBe(13)
		expect(Style.under(config, 0)).toBe(9)
	end)
end)
