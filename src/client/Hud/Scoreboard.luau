--!strict
-- The scoreboard (spec §11.1) in look C (the owner, Q184), at the top centre of the device's safe area, `top` pixels
-- from its top (HudScreen.boardTop: in Roblox's top bar's free band, else under the bar):
-- - desktop, S2 Shields (Q195/Q196): each team's score on a shield in its colour, Blue left and Orange right of the
--   clock's box; under the clock the goal's worth chip, then OVERTIME or LAST CHANCE (HudText:period, in the trailing
--   team's colour); under the possessing team's shield a square lap chip per gate, lit for each gate crossed this lap;
-- - a phone, S5 Compact chips (Q196): the score chips round the clock in one row, the worth chip outside the row beside
--   the score of the team the goal is open for, the period under the row; no lap chips.
-- The worth chip says what a goal is worth while the goal is open (+1, +3, +5: Q188). How it all moves (a score's
-- bounce, the chips filling, the worth chip popping and glowing) is BoardMotion's, read through its tracks' bindings,
-- as the clock is, so nothing renders again while it moves. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoardMotion = require(script.Parent.BoardMotion)
local Config = require(ReplicatedStorage.Shared.Config)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local MatchEngine = require(ReplicatedStorage.Shared.Rules.MatchEngine)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

type Team = Team.Team
type Children = { [string]: React.Node }

export type ScoreboardProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	match: MatchEngine.Snapshot,
	-- A phone's screen (HudScreen.compact): S5, else S2.
	compact: boolean,
	-- Its top, in pixels from the top of the safe area.
	top: number,
	clock: React.Binding<string>,
	motion: BoardMotion.BoardMotion,
}

local CENTRE = Vector2.new(0.5, 0.5)
local MIDDLE = UDim2.fromScale(0.5, 0.5)
local FULL = UDim2.fromScale(1, 1)
local WHITE = Color3.new(1, 1, 1)

-- Lettering filling its box, centred; `scale` grows it from its centre, `font` replaces the look's, `zIndex` orders
-- it over a sibling.
type LabelOptions = { scale: React.Binding<number>?, font: Enum.Font?, zIndex: number? }

local function label(
	config: Config.GameConfig,
	text: string | React.Binding<string>,
	size: number,
	options: LabelOptions?
): React.ReactElement
	local scale = options and options.scale
	return React.createElement(
		"TextLabel",
		Style.lettering(config, {
			AnchorPoint = CENTRE,
			Position = MIDDLE,
			Size = FULL,
			Text = text,
			TextSize = size,
			Font = options and options.font,
			ZIndex = options and options.zIndex,
		}),
		{
			Ink = Style.inked(config),
			Scale = if scale ~= nil then React.createElement("UIScale", { Scale = scale }) else nil,
		}
	)
end

-- A part shown while its scale is above nothing.
local function shown(scale: number): boolean
	return scale > 0
end

local function sizesOf(props: ScoreboardProps): Config.BoardTextSizes
	local layout = props.config.UI.hud.layout
	return if props.compact then layout.compactScoreboard.textSizes else layout.scoreboard.textSizes
end

-- Centred in its parent and as big: a frame that a UIScale grows from the middle.
local function centred(): Style.Props
	return { AnchorPoint = CENTRE, Position = MIDDLE, Size = FULL }
end

-- S2's shield: a body with the look's corners over the top of a round tip as tall as the shield (its radius half the
-- shield's shorter side), so its top corners are the look's and its bottom round.
local function shieldPieces(config: Config.GameConfig, size: UDim2): { Style.Piece }
	local height = size.Y.Offset
	local tip = math.min(size.X.Offset, height) / 2
	return {
		{ top = 0, height = (height - tip) / height, corner = config.UI.hud.look.corner },
		{ top = 0, height = 1, corner = Style.ROUND },
	}
end

-- `team`'s score in a box of its colour, `size` big at `order` in its row (`pieces`: a shield's shape).
local function scoreBox(
	props: ScoreboardProps,
	team: Team,
	size: UDim2,
	order: number,
	pieces: { Style.Piece }?
): React.ReactElement
	local config = props.config
	local content: Children = {}
	content[`{team}Score`] = label(
		config,
		tostring(props.match.scores[team]),
		sizesOf(props).score,
		{ scale = props.motion.scores[team].binding }
	)
	return Style.box(config, { LayoutOrder = order, Size = size }, Style.teamColor(config, team), content, pieces)
