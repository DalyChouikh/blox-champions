--!strict
-- The next gate's marker while the viewer carries the ball (spec §11.1; #376, the owner's Q264, Q266): a bold look C
-- chevron, two rounded bars meeting at its tip (Roblox draws a rounded bar, and look C's ink round it, exactly; a
-- notched arrowhead's ink would spike in its notch), in the team's colour over look C's ink, its drop shadow under it.
-- Each arm leans `spread` degrees off the line it points along; the chevron is `width` across its two arms' round ends.
-- Its place (its centre), turn (degrees, 0 pointing up, clockwise) and showing are bindings the Hud sets each frame,
-- only on change. Sizes in whole pixels: a UDim's offset drops a fraction. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)

export type GateChevronProps = {
	config: Config.GameConfig,
	compact: boolean,
	color: Color3,
	place: React.Binding<UDim2>,
	turn: React.Binding<number>,
	shown: React.Binding<boolean>,
}

local SIDES: { [string]: number } = { Left = -1, Right = 1 }

local function GateChevron(props: GateChevronProps): React.ReactElement
	local config = props.config
	local look = config.UI.hud.look
	local chevron = config.UI.hud.layout.markers.chevron
	local width = HudScreen.markerSizes(config, props.compact).chevron
	local ink = look.outline
	local bar = math.round(chevron.bar * width)
	local spread = math.rad(chevron.spread)
	local arm = (width - bar) / (2 * math.sin(spread))
	-- Each arm's middle, half an arm across from the chevron's: the tip above, the arms' ends below, alike.
	local across = math.round(arm * math.sin(spread) / 2)
	local length = math.round(arm + bar)
	-- A bar on `side`, `grow` pixels bigger all round, in `color`, at `z`.
	local function barOf(side: number, grow: number, color: Color3, z: number): React.ReactElement
		return React.createElement("Frame", {
			AnchorPoint = Style.CENTRE,
			Position = UDim2.new(0.5, side * across, 0.5, 0),
			Size = UDim2.fromOffset(length + 2 * grow, bar + 2 * grow),
			Rotation = side * (90 - chevron.spread),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
		}, { Corner = Style.round() })
	end
	local shadow: Style.Children, arrow: Style.Children = {}, {}
	for name, side in SIDES do
		shadow[name] = barOf(side, ink, look.ink, 1)
		arrow[`{name}Ink`] = barOf(side, ink, look.ink, 1)
		arrow[name] = barOf(side, 0, props.color, 2)
	end
	-- A holder as big as the chevron, centred `drop` pixels lower, turned round its centre.
	local function holder(drop: number, z: number, children: Style.Children): React.ReactElement
		return React.createElement(
			"Frame",
			Style.holder({
				AnchorPoint = Style.CENTRE,
				Position = UDim2.new(0.5, 0, 0.5, drop),
				Size = UDim2.fromOffset(width, width),
				Rotation = props.turn,
				ZIndex = z,
			}),
			children
		)
	end
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = Style.CENTRE,
			Position = props.place,
			Size = UDim2.fromOffset(width, width),
			Visible = props.shown,
		}),
		{ Shadow = holder(look.shadow, 1, shadow), Arrow = holder(0, 2, arrow) }
	)
end

return GateChevron
