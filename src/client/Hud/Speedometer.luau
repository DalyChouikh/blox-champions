--!strict
-- The speedometer (spec §7.2, §11.1) in look C (the owner, Q192): big outlined digits in the viewer's team colour over
-- a small KM/H, the skater's speed as SkateMath.shownSpeed reads it (along the surface, or across the ground in the
-- air), eased by the Hud and shown through a binding, so it follows the skater each frame without a render. Bottom
-- right; on touch top left, as the touch buttons and the score button fill the right side; small on a phone's screen
-- (HudScreen.compact). Hidden without a skater. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)

export type SpeedometerProps = {
	config: Config.GameConfig,
	speed: React.Binding<string>,
	-- The viewer's team colour (Style.teamColor).
	color: Color3,
	-- Touch buttons on the screen, and a phone's screen.
	touch: boolean,
	compact: boolean,
	visible: boolean,
}

local function Speedometer(props: SpeedometerProps): React.ReactElement
	local config = props.config
	local place = config.UI.hud.layout.speedometer
	local sizes = if props.compact then place.compactTextSizes else place.textSizes
	local touch = props.touch
	local function line(
		text: string | React.Binding<string>,
		size: number,
		order: number,
		color: Color3?
	): React.ReactElement
		return React.createElement(
			"TextLabel",
			Style.lettering(config, {
				LayoutOrder = order,
				AutomaticSize = Enum.AutomaticSize.XY,
				Text = text,
				TextSize = size,
				TextColor3 = color,
			}),
			{ Ink = Style.inked(config) }
		)
	end
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = if touch then Vector2.zero else Vector2.one,
			Position = if touch then place.touchPosition else place.position,
			AutomaticSize = Enum.AutomaticSize.XY,
			Visible = props.visible,
		}),
		{
			Layout = Style.list(config, Enum.FillDirection.Vertical, {
				HorizontalAlignment = if touch then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 0),
			}),
			Speed = line(props.speed, sizes.speed, 1, props.color),
			Unit = line(config.UI.text.speedUnit, sizes.unit, 2),
		}
	)
end

return Speedometer
