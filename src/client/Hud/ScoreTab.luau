--!strict
-- The TAB board (spec §6.4, §11.1; #357): one compact table on desktop and phones (the owner, Q236, Q237) of every
-- player still in the match (a leaver's row goes at once, #309). A header names the columns; then each team's bar in
-- its HUD colour, with its name and score, the viewer's team first (a spectator's in the teams' own order), and its
-- rows by score as the server sends them: an avatar circle (HudText.avatar), the name, score, goals, assists, saves and
-- steals, the viewer's row outlined in look.key; look C's box, lettering and ink (Q184), clipped to the box's corners
-- as the design page drew it. Under it, where the mode offers it, Switch team (#310): its key on look C's cap (none on
-- touch, where it is tapped), greyed whole while a switch can't happen (Q117, Q118). It fits the HUD's area under the
-- scoreboard's ink (HudScreen.tabTop, tabFit; Q203's rule), on touch under the SCORES button too, which stays above it
-- (Q234, Q236): off touch it shrinks to fit; on touch its teams scroll where they do not fit (Q190), and while open it
-- takes the touches over that area, so the touch buttons under it are not pressed (the HUD's gui draws over theirs). It
-- pops in and fades out whole (a Reveal's bindings, Q194), drawn above the HUD's stage. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local Types = require(ReplicatedStorage.Shared.Rules.Types)
local UI = require(ReplicatedStorage.Shared.Config.UI)

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
	-- A phone's screen (HudScreen.compact): the board's compact sizes.
	compact: boolean,
	-- Played by touch: under the SCORES button, its rows scrolling, taking the touches over its area while open.
	touch: boolean,
	-- Open, not only fading out after it closed.
	open: boolean,
	-- Its pop (1 at rest) and how far it has faded out, 0 to 1 (Reveal).
	scale: React.Binding<number>,
	leave: React.Binding<number>,
	-- The HUD's whole area, in pixels, and how far below its top the scoreboard's ink reaches (HudScreen.boardBottom
	-- less the HUD's top; 0 without a scoreboard).
	area: React.Binding<Vector2>,
	boardBottom: number,
	-- The Switch team button; nil where the board has none.
	switchTeam: SwitchTeam?,
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

-- `player`'s avatar: their headshot on a disc in the HUD's text colour, which shows alone for an id that is no Roblox
-- user's or while the headshot loads, ringed in look C's ink.
local function avatar(
	config: Config.GameConfig,
	sizes: Config.TabSizes,
	text: HudText.HudText,
	player: Types.PlayerId
): React.ReactElement
	local hud = config.UI.hud
	return React.createElement("ImageLabel", {
		AnchorPoint = Style.CENTRE,
		Position = Style.MIDDLE,
		Size = UDim2.fromOffset(sizes.avatar, sizes.avatar),
		BackgroundColor3 = hud.textColor,
		BorderSizePixel = 0,
		Image = text:avatar(player) or "",
	}, {
		Corner = Style.round(),
		Ink = React.createElement("UIStroke", { Color = hud.look.ink, Thickness = hud.look.textOutline }),
	})
end

-- `stats`' row at `order`, outlined inside its edge in look.key when it is the viewer's.
local function row(
	props: ScoreTabProps,
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
			Cells = cells(config, sizes, texts, sizes.textSize, true, avatar(config, sizes, text, stats.player)),
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
local function bar(props: ScoreTabProps, sizes: Config.TabSizes, team: Team.Team, order: number): React.ReactElement
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
local function teamOrder(props: ScoreTabProps): { Team.Team }
	for _, stats in props.stats.players do
		if stats.player == props.localId then
			return { stats.team, Team.opponent(stats.team) }
		end
	end
	return Team.list
end

-- The header's cells: the columns' names (UI.text.columns) at headSize, over the avatars' column.
local function header(props: ScoreTabProps, sizes: Config.TabSizes): React.ReactElement
	local columns = props.config.UI.text.columns
	local names = { columns.player, columns.score, columns.goals, columns.assists, columns.saves, columns.steals }
	return cells(props.config, sizes, names, sizes.headSize, false, nil)
end

-- Each team's bar and rows, one under another.
local function teams(props: ScoreTabProps, sizes: Config.TabSizes): Style.Children
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

-- Switch team at `position` under the box, `height` pixels tall: its key's cap (the hints' sizes, still), then its
-- words, centred, greyed whole while a switch can't happen.
local function switchButton(
	config: Config.GameConfig,
	sizes: Config.TabSizes,
	switchTeam: SwitchTeam,
	position: React.Binding<UDim2>,
	height: number
): React.ReactElement
	local words = config.UI.text.switchTeam
	local parts: Style.Children = {
		Layout = Style.list(config, Enum.FillDirection.Horizontal, { Padding = UDim.new(0, sizes.switchGap) }),
		Label = React.createElement(
			"TextLabel",
			Style.lettering(config, {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(Style.textWidth(config, words, sizes.switchSize), sizes.switchSize),
				Text = words,
				TextSize = sizes.switchSize,
			}),
			{ Ink = Style.inked(config) }
		),
	}
	local view = switchTeam.key
	if view ~= nil then
		local name, key = Style.keyCap(config, view, config.UI.hud.layout.hints.cap, 1, Style.stillCap)
		parts[name] = key
	end
	return React.createElement(
		"TextButton",
		Style.holder({
			Position = position,
			Size = UDim2.new(1, 0, 0, height),
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			[React.Event.Activated] = switchTeam.onActivated,
		}),
		{
			Row = React.createElement(
				"CanvasGroup",
				Style.holder({ Size = Style.FULL, GroupTransparency = Style.dim(config, not switchTeam.open) }),
				parts
			),
		}
	)
end

local function ScoreTab(props: ScoreTabProps): React.ReactElement
	local config = props.config
	local hud = config.UI.hud
	local look = hud.look
	local compact, touch, switchTeam = props.compact, props.touch, props.switchTeam
	local sizes = HudScreen.tabSizes(config, compact)
	local switchRow: HudScreen.SwitchRow? = if switchTeam == nil
		then nil
		elseif switchTeam.key ~= nil then "Key"
		else "Label"
	local switchHeight = HudScreen.tabSwitch(config, compact, switchRow)
	local players = #props.stats.players
	local line, shadow = look.outline, look.shadow
	local area, boardBottom = props.area, props.boardBottom
	-- Where its part of the HUD's area starts, and its scale and how tall its teams show there.
	local function topOf(shown: Vector2): number
		return HudScreen.tabTop(config, touch, shown.Y, boardBottom)
	end
	local function fitted(shown: Vector2): (number, number)
		local top = topOf(shown)
		return HudScreen.tabFit(config, compact, touch, Vector2.new(shown.X, shown.Y - top), players, switchRow)
	end
	local rows = area:map(function(shown: Vector2): number
		local _, teamsShown = fitted(shown)
		return teamsShown
	end)
	return React.createElement(
		"Frame",
		Style.topmost(Style.holder({
			Position = area:map(function(shown: Vector2): UDim2
				return UDim2.fromOffset(0, topOf(shown))
			end),
			Size = area:map(function(shown: Vector2): UDim2
				return UDim2.new(1, 0, 1, -topOf(shown))
			end),
			Active = touch and props.open,
		})),
		{
			Board = React.createElement(
				"Frame",
				Style.holder({
					AnchorPoint = Style.CENTRE,
					Position = Style.MIDDLE,
					Size = rows:map(function(teamsShown: number): UDim2
						return UDim2.fromOffset(
							sizes.width + 2 * line,
							2 * line + shadow + sizes.headHeight + teamsShown + switchHeight
						)
					end),
				}),
				{
					Fit = React.createElement("UIScale", {
						Scale = area:map(function(shown: Vector2): number
							local scale = fitted(shown)
							return scale
						end),
					}),
					Group = React.createElement(
						"CanvasGroup",
						Style.holder({
							AnchorPoint = Style.CENTRE,
							Position = Style.MIDDLE,
							Size = Style.FULL,
							GroupTransparency = props.leave,
						}),
						{
							Pop = React.createElement("UIScale", { Scale = props.scale }),
							Box = Style.box(
								config,
								{
									Position = UDim2.fromOffset(line, line),
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
											CanvasSize = UDim2.new(
												1,
												0,
												0,
												HudScreen.tabBody(config, compact, players)
											),
											BackgroundTransparency = 1,
											BorderSizePixel = 0,
											ScrollingDirection = Enum.ScrollingDirection.Y,
											ScrollBarThickness = hud.layout.scoreTab.scrollBar,
											ScrollBarImageColor3 = hud.textColor,
											Selectable = false,
										}, teams(props, sizes)),
									}),
								}
							),
							SwitchTeam = if switchTeam ~= nil
								then switchButton(
									config,
									sizes,
									switchTeam,
									rows:map(function(teamsShown: number): UDim2
										local under = 2 * line
											+ sizes.headHeight
											+ teamsShown
											+ shadow
											+ sizes.switchGap
										return UDim2.fromOffset(0, under)
									end),
									switchHeight - sizes.switchGap
								)
								else nil,
						}
					),
				}
			),
		}
	)
end

return ScoreTab
