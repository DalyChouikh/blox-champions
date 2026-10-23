--!strict
-- The whole HUD as one React element: a full-screen frame, "Root", that holds every part of the HUD. The scoreboard
-- shows from the first snapshot on; the hints wherever the Hud gives their keys. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Banner = require(script.Parent.Banner)
local Config = require(ReplicatedStorage.Shared.Config)
local ControlHints = require(script.Parent.ControlHints)
local Feed = require(script.Parent.Feed)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Scoreboard = require(script.Parent.Scoreboard)
local Speedometer = require(script.Parent.Speedometer)
local Style = require(script.Parent.Style)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

-- What changes every frame, written straight to the instances that show it, without a render.
export type HudBindings = {
	clock: React.Binding<string>,
	speed: React.Binding<string>,
	labels: ControlHints.HintLabels,
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
	-- Each hint's key on this device; nil where no hints show.
	keys: ControlHints.HintKeys?,
	bindings: HudBindings,
}

local function App(props: AppProps): React.ReactElement
	local config, text, state, bindings = props.config, props.text, props.state, props.bindings
	local match, keys = state.match, props.keys
	return React.createElement(React.Fragment, nil, {
		Root = React.createElement("Frame", Style.holder({ Size = UDim2.fromScale(1, 1) }), {
			Scoreboard = if match ~= nil
				then React.createElement(Scoreboard, {
					config = config,
					text = text,
					match = match,
					names = state.names,
					carrier = props.carrier,
					clock = bindings.clock,
				})
				else nil,
			Banner = React.createElement(Banner, { config = config, text = text, banner = state.banner }),
			Feed = React.createElement(Feed, { config = config, text = text, feed = state.feed, names = state.names }),
			ControlHints = if keys ~= nil
				then React.createElement(ControlHints, { config = config, keys = keys, labels = bindings.labels })
				else nil,
			Speedometer = React.createElement(Speedometer, {
				config = config,
				speed = bindings.speed,
				device = props.device,
				visible = props.hasSkater,
			}),
		}),
	})
end

return App
