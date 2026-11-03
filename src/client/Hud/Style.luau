--!strict
-- The props and layout pieces the HUD's parts share, all from Config.UI.hud, so each part spells out only its own.
-- Look C (the owner, Q184; UI.hud.look) is drawn from Roblox's released UI objects only: a box's outline and drop
-- shadow are one ink shape under its fill (Style.box), its shade a gradient, its lettering outlined by a UIStroke.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Fit = require(ReplicatedStorage.Shared.Hud.Fit)
local React = require(ReplicatedStorage.Packages.React)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

-- Keyed by property name, or by a React event (React.Event.Activated).
export type Props = { [any]: any }
-- One key as the HUD shows it: the name the player's own keyboard gives it, or Roblox's glyph on a gamepad.
export type KeyView = { text: string?, image: string? }
-- How see-through a greyed part's text or glyph is: a number, or a binding that follows the play.
export type Fade = number | React.Binding<number>
-- A rounded part of a look C box, as wide as the box: its top and its height as shares of the box's height.
export type Piece = { top: number, height: number, corner: UDim }
type Children = { [string]: React.Node }

-- A white fill shows its gradient's own colours (a UIGradient multiplies the colour it covers).
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local Style = {}

-- A corner that rounds a part's shorter side all the way.
Style.ROUND = UDim.new(0.5, 0)

-- `props` written over `base`, which the caller made fresh: React keeps each element's props.
local function over(base: Props, props: Props?): Props
	if props ~= nil then
		for key, value in props do
			base[key] = value
		end
	end
	return base
end

-- A text label: the HUD's font and text colour at its text size, on no background.
function Style.text(config: Config.GameConfig, props: Props?): Props
	local hud = config.UI.hud
	return over({
		Font = hud.font,
		TextColor3 = hud.textColor,
		TextSize = hud.textSize,
		BackgroundTransparency = 1,
	}, props)
end

-- What the HUD draws in `team`'s colour (the HUD's own, look.teamColors: brighter than the world's, the owner's
-- choice, Q201), or in its own text colour for no team (a draw, overtime, a loose ball).
function Style.teamColor(config: Config.GameConfig, team: Team.Team?): Color3
	local hud = config.UI.hud
	return if team ~= nil then hud.look.teamColors[team] else hud.textColor
end

-- How see-through something greyed is (a control, a hint or a button that would do nothing, an empty pip):
-- UI.hud.dimTransparency; else solid.
function Style.dim(config: Config.GameConfig, greyed: boolean): number
	return if greyed then config.UI.hud.dimTransparency else 0
end

-- A panel: the HUD's panel colour, see-through by panelTransparency.
function Style.panel(config: Config.GameConfig, props: Props?): Props
	local hud = config.UI.hud
	return over(
		{ BackgroundColor3 = hud.panel, BackgroundTransparency = hud.panelTransparency, BorderSizePixel = 0 },
		props
	)
end

-- A panel drawn over the game (the score tab, the end screen): Style.panel, but overlayTransparency see-through.
function Style.overlay(config: Config.GameConfig, props: Props?): Props
	return Style.panel(config, over({ BackgroundTransparency = config.UI.hud.overlayTransparency }, props))
end

-- Drawn above its siblings that keep the default ZIndex (1): with equal ZIndex, the sibling parented later draws on
-- top (probed), and React's order of keyed children is not fixed.
function Style.above(props: Props?): Props
	return over({ ZIndex = 2 }, props)
end

-- A frame that only holds others.
function Style.holder(props: Props?): Props
	return over({ BackgroundTransparency = 1, BorderSizePixel = 0 }, props)
end

-- Lines a frame's parts up one after another in their LayoutOrder, centred, `spacing` apart, with `props` on top.
function Style.list(config: Config.GameConfig, direction: Enum.FillDirection, props: Props?): React.ReactElement
	return React.createElement(
		"UIListLayout",
		over({
			FillDirection = direction,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, config.UI.hud.spacing),
		}, props)
	)
end

-- Rounds a panel's corners.
function Style.corner(config: Config.GameConfig): React.ReactElement
	return React.createElement("UICorner", { CornerRadius = config.UI.hud.corner })
end

-- Rounds a square frame all the way: a disc.
function Style.round(): React.ReactElement
	return React.createElement("UICorner", { CornerRadius = Style.ROUND })
end

-- Look C's lettering: Style.text in UI.hud.look's font, with `props` on top.
function Style.lettering(config: Config.GameConfig, props: Props?): Props
	return Style.text(config, over({ Font = config.UI.hud.look.font }, props))
end

-- Look C's ink outline round a text label's letters (a UIStroke on a text label rings its text): look.textOutline
-- pixels thick.
function Style.inked(config: Config.GameConfig): React.ReactElement
	local look = config.UI.hud.look
	return React.createElement("UIStroke", { Color = look.ink, Thickness = look.textOutline })
end

-- Look C's shade down a part in `color`, from `top` to `bottom` (shares of its box's height): the colour at the
-- box's top, darkening to look.shade of the way to black at its bottom. On a white frame (Style.box's fill).
function Style.shading(config: Config.GameConfig, color: Color3, top: number, bottom: number): React.ReactElement
	local shade = config.UI.hud.look.shade
	return React.createElement("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(color:Lerp(BLACK, shade * top), color:Lerp(BLACK, shade * bottom)),
	})
end

