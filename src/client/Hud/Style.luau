--!strict
-- The props and layout pieces the HUD's parts share, all from Config.UI.hud, so each part spells out only its own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Fit = require(ReplicatedStorage.Shared.Hud.Fit)
local React = require(ReplicatedStorage.Packages.React)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

-- Keyed by property name, or by a React event (React.Event.Activated).
export type Props = { [any]: any }
-- One key as the HUD shows it: the name the player's own keyboard gives it, or Roblox's glyph on a gamepad.
export type KeyView = { text: string?, image: string? }

local Style = {}

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

-- What the HUD draws in `team`'s colour, or in its own text colour for no team (a draw, overtime, a loose ball).
function Style.teamColor(config: Config.GameConfig, team: Team.Team?): Color3
	return if team ~= nil then config.UI.teamColors[team] else config.UI.hud.textColor
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
	fade: number?
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
	fade: number?
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
