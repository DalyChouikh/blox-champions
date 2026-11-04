--!strict
-- The props and layout pieces the HUD's parts share, all from Config.UI.hud, so each part spells out only its own.
-- Look C (the owner, Q184; UI.hud.look) is drawn from Roblox's released UI objects only: a box's outline and drop
-- shadow are one ink shape under its fill (Style.box), its shade a gradient, its lettering outlined by a UIStroke;
-- a key's cap (Style.keyCap) pops, and sweeps while its key cools down, through bindings only (#354); a mouse's
-- button shows as a mouse with that button inked (Q207).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Fit = require(ReplicatedStorage.Shared.Hud.Fit)
local React = require(ReplicatedStorage.Packages.React)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local TextService = game:GetService("TextService")
local TextWidths = require(script.Parent.TextWidths)

-- Keyed by property name, or by a React event (React.Event.Activated).
export type Props = { [any]: any }
-- One of a mouse's buttons: its key shows as a mouse with that button inked (#354, the owner's Q207).
export type MouseButton = "Left" | "Right"
-- One key as the HUD shows it: the name the player's own keyboard gives it, or Roblox's glyph on a gamepad; a
-- mouse's button also says which (its key cap draws the mouse, the parts that letter keys keep the name).
export type KeyView = { text: string?, image: string?, mouse: MouseButton? }
-- How see-through a greyed part's text or glyph is: a number, or a binding that follows the play.
export type Fade = number | React.Binding<number>
-- A rounded part of a look C box, as wide as the box: its top and its height as shares of the box's height.
export type Piece = { top: number, height: number, corner: UDim }
-- What moves on a key's cap (#354): its pop (a UIScale), whether it shows pressed, the share of its cooldown still
-- to run (0 while not cooling) and its seconds left ("" while not cooling).
export type CapBindings = {
	press: React.Binding<number>,
	pressed: React.Binding<boolean>,
	cooldown: React.Binding<number>,
	seconds: React.Binding<string>,
}
export type Children = { [string]: React.Node }

-- A white fill shows its gradient's own colours (a UIGradient multiplies the colour it covers).
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
-- Room enough for any one line of text (TextService).
local UNBOUNDED = Vector2.new(math.huge, math.huge)
-- Solid across the first half of a gradient, clear across the second: a hard step (two keypoints a hair apart).
local STEP = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.4999, 0),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local Style = {}

-- A frame's fill under a shade (Style.shading).
Style.WHITE = WHITE
-- A corner that rounds a part's shorter side all the way.
Style.ROUND = UDim.new(0.5, 0)
-- A part centred on its place (its AnchorPoint), placed in the middle of its parent, or as big as its parent.
Style.CENTRE = Vector2.new(0.5, 0.5)
Style.MIDDLE = UDim2.fromScale(0.5, 0.5)
Style.FULL = UDim2.fromScale(1, 1)
local CENTRE, MIDDLE, FULL = Style.CENTRE, Style.MIDDLE, Style.FULL

-- A sweep's angle clockwise from 12 o'clock, where the share still to run starts: 0 for all of it, 360 for none.
local function sweepAngle(share: number): number
	return (1 - share) * 360
end

-- Each half's gradient turn for `share` (Style.sweep): the right half sweeps to 6 o'clock, the left from there.
local function rightTurn(share: number): number
	return math.min(sweepAngle(share), 180) + 180
end

local function leftTurn(share: number): number
	return math.max(sweepAngle(share), 180) + 180
end

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

-- What a part holds, `children`, in a "Content" frame as big as it, above the part's own drawing.
local function holding(children: Props?): React.ReactElement
	return React.createElement("Frame", Style.holder({ Size = FULL, ZIndex = 3 }), children)
end

-- Drawn above its siblings that keep the default ZIndex (1): with equal ZIndex, the sibling parented later draws on
-- top (probed), and React's order of keyed children is not fixed.
function Style.above(props: Props?): Props
	return over({ ZIndex = 2 }, props)
end

