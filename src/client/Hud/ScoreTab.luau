--!strict
-- The score tab (spec §6.4, §11.1), in the middle of the HUD's stage while its key is held (or its touch button toggled
-- on), solid: every player still in the match (a leaver's row goes at once, #309), by team, then score (StatsTable).
-- It draws over the end screen, which it opens over on touch (Style.above). It shrinks to fit a small screen, as tall
-- as its rows make it. Under the table, where the mode offers it, a Switch team button (#310): its key (T, or D-pad
-- Up, while the tab is open) or a tap on touch asks the server for a switch; greyed while one can't happen (the owner,
-- Q117, Q118). A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local StatsTable = require(script.Parent.StatsTable)
local Style = require(script.Parent.Style)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

export type SwitchTeam = {
	-- Whether a switch works now; greyed while it doesn't (Q118).
	open: boolean,
	-- Its key on this device (Q117); none on touch, where it is tapped.
	key: Style.KeyView?,
	onActivated: () -> (),
}

export type ScoreTabProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	stats: Types.MatchStats,
	names: { [Types.PlayerId]: string },
	localId: Types.PlayerId,
	-- The HUD's stage, which the tab fits in.
	area: React.Binding<Vector2>,
	-- The Switch team button; nil where the tab has none.
	switchTeam: SwitchTeam?,
}

-- The Switch team button, a row as tall as the table's, at `order` under it: its key, then its label.
local function switchTeamButton(config: Config.GameConfig, switchTeam: SwitchTeam, order: number): React.ReactElement
	local hud = config.UI.hud
	local height = hud.layout.scoreTab.rowHeight
	local fade = if switchTeam.open then 0 else hud.dimTransparency
	local children: { [string]: React.Node } = {
		Layout = Style.list(config, Enum.FillDirection.Horizontal),
		Label = Style.label(config, config.UI.text.switchTeam, 2, fade),
	}
	local view = switchTeam.key
	if view ~= nil then
		local name, key = Style.key(config, view, height, 1, fade)
		children[name] = key
	end
	return React.createElement(
		"TextButton",
		Style.holder({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, height),
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			[React.Event.Activated] = switchTeam.onActivated,
		}),
		children
	)
end

local function ScoreTab(props: ScoreTabProps): React.ReactElement
	local config = props.config
	local hud = config.UI.hud
	local place = hud.layout.scoreTab
	local switchTeam = props.switchTeam
	local content = StatsTable.height(config, #props.stats.players)
		+ if switchTeam ~= nil then hud.spacing + place.rowHeight else 0
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
			Layout = Style.list(
				config,
				Enum.FillDirection.Vertical,
				{ VerticalAlignment = Enum.VerticalAlignment.Top }
			),
			Fit = Style.fit(config, props.area, place.size, content),
			Table = React.createElement(StatsTable.Table, {
				config = config,
				text = props.text,
				players = props.stats.players,
				names = props.names,
				localId = props.localId,
				order = 1,
			}),
			SwitchTeam = if switchTeam ~= nil then switchTeamButton(config, switchTeam, 2) else nil,
		}
	)
end

return ScoreTab
