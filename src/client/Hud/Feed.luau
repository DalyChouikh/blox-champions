--!strict
-- The event feed (spec §11.1), above the bottom of the screen: possession changes, laps, the goal opening and points,
-- the newest last, each line in its team's colour. Each line is keyed by its entry's id, so a line keeps its label
-- while older ones leave. It centres in the HUD's stage (left of the touch buttons on touch) and shrinks to fit it. A
-- plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
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
	-- The HUD's stage, which the feed fits in.
	area: React.Binding<Vector2>,
}

local function Feed(props: FeedProps): React.ReactElement
	local config = props.config
	local ui = config.UI
	local place = ui.hud.layout.feed
	local row = UDim2.new(1, 0, 0, place.rowHeight)
	-- Lines sit one under another with no gap (rowHeight spaces them), the newest at the bottom.
	local lines: { [string]: React.Node } = {
		Layout = Style.list(config, Enum.FillDirection.Vertical, {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(),
		}),
		Fit = Style.fit(config, props.area, place.size),
	}
	for _, entry in props.feed do
		lines[tostring(entry.id)] = React.createElement(
			"TextLabel",
			Style.text(config, {
				LayoutOrder = entry.id,
				Size = row,
				Text = props.text:feed(entry, props.names),
				TextColor3 = ui.teamColors[entry.team],
			})
		)
	end
	return React.createElement(
		"Frame",
		Style.holder({ AnchorPoint = Vector2.new(0.5, 1), Position = place.position, Size = place.size }),
		lines
	)
end

return Feed
