--!strict
-- A table of players' stats (spec §6.4): a header from Config.UI.text.columns, then a row per player in the order
-- given (the score tab's: by team, then score), keyed by their id: name, score, goals, assists, saves and steals, in
-- their team's colour. A player who left is faded (dimTransparency), and the local player's row is outlined. The
-- score tab and the end screen draw it. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

export type StatsTableProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	players: { Types.PlayerStats },
	names: { [Types.PlayerId]: string },
	localId: Types.PlayerId,
	-- Its place among its parent's parts.
	order: number,
}

-- Each column's cell name, in order; the first holds the name and takes the width the others leave.
local COLUMNS = { "Name", "Score", "Goals", "Assists", "Saves", "Steals" }

-- A row of `cells`, one per column, in `color`, faded by `fade`, outlined when `marked`.
local function row(
	config: Config.GameConfig,
	order: number,
	cells: { string },
	color: Color3,
	fade: number,
	marked: boolean
): React.ReactElement
	local hud = config.UI.hud
	local place = hud.layout.scoreTab
	local others = #COLUMNS - 1
	local children: { [string]: React.Node } = { Layout = Style.list(config, Enum.FillDirection.Horizontal) }
	for index, column in COLUMNS do
		local first = index == 1
		children[column] = React.createElement(
			"TextLabel",
			Style.text(config, {
				LayoutOrder = index,
				Size = if first
					then UDim2.new(1, -(place.columnWidth + hud.spacing) * others, 1, 0)
					else UDim2.new(0, place.columnWidth, 1, 0),
				Text = cells[index],
				TextColor3 = color,
				TextTransparency = fade,
				TextXAlignment = if first then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			})
		)
	end
	children.You = if marked
		then React.createElement("UIStroke", { Thickness = hud.glowThickness, Color = hud.textColor })
		else nil
	return React.createElement(
		"Frame",
		Style.holder({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, place.rowHeight) }),
		children
	)
end

local function StatsTable(props: StatsTableProps): React.ReactElement
	local config, text = props.config, props.text
	local ui = config.UI
	local columns = ui.text.columns
	local rows: { [string]: React.Node } = {
		Layout = Style.list(config, Enum.FillDirection.Vertical),
		Header = row(
			config,
			0,
			{ columns.player, columns.score, columns.goals, columns.assists, columns.saves, columns.steals },
			ui.hud.textColor,
			0,
			false
		),
	}
	for index, stats in props.players do
		rows[stats.player] = row(
			config,
			index,
			{
				text:name(stats.player, props.names),
				tostring(stats.score),
				tostring(stats.goals),
				tostring(stats.assists),
				tostring(stats.saves),
				tostring(stats.steals),
			},
			ui.teamColors[stats.team],
			if stats.present then 0 else ui.hud.dimTransparency,
			stats.player == props.localId
		)
	end
	return React.createElement(
		"Frame",
		Style.holder({ LayoutOrder = props.order, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y }),
		rows
	)
end

return StatsTable
