--!strict
-- The end of the match (spec §6.5, §11.1; #358, the owner's Q243: today's parts in look C), over the Hud's dim of the
-- whole screen until the next match starts, its parts down the stage's middle, layout.endScreen.gap apart: the result
-- in GOAL!'s lettering (Style.banner, the winner's ring; none for a draw), the MVP's card while there is one (a look C
-- box: their avatar, their name with the MVP chip, their score, goals and steals), each team's total on a chip in its
-- team colour, and the TAB board's table of everyone still in the match (Hud/TeamTable, #357), whole. On touch (the
-- owner's choice) it leaves the table out, as the touch score button opens the TAB board in its place. It shrinks to
-- fit the stage and pops in as the match ends (a Reveal's scale, Q194). A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local TeamTable = require(script.Parent.TeamTable)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

export type EndScreenProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	ended: HudState.Ended,
	names: { [Types.PlayerId]: string },
	localId: Types.PlayerId,
	-- The HUD's stage, which the screen fits in.
	area: React.Binding<Vector2>,
	-- A phone's screen (HudScreen.compact): the compact sizes.
	compact: boolean,
	-- Played by touch: without the table.
	touch: boolean,
	-- Its pop (1 at rest; Reveal).
	scale: React.Binding<number>,
}

-- A look C box of `size` at `order` in the stack, its ink inside the part's own frame (look.outline round it, the
-- shadow under it), so the stack's gap falls between the parts' inks; and how wide that frame is.
local function boxed(
	config: Config.GameConfig,
	order: number,
	size: Vector2,
	color: Color3,
	children: Style.Children
): (React.ReactElement, number)
	local look = config.UI.hud.look
	local line = look.outline
	local width = size.X + 2 * line
	local frame = React.createElement(
		"Frame",
		Style.holder({
			LayoutOrder = order,
			Size = UDim2.fromOffset(width, size.Y + 2 * line + look.shadow),
		}),
		{
			Box = Style.box(
				config,
				{ Position = UDim2.fromOffset(line, line), Size = UDim2.fromOffset(size.X, size.Y) },
				color,
				children
			),
		}
	)
	return frame, width
end

