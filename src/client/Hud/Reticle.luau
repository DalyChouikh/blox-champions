--!strict
-- The reticle (spec §11.1): a dot at the centre of whatever it is drawn in, always shown. The Hud draws it in a
-- full-screen gui, so it marks where the camera aims, and with a locked mouse it stands in for the cursor. A plain
-- function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local React = require(ReplicatedStorage.Packages.React)

export type ReticleProps = { config: Config.GameConfig }

local function Reticle(props: ReticleProps): React.ReactElement
	local hud = props.config.UI.hud
	local size = hud.layout.reticle.size
	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = hud.textColor,
		BorderSizePixel = 0,
	}, {
		-- Rounded all the way: a dot.
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
end

return Reticle
