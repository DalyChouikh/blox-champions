--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(Client.Hud.Style)
local TouchButton = require(Client.Hud.TouchButton)

-- Look C with values of this spec's own: a 2 px outline, a 5 px shadow, 1.5 px ink round the words, 4 px inside the
-- fill's sides, 3 px of room round the ink inside its group.
local config = Fixtures.config({
	UI = {
		hud = {
			look = {
				outline = 2,
				shadow = 5,
				textOutline = 1.5,
				pressed = Color3.fromRGB(240, 120, 40),
				groupRoom = 3,
			},
		},
		touchStyle = { textPadding = 4 },
	},
})
local look = config.UI.hud.look
local FILL: Config.Gradient = { top = Color3.fromRGB(200, 100, 40), bottom = Color3.fromRGB(0, 50, 240) }

local folder: Folder?

afterEach(function()
	Fixtures.unmountAll()
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
end)

-- What moves on the face, at rest, its fade solid, and their setters.
local function moving(): any
	local press, setPress = React.createBinding(1)
	local pressed, setPressed = React.createBinding(false)
	local cooldown, setCooldown = React.createBinding(0)
	local seconds, setSeconds = React.createBinding("")
	local label, setLabel = React.createBinding("Jump")
	local fade, setFade = React.createBinding(0)
	local bindings: Style.CapBindings = { press = press, pressed = pressed, cooldown = cooldown, seconds = seconds }
	return {
		bindings = bindings,
		label = label,
		fade = fade,
		setPress = setPress,
		setPressed = setPressed,
		setCooldown = setCooldown,
		setSeconds = setSeconds,
		setLabel = setLabel,
		setFade = setFade,
	}
end

-- A face reading `parts`' bindings, 60 px round unless `props` say otherwise, drawn into a button of its size inside
-- `parent` (a new folder in the workspace without one); returns its Face frame.
local function face(parts: any, props: { [string]: any }?, parent: Instance?): Frame
	local base = {
		config = config,
		size = Vector2.new(60, 60),
		corner = Style.ROUND,
		fill = FILL,
		textSize = 15,
		label = parts.label,
		moving = parts.bindings,
		fade = parts.fade,
	}
	local overrides: { [string]: any } = props or {}
	for key, value in overrides do
		base[key] = value
	end
	local holder = parent
	if holder == nil then
		local made = Instance.new("Folder")
		made.Name = "TouchButtonTest"
		made.Parent = workspace
		folder = made
		holder = made
	end
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(base.size.X, base.size.Y)
	button.Parent = holder
	local element = React.createElement(TouchButton, base :: any)
	local mounted = Fixtures.mount(React.createElement(React.Fragment, nil, { Face = element }), button)
	return mounted:FindFirstChild("Face") :: Frame
end

local function near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 1e-3 and math.abs(a.G - b.G) < 1e-3 and math.abs(a.B - b.B) < 1e-3
end