-- Drawn above what Style.above lifts (the HUD's stage): the TAB board, over all the HUD draws (#357).
function Style.topmost(props: Props?): Props
	return over({ ZIndex = 3 }, props)
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
	parts.Content = holding(children)
	return React.createElement("Frame", Style.holder(props), parts)
end

-- A player's avatar `size` pixels across (#357): `image` (HudText.avatar: their headshot) on a disc in the HUD's text
-- colour, which shows alone for an id that is no Roblox user's or while the headshot loads, ringed in look C's ink.
function Style.avatar(config: Config.GameConfig, size: number, image: string?): React.ReactElement
	local hud = config.UI.hud
	return React.createElement("ImageLabel", {
		AnchorPoint = Style.CENTRE,
		Position = Style.MIDDLE,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = hud.textColor,
		BorderSizePixel = 0,
		Image = image or "",
	}, {
		Corner = Style.round(),
		Ink = React.createElement("UIStroke", { Color = hud.look.ink, Thickness = hud.look.textOutline }),
	})
end

-- A ring: a see-through disc frame (`props` place and size it) with an outline, a UIStroke (`outline` sets its Color,
-- Thickness and any other of its properties). `effects` holds what acts on the outline itself (a gradient).
function Style.ring(props: Props, outline: Props, effects: { [string]: React.Node }?): React.ReactElement
	return React.createElement("Frame", over({ BackgroundTransparency = 1 }, props), {
		Corner = Style.round(),
		Stroke = React.createElement("UIStroke", outline, effects),
	})
end

-- Look C's ring (#353): a `thickness`-pixel stroke in `color` over an ink stroke look.textOutline wider each side,
-- round a disc `size` pixels across at the colour stroke's outer edge (a UIStroke lies outside its frame), in a frame
-- as big as the ink reaches, which `props` place. `fade` sees both strokes through alike; `children` sit above them, in
-- its "Content" frame.
function Style.inkedRing(
	config: Config.GameConfig,
	props: Props,
	size: number,
	thickness: number,
	color: Color3,
	fade: Fade?,
	children: Props?
): React.ReactElement
	local look = config.UI.hud.look
	local ink = look.textOutline
	local reach = size + 2 * ink
	local parts: { [string]: React.Node } = {
		Ink = Style.ring({
			AnchorPoint = CENTRE,
			Position = MIDDLE,
			Size = UDim2.fromOffset(size - 2 * thickness - 2 * ink, size - 2 * thickness - 2 * ink),
			ZIndex = 1,
		}, { Color = look.ink, Thickness = thickness + 2 * ink, Transparency = fade }),
		Line = Style.ring({
			AnchorPoint = CENTRE,
			Position = MIDDLE,
			Size = UDim2.fromOffset(size - 2 * thickness, size - 2 * thickness),
			ZIndex = 2,
		}, { Color = color, Thickness = thickness, Transparency = fade }),
	}
	if children ~= nil then
		parts.Content = holding(children)
	end
	return React.createElement("Frame", Style.holder(over({ Size = UDim2.fromOffset(reach, reach) }, props)), parts)
end

-- One side of a part, `left` or right, `height` down from its top, clipping to that side a shape (`shape`'s props,
-- `children` in it) as big as the whole part: the shape keeps its own outline there (Style.sweep's halves, a
-- mouse's button).
local function sideClip(left: boolean, height: UDim, shape: Props, children: Props): React.ReactElement
	return React.createElement(
		"Frame",
		Style.holder({
			Position = UDim2.fromScale(if left then 0 else 0.5, 0),
			Size = UDim2.new(UDim.new(0.5, 0), height),
			ClipsDescendants = true,
		}),
		{
			Ink = React.createElement(
				"Frame",
				over({ Position = UDim2.fromScale(if left then 0 else -1, 0), BorderSizePixel = 0 }, shape),
				children
			),
		}
	)
end

-- Whether a key's cooldown is still running: the share of it still to run.
local function cooling(share: number): boolean
	return share > 0
end

-- A cooling key's sweep (#354, the owner's Q186: "fills back clockwise"): look C's ink over a `size`-pixel square in
-- the middle of a part `width` pixels wide and as tall, look.sweepTransparency see-through, lit where its cooldown has
-- run: from 12 o'clock clockwise as `share` (a binding, the share still to run) goes from 1 to 0, and not drawn at all
-- while nothing cools. Each half of the square is a clip holding the square's ink, `corner` rounded, whose gradient
-- steps from solid to clear along the line through the middle at the sweep's angle (Rotation: the angle + 180, the
-- right half to 6 o'clock, the left on from there), so only two numbers change as it sweeps. The square is placed
-- from the part's left by an offset alone, which a UDim keeps in whole pixels (dropping a half), so the halves meet on
-- a pixel's edge: a seam through a pixel showed a line down the cap (#363).
function Style.sweep(
	config: Config.GameConfig,
	size: number,
	width: number,
	corner: UDim,
	share: React.Binding<number>
): React.ReactElement
	local look = config.UI.hud.look
	local function half(left: boolean, turn: (share: number) -> number): React.ReactElement
		return sideClip(left, UDim.new(1, 0), {
			Size = UDim2.fromScale(2, 1),
			BackgroundColor3 = look.ink,
			BackgroundTransparency = look.sweepTransparency,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = corner }),
			Step = React.createElement("UIGradient", { Transparency = STEP, Rotation = share:map(turn) }),
		})
	end
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, (width - size) / 2, 0.5, 0),
			Size = UDim2.fromOffset(size, size),
			Visible = share:map(cooling),
		}),
		{ Left = half(true, leftTurn), Right = half(false, rightTurn) }
	)
