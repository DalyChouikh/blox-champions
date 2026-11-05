--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Style)
local TextService = game:GetService("TextService")

-- Look C with round numbers of this spec's own: a 2 px outline, a 5 px shadow, 10 px corners, half as bright at the
-- bottom, team colours of its own, and 3 px of room inside a fading group.
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
				key = Color3.fromRGB(240, 200, 60),
				pressed = Color3.fromRGB(240, 120, 40),
				sweepTransparency = 0.3,
				groupRoom = 3,
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

-- A key cap's sizes and colours of this spec's own (#354): a 12 x 20 mouse in 2 px of ink, its buttons 8 px deep.
local CAP: Config.CapSizes = {
	height = 30,
	padding = 6,
	corner = UDim.new(0, 8),
	textSize = 15,
	mouse = { width = 12, height = 20, buttons = 8, line = 2 },
}
local INK = Color3.fromRGB(10, 20, 30)
local KEY = Color3.fromRGB(240, 200, 60)
local PRESSED = Color3.fromRGB(240, 120, 40)
local GLYPH = "rbxasset://textures/ui/Controls/DefaultController/ButtonX@2x.png"

-- What moves on a key cap, at rest, and their setters.
local function capBindings(): any
	local press, setPress = React.createBinding(1)
	local pressed, setPressed = React.createBinding(false)
	local cooldown, setCooldown = React.createBinding(0)
	local seconds, setSeconds = React.createBinding("")
	local bindings: Style.CapBindings = { press = press, pressed = pressed, cooldown = cooldown, seconds = seconds }
	return {
		bindings = bindings,
		setPress = setPress,
		setPressed = setPressed,
		setCooldown = setCooldown,
		setSeconds = setSeconds,
	}
end

describe("Style (look C)", function()
	-- A group fading parts as one (#355 Q254, #383): it reaches look.groupRoom past its parent on every side, and
	-- `below` pixels more under it, padded back in by the same, so ink drawn to its parent's edges keeps that room.
	it("fades parts as one in a group reaching its room past its parent, padded back in", function()
		local fade, setFade = React.createBinding(0.4)
		local element = Style.fadeGroup(config, fade, 5, { Part = React.createElement("Frame") })
		local group = mount(element):FindFirstChild("Box") :: CanvasGroup
		expect(group.ClassName).toBe("CanvasGroup")
		expect(group.BackgroundTransparency).toBe(1)
		expect(group.Position).toEqual(UDim2.fromOffset(-3, -3))
		expect(group.Size).toEqual(UDim2.new(1, 6, 1, 11))
		local padding = group:FindFirstChildOfClass("UIPadding") :: UIPadding
		for _, side in { padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop, padding.PaddingBottom } do
			expect(side).toEqual(UDim.new(0, 3))
		end
		expect(group:FindFirstChild("Part") ~= nil).toBe(true)
		expect(group.GroupTransparency).toBeCloseTo(0.4, 5)
		setFade(0.6)
		expect(group.GroupTransparency).toBeCloseTo(0.6, 5)
	end)

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

	-- The touch buttons' fills (#355): two colours of their own, not one shaded by the look.
	it("fills a box from a gradient's top colour to its bottom one, each piece by its share of the height", function()
		local gradient: Config.Gradient = { top = Color3.fromRGB(200, 100, 40), bottom = Color3.fromRGB(0, 50, 240) }
		local pieces: { Style.Piece } = {
			{ top = 0.5, height = 0.5, corner = UDim.new(0, 10) },
			{ top = 0, height = 1, corner = Style.ROUND },
		}
		local mounted = mount(Style.box(config, { Size = UDim2.fromOffset(80, 80) }, gradient, nil, pieces))
		local box = mounted:FindFirstChild("Box") :: Frame
		local lower = ((box:FindFirstChild("Fill1") :: Frame):FindFirstChildOfClass("UIGradient") :: UIGradient).Color
		local whole = ((box:FindFirstChild("Fill2") :: Frame):FindFirstChildOfClass("UIGradient") :: UIGradient).Color
		-- The lower piece from halfway down, the whole one from the top, both to the bottom colour.
		expect(near(lower.Keypoints[1].Value, Color3.fromRGB(100, 75, 140))).toBe(true)
		expect(near(lower.Keypoints[#lower.Keypoints].Value, gradient.bottom)).toBe(true)
		expect(near(whole.Keypoints[1].Value, gradient.top)).toBe(true)
		expect(near(whole.Keypoints[#whole.Keypoints].Value, gradient.bottom)).toBe(true)
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

	-- X1's strokes (#353): the colour over an ink 1.5 px wider each side here. A UIStroke lies outside its frame, so a
	-- 40 px ring with a 4 px stroke is a 32 px frame; its ink a 29 px frame with a 7 px stroke, reaching 43 across.
	it("draws a look C ring: its stroke over an ink stroke wider each side, both faded alike", function()
		local fade = React.createBinding(0.25)
		local held: { [string]: React.Node } = { Digit = React.createElement("TextLabel", { Text = "3" }) }
		local mounted = mount(Style.inkedRing(config, { Position = UDim2.fromOffset(5, 6) }, 40, 4, RED, fade, held))
		local ring = mounted:FindFirstChild("Box") :: Frame
		expect(ring.Size).toEqual(UDim2.fromOffset(43, 43))
		expect(ring.Position).toEqual(UDim2.fromOffset(5, 6))
		expect(ring.BackgroundTransparency).toBe(1)
		local line = ring:FindFirstChild("Line") :: Frame
		local ink = ring:FindFirstChild("Ink") :: Frame
		expect(line.Size).toEqual(UDim2.fromOffset(32, 32))
		expect(ink.Size).toEqual(UDim2.fromOffset(29, 29))
		for _, stroked in { line, ink } do
			expect(stroked.AnchorPoint == Vector2.new(0.5, 0.5)).toBe(true)
			expect(stroked.Position).toEqual(UDim2.fromScale(0.5, 0.5))
			expect(stroked.BackgroundTransparency).toBe(1)
			expect((stroked:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(Style.ROUND)
		end
		local lineStroke = line:FindFirstChildOfClass("UIStroke") :: UIStroke
		local inkStroke = ink:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(lineStroke.Thickness).toBe(4)
		expect(lineStroke.Color == RED).toBe(true)
		expect(inkStroke.Thickness).toBe(7)
		expect(inkStroke.Color == Color3.fromRGB(10, 20, 30)).toBe(true)
		expect(lineStroke.Transparency).toBe(0.25)
		expect(inkStroke.Transparency).toBe(0.25)
		-- The ink under the stroke, what the ring holds above both.
		local content = ring:FindFirstChild("Content") :: Frame
		expect(content.Size).toEqual(UDim2.fromScale(1, 1))
		expect(content:FindFirstChild("Digit") ~= nil).toBe(true)
		expect(ink.ZIndex < line.ZIndex and line.ZIndex < content.ZIndex).toBe(true)
	end)

	it("colours a team in the HUD's own pair, not the world's, and no team in the text colour", function()
		expect(Style.teamColor(config, "Blue") == Color3.fromRGB(0, 100, 250)).toBe(true)
		expect(Style.teamColor(config, "Orange") == Color3.fromRGB(250, 150, 0)).toBe(true)
		expect(Style.teamColor(config, nil) == config.UI.hud.textColor).toBe(true)
	end)

	-- Look C's key caps (#354, the design page's): this spec's own sizes, a key pressed, a key cooling down (Q186).
	it("draws a key cap: its name in ink on a cap as wide as the name, never narrower than tall, inked", function()
		local moving = capBindings()
		local name, short = Style.keyCap(config, { text = "E" }, CAP, 2, moving.bindings)
		expect(name).toBe("Key")
		local _, long = Style.keyCap(config, { text = "Shift" }, CAP, 1, moving.bindings)
		local mounted = mount(React.createElement(React.Fragment, nil, { Short = short, Long = long }))
		local key = mounted:FindFirstChild("Short") :: Frame
		expect(key.Size).toEqual(UDim2.fromOffset(30, 30))
		expect(key.LayoutOrder).toBe(2)
		local shift = TextService:GetTextSize("Shift", 15, config.UI.hud.look.font, Vector2.new(math.huge, math.huge))
		expect((mounted:FindFirstChild("Long") :: Frame).Size).toEqual(UDim2.fromOffset(math.ceil(shift.X) + 12, 30))
		local face = key:FindFirstChild("Face") :: Frame
		expect(face.Size).toEqual(UDim2.fromScale(1, 1))
		expect(face.AnchorPoint == Vector2.new(0.5, 0.5)).toBe(true)
		expect(face.BackgroundColor3 == KEY).toBe(true)
		expect((face:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(UDim.new(0, 8))
		local stroke = face:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Color == INK).toBe(true)
		expect(stroke.Thickness).toBe(1.5)
		local label = face:FindFirstChild("Legend") :: TextLabel
		expect(label.Text).toBe("E")
		expect(label.TextColor3 == INK).toBe(true)
		expect(label.TextSize).toBe(15)
		expect(label.Font).toBe(config.UI.hud.look.font)
	end)

	-- The Get Up prompt's bigger caps (#369, the owner's Q221): a cap can drop look C's shadow, in one shape with its
	-- outline, under its face, so a press never moves it; no other cap draws one.
	it("drops a cap's shadow when its sizes ask for one", function()
		local moving = capBindings()
		local _, plain = Style.keyCap(config, { text = "E" }, CAP, 1, moving.bindings)
		local dropped: Config.CapSizes = {
			height = 30,
			padding = 6,
			corner = UDim.new(0, 8),
			textSize = 15,
			dropShadow = true,
		}
		local _, cap = Style.keyCap(config, { text = "W" }, dropped, 1, moving.bindings)
		local parts = mount(React.createElement(React.Fragment, nil, { Plain = plain, Dropped = cap }))
		expect((parts:FindFirstChild("Plain") :: Frame):FindFirstChild("Shadow")).toBeNil()
		local key = parts:FindFirstChild("Dropped") :: Frame
		local shadow = key:FindFirstChild("Shadow") :: Frame
		-- This spec's look.shadow.
		expect(shadow.Position).toEqual(UDim2.fromOffset(0, 5))
		expect(shadow.Size).toEqual(UDim2.fromScale(1, 1))
		expect(shadow.BackgroundColor3 == INK).toBe(true)
		expect((shadow:FindFirstChild("Corner") :: UICorner).CornerRadius).toEqual(UDim.new(0, 8))
		expect((shadow:FindFirstChild("Outline") :: UIStroke).Thickness).toBe(1.5)
		expect(shadow.ZIndex < (key:FindFirstChild("Face") :: Frame).ZIndex).toBe(true)
	end)

	-- A cap that nothing moves (#369): at rest, its name in ink on the plain cap, unscaled, no sweep.
	it("draws a still cap at rest", function()
		local _, cap = Style.keyCap(config, { text = "W" }, CAP, 1, Style.stillCap)
		local key = mount(cap):FindFirstChild("Box") :: Frame
		local face = key:FindFirstChild("Face") :: Frame
		expect((face:FindFirstChild("Legend") :: TextLabel).Text).toBe("W")
		expect(face.BackgroundColor3 == KEY).toBe(true)
		expect((face:FindFirstChild("Scale") :: UIScale).Scale).toBe(1)
		expect((face:FindFirstChild("Sweep") :: Frame).Visible).toBe(false)
	end)

	-- The banners' lettering at any place (#369): what Style.banner holds, for a group that holds more than it.
	it("letters words at a given place, in the banners' layers", function()
		local look = config.UI.hud.look
		local parts = Style.letters(config, "GET UP!", 40, nil, 0, 100, 10)
		local mounted = mount(React.createElement(React.Fragment, nil, parts))
		local front = mounted:FindFirstChild("Front") :: TextLabel
		expect(front.Text).toBe("GET UP!")
		expect(front.Font).toBe(look.bannerFont)
		expect(front.TextSize).toBe(40)
		expect(front.Position).toEqual(UDim2.fromOffset(100, 10))
		local width = Style.textWidth(config, "GET UP!", 40, look.bannerFont)
		expect(front.Size).toEqual(UDim2.fromOffset(width, 40))
		-- Look.shadow lower; no team ring without a colour.
		expect((mounted:FindFirstChild("Shadow") :: TextLabel).Position).toEqual(UDim2.fromOffset(100, 15))
		expect(mounted:FindFirstChild("Edge")).toBeNil()
	end)

	-- Look C's banners (#356, the owner's Q191, Q210): white over ink, the team's ring round that, the shadow lower.
	it("letters a banner in three layers inside a group that fades whole, nothing clipped", function()
		local look = config.UI.hud.look
		local width = Style.textWidth(config, "GOAL!", 40, look.bannerFont)
		local group = mount(Style.banner(config, {}, "GOAL!", 40, RED, 3, 6)):FindFirstChild("Box") :: CanvasGroup
		expect(group.ClassName).toBe("CanvasGroup")
		-- The text and 6 px of ink each side, and the shadow's 5 px under that.
		expect(group.Size).toEqual(UDim2.fromOffset(width + 12, 40 + 12 + 5))
		local front = group:FindFirstChild("Front") :: TextLabel
		local edge = group:FindFirstChild("Edge") :: TextLabel
		local shadow = group:FindFirstChild("Shadow") :: TextLabel
		for _, label in { front, edge, shadow } do
			expect(label.Text).toBe("GOAL!")
			expect(label.Font).toBe(look.bannerFont)
			expect(label.TextSize).toBe(40)
			expect(label.Size).toEqual(UDim2.fromOffset(width, 40))
		end
		expect(front.Position).toEqual(UDim2.fromOffset(6, 6))
		expect(edge.Position).toEqual(UDim2.fromOffset(6, 6))
		expect(shadow.Position).toEqual(UDim2.fromOffset(6, 11))
		expect(near(front.TextColor3, config.UI.hud.textColor)).toBe(true)
		expect(near((front:FindFirstChild("Ink") :: UIStroke).Color, INK)).toBe(true)
		expect((front:FindFirstChild("Ink") :: UIStroke).Thickness).toBe(1.5)
		expect(near(edge.TextColor3, RED)).toBe(true)
		expect(near((edge:FindFirstChild("Ink") :: UIStroke).Color, RED)).toBe(true)
		expect((edge:FindFirstChild("Ink") :: UIStroke).Thickness).toBe(4.5)
		expect(near(shadow.TextColor3, INK)).toBe(true)
		expect((shadow:FindFirstChild("Ink") :: UIStroke).Thickness).toBe(4.5)
		-- Back to front: the shadow, the ring, the white letters.
		expect(shadow.ZIndex < edge.ZIndex and edge.ZIndex < front.ZIndex).toBe(true)
	end)

	it("letters a banner about nobody with no team ring, its shadow as wide as its ink", function()
		local group = mount(Style.banner(config, {}, "60 SECONDS", 40, nil, 3, 6)):FindFirstChild("Box") :: CanvasGroup
		expect(group:FindFirstChild("Edge")).toBeNil()
		local shadow = group:FindFirstChild("Shadow") :: TextLabel
		expect((shadow:FindFirstChild("Ink") :: UIStroke).Thickness).toBe(1.5)
	end)

	-- Rows and caps are sized from their texts (an auto-sized row round its box's ink would grow without end).
	it("measures a key cap's width: its name's and padding, never narrower than tall; a glyph's square", function()
		local font = config.UI.hud.look.font
		local shift = TextService:GetTextSize("Shift", 15, font, Vector2.new(math.huge, math.huge))
		expect(Style.textWidth(config, "Shift", 15)).toBe(math.ceil(shift.X))
		expect(Style.textWidth(config, "", 15)).toBe(0)
		-- In another font when asked (the banners' Luckiest Guy, #356).
		local banner = config.UI.hud.look.bannerFont
		local goal = TextService:GetTextSize("Shift", 15, banner, Vector2.new(math.huge, math.huge))
		expect(Style.textWidth(config, "Shift", 15, banner)).toBe(math.ceil(goal.X))
		expect(Style.capWidth(config, { text = "Shift" }, CAP)).toBe(math.ceil(shift.X) + 12)
		expect(Style.capWidth(config, { text = "E" }, CAP)).toBe(30)
		expect(Style.capWidth(config, { image = GLYPH }, CAP)).toBe(30)
		-- A mouse button's square, though its name alone would be wider.
		expect(Style.capWidth(config, { text = "LMB" }, CAP) > 30).toBe(true)
		expect(Style.capWidth(config, { text = "LMB", mouse = "Left" }, CAP)).toBe(30)
		-- On a cap with no mouse's sizes it goes by its name.
		local plain: Config.CapSizes = {
			height = CAP.height,
			padding = CAP.padding,
			corner = CAP.corner,
			textSize = CAP.textSize,
		}
		local named = Style.capWidth(config, { text = "LMB" }, plain)
		expect(named > 30).toBe(true)
		expect(Style.capWidth(config, { text = "LMB", mouse = "Left" }, plain)).toBe(named)
	end)

	it("pops a pressed key's cap in the pressed colour, and writes a cooling key's seconds on it", function()
		local moving = capBindings()
		local _, cap = Style.keyCap(config, { text = "E" }, CAP, 1, moving.bindings)
		local face = (mount(cap):FindFirstChild("Box") :: Frame):FindFirstChild("Face") :: Frame
		moving.setPressed(true)
		expect(face.BackgroundColor3 == PRESSED).toBe(true)
		moving.setPress(0.88)
		expect((face:FindFirstChildOfClass("UIScale") :: UIScale).Scale).toBeCloseTo(0.88, 4)
		moving.setPressed(false)
		expect(face.BackgroundColor3 == KEY).toBe(true)
		local label = face:FindFirstChild("Legend") :: TextLabel
		moving.setSeconds("0.7")
		expect(label.Text).toBe("0.7")
		moving.setSeconds("")
		expect(label.Text).toBe("E")
	end)

	-- Lit where the cooldown has run, growing clockwise from 12 o'clock (Q186: "fills back clockwise"): each half's ink
	-- steps from solid to clear across its middle, turned so the step runs along the sweep's edge. Drawn only while the
	-- key cools (#363: at rest its step lay on the halves' seam).
	it("sweeps a cooling key's ink away clockwise from 12 o'clock as its cooldown runs out", function()
		local moving = capBindings()
		local _, cap = Style.keyCap(config, { text = "E" }, CAP, 1, moving.bindings)
		local face = (mount(cap):FindFirstChild("Box") :: Frame):FindFirstChild("Face") :: Frame
		local sweep = face:FindFirstChild("Sweep") :: Frame
		expect(sweep.Size).toEqual(UDim2.fromOffset(30, 30))
		expect(sweep.Position).toEqual(UDim2.fromScale(0, 0.5))
		expect(sweep.Visible).toBe(false)
		expect(sweep.ZIndex < (face:FindFirstChild("Legend") :: TextLabel).ZIndex).toBe(true)
		local halves = { sweep:FindFirstChild("Left") :: Frame, sweep:FindFirstChild("Right") :: Frame }
		local turns: { UIGradient } = {}
		for index, half in halves do
			expect(half.ClipsDescendants).toBe(true)
			expect(half.Size).toEqual(UDim2.fromScale(0.5, 1))
			local ink = half:FindFirstChild("Ink") :: Frame
			expect(ink.Size).toEqual(UDim2.fromScale(2, 1))
			expect(ink.Position).toEqual(UDim2.fromScale(1 - index, 0))
			expect(ink.BackgroundColor3 == INK).toBe(true)
			expect(ink.BackgroundTransparency).toBeCloseTo(0.3, 4)
			expect((ink:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(UDim.new(0, 8))
			local gradient = ink:FindFirstChildOfClass("UIGradient") :: UIGradient
			local keys = gradient.Transparency.Keypoints
			expect(keys[1].Value).toBe(0)
			expect(keys[#keys].Value).toBe(1)
			table.insert(turns, gradient)
		end
		expect(halves[2].Position).toEqual(UDim2.fromScale(0.5, 0))
		-- All ink, a quarter run (lit 12 to 3), three quarters (lit 12 to 9), all run.
		local cases = { { share = 1, left = 360, right = 180 }, { share = 0.75, left = 360, right = 270 } }
		table.insert(cases, { share = 0.25, left = 450, right = 360 })
		table.insert(cases, { share = 0, left = 540, right = 360 })
		for _, case in cases do
			moving.setCooldown(case.share)
			expect(turns[1].Rotation).toBeCloseTo(case.left, 3)
			expect(turns[2].Rotation).toBeCloseTo(case.right, 3)
			expect(sweep.Visible).toBe(case.share > 0)
		end
	end)

	-- The halves meet on the sweep's middle: started on a half pixel, the seam split a pixel and showed a line down the
	-- cap (#363, the owner's Q212). So the square starts on a whole pixel, within half a pixel of the cap's middle.
	it("puts a cap's sweep on whole pixels however wide its name makes the cap", function()
		local moving = capBindings()
		local names = { "E", "Tab", "Ctrl", "Shift", "Space", "Enter" }
		local caps: { [string]: React.Node } = {}
		for _, name in names do
			local _, cap = Style.keyCap(config, { text = name }, CAP, 1, moving.bindings)
			caps[name] = cap
		end
		local mounted = mount(React.createElement(React.Fragment, nil, caps))
		local odd = false
		for _, name in names do
			local width = Style.capWidth(config, { text = name }, CAP)
			odd = odd or (width - 30) % 2 == 1
			local face = (mounted:FindFirstChild(name) :: Frame):FindFirstChild("Face") :: Frame
			local sweep = face:FindFirstChild("Sweep") :: Frame
			-- From the cap's left edge by an offset alone (a UDim's offset holds whole pixels).
			expect(sweep.AnchorPoint.X).toBe(0)
			expect(sweep.Position.X.Scale).toBe(0)
			expect(math.abs(sweep.Position.X.Offset - (width - 30) / 2) <= 0.5).toBe(true)
		end
		-- At least one of these names gives a cap whose middle falls between pixels.
		expect(odd).toBe(true)
	end)

	-- The mouse's buttons (Q207, A1 on the design page): a mouse in the HUD's text colour on the cap, its key's button
	-- inked: the body's own rounded shape seen through a clip over that button, so it keeps the body's curve.
	it("draws a mouse button's key as a mouse on its cap, that button inked", function()
		local moving = capBindings()
		local name, left = Style.keyCap(config, { text = "LMB", mouse = "Left" }, CAP, 1, moving.bindings)
		expect(name).toBe("Key")
		local _, right = Style.keyCap(config, { text = "RMB", mouse = "Right" }, CAP, 2, moving.bindings)
		local mounted = mount(React.createElement(React.Fragment, nil, { Left = left, Right = right }))
		local key = mounted:FindFirstChild("Left") :: Frame
		expect(key.Size).toEqual(UDim2.fromOffset(30, 30))
		local face = key:FindFirstChild("Face") :: Frame
		expect(face.BackgroundColor3 == KEY).toBe(true)
		expect(face:FindFirstChildOfClass("UIStroke") ~= nil).toBe(true)
		-- The 12 x 20 body in its 2 px of ink, centred on the cap, above the sweep.
		local mouse = face:FindFirstChild("Mouse") :: Frame
		expect(mouse.Size).toEqual(UDim2.fromOffset(16, 24))
		expect(mouse.Position).toEqual(UDim2.fromScale(0.5, 0.5))
		expect(mouse.AnchorPoint == Vector2.new(0.5, 0.5)).toBe(true)
		expect(mouse.ZIndex > (face:FindFirstChild("Sweep") :: Frame).ZIndex).toBe(true)
		local ink = mouse:FindFirstChild("Ink") :: Frame
		expect(ink.Size).toEqual(UDim2.fromScale(1, 1))
		expect(ink.BackgroundColor3 == INK).toBe(true)
		expect((ink:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(Style.ROUND)
		local body = mouse:FindFirstChild("Body") :: Frame
		expect(body.Size).toEqual(UDim2.fromOffset(12, 20))
		expect(body.Position).toEqual(UDim2.fromScale(0.5, 0.5))
		expect(body.AnchorPoint == Vector2.new(0.5, 0.5)).toBe(true)
		expect(body.BackgroundColor3 == config.UI.hud.textColor).toBe(true)
		expect((body:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(Style.ROUND)
		expect(body.ZIndex > ink.ZIndex).toBe(true)
		-- The left button inked, 8 px deep, rounded as the body is; ink lines between the buttons and under them.
		local button = body:FindFirstChild("Button") :: Frame
		expect(button.ClipsDescendants).toBe(true)
		expect(button.Position).toEqual(UDim2.fromScale(0, 0))
		expect(button.Size).toEqual(UDim2.new(0.5, 0, 0, 8))
		local lit = button:FindFirstChild("Ink") :: Frame
		expect(lit.Position).toEqual(UDim2.fromScale(0, 0))
		expect(lit.Size).toEqual(UDim2.fromOffset(12, 20))
		expect(lit.BackgroundColor3 == INK).toBe(true)
		expect((lit:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(Style.ROUND)
		local between = body:FindFirstChild("Between") :: Frame
		expect(between.Size).toEqual(UDim2.fromOffset(2, 8))
		expect(between.Position).toEqual(UDim2.fromScale(0.5, 0))
		expect(between.AnchorPoint == Vector2.new(0.5, 0)).toBe(true)
		local under = body:FindFirstChild("Under") :: Frame
		expect(under.Size).toEqual(UDim2.new(1, 0, 0, 2))
		expect(under.Position).toEqual(UDim2.fromOffset(0, 8))
		expect(under.AnchorPoint == Vector2.new(0, 0.5)).toBe(true)
		for _, line in { between, under } do
			expect(line.BackgroundColor3 == INK).toBe(true)
			expect(line.ZIndex > button.ZIndex).toBe(true)
		end
		-- The right button: the clip over the body's right half, the shape in it moved back by that half.
		local rightFace = (mounted:FindFirstChild("Right") :: Frame):FindFirstChild("Face") :: Frame
		local rightBody = (rightFace:FindFirstChild("Mouse") :: Frame):FindFirstChild("Body") :: Frame
		local rightButton = rightBody:FindFirstChild("Button") :: Frame
		expect(rightButton.Position).toEqual(UDim2.fromScale(0.5, 0))
		expect((rightButton:FindFirstChild("Ink") :: Frame).Position).toEqual(UDim2.fromScale(-1, 0))
		-- No name on it; cooling, its seconds lettered over the mouse in the text colour, inked.
		local legend = face:FindFirstChild("Legend") :: TextLabel
		expect(legend.Text).toBe("")
		moving.setSeconds("0.7")
		expect(legend.Text).toBe("0.7")
		expect(legend.TextColor3 == config.UI.hud.textColor).toBe(true)
		expect(legend:FindFirstChildOfClass("UIStroke") ~= nil).toBe(true)
		expect(legend.ZIndex > mouse.ZIndex).toBe(true)
		-- Pressed, the cap turns the pressed colour as every key's does.
		moving.setPressed(true)
		expect(face.BackgroundColor3 == PRESSED).toBe(true)
	end)

	it("shows a gamepad's glyph instead of a cap, its seconds lettered over it", function()
		local moving = capBindings()
		local name, cap = Style.keyCap(config, { image = GLYPH }, CAP, 1, moving.bindings)
		expect(name).toBe("Glyph")
		local glyph = mount(cap):FindFirstChild("Box") :: Frame
		expect(glyph.Size).toEqual(UDim2.fromOffset(30, 30))
		local face = glyph:FindFirstChild("Face") :: ImageLabel
		expect(face.Image).toBe(GLYPH)
		expect(face.BackgroundTransparency).toBe(1)
		local label = face:FindFirstChild("Legend") :: TextLabel
		expect(label.Text).toBe("")
		moving.setSeconds("0.7")
		expect(label.Text).toBe("0.7")
		expect(label.TextColor3 == config.UI.hud.textColor).toBe(true)
		expect(label:FindFirstChildOfClass("UIStroke") ~= nil).toBe(true)
		-- Round, as Roblox's glyphs are.
		local ink = ((face:FindFirstChild("Sweep") :: Frame):FindFirstChild("Left") :: Frame):FindFirstChild("Ink")
		expect(((ink :: Frame):FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(Style.ROUND)
	end)
end)