describe("TouchButton", function()
	-- The design page's button: its outline inside its size (60 px across the ink), its shadow hanging below.
	it(
		"draws a round look C face as big as its button: the ink to its edges, the fill inside, the shadow below",
		function()
			local front = face(moving())
			expect(front.AnchorPoint).toEqual(Vector2.new(0.5, 0.5))
			expect(front.Position).toEqual(UDim2.fromScale(0.5, 0.5))
			expect(front.Size).toEqual(UDim2.fromScale(1, 1))
			local group = front:FindFirstChild("Group") :: CanvasGroup
			expect(group.ClassName).toBe("CanvasGroup")
			-- The room round the ink and the shadow below it, which a CanvasGroup would clip.
			expect(group.Position).toEqual(UDim2.fromOffset(-3, -3))
			expect(group.Size).toEqual(UDim2.new(1, 6, 1, 11))
			local box = group:FindFirstChild("Box") :: Frame
			-- Inside the group's padding (its room), the outline in from the button's sides.
			expect(box.Position).toEqual(UDim2.fromOffset(2, 2))
			expect(box.Size).toEqual(UDim2.fromOffset(56, 56))
			local fill = box:FindFirstChild("Fill1") :: Frame
			expect((fill:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(Style.ROUND)
			local keys = (fill:FindFirstChildOfClass("UIGradient") :: UIGradient).Color.Keypoints
			expect(near(keys[1].Value, FILL.top)).toBe(true)
			expect(near(keys[#keys].Value, FILL.bottom)).toBe(true)
			local ink = box:FindFirstChild("Ink1") :: Frame
			expect(ink.Size).toEqual(UDim2.new(1, 4, 1, 9))
		end
	)

	it("letters its words white in ink, shrinking under its text size to fit inside the fill's padding", function()
		local parts = moving()
		local words = face(parts):FindFirstChild("Words", true) :: TextLabel
		expect(words.Text).toBe("Jump")
		expect(words.Font).toBe(look.font)
		expect(words.TextColor3 == config.UI.hud.textColor).toBe(true)
		expect(words.TextScaled).toBe(true)
		expect(words.Size).toEqual(UDim2.fromScale(1, 1))
		expect((words:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint).MaxTextSize).toBe(15)
		local padding = words:FindFirstChildOfClass("UIPadding") :: UIPadding
		expect(padding.PaddingLeft).toEqual(UDim.new(0, 4))
		expect(padding.PaddingRight).toEqual(UDim.new(0, 4))
		local ink = words:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(ink.Thickness).toBe(1.5)
		expect(ink.Color == look.ink).toBe(true)
		parts.setLabel("Magnetic Pass")
		expect(words.Text).toBe("Magnetic Pass")
	end)

	-- As a hint's key cap (#354, the owner's Q186): a press pops it, and it shows pressed while it pops or is held.
	it("pops round its middle when pressed, and turns the pressed colour while it is", function()
		local parts = moving()
		local front = face(parts)
		local pop = front:FindFirstChildOfClass("UIScale") :: UIScale
		expect(pop.Scale).toBe(1)
		parts.setPress(0.88)
		expect(pop.Scale).toBeCloseTo(0.88, 5)
		local pressed = front:FindFirstChild("Pressed", true) :: Frame
		expect(pressed.Visible).toBe(false)
		expect(pressed.Size).toEqual(UDim2.fromScale(1, 1))
		expect(pressed.BackgroundColor3 == look.pressed).toBe(true)
		expect((pressed:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(Style.ROUND)
		parts.setPressed(true)
		expect(pressed.Visible).toBe(true)
		-- Over the fill, under the words.
		local words = front:FindFirstChild("Words", true) :: TextLabel
		expect(pressed.ZIndex < words.ZIndex).toBe(true)
		-- Under a cooling button's sweep too.
		local sweep = front:FindFirstChild("Sweep", true) :: Frame
		expect(pressed.ZIndex < sweep.ZIndex).toBe(true)
	end)

	-- The design page: a cooling button's seconds stand in for its words, over an ink sweep across its fill.
	it("shows a cooling button's seconds in place of its words, over a sweep across its fill", function()
		local parts = moving()
		local front = face(parts)
		local words = front:FindFirstChild("Words", true) :: TextLabel
		local seconds = front:FindFirstChild("Seconds", true) :: TextLabel
		local sweep = front:FindFirstChild("Sweep", true) :: Frame
		expect(seconds.Visible).toBe(false)
		expect(sweep.Visible).toBe(false)
		expect((seconds:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint).MaxTextSize).toBe(15)
		parts.setCooldown(0.5)
		parts.setSeconds("1.4")
		expect(words.Visible).toBe(false)
		expect(seconds.Visible).toBe(true)
		expect(seconds.Text).toBe("1.4")
		expect(sweep.Visible).toBe(true)
		-- A square as big as the fill: 60 - 2 x 2.
		expect(sweep.Size).toEqual(UDim2.fromOffset(56, 56))
		expect(sweep.ZIndex < words.ZIndex).toBe(true)
		parts.setCooldown(0)
		parts.setSeconds("")
		expect(words.Visible).toBe(true)
		expect(seconds.Visible).toBe(false)
	end)

	-- Greyed whole (#368, the owner's Q220), as a hint row: box, ink and words fade as one.
	it("fades whole while greyed", function()
		local parts = moving()
		local group = face(parts):FindFirstChild("Group") :: CanvasGroup
		expect(group.GroupTransparency).toBe(0)
		parts.setFade(0.6)
		expect(group.GroupTransparency).toBeCloseTo(0.6, 5)
	end)

	-- SCORES (#355, the owner's Q250): a rounded box, its words fixed, never greyed.
	it("draws a box with fixed words that never fades, as SCORES", function()
		local parts = moving()
		parts.fade = nil
		local front = face(parts, { size = Vector2.new(96, 36), corner = UDim.new(0, 7), label = "SCORES" })
		local fill = (front:FindFirstChild("Box", true) :: Frame):FindFirstChild("Fill1") :: Frame
		expect((fill:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(UDim.new(0, 7))
		local pressed = front:FindFirstChild("Pressed", true) :: Frame
		expect((pressed:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(UDim.new(0, 7))
		-- Its sweep (never shown: SCORES never cools) a square as tall as its fill, 36 - 2 x 2.
		expect((front:FindFirstChild("Sweep", true) :: Frame).Size).toEqual(UDim2.fromOffset(32, 32))
		expect((front:FindFirstChild("Words", true) :: TextLabel).Text).toBe("SCORES")
		expect((front:FindFirstChild("Group") :: CanvasGroup).GroupTransparency).toBe(0)
	end)
end)

-- The face as Roblox lays it out (a ScreenGui under StarterGui is laid out in Edit, after a frame): the group clips
-- what it holds at its edges, cutting the ink flat past them (the owner's Q253: the bottoms) and where a disc's
-- edge touches them (Q254: the sides).
describe("TouchButton, laid out", function()
	local gui: ScreenGui?

	afterEach(function()
		if gui ~= nil then
			gui:Destroy()
			gui = nil
		end
	end)

	-- `object`'s left, top, width and height in pixels from `from`'s top left.
	local function rect(object: GuiObject, from: GuiObject): string
		local at = object.AbsolutePosition - from.AbsolutePosition
		return `{at.X} {at.Y} {object.AbsoluteSize.X} {object.AbsoluteSize.Y}`
	end

	-- The fill, the ink and the group of a mounted face, from its button's top left.
	local function parts(front: Frame): { string }
		local button = front:FindFirstAncestorWhichIsA("GuiObject") :: GuiObject
		local group = front:FindFirstChild("Group") :: CanvasGroup
		local box = group:FindFirstChild("Box") :: Frame
		return {
			`fill {rect(box:FindFirstChild("Fill1") :: Frame, button)}`,
			`ink {rect(box:FindFirstChild("Ink1") :: Frame, button)}`,
			`group {rect(group, button)}`,
		}
	end

	it("keeps the fill inside the outline and the whole ink, its shadow too, its room inside the group", function()
		local layer = Instance.new("ScreenGui")
		layer.Name = "TouchButtonLaidOutTest"
		layer.Parent = game:GetService("StarterGui")
		gui = layer
		local round = face(moving(), nil, layer)
		local scores = face(moving(), { size = Vector2.new(96, 36), corner = UDim.new(0, 7), label = "SCORES" }, layer)
		task.wait()
		-- The outline 2 px inside the button's sides, the shadow 5 px under its bottom, the group 3 px past them all.
		expect(parts(round)).toEqual({ "fill 2 2 56 56", "ink 0 0 60 65", "group -3 -3 66 71" })
		expect(parts(scores)).toEqual({ "fill 2 2 92 32", "ink 0 0 96 41", "group -3 -3 102 47" })
	end)
end)
