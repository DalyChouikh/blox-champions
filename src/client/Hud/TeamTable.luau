--!strict
-- The TAB board's table (spec §6.4, §11.1; #357, the owner's Q236, Q237), drawn by the board (Hud/ScoreTab) and the end
-- screen (Hud/EndScreen, #358, Q243): look C's box in look.box, clipped to its corners, holding a header of the
-- columns' names (UI.text.columns) over each team's bar in its HUD colour, with its name and score, the viewer's team
-- first (a spectator's in the teams' own order), and its rows by score as the server sends them: an avatar circle
-- (HudText.avatar), the name, score, goals, assists, saves and steals, the viewer's row outlined in look.key. Its teams
-- show `shown` pixels tall and scroll the rest. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local Types = require(ReplicatedStorage.Shared.Rules.Types)
local UI = require(ReplicatedStorage.Shared.Config.UI)

export type TeamTableProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	stats: Types.MatchStats,
	names: { [Types.PlayerId]: string },
	localId: Types.PlayerId,
	-- A phone's screen (HudScreen.compact): the compact sizes.
	compact: boolean,
	-- Where its box sits in its parent, and how tall its teams show (the rest scrolls).
	position: UDim2,
	shown: React.Binding<number>,
}

-- The number columns' cells, in order, after the avatar's and the name's.
local NUMBERS = { "Score", "Goals", "Assists", "Saves", "Steals" }

-- A row's cells, `side` in from the box's edges and `gap` apart: the avatar's slot (holding `avatar`; the header's is
-- empty), the name (`texts[1]`), then the numbers, all at `size` in look C's lettering, inked but for the header's.
local function cells(
	config: Config.GameConfig,
	sizes: Config.TabSizes,
	texts: { string },
	size: number,
	inked: boolean,
	avatar: React.ReactElement?
): React.ReactElement
	local look = config.UI.hud.look
	local function label(order: number, words: string, width: UDim, align: Enum.TextXAlignment): React.ReactElement
		return React.createElement(
			"TextLabel",
			Style.lettering(config, {
				LayoutOrder = order,
				Size = UDim2.new(width, UDim.new(1, 0)),
				Text = words,
				TextSize = size,
				TextXAlignment = align,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			if inked then { Ink = Style.inked(config) } else nil
		)
	end
	local side = UDim.new(0, sizes.side)
	local slot = UI.tabAvatarSlot(sizes, look.textOutline)
	local others = UI.tabCellsWidth(sizes, look.textOutline, #NUMBERS)
	local children: Style.Children = {
		Layout = Style.list(config, Enum.FillDirection.Horizontal, { Padding = UDim.new(0, sizes.gap) }),
		Padding = React.createElement("UIPadding", { PaddingLeft = side, PaddingRight = side }),
		Avatar = React.createElement(
			"Frame",
			Style.holder({ LayoutOrder = 1, Size = UDim2.new(0, slot, 1, 0) }),
			{ Disc = avatar }
		),
		Name = label(2, texts[1], UDim.new(1, -others), Enum.TextXAlignment.Left),
	}
	for index, column in NUMBERS do
		children[column] = label(2 + index, texts[1 + index], UDim.new(0, sizes.column), Enum.TextXAlignment.Center)
	end
	return React.createElement("Frame", Style.holder({ Size = Style.FULL }), children)
end

-- `stats`' row at `order`, outlined inside its edge in look.key when it is the viewer's.
local function row(
	props: TeamTableProps,
	sizes: Config.TabSizes,
	stats: Types.PlayerStats,
	order: number
): React.ReactElement
	local config, text = props.config, props.text
	local look = config.UI.hud.look
	local line = look.outline
	local texts = {
		text:name(stats.player, props.names),
		tostring(stats.score),
		tostring(stats.goals),
		tostring(stats.assists),
		tostring(stats.saves),
		tostring(stats.steals),
	}
	return React.createElement(
		"Frame",
		Style.holder({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, sizes.rowHeight) }),
		{
			Cells = cells(
				config,
				sizes,
				texts,
				sizes.textSize,
				true,
				Style.avatar(config, sizes.avatar, text:avatar(stats.player))
			),
			You = if stats.player == props.localId
				then React.createElement(
					"Frame",
					Style.holder({
						Position = UDim2.fromOffset(line, line),
						Size = UDim2.new(1, -2 * line, 1, -2 * line),
					}),
					{
						Corner = Style.corner(config),
						Stroke = React.createElement("UIStroke", { Color = look.key, Thickness = line }),
					}
				)
				else nil,
		}
	)
end

-- `team`'s bar at `order`: its HUD colour over an ink line, its name at the left and its score at the right.
local function bar(props: TeamTableProps, sizes: Config.TabSizes, team: Team.Team, order: number): React.ReactElement
	local config = props.config
	local look = config.UI.hud.look
	local line = look.outline
	local side = UDim.new(0, sizes.side)
	local function label(words: string, align: Enum.TextXAlignment): React.ReactElement
		return React.createElement(
			"TextLabel",
			Style.lettering(
				config,
				{ Size = Style.FULL, Text = words, TextSize = sizes.barSize, TextXAlignment = align }
			),
			{ Ink = Style.inked(config) }
		)
	end
	return React.createElement(
		"Frame",
		Style.holder({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, sizes.barHeight) }),
		{
			Fill = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 1, -line),
				BackgroundColor3 = Style.teamColor(config, team),
				BorderSizePixel = 0,
			}, {
				Padding = React.createElement("UIPadding", { PaddingLeft = side, PaddingRight = side }),
				Name = label(props.text:teamBar(team), Enum.TextXAlignment.Left),
				Score = label(tostring(props.stats.scores[team]), Enum.TextXAlignment.Right),
			}),
			Line = React.createElement("Frame", {
				Position = UDim2.new(0, 0, 1, -line),
				Size = UDim2.new(1, 0, 0, line),
				BackgroundColor3 = look.ink,
				BorderSizePixel = 0,
			}),
		}
	)
