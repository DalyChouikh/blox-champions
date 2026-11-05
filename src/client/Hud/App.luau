--!strict
-- The whole HUD as one React element: a full-screen frame, "Root", that holds every part of the HUD. The banner line
-- (its place from HudScreen.bannerLine, measured from the safe area's top, less the stage's top), the goal message, the
-- feed, the Get Up prompt and the end screen sit in its frame "Stage", the HUD's stage (the Hud's binding): on touch
-- the part of the HUD's area left of the touch buttons, so they centre there, clear of the buttons, and all but the
-- small prompt shrink to fit it. The stage draws over the other parts, and the TAB board over everything (#357): it
-- fits the HUD's whole area under the scoreboard's ink, on touch under the score button too, over the touch buttons
-- (the owner, Q234, Q236). The scoreboard shows from the first snapshot on; the hints and the Get Up prompt wherever
-- the Hud gives their keys; the board while it shows (HudState.tabShows, then its fade), and while it does no part of
-- the stage, which it would cut (the owner, Q235, Q238): they come back once it has gone, their time counting on. Once
-- the match is over the end screen shows until the next match in place of the scoreboard, holding the final score,
-- over a dim of the whole screen in a gui of its own under the HUD's (the page's Q243), so the rest of the HUD goes
-- meanwhile, or it would show through; on touch it is compact (the owner's choice) and the board opens in its place,
-- from its button, shown on touch throughout. The reticle, the kickoff count and the scoreboard are drawn in guis
-- the Hud gives (portals): the reticle and the count in the full-screen one, where throws aim, the scoreboard in the
-- safe area's, from its top (in Roblox's top bar's free band where it fits, HudScreen). The reticle shows only while
-- the local player holds the ball (RC's way, the owner's Q185); its rings shrink, and the count moves down, where they
-- would touch the scoreboard (HudScreen); both hide while the board or the end screen shows. The reticle and the
-- speedometer read in the viewer's team colour. On touch each touch button's look C face (Hud/TouchButton, #355) is
-- drawn into TouchControls' button for it (portals), from its hint row's bindings: Jump in UI.touchStyle.jumpFill, the
-- others in its fill; and SCORES lines up with their right edge. Each part, each face too, is behind its own error
-- boundary (Hud/PartBoundary, #379): one whose render throws shows nothing until the next match, and the rest go on.
-- A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Banner = require(script.Parent.Banner)
local BannerMotion = require(script.Parent.BannerMotion)
local BoardMotion = require(script.Parent.BoardMotion)
local Config = require(ReplicatedStorage.Shared.Config)
local ControlHints = require(script.Parent.ControlHints)
local ControlLabels = require(script.Parent.Parent.ControlLabels)
local Countdown = require(script.Parent.Countdown)
local EndScreen = require(script.Parent.EndScreen)
local Feed = require(script.Parent.Feed)
local GetUp = require(script.Parent.GetUp)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local PartBoundary = require(script.Parent.PartBoundary)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Reticle = require(script.Parent.Reticle)
local Reveal = require(script.Parent.Reveal)
local ScoreButton = require(script.Parent.ScoreButton)
local ScoreTab = require(script.Parent.ScoreTab)
local Scoreboard = require(script.Parent.Scoreboard)
local Speedometer = require(script.Parent.Speedometer)
local Style = require(script.Parent.Style)
local TouchButton = require(script.Parent.TouchButton)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

-- What changes every frame, written straight to the instances that show it, without a render.
export type HudBindings = {
	clock: React.Binding<string>,
	speed: React.Binding<string>,
	-- Each hint row's label, fade and key cap (#354).
	hints: ControlHints.HintRows,
	-- The HUD's stage in pixels, where the banner, the feed and the end screen centre and fit; zero until it is known.
	stage: React.Binding<Vector2>,
	-- The HUD's whole area in pixels, which the TAB board fits; zero until it is known.
	area: React.Binding<Vector2>,
	-- How long the throw key has been held while a throw charges, 0 otherwise: the reticle's ring (#312).
	charge: React.Binding<number>,
	-- Where the touch buttons' right edge sits across the HUD's area (TouchArea.lineUp): SCORES' right edge (#355).
	lineUp: React.Binding<number>,
	-- The whole screen in the HUD's area's pixels: the open board's shield on touch reaches it (#355).
	screen: React.Binding<Rect>,
	-- What moves on SCORES: its pop and whether it shows pressed (never cooling).
	scoreButton: Style.CapBindings,
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
	-- How the banner line and the goal message move, and the Get Up prompt, the TAB board (#357) and the end screen
	-- (#358: only its pop is read, as it goes when the next match starts).
	banners: BannerMotion.BannerMotion,
	prompt: Reveal.Reveal,
	tab: Reveal.Reveal,
	ending: Reveal.Reveal,
	-- Whether the local player has a skater: a spectator has no speed and no hints.
	hasSkater: boolean,
	-- Whether the local player holds the ball: the reticle shows only then.
	carrying: boolean,
	-- Each hint's key on this device; nil where no hints show.
	keys: ControlHints.HintKeys?,
	-- The movement keys on this device while the Get Up prompt shows (Reveal.shown); nil otherwise.
	getUpKeys: { Style.KeyView }?,
	-- The TAB board open (HudState.tabShows), and on the screen: open, or fading out after (Reveal.shown).
	tabOpen: boolean,
	tabShown: boolean,
	onScoreButton: () -> (),
	-- TouchControls' buttons, by control, each drawn its face on touch (#355).
	touchButtons: { [string]: GuiButton },
	-- The score tab's Switch team button; nil where it has none (#310).
	switchTeam: ScoreTab.SwitchTeam?,
	bindings: HudBindings,
	-- The full-screen gui the reticle is drawn in, and the safe area's the scoreboard is (portals): the HUD's own sits
	-- below Roblox's top bar; the end screen's dim's, the whole screen under them all.
	centre: ScreenGui,
	top: ScreenGui,
	dim: ScreenGui,
	-- Where a part hidden after its render threw is reported (#379).
	log: (line: string) -> (),
}

-- The Stage frame's size: the stage, or the whole Root while the stage is not known.
local function stageSize(stage: Vector2): UDim2
	return if stage.X > 0 and stage.Y > 0 then UDim2.fromOffset(stage.X, stage.Y) else UDim2.fromScale(1, 1)
end

-- A touch button's face, from its hint row's bindings (`row`).
local function touchFace(config: Config.GameConfig, control: Config.TouchControl, row: ControlHints.HintRow): React.Node
	local button, style = config.Input.touch.buttons[control], config.UI.touchStyle
	return React.createElement(TouchButton, {
		config = config,
		size = Vector2.new(button.size, button.size),
		corner = Style.ROUND,
		fill = if control == "jump" then style.jumpFill else style.fill,
		textSize = button.textSize,
		label = row.label,
		moving = row.cap,
		fade = row.fade,
	})
end

-- Puts each of `parts` behind its own error boundary (#379): one whose render throws shows nothing until the next
-- match (`match`), reported to `log` by its name, and the rest go on.
local function guarded(
	parts: { [string]: React.Node },
	match: number,
	log: (line: string) -> ()
): { [string]: React.Node }
	for name, part in parts do
		parts[name] = React.createElement(PartBoundary, { name = name, part = part, match = match, report = log })
	end
	return parts
end

local function App(props: AppProps): React.ReactElement
	local config, text, state, bindings = props.config, props.text, props.state, props.bindings
	local match, keys, ended = state.match, props.keys, state.ended
	local touch = props.device == Enum.PreferredInput.Touch
	local tabShown = props.tabShown
	local uncovered = not tabShown and ended == nil
	local compact, top, aim = props.compact, props.boardTop, props.aim
	local period = match ~= nil and text:period(match) ~= nil
	-- The match the scoreboard shows: none once it is over, when the end screen holds the final score.
	local scoreboard = if ended == nil then match else nil
	local banners = props.banners
	local feedLines = state:feedLines()
	local shownBanner = state.banner
	local lineSize = HudScreen.bannerSize(config, compact, if shownBanner ~= nil then shownBanner.kind else "Go")
	local viewer = Style.teamColor(config, HudState.teamOf(match, props.localId))
	-- Every part, the touch buttons' faces by control among them, each behind its own error boundary; placed below.
	local parts: { [string]: React.Node } = {
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
		Dim = if ended ~= nil
			then React.createElement("Frame", {
				Size = Style.FULL,
				BackgroundColor3 = config.UI.hud.look.ink,
				BackgroundTransparency = props.ending.scale.binding:map(function(scale: number): number
					return HudScreen.endDim(config, scale)
				end),
				BorderSizePixel = 0,
			})
			else nil,
		Scoreboard = if scoreboard ~= nil
			then React.createElement(Scoreboard, {
				config = config,
				text = text,
				match = scoreboard,
				compact = compact,
				top = top,
				clock = bindings.clock,
				motion = props.board,
			})
			else nil,
		ControlHints = if keys ~= nil and ended == nil
			then React.createElement(ControlHints, {
				config = config,
				keys = keys,
				rows = bindings.hints,
				area = bindings.area,
			})
			else nil,
		Speedometer = React.createElement(Speedometer, {
			config = config,
			speed = bindings.speed,
			color = viewer,
			touch = touch,
			compact = compact,
			visible = props.hasSkater and ended == nil,
		}),
		ScoreButton = if touch
			then React.createElement(ScoreButton, {
				config = config,
				left = bindings.lineUp,
				moving = bindings.scoreButton,
				onActivated = props.onScoreButton,
			})
			else nil,
		Banner = if uncovered
			then React.createElement(Banner, {
				config = config,
				text = text,
				banner = state.banner,
				compact = compact,
				line = HudScreen.bannerLine(config, compact, props.bannerAt, top, period, lineSize) - props.stageTop,
				scale = banners.line.scale.binding,
				leave = banners.line.leave,
				area = bindings.stage,
			})
			else nil,
		Message = if uncovered
			then React.createElement(Banner, {
				config = config,
				text = text,
				banner = state.message,
				compact = compact,
				scale = banners.message.scale.binding,
				leave = banners.message.leave,
				area = bindings.stage,
			})
			else nil,
		Feed = if uncovered
			then React.createElement(Feed, {
				config = config,
				text = text,
				feed = state.feed,
				lines = feedLines,
				chips = banners.chips,
				names = state.names,
				compact = compact,
				area = bindings.stage,
			})
			else nil,
		GetUp = if props.getUpKeys ~= nil and uncovered
			then React.createElement(GetUp, {
				config = config,
				keys = props.getUpKeys,
				compact = compact,
				lines = feedLines,
				scale = props.prompt.scale.binding,
				leave = props.prompt.leave.binding,
				area = bindings.stage,
			})
			else nil,
		EndScreen = if ended ~= nil and not tabShown
			then React.createElement(EndScreen, {
				config = config,
				text = text,
				ended = ended,
				names = state.names,
				localId = props.localId,
				area = bindings.stage,
				compact = compact,
				touch = touch,
				scale = props.ending.scale.binding,
			})
			else nil,
		ScoreTab = if tabShown and match ~= nil
			then React.createElement(ScoreTab, {
				config = config,
				text = text,
				stats = if ended ~= nil then ended.stats else match.stats,
				names = state.names,
				localId = props.localId,
				compact = compact,
				touch = touch,
				open = props.tabOpen,
				scale = props.tab.scale.binding,
				leave = props.tab.leave.binding,
				area = bindings.area,
				screen = bindings.screen,
				boardBottom = if scoreboard ~= nil
					then HudScreen.boardBottom(config, compact, top, period) - props.stageTop
					else 0,
				switchTeam = props.switchTeam,
			})
			else nil,
	}
	if touch then
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			parts[control] = touchFace(config, control, bindings.hints[control])
		end
	end
	guarded(parts, state.matchNumber, props.log)
	-- Each face drawn into its touch button.
	local faces: { [string]: React.Node } = {}
	if touch then
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			faces[control] = ReactRoblox.createPortal({ Face = parts[control] }, props.touchButtons[control])
		end
	end
	return React.createElement(React.Fragment, nil, {
		Centre = ReactRoblox.createPortal({ Reticle = parts.Reticle, Countdown = parts.Countdown }, props.centre),
		Dim = ReactRoblox.createPortal({ Dim = parts.Dim }, props.dim),
		Top = ReactRoblox.createPortal({ Scoreboard = parts.Scoreboard }, props.top),
		Touch = if touch then React.createElement(React.Fragment, nil, faces) else nil,
		Root = React.createElement("Frame", Style.holder({ Size = UDim2.fromScale(1, 1) }), {
			ControlHints = parts.ControlHints,
			Speedometer = parts.Speedometer,
			ScoreButton = parts.ScoreButton,
			-- Above the other parts.
			Stage = React.createElement("Frame", Style.holder(Style.above({ Size = bindings.stage:map(stageSize) })), {
				Banner = parts.Banner,
				Message = parts.Message,
				Feed = parts.Feed,
				GetUp = parts.GetUp,
				EndScreen = parts.EndScreen,
			}),
			ScoreTab = parts.ScoreTab,
		}),
	})
end

return App
