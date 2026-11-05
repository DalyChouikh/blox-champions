--!strict
-- The control hints (spec §11.1) in look C (#354; the owner's Q186, Q195b), at the right of the screen: a row per
-- control, in ControlLabels' order, a look C box round the key's cap (Style.keyCap) and what the control does now. The
-- key is the name the player's own keyboard gives it, or Roblox's glyph on a gamepad. What follows the play is a
-- binding, so a row changes without a render: it hides while it has no label (an empty one: Attach with no teammate
-- ahead), and fades whole (box, cap and label: a CanvasGroup) while it shows but does nothing now (#315, #368: RC fades
-- the whole row, Video 34 at 43.0 s). A key just pressed pops in the pressed colour, with RC's >> outside its row, over
-- the game (Q195b: the box keeps no room for it); a key cooling down shows its seconds left and an ink sweep clearing
-- clockwise. Each row is as wide as its parts, measured (Style.textWidth, Style.capWidth): an auto-sized row would grow
-- without end round its box's ink, which reaches past the box. The rows stack right-aligned, clearance pixels of the
-- game between one row's drop shadow and the next one's outline, the column's top on a whole pixel of its area
-- (HudScreen.hintsTop, #378). A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ControlLabels = require(script.Parent.Parent.ControlLabels)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)

export type HintKeys = { [Config.TouchControl]: Style.KeyView }
-- One row's bindings: what its control does now ("" while it has no label), how see-through the whole row is (0
-- while its control works, UI.hud.dimTransparency while it is greyed), and what moves on its key's cap.
export type HintRow = {
	label: React.Binding<string>,
	fade: React.Binding<number>,
	cap: Style.CapBindings,
}
export type HintRows = { [Config.TouchControl]: HintRow }

export type ControlHintsProps = {
	config: Config.GameConfig,
	keys: HintKeys,
	rows: HintRows,
	-- The size in pixels of the HUD's area the column is placed in.
	area: React.Binding<Vector2>,
	-- Told the column's frame whenever its laid-out box changes: the screen markers keep clear of it (#376).
	onBox: ((frame: GuiObject) -> ())?,
}

local function shown(label: string): boolean
	return label ~= ""
end

-- A row at `order`: its mark, then its box with the key's cap and the label in a group that fades them as one. The
-- group reaches past the box by its outline and drop shadow, so the ink it holds is not clipped.
local function hint(config: Config.GameConfig, view: Style.KeyView, moving: HintRow, order: number): React.ReactElement
	local look = config.UI.hud.look
	local place = config.UI.hud.layout.hints
	local outline, shadow = look.outline, look.shadow
	-- The row's box inside its ink: the outline round it, the shadow under it.
	local inside = {
		Position = UDim2.fromOffset(outline, outline),
		Size = UDim2.new(1, -2 * outline, 1, -2 * outline - shadow),
	}
	local keyName, key = Style.keyCap(config, view, place.cap, 1, moving.cap)
	-- Across: the outlines, the insets, the cap and the gap, then the label's text.
	local across = 2 * outline
		+ place.inset.left
		+ Style.capWidth(config, view, place.cap)
		+ place.gap
		+ place.inset.right
	local height = HudScreen.hintRow(config)
	local line: { [string]: React.Node } = {
		Inset = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, place.inset.left),
			PaddingRight = UDim.new(0, place.inset.right),
		}),
		Layout = Style.list(config, Enum.FillDirection.Horizontal, { Padding = UDim.new(0, place.gap) }),
		[keyName] = key,
		Label = React.createElement(
			"TextLabel",
			Style.lettering(config, {
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				Text = moving.label,
				TextSize = place.textSize,
			})
		),
	}
	return React.createElement(
		"Frame",
		Style.holder({
			LayoutOrder = order,
			Size = moving.label:map(function(label: string): UDim2
				return UDim2.fromOffset(across + Style.textWidth(config, label, place.textSize), height)
			end),
			Visible = moving.label:map(shown),
		}),
		{
			Mark = React.createElement(
				"TextLabel",
				Style.lettering(config, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromOffset(-place.press.gap, outline),
					Size = UDim2.fromOffset(0, place.rowHeight),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = config.UI.text.pressMark,
					TextColor3 = look.pressed,
					TextSize = place.press.textSize,
					Visible = moving.cap.pressed,
				}),
				{ Ink = Style.inked(config) }
			),
			Group = Style.fadeGroup(config, moving.fade, 0, {
				Box = Style.box(config, inside, look.box),
				Line = React.createElement("Frame", Style.holder(Style.above(inside)), line),
			}),
		}
	)
end

local function ControlHints(props: ControlHintsProps): React.ReactElement
	local config = props.config
	local place = config.UI.hud.layout.hints
	local rows: { [string]: React.Node } = {
		Layout = Style.list(config, Enum.FillDirection.Vertical, {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, place.clearance),
		}),
	}
	-- What places the column: its area's size, and each row's label, as an empty one hides its row.
	local placing: { [string]: React.Binding<any> } = { area = props.area }
	for order, control: Config.TouchControl in ControlLabels.CONTROLS do
		rows[control] = hint(config, props.keys[control], props.rows[control], order)
		placing[control] = props.rows[control].label
	end
	local x = place.position.X
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = Vector2.new(1, 0),
			Position = React.joinBindings(placing):map(function(now: { [string]: any }): UDim2
				local count = 0
				for _, control in ControlLabels.CONTROLS do
					if shown(now[control]) then
						count += 1
					end
				end
				local area: Vector2 = now.area
				return UDim2.new(x.Scale, x.Offset, 0, HudScreen.hintsTop(config, area.Y, count))
			end),
			Size = UDim2.new(),
			AutomaticSize = Enum.AutomaticSize.XY,
			[React.Change.AbsoluteSize] = props.onBox,
			[React.Change.AbsolutePosition] = props.onBox,
		}),
		rows
	)
end

return ControlHints
