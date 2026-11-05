--!strict
-- The touch button that opens and closes the score tab (spec §11.1; the owner's choice, as touch has no key to
-- hold), at the top right: S2 in look C (#355, the owner's Q250). Its right edge sits at `left` across the HUD's area,
-- lined up with the touch buttons' right edge (TouchArea.lineUp: Jump's, past a notched phone's safe area), its top
-- layout.scoreButton.top under Roblox's top bar; its face is a look C box in the touch buttons' fill (Hud/TouchButton)
-- that pops when tapped (`moving`). It takes no gamepad selection. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local TouchButton = require(script.Parent.TouchButton)

export type ScoreButtonProps = {
	config: Config.GameConfig,
	-- Pixels from the HUD's area's left edge to the button's right edge.
	left: React.Binding<number>,
	moving: Style.CapBindings,
	onActivated: () -> (),
}

local function ScoreButton(props: ScoreButtonProps): React.ReactElement
	local config = props.config
	local place = config.UI.hud.layout.scoreButton
	local size = place.size
	return React.createElement(
		"TextButton",
		Style.holder({
			AnchorPoint = Vector2.new(1, 0),
			Position = props.left:map(function(left: number): UDim2
				return UDim2.fromOffset(left, place.top)
			end),
			Size = size,
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			[React.Event.Activated] = props.onActivated,
		}),
		{
			Face = React.createElement(TouchButton, {
				config = config,
				size = Vector2.new(size.X.Offset, size.Y.Offset),
				corner = place.corner,
				fill = config.UI.touchStyle.fill,
				textSize = place.textSize,
				label = config.UI.text.scores,
				moving = props.moving,
			}),
		}
	)
end

return ScoreButton
