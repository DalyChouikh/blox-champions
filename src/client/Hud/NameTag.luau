--!strict
-- A name tag's drawing (spec §11.1; #358; the owner's Q197 M1 Stacked, Q198 H4 Badge + ripple, Q240-Q241's E2 glove),
-- in look C, rendered into its BillboardGui by NameTags. On the tag's middle the name, in a pill of the team's HUD
-- colour. On one line above it: while they are a pass's target (#315), the pass key on look C's cap with a pointer
-- under it; while they call, the badge, a disc in the team's colour with an ink rim, a ring rippling out behind it and
-- the white glove waving in it, left of the key or alone over the name. A plain function of its props; the call moves
-- through bindings every calling tag shares.

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
	-- The team's HUD colour (Style.teamColor).
	color: Color3,
	-- The pass key while they are a pass's target; nil otherwise. (`key` is React's own prop: it never reaches here.)
	passKey: Style.KeyView?,
	calling: boolean,
	call: CallBindings,
}

-- A pointer is a square turned this far, half of it under the key's cap.
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

-- The pass key `key` with its top-left at (left, top) in the tag, on whole pixels as a UDim's Offset cuts them (#363: a
-- cap's sweep halves meet on its middle), its pointer below the cap, half under it.
local function passKey(props: NameTagProps, key: Style.KeyView, left: number, top: number): React.ReactElement
	local config, sizes = props.config, props.sizes
	local look = config.UI.hud.look
	local name, cap = Style.keyCap(config, key, sizes.cap, 1, Style.stillCap)
	local held: Style.Children = { [name] = cap }
	local side = math.round(sizes.pointer * POINTER_SIDE)
	return React.createElement(
		"Frame",
		Style.holder({
			Position = UDim2.fromOffset(left, top),
			Size = UDim2.fromOffset(Style.capWidth(config, key, sizes.cap), sizes.cap.height),
		}),
		{
			Pointer = React.createElement("Frame", {
				AnchorPoint = Style.CENTRE,
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromOffset(side, side),
				Rotation = POINTER_TURN,
				BackgroundColor3 = look.key,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, { Ink = Style.inked(config) }),
			Cap = React.createElement("Frame", Style.holder({ Size = Style.FULL, ZIndex = 2 }), held),
		}
	)
end

local function NameTag(props: NameTagProps): React.ReactElement
	local config, sizes, key = props.config, props.sizes, props.passKey
	local calling = props.calling
	local cap = sizes.cap
	-- The line the key and the badge sit on: above the tag's middle, the pill's top half and ink, the gap, the pointer
	-- and half the cap.
	local line = sizes.height / 2
		- (sizes.pillHeight / 2 + config.UI.hud.look.outline + sizes.gap + sizes.pointer + cap.height / 2)
	-- The badge in its rim, then the key, badgeGap apart while both show, the pair on the tag's middle.
	local ringed = sizes.badge + sizes.rim
	local keyWidth = if key ~= nil then Style.capWidth(config, key, cap) else 0
	local badgeWidth = if calling then 2 * ringed else 0
	local gap = if calling and key ~= nil then sizes.badgeGap else 0
	local left = (sizes.width - badgeWidth - gap - keyWidth) / 2
	return React.createElement(React.Fragment, nil, {
		Pill = pill(props),
		Badge = if calling then badge(props, left + ringed, line) else nil,
		PassKey = if key ~= nil then passKey(props, key, left + badgeWidth + gap, line - cap.height / 2) else nil,
	})
end

return NameTag