end

-- The HUD's text widths, each measured once by TextService (a text label's own bounds) until look C's fonts load
-- (TextWidths, #364).
Style.widths = TextWidths.new(function(text: string, size: number, font: Enum.Font): number
	return TextService:GetTextSize(text, size, font, UNBOUNDED).X
end)

-- How wide `text` is at `size` in look C's font (or `inFont`: the banners' look.bannerFont), in whole pixels.
function Style.textWidth(config: Config.GameConfig, text: string, size: number, inFont: Enum.Font?): number
	return Style.widths:width(text, size, inFont or config.UI.hud.look.font)
end

-- A UIStroke round a text label's letters in `color`, `thickness` pixels out.
local function stroke(color: Color3, thickness: number): React.ReactElement
	return React.createElement("UIStroke", { Color = color, Thickness = thickness })
end

-- Look C's banner lettering (#356, the owner's Q191, Q210): `words` in look.bannerFont `size` pixels tall, white
-- over look C's ink outline, a ring of `color` `edge` pixels wide round that (none without a colour), and all of it
-- again in ink look.shadow lower, behind: three labels the text's measured size, the front one's top-left at (x, y),
-- for a group that holds their ink and the shadow below, so nothing is clipped (Style.banner, Hud/GetUp).
function Style.letters(
	config: Config.GameConfig,
	words: string,
	size: number,
	color: Color3?,
	edge: number,
	x: number,
	y: number
): Children
	local look = config.UI.hud.look
	local width = Style.textWidth(config, words, size, look.bannerFont)
	local ring = look.textOutline + (if color ~= nil then edge else 0)
	local function layer(drop: number, letters: Color3?, outline: React.ReactElement, order: number): React.ReactElement
		return React.createElement(
			"TextLabel",
			Style.lettering(config, {
				Position = UDim2.fromOffset(x, y + drop),
				Size = UDim2.fromOffset(width, size),
				Font = look.bannerFont,
				TextSize = size,
				Text = words,
				TextColor3 = letters,
				ZIndex = order,
			}),
			{ Ink = outline }
		)
	end
	return {
		Shadow = layer(look.shadow, look.ink, stroke(look.ink, ring), 1),
		Edge = if color ~= nil then layer(0, color, stroke(color, ring), 2) else nil,
		Front = layer(0, nil, Style.inked(config), 3),
	}