end

-- The teams in the board's order: the viewer's first, else the teams' own.
local function teamOrder(props: TeamTableProps): { Team.Team }
	for _, stats in props.stats.players do
		if stats.player == props.localId then
			return { stats.team, Team.opponent(stats.team) }
		end
	end
	return Team.list
end

-- The header's cells: the columns' names (UI.text.columns) at headSize, over the avatars' column.
local function header(props: TeamTableProps, sizes: Config.TabSizes): React.ReactElement
	local columns = props.config.UI.text.columns
	local names = { columns.player, columns.score, columns.goals, columns.assists, columns.saves, columns.steals }
	return cells(props.config, sizes, names, sizes.headSize, false, nil)
end

-- Each team's bar and rows, one under another.
local function teams(props: TeamTableProps, sizes: Config.TabSizes): Style.Children
	local children: Style.Children = {
		Layout = Style.list(props.config, Enum.FillDirection.Vertical, {
			Padding = UDim.new(0, 0),
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
	}
	local order = 0
	for _, team: Team.Team in teamOrder(props) do
		order += 1
		children[team] = bar(props, sizes, team, order)
		for _, stats in props.stats.players do
			if stats.team == team then
				order += 1
				children[stats.player] = row(props, sizes, stats, order)
			end
		end
	end
	return children
end

local function TeamTable(props: TeamTableProps): React.ReactElement
	local config = props.config
	local hud = config.UI.hud
	local look = hud.look
	local compact, rows = props.compact, props.shown
	local sizes = HudScreen.tabSizes(config, compact)
	local players = #props.stats.players
	return Style.box(
		config,
		{
			Position = props.position,
			Size = rows:map(function(teamsShown: number): UDim2
				return UDim2.fromOffset(sizes.width, sizes.headHeight + teamsShown)
			end),
		},
		look.box,
		{
			-- Clipped to the box's corners: a team's bar at the bottom would square them off.
			Clip = React.createElement("CanvasGroup", Style.holder({ Size = Style.FULL }), {
				Corner = React.createElement("UICorner", { CornerRadius = look.corner }),
				Header = React.createElement(
					"Frame",
					Style.holder({ Size = UDim2.new(1, 0, 0, sizes.headHeight) }),
					{ Cells = header(props, sizes) }
				),
				Teams = React.createElement("ScrollingFrame", {
					Position = UDim2.fromOffset(0, sizes.headHeight),
					Size = rows:map(function(teamsShown: number): UDim2
						return UDim2.new(1, 0, 0, teamsShown)
					end),
					CanvasSize = UDim2.new(1, 0, 0, HudScreen.tabBody(config, compact, players)),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ScrollBarThickness = hud.layout.scoreTab.scrollBar,
					ScrollBarImageColor3 = hud.textColor,
					Selectable = false,
				}, teams(props, sizes)),
			}),
		}
	)
end

return TeamTable
