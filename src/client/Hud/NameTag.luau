--!strict
-- A name tag's drawing (spec §11.1; #358; the owner's Q197 M1 Stacked, Q198 H4 Badge + ripple, Q240-Q241's E2 glove),
-- in look C, rendered into its BillboardGui by NameTags. On the tag's middle the name, in a pill of the team's HUD
-- colour. On one line above it, in this order (the owner's Q197, Q247): while they call, the badge, a disc in the
-- team's colour with an ink rim, a ring rippling out behind it and the white glove waving in it; while they are a
-- pass's target (#315), the pass key on look C's cap with a pointer under it; while they are the teammate to attach
-- behind (#381), the Attach mark, the Attach key and its word in a dark box with a pointer under it. The marks that
-- show sit badgeGap apart, the row on the tag's middle. A plain function of its props; the call moves through
-- bindings every calling tag shares.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CallBadge = require(ReplicatedStorage.Shared.Hud.CallBadge)
local Config = require(ReplicatedStorage.Shared.Config)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)

-- How the call moves now: the glove's turn in degrees, the ring's size and how far it has faded.
export type CallBindings = {
	turn: React.Binding<number>,
	ring: React.Binding<UDim2>,
	fade: React.Binding<number>,
}

export type NameTagProps = {
	config: Config.GameConfig,
	sizes: Config.TagSizes,
	name: string,
	-- The team's colour (Style.teamColor).
	color: Color3,
	-- The pass key while they are a pass's target; nil otherwise. (`key` is React's own prop: it never reaches here.)
	passKey: Style.KeyView?,
	-- While they are the teammate to attach behind (#381): the Attach mark, with the Attach key as the hints show it,
	-- or none on touch, where the word stands alone.
	attaching: boolean,
	attachKey: Style.KeyView?,
	calling: boolean,
	call: CallBindings,
}

-- A pointer is a square turned this far, half of it under its mark.
local POINTER_TURN = 45
-- A square's side, per the half of its diagonal that shows under the cap.
local POINTER_SIDE = math.sqrt(2)
-- The name's box, round all the way (M1 drew a pill).
local PILL: { Style.Piece } = table.freeze({ { top = 0, height = 1, corner = Style.ROUND } })

-- The name in its pill, as wide as its words with pillInset each side, the tag's width at most.
local function pill(props: NameTagProps): React.ReactElement
	local config, sizes = props.config, props.sizes
	local inset = sizes.pillInset
	local width = math.min(
		Style.textWidth(config, props.name, sizes.textSize) + 2 * inset,
		sizes.width - 2 * config.UI.hud.look.outline
	)
	return Style.box(
		config,
		{ AnchorPoint = Style.CENTRE, Position = Style.MIDDLE, Size = UDim2.fromOffset(width, sizes.pillHeight) },
		props.color,
		{
			Player = React.createElement(
				"TextLabel",
				Style.lettering(config, {
					AnchorPoint = Style.CENTRE,
					Position = Style.MIDDLE,
					Size = UDim2.new(1, -2 * inset, 1, 0),
					Text = props.name,
					TextSize = sizes.textSize,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				{ Ink = Style.inked(config) }
			),
		},
		PILL
	)
end

-- The glove's bars in a square holder 2 x badge across, centred on its wave's pivot: each part in white over its ink,
-- grown glove.ink all round, the seams in ink on top. By Scale, as a UDim's Offset would cut a bar to whole pixels and
-- lose a seam 0.9 units wide.
local function gloveBars(config: Config.GameConfig, sizes: Config.TagSizes): Style.Children
	local tag = config.UI.nameTag
	local glove, unit = tag.glove, sizes.glove
	local ink = config.UI.hud.look.ink
	local pivot = tag.call.wavePivot * unit
	local across = 2 * sizes.badge
	local function bar(part: Config.GlovePart, grow: number, color: Color3, layer: number): React.ReactElement
		local placed = CallBadge.place(part, unit, grow)
		return React.createElement("Frame", {
			AnchorPoint = Style.CENTRE,
			Position = UDim2.fromScale(0.5 + placed.x / across, 0.5 + (placed.y - pivot) / across),
			Size = UDim2.fromScale(placed.width / across, placed.height / across),
			Rotation = placed.rotation,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = layer,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(placed.corner / math.min(placed.width, placed.height), 0),
			}),
		})
	end
	local bars: Style.Children = {}
	for index, part in glove.parts do
		bars[`Ink{index}`] = bar(part, glove.ink, ink, 1)
		bars[`Fill{index}`] = bar(part, 0, Style.WHITE, 2)
	end
	for index, seam in glove.seams do
		bars[`Seam{index}`] = bar(seam, 0, ink, 3)
	end
	return bars
end

-- The call's badge with its middle at (x, y) in the tag.
local function badge(props: NameTagProps, x: number, y: number): React.ReactElement
	local config, sizes, color = props.config, props.sizes, props.color
	local across = 2 * sizes.badge
	local pivot = config.UI.nameTag.call.wavePivot * sizes.glove
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = Style.CENTRE,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(across, across),
		}),
		{
			Ripple = React.createElement(
				"Frame",
				Style.holder({
					AnchorPoint = Style.CENTRE,
					Position = Style.MIDDLE,
					Size = props.call.ring,
					ZIndex = 1,
				}),
				{
					Corner = Style.round(),
					Stroke = React.createElement("UIStroke", {
						Color = color,
						Thickness = sizes.rippleLine,
						Transparency = props.call.fade,
					}),
				}
			),
			Disc = React.createElement("Frame", {
				Size = Style.FULL,
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				Corner = Style.round(),
				Rim = React.createElement("UIStroke", { Color = config.UI.hud.look.ink, Thickness = sizes.rim }),
			}),
			Glove = React.createElement(
				"Frame",
				Style.holder({
					AnchorPoint = Style.CENTRE,
					Position = UDim2.new(0.5, 0, 0.5, math.round(sizes.gloveDrop + pivot)),
					Size = Style.FULL,
					Rotation = props.call.turn,
					ZIndex = 3,
				}),
				gloveBars(config, sizes)
			),
		}
	)