end

local function clockBox(props: ScoreboardProps, size: UDim2, order: number): React.ReactElement
	local config = props.config
	return Style.box(config, { LayoutOrder = order, Size = size }, config.UI.hud.look.box, {
		Clock = label(config, props.clock, sizesOf(props).clock),
	})
end

-- The goal's worth chip in a holder placed by `place`: it pops in and shrinks away (hidden at nothing), bounces, and
-- glows under its text (a white veil), in the colour of the team the goal is, or was last, open for.
local function worthChip(props: ScoreboardProps, place: Style.Props): React.ReactElement
	local config, motion = props.config, props.motion
	local look = config.UI.hud.look
	place.Visible = motion.worth.binding:map(shown)
	return React.createElement("Frame", Style.holder(place), {
		Pop = React.createElement("Frame", Style.holder(centred()), {
			Scale = React.createElement("UIScale", { Scale = motion.worth.binding }),
			Bounce = React.createElement("Frame", Style.holder(centred()), {
				Scale = React.createElement("UIScale", { Scale = motion.worthBounce.binding }),
				WorthChip = Style.box(config, centred(), Style.teamColor(config, motion.worthTeam), {
					Glow = React.createElement("Frame", {
						Size = FULL,
						BackgroundColor3 = WHITE,
						BackgroundTransparency = motion.glow.binding,
						BorderSizePixel = 0,
						ZIndex = 1,
					}, { Corner = React.createElement("UICorner", { CornerRadius = look.corner }) }),
					WorthText = label(
						config,
						motion.worthText,
						sizesOf(props).worth,
						{ font = look.bannerFont, zIndex = 2 }
					),
				}),
			}),
		}),
	})
end

-- OVERTIME or LAST CHANCE (in the trailing team's colour), placed by `place`; hidden in regulation.
local function period(props: ScoreboardProps, place: Style.Props): React.ReactElement
	local config, match = props.config, props.match
	local text = props.text:period(match)
	-- Set only through Last Chance.
	local trailing: Team? = match.trailingTeam
	place.Text = text or ""
	place.TextSize = sizesOf(props).period
	place.TextColor3 = Style.teamColor(config, trailing)
	place.Visible = text ~= nil
	return React.createElement("TextLabel", Style.lettering(config, place), { Ink = Style.inked(config) })
end

-- A square lap chip per gate under `team`'s shield: the look's empty box, lit by a square of the team's colour that
-- grows from its centre as its gate is crossed (BoardMotion's chip), hidden while it has not grown at all (Roblox holds
-- a UIScale at no less than 1e-7, so it would still be drawn).
local function lapChips(props: ScoreboardProps, team: Team): React.ReactElement
	local config = props.config
	local board = config.UI.hud.layout.scoreboard
	local side, gap, corner = board.lapChip, board.chipGap, board.chipCorner
	local count = props.match.gateCount
	local color = Style.teamColor(config, team)
	local shape: { Style.Piece } = { { top = 0, height = 1, corner = corner } }
	local chips: Children = {
		Layout = Style.list(config, Enum.FillDirection.Horizontal, { Padding = UDim.new(0, gap) }),
	}
	for index = 1, count do
		local fill = props.motion.chips[index].binding
		chips[tostring(index)] = Style.box(
			config,
			{ LayoutOrder = index, Size = UDim2.fromOffset(side, side) },
			config.UI.hud.look.box,
			{
				Lit = React.createElement("Frame", {
					AnchorPoint = CENTRE,
					Position = MIDDLE,
					Size = FULL,
					BackgroundColor3 = WHITE,
					BorderSizePixel = 0,
					Visible = fill:map(shown),
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = corner }),
					Shade = Style.shading(config, color, 0, 1),
					Grow = React.createElement("UIScale", { Scale = fill }),
				}),
			},
			shape
		)
	end
	return React.createElement(
		"Frame",
		Style.holder({ LayoutOrder = 2, Size = UDim2.fromOffset(count * side + (count - 1) * gap, side) }),
		chips
	)
