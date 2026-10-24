--!strict
-- The end of the match (spec §6.5, §11.1), in the middle of the HUD's stage until the next match starts, solid: the
-- winner in their team's colour, both teams' totals, the MVP's card (their row of the score tab; hidden without an
-- MVP), and the whole score tab, one under another. Compact (on touch, the owner's choice) it leaves the score tab out,
-- which the touch score button opens over it, and is only as tall as the rest. It shrinks to fit a small screen, as
-- tall as its parts make it. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local StatsTable = require(script.Parent.StatsTable)
local Style = require(script.Parent.Style)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

export type EndScreenProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	ended: HudState.Ended,
	names: { [Types.PlayerId]: string },
	localId: Types.PlayerId,
	-- The HUD's stage, which the screen fits in.
	area: React.Binding<Vector2>,
	-- Without the whole score tab.
	compact: boolean,
}

-- A headline in `color`, as tall as the HUD's titles.
local function title(config: Config.GameConfig, order: number, text: string, color: Color3): React.ReactElement
	local hud = config.UI.hud
	return React.createElement(
		"TextLabel",
		Style.text(config, {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, hud.titleSize),
			Text = text,
			TextSize = hud.titleSize,
			TextColor3 = color,
		})
	)
end

-- A team's total in its colour.
local function total(config: Config.GameConfig, team: Team.Team, scores: { [Team.Team]: number }, order: number)
	local size = config.UI.hud.titleSize
	return React.createElement(
		"TextLabel",
		Style.text(config, {
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, size),
			Text = tostring(scores[team]),
			TextSize = size,
			TextColor3 = config.UI.teamColors[team],
		})
	)
end

-- How tall the screen's parts stack, a gap apart (Style.list): the winner and the totals (each a title high), the
-- MVP's title and card while there is an MVP, and the table of `players` unless compact.
local function contentHeight(config: Config.GameConfig, players: number, mvp: boolean, compact: boolean): number
	local hud = config.UI.hud
	local line = hud.titleSize + hud.spacing
	local height = 2 * line - hud.spacing
	if mvp then
		height += hud.spacing + line + StatsTable.height(config, 1)
	end
	if not compact then
		height += hud.spacing + StatsTable.height(config, players)
	end
	return height
end

local function EndScreen(props: EndScreenProps): React.ReactElement
	local config, text, ended = props.config, props.text, props.ended
	local ui = config.UI
	local place = ui.hud.layout.endScreen
	local stats = ended.stats
	local mvpStats: Types.PlayerStats? = nil
	for _, player in stats.players do
		if player.player == ended.mvp then
			mvpStats = player
		end
	end
	local compact = props.compact
	-- Compact, it is only as tall as its parts (AutomaticSize Y).
	local size = if compact then UDim2.fromOffset(place.size.X.Offset, 0) else place.size
	return React.createElement(
		"Frame",
		Style.overlay(config, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = place.position,
			Size = size,
			AutomaticSize = Enum.AutomaticSize.Y,
		}),
		{
			Corner = Style.corner(config),
			Padding = Style.padding(config),
			Fit = Style.fit(config, props.area, size, contentHeight(config, #stats.players, mvpStats ~= nil, compact)),
			Layout = Style.list(config, Enum.FillDirection.Vertical),
			Winner = title(config, 1, text:wins(ended.winner), ui.teamColors[ended.winner]),
			Totals = React.createElement(
				"Frame",
				Style.holder({ LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.XY }),
				{
					Layout = Style.list(config, Enum.FillDirection.Horizontal),
					BlueTotal = total(config, "Blue", stats.scores, 1),
					OrangeTotal = total(config, "Orange", stats.scores, 2),
				}
			),
			Mvp = React.createElement(
				"Frame",
				Style.holder({
					LayoutOrder = 3,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Visible = mvpStats ~= nil,
				}),
				{
					Layout = Style.list(config, Enum.FillDirection.Vertical),
					Title = title(config, 1, ui.text.mvp, ui.hud.textColor),
					Table = React.createElement(StatsTable.Table, {
						config = config,
						text = text,
						players = if mvpStats ~= nil then { mvpStats } else {},
						names = props.names,
						localId = props.localId,
						order = 2,
					}),
				}
			),
			Table = if compact
				then nil
				else React.createElement(StatsTable.Table, {
					config = config,
					text = text,
					players = stats.players,
					names = props.names,
					localId = props.localId,
					order = 4,
				}),
		}
	)
end

return EndScreen
