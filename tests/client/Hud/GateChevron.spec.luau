--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local GateChevron = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.GateChevron)
local React = require(ReplicatedStorage.Packages.React)

-- Round sizes of this spec's own: look C's ink 2 px round a part and 3 more below; a 40 px chevron (20 on a phone), its
-- bars 0.2 of it thick, each arm 30 degrees off the line it points along: (40 - 8) / (2 sin 30) = 32 px long.
local INK = Color3.fromRGB(10, 20, 30)
local TEAM = Color3.fromRGB(250, 150, 60)
local config = Fixtures.config({
	UI = {
		hud = {
			look = { ink = INK, outline = 2, shadow = 3 },
			layout = {
				markers = {
					chevron = { bar = 0.2, spread = 30 },
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

local function chevron(compact: boolean?, turn: React.Binding<number>?): Frame
	local place = React.createBinding(UDim2.fromOffset(600, 100))
	local shown = React.createBinding(true)
	local parent = Instance.new("Folder")
	parent.Name = "GateChevronTest"
	parent.Parent = workspace
	folder = parent
	-- Keyed as App keys it: react-roblox names a host instance by the nearest key up the tree.
	local mount = Fixtures.mount(
		React.createElement(React.Fragment, nil, {
			GateChevron = React.createElement(GateChevron, {
				config = config,
				compact = compact == true,
				color = TEAM,
				place = place,
				turn = turn or React.createBinding(180),
				shown = shown,
			}),
		}),
		parent
	)
	return mount:FindFirstChild("GateChevron") :: Frame
end

local function child(root: Instance, path: { string }): GuiObject
	local node: Instance = root
	for _, name in path do
		node = node:FindFirstChild(name) :: Instance
	end
	return node :: GuiObject
end

describe("GateChevron", function()
	it("sits centred where its place binding puts it", function()
		local root = chevron()
		expect(root.AnchorPoint).toEqual(Vector2.new(0.5, 0.5))
		expect(root.Position).toEqual(UDim2.fromOffset(600, 100))
		expect(root.Visible).toBe(true)
	end)

	it("draws two rounded bars meeting at its tip, in the team's colour over look C's ink", function()
		local root = chevron()
		-- Each bar 32 long between its round ends' centres, 8 thick: 40 x 8, centred 8 px either side of the middle
		-- (half an arm's 16 px across) and turned 60 degrees off flat, so they meet at the tip 13.9 px above the
		-- middle.
		local sides: { [string]: number } = { Left = -1, Right = 1 }
		for name: string, side: number in sides do
			local bar = child(root, { "Arrow", name })
			expect(bar.Size).toEqual(UDim2.fromOffset(40, 8))
			expect(bar.Position).toEqual(UDim2.new(0.5, side * 8, 0.5, 0))
			expect(bar.Rotation).toBe(side * 60)
			expect(bar.BackgroundColor3).toEqual(TEAM)
			expect((bar:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(UDim.new(0.5, 0))
			-- Its ink 2 px round it, and its shadow the ink again, 3 px lower on the screen.
			local ink = child(root, { "Arrow", `{name}Ink` })
			expect(ink.Size).toEqual(UDim2.fromOffset(44, 12))
			expect(ink.Position).toEqual(bar.Position)
			expect(ink.Rotation).toBe(bar.Rotation)
			expect(ink.BackgroundColor3).toEqual(INK)
			expect(ink.ZIndex < bar.ZIndex).toBe(true)
			expect(child(root, { "Shadow", name }).Size).toEqual(ink.Size)
		end
		expect(child(root, { "Shadow" }).Position).toEqual(UDim2.new(0.5, 0, 0.5, 3))
		expect(child(root, { "Arrow" }).Position).toEqual(UDim2.fromScale(0.5, 0.5))
	end)

	it("turns its tip and its shadow with its turn binding", function()
		local turn, setTurn = React.createBinding(180)
		local root = chevron(false, turn)
		expect(child(root, { "Arrow" }).Rotation).toBe(180)
		expect(child(root, { "Shadow" }).Rotation).toBe(180)
		setTurn(45)
		expect(child(root, { "Arrow" }).Rotation).toBe(45)
		expect(child(root, { "Shadow" }).Rotation).toBe(45)
	end)

	it("draws at a phone's size on a phone's screen", function()
		-- 20 px: bars 4 thick and 16 long, 20 x 4, 4 px either side.
		local bar = child(chevron(true), { "Arrow", "Right" })
		expect(bar.Size).toEqual(UDim2.fromOffset(20, 4))
		expect(bar.Position).toEqual(UDim2.new(0.5, 4, 0.5, 0))
	end)
end)
