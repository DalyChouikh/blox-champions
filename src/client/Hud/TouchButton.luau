--!strict
-- A touch button's face in look C (#355; the owner's Q245-Q250, as the design page drew it and the trial played): a
-- look C box (Style.box) as big as its button across its ink (the page's: the outline inside the size, the shadow
-- hanging below), filled with `fill`, `corner` rounded (a disc: Style.ROUND), its words white in look C's lettering,
-- inked, shrinking under textSize to fit inside UI.touchStyle.textPadding of the fill's sides. What moves is bound, as
-- on a hint row's key cap (#354, Q186): it pops round its middle when pressed (`moving.press`) and shows look.pressed
-- over its fill while it pops or is held; a cooling button's seconds stand in for its words over an ink sweep across
-- its fill (Style.sweep); greyed, it fades whole (`fade`: a CanvasGroup, as a hint row, so its ink does not show
-- through its fill). Drawn into its hit button (TouchControls' through the Hud, or SCORES', Hud/ScoreButton), as big
-- as it. No RC >> beside a pressed button: a thumb covers that spot (the design page). A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)

export type TouchButtonProps = {
	config: Config.GameConfig,
	-- Pixels across its ink: its hit area's size.
	size: Vector2,
	corner: UDim,
	fill: Config.Gradient,
	-- The tallest its words may be, in pixels.
	textSize: number,
	label: string | React.Binding<string>,
	moving: Style.CapBindings,
	-- How see-through it is (UI.hud.dimTransparency while greyed); solid without one.
	fade: Style.Fade?,
}

local function cooling(seconds: string): boolean
	return seconds ~= ""
end

local function resting(seconds: string): boolean
	return seconds == ""
end

-- Words filling the fill, `text` white in ink, shrinking under `textSize` within the touch style's padding.
local function words(
	config: Config.GameConfig,
	text: string | React.Binding<string>,
	textSize: number,
	visible: React.Binding<boolean>
): React.ReactElement
	local padding = UDim.new(0, config.UI.touchStyle.textPadding)
	return React.createElement(
		"TextLabel",
		Style.lettering(config, { Size = Style.FULL, Text = text, TextScaled = true, Visible = visible, ZIndex = 2 }),
		{
			Ink = Style.inked(config),
			Fit = React.createElement("UITextSizeConstraint", { MaxTextSize = textSize }),
			Padding = React.createElement("UIPadding", { PaddingLeft = padding, PaddingRight = padding }),
		}
	)
end

local function TouchButton(props: TouchButtonProps): React.ReactElement
	local config, moving, corner = props.config, props.moving, props.corner
	local look = config.UI.hud.look
	local line = look.outline
	local room = config.UI.touchStyle.groupRoom
	-- The fill's size: the button's, inside its outline (not its group's, bigger by the room and the shadow).
	local inner = props.size - Vector2.new(2 * line, 2 * line)
	local inside: Style.Children = {
		Pressed = React.createElement("Frame", {
			Size = Style.FULL,
			BackgroundColor3 = look.pressed,
			BorderSizePixel = 0,
			Visible = moving.pressed,
			-- Under the sweep (1) and the words.
			ZIndex = 0,
		}, { Corner = React.createElement("UICorner", { CornerRadius = corner }) }),
		Sweep = Style.sweep(config, inner.Y, inner.X, corner, moving.cooldown),
		Words = words(config, props.label, props.textSize, moving.seconds:map(resting)),
		Seconds = words(config, moving.seconds, props.textSize, moving.seconds:map(cooling)),
	}
	return React.createElement(
		"Frame",
		Style.holder({ AnchorPoint = Style.CENTRE, Position = Style.MIDDLE, Size = Style.FULL }),
		{
			Pop = React.createElement("UIScale", { Scale = moving.press }),
			Group = React.createElement(
				"CanvasGroup",
				Style.holder({
					-- Room round the ink and its shadow, which the group would cut where they reach its edges.
					Position = UDim2.fromOffset(-room, -room),
					Size = UDim2.new(1, 2 * room, 1, look.shadow + 2 * room),
					GroupTransparency = props.fade or 0,
				}),
				{
					Box = Style.box(config, {
						Position = UDim2.fromOffset(room + line, room + line),
						Size = UDim2.fromOffset(inner.X, inner.Y),
					}, props.fill, inside, { { top = 0, height = 1, corner = corner } }),
				}
			),
		}
	)
end

return TouchButton
