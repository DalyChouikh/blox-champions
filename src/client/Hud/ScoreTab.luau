--!strict
-- The score tab (spec §6.4, §11.1), in the middle of the HUD's stage while its key is held (or its touch button toggled
-- on), solid: every player still in the match (a leaver's row goes at once, #309), by team, then score (StatsTable).
-- It draws over the end screen, which it opens over on touch (Style.above). It shrinks to fit a small screen, as tall
-- as its rows make it. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local StatsTable = require(script.Parent.StatsTable)
local Style = require(script.Parent.Style)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

export type ScoreTabProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	stats: Types.MatchStats,
	names: { [Types.PlayerId]: string },
	localId: Types.PlayerId,
	-- The HUD's stage, which the tab fits in.
	area: React.Binding<Vector2>,
}

local function ScoreTab(props: ScoreTabProps): React.ReactElement
	local config = props.config
	local place = config.UI.hud.layout.scoreTab
	return React.createElement(
		"Frame",
		-- Above the end screen.
		Style.overlay(
			config,
			Style.above({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = place.position,
				Size = place.size,
				AutomaticSize = Enum.AutomaticSize.Y,
			})
		),
		{
			Corner = Style.corner(config),
			Padding = Style.padding(config),
			Fit = Style.fit(config, props.area, place.size, StatsTable.height(config, #props.stats.players)),
			Table = React.createElement(StatsTable.Table, {
				config = config,
				text = props.text,
				players = props.stats.players,
				names = props.names,
				localId = props.localId,
				order = 1,
			}),
		}
	)
end

return ScoreTab
