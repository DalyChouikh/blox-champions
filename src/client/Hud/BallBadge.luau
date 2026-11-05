--!strict
-- The ball's marker while the ball is off the screen (spec §11.1; #376, the owner's Q242, Q264-Q266): Roller Champions'
-- ball badge (Video 31 at 21.0 s, Video 34 at 98.2 s) in look C. RC's white ball, crossed by the two lines of its band,
-- inside a ring; a right-angled pointer outside the ring, turned toward the ball. The ring, the lines and the pointer
-- in the colour of the team that last held the ball (the HUD's, Style.teamColor), look C's ink before a team has, like
-- RC's at the kickoff; the ball stays white whoever holds it, as RC's does. Look C's ink rings the ring and the
-- pointer, its drop shadow under them. The band leans and stays put: the ball in the world has no band yet to follow.
-- Its place (the badge's centre), turn (degrees, 0 pointing up, clockwise) and showing are bindings the Hud sets each
-- frame, only on change. Sizes in whole pixels: a UDim's offset drops a fraction. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

export type BallBadgeProps = {
	config: Config.GameConfig,
	compact: boolean,
	-- The team that last held the ball; nil before any has.
	team: Team.Team?,
	place: React.Binding<UDim2>,
	turn: React.Binding<number>,
	shown: React.Binding<boolean>,
}

-- A disc `size` pixels across in `color`, centred, at `z` among the badge's parts.
local function disc(size: number, color: Color3, z: number): React.ReactElement
	return React.createElement("Frame", {
		AnchorPoint = Style.CENTRE,
		Position = Style.MIDDLE,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
	}, { Corner = Style.round() })
end

-- A holder as big as the badge, centred on it, at `z`, turned by `turn` and `drop` pixels lower: the pointer's (and its
-- shadow's), which turns round the badge's centre.
local function holder(
	width: number,
	turn: React.Binding<number>,
	drop: number,
	z: number,
	children: Style.Children
): React.ReactElement
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = Style.CENTRE,
			Position = UDim2.new(0.5, 0, 0.5, drop),
			Size = UDim2.fromOffset(width, width),
			Rotation = turn,
			ZIndex = z,
		}),
		children
	)
end

local function BallBadge(props: BallBadgeProps): React.ReactElement
	local config = props.config
	local look = config.UI.hud.look
	local badge = config.UI.hud.layout.markers.badge
	local width = HudScreen.markerSizes(config, props.compact).badge
	local ink, drop = look.outline, look.shadow
	local tone = if props.team ~= nil then Style.teamColor(config, props.team) else look.ink
	local ring = math.round(badge.ring * width)
	local ball = width - 2 * ring
	-- The band's lines: chords of the ball `band` either side of its middle, 1 px into the ring at each end.
	local offset = math.round(badge.band * width)
	local chord = math.round(2 * math.sqrt((ball / 2) ^ 2 - offset ^ 2) + 2)
	local lines: Style.Children = {}
	for index, side in { -1, 1 } do
		lines[`Line{index}`] = React.createElement("Frame", {
			AnchorPoint = Style.CENTRE,
			Position = UDim2.new(0.5, 0, 0.5, side * offset),
			Size = UDim2.fromOffset(chord, badge.line),
			BackgroundColor3 = tone,
			BorderSizePixel = 0,
		})
	end
	-- The pointer: its base past the ring's ink, `gap` and its own ink; a square `side` across cut on its diagonal
	-- (legs `side`, inradius side (2 - sqrt 2) / 2), its ink the tip grown `ink` on every side about that incentre.
	local base = width / 2 + 2 * ink + badge.gap
	local side = math.round(badge.pointer * width * math.sqrt(2))
	local inradius = side * (2 - math.sqrt(2)) / 2
	local inkSide = math.round(side * (inradius + ink) / inradius)
	local function inkTip(): React.ReactElement
		return Style.tip(inkSide, look.ink, { Position = UDim2.new(0.5, 0, 0.5, -(base - ink)), ZIndex = 1 })
	end
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = Style.CENTRE,
			Position = props.place,
			Size = UDim2.fromOffset(width, width),
			Visible = props.shown,
		}),
		{
			PointerShadow = holder(width, props.turn, drop, 1, { Ink = inkTip() }),
			Ink = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0.5, -(width / 2 + ink)),
				Size = UDim2.fromOffset(width + 2 * ink, width + 2 * ink + drop),
				BackgroundColor3 = look.ink,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, { Corner = Style.round() }),
			Pointer = holder(width, props.turn, 0, 2, {
				Ink = inkTip(),
				Fill = Style.tip(side, tone, { Position = UDim2.new(0.5, 0, 0.5, -base), ZIndex = 2 }),
			}),
			Ring = disc(width, tone, 3),
			Ball = disc(ball, Style.WHITE, 4),
			Band = React.createElement(
				"Frame",
				Style.holder({
					AnchorPoint = Style.CENTRE,
					Position = Style.MIDDLE,
					Size = UDim2.fromOffset(ball, ball),
					Rotation = badge.lean,
					ZIndex = 5,
				}),
				lines
			),
		}
	)
end

return BallBadge
