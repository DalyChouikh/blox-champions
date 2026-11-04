--!strict
-- The event feed (spec §11.1), over the goal message at the bottom of the screen (HudScreen.feedBottom; #356, the
-- owner's Q211): possession changes and points, the newest last, each line a look C chip (#369, the owner's Q221) with
-- the player's name in its team's colour, which alone says the team (Q226). Each chip is keyed by its entry's id, so a
-- chip stays while older ones leave. It centres in the HUD's stage (left of the touch buttons on touch), as wide as its
-- widest chip and as tall as its chips stand (HudScreen.feedHeight), and shrinks to fit the stage. A plain function of
-- its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

export type FeedProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	-- Oldest first.
	feed: { HudState.FeedEntry },
	names: { [Types.PlayerId]: string },
	-- A phone's screen (HudScreen.compact).
	compact: boolean,
	-- The HUD's stage, which the feed fits in.
	area: React.Binding<Vector2>,
}

-- `entry`'s chip, `width` pixels wide: a look C box in look.box with its words.
local function chip(
	props: FeedProps,
	sizes: Config.FeedSizes,
	entry: HudState.FeedEntry,
	width: number
): React.ReactElement
	local config = props.config
	local place = { LayoutOrder = entry.id, Size = UDim2.fromOffset(width, sizes.height) }
	return Style.box(config, place, config.UI.hud.look.box, {
		Label = React.createElement(
			"TextLabel",
			Style.lettering(config, {
				Size = Style.FULL,
				RichText = true,
				Text = props.text:feedMarked(entry, props.names, Style.teamColor(config, entry.team)),
				TextSize = sizes.textSize,
			}),
			{ Ink = Style.inked(config) }
		),
	}, { { top = 0, height = 1, corner = sizes.corner } })
end

local function Feed(props: FeedProps): React.ReactElement
	local config, compact = props.config, props.compact
	local look = config.UI.hud.look
	local sizes = HudScreen.feedSizes(config, compact)
	local outline, drop = look.outline, look.shadow
	-- Lines sit one over another, a chip's ink and the clearance apart, the newest at the bottom; the frame holds the
	-- ink, so it fits the stage whole.
	local lines: Style.Children = {
		Layout = Style.list(config, Enum.FillDirection.Vertical, {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, config.UI.hud.layout.feed.clearance + 2 * outline + drop),
		}),
		Inset = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, outline),
			PaddingBottom = UDim.new(0, outline + drop),
		}),
	}
	local widest = 0
	for _, entry in props.feed do
		-- Measured without the name's mark, which draws nothing of its own.
		local words = props.text:feed(entry, props.names)
		local width = Style.textWidth(config, words, sizes.textSize) + 2 * sizes.inset
		widest = math.max(widest, width)
		lines[tostring(entry.id)] = chip(props, sizes, entry, width)
	end
	local box = UDim2.fromOffset(widest + 2 * outline, HudScreen.feedHeight(config, compact, #props.feed))
	lines.Fit = Style.fit(config, props.area, box)
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -HudScreen.feedBottom(config, compact)),
			Size = box,
		}),
		lines
	)
end

return Feed
