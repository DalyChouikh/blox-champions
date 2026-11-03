--!strict
-- The whole HUD as one React element: a full-screen frame, "Root", that holds every part of the HUD. The banner line
-- (its place from HudScreen.bannerLine, measured from the safe area's top, less the stage's top), the goal message,
-- the feed, the Get Up prompt, the score tab and the end screen sit in its frame "Stage", the HUD's stage (the Hud's
-- binding): on touch the part of the HUD's area left of the touch buttons, so they centre there, clear of the buttons,
-- and all but the small prompt shrink to fit it. The stage draws over the other parts. The scoreboard shows from the
-- first snapshot on; the hints and the Get Up prompt wherever the Hud gives their keys; the score tab while it is open.
-- Once the match is over the end screen shows until the next match in place of the scoreboard, holding the final
-- score. Off touch it holds its own score tab too, so an open one shows no other; on touch it is compact (the owner's
-- choice) and the score tab opens over it, from its button, shown on touch throughout, or a held key. The reticle,
-- the kickoff count and the scoreboard are drawn in guis the Hud gives (portals): the reticle and the count in the
-- full-screen one, where throws aim, the scoreboard in the safe area's, from its top (in Roblox's top bar's free band
-- where it fits, HudScreen). The reticle shows only while the local player holds the ball (RC's way, the owner's
-- Q185); its rings shrink, and the count moves down, where they would touch the scoreboard (HudScreen); both hide
-- while the score tab or the end screen shows. The reticle and the speedometer read in the viewer's team colour. A
-- plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Banner = require(script.Parent.Banner)
local BannerMotion = require(script.Parent.BannerMotion)
local BoardMotion = require(script.Parent.BoardMotion)
local Config = require(ReplicatedStorage.Shared.Config)
local ControlHints = require(script.Parent.ControlHints)
local Countdown = require(script.Parent.Countdown)
local EndScreen = require(script.Parent.EndScreen)
local Feed = require(script.Parent.Feed)
local GetUp = require(script.Parent.GetUp)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Reticle = require(script.Parent.Reticle)
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
	-- Each hint row's label, fade and key cap (#354).
	hints: ControlHints.HintRows,
	-- The HUD's stage in pixels, where the banner, the feed, the score tab and the end screen centre and fit; zero
	-- until it is known.
	stage: React.Binding<Vector2>,
	-- How long the throw key has been held while a throw charges, 0 otherwise: the reticle's ring (#312).
	charge: React.Binding<number>,
}

-- Everything the HUD shows; the Hud renders App again whenever one of them changes.
export type AppProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	state: HudState.HudState,
	device: Enum.PreferredInput,
	localId: Types.PlayerId,
	-- A phone's screen (HudScreen.compact), the scoreboard's top and the crosshair's aim in pixels from the top of the
	-- safe area (HudScreen.boardTop, HudScreen.aim).
	compact: boolean,
	boardTop: number,
	aim: number,
	-- The banner line at its highest and the stage's top, in pixels from the safe area's top (HudScreen.bannerAt).
	bannerAt: number,
	stageTop: number,
	-- How the scoreboard moves, having watched the state's match.
	board: BoardMotion.BoardMotion,
	-- How the banner line and the goal message move.
	banners: BannerMotion.BannerMotion,
	-- Whether the local player has a skater: a spectator has no speed and no hints.
	hasSkater: boolean,
	-- Whether the local player holds the ball: the reticle shows only then.
	carrying: boolean,
	-- Each hint's key on this device; nil where no hints show.
	keys: ControlHints.HintKeys?,
	-- The movement keys on this device while the local skater is knocked down; nil otherwise.
	getUpKeys: { Style.KeyView }?,
	-- Its key held, or its touch button toggled on.
	scoreTabOpen: boolean,
	onScoreButton: () -> (),
	-- The score tab's Switch team button; nil where it has none (#310).
	switchTeam: ScoreTab.SwitchTeam?,
	bindings: HudBindings,
	-- The full-screen gui the reticle is drawn in, and the safe area's the scoreboard is (portals): the HUD's own sits
	-- below Roblox's top bar.
	centre: ScreenGui,
	top: ScreenGui,
}

