--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local BallBadge = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.BallBadge)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local React = require(ReplicatedStorage.Packages.React)

-- Round sizes of this spec's own: look C's ink 2 px round a part and 3 more below; a 50 px badge (30 on a phone), its
-- ring 0.1 of it, its band's lines 2 px thick 0.2 of it either side of the middle, leaning 10 degrees; its pointer 0.2
-- of it tall, 4 px past the ring's ink.
local INK = Color3.fromRGB(10, 20, 30)
local BLUE = Color3.fromRGB(40, 120, 250)
local config = Fixtures.config({
	UI = {
		teamColors = { Blue = BLUE },
		hud = {
			look = { ink = INK, outline = 2, shadow = 3 },
			layout = {
				markers = {
					badge = { ring = 0.1, band = 0.2, line = 2, lean = 10, gap = 4, pointer = 0.2 },
					sizes = { badge = 50, chevron = 40 },
					compactSizes = { badge = 30, chevron = 20 },
				},
			},
		},
	},
})

local folder: Folder?

afterEach(function()
	Fixtures.unmountAll()
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
end)

type Moving = { place: React.Binding<UDim2>, turn: React.Binding<number>, shown: React.Binding<boolean> }

local function badge(team: string?, compact: boolean?, moving: Moving?): Frame
	local place = React.createBinding(UDim2.fromOffset(300, 40))
	local turn = React.createBinding(30)
	local shown = React.createBinding(true)
	local bindings: Moving = moving or { place = place, turn = turn, shown = shown }
	local parent = Instance.new("Folder")
	parent.Name = "BallBadgeTest"
	parent.Parent = workspace
	folder = parent
	-- Keyed as App keys it: react-roblox names a host instance by the nearest key up the tree.
	local mount = Fixtures.mount(
		React.createElement(React.Fragment, nil, {
			BallBadge = React.createElement(BallBadge, {
				config = config,
				compact = compact == true,
				team = team :: any,
				place = bindings.place,
				turn = bindings.turn,
				shown = bindings.shown,
			}),
		}),
		parent
	)
	return mount:FindFirstChild("BallBadge") :: Frame
end

local function part(root: Instance, path: { string }): GuiObject
	local node: Instance = root
	for _, name in path do
		node = node:FindFirstChild(name) :: Instance
	end
	return node :: GuiObject
end

