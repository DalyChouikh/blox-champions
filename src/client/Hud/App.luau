--!strict
-- The whole HUD as one React element: a full-screen frame, "Root", that holds every part of the HUD. The scoreboard
-- shows from the first snapshot on; the hints wherever the Hud gives their keys; the score tab while it is open, except
-- once the match is over, when the end screen shows until the next match in place of the score tab and the scoreboard
-- (it holds the final score and its own score tab); the score button on touch. A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Banner = require(script.Parent.Banner)
local Config = require(ReplicatedStorage.Shared.Config)
local ControlHints = require(script.Parent.ControlHints)
local EndScreen = require(script.Parent.EndScreen)
local Feed = require(script.Parent.Feed)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local ScoreButton = require(script.Parent.ScoreButton)
local ScoreTab = require(script.Parent.ScoreTab)
local Scoreboard = require(script.Parent.Scoreboard)
local Speedometer = require(script.Parent.Speedometer)
local Style = require(script.Parent.Style)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

-- What changes every frame, written straight to the instances that show it, without a render.
export type HudBindings = {
	clock: React.Binding<string>,
	speed: React.Binding<string>,
	labels: ControlHints.HintLabels,
	-- The HUD's area in pixels, which the score tab and the end screen fit in; zero until it is known.
	area: React.Binding<Vector2>,
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
	-- Its key held, or its touch button toggled on.
	scoreTabOpen: boolean,
	onScoreButton: () -> (),
	bindings: HudBindings,
}

local function App(props: AppProps): React.ReactElement
	local config, text, state, bindings = props.config, props.text, props.state, props.bindings
	local match, keys, ended = state.match, props.keys, state.ended
	return React.createElement(React.Fragment, nil, {
		Root = React.createElement("Frame", Style.holder({ Size = UDim2.fromScale(1, 1) }), {
			Scoreboard = if match ~= nil and ended == nil
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
			ScoreTab = if props.scoreTabOpen
					and match ~= nil
					and ended == nil
				then React.createElement(ScoreTab, {
					config = config,
					text = text,
					stats = match.stats,
					names = state.names,
					localId = props.localId,
					area = bindings.area,
				})
				else nil,
			EndScreen = if ended ~= nil
				then React.createElement(EndScreen, {
					config = config,
					text = text,
					ended = ended,
					names = state.names,
					localId = props.localId,
					area = bindings.area,
				})
				else nil,
			ScoreButton = if props.device == Enum.PreferredInput.Touch
				then React.createElement(ScoreButton, { config = config, onActivated = props.onScoreButton })
				else nil,
		}),
	})
end

return App
