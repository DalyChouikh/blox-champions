--!strict
-- The Get Up prompt (#220), shown while the local skater is knocked down: the movement keys as the device shows them,
-- then what they do now, on the HUD's panel at the bottom centre like Roller Champions' box (the owner's recording,
-- Video 5 at 0:18), so it reads over the skater. The panel widens to fit a long label. Moving gets the skater up
-- sooner; the server decides when. It sits in the HUD's stage, so on touch it centres left of the buttons. A plain
-- function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)

export type GetUpProps = {
	config: Config.GameConfig,
	-- In the order shown: a keyboard's up, left, down and right; a gamepad's stick; the touch stick's name.
	keys: { Style.KeyView },
}

local function GetUp(props: GetUpProps): React.ReactElement
	local config = props.config
	local hud = config.UI.hud
	local place = hud.layout.getUp
	-- The keys fill the panel's height inside its padding.
	local height = place.size.Y.Offset - 2 * hud.spacing
	local children: { [string]: React.Node } = {
		Corner = Style.corner(config),
		Padding = Style.padding(config),
		Layout = Style.list(config, Enum.FillDirection.Horizontal),
		Label = Style.label(config, config.UI.controlLabels.GetUp, #props.keys + 1),
	}
	for order, view in props.keys do
		local name, key = Style.key(config, view, height, order)
		children[`{name}{order}`] = key
	end
	return React.createElement(
		"Frame",
		Style.panel(config, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = place.position,
			Size = place.size,
			AutomaticSize = Enum.AutomaticSize.X,
		}),
		children
	)
end

return GetUp