end

-- A mark on the cap's line, `width` wide, its top-left at (left, top) in the tag on whole pixels as a UDim's Offset
-- cuts them (#363: a cap's sweep halves meet on its middle): `face` over a pointer in `color` under its middle, half
-- under it.
local function pointed(
	props: NameTagProps,
	left: number,
	top: number,
	width: number,
	color: Color3,
	face: Style.Children
): React.ReactElement
	local config, sizes = props.config, props.sizes
	local side = math.round(sizes.pointer * POINTER_SIDE)
	local parts: Style.Children = {
		Pointer = React.createElement("Frame", {
			AnchorPoint = Style.CENTRE,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(side, side),
			Rotation = POINTER_TURN,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, { Ink = Style.inked(config) }),
	}
	for name, part in face do
		parts[name] = part
	end
	return React.createElement(
		"Frame",
		Style.holder({ Position = UDim2.fromOffset(left, top), Size = UDim2.fromOffset(width, sizes.cap.height) }),
		parts
	)
end

-- The pass key `key` at (left, top), its pointer in the cap's yellow.
local function passKey(props: NameTagProps, key: Style.KeyView, left: number, top: number): React.ReactElement
	local config, cap = props.config, props.sizes.cap
	local name, drawn = Style.keyCap(config, key, cap, 1, Style.stillCap)
	local held: Style.Children = { [name] = drawn }
	return pointed(props, left, top, Style.capWidth(config, key, cap), config.UI.hud.look.key, {
		Cap = React.createElement("Frame", Style.holder({ Size = Style.FULL, ZIndex = 2 }), held),
	})
end

-- Where the Attach mark's word starts: after its key's cap and inked edge, a gamepad's glyph, or nothing on touch,
-- then the cap's padding.
local function wordLeft(props: NameTagProps, key: Style.KeyView?): number
	local config, cap = props.config, props.sizes.cap
	if key == nil then
		return cap.padding
	end
	local edge = if key.image ~= nil then 0 else math.ceil(config.UI.hud.look.textOutline)
	return Style.capWidth(config, key, cap) + edge + cap.padding
end

-- How wide the Attach mark is: its word, measured, with the cap's padding after it.
local function attachWidth(props: NameTagProps, key: Style.KeyView?): number
	local config, cap = props.config, props.sizes.cap
	return wordLeft(props, key) + Style.textWidth(config, config.UI.controlLabels.Attach, cap.textSize) + cap.padding
end

-- A lettered Attach key at the box's left (the design page's Look 1): the key's yellow, round on the left as the box
-- is, square on the right, where its edge is inked; its name in ink.
local function letteredKey(config: Config.GameConfig, cap: Config.CapSizes, key: Style.KeyView): Style.Children
	local look = config.UI.hud.look
	local width = Style.capWidth(config, key, cap)
	return {
		Key = React.createElement("Frame", {
			Size = UDim2.new(0, width, 1, 0),
			BackgroundColor3 = look.key,
			BorderSizePixel = 0,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = cap.corner }),
			Square = React.createElement("Frame", {
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(0.5, 1),
				BackgroundColor3 = look.key,
				BorderSizePixel = 0,
			}),
			-- Over the square half.
			Legend = React.createElement(
				"TextLabel",
				Style.lettering(config, {
					Size = Style.FULL,
					Text = key.text or "",
					TextColor3 = look.ink,
					TextSize = cap.textSize,
					ZIndex = 2,
				})
			),
		}),
		Edge = React.createElement("Frame", {
			Position = UDim2.fromOffset(width, 0),
			Size = UDim2.new(0, math.ceil(look.textOutline), 1, 0),
			BackgroundColor3 = look.ink,
			BorderSizePixel = 0,
		}),
	}
