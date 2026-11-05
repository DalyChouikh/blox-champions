--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Config = require(ReplicatedStorage.Shared.Config)
local ControlHints = require(Client.Hud.ControlHints)
local ControlLabels = require(Client.ControlLabels)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(Client.Hud.Style)

-- Look C's rows at sizes of this spec's own: 30 px rows 2 px apart, a 24 px cap (a 10 x 18 mouse on a mouse
-- button's), the mark 10 px out.
local config = Fixtures.config({
	UI = {
		hud = {
			look = { outline = 2, shadow = 3, groupRoom = 5 },
			layout = {
				hints = {
					rowHeight = 30,
					clearance = 2,
					inset = { left = 4, right = 9 },
					gap = 7,
					textSize = 18,
					cap = {
						height = 24,
						padding = 5,
						corner = UDim.new(0, 6),
						textSize = 14,
						mouse = { width = 10, height = 18, buttons = 7, line = 2 },
					},
					press = { textSize = 20, gap = 10 },
				},
			},
		},
	},
})
local look = config.UI.hud.look
local GLYPH = "rbxasset://textures/ui/Controls/DefaultController/ButtonX@2x.png"

-- A row's setters, for what follows the play.
type Setters = {
	label: (string) -> (),
	fade: (number) -> (),
	press: (number) -> (),
	pressed: (boolean) -> (),
	cooldown: (number) -> (),
	seconds: (string) -> (),
}

local folder: Folder
local setters: { [string]: Setters }

-- Hints for every control, each reading its own name, lit and at rest, with `keys` for their keys (an "X" key
-- otherwise).
local function hints(keys: { [string]: Style.KeyView }): React.ReactElement
	local views: ControlHints.HintKeys = {}
	local rows: ControlHints.HintRows = {}
	setters = {}
	for _, control: Config.TouchControl in ControlLabels.CONTROLS do
		views[control] = keys[control] or { text = "X" }
		local label, setLabel = React.createBinding(control :: string)
		local fade, setFade = React.createBinding(0)
		local press, setPress = React.createBinding(1)
		local pressed, setPressed = React.createBinding(false)
		local cooldown, setCooldown = React.createBinding(0)
		local seconds, setSeconds = React.createBinding("")
		rows[control] = {
			label = label,
			fade = fade,
			cap = { press = press, pressed = pressed, cooldown = cooldown, seconds = seconds },
		}
		setters[control] = {
			label = setLabel,
			fade = setFade,
			press = setPress,
			pressed = setPressed,
			cooldown = setCooldown,
			seconds = setSeconds,
		}
	end
	return React.createElement(React.Fragment, nil, {
		ControlHints = React.createElement(ControlHints, { config = config, keys = views, rows = rows }),
	})
end

-- A row's parts: the row, its fading group, the line in its box, the key's slot, cap face and legend, its label and
-- its mark.
local function partsOf(mounted: Instance, control: string): any
	local row = (mounted:FindFirstChild("ControlHints") :: Frame):FindFirstChild(control) :: Frame
	local group = row:FindFirstChild("Group") :: CanvasGroup
	local line = group:FindFirstChild("Line") :: Frame
	local slot = (line:FindFirstChild("Key") or line:FindFirstChild("Glyph")) :: Frame
	return {
		row = row,
		group = group,
		line = line,
		slot = slot,
		face = slot:FindFirstChild("Face"),
		legend = (slot:FindFirstChild("Face") :: Instance):FindFirstChild("Legend") :: TextLabel,
		label = line:FindFirstChild("Label") :: TextLabel,
		mark = row:FindFirstChild("Mark") :: TextLabel,
	}
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ControlHintsTest"
	folder.Parent = workspace
end)

afterEach(function()
	Fixtures.unmountAll()
	folder:Destroy()
end)

