--!strict
-- The touch button that opens and closes the score tab (spec §11.1; the owner's choice, as touch has no key to
-- hold), in the upper right. It takes no gamepad selection. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)

export type ScoreButtonProps = {
	config: Config.GameConfig,
	onActivated: () -> (),
}

local function ScoreButton(props: ScoreButtonProps): React.ReactElement
	local config = props.config
	local place = config.UI.hud.layout.scoreButton
	return React.createElement(
		"TextButton",
		Style.text(
			config,
			Style.panel(config, {
				AnchorPoint = Vector2.new(1, 0),
				Position = place.position,
				Size = place.size,
				Text = config.UI.text.scores,
				Selectable = false,
				[React.Event.Activated] = props.onActivated,
			})
		),
		{ Corner = Style.corner(config) }
	)
end

return ScoreButton
