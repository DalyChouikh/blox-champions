--!strict
-- The score tab (spec §6.4, §11.1), in the middle of the screen while its key is held (or its touch button toggled
-- on): every player who played this match, by team, then score (StatsTable). It shrinks to fit a small screen. A
-- plain function of its props.

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
	-- The HUD's area, which the tab fits in.
	area: React.Binding<Vector2>,
}

local function ScoreTab(props: ScoreTabProps): React.ReactElement
	local config = props.config
	local place = config.UI.hud.layout.scoreTab
	return React.createElement(
		"Frame",
		Style.panel(config, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = place.position,
			Size = place.size,
			AutomaticSize = Enum.AutomaticSize.Y,
		}),
		{
			Corner = Style.corner(config),
			Padding = Style.padding(config),
			Fit = Style.fit(config, props.area, place.size),
			Table = React.createElement(StatsTable, {
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