end

-- A list down a column, its parts from the top, `gap` apart.
local function column(config: Config.GameConfig, gap: number): React.ReactElement
	return Style.list(
		config,
		Enum.FillDirection.Vertical,
		{ Padding = UDim.new(0, gap), VerticalAlignment = Enum.VerticalAlignment.Top }
	)
end

-- S2: a column per team (its shield, its lap chips while it has the ball, chipClearance clear of the shield's shadow)
-- either side of the clock's column.
local function shields(props: ScoreboardProps, place: Style.Props): React.ReactElement
	local config = props.config
	local board = config.UI.hud.layout.scoreboard
	local drop = Style.under(config, board.chipClearance)
	local height = board.shield.Y.Offset + drop + board.lapChip
	local function teamColumn(team: Team, order: number): React.ReactElement
		local parts: Children = {
			Layout = column(config, drop),
			LapChips = if props.match.possessingTeam == team then lapChips(props, team) else nil,
		}
		parts[`{team}Shield`] = scoreBox(props, team, board.shield, 1, shieldPieces(config, board.shield))
		return React.createElement(
			"Frame",
			Style.holder({ LayoutOrder = order, Size = UDim2.fromOffset(board.shield.X.Offset, height) }),
			parts
		)
	end
	place.Size = UDim2.fromOffset(HudScreen.boardWidth(config, false), height)
	return React.createElement("Frame", Style.holder(place), {
		Layout = Style.list(
			config,
			Enum.FillDirection.Horizontal,
			{ Padding = UDim.new(0, board.gap), VerticalAlignment = Enum.VerticalAlignment.Top }
		),
		Blue = teamColumn("Blue", 1),
		Middle = React.createElement(
			"Frame",
			Style.holder({ LayoutOrder = 2, Size = UDim2.fromOffset(board.clock.X.Offset, height) }),
			{
				Layout = column(config, board.gap),
				ClockBox = clockBox(props, board.clock, 1),
				Worth = worthChip(props, { LayoutOrder = 2, Size = board.worth }),
				Period = period(props, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, board.textSizes.period) }),
			}
		),
		Orange = teamColumn("Orange", 3),
	})
end

-- S5: the score chips round the clock in one row; the worth chip outside it, beside the team the goal is open for.
local function chips(props: ScoreboardProps, place: Style.Props): React.ReactElement
	local config = props.config
	local board = config.UI.hud.layout.compactScoreboard
	local gap = board.gap
	local left = props.motion.worthTeam == "Blue"
	place.Size = UDim2.fromOffset(HudScreen.boardWidth(config, true), board.score.Y.Offset)
	return React.createElement("Frame", Style.holder(place), {
		Row = React.createElement("Frame", Style.holder({ Size = FULL }), {
			Layout = Style.list(config, Enum.FillDirection.Horizontal, { Padding = UDim.new(0, gap) }),
			BlueChip = scoreBox(props, "Blue", board.score, 1),
			ClockBox = clockBox(props, board.clock, 2),
			OrangeChip = scoreBox(props, "Orange", board.score, 3),
		}),
		Worth = worthChip(props, {
			AnchorPoint = if left then Vector2.new(1, 0.5) else Vector2.new(0, 0.5),
			Position = if left then UDim2.new(0, -gap, 0.5, 0) else UDim2.new(1, gap, 0.5, 0),
			Size = board.worth,
		}),
		Period = period(props, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, gap),
			Size = UDim2.new(1, 0, 0, board.textSizes.period),
		}),
	})
end

local function Scoreboard(props: ScoreboardProps): React.ReactElement
	local layout = props.config.UI.hud.layout
	local position = if props.compact then layout.compactScoreboard.position else layout.scoreboard.position
	local place: Style.Props = {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(position.X.Scale, position.X.Offset, 0, props.top),
	}
	return if props.compact then chips(props, place) else shields(props, place)
end

return Scoreboard
