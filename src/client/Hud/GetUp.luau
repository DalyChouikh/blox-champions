--!strict
-- The Get Up prompt (#220), shown while the local skater is knocked down, in banner style (#369, the owner's Q221): the
-- movement keys as the device shows them on look C's bigger caps (Style.keyCap), then its words in the banners'
-- lettering (Style.letters), on no box, at the bottom centre like Roller Champions' prompt (the owner's recording,
-- Video 5 at 0:18), over the feed's lines where they reach it (HudScreen.getUpBottom). It pops in and fades out whole,
-- in one CanvasGroup (a Reveal's bindings). Moving asks the server to get the skater up, which it does from
-- Actions.getUpAfter: since #287 the whole slide (Q62), and the prompt stays as RC's does (the owner, #303, Q88). It
-- sits in the HUD's stage, so on touch it centres left of the buttons, and shrinks to fit it. A plain function of its
-- props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)

export type GetUpProps = {
	config: Config.GameConfig,
	-- In the order shown: a keyboard's up, left, down and right; a gamepad's stick; the touch stick's name.
	keys: { Style.KeyView },
	-- A phone's screen (HudScreen.compact).
	compact: boolean,
	-- How many lines the feed shows now.
	lines: number,
	-- Its pop (1 at rest) and how far it has faded out (0 to 1).
	scale: React.Binding<number>,
	leave: React.Binding<number>,
	-- The HUD's stage, which it fits in.
	area: React.Binding<Vector2>,
}

local function GetUp(props: GetUpProps): React.ReactElement
	local config, keys, compact = props.config, props.keys, props.compact
	local look = config.UI.hud.look
	local sizes = HudScreen.getUpSizes(config, compact)
	local cap, size = sizes.cap, sizes.textSize
	local words = config.UI.controlLabels.GetUp
	-- Whole pixels of room for the ink round the caps and the words: a UDim's offset drops a fraction.
	local ink = math.ceil(look.textOutline)
	local row = math.max(cap.height, size)
	local caps: Style.Children = {
		Layout = Style.list(config, Enum.FillDirection.Horizontal, { Padding = UDim.new(0, sizes.gap) }),
	}
	local across = (#keys - 1) * sizes.gap
	for order, view in keys do
		local name, key = Style.keyCap(config, view, cap, order, Style.stillCap)
		caps[`{name}{order}`] = key
		across += Style.capWidth(config, view, cap)
	end
	-- The banners' font draws its letters' middle above its line's: down by that, they sit on the caps' middle.
	local top = ink + (row - size) // 2 + math.round(size * look.bannerDigitRise)
	local parts = Style.letters(config, words, size, nil, 0, ink + across + sizes.wordsGap, top)
	parts.Keys = React.createElement(
		"Frame",
		Style.holder({
			Position = UDim2.fromOffset(ink, ink + (row - cap.height) // 2),
			Size = UDim2.fromOffset(across, cap.height),
		}),
		caps
	)
	parts.Pop = React.createElement("UIScale", { Scale = props.scale })
	local width = 2 * ink + across + sizes.wordsGap + Style.textWidth(config, words, size, look.bannerFont)
	local box = UDim2.fromOffset(width, 2 * ink + row + look.shadow)
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -HudScreen.getUpBottom(config, compact, props.lines)),
			Size = box,
		}),
		{
			Fit = Style.fit(config, props.area, box),
			Group = React.createElement(
				"CanvasGroup",
				Style.holder({
					AnchorPoint = Style.CENTRE,
					Position = Style.MIDDLE,
					Size = Style.FULL,
					GroupTransparency = props.leave,
				}),
				parts
			),
		}
	)
end

return GetUp