end

-- How wide a banner (Style.banner) of `words` `size` pixels tall stands: its letters, `ink` pixels in from each
-- edge.
function Style.bannerWidth(config: Config.GameConfig, words: string, size: number, ink: number): number
	return Style.textWidth(config, words, size, config.UI.hud.look.bannerFont) + 2 * ink
end

-- A banner: its letters (Style.letters) `ink` pixels in from the edges of a CanvasGroup (`props` place it; `children`
-- act on it). The group fades whole (GroupTransparency): see-through layers would darken where they overlap.
function Style.banner(
	config: Config.GameConfig,
	props: Props,
	words: string,
	size: number,
	color: Color3?,
	edge: number,
	ink: number,
	children: Props?
): React.ReactElement
	local look = config.UI.hud.look
	local parts = Style.letters(config, words, size, color, edge, ink, ink)
	if children ~= nil then
		for key, child in children do
			parts[key] = child
		end
	end
	return React.createElement(
		"CanvasGroup",
		over({
			Size = UDim2.fromOffset(Style.bannerWidth(config, words, size, ink), size + 2 * ink + look.shadow),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, props),
		parts
	)
end

-- The button `view` shows as a mouse on its cap: only a cap with a mouse's sizes can (the hints'); the others go by
-- the button's name, as `view` names it too.
local function drawnMouse(view: KeyView, sizes: Config.CapSizes): MouseButton?
	return if sizes.mouse ~= nil then view.mouse else nil
end

-- How wide `view`'s key cap is (Style.keyCap): its name's width with sizes.padding each side, never narrower than
-- tall; a glyph's or a drawn mouse's square.
function Style.capWidth(config: Config.GameConfig, view: KeyView, sizes: Config.CapSizes): number
	local height = sizes.height
	if view.image ~= nil or drawnMouse(view, sizes) ~= nil then
		return height
	end
	return math.max(height, Style.textWidth(config, view.text or "", sizes.textSize) + 2 * sizes.padding)
end

-- A mouse on a mouse button's key cap (#354; the owner's Q207, A1 on the design page): a body sizes.mouse.width x
-- height in the HUD's text colour inside look C's ink, `line` thick, rounded top and bottom; its buttons `buttons`
-- deep, parted by ink lines; `button` inked: the body's own shape seen through a clip over that button, so it keeps
-- the body's curve (clips and shapes, as Style.sweep).
local function mouseShape(config: Config.GameConfig, sizes: Config.CapSizes, button: MouseButton): React.ReactElement
	local hud = config.UI.hud
	-- Only a cap with its sizes comes here (drawnMouse).
	local mouse = sizes.mouse :: Config.MouseSizes
	local line, buttons = mouse.line, mouse.buttons
	local body = UDim2.fromOffset(mouse.width, mouse.height)
	local function round(): React.ReactElement
		return React.createElement("UICorner", { CornerRadius = Style.ROUND })
	end
	local function inked(props: Props, children: Props?): React.ReactElement
		return React.createElement(
			"Frame",
			over({ BackgroundColor3 = hud.look.ink, BorderSizePixel = 0 }, props),
			children
		)
	end
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = CENTRE,
			Position = MIDDLE,
			Size = UDim2.fromOffset(mouse.width + 2 * line, mouse.height + 2 * line),
			ZIndex = 2,
		}),
		{
			Ink = inked({ Size = FULL }, { Corner = round() }),
			Body = React.createElement("Frame", {
				AnchorPoint = CENTRE,
				Position = MIDDLE,
				Size = body,
				BackgroundColor3 = hud.textColor,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				Corner = round(),
				Button = sideClip(
					button == "Left",
					UDim.new(0, buttons),
					{ Size = body, BackgroundColor3 = hud.look.ink },
					{ Corner = round() }
				),
				Between = inked({
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromOffset(line, buttons),
					ZIndex = 2,
				}),
				Under = inked({
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromOffset(0, buttons),
					Size = UDim2.new(1, 0, 0, line),
					ZIndex = 2,
				}),
			}),
		}
	)