-- The MVP's card: their avatar (Style.avatar), their name and the MVP chip in key yellow, then their numbers. A name
-- too long for the card ends in an ellipsis where the chip would pass its inset. Returns it and its width (boxed).
local function card(props: EndScreenProps, sizes: Config.EndSizes, mvp: Types.PlayerStats): (React.ReactElement, number)
	local config, text = props.config, props.text
	local hud = config.UI.hud
	local look = hud.look
	local inset = sizes.inset
	local name = text:name(mvp.player, props.names)
	local chipWords = config.UI.text.mvp
	local chipWidth = Style.textWidth(config, chipWords, sizes.chipSize) + 2 * inset
	local textLeft = sizes.avatar + 2 * inset
	local room = sizes.cardWidth - textLeft - chipWidth - 2 * inset
	local nameWidth = math.min(Style.textWidth(config, name, sizes.nameSize), room)
	return boxed(config, 2, Vector2.new(sizes.cardWidth, sizes.avatar + 2 * inset), look.box, {
		Avatar = React.createElement(
			"Frame",
			Style.holder({
				Position = UDim2.fromOffset(inset, inset),
				Size = UDim2.fromOffset(sizes.avatar, sizes.avatar),
			}),
			{ Disc = Style.avatar(config, sizes.avatar, text:avatar(mvp.player)) }
		),
		Player = React.createElement(
			"TextLabel",
			Style.lettering(config, {
				Position = UDim2.fromOffset(textLeft, inset),
				Size = UDim2.fromOffset(nameWidth, sizes.nameSize),
				Text = name,
				TextSize = sizes.nameSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			{ Ink = Style.inked(config) }
		),
		-- Centred on the name's line, on a whole pixel.
		Chip = React.createElement("Frame", {
			Position = UDim2.fromOffset(
				textLeft + nameWidth + inset,
				inset + math.floor((sizes.nameSize - sizes.chipHeight) / 2)
			),
			Size = UDim2.fromOffset(chipWidth, sizes.chipHeight),
			BackgroundColor3 = look.key,
			BorderSizePixel = 0,
		}, {
			Corner = Style.corner(config),
			Stroke = React.createElement("UIStroke", { Color = look.ink, Thickness = look.textOutline }),
			Word = React.createElement(
				"TextLabel",
				Style.lettering(config, {
					Size = Style.FULL,
					Text = chipWords,
					TextSize = sizes.chipSize,
					TextColor3 = look.ink,
				})
			),
		}),
		Numbers = React.createElement(
			"TextLabel",
			Style.lettering(config, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, textLeft, 1, -inset),
				Size = UDim2.new(1, -textLeft - inset, 0, sizes.statSize),
				Text = text:mvpLine(mvp.score, mvp.goals, mvp.steals),
				TextSize = sizes.statSize,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		),
	})
end

-- `team`'s total on a chip in its team colour, as wide as its words with `inset` each side. Returns it and its width
-- (boxed).
local function total(
	props: EndScreenProps,
	sizes: Config.EndSizes,
	team: Team.Team,
	order: number
): (React.ReactElement, number)
	local config = props.config
	local words = props.text:teamTotal(team, props.ended.stats.scores[team])
	local width = Style.textWidth(config, words, sizes.totalSize) + 2 * sizes.inset
	return boxed(config, order, Vector2.new(width, sizes.totalHeight), Style.teamColor(config, team), {
		Total = React.createElement(
			"TextLabel",
			Style.lettering(config, { Size = Style.FULL, Text = words, TextSize = sizes.totalSize }),
			{ Ink = Style.inked(config) }
		),
	})
end

local function EndScreen(props: EndScreenProps): React.ReactElement
	local config, text, ended = props.config, props.text, props.ended
	local hud = config.UI.hud
	local look = hud.look
	local compact = props.compact
	local sizes = HudScreen.endSizes(config, compact)
	local stats = ended.stats
	local mvp: Types.PlayerStats? = nil
	for _, player in stats.players do
		if player.player == ended.mvp then
			mvp = player
			break
		end
	end
	local players = #stats.players
	local withTable = not props.touch
	-- The table at the desktop's sizes: it shows off touch only.
	local tab = HudScreen.tabSizes(config, false)
	local tableWidth = tab.width + 2 * look.outline
	local winner: Team.Team? = ended.winner
	local result = text:result(winner)
	local resultSize, resultInk = HudScreen.bannerSize(config, compact, "Goal"), HudScreen.bannerInk(config, compact)
	local body = HudScreen.tabBody(config, false, players)
	local shown = React.createBinding(body)
	-- Each team's total, in the teams' own order, side by side hud.spacing apart (Style.list).
	local totals: Style.Children = { Layout = Style.list(config, Enum.FillDirection.Horizontal) }
	local totalsWidth = -hud.spacing
	for order, team: Team.Team in Team.list do
		local chip, chipWidth = total(props, sizes, team, order)
		totals[`{team}Total`] = chip
		totalsWidth += chipWidth + hud.spacing
	end
	local mvpCard: React.ReactElement? = nil
	local cardWidth = 0
	if mvp ~= nil then
		mvpCard, cardWidth = card(props, sizes, mvp)
	end
	-- As wide as its widest part, so the whole of it fits the stage.
	local width = math.max(
		Style.bannerWidth(config, result, resultSize, resultInk),
		totalsWidth,
		cardWidth,
		if withTable then tableWidth else 0
	)
	local size = UDim2.fromOffset(width, HudScreen.endHeight(config, compact, players, mvp ~= nil, withTable))
	return React.createElement("Frame", Style.holder({ Size = Style.FULL }), {
		Stack = React.createElement(
			"Frame",
			Style.holder({ AnchorPoint = Style.CENTRE, Position = Style.MIDDLE, Size = size }),
			{
				Fit = Style.fit(config, props.area, size),
				Group = React.createElement(
					"Frame",
					Style.holder({ AnchorPoint = Style.CENTRE, Position = Style.MIDDLE, Size = Style.FULL }),
					{
						Pop = React.createElement("UIScale", { Scale = props.scale }),
						Layout = Style.list(config, Enum.FillDirection.Vertical, {
							Padding = UDim.new(0, hud.layout.endScreen.gap),
							VerticalAlignment = Enum.VerticalAlignment.Top,
						}),
						Result = Style.banner(
							config,
							{ LayoutOrder = 1 },
							result,
							resultSize,
							if winner ~= nil then Style.teamColor(config, winner) else nil,
							HudScreen.banners(config, compact).edge,
							resultInk
						),
						Mvp = mvpCard,
						Totals = React.createElement(
							"Frame",
							Style.holder({
								LayoutOrder = 3,
								Size = UDim2.new(1, 0, 0, sizes.totalHeight + 2 * look.outline + look.shadow),
							}),
							totals
						),
						Table = if withTable
							then React.createElement(
								"Frame",
								Style.holder({
									LayoutOrder = 4,
									Size = UDim2.fromOffset(
										tableWidth,
										tab.headHeight + body + 2 * look.outline + look.shadow
									),
								}),
								{
									Box = React.createElement(TeamTable, {
										config = config,
										text = text,
										stats = stats,
										names = props.names,
										localId = props.localId,
										compact = false,
										position = UDim2.fromOffset(look.outline, look.outline),
										shown = shown,
									}),
								}
							)
							else nil,
					}
				),
			}
		),
	})
end

return EndScreen
