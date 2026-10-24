--!strict
-- The whole HUD as one React element: a full-screen frame, "Root", that holds every part of the HUD. The match's parts
-- show from the first snapshot on. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Scoreboard = require(script.Parent.Scoreboard)
local Style = require(script.Parent.Style)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

-- What changes every frame, written straight to the instances that show it, without a render.
export type HudBindings = {
	clock: React.Binding<string>,
}

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
	bindings: HudBindings,
}

local function App(props: AppProps): React.ReactElement
	local state = props.state
	local match = state.match
	return React.createElement(React.Fragment, nil, {
		Root = React.createElement("Frame", Style.holder({ Size = UDim2.fromScale(1, 1) }), {
			Scoreboard = if match ~= nil
				then React.createElement(Scoreboard, {
					config = props.config,
					text = props.text,
					match = match,
					names = state.names,
					carrier = props.carrier,
					clock = props.bindings.clock,
				})
				else nil,
		}),
	})
end

return App