end

-- The Attach mark (#381, the owner's Q246, Q247 Look 1, as the design page drew it) at (left, top), `width` wide: a
-- dark box as tall as the pass key's cap, in the touch buttons' fill, rounded and outlined in ink as the cap is; on
-- its left the Attach key as the hints show it (a lettered key, or a gamepad's glyph on the box, as Style.keyCap draws
-- one on no cap); then the word, white in look C's ink. On touch, which has no key, the word alone. Its pointer takes
-- the box's colour where they meet, as the pass key's takes its cap's.
local function attachMark(
	props: NameTagProps,
	key: Style.KeyView?,
	left: number,
	top: number,
	width: number
): React.ReactElement
	local config, cap = props.config, props.sizes.cap
	local fill = config.UI.touchStyle.fill
	local word = config.UI.controlLabels.Attach
	local parts: Style.Children = {}
	if key ~= nil and key.image ~= nil then
		local name, glyph = Style.keyCap(config, key, cap, 1, Style.stillCap)
		parts[name] = glyph
	elseif key ~= nil then
		parts = letteredKey(config, cap, key)
	end
	parts.Corner = React.createElement("UICorner", { CornerRadius = cap.corner })
	parts.Outline = Style.inked(config)
	parts.Shade = Style.shading(config, fill, 0, 1)
	parts.Word = React.createElement(
		"TextLabel",
		Style.lettering(config, {
			Position = UDim2.fromOffset(wordLeft(props, key), 0),
			Size = UDim2.new(0, Style.textWidth(config, word, cap.textSize), 1, 0),
			Text = word,
			TextSize = cap.textSize,
		}),
		{ Ink = Style.inked(config) }
	)
	return pointed(props, left, top, width, fill.bottom, {
		Box = React.createElement(
			"Frame",
			{ Size = Style.FULL, BackgroundColor3 = Style.WHITE, BorderSizePixel = 0, ZIndex = 2 },
			parts
		),
	})
end

-- Each mark's left edge on the row, `widths` in the row's order (0 for one not shown): those shown badgeGap apart, the
-- row on the tag's middle.
local function lay(sizes: Config.TagSizes, widths: { number }): { number }
	local gap = sizes.badgeGap
	-- Each mark shown and the gap after it, the last one's gap past the row's end.
	local across = 0
	for _, width in widths do
		if width > 0 then
			across += width + gap
		end
	end
	local left = (sizes.width - across + gap) / 2
	local lefts = table.create(#widths, 0)
	for index, width in widths do
		lefts[index] = left
		if width > 0 then
			left += width + gap
		end
	end
	return lefts
end

local function NameTag(props: NameTagProps): React.ReactElement
	local config, sizes = props.config, props.sizes
	local key, attachKey = props.passKey, props.attachKey
	local calling, attaching = props.calling, props.attaching
	local cap = sizes.cap
	-- The line the marks sit on: above the tag's middle, the pill's top half and ink, the gap, the pointer and half
	-- the cap.
	local line = sizes.height / 2
		- (sizes.pillHeight / 2 + config.UI.hud.look.outline + sizes.gap + sizes.pointer + cap.height / 2)
	local top = line - cap.height / 2
	-- The badge in its rim, the pass key, the Attach mark.
	local ringed = sizes.badge + sizes.rim
	local attachAcross = if attaching then attachWidth(props, attachKey) else 0
	local lefts = lay(sizes, {
		if calling then 2 * ringed else 0,
		if key ~= nil then Style.capWidth(config, key, cap) else 0,
		attachAcross,
	})
	return React.createElement(React.Fragment, nil, {
		Pill = pill(props),
		Badge = if calling then badge(props, lefts[1] + ringed, line) else nil,
		PassKey = if key ~= nil then passKey(props, key, lefts[2], top) else nil,
		Attach = if attaching then attachMark(props, attachKey, lefts[3], top, attachAcross) else nil,
	})
end

return NameTag