-- The Stage frame's size: the stage, or the whole Root while the stage is not known.
local function stageSize(stage: Vector2): UDim2
	return if stage.X > 0 and stage.Y > 0 then UDim2.fromOffset(stage.X, stage.Y) else UDim2.fromScale(1, 1)
end

local function App(props: AppProps): React.ReactElement
	local config, text, state, bindings = props.config, props.text, props.state, props.bindings
	local match, keys, ended = state.match, props.keys, state.ended
	local touch = props.device == Enum.PreferredInput.Touch
	local scoreTab = props.scoreTabOpen and match ~= nil and (ended == nil or touch)
	local uncovered = not scoreTab and ended == nil
	local compact, top, aim = props.compact, props.boardTop, props.aim
	local period = match ~= nil and text:period(match) ~= nil
	local banners = props.banners
	local shownBanner = state.banner
	local lineSize = HudScreen.bannerSize(config, compact, if shownBanner ~= nil then shownBanner.kind else "Go")
	local viewer = Style.teamColor(config, HudState.teamOf(match, props.localId))
	return React.createElement(React.Fragment, nil, {
		Centre = ReactRoblox.createPortal({
			Reticle = React.createElement(Reticle, {
				config = config,
				compact = compact,
				color = viewer,
				visible = uncovered and props.carrying,
				charge = bindings.charge,
				scale = HudScreen.ringScale(config, compact, top, aim, period),
			}),
			Countdown = React.createElement(Countdown, {
				config = config,
				text = text,
				banner = state.banner,
				compact = compact,
				visible = uncovered,
				drop = HudScreen.countDrop(config, compact, top, aim, period),
			}),
		}, props.centre),
		Top = ReactRoblox.createPortal({
			Scoreboard = if match ~= nil and ended == nil
				then React.createElement(Scoreboard, {
					config = config,
					text = text,
					match = match,
					compact = compact,
					top = top,
					clock = bindings.clock,
					motion = props.board,
				})
				else nil,
		}, props.top),
		Root = React.createElement("Frame", Style.holder({ Size = UDim2.fromScale(1, 1) }), {
			ControlHints = if keys ~= nil
				then React.createElement(ControlHints, {
					config = config,
					keys = keys,
					rows = bindings.hints,
				})
				else nil,
			Speedometer = React.createElement(Speedometer, {
				config = config,
				speed = bindings.speed,
				color = viewer,
				touch = touch,
				compact = compact,
				visible = props.hasSkater,
			}),
			ScoreButton = if touch
				then React.createElement(ScoreButton, { config = config, onActivated = props.onScoreButton })
				else nil,
			-- Above the other parts, so the solid score tab and end screen cover them.
			Stage = React.createElement("Frame", Style.holder(Style.above({ Size = bindings.stage:map(stageSize) })), {
				Banner = React.createElement(Banner, {
					config = config,
					text = text,
					banner = state.banner,
					compact = compact,
					line = HudScreen.bannerLine(config, compact, props.bannerAt, top, period, lineSize)
						- props.stageTop,
					scale = banners.line.scale.binding,
					leave = banners.line.leave,
					area = bindings.stage,
				}),
				Message = React.createElement(Banner, {
					config = config,
					text = text,
					banner = state.message,
					compact = compact,
					scale = banners.message.scale.binding,
					leave = banners.message.leave,
					area = bindings.stage,
				}),
				Feed = React.createElement(Feed, {
					config = config,
					text = text,
					feed = state.feed,
					names = state.names,
					compact = compact,
					area = bindings.stage,
				}),
				GetUp = if props.getUpKeys ~= nil
					then React.createElement(GetUp, { config = config, keys = props.getUpKeys })
					else nil,
				ScoreTab = if scoreTab and match ~= nil
					then React.createElement(ScoreTab, {
						config = config,
						text = text,
						stats = if ended ~= nil then ended.stats else match.stats,
						names = state.names,
						localId = props.localId,
						area = bindings.stage,
						switchTeam = props.switchTeam,
					})
					else nil,
				EndScreen = if ended ~= nil
					then React.createElement(EndScreen, {
						config = config,
						text = text,
						ended = ended,
						names = state.names,
						localId = props.localId,
						area = bindings.stage,
						compact = touch,
					})
					else nil,
			}),
		}),
	})
end

return App
