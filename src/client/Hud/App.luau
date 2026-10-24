--!strict
-- The whole HUD as one React element: a full-screen frame, "Root", that holds every part of the HUD. A plain function
-- of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

-- Everything the HUD shows; the Hud renders App again whenever one of them changes.
export type AppProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	state: HudState.HudState,
	device: Enum.PreferredInput,
	localId: Types.PlayerId,
	-- Who carries the ball (BallCarrier), nil while it is loose.
	carrier: Types.PlayerId?,
	-- Whether the local player has a skater: a spectator has no speed and no hints.
	hasSkater: boolean,
}

local function App(_props: AppProps): React.ReactElement
	return React.createElement(React.Fragment, nil, {
		Root = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}),
	})
end

return App