end

-- Look C's key cap (#354, the design page's): `view`'s name in ink on a look.key cap `sizes.height` pixels tall and
-- as wide as the name with sizes.padding each side, never narrower than tall, outlined in ink look.textOutline
-- thick; a mouse's button a mouse on a square cap, that button inked (Q207); for a gamepad Roblox's glyph instead,
-- on no cap. `moving` pops it (its UIScale), turns the cap look.pressed, sweeps it (Style.sweep, a square as tall as
-- the cap) and writes its seconds left in place of its name, lettered over a glyph or a mouse. With sizes.dropShadow
-- a cap drops look.shadow under its face, outlined as it is. Its slot keeps its size while it pops, so its row never
-- shifts. At `order` in its row; returns what its row calls it ("Glyph" or "Key") and the cap.
function Style.keyCap(
	config: Config.GameConfig,
	view: KeyView,
	sizes: Config.CapSizes,
	order: number,
	moving: CapBindings
): (string, React.ReactElement)
	local hud = config.UI.hud
	local look = hud.look
	local height, image = sizes.height, view.image
	local width = Style.capWidth(config, view, sizes)
	local mouse: MouseButton? = drawnMouse(view, sizes)
	local parts: Children = {
		Scale = React.createElement("UIScale", { Scale = moving.press }),
		Sweep = Style.sweep(config, height, width, if image ~= nil then Style.ROUND else sizes.corner, moving.cooldown),
	}
	if image ~= nil or mouse ~= nil then
		-- The seconds lettered over a picture of the key.
		parts.Legend = React.createElement(
			"TextLabel",
			Style.lettering(config, { Size = FULL, Text = moving.seconds, TextSize = sizes.textSize, ZIndex = 3 }),
			{ Ink = Style.inked(config) }
		)
	end
	if image ~= nil then
		local face = Style.holder({ AnchorPoint = CENTRE, Position = MIDDLE, Size = FULL, Image = image })
		return "Glyph",
			React.createElement(
				"Frame",
				Style.holder({ LayoutOrder = order, Size = UDim2.fromOffset(width, height) }),
				{
					Face = React.createElement("ImageLabel", face, parts),
				}
			)
	end
	parts.Corner = React.createElement("UICorner", { CornerRadius = sizes.corner })
	parts.Outline = Style.inked(config)
	if mouse ~= nil then
		parts.Mouse = mouseShape(config, sizes, mouse)
	else
		local name = view.text or ""
		parts.Legend = React.createElement(
			"TextLabel",
			Style.lettering(config, {
				Size = FULL,
				Text = moving.seconds:map(function(seconds: string): string
					return if seconds ~= "" then seconds else name
				end),
				TextColor3 = look.ink,
				TextSize = sizes.textSize,
				ZIndex = 2,
			})
		)
	end
	local slot: Children = {
		Face = React.createElement("Frame", {
			AnchorPoint = CENTRE,
			Position = MIDDLE,
			Size = FULL,
			BackgroundColor3 = moving.pressed:map(function(pressed: boolean): Color3
				return if pressed then look.pressed else look.key
			end),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, parts),
	}
	if sizes.dropShadow then
		slot.Shadow = React.createElement("Frame", {
			Position = UDim2.fromOffset(0, look.shadow),
			Size = FULL,
			BackgroundColor3 = look.ink,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = sizes.corner }),
			Outline = Style.inked(config),
		})
	end
	return "Key",
		React.createElement(
			"Frame",
			Style.holder({
				LayoutOrder = order,
				Size = UDim2.fromOffset(width, height),
			}),
			slot
		)
end

-- What moves on a cap that nothing moves (the Get Up prompt's keys, #369): at rest, never pressed, never cooling.
local STILL_CAP: CapBindings = {
	press = (React.createBinding(1)),
	pressed = (React.createBinding(false)),
	cooldown = (React.createBinding(0)),
	seconds = (React.createBinding("")),
}
Style.stillCap = STILL_CAP

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