describe("ControlHints", function()
	it("shows each control's key: the keyboard's own key names, Roblox's gamepad glyphs", function()
		local mounted = Fixtures.mount(hints({ tackle = { text = "E" }, pass = { image = GLYPH } }), folder)
		local tackle = partsOf(mounted, "tackle")
		expect(tackle.slot.Name).toBe("Key")
		expect(tackle.legend.Text).toBe("E")
		expect(tackle.label.Text).toBe("tackle")
		local pass = partsOf(mounted, "pass")
		expect(pass.slot.Name).toBe("Glyph")
		expect(pass.face.Image).toBe(GLYPH)
		local frame = mounted:FindFirstChild("ControlHints") :: Frame
		for index, control: Config.TouchControl in ControlLabels.CONTROLS do
			expect((frame:FindFirstChild(control) :: Frame).LayoutOrder).toBe(index)
		end
	end)

	-- Look C (#354, the design page's): a box round the key's cap and the label, its ink inside the row's group.
	it("draws each row as a look C box round its key's cap and its label", function()
		local mounted = Fixtures.mount(hints({ tackle = { text = "E" } }), folder)
		local tackle = partsOf(mounted, "tackle")
		-- The box, its outline and its drop shadow fill the row's height: 30 + 2 + 2 + 3; across, the outlines, the
		-- insets, the cap, the gap and the label's text.
		local label = Style.textWidth(config, "tackle", 18)
		expect(tackle.row.Size).toEqual(UDim2.fromOffset(2 + 4 + 24 + 7 + label + 9 + 2, 37))
		-- A longer label widens it.
		setters.tackle.label("Cancel & Dodge")
		local longer = Style.textWidth(config, "Cancel & Dodge", 18)
		expect(tackle.row.Size).toEqual(UDim2.fromOffset(2 + 4 + 24 + 7 + longer + 9 + 2, 37))
		-- Its box and line inside its ink: the 2 px outline round them, the 3 px shadow under them.
		local box = tackle.group:FindFirstChild("Box") :: Frame
		expect(box.Position).toEqual(UDim2.fromOffset(2, 2))
		expect(box.Size).toEqual(UDim2.new(1, -4, 1, -7))
		expect(tackle.line.Position).toEqual(UDim2.fromOffset(2, 2))
		expect(tackle.line.Size).toEqual(UDim2.new(1, -4, 1, -7))
		expect(box:FindFirstChild("Ink1") ~= nil and box:FindFirstChild("Fill1") ~= nil).toBe(true)
		expect(tackle.line.ZIndex > box.ZIndex).toBe(true)
		local inset = tackle.line:FindFirstChildOfClass("UIPadding") :: UIPadding
		expect(inset.PaddingLeft).toEqual(UDim.new(0, 4))
		expect(inset.PaddingRight).toEqual(UDim.new(0, 9))
		expect((tackle.line:FindFirstChildOfClass("UIListLayout") :: UIListLayout).Padding).toEqual(UDim.new(0, 7))
		expect(tackle.slot.Size).toEqual(UDim2.fromOffset(24, 24))
		expect(tackle.legend.TextSize).toBe(14)
		expect(tackle.label.TextSize).toBe(18)
		expect(tackle.label.Font).toBe(look.font)
	end)

	-- A greyed hint (#315: Magnetic Pass with nobody to pass to; RC fades the whole row, Video 34 at 43.0 s): its box,
	-- key and label faded together as its fade binding says, without a render.
	it("fades a greyed hint whole as its fade says", function()
		local mounted = Fixtures.mount(hints({ pass = { image = GLYPH } }), folder)
		local tackle, pass = partsOf(mounted, "tackle"), partsOf(mounted, "pass")
		expect(tackle.group.GroupTransparency).toBe(0)
		setters.tackle.fade(0.6)
		setters.pass.fade(0.6)
		expect(tackle.group.GroupTransparency).toBeCloseTo(0.6, 4)
		expect(pass.group.GroupTransparency).toBeCloseTo(0.6, 4)
		setters.tackle.fade(0)
		expect(tackle.group.GroupTransparency).toBe(0)
	end)

	it("hides a hint with an empty label", function()
		local mounted = Fixtures.mount(hints({}), folder)
		local attach = partsOf(mounted, "attach")
		expect(attach.row.Visible).toBe(true)
		setters.attach.label("")
		expect(attach.row.Visible).toBe(false)
		setters.attach.label("Attach")
		expect(attach.row.Visible).toBe(true)
		expect(attach.label.Text).toBe("Attach")
	end)

	-- The owner (Q186, Q195b): the key pressed pops, and RC's >> shows beside it outside the box, over the game.
	it("pops a key pressed and marks it outside its row, unfaded", function()
		local mounted = Fixtures.mount(hints({ pump = { text = "Shift" } }), folder)
		local pump = partsOf(mounted, "pump")
		expect(pump.mark.Visible).toBe(false)
		expect(pump.mark.Parent == pump.row).toBe(true)
		expect(pump.mark.Text).toBe(config.UI.text.pressMark)
		expect(pump.mark.TextColor3 == look.pressed).toBe(true)
		expect(pump.mark.TextSize).toBe(20)
		-- Its right edge 10 px left of the row's outline, level with the box.
		expect(pump.mark.AnchorPoint == Vector2.new(1, 0)).toBe(true)
		expect(pump.mark.Position).toEqual(UDim2.fromOffset(-10, 2))
		expect(pump.mark.Size).toEqual(UDim2.fromOffset(0, 30))
		setters.pump.pressed(true)
		setters.pump.press(0.9)
		expect(pump.mark.Visible).toBe(true)
		expect(pump.face.BackgroundColor3 == look.pressed).toBe(true)
		expect((pump.face:FindFirstChildOfClass("UIScale") :: UIScale).Scale).toBeCloseTo(0.9, 4)
		setters.pump.pressed(false)
		expect(pump.mark.Visible).toBe(false)
		expect(pump.face.BackgroundColor3 == look.key).toBe(true)
	end)

	-- The owner (Q186): a key on cooldown fills back clockwise with the seconds left on it.
	it("writes a cooling key's seconds on its cap and sweeps it", function()
		local mounted = Fixtures.mount(hints({ uppercut = { text = "Q" } }), folder)
		local uppercut = partsOf(mounted, "uppercut")
		setters.uppercut.seconds("0.7")
		setters.uppercut.cooldown(0.5)
		expect(uppercut.legend.Text).toBe("0.7")
		local sweep = uppercut.face:FindFirstChild("Sweep") :: Frame
		expect(sweep.Size).toEqual(UDim2.fromOffset(24, 24))
		local right = (sweep:FindFirstChild("Right") :: Frame):FindFirstChild("Ink") :: Frame
		expect((right:FindFirstChildOfClass("UIGradient") :: UIGradient).Rotation).toBeCloseTo(360, 3)
		setters.uppercut.seconds("")
		expect(uppercut.legend.Text).toBe("Q")
	end)
end)

-- The column as Roblox lays it out (a ScreenGui under StarterGui is laid out in Edit, after a frame).
describe("ControlHints, laid out", function()
	local gui: ScreenGui?

	afterEach(function()
		if gui ~= nil then
			gui:Destroy()
			gui = nil
		end
	end)

	it("stacks the rows right-aligned, each as wide as its parts, clearance apart, the mark left of its row", function()
		local layer = Instance.new("ScreenGui")
		layer.Name = "ControlHintsLaidOutTest"
		layer.Parent = game:GetService("StarterGui")
		gui = layer
		local mounted = Fixtures.mount(hints({ jump = { text = "Space" }, pump = { text = "E" } }), layer)
		setters.jump.pressed(true)
		task.wait()
		local column = mounted:FindFirstChild("ControlHints") :: Frame
		local jump, pump = partsOf(mounted, "jump"), partsOf(mounted, "pump")
		local right = jump.row.AbsolutePosition.X + jump.row.AbsoluteSize.X
		expect(pump.row.AbsolutePosition.X + pump.row.AbsoluteSize.X).toBe(right)
		expect(right).toBe(column.AbsolutePosition.X + column.AbsoluteSize.X)
		-- The outline, the inset, the cap, the gap, the label, the inset and the outline.
		local width = 2 + 4 + pump.slot.AbsoluteSize.X + 7 + pump.label.AbsoluteSize.X + 9 + 2
		expect(pump.row.AbsoluteSize.X).toBe(width)
		expect(pump.slot.AbsoluteSize.X).toBe(24)
		-- 2 px of the game between jump's drop shadow (the row's bottom) and pump's outline (its top).
		expect(pump.row.AbsolutePosition.Y - (jump.row.AbsolutePosition.Y + jump.row.AbsoluteSize.Y)).toBe(2)
		local mark = jump.mark
		expect(mark.AbsolutePosition.X + mark.AbsoluteSize.X).toBe(jump.row.AbsolutePosition.X - 10)
		expect(mark.AbsolutePosition.Y).toBe(jump.row.AbsolutePosition.Y + 2)
		-- Each row's group keeps look.groupRoom round its ink: a group cuts off what reaches its edges (#386, Q257).
		expect(Fixtures.inkRoom(jump.group)).toEqual({ left = 5, top = 5, right = 5, bottom = 5 })
		expect(Fixtures.inkRoom(pump.group)).toEqual({ left = 5, top = 5, right = 5, bottom = 5 })
	end)
end)
