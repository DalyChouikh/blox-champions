--!strict
-- The scoreboard (spec §11.1), at the top of the screen:
-- - both scores, each with a pip per point to win, filled for each point scored;
-- - the clock between them, a binding, so it counts without a render; OVERTIME under it in overtime;
-- - the carrier's name in their team's colour, hidden while the ball is loose;
-- - the lap bar of the team with the ball: a segment per gate, filled for each gate crossed this lap, labelled with the
--   lap or the streak (HudText:lap), and glowing while the goal is open for that team.
-- A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local MatchEngine = require(ReplicatedStorage.Shared.Rules.MatchEngine)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type Team = Team.Team
type Children = { [string]: React.Node }
type Scores = { [Team]: number }

export type ScoreboardProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	match: MatchEngine.Snapshot,
	names: { [Types.PlayerId]: string },
	-- Who carries the ball, nil while it is loose.
	carrier: Types.PlayerId?,
	clock: React.Binding<string>,
}

-- `count` marks in a row, `size` each, the first `full` filled in `color` and the rest faded: pips or lap segments.
local function marks(config: Config.GameConfig, count: number, full: number, color: Color3, size: UDim2): Children
	local children: Children = { Layout = Style.list(config, Enum.FillDirection.Horizontal) }
	for index = 1, count do
		children[tostring(index)] = React.createElement("Frame", {
			LayoutOrder = index,
			Size = size,
			BackgroundColor3 = color,
			BackgroundTransparency = if index <= full then 0 else config.UI.hud.dimTransparency,
			BorderSizePixel = 0,
		})
	end
	return children
end

-- A team's score in its colour, as tall as the row.
local function score(config: Config.GameConfig, team: Team, scores: Scores, order: number): React.ReactElement
	return React.createElement(
		"TextLabel",
		Style.text(config, {
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			Text = tostring(scores[team]),
			TextSize = config.UI.hud.titleSize,
			TextColor3 = config.UI.teamColors[team],
		})
	)
end

-- A pip per point to win, one filled for each of the team's points.
local function pips(config: Config.GameConfig, team: Team, scores: Scores, order: number): React.ReactElement
	local side = config.UI.hud.pipSize
	return React.createElement(
		"Frame",
		Style.holder({ LayoutOrder = order, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, side) }),
		marks(config, config.Match.pointsToWin, scores[team], config.UI.teamColors[team], UDim2.fromOffset(side, side))
	)
end

-- The lap bar of `team`, the team with the ball (nil while neutral, when it hides).
local function lapBar(props: ScoreboardProps, team: Team?, order: number): React.ReactElement
	local config, match = props.config, props.match
	local hud = config.UI.hud
	local color = if team ~= nil then config.UI.teamColors[team] else hud.textColor
	local count = match.gateCount
	-- Segments fill the bar's width exactly, spacing apart.
	local segment = UDim2.new(1 / count, -hud.spacing * (count - 1) / count, 1, 0)
	return React.createElement(
		"Frame",
		Style.holder({
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),
			Visible = team ~= nil,
		}),
		{
			Layout = Style.list(config, Enum.FillDirection.Vertical),
			Glow = React.createElement("UIStroke", {
				Thickness = hud.glowThickness,
				Color = color,
				Enabled = team ~= nil and match.goalOpenFor == team,
			}),
			Segments = React.createElement(
				"Frame",
				Style.holder({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, hud.pipSize) }),
				marks(config, count, match.lapProgress, color, segment)
			),
			LapLabel = React.createElement(
				"TextLabel",
				Style.text(config, {
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, hud.textSize),
					Text = props.text:lap(match) or "",
				})
			),
		}
	)
end

local function Scoreboard(props: ScoreboardProps): React.ReactElement
	local config, match, carrier = props.config, props.match, props.carrier
	local ui = config.UI
	local hud = ui.hud
	local place = hud.layout.scoreboard
	local carrierTeam = if carrier ~= nil then HudState.teamOf(match, carrier) else nil
	local line = UDim2.new(1, 0, 0, hud.textSize)
	return React.createElement(
		"Frame",
		Style.panel(config, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = place.position,
			Size = place.size,
			AutomaticSize = Enum.AutomaticSize.Y,
		}),
		{
			Corner = Style.corner(config),
			Padding = Style.padding(config),
			Layout = Style.list(config, Enum.FillDirection.Vertical),
			Score = React.createElement(
				"Frame",
				Style.holder({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, hud.titleSize) }),
				{
					Layout = Style.list(config, Enum.FillDirection.Horizontal),
					BlueScore = score(config, "Blue", match.scores, 1),
					BluePips = pips(config, "Blue", match.scores, 2),
					Clock = React.createElement(
						"TextLabel",
						Style.text(config, {
							LayoutOrder = 3,
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.fromScale(0, 1),
							Text = props.clock,
							TextSize = hud.titleSize,
						})
					),
					OrangePips = pips(config, "Orange", match.scores, 4),
					OrangeScore = score(config, "Orange", match.scores, 5),
				}
			),
			Period = React.createElement(
				"TextLabel",
				Style.text(config, {
					LayoutOrder = 2,
					Size = line,
					Text = ui.text.overtime,
					Visible = match.period == "Overtime",
				})
			),
			Carrier = React.createElement(
				"TextLabel",
				Style.text(config, {
					LayoutOrder = 3,
					Size = line,
					Text = if carrier ~= nil then props.text:name(carrier, props.names) else "",
					TextColor3 = if carrierTeam ~= nil then ui.teamColors[carrierTeam] else hud.textColor,
					Visible = carrier ~= nil,
				})
			),
			LapBar = lapBar(props, match.possessingTeam, 4),
		}
	)
end

return Scoreboard
