--!strict
-- The speedometer (spec §7.2, §11.1), in the lower right: the skater's speed in km/h, a binding, so it follows the
-- skater each frame without a render. On touch it sits small in the top-left corner, as the touch buttons and the
-- score button fill the right side (a phone has no room left there). Hidden without a skater. A plain function of its
-- props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)

export type SpeedometerProps = {
	config: Config.GameConfig,
	speed: React.Binding<string>,
	device: Enum.PreferredInput,
	visible: boolean,
}

local function Speedometer(props: SpeedometerProps): React.ReactElement
	local hud = props.config.UI.hud
	local place = hud.layout.speedometer
	local touch = props.device == Enum.PreferredInput.Touch
	return React.createElement(
		"TextLabel",
		Style.text(props.config, {
			AnchorPoint = if touch then Vector2.zero else Vector2.one,
			Position = if touch then place.touchPosition else place.position,
			Size = place.size,
			Text = props.speed,
			TextSize = if touch then hud.textSize else hud.titleSize,
			TextXAlignment = if touch then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			Visible = props.visible,
		})
	)
end

return Speedometer
