--!strict
-- The event feed (spec §11.1), over the goal message at the bottom of the screen (HudScreen.feedBottom; #356, the
-- owner's Q211): possession changes and points, the newest at the bottom, each line a look C chip (#369, the owner's
-- Q221) with the player's name in its team's colour, which alone says the team (Q226). A chip pops in and fades out
-- whole, on its slot in BannerMotion (#373, the owner's Q227); a replaced ball line fades in the new one's row, beneath
-- it, taking no row of its own, so nothing moves. Each chip is keyed by its entry's id, so a chip stays while older
-- ones leave. The feed centres in the HUD's stage (left of the touch buttons on touch), as wide as its widest chip and
-- as tall as its rows stand (HudScreen.feedHeight), and shrinks to fit the stage. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BannerMotion = require(script.Parent.BannerMotion)
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
	-- How many rows they stand (HudState.feedLines).
	lines: number,
	-- Each entry's slot (BannerMotion.chips), by its id.
	chips: { [number]: BannerMotion.Slot },
	names: { [Types.PlayerId]: string },
	-- A phone's screen (HudScreen.compact).
	compact: boolean,
	-- The HUD's stage, which the feed fits in.
	area: React.Binding<Vector2>,
}

-- `entry`'s chip, `width` pixels wide, `row` rows up from the bottom: a look C box in look.box with its words, in a
-- group that holds its ink, so that it fades whole.
local function chip(
	props: FeedProps,
	sizes: Config.FeedSizes,
	entry: HudState.FeedEntry,
	width: number,
	row: number
): React.ReactElement
	local config = props.config
	local look = config.UI.hud.look
	local outline = look.outline
	local height = HudScreen.feedHeight(config, props.compact, 1)
	local slot = props.chips[entry.id]
	local rowsAbove = props.lines - 1 - row
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, rowsAbove * (height + config.UI.hud.layout.feed.clearance)),
			Size = UDim2.fromOffset(width + 2 * outline, height),
			-- A newer line draws over one fading in its row.
			ZIndex = entry.id,
		}),
		{
			Group = Style.fadeGroup(config, slot.leave, 0, {
				Pop = React.createElement("UIScale", { Scale = slot.scale.binding }),
				Chip = Style.box(
					config,
					{
						Position = UDim2.fromOffset(outline, outline),
						Size = UDim2.fromOffset(width, sizes.height),
					},
					look.box,
					{
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
					},
					{ { top = 0, height = 1, corner = sizes.corner } }
				),
			}),
		}
	)
end

local function Feed(props: FeedProps): React.ReactElement
	local config, compact, feed = props.config, props.compact, props.feed
	local sizes = HudScreen.feedSizes(config, compact)
	local lines: Style.Children = {}
	local widest = 0
	-- Newest first: rows count up from the bottom, and a replaced ball line takes the row of the live one after it.
	local row, ballRow = 0, 0
	for index = #feed, 1, -1 do
		local entry = feed[index]
		-- Measured without the name's mark, which draws nothing of its own.
		local words = props.text:feed(entry, props.names)
		local width = Style.textWidth(config, words, sizes.textSize) + 2 * sizes.inset
		widest = math.max(widest, width)
		if entry.replaced then
			lines[tostring(entry.id)] = chip(props, sizes, entry, width, ballRow)
		else
			lines[tostring(entry.id)] = chip(props, sizes, entry, width, row)
			if entry.kind == "Possession" then
				ballRow = row
			end
			row += 1
		end
	end
	local box =
		UDim2.fromOffset(widest + 2 * config.UI.hud.look.outline, HudScreen.feedHeight(config, compact, props.lines))
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