describe("BallBadge", function()
	it("sits where its place binding puts its centre, shown while its binding says so", function()
		local place, setPlace = React.createBinding(UDim2.fromOffset(300, 40))
		local turn = React.createBinding(0)
		local shown, setShown = React.createBinding(true)
		local root = badge("Blue", false, { place = place, turn = turn, shown = shown })
		expect(root.AnchorPoint).toEqual(Vector2.new(0.5, 0.5))
		expect(root.Position).toEqual(UDim2.fromOffset(300, 40))
		expect(root.Visible).toBe(true)
		setPlace(UDim2.fromOffset(120, 400))
		setShown(false)
		expect(root.Position).toEqual(UDim2.fromOffset(120, 400))
		expect(root.Visible).toBe(false)
	end)

	it("draws RC's white ball in a ring of the team's colour, ringed in ink with a drop shadow", function()
		local root = badge("Blue")
		local ring, ball, ink = part(root, { "Ring" }), part(root, { "Ball" }), part(root, { "Ink" })
		expect(ring.Size).toEqual(UDim2.fromOffset(50, 50))
		expect(ring.BackgroundColor3).toEqual(BLUE)
		-- The ball inside the ring's 5 px.
		expect(ball.Size).toEqual(UDim2.fromOffset(40, 40))
		expect(ball.BackgroundColor3).toEqual(Color3.new(1, 1, 1))
		-- The ink 2 px round the ring and 3 more below: one shape.
		expect(ink.Size).toEqual(UDim2.fromOffset(54, 57))
		expect(ink.Position).toEqual(UDim2.new(0.5, 0, 0.5, -27))
		expect(ink.BackgroundColor3).toEqual(INK)
		for _, name in { "Ring", "Ball", "Ink" } do
			expect((part(root, { name }):FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(
				UDim.new(0.5, 0)
			)
		end
	end)

	it("crosses the ball with its band's two lines, leaning, in the team's colour", function()
		local root = badge("Blue")
		local band = part(root, { "Band" })
		expect(band.Rotation).toBe(10)
		-- Each line 2 px thick, 10 px either side of the middle, as long as the ball's chord there and 1 px into the
		-- ring at each end, in whole pixels (a UDim's offset drops a fraction): 2 sqrt(20^2 - 10^2) + 2 = 36.6, so 37.
		local chord = 37
		for index, offset in { -10, 10 } do
			local line = part(band, { `Line{index}` })
			expect(line.BackgroundColor3).toEqual(BLUE)
			expect(line.AnchorPoint).toEqual(Vector2.new(0.5, 0.5))
			expect(line.Position).toEqual(UDim2.new(0.5, 0, 0.5, offset))
			expect(line.Size.X.Offset).toBe(chord)
			expect(line.Size.Y.Offset).toBe(2)
		end
	end)

	it("turns its pointer to the ball: a right-angled tip past the ring's ink, inked, its shadow dropped", function()
		local turn, setTurn = React.createBinding(30)
		local place = React.createBinding(UDim2.fromOffset(300, 40))
		local shown = React.createBinding(true)
		local root = badge("Blue", false, { place = place, turn = turn, shown = shown })
		local pointer, shadow = part(root, { "Pointer" }), part(root, { "PointerShadow" })
		expect(pointer.Rotation).toBe(30)
		expect(shadow.Rotation).toBe(30)
		setTurn(-135)
		expect(pointer.Rotation).toBe(-135)
		expect(shadow.Rotation).toBe(-135)
		-- The shadow's holder look.shadow lower on the screen.
		expect(shadow.Position).toEqual(UDim2.new(0.5, 0, 0.5, 3))
		-- The tip 10 px tall from its base, 25 + 2 x 2 + 4 = 33 px out: half a square 10 sqrt 2 (14 whole) pixels wide
		-- turned 45 degrees, centred on the base, the half past the base kept by a hard-step gradient.
		local fill = part(pointer, { "Fill" })
		expect(fill.Size).toEqual(UDim2.fromOffset(14, 14))
		expect(fill.Position).toEqual(UDim2.new(0.5, 0, 0.5, -33))
		expect(fill.Rotation).toBe(45)
		expect(fill.BackgroundColor3).toEqual(BLUE)
		local cut = fill:FindFirstChildOfClass("UIGradient") :: UIGradient
		expect(cut.Rotation).toBe(45)
		expect(cut.Transparency.Keypoints[1].Value).toBe(0)
		expect(cut.Transparency.Keypoints[#cut.Transparency.Keypoints].Value).toBe(1)
		-- Its ink the same tip grown 2 px on every side about its incentre (its inradius 14 (2 - sqrt 2) / 2 = 4.1): a
		-- square 14 x 6.1 / 4.1 = 20.8, so 21 px wide, its base 2 px nearer the ring.
		local ink = part(pointer, { "Ink" })
		expect(ink.Size).toEqual(UDim2.fromOffset(21, 21))
		expect(ink.Position).toEqual(UDim2.new(0.5, 0, 0.5, -31))
		expect(ink.BackgroundColor3).toEqual(INK)
		expect(part(shadow, { "Ink" }).Size).toEqual(ink.Size)
	end)

	it("is dark like RC's until a team has held the ball, its ball still white", function()
		local root = badge(nil)
		expect(part(root, { "Ring" }).BackgroundColor3).toEqual(INK)
		expect(part(root, { "Band", "Line1" }).BackgroundColor3).toEqual(INK)
		expect(part(root, { "Pointer", "Fill" }).BackgroundColor3).toEqual(INK)
		expect(part(root, { "Ball" }).BackgroundColor3).toEqual(Color3.new(1, 1, 1))
	end)

	it("draws at a phone's size on a phone's screen", function()
		local root = badge("Blue", true)
		expect(part(root, { "Ring" }).Size).toEqual(UDim2.fromOffset(30, 30))
		expect(part(root, { "Ball" }).Size).toEqual(UDim2.fromOffset(24, 24))
	end)
end)
