--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local GetUp = require(Client.Hud.GetUp)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(Client.Hud.Style)
local TextService = game:GetService("TextService")

-- This spec's own: 2 px of ink round the caps and the words, a 4 px drop shadow, a digit's rise of a tenth; 40 px caps
-- 5 apart and the words at 30, 10 past them; 30 px caps and the words at 20 on a phone.
local config = Fixtures.config({
	UI = {
		hud = {
			screenMargin = 8,
			look = { shadow = 4, textOutline = 2, bannerDigitRise = 0.1, groupRoom = 3 },
			layout = {
				getUp = {
					sizes = {
						bottom = 90,
						gap = 5,
						wordsGap = 10,
						textSize = 30,
						cap = { height = 40, padding = 5, corner = UDim.new(0, 8), textSize = 20, dropShadow = true },
					},
					compactSizes = {
						bottom = 60,
						gap = 4,
						wordsGap = 8,
						textSize = 20,
						cap = { height = 30, padding = 4, corner = UDim.new(0, 6), textSize = 14, dropShadow = true },
					},
				},
			},
		},
	},
})
local look = config.UI.hud.look
local UNBOUNDED = Vector2.new(math.huge, math.huge)
-- Roblox's glyph for a gamepad's left stick (probed).
local GLYPH = "rbxasset://textures/ui/Controls/DefaultController/Thumbstick1@2x.png"

local folder: Folder
local scale: React.Binding<number>, setScale: (number) -> ()
local leave: React.Binding<number>, setLeave: (number) -> ()
local area: React.Binding<Vector2>, setArea: (Vector2) -> ()

-- The prompt keyed as App keys it, which names its frame.
local function prompt(
	keys: { Style.KeyView },
	compact: boolean?,
	lines: number?,
	own: Config.GameConfig?
): React.ReactElement
	return React.createElement(React.Fragment, nil, {
		GetUp = React.createElement(GetUp, {
			config = own or config,
			keys = keys,
			compact = compact == true,
			lines = lines or 0,
			scale = scale,
			leave = leave,
			area = area,
		}),
	})
end

local function mounted(element: React.ReactElement): Frame
	return Fixtures.mount(element, folder):FindFirstChild("GetUp") :: Frame
end

local function child(parent: Instance, name: string): any
	return parent:FindFirstChild(name)
end

-- How wide the words are in the banners' font, whole pixels up.
local function wordsWidth(size: number): number
	return math.ceil(TextService:GetTextSize("GET UP!", size, look.bannerFont, UNBOUNDED).X)
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "GetUpTest"
	folder.Parent = workspace
	scale, setScale = React.createBinding(1)
	leave, setLeave = React.createBinding(0)
	area, setArea = React.createBinding(Vector2.zero)
end)

afterEach(function()
	Fixtures.unmountAll()
	folder:Destroy()
end)

