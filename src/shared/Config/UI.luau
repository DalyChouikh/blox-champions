--!strict
-- HUD settings (spec §11.2). The clock-warning marks also drive the rules' ClockWarning events (spec §5.1).
-- Team colors are the one source for everything drawn in a team's color (spawn pads, the HUD, the arena's glow).
-- Control labels name each control as it acts now: a touch button reads Dodge with the ball, Tackle without. Every
-- string the HUD shows, its style and layout, the world markers, the name tags and the arena's glow live here too.

local PartSize = require(script.Parent.Parent.Util.PartSize)
local Validate = require(script.Parent.Validate)

-- One label per action, plus the controls that start none (Ball Focus and the skating buttons) and the movement keys'
-- while knocked down.
export type ControlLabels = {
	Jump: string,
	-- The jump button in the air (#218).
	AirPose: string,
	Pump: string,
	Brake: string,
	Attach: string,
	Tackle: string,
	Dive: string,
	Dodge: string,
	Uppercut: string,
	ChargeThrow: string,
	RollBall: string,
	-- The Dodge while a throw charges: it drops the charge (#312), as RC's hint names it (Video 32 at 3.2 s).
	CancelDodge: string,
	Pass: string,
	CallPass: string,
	BallFocus: string,
	-- The Get Up prompt's words beside the movement keys while knocked down (#220): moving asks to get up, from
	-- Actions.getUpAfter (the whole slide since #287); kept as RC shows it (the owner, #303, Q88).
	GetUp: string,
}

-- A fill from `top` at a box's top to `bottom` at its bottom (Hud/Style.box).
export type Gradient = { top: Color3, bottom: Color3 }

-- How the touch controls look: the stick's ring on `background`, the knob and the Ball Focus ring in `foreground` (the
-- knob knobTransparency see-through), rounded by `corner`. The buttons are look C's (Hud/TouchButton): each filled
-- with `fill`, Jump with jumpFill, its words (Config.Input.touch's textSize at most) shrinking to fit within
-- textPadding pixels of its fill's sides.
export type TouchStyle = {
	background: Color3,
	backgroundTransparency: number,
	foreground: Color3,
	corner: UDim,
	textPadding: number,
	knobTransparency: number,
	fill: Gradient,
	jumpFill: Gradient,
}

-- Every string the HUD shows. %d stands for a number (%02d pads it to two digits) and %s for a name; a text takes
-- exactly the values noted.
export type UIText = {
	-- The clock's minutes and seconds (two values).
	clock: string,
	-- What a goal is worth while the goal is open (one value).
	goalWorth: string,
	overtime: string,
	goal: string,
	denied: string,
	-- The seconds left (one value).
	clockWarning: string,
	lastChance: string,
	-- The speedometer's reading (one value), over its unit.
	speed: string,
	speedUnit: string,
	-- The new holder's name (one value).
	possession: string,
	-- The streak (one value).
	lapCompleted: string,
	-- The team's name (one value).
	goalOpen: string,
	-- The scorer's name (one value).
	scored: string,
	-- The winning team's name (one value).
	wins: string,
	-- The end screen's MVP card: their score, goals and steals (three values); a team's total: its name in
	-- capitals and its score (#358).
	mvpLine: string,
	teamTotal: string,
	-- The end screen's headline when overtime runs out (the owner, Q95).
	draw: string,
	-- At GO, the player's own team's name in capitals (one value): Roller Champions' line (the owner, Q109).
	go: string,
	mvp: string,
	scores: string,
	columns: { player: string, score: string, goals: string, assists: string, saves: string, steals: string },
	-- A player the HUD has no name for.
	unknownPlayer: string,
	-- Over the teammate a pass would go to, on touch, where no key letter shows (#315).
	touchPassTarget: string,
	-- The Get Up prompt's key on touch, where the stick has none.
	touchMove: string,
	-- The score tab's button that moves the player to the other team (#310).
	switchTeam: string,
	-- The seconds left on a key cooling down (one value), and the mark beside a key just pressed (#354).
	cooldown: string,
	pressMark: string,
}

-- A colour for each team.
export type TeamColors = { Blue: Color3, Orange: Color3 }

-- A scoreboard's text sizes (pixels): the scores, the clock, the goal's worth and the period (OVERTIME, LAST CHANCE).
export type BoardTextSizes = { score: number, clock: number, worth: number, period: number }

-- The desktop scoreboard, S2 Shields (Hud/Scoreboard): position is its top centre's, from the top of the device's safe
-- area (in the top bar's free band, or under the bar where Roblox's buttons reach it: HudScreen); a team shield each
-- side of the clock's box, the goal's worth chip under the clock, and under the possessing team's shield a row of
-- square lap chips lapChip pixels across with chipCorner corners, chipGap apart, with chipClearance pixels of the game
-- showing between the shield's drop shadow and their outlines; gap between the other parts. Sizes are pixels.
export type ScoreboardLayout = {
	position: UDim2,
	shield: UDim2,
	clock: UDim2,
	worth: UDim2,
	lapChip: number,
	chipCorner: UDim,
	gap: number,
	chipGap: number,
	chipClearance: number,
	textSizes: BoardTextSizes,
}

-- The phone scoreboard, S5 Compact chips: one row, a score chip each side of the clock's box, the worth chip outside
-- the row beside the score of the team the goal is open for; placed as ScoreboardLayout is.
export type CompactScoreboardLayout = {
	position: UDim2,
	score: UDim2,
	clock: UDim2,
	worth: UDim2,
	gap: number,
	textSizes: BoardTextSizes,
}

-- A crosshair's two rings on one kind of screen (Hud/Reticle): the carrying ring and the charge ring, `carry` and
-- `charge` pixels across at their strokes' outer edges, the strokes `thickness` pixels wide over look C's ink.
export type RingSizes = { carry: number, charge: number, thickness: number }

-- The kickoff count on one kind of screen (Hud/Countdown): its digit textSize pixels tall inside a ring ringSize pixels
-- across at its stroke's outer edge, the stroke ringThickness pixels wide over look C's ink.
export type CountSizes = { textSize: number, ringSize: number, ringThickness: number }

-- The banners on one kind of screen (Hud/Banner, #356): text sizes in pixels, the headline's (GO, DENIED!, the
-- clock warnings, LAST CHANCE, OVERTIME), GOAL!'s, a completed lap's and the goal message's, each lettered in
-- look C's ink with a ring of its team's colour `edge` pixels wide round that.
export type BannerSizes = { headline: number, goal: number, lap: number, message: number, edge: number }

-- A mouse on a mouse button's key cap (#354, the owner's Q207): a body width x height pixels in look C's ink `line`
-- pixels thick, its buttons `buttons` pixels deep from its rounded top. Whole pixels (a UDim's offset drops a
-- fraction).
export type MouseSizes = { width: number, height: number, buttons: number, line: number }

-- A look C key cap (Hud/Style.keyCap): `height` pixels tall and as wide as its key's name with `padding` each side,
-- never narrower than tall, its corners `corner`, its name at textSize; with `mouse` (the hints') a mouse button's cap
-- square with a mouse on it, without it the button's name. With dropShadow it drops look C's shadow. Pixels.
export type CapSizes = {
	height: number,
	padding: number,
	corner: UDim,
	textSize: number,
	mouse: MouseSizes?,
	dropShadow: boolean?,
}

-- A line of the event feed (Hud/Feed, #369, the owner's Q221): a look C box `height` pixels tall with `corner`s, in
-- look.box; in it, its words at textSize, `inset` pixels from each side. Pixels.
export type FeedSizes = { height: number, corner: UDim, inset: number, textSize: number }

-- The Get Up prompt (Hud/GetUp, #369, the owner's Q221): the movement keys' caps `gap` pixels apart, then wordsGap,
-- then its words in the banners' lettering at textSize. Its ink's bottom sits `bottom` pixels above the stage's, higher
-- when the feed reaches there (HudScreen.getUpBottom). Pixels.
export type GetUpSizes = { bottom: number, cap: CapSizes, gap: number, wordsGap: number, textSize: number }

-- The end screen's parts on a desktop's screen or a phone's (Hud/EndScreen, #358, the owner's Q243): the MVP's card
-- cardWidth wide, `inset` in from its box's edges, their avatar `avatar` across beside the name (nameSize) with the
-- MVP chip (chipHeight tall, its word at chipSize) and a line of their numbers (statSize); each team's total on a
-- chip totalHeight tall at totalSize. Pixels.
export type EndSizes = {
	cardWidth: number,
	inset: number,
	avatar: number,
	nameSize: number,
	statSize: number,
	chipHeight: number,
	chipSize: number,
	totalHeight: number,
	totalSize: number,
}

-- The TAB board on one kind of screen (Hud/ScoreTab, #357, the owner's Q236, Q237): a look C box `width` pixels wide.
-- In it a header headHeight tall with the column names at headSize; then each team's bar, barHeight tall with its ink
-- line, its name and score at barSize; then its rows, rowHeight tall: an avatar circle `avatar` pixels across in its
-- ink, the name, then the five number columns, each `column` wide, all `gap` apart and `side` in from the box's edges,
-- at textSize. Switch team sits switchGap under the box's ink, its words at switchSize. Pixels.
export type TabSizes = {
	width: number,
	side: number,
	gap: number,
	avatar: number,
	column: number,
	rowHeight: number,
	textSize: number,
	headHeight: number,
	headSize: number,
	barHeight: number,
	barSize: number,
	switchGap: number,
	switchSize: number,
}

-- The desktop hints in look C (Hud/ControlHints): position is the column's right middle's. A row per control is a
-- look C box rowHeight pixels tall, with clearance pixels of the game between one row's drop shadow and the next
-- row's outline; in it, inset pixels from its left and right, the key's cap, then `gap`, then its label at
-- textSize, the key's cap sized by `cap`. A pressed key's mark (UI.text.pressMark) sits outside the row at
-- press.textSize, its right edge press.gap pixels left of the row's outline. Sizes are pixels.
export type HintsLayout = {
	position: UDim2,
	rowHeight: number,
	clearance: number,
	inset: { left: number, right: number },
	gap: number,
	textSize: number,
	cap: CapSizes,
	press: { textSize: number, gap: number },
}

-- Where each part of the HUD sits; sizes and row heights are pixels.
-- RC's ball badge (#376, Q265, Q266), in shares of its width but for `line` and `gap` (whole pixels): a white ball
-- inside a ring `ring` wide, crossed by its band's two lines `line` pixels thick, `band` either side of its middle and
-- leaning `lean` degrees; a right-angled pointer outside the ring, `pointer` tall, `gap` pixels of the game past the
-- ring's ink, turned toward the ball. The ring, the lines and the pointer in the team's colour, look C's ink before a
-- team has held the ball.
export type BadgeLook = { ring: number, band: number, line: number, lean: number, gap: number, pointer: number }
-- The next gate's chevron (#376, Q266): two rounded bars `bar` of its width thick, each arm leaning `spread` degrees
-- from the line it points along.
export type ChevronLook = { bar: number, spread: number }
-- Each screen marker's width in pixels.
export type MarkerSizes = { badge: number, chevron: number }

export type HudLayout = {
	-- A screen whose shorter side is under compactBelow pixels is a phone's: the compact scoreboard and the small
	-- speedometer (HudScreen.compact).
	compactBelow: number,
	scoreboard: ScoreboardLayout,
	compactScoreboard: CompactScoreboardLayout,
	-- The banners (#356, the owner's Q210): one line centred `height` of the way down the whole screen, lower where
	-- a banner's ink would come within `clearance` pixels of the scoreboard's (HudScreen.bannerLine); the goal
	-- message on a line of its own, its drop shadow `bottom` pixels above the stage's bottom, the feed above it
	-- (HudScreen.feedBottom). A leaving banner floats up `rise` of its text size as it fades. `sizes` on a
	-- desktop's screen, compactSizes on a phone's.
	banner: {
		height: number,
		clearance: number,
		bottom: number,
		rise: number,
		sizes: BannerSizes,
		compactSizes: BannerSizes,
	},
	-- The event feed's chips: `clearance` pixels of the game between one's drop shadow and the next one's outline.
	-- `sizes` on a desktop's screen, compactSizes on a phone's.
	feed: { clearance: number, sizes: FeedSizes, compactSizes: FeedSizes },
	hints: HintsLayout,
	-- position is the bottom-right corner's; on touch, touchPosition is the top-left corner's, clear of the touch
	-- buttons and the score button. The reading's digits over its unit, at textSizes, compactTextSizes on a phone.
	speedometer: {
		position: UDim2,
		touchPosition: UDim2,
		textSizes: { speed: number, unit: number },
		compactTextSizes: { speed: number, unit: number },
	},
	-- The crosshair (#312, #353), shown while the viewer carries the ball: its dot `size` pixels across, centred
	-- across the whole screen and `height` of the way down it (throws and passes aim through it), ringed by the
	-- carrying ring; over the first growShare of a throw's charge that ring grows out into the charge ring and fades,
	-- as the charge ring fills from its bottom up both sides, closing at a full charge; held full it blinks once every
	-- blinkSeconds. `sizes` on a desktop's screen, compactSizes on a phone's (HudScreen.compact). Rings that would come
	-- within `clearance` pixels of the scoreboard shrink round the dot (HudScreen.ringScale).
	reticle: {
		size: number,
		height: number,
		blinkSeconds: number,
		growShare: number,
		clearance: number,
		sizes: RingSizes,
		compactSizes: RingSizes,
	},
	-- The screen markers (#376, the owner's Q242, Q264-Q266): for the ball while it is off the screen, RC's ball
	-- badge (Video 31 at 21.0 s, Video 34 at 98.2 s); for the next gate while the viewer carries the ball, a bold
	-- chevron. A marker pinned to the screen's edge sits edgeGap pixels of the game inside the safe area (its ink
	-- counted), sliding along it to keep clearance pixels from the HUD's parts. `sizes` (each marker's width) on a
	-- desktop's screen, compactSizes on a phone's.
	markers: {
		edgeGap: number,
		clearance: number,
		badge: BadgeLook,
		chevron: ChevronLook,
		sizes: MarkerSizes,
		compactSizes: MarkerSizes,
	},
	-- The kickoff count (#353) at the crosshair's place, lower where its ring would come within reticle.clearance
	-- pixels of the scoreboard (HudScreen.countDrop): `sizes` on a desktop's screen, compactSizes on a phone's.
	countdown: { sizes: CountSizes, compactSizes: CountSizes },
	-- The TAB board (#357): `sizes` on a desktop's screen, compactSizes on a phone's (HudScreen.compact), kept `margin`
	-- pixels in from its area's edges (HudScreen.tabFit); its rows scroll on touch behind a bar scrollBar pixels wide,
	-- in the rows' right side.
	scoreTab: { margin: number, scrollBar: number, sizes: TabSizes, compactSizes: TabSizes },
	-- The touch button that opens the score tab: `size`, its top `top` pixels under Roblox's top bar (the HUD's
	-- area's top), its right edge lined up with the touch buttons' (Input/TouchArea.lineUp); a look C box `corner`
	-- rounded inside its ink, its words textSize pixels tall at most.
	scoreButton: { top: number, size: UDim2, corner: UDim, textSize: number },
	-- The end screen (Hud/EndScreen): its parts `gap` apart, at `sizes` on a desktop's screen and compactSizes on a
	-- phone's, over the whole screen dimmed in look.ink, `dim` see-through.
	endScreen: { gap: number, dim: number, sizes: EndSizes, compactSizes: EndSizes },
	-- The Get Up prompt: `sizes` on a desktop's screen, compactSizes on a phone's.
	getUp: {
		sizes: GetUpSizes,
		compactSizes: GetUpSizes,
	},
}

-- Look C, Bold arcade (Hud/Style): text in `font`, banners and the goal's worth in `bannerFont`, in the HUD's text
-- colour with an ink outline textOutline pixels thick. A box has `corner`s, an ink outline `outline` pixels wide and
-- an ink shadow dropping `shadow` pixels below it; it is its colour at the top and that colour times (1 - shade) at the
-- bottom. `box` colours a box that is no team's (the clock's, an empty lap chip); a team's parts take UI.teamColors
-- (Style.teamColor). bannerFont draws a digit's middle bannerDigitRise of its text size above its line's middle; a
-- digit centred in a shape moves down by that (Hud/Countdown). A key's cap is `key` with its name in ink, `pressed`
-- while it pops (the press's mark too); a cooling key's sweep is ink, sweepTransparency see-through.
export type LookSettings = {
	font: Enum.Font,
	bannerFont: Enum.Font,
	bannerDigitRise: number,
	ink: Color3,
	outline: number,
	shadow: number,
	textOutline: number,
	corner: UDim,
	box: Color3,
	shade: number,
	key: Color3,
	pressed: Color3,
	sweepTransparency: number,
	-- Empty pixels a group that fades parts as one (Style.fadeGroup) keeps round their ink: a CanvasGroup cuts off
	-- what reaches its edges, and where an edge falls between the screen's pixels it shaves ink touching it.
	groupRoom: number,
}

-- A bounce's shape (Hud/Motion.bounce): over `seconds`, a part goes to `scale` times its size, then to `rebound`
-- times it, then back to its size, in three equal parts.
export type BounceShape = { seconds: number, scale: number, rebound: number }

-- How the HUD's parts move (Hud/Motion), in seconds. A part popping in grows from nothing past its size by
-- `overshoot` of it, then settles; a bounce (a score that changes) grows past its size and comes back under it, a
-- press (a key pressed) shrinks under its size and springs back past it; a meter's part fills or empties, and a
-- part shrinks away, easing out over easeSeconds. The last lap chip stays full lapHoldSeconds before the row
-- empties for the next lap. A glow brightens (a white veil down to `transparency`) and dims once every
-- glow.seconds. The speedometer's reading eases toward the speed, closing speedRate of the gap a second.
export type MotionSettings = {
	pop: { seconds: number, overshoot: number },
	bounce: BounceShape,
	press: BounceShape,
	easeSeconds: number,
	lapHoldSeconds: number,
	glow: { seconds: number, transparency: number },
	speedRate: number,
}

-- How the HUD looks and how long its messages last. dimTransparency greys what would do nothing (a control, a hint,
-- the Switch team button: Style.dim); glowThickness (pixels) outlines the touch throw button while Ball Focus is on
-- and the viewer's row on the end screen. `look` and `motion` are look C's: the parts it restyles read them.
export type HudSettings = {
	font: Enum.Font,
	textColor: Color3,
	panel: Color3,
	panelTransparency: number,
	dimTransparency: number,
	corner: UDim,
	textSize: number,
	titleSize: number,
	-- How long a banner shows (a headline, also GOAL! outside a celebration; a completed lap) and the goal message.
	bannerSeconds: { headline: number, lap: number, message: number },
	feedSeconds: number,
	feedMaxEntries: number,
	glowThickness: number,
	-- Pixels between the parts of a panel, and inside its edge.
	spacing: number,
	-- Pixels kept clear at each edge of the HUD's area by a part shrunk to fit it (Style.fit).
	screenMargin: number,
	-- The HUD's guis draw at this order, over the touch controls' (Roblox's default, 0; #357); the end screen's dim one
	-- under it, over them too (#358).
	displayOrder: number,
	-- A Roblox user's avatar on the TAB board (HudText.avatar): a content id with %s for their UserId.
	avatarImage: string,
	look: LookSettings,
	motion: MotionSettings,
	layout: HudLayout,
}

-- The ball's ring (pixels: ringSize wider than the ball, so it rings it at any distance), its line and ground marker
-- (studs, the marker found within groundProbe studs below the ball). The screen's markers are the HUD's
-- (UI.hud.layout.markers, #376).
export type MarkerSettings = {
	ringSize: number,
	ringThickness: number,
	lineWidth: number,
	groundProbe: number,
	-- The ground marker is a disc this wide and this thick.
	groundMarkerSize: number,
	groundMarkerThickness: number,
	groundMarkerTransparency: number,
}

-- One part of the call's glove (#358, the owner's Q240 G3, Q241 E2), in the glove's own units from its middle: a bar
-- `width` x `height` with its top-left corner at (x, y) before it turns, its corners `corner` round, turned `turn`
-- degrees (clockwise) round the middle of its bottom edge, as a finger turns at its root.
export type GlovePart = { x: number, y: number, width: number, height: number, corner: number, turn: number }

-- A name tag on one kind of screen (NameTags, #358, the owner's Q197 M1 Stacked, Q198 H4): its gui `width` x
-- `height`, the name's pill on its middle (pillHeight tall, the name at textSize with pillInset each side). Above
-- the pill's ink, `gap` and a pointer `pointer` pixels tall (a square turned 45 degrees, half under the cap), the
-- pass key on look C's cap (`cap`); the call's badge (`badge` across its middle, a `rim` of ink) badgeGap beside
-- the cap, its glove `glove` pixels a glove unit, gloveDrop below the badge's middle, and its ring growing `ripple`
-- pixels out, rippleLine thick; the Attach mark (#381) badgeGap after the pass key, as tall as its cap, its word at
-- the cap's textSize with the cap's padding round it, as the design page drew it (the owner's Q247). Pixels.
export type TagSizes = {
	width: number,
	height: number,
	pillHeight: number,
	pillInset: number,
	textSize: number,
	cap: CapSizes,
	pointer: number,
	gap: number,
	badge: number,
	rim: number,
	ripple: number,
	rippleLine: number,
	badgeGap: number,
	glove: number,
	gloveDrop: number,
}

-- The call's motion (#358, the owner's Q198 H4): its badge's ring ripples out every rippleSeconds and its glove
-- waves waveDegrees each way, waveRate radians a second, round a point wavePivot glove units below its middle.
export type CallMotion = { rippleSeconds: number, waveDegrees: number, waveRate: number, wavePivot: number }

-- The name tags (#358): the pill's ink resting studsOffset studs above a player's root, at `sizes` on a desktop's
-- screen and compactSizes on a phone's; how the call moves while a teammate calls; its glove: `parts` in white over
-- their ink, each grown `ink` glove units all round, `seams` in ink on top.
export type NameTagSettings = {
	studsOffset: Vector3,
	sizes: TagSizes,
	compactSizes: TagSizes,
	call: CallMotion,
	glove: { ink: number, parts: { GlovePart }, seams: { GlovePart } },
}

-- The fire lines (#412, the owner's Q300-Q303 and Q329; Arena spec §5.4): one line a lap of the streak, along the
-- outer wall from each gate passed to the next, `thickness` studs across, lap 1's at the wall's glass line
-- (Arena.glassLook.outerWall) and each next lap's `spacing` higher. A gate passed sends a fireball `fireball` studs
-- across after `delaySeconds`, flying on to the next gate in `flightSeconds` with its line growing behind it; the
-- lines fade out over `fadeSeconds` when the streak ends.
export type FireLineSettings = {
	thickness: number,
	spacing: number,
	fireball: number,
	delaySeconds: number,
	flightSeconds: number,
	fadeSeconds: number,
}

-- The goal's lip and strips (the ring's blocks before its meshes come), the next gate's panel and the fire lines
-- glow in `material`; the goal's door opens and shuts over doorSeconds (Arena spec §5.3).
export type ArenaGlowSettings = {
	material: Enum.Material,
	doorSeconds: number,
	fireLines: FireLineSettings,
}

-- The goal's worth in its open middle (#411, the owner's Q294; Arena spec §5.3): a disc in the open team's colour,
-- glowing as the next gate's marker does (arenaGlow.material at Arena.glass.transparency, Q327), `thickness` studs
-- thick and `fill` of the opening's diameter across, `behind` studs
-- behind the door's plane so the door's bars and the disc never meet; on both its faces the worth (HudText.worth)
-- in the banners' lettering, `textHeight` of the disc's diameter tall, popping in with the banners' pop.
export type GoalWorthSettings = {
	thickness: number,
	fill: number,
	textHeight: number,
	behind: number,
}

-- The skates' fire (#413, the owner's Q298): a ribbon `width` studs across, `lift` studs over each skate's sole,
-- `lifetime` seconds of travel long (so longer with speed), showing while the skater moves at `minSpeed` studs/s or
-- more, drawn in the team's colour at `brightness` times its light (Q331), `transparency` see-through at the skate and
-- `fade.transparency` at `fade.from` of the way back, where it starts fading to nothing at its tail.
export type SkateFireSettings = {
	width: number,
	lift: number,
	lifetime: number,
	minSpeed: number,
	brightness: number,
	transparency: number,
	fade: { from: number, transparency: number },
}

-- The trail behind a thrown, passed or rolled ball on every screen (§9.4, #313): `lifetime` seconds long and `width`
-- studs wide in `color`, `transparency` see-through behind the ball, fading to nothing at its end.
export type BallTrailSettings = { lifetime: number, width: number, color: Color3, transparency: number }

export type UIConfig = {
	clockWarnings: { number },
	-- The team colours, one pair for the world and the HUD: the arena's glow and pads, the fire lines, the ball, the
	-- markers, the name tags and every HUD part in a team's colour (Hud/Style.teamColor).
	teamColors: TeamColors,
	teamNames: { Blue: string, Orange: string },
	controlLabels: ControlLabels,
	-- What a hint calls a key Roblox gives no name to, by its Enum.KeyCode name.
	keyNames: { [string]: string },
	touchStyle: TouchStyle,
	text: UIText,
	hud: HudSettings,
	markers: MarkerSettings,
	nameTag: NameTagSettings,
	arenaGlow: ArenaGlowSettings,
	goalWorth: GoalWorthSettings,
	skateFire: SkateFireSettings,
	ballTrail: BallTrailSettings,
}

local defaults: UIConfig = {
	clockWarnings = { 60, 30 },
	-- Roller Champions' blue #0eb2f7 and orange #ea5e0f, read from the owner's Video 36 (the owner's Q316, then Q318
	-- after playing four options): they glow true in Neon, where the old world orange #da8541 glowed yellow, and a lit
	-- lap chip still reads against an empty one, so the HUD's lighter pair (Q201) went.
	teamColors = { Blue = Color3.fromRGB(14, 178, 247), Orange = Color3.fromRGB(234, 94, 15) },
	teamNames = { Blue = "Blue", Orange = "Orange" },
	controlLabels = {
		Jump = "Jump",
		AirPose = "Air Pose",
		Pump = "Pump",
		Brake = "Brake",
		Attach = "Attach",
		Tackle = "Tackle",
		Dive = "Dive",
		Dodge = "Dodge",
		Uppercut = "Uppercut",
		ChargeThrow = "Throw",
		-- RC's hints while a throw charges (#312; Video 32 at 3.2 s).
		RollBall = "Roll Ball",
		CancelDodge = "Cancel & Dodge",
		-- RC's name for it (#315, the owner: Q103; Video 34 at 41.6 s).
		Pass = "Magnetic Pass",
		CallPass = "Call",
		BallFocus = "Focus",
		GetUp = "GET UP!",
	},
	-- Roblox's GetStringForKeyCode gives these "" (or " " for Space).
	keyNames = {
		Space = "Space",
		LeftShift = "Shift",
		RightShift = "Shift",
		LeftControl = "Ctrl",
		RightControl = "Ctrl",
		Tab = "Tab",
		MouseLeftButton = "LMB",
		MouseRightButton = "RMB",
	},
	-- Roblox's own touch thumbstick colors; the art pass restyles them. The buttons' fills are the design page's,
	-- as the owner played them (#355, Q249; measured in the trial's shot): a deep blue, Jump orange.
	touchStyle = {
		background = Color3.fromRGB(18, 18, 21),
		backgroundTransparency = 0.4,
		foreground = Color3.fromRGB(213, 215, 221),
		corner = UDim.new(0.5, 0),
		textPadding = 6,
		knobTransparency = 0,
		fill = { top = Color3.fromRGB(58, 69, 102), bottom = Color3.fromRGB(28, 35, 64) },
		jumpFill = { top = Color3.fromRGB(255, 178, 90), bottom = Color3.fromRGB(232, 116, 28) },
	},
	text = {
		clock = "%d:%02d",
		-- The scoreboard's worth chip (#352): +1, +3 or +5 (the owner, Q188: the worth lives in the scoreboard).
		goalWorth = "+%d",
		overtime = "OVERTIME",
		goal = "GOAL!",
		denied = "DENIED!",
		clockWarning = "%d SECONDS",
		lastChance = "LAST CHANCE",
		-- Big digits over a small KM/H, as Roller Champions reads it (the owner, Q192).
		speed = "%d",
		speedUnit = "KM/H",
		possession = "%s has the ball",
		-- Banners now (#356, the owner's Q210-Q211), in capitals like the others; the team's name capitalised as in GO.
		lapCompleted = "LAP %d COMPLETED",
		goalOpen = "%s GOAL IS ACTIVE!",
		scored = "%s scored!",
		-- In the banners' capitals (#358, the owner's Q243: the result in GOAL!'s lettering).
		wins = "%s WINS!",
		mvpLine = "Score %d \u{B7} Goals %d \u{B7} Steals %d",
		teamTotal = "%s %d",
		draw = "DRAW",
		go = "GO %s TEAM!",
		mvp = "MVP",
		scores = "SCORES",
		columns = {
			player = "Player",
			score = "Score",
			goals = "Goals",
			assists = "Assists",
			saves = "Saves",
			steals = "Steals",
		},
		unknownPlayer = "Player",
		-- On the pass key's cap over its target on touch, which has no key: RC floats the pass key's letter there
		-- (Video 34 at 41.6 s); M1 drew a PASS chip on phones (#358, the owner's Q197).
		touchPassTarget = "PASS",
		touchMove = "Move",
		switchTeam = "Switch team",
		-- A cooling key's seconds left, to a tenth, as the page wrote them (#354, Q186); RC's >> beside a key
		-- just pressed, as the page drew it.
		cooldown = "%.1f",
		pressMark = "\u{BB}",
	},
	-- The HUD's graybox look, which the Presentation part's issues replace part by part with look C (`look`).
	hud = {
		font = Enum.Font.BuilderSansBold,
		textColor = Color3.fromRGB(245, 245, 245),
		panel = Color3.fromRGB(18, 18, 21),
		panelTransparency = 0.35,
		-- The owner's choice (2026-10-24).
		dimTransparency = 0.6,
		corner = UDim.new(0, 8),
		textSize = 20,
		titleSize = 32,
		-- Roller Champions' times, measured frame by frame (#356): GO shows 2.5 s (Video 31 at 20.9 s), a completed
		-- lap 3.6 s and the goal message about 5 s (Video 4 at 7:22.7).
		bannerSeconds = { headline = 2.5, lap = 3.6, message = 5 },
		feedSeconds = 6,
		-- One ball line at a time (the owner, Q227) leaves room for lines about points. Five lines pushed the Get Up
		-- prompt into the banner line on a phone (measured, Q230); with three it stays clear, under GOAL! too.
		feedMaxEntries = 3,
		glowThickness = 3,
		spacing = 6,
		screenMargin = 8,
		-- On a phone the open TAB board covers the touch buttons (the owner, Q236), so the HUD draws over their gui.
		-- The end screen's dim covers them too, as they do nothing then, while SCORES, in the HUD, stays bright.
		displayOrder = 2,
		-- Roblox's headshot of a user, which loads without yielding; 48 px is its smallest size (probed in Studio: a
		-- real user's loads in ~0.6 s, an unknown id fails and prints nothing).
		avatarImage = "rbxthumb://type=AvatarHeadShot&id=%s&w=48&h=48",
		-- Look C, Bold arcade (the owner, Q184: chunky rounded shapes, thick dark outlines and drop shadows, Fredoka
		-- with Luckiest Guy banners), as the private design page drew it: ink #0b0e18, 3 px outlines, a 4 px shadow,
		-- 14 px corners, the clock's box #2a3350, darker toward the bottom (the page's #2a3350 -> #161c30; its team
		-- boxes about 0.6 as bright at the bottom). Both fonts are Roblox's own.
		look = {
			font = Enum.Font.FredokaOne,
			bannerFont = Enum.Font.LuckiestGuy,
			-- Luckiest Guy's 1 to 5, measured in Studio at a 100 px text size: their ink's middle 15.0 to 16.5 px
			-- above the line's (the owner saw the count's digit sit high in its ring, Q204).
			bannerDigitRise = 0.16,
			ink = Color3.fromRGB(11, 14, 24),
			outline = 3,
			shadow = 4,
			textOutline = 2.5,
			corner = UDim.new(0, 14),
			box = Color3.fromRGB(42, 51, 80),
			shade = 0.4,
			-- The page's key caps (#354): #ffd23f with ink lettering, #ff8a2c while pressed (the page drew RC's >>
			-- beside it in a near orange, #f08a2c: one colour here), and its cooldown's 62% black sweep (Q186).
			key = Color3.fromRGB(255, 210, 63),
			pressed = Color3.fromRGB(255, 138, 44),
			sweepTransparency = 0.38,
			-- 2 px keep a disc's sides as round as with no group (probed on the phone emulator: the owner saw the touch
			-- buttons' sides, then Switch team's cap, cut; #355 Q254, #383).
			groupRoom = 2,
		},
		-- Every HUD change animates briefly, from settings (the owner, Q194), at the page's timings: a pop to 1.12 then
		-- 1 (its banners), a score's bounce to 1.55, back to 0.9, then 1 in 0.4 s, its lap chips filling in 0.25 s
		-- easing out, the worth chip glowing brighter and back over 2.4 s, the speed easing at 6 a second. The last
		-- lap chip shows full for half a second before the row empties (the owner, Q196).
		motion = {
			pop = { seconds = 0.2, overshoot = 0.12 },
			bounce = { seconds = 0.4, scale = 1.55, rebound = 0.9 },
			-- A pressed key pops (the owner, Q186) as the page drew it: held in to 0.88 for 0.3 s, then sprung back
			-- past its size to its press keyframes' 1.06. RC's >> shows ~0.13 s (Video 24); ours keeps the page's 0.3.
			press = { seconds = 0.3, scale = 0.88, rebound = 1.06 },
			easeSeconds = 0.25,
			lapHoldSeconds = 0.5,
			glow = { seconds = 2.4, transparency = 0.8 },
			speedRate = 6,
		},
		layout = {
			-- Roblox's own touch controls grow on a screen whose shorter side passes 500 px (its DynamicThumbstick,
			-- read from its PlayerModule): below that, a phone. The phone emulator is 750 x 381.
			compactBelow = 500,
			-- S2 Shields on desktop (the owner, Q195/Q196), at the page's sizes: it drew the desktop 1280 wide over our
			-- 1556 x 793 Play view, so 1.2 px a unit (a 78 x 74 shield, a 46 px score, a 34 px clock, 6-unit lap chip
			-- corners); the lap chips square and of one size (Q196).
			scoreboard = {
				position = UDim2.new(0.5, 0, 0, 8),
				shield = UDim2.fromOffset(94, 89),
				clock = UDim2.fromOffset(120, 56),
				worth = UDim2.fromOffset(56, 38),
				lapChip = 17,
				chipCorner = UDim.new(0, 7),
				gap = 12,
				chipGap = 6,
				-- The owner, on #352's screenshots (Q200): the chips touched the shield; "bring them down a bit, just a
				-- little".
				chipClearance = 3,
				textSizes = { score = 55, clock = 41, worth = 26, period = 22 },
			},
			-- S5 Compact chips on phones (Q196), at the page's phone sizes, drawn 750 wide: one point a unit.
			compactScoreboard = {
				position = UDim2.new(0.5, 0, 0, 8),
				score = UDim2.fromOffset(52, 44),
				clock = UDim2.fromOffset(80, 44),
				worth = UDim2.fromOffset(48, 34),
				gap = 8,
				textSizes = { score = 38, clock = 30, worth = 22, period = 18 },
			},
			-- The banners as the design page drew them (the owner, Q210): GO's line 22% of the way down, where Roller
			-- Champions centres it (Video 31 at 20.9 s), 3 px of the game kept under the scoreboard as for the
			-- crosshair (Q203); the goal message at the bottom centre (RC's 94%, Video 4 at 7:23), in the feed's old
			-- place. The page's round 4 sizes at 1.2 px a unit (GO 42, GOAL! 56, the lap 30, the message 24 units); on
			-- a phone ~1.3x their share of the screen (Q191).
			banner = {
				height = 0.22,
				clearance = 3,
				bottom = 24,
				rise = 0.4,
				sizes = { headline = 50, goal = 67, lap = 36, message = 29, edge = 3 },
				compactSizes = { headline = 32, goal = 43, lap = 23, message = 18, edge = 2 },
			},
			-- Look C chips (the owner, Q221) with no team edge (Q226), at the design page's sizes (a 34 px chip with
			-- its 2.5 px outline, 18 px text); on a phone a little smaller, still big and clear (Q181). One chip's drop
			-- shadow clear of the next one's outline by the hints' 3 px.
			feed = {
				clearance = 3,
				sizes = { height = 30, corner = UDim.new(0, 10), inset = 10, textSize = 18 },
				compactSizes = { height = 24, corner = UDim.new(0, 8), inset = 8, textSize = 15 },
			},
			-- Look C's hints (#354), at the page's sizes (1.2 px a unit: 34-unit rows 6 apart, a 28-unit cap, 18-unit
			-- labels), in today's place at the right; RC's >> outside the row, over the game (the owner, Q195b),
			-- where the page drew it: its left edge 30 px from the row's outline (a 14 px mark).
			hints = {
				position = UDim2.new(1, -24, 0.5, 0),
				rowHeight = 41,
				clearance = 3,
				inset = { left = 5, right = 12 },
				gap = 11,
				textSize = 22,
				-- A mouse button's key a 16 x 24 mouse on its cap (the owner's Q207: A1, as the design page's Studio
				-- render drew it).
				cap = {
					height = 34,
					padding = 8,
					corner = UDim.new(0, 10),
					textSize = 17,
					mouse = { width = 16, height = 24, buttons = 10, line = 2 },
				},
				press = { textSize = 24, gap = 16 },
			},
			-- Big digits in the viewer's team colour over a small KM/H, bottom right on desktop and small top left on
			-- phones, where the touch buttons take the right side (the owner, Q192), at the page's sizes (46 and 14
			-- units on desktop; 30 and 12 on the phone, 4 px under Roblox's top bar).
			speedometer = {
				position = UDim2.new(1, -31, 1, -22),
				touchPosition = UDim2.fromOffset(18, 4),
				textSizes = { speed = 55, unit = 17 },
				compactTextSizes = { speed = 30, unit = 12 },
			},
			-- RC's crosshair (#312): above the skater, 31.5% down the screen (Video 32 at 2.0-4.4 s, Video 13 at 99.0
			-- s; the owner kept it in trial #311, Q123/Q127); its charge ring, read at 1918 x 1078 (Video 32 at 3.2 s),
			-- 130 px across with a ~4 px stroke. Closed and held, it blinks until the release (the owner, Q142): Video
			-- 32 at 30 fps lit at 3.67, 4.07 and 4.47 s, nearly gone at 3.47, 3.87 and 4.27 s: once every 0.4 s. X1
			-- (the owner, Q185/Q188b): RC's small carrying ring (~55-60 px, Video 32 at 2.4 s; Q143) at the design
			-- page's share of the charge ring (61 px), growing into it and fading over the charge's first quarter as
			-- the page drew it; on a phone the page's 46 and 24 px with a 3 px stroke (Q203). 3 px of the game kept
			-- between the rings and the scoreboard, as between the lap chips and the shield (Q200).
			reticle = {
				size = 6,
				height = 0.315,
				blinkSeconds = 0.4,
				growShare = 0.25,
				clearance = 3,
				sizes = { carry = 61, charge = 130, thickness = 4 },
				compactSizes = { carry = 24, charge = 46, thickness = 3 },
			},
			-- RC's ball badge measured in Video 34 at 98.2 s (79 px across at 1918 x 1078: the ring 9 px, the band's
			-- lines 16 px either side of the middle, 3 px thick, a pointer 21 x 11.5 px apart from the ring), its
			-- pointer a right angle and further out so look C's ink keeps it apart (Q266); the gate's chevron with a
			-- 60 degree tip (a right angle read as an "L"); the page's sizes (Q264): RC's 79 px at 1078 px tall is
			-- about 52 at our 793; on phones bigger than RC's share. 3 px of the game kept from the HUD's parts (Q203).
			markers = {
				edgeGap = 10,
				clearance = 3,
				badge = { ring = 0.115, band = 0.2, line = 2, lean = -12, gap = 5, pointer = 0.17 },
				chevron = { bar = 0.3, spread = 30 },
				sizes = { badge = 52, chevron = 40 },
				compactSizes = { badge = 34, chevron = 28 },
			},
			-- The kickoff count a third down, where RC's sits (the owner, Q185): on desktop RC's at 1918 x 1078 (Video
			-- 31 at 16.5 s), a 200 px ring with a 75 px digit (Q108); on a phone RC's share of the screen's height (a
			-- 76 px ring) with a bigger digit, big and clear on phones (Q181), as the design page drew it (Q203).
			countdown = {
				sizes = { textSize = 76, ringSize = 200, ringThickness = 8 },
				compactSizes = { textSize = 40, ringSize = 76, ringThickness = 4 },
			},
			-- One compact table on desktop and phones (the owner, Q236, Q237), at the design page's sizes: 19 px rows
			-- 800 wide on desktop, 17 px rows 610 wide on a phone, each avatar 32 or 26 px across with its ink as the
			-- page drew it, rows one pixel shorter than the page's on a phone so that a 3-a-side board fits under the
			-- SCORES button with margin pixels to spare. Rows scroll on touch behind a thin bar in their side.
			scoreTab = {
				margin = 3,
				scrollBar = 6,
				sizes = {
					width = 800,
					side = 12,
					gap = 6,
					avatar = 27,
					column = 76,
					rowHeight = 38,
					textSize = 19,
					headHeight = 23,
					headSize = 14,
					barHeight = 31,
					barSize = 20,
					switchGap = 10,
					switchSize = 18,
				},
				compactSizes = {
					width = 610,
					side = 8,
					gap = 6,
					avatar = 21,
					column = 58,
					rowHeight = 27,
					textSize = 17,
					headHeight = 15,
					headSize = 11,
					barHeight = 25,
					barSize = 17,
					switchGap = 4,
					switchSize = 15,
				},
			},
			-- S2 (#355, the owner's Q250): today's 96 x 36, 16 px under Roblox's top bar (74 px from a phone's top),
			-- lined up with Jump; the design page's 10 px corner outside its 3 px ink, and its 17 px words.
			scoreButton = { top = 16, size = UDim2.fromOffset(96, 36), corner = UDim.new(0, 7), textSize = 17 },
			-- Today's parts in look C (#358, the owner's Q243), at the design page's sizes: the result in GOAL!'s
			-- lettering, the MVP's card, the team totals on chips, then the TAB board's table (not on touch), the game
			-- half-dimmed behind them.
			endScreen = {
				gap = 16,
				dim = 0.5,
				sizes = {
					cardWidth = 400,
					inset = 12,
					avatar = 44,
					nameSize = 21,
					statSize = 15,
					chipHeight = 24,
					chipSize = 14,
					totalHeight = 34,
					totalSize = 22,
				},
				compactSizes = {
					cardWidth = 350,
					inset = 10,
					avatar = 40,
					nameSize = 19,
					statSize = 14,
					chipHeight = 22,
					chipSize = 13,
					totalHeight = 28,
					totalSize = 17,
				},
			},
			-- At the bottom centre like Roller Champions' prompt (Video 5 at 0:18), banner style (the owner, Q221), at
			-- the design page's sizes: 46 px caps with their drop shadow, GET UP! in the banners' font at 40, 104 px
			-- up. On a phone the hints' own cap size and a banner's share of the screen (Q191).
			getUp = {
				sizes = {
					bottom = 104,
					gap = 9,
					wordsGap = 15,
					textSize = 40,
					cap = { height = 46, padding = 11, corner = UDim.new(0, 13), textSize = 21, dropShadow = true },
				},
				compactSizes = {
					bottom = 72,
					gap = 6,
					wordsGap = 10,
					textSize = 28,
					cap = { height = 34, padding = 8, corner = UDim.new(0, 10), textSize = 17, dropShadow = true },
				},
			},
		},
	},
	markers = {
		ringSize = 56,
		ringThickness = 3,
		lineWidth = 0.2,
		groundProbe = 100,
		groundMarkerSize = 4,
		groundMarkerThickness = 0.2,
		groundMarkerTransparency = 0.4,
	},
	-- M1 Stacked with H4's badge and the E2 glove (#358, the owner's Q197, Q198, Q240, Q241), over the head of a body
	-- 4 studs up to its head's top (measured in Play), at the design page's
	-- proportions: its key cap 24 units, the hints' 34 px cap on desktop (1.42 px a unit), about 1.05 on a phone.
	nameTag = {
		studsOffset = Vector3.new(0, 4, 0),
		sizes = {
			width = 240,
			height = 184,
			pillHeight = 26,
			pillInset = 9,
			textSize = 18,
			cap = { height = 34, padding = 8, corner = UDim.new(0, 10), textSize = 17, dropShadow = false },
			pointer = 9,
			gap = 2,
			badge = 24,
			rim = 4,
			ripple = 20,
			rippleLine = 4,
			badgeGap = 3,
			glove = 1,
			gloveDrop = 3,
		},
		compactSizes = {
			width = 190,
			height = 140,
			pillHeight = 20,
			pillInset = 7,
			textSize = 14,
			cap = { height = 24, padding = 6, corner = UDim.new(0, 8), textSize = 13, dropShadow = false },
			pointer = 7,
			gap = 2,
			badge = 18,
			rim = 3,
			ripple = 15,
			rippleLine = 3,
			badgeGap = 2,
			glove = 0.76,
			gloveDrop = 2,
		},
		-- H4: a ring every second, the glove waving 12 degrees each way (the page's 12 sin 8t).
		call = { rippleSeconds = 1, waveDegrees = 12, waveRate = 8, wavePivot = 10 },
		-- E2 (Q241): G3's four straight fingers with seams, the palm, a pad under the thumb that carries the outline
		-- from the wrist up into the thumb in one curve.
		glove = {
			ink = 2.5,
			parts = {
				{ x = -9, y = -6, width = 18, height = 16, corner = 5, turn = 0 },
				{ x = -9, y = -15, width = 4.5, height = 12, corner = 2.25, turn = 0 },
				{ x = -4.5, y = -19, width = 4.5, height = 16, corner = 2.25, turn = 0 },
				{ x = 0, y = -18, width = 4.5, height = 15, corner = 2.25, turn = 0 },
				{ x = 4.5, y = -14, width = 4.5, height = 11, corner = 2.25, turn = 0 },
				{ x = -9, y = -2, width = 7, height = 12, corner = 3.5, turn = -4 },
				{ x = -9.6, y = -6, width = 5, height = 12, corner = 2.5, turn = -26 },
			},
			seams = {
				{ x = -4.95, y = -13, width = 0.9, height = 9, corner = 0.45, turn = 0 },
				{ x = -0.45, y = -16, width = 0.9, height = 12, corner = 0.45, turn = 0 },
				{ x = 4.05, y = -12, width = 0.9, height = 8, corner = 0.45, turn = 0 },
			},
		},
	},
	arenaGlow = {
		material = Enum.Material.Neon,
		doorSeconds = 0.4,
		-- The fireball leaves a quarter second after the gate (RC Video 36 at 43.75-44.0 s) and reaches the next in a
		-- second, as the design page drew it (Q301); the lines fade in 0.3 s (Q303).
		fireLines = {
			thickness = 0.8,
			spacing = 2,
			fireball = 2.4,
			delaySeconds = 0.25,
			flightSeconds = 1,
			fadeSeconds = 0.3,
		},
	},
	-- Filling the opening (Q327), the number about a radius tall as the design page drew it (Q294).
	goalWorth = { thickness = 0.2, fill = 1, textHeight = 0.55, behind = 0.5 },
	-- Look G (Q331), as Studio Play showed it: about a skate wide; over the sole by more than the 0.26 studs a sole
	-- dips into the floor while skating (measured), so the floor never hides it; 0.4 s of travel, about 6 body heights
	-- at softCap, nearly solid for its first half like RC's (Video 36 at 42.1 s); from a crawl up, so standing still
	-- (an idle pose's foot sway) leaves none; three times as bright as its colour, so it glows as the gate markers'
	-- Neon does (orange toward amber, blue a neon cyan).
	skateFire = {
		width = 0.8,
		lift = 0.3,
		lifetime = 0.4,
		minSpeed = 2,
		brightness = 3,
		transparency = 0.1,
		fade = { from = 0.6, transparency = 0.35 },
	},
	-- The owner asked for a trail behind the ball (Q98; RC's thrown ball leaves a white streak, Video 4 at
	-- 366.8-367.0 s and Video 31 at 39.1 s; Illegal Soccer's a white dashed one), white as the crosshair is (Q141)
	-- and behind a team-coloured ball too, as RC's (Q160), and bolder once a thin faint one was seen from the side
	-- (Q146): as wide as the ball, solid at it, 0.4 s long: 96 studs behind a full throw (16 body lengths).
	ballTrail = { lifetime = 0.4, width = 2, color = Color3.new(1, 1, 1), transparency = 0 },
}

local function noDuplicates(values: { number }): boolean
	local seen: { [number]: boolean } = {}
	for _, value in values do
		if seen[value] then
			return false
		end
		seen[value] = true
	end
	return true
end

-- How many values `text` takes: its %d, %s and %f, each with an optional width and precision (%02d, %.1f). A
-- doubled %% prints a percent sign and takes none, so it is dropped first.
local function placeholders(text: string): number
	local plain = string.gsub(text, "%%%%", "")
	local _, count = string.gsub(plain, "%%[%d%.]*[dsf]", "")
	return count
end

local label = Validate.string({ nonEmpty = true })

local function template(count: number): Validate.Validator
	return Validate.check(label, function(text: string): boolean
		return placeholders(text) == count
	end, `placeholder count must be {count}`)
end

-- Every KeyCode name, so keyNames can only name keys that exist.
local keyCodeNames: { [string]: boolean } = {}
for _, item in Enum.KeyCode:GetEnumItems() do
	keyCodeNames[item.Name] = true
end

-- A table of names keyed by KeyCode name; each error names the bad key.
local function keyNames(value: any, path: string): { string }
	if type(value) ~= "table" then
		return { `{path}: expected table, got {typeof(value)}` }
	end
	local errors: { string } = {}
	for key, name in value do
		if type(key) ~= "string" or not keyCodeNames[key] then
			table.insert(errors, `{path}: {tostring(key)} must name a key`)
		else
			for _, nameError in label(name, `{path}.{key}`) do
				table.insert(errors, nameError)
			end
		end
	end
	table.sort(errors)
	return errors
end

local textSize = Validate.textSize()
local transparency = Validate.number({ min = 0, max = 1 })
-- A transparency that still shows something.
local seen = Validate.number({ min = 0, below = 1 })
local positive = Validate.number({ above = 0 })
-- A part's size along one axis, inside the limits Roblox would silently clamp it to.
local partSize = Validate.number({ min = PartSize.MIN, max = PartSize.MAX })
local udim2 = Validate.datatype("UDim2")
local pixels = Validate.pixels()
-- Whole pixels, where a UDim's offset would drop a fraction (probed).
local wholePixels = Validate.number({ min = 1, integer = true })
local gradient = Validate.record({ top = Validate.datatype("Color3"), bottom = Validate.datatype("Color3") })
local nonNegative = Validate.number({ min = 0 })
-- Whole pixels or none.
local wholeOrNone = Validate.number({ min = 0, integer = true })
-- The TAB board's offsets (Hud/ScoreTab) in whole pixels, so its rows and bars meet on pixel edges.
local tabSizes = Validate.record({
	width = wholePixels,
	side = wholeOrNone,
	gap = wholeOrNone,
	avatar = wholePixels,
	column = wholePixels,
	rowHeight = wholePixels,
	textSize = textSize,
	headHeight = wholePixels,
	headSize = textSize,
	barHeight = wholePixels,
	barSize = textSize,
	switchGap = wholeOrNone,
	switchSize = textSize,
})
local boardTextSizes = Validate.record({ score = textSize, clock = textSize, worth = textSize, period = textSize })
local speedTextSizes = Validate.record({ speed = textSize, unit = textSize })
local ringSizes = Validate.record({ carry = positive, charge = positive, thickness = positive })
-- The screen markers' widths, and the badge's lines and gap, in whole pixels, so their edges meet pixel edges.
local markerSizes = Validate.record({ badge = wholePixels, chevron = wholePixels })
local badgeLook = Validate.check(
	Validate.record({
		ring = positive,
		band = positive,
		line = wholePixels,
		lean = Validate.number({ min = -90, max = 90 }),
		gap = wholeOrNone,
		pointer = positive,
	}),
	function(badge: BadgeLook): boolean
		return badge.band < 0.5 - badge.ring
	end,
	"the band's lines must lie inside the ball (band < 0.5 - ring)"
)
local countSizes = Validate.record({ textSize = textSize, ringSize = positive, ringThickness = positive })
local bannerSizes = Validate.record({
	headline = textSize,
	goal = textSize,
	lap = textSize,
	message = textSize,
	edge = nonNegative,
})
local feedSizes = Validate.record({
	height = positive,
	corner = Validate.datatype("UDim"),
	inset = nonNegative,
	textSize = textSize,
})
-- A key cap drawn alone (the Get Up prompt's, a name tag's pass key), with or without look C's drop shadow.
local capSizes = Validate.record({
	height = positive,
	padding = nonNegative,
	corner = Validate.datatype("UDim"),
	textSize = textSize,
	dropShadow = Validate.boolean(),
})
local getUpSizes = Validate.record({
	bottom = nonNegative,
	gap = nonNegative,
	wordsGap = nonNegative,
	textSize = textSize,
	cap = capSizes,
})
-- A name tag's sizes (NameTags) in whole pixels where its boxes meet; the glove's scale and drop may be fractions.
local tagSizes = Validate.record({
	width = wholePixels,
	height = wholePixels,
	pillHeight = wholePixels,
	pillInset = wholeOrNone,
	textSize = textSize,
	cap = capSizes,
	pointer = wholePixels,
	gap = wholeOrNone,
	badge = wholePixels,
	rim = wholeOrNone,
	ripple = wholeOrNone,
	rippleLine = positive,
	badgeGap = wholeOrNone,
	glove = positive,
	gloveDrop = nonNegative,
})
local glovePart = Validate.record({
	x = Validate.number(),
	y = Validate.number(),
	width = positive,
	height = positive,
	corner = nonNegative,
	turn = Validate.number(),
})
local gloveParts = Validate.check(Validate.list(glovePart), function(parts: { GlovePart }): boolean
	return #parts > 0
end, "must not be empty")

-- Each text of a scoreboard is drawn inside its box (Hud/Scoreboard): the scores in their shields or chips, the clock
-- and the goal's worth, so none may be taller than its box.
local function textsFit(sizes: BoardTextSizes, score: UDim2, clock: UDim2, worth: UDim2): boolean
	return sizes.score <= score.Y.Offset and sizes.clock <= clock.Y.Offset and sizes.worth <= worth.Y.Offset
end

-- The end screen's sizes (Hud/EndScreen) in whole pixels, so its boxes sit on pixel edges.
local endSizes = Validate.record({
	cardWidth = wholePixels,
	inset = wholeOrNone,
	avatar = wholePixels,
	nameSize = textSize,
	statSize = textSize,
	chipHeight = wholePixels,
	chipSize = textSize,
	totalHeight = wholePixels,
	totalSize = textSize,
})

-- The end screen's words inside their chips: the MVP's word on its chip (no ink), a total in look C's ink.
local function chipsHold(sizes: EndSizes, look: LookSettings): boolean
	return sizes.chipSize <= sizes.chipHeight and sizes.totalSize + 2 * math.ceil(look.textOutline) <= sizes.totalHeight
end

-- The MVP's card (Hud/EndScreen) as tall as their avatar inside its inset: beside it their name, in look C's ink,
-- over their numbers.
local function cardHolds(sizes: EndSizes, look: LookSettings): boolean
	return sizes.nameSize + math.ceil(look.textOutline) + sizes.statSize <= sizes.avatar
end

-- A name tag's name (NameTags) in look C's ink inside its pill.
local function pillHolds(sizes: TagSizes, look: LookSettings): boolean
	return sizes.textSize + 2 * math.ceil(look.textOutline) <= sizes.pillHeight
end

-- A name tag's marks' row inside its gui (#358, #381): above the gui's middle (the pill's), the pill's top half and
-- ink, the gap, the pointer and the key cap, with the badge round the cap's middle at its widest ripple. Across, its
-- widest row on the gui's middle: the badge in its rim, badgeGap, the pass key's cap, badgeGap, the Attach mark (its
-- key's cap, inked edge and the word's padding), each cap at its narrowest (square) and the words, measured only when
-- drawn, left out; past the row's left the ring, past its right the mark's ink.
local function rowFits(sizes: TagSizes, look: LookSettings): boolean
	local cap = sizes.cap
	local capMiddle = sizes.pillHeight / 2 + look.outline + sizes.gap + sizes.pointer + cap.height / 2
	local ring = sizes.badge + sizes.ripple + sizes.rippleLine
	local ringed = sizes.badge + sizes.rim
	local attach = cap.height + math.ceil(look.textOutline) + 2 * cap.padding
	local row = 2 * ringed + sizes.badgeGap + cap.height + sizes.badgeGap + attach
	return capMiddle + math.max(cap.height / 2, ring) <= sizes.height / 2
		and row + 2 * math.max(ring - ringed, look.textOutline) <= sizes.width
end

-- How many number columns a table of players' stats has: every column but the name's (UI.text.columns).
local function numberColumns(ui: UIConfig): number
	local count = 0
	for _ in ui.text.columns do
		count += 1
	end
	return count - 1
end

-- How wide a TAB board row's avatar slot is (Hud/ScoreTab): its circle and `ink` round it, in whole pixels.
local function tabAvatarSlot(sizes: TabSizes, ink: number): number
	return sizes.avatar + 2 * math.ceil(ink)
end

-- How wide a TAB board row's cells but its name stand (Hud/ScoreTab): the avatar's slot, `numbers` number columns,
-- and a gap between each two of the row's cells. The name takes what they leave of the box's width inside `side` at
-- each edge.
local function tabCellsWidth(sizes: TabSizes, ink: number, numbers: number): number
	return tabAvatarSlot(sizes, ink) + (numbers + 1) * sizes.gap + numbers * sizes.column
end

-- Whether a TAB board's row leaves its name some room.
local function tabNamesFit(sizes: TabSizes, ink: number, numbers: number): boolean
	return sizes.width - 2 * sizes.side - tabCellsWidth(sizes, ink, numbers) > 0
end

-- What a TAB board's rows, header and bars show fits in them (Hud/ScoreTab): an avatar's circle and a row's text with
-- look C's ink round them, the header's names (not inked), a bar's text with its ink above the bar's ink line.
local function tabHolds(sizes: TabSizes, look: LookSettings): boolean
	local ink = 2 * look.textOutline
	return sizes.avatar + ink <= sizes.rowHeight
		and sizes.textSize + ink <= sizes.rowHeight
		and sizes.headSize <= sizes.headHeight
		and sizes.barSize + ink <= sizes.barHeight - look.outline
end

-- The reticle's dot, `ink` thick round it, inside a carrying ring's ink, which reaches `ink` either side of its
-- stroke (Hud/Reticle).
local function dotFits(rings: RingSizes, dot: number, ink: number): boolean
	return dot < rings.carry - 2 * rings.thickness - 4 * ink
end

-- The count's digit inside its ring's ink (Hud/Countdown).
local function digitFits(count: CountSizes, ink: number): boolean
	return count.textSize < count.ringSize - 2 * (count.ringThickness + ink)
end

local fields = Validate.record({
	clockWarnings = Validate.check(
		Validate.list(Validate.number({ min = 1, integer = true })),
		noDuplicates,
		"must not contain duplicates"
	),
	teamColors = Validate.record({ Blue = Validate.datatype("Color3"), Orange = Validate.datatype("Color3") }),
	teamNames = Validate.record({ Blue = label, Orange = label }),
	controlLabels = Validate.record({
		Jump = label,
		AirPose = label,
		Pump = label,
		Brake = label,
		Attach = label,
		Tackle = label,
		Dive = label,
		Dodge = label,
		Uppercut = label,
		ChargeThrow = label,
		RollBall = label,
		CancelDodge = label,
		Pass = label,
		CallPass = label,
		BallFocus = label,
		GetUp = label,
	}),
	keyNames = keyNames,
	touchStyle = Validate.record({
		background = Validate.datatype("Color3"),
		backgroundTransparency = transparency,
		foreground = Validate.datatype("Color3"),
		corner = Validate.datatype("UDim"),
		textPadding = Validate.number({ min = 0 }),
		knobTransparency = transparency,
		fill = gradient,
		jumpFill = gradient,
	}),
	text = Validate.record({
		clock = template(2),
		goalWorth = template(1),
		overtime = label,
		goal = label,
		denied = label,
		clockWarning = template(1),
		lastChance = label,
		speed = template(1),
		speedUnit = label,
		possession = template(1),
		lapCompleted = template(1),
		goalOpen = template(1),
		scored = template(1),
		wins = template(1),
		mvpLine = template(3),
		teamTotal = template(2),
		draw = label,
		go = template(1),
		mvp = label,
		scores = label,
		columns = Validate.record({
			player = label,
			score = label,
			goals = label,
			assists = label,
			saves = label,
			steals = label,
		}),
		unknownPlayer = label,
		touchPassTarget = label,
		touchMove = label,
		switchTeam = label,
		cooldown = template(1),
		pressMark = label,
	}),
	hud = Validate.record({
		font = Validate.enumItem(Enum.Font),
		textColor = Validate.datatype("Color3"),
		panel = Validate.datatype("Color3"),
		panelTransparency = transparency,
		dimTransparency = transparency,
		corner = Validate.datatype("UDim"),
		textSize = textSize,
		titleSize = textSize,
		bannerSeconds = Validate.record({ headline = positive, lap = positive, message = positive }),
		feedSeconds = positive,
		feedMaxEntries = Validate.number({ min = 1, integer = true }),
		glowThickness = Validate.number({ min = 0 }),
		spacing = Validate.number({ min = 0 }),
		screenMargin = Validate.number({ min = 0 }),
		-- The dim goes one under it: level with the touch controls' gui (Roblox's default, 0), which of them draws on
		-- top would be left to the engine.
		displayOrder = Validate.number({ min = 2, integer = true }),
		avatarImage = template(1),
		look = Validate.record({
			font = Validate.enumItem(Enum.Font),
			bannerFont = Validate.enumItem(Enum.Font),
			-- Past half its size a digit's middle would sit above its whole line.
			bannerDigitRise = Validate.number({ min = 0, max = 0.5 }),
			ink = Validate.datatype("Color3"),
			outline = nonNegative,
			shadow = nonNegative,
			textOutline = nonNegative,
			corner = Validate.datatype("UDim"),
			box = Validate.datatype("Color3"),
			-- A bottom as dark as black would lose the box's colour there.
			shade = seen,
			key = Validate.datatype("Color3"),
			pressed = Validate.datatype("Color3"),
			-- A sweep that shows nothing would show no cooldown.
			sweepTransparency = seen,
			groupRoom = wholePixels,
		}),
		motion = Validate.record({
			pop = Validate.record({ seconds = positive, overshoot = nonNegative }),
			-- A bounce grows (or keeps its size, with no bounce), then comes back to a size that still shows.
			bounce = Validate.record({
				seconds = positive,
				scale = Validate.number({ min = 1 }),
				rebound = Validate.number({ above = 0, max = 1 }),
			}),
			-- A press goes in (or keeps its size) to a size that still shows, then springs back no smaller than it.
			press = Validate.record({
				seconds = positive,
				scale = Validate.number({ above = 0, max = 1 }),
				rebound = Validate.number({ min = 1 }),
			}),
			easeSeconds = positive,
			lapHoldSeconds = nonNegative,
			glow = Validate.record({ seconds = positive, transparency = transparency }),
			speedRate = positive,
		}),
		layout = Validate.record({
			compactBelow = positive,
			scoreboard = Validate.record({
				position = udim2,
				shield = pixels,
				clock = pixels,
				worth = pixels,
				lapChip = positive,
				chipCorner = Validate.datatype("UDim"),
				gap = nonNegative,
				chipGap = nonNegative,
				chipClearance = nonNegative,
				textSizes = boardTextSizes,
			}),
			compactScoreboard = Validate.record({
				position = udim2,
				score = pixels,
				clock = pixels,
				worth = pixels,
				gap = nonNegative,
				textSizes = boardTextSizes,
			}),
			banner = Validate.record({
				-- On the screen, never on its top or bottom edge.
				height = Validate.number({ above = 0, below = 1 }),
				clearance = nonNegative,
				bottom = nonNegative,
				-- Within the banner's own height.
				rise = Validate.number({ min = 0, max = 1 }),
				sizes = bannerSizes,
				compactSizes = bannerSizes,
			}),
			feed = Validate.record({
				clearance = nonNegative,
				sizes = feedSizes,
				compactSizes = feedSizes,
			}),
			hints = Validate.record({
				position = udim2,
				rowHeight = positive,
				clearance = nonNegative,
				inset = Validate.record({ left = nonNegative, right = nonNegative }),
				gap = nonNegative,
				textSize = textSize,
				cap = Validate.record({
					height = positive,
					padding = nonNegative,
					corner = Validate.datatype("UDim"),
					textSize = textSize,
					mouse = Validate.record({
						width = wholePixels,
						height = wholePixels,
						buttons = wholePixels,
						line = wholePixels,
					}),
				}),
				press = Validate.record({ textSize = textSize, gap = nonNegative }),
			}),
			speedometer = Validate.record({
				position = udim2,
				touchPosition = udim2,
				textSizes = speedTextSizes,
				compactTextSizes = speedTextSizes,
			}),
			reticle = Validate.record({
				size = positive,
				-- On the screen, never on its top or bottom edge.
				height = Validate.number({ above = 0, below = 1 }),
				blinkSeconds = positive,
				-- A share of the charge: the carrying ring has grown out and gone by the time it is spent.
				growShare = Validate.number({ above = 0, max = 1 }),
				clearance = nonNegative,
				sizes = ringSizes,
				compactSizes = ringSizes,
			}),
			markers = Validate.record({
				edgeGap = nonNegative,
				clearance = nonNegative,
				badge = badgeLook,
				chevron = Validate.record({
					bar = Validate.number({ above = 0, below = 1 }),
					spread = Validate.number({ above = 0, below = 90 }),
				}),
				sizes = markerSizes,
				compactSizes = markerSizes,
			}),
			countdown = Validate.record({ sizes = countSizes, compactSizes = countSizes }),
			scoreTab = Validate.record({
				margin = nonNegative,
				scrollBar = wholeOrNone,
				sizes = tabSizes,
				compactSizes = tabSizes,
			}),
			scoreButton = Validate.record({
				top = nonNegative,
				size = pixels,
				corner = Validate.datatype("UDim"),
				textSize = textSize,
			}),
			endScreen = Validate.record({
				gap = wholeOrNone,
				dim = transparency,
				sizes = endSizes,
				compactSizes = endSizes,
			}),
			getUp = Validate.record({
				sizes = getUpSizes,
				compactSizes = getUpSizes,
			}),
		}),
	}),
	markers = Validate.record({
		ringSize = positive,
		ringThickness = positive,
		lineWidth = positive,
		groundProbe = positive,
		groundMarkerSize = positive,
		groundMarkerThickness = positive,
		groundMarkerTransparency = transparency,
	}),
	nameTag = Validate.record({
		studsOffset = Validate.datatype("Vector3"),
		sizes = tagSizes,
		compactSizes = tagSizes,
		call = Validate.record({
			rippleSeconds = positive,
			waveDegrees = nonNegative,
			waveRate = nonNegative,
			wavePivot = Validate.number(),
		}),
		glove = Validate.record({ ink = nonNegative, parts = gloveParts, seams = Validate.list(glovePart) }),
	}),
	arenaGlow = Validate.record({
		material = Validate.enumItem(Enum.Material),
		doorSeconds = nonNegative,
		-- Each piece and fireball is a part: Roblox would silently clamp a size outside its part limits. The
		-- spacing's rule is below.
		fireLines = Validate.record({
			thickness = partSize,
			spacing = Validate.number(),
			fireball = partSize,
			delaySeconds = nonNegative,
			flightSeconds = nonNegative,
			fadeSeconds = nonNegative,
		}),
	}),
	goalWorth = Validate.record({
		thickness = partSize,
		fill = Validate.number({ above = 0, max = 1 }),
		textHeight = Validate.number({ above = 0, max = 1 }),
		behind = nonNegative,
	}),
	skateFire = Validate.record({
		width = positive,
		lift = nonNegative,
		lifetime = positive,
		minSpeed = nonNegative,
		brightness = positive,
		transparency = seen,
		fade = Validate.record({
			from = Validate.number({ above = 0, below = 1 }),
			transparency = seen,
		}),
	}),
	ballTrail = Validate.record({
		lifetime = positive,
		width = positive,
		color = Validate.datatype("Color3"),
		transparency = seen,
	}),
})

local schema = Validate.checkAll(fields, {
	{
		message = "the count's digit must fit inside its ring's ink "
			.. "(textSize < ringSize - 2 × (ringThickness + look.textOutline))",
		holds = function(ui: UIConfig): boolean
			local countdown, ink = ui.hud.layout.countdown, ui.hud.look.textOutline
			return digitFits(countdown.sizes, ink) and digitFits(countdown.compactSizes, ink)
		end,
	},
	-- A hint's cap and label sit in its row's box (Hud/ControlHints), the cap's name on the cap.
	{
		message = "a hint's key cap and label must fit its row (cap.height and textSize <= rowHeight, "
			.. "cap.textSize <= cap.height)",
		holds = function(ui: UIConfig): boolean
			local hints = ui.hud.layout.hints
			local cap = hints.cap
			return cap.height <= hints.rowHeight and hints.textSize <= hints.rowHeight and cap.textSize <= cap.height
		end,
	},
	-- A mouse button's cap draws its mouse inside its ink on the cap, and the line under its buttons where the body's
	-- sides run straight, never across its round top or bottom (Hud/Style.keyCap).
	{
		message = "a hint cap's mouse must fit its cap in its ink, the line under its buttons on its "
			.. "straight sides (height + 2 × line <= cap.height, width / 2 + line / 2 <= buttons <= "
			.. "height - width / 2 - line / 2)",
		holds = function(ui: UIConfig): boolean
			local cap = ui.hud.layout.hints.cap
			-- A hint's cap always has one (its validator).
			local mouse = cap.mouse :: MouseSizes
			-- Where a round end meets the straight sides, with the line's half.
			local edge = (mouse.width + mouse.line) / 2
			return mouse.height + 2 * mouse.line <= cap.height
				and mouse.buttons >= edge
				and mouse.buttons <= mouse.height - edge
		end,
	},
	{
		message = "the end screen's words must fit their chips (chipSize <= chipHeight, "
			.. "totalSize + 2 \u{D7} textOutline <= totalHeight)",
		holds = function(ui: UIConfig): boolean
			local endScreen, look = ui.hud.layout.endScreen, ui.hud.look
			return chipsHold(endScreen.sizes, look) and chipsHold(endScreen.compactSizes, look)
		end,
	},
	{
		message = "the end screen's card must hold its name over its numbers beside the avatar "
			.. "(nameSize + textOutline + statSize <= avatar)",
		holds = function(ui: UIConfig): boolean
			local endScreen, look = ui.hud.layout.endScreen, ui.hud.look
			return cardHolds(endScreen.sizes, look) and cardHolds(endScreen.compactSizes, look)
		end,
	},
	-- The name tags (#358) on either kind of screen.
	{
		message = "a name tag's name must fit its pill (textSize + 2 \u{D7} textOutline <= pillHeight)",
		holds = function(ui: UIConfig): boolean
			local tag, look = ui.nameTag, ui.hud.look
			return pillHolds(tag.sizes, look) and pillHolds(tag.compactSizes, look)
		end,
	},
	{
		message = "a name tag must hold its marks' row (the pill, gap, pointer and key cap; the badge's widest ripple, "
			.. "the pass key and the Attach mark)",
		holds = function(ui: UIConfig): boolean
			local tag, look = ui.nameTag, ui.hud.look
			return rowFits(tag.sizes, look) and rowFits(tag.compactSizes, look)
		end,
	},
	-- One compact table on desktop and phones (#357, the owner's Q237), each at its own sizes.
	{
		message = "the TAB board's number columns must leave room for names, on either kind of screen",
		holds = function(ui: UIConfig): boolean
			local tab, ink, numbers = ui.hud.layout.scoreTab, ui.hud.look.textOutline, numberColumns(ui)
			return tabNamesFit(tab.sizes, ink, numbers) and tabNamesFit(tab.compactSizes, ink, numbers)
		end,
	},
	{
		message = "a TAB board's rows, header and bars must hold what they show (avatar and textSize with look C's "
			.. "ink round them <= rowHeight, headSize <= headHeight, barSize with its ink <= barHeight - look.outline)",
		holds = function(ui: UIConfig): boolean
			local tab, look = ui.hud.layout.scoreTab, ui.hud.look
			return tabHolds(tab.sizes, look) and tabHolds(tab.compactSizes, look)
		end,
	},
	-- The crosshair's rings build round its dot (#312, #353), on either kind of screen.
	{
		message = "the reticle's dot must fit inside each carrying ring's ink "
			.. "(size < carry - 2 × thickness - 4 × look.textOutline)",
		holds = function(ui: UIConfig): boolean
			local reticle, ink = ui.hud.layout.reticle, ui.hud.look.textOutline
			return dotFits(reticle.sizes, reticle.size, ink) and dotFits(reticle.compactSizes, reticle.size, ink)
		end,
	},
	-- The carrying ring grows out into the charge ring as a throw charges (X1, the owner's Q188b).
	{
		message = "the reticle's carrying ring must be smaller than its charge ring (carry < charge)",
		holds = function(ui: UIConfig): boolean
			local reticle = ui.hud.layout.reticle
			return reticle.sizes.carry < reticle.sizes.charge
				and reticle.compactSizes.carry < reticle.compactSizes.charge
		end,
	},
	{
		message = "the desktop scoreboard's texts must fit their boxes (text size <= box height)",
		holds = function(ui: UIConfig): boolean
			local board = ui.hud.layout.scoreboard
			return textsFit(board.textSizes, board.shield, board.clock, board.worth)
		end,
	},
	{
		message = "the phone scoreboard's texts must fit their boxes (text size <= box height)",
		holds = function(ui: UIConfig): boolean
			local board = ui.hud.layout.compactScoreboard
			return textsFit(board.textSizes, board.score, board.clock, board.worth)
		end,
	},
	-- Each lap's fire line stands apart from the last (Q302's stack): `spacing` apart up the upright glass, farther
	-- along a slope.
	{
		message = "the fire lines must not overlap (arenaGlow.fireLines.spacing > thickness)",
		holds = function(ui: UIConfig): boolean
			local lines = ui.arenaGlow.fireLines
			return lines.spacing > lines.thickness
		end,
	},
})

return {
	defaults = defaults,
	schema = schema,
	tabAvatarSlot = tabAvatarSlot,
	tabCellsWidth = tabCellsWidth,
}