-- A look C box in `color`, its frame placed and sized by `props`: `pieces` (one piece with look.corner by default)
-- filled and shaded (Style.shading) over one ink silhouette, each piece grown by look.outline on every side and by
-- look.shadow more below it, so the outline and the drop shadow are one shape with no seam where pieces meet.
-- `children` sit above it all, in its "Content" frame.
function Style.box(
	config: Config.GameConfig,
	props: Props,
	color: Color3,
	children: Props?,
	pieces: { Piece }?
): React.ReactElement
	local look = config.UI.hud.look
	local grow, drop = look.outline, look.shadow
	local shape: { Piece } = pieces or { { top = 0, height = 1, corner = look.corner } }
	local parts: Children = {}
	for index, piece in shape do
		local corner = piece.corner
		local grown = UDim.new(corner.Scale, corner.Offset + grow)
		parts[`Ink{index}`] = React.createElement("Frame", {
			Position = UDim2.new(0, -grow, piece.top, -grow),
			Size = UDim2.new(1, 2 * grow, piece.height, 2 * grow + drop),
			BackgroundColor3 = look.ink,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, { Corner = React.createElement("UICorner", { CornerRadius = grown }) })
		parts[`Fill{index}`] = React.createElement("Frame", {
			Position = UDim2.fromScale(0, piece.top),
			Size = UDim2.fromScale(1, piece.height),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = corner }),
			Shade = Style.shading(config, color, piece.top, piece.top + piece.height),
		})
	end
	parts.Content = React.createElement("Frame", Style.holder({ Size = UDim2.fromScale(1, 1), ZIndex = 3 }), children)
	return React.createElement("Frame", Style.holder(props), parts)
end

-- How far below a look C box's bottom another starts so `clearance` pixels show between them: the upper box's ink
-- reaches look.outline + look.shadow below it (Style.box), the lower one's look.outline above it.
function Style.under(config: Config.GameConfig, clearance: number): number
	local look = config.UI.hud.look
	return look.outline + look.shadow + clearance + look.outline
end

-- A ring: a see-through disc frame (`props` place and size it) with an outline, a UIStroke (`outline` sets its Color,
-- Thickness and any other of its properties). `effects` holds what acts on the outline itself (a gradient).
function Style.ring(props: Props, outline: Props, effects: { [string]: React.Node }?): React.ReactElement
	return React.createElement("Frame", over({ BackgroundTransparency = 1 }, props), {
		Corner = Style.round(),
		Stroke = React.createElement("UIStroke", outline, effects),
	})
end

-- Shrinks a part to fit the HUD's area (a binding), screenMargin inside each edge (Fit). The part is `size`, or, for a
-- panel that grows to fit its parts (AutomaticSize Y), as tall as they need where that is taller: `content` pixels
-- inside Style.padding.
function Style.fit(
	config: Config.GameConfig,
	area: React.Binding<Vector2>,
	size: UDim2,
	content: number?
): React.ReactElement
	local hud = config.UI.hud
	local margin = hud.screenMargin
	local laidOut = if content ~= nil
		then UDim2.fromOffset(size.X.Offset, math.max(size.Y.Offset, content + 2 * hud.spacing))
		else size
	return React.createElement("UIScale", {
		Scale = area:map(function(shown: Vector2): number
			return Fit.scale(shown, laidOut, margin)
		end),
	})
end

-- A key `height` pixels tall at `order` in its row: Roblox's glyph, or its name on a key cap that a long name ("Shift")
-- widens, keeping `spacing` at each side, faded by `fade` on a greyed button. Returns what its row calls it ("Glyph" or
-- "Key") and the key.
function Style.key(
	config: Config.GameConfig,
	view: KeyView,
	height: number,
	order: number,
	fade: Fade?
): (string, React.ReactElement)
	local size = UDim2.fromOffset(height, height)
	if view.image ~= nil then
		return "Glyph",
			React.createElement(
				"ImageLabel",
				Style.holder({ LayoutOrder = order, Size = size, Image = view.image, ImageTransparency = fade })
			)
	end
	local spacing = UDim.new(0, config.UI.hud.spacing)
	return "Key",
		React.createElement(
			"TextLabel",
			Style.text(
				config,
				Style.panel(config, {
					LayoutOrder = order,
					Size = size,
					AutomaticSize = Enum.AutomaticSize.X,
					Text = view.text or "",
					TextTransparency = fade,
				})
			),
			{
				Corner = Style.corner(config),
				Padding = React.createElement("UIPadding", { PaddingLeft = spacing, PaddingRight = spacing }),
			}
		)
end

-- A key's label: as tall as its row, as wide as its text (a string or a binding), at `order` in the row, faded by
-- `fade` on a greyed button.
function Style.label(
	config: Config.GameConfig,
	text: string | React.Binding<string>,
	order: number,
	fade: Fade?
): React.ReactElement
	return React.createElement(
		"TextLabel",
		Style.text(config, {
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			Text = text,
			TextTransparency = fade,
		})
	)
end

-- Keeps a panel's parts `spacing` inside its edge.
function Style.padding(config: Config.GameConfig): React.ReactElement
	local inset = UDim.new(0, config.UI.hud.spacing)
	return React.createElement("UIPadding", {
		PaddingTop = inset,
		PaddingBottom = inset,
		PaddingLeft = inset,
		PaddingRight = inset,
	})
end

return table.freeze(Style)