describe("GetUp", function()
	-- Banner style (the owner, Q221): no box, the caps, then the words in the banners' lettering.
	it("shows the movement keys' caps in order, then GET UP! in the banners' lettering, on no box", function()
		-- An AZERTY keyboard's movement keys, as Roblox names W, A, S and D there (probed).
		local names = { "Z", "Q", "S", "D" }
		local views: { Style.KeyView } = {}
		for _, name in names do
			table.insert(views, { text = name })
		end
		local frame = mounted(prompt(views))
		expect(frame.BackgroundTransparency).toBe(1)
		local group = child(frame, "Group") :: CanvasGroup
		-- Its room (3 px) past the prompt on every side.
		expect(group.Size).toEqual(UDim2.new(1, 6, 1, 6))
		local keys = child(group, "Keys") :: Frame
		for index, name in names do
			local key = child(keys, `Key{index}`)
			expect(`{key.Face.Legend.Text} at {key.LayoutOrder}`).toBe(`{name} at {index}`)
			-- A letter's cap is as wide as it is tall, with its drop shadow.
			expect(key.Size).toEqual(UDim2.fromOffset(40, 40))
			expect(key.Shadow ~= nil).toBe(true)
		end
		-- 4 x 40 + 3 x 5 across, inside the 2 px of ink; the caps fill the row, so they start at the top.
		expect(keys.Position).toEqual(UDim2.fromOffset(2, 2))
		expect(keys.Size).toEqual(UDim2.fromOffset(175, 40))
		expect(child(keys, "Layout").Padding).toEqual(UDim.new(0, 5))

		local front = child(group, "Front") :: TextLabel
		expect(front.Text).toBe("GET UP!")
		expect(front.Font).toBe(look.bannerFont)
		expect(front.TextSize).toBe(30)
		-- 10 past the caps; down the row by (40 - 30) / 2, and by the letters' rise (a tenth of 30).
		expect(front.Position).toEqual(UDim2.fromOffset(2 + 175 + 10, 2 + 5 + 3))
		expect(child(group, "Shadow").Position).toEqual(UDim2.fromOffset(187, 14))
		expect(child(group, "Edge")).toBeNil()
		-- The ink each side of everything; the row and its drop shadow, tall.
		expect(frame.Size).toEqual(UDim2.fromOffset(2 + 175 + 10 + wordsWidth(30) + 2, 2 + 40 + 4 + 2))
	end)

	it("shows a gamepad's stick as Roblox's glyph", function()
		local frame = mounted(prompt({ { image = GLYPH } }))
		local group = child(frame, "Group")
		local keys = child(group, "Keys")
		expect(child(keys, "Glyph1").Face.Image).toBe(GLYPH)
		expect(child(keys, "Key1")).toBeNil()
		-- A glyph's square.
		expect(keys.Size).toEqual(UDim2.fromOffset(40, 40))
		expect(child(group, "Front").Position).toEqual(UDim2.fromOffset(2 + 40 + 10, 10))
	end)

	-- The touch stick's name on a cap as wide as it (the owner, Q221), a phone's sizes.
	it("shows the touch stick's name on a phone's cap, at a phone's sizes", function()
		local frame = mounted(prompt({ { text = "Move" } }, true))
		local group = child(frame, "Group")
		local keys = child(group, "Keys")
		local key = child(keys, "Key1")
		expect(key.Face.Legend.Text).toBe("Move")
		local name = math.ceil(TextService:GetTextSize("Move", 14, look.font, UNBOUNDED).X)
		local across = math.max(30, name + 2 * 4)
		expect(key.Size).toEqual(UDim2.fromOffset(across, 30))
		expect(keys.Size).toEqual(UDim2.fromOffset(across, 30))
		local front = child(group, "Front") :: TextLabel
		expect(front.TextSize).toBe(20)
		-- 8 past the cap; down the row by (30 - 20) / 2, and by the letters' rise (a tenth of 20).
		expect(front.Position).toEqual(UDim2.fromOffset(2 + across + 8, 2 + 5 + 2))
		expect(frame.Size).toEqual(UDim2.fromOffset(2 + across + 8 + wordsWidth(20) + 2, 2 + 30 + 4 + 2))
	end)

	-- Look C's own ink is a fraction, and a UDim's offset would drop it; these words stand taller than their caps.
	it("rounds its ink up to whole pixels and centres caps shorter than its words", function()
		local own = Fixtures.config({
			UI = {
				hud = {
					look = { shadow = 4, textOutline = 2.5, bannerDigitRise = 0.1 },
					layout = {
						getUp = {
							sizes = {
								bottom = 90,
								gap = 5,
								wordsGap = 10,
								textSize = 30,
								cap = {
									height = 20,
									padding = 5,
									corner = UDim.new(0, 8),
									textSize = 14,
									dropShadow = true,
								},
							},
						},
					},
				},
			},
		})
		local frame = mounted(prompt({ { text = "W" } }, false, 0, own))
		local group = child(frame, "Group")
		local keys = child(group, "Keys") :: Frame
		local across = keys.Size.X.Offset
		-- The ink's 2.5 up to 3; the 20 px caps down the 30 px row by 5.
		expect(keys.Position).toEqual(UDim2.fromOffset(3, 3 + 5))
		expect(keys.Size.Y.Offset).toBe(20)
		-- The words fill the row: down only by their rise, a tenth of 30.
		expect(child(group, "Front").Position).toEqual(UDim2.fromOffset(3 + across + 10, 3 + 3))
		expect(frame.Size.Y.Offset).toBe(3 + 30 + 4 + 3)
	end)

	-- Up from the stage's bottom, on either kind of screen, clear of the feed's lines (HudScreen.getUpBottom).
	it("sits at the bottom centre, over the feed's lines", function()
		local keys: { Style.KeyView } = { { text = "W" } }
		local root, rerender = Fixtures.mount(prompt(keys), folder)
		local frame = child(root, "GetUp") :: Frame
		expect(frame.AnchorPoint == Vector2.new(0.5, 1)).toBe(true)
		expect(frame.Position).toEqual(UDim2.new(0.5, 0, 1, -90))
		rerender(prompt(keys, true))
		expect(frame.Position).toEqual(UDim2.new(0.5, 0, 1, -60))
		-- Three lines reach past its place.
		local high = HudScreen.getUpBottom(config, false, 3)
		expect(high > 90).toBe(true)
		rerender(prompt(keys, false, 3))
		expect(frame.Position).toEqual(UDim2.new(0.5, 0, 1, -high))
	end)

	it("pops by its scale and fades whole by how far it has left", function()
		local group = child(mounted(prompt({ { text = "W" } })), "Group") :: CanvasGroup
		setScale(0.5)
		expect(child(group, "Pop").Scale).toBe(0.5)
		expect(group.GroupTransparency).toBe(0)
		setLeave(0.25)
		expect(group.GroupTransparency).toBeCloseTo(0.25, 4)
	end)

	it("shrinks to fit a stage narrower than itself", function()
		local frame = mounted(prompt({ { text = "W" }, { text = "A" } }))
		local fit = child(frame, "Fit") :: UIScale
		expect(fit.Scale).toBe(1)
		setArea(Vector2.new(150, 323))
		expect(fit.Scale).toBeCloseTo((150 - 2 * 8) / frame.Size.X.Offset, 4)
		setArea(Vector2.new(1920, 1000))
		expect(fit.Scale).toBe(1)
	end)
end)

-- The prompt as Roblox lays it out (a ScreenGui under StarterGui is laid out in Edit, after a frame).
describe("GetUp, laid out", function()
	local gui: ScreenGui?

	afterEach(function()
		if gui ~= nil then
			gui:Destroy()
			gui = nil
		end
	end)

	-- A group cuts off the ink that reaches past its edges (#386, the owner's Q257).
	it("keeps look.groupRoom round its keys' and words' ink inside the group that fades it", function()
		local layer = Instance.new("ScreenGui")
		layer.Name = "GetUpLaidOutTest"
		layer.Parent = game:GetService("StarterGui")
		gui = layer
		setArea(Vector2.new(1556, 735))
		local frame = Fixtures.mount(prompt({ { text = "W" } }), layer):FindFirstChild("GetUp") :: Frame
		task.wait()
		expect(Fixtures.inkRoom(child(frame, "Group"))).toEqual({ left = 3, top = 3, right = 3, bottom = 3 })
	end)
end)
