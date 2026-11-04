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
	-- The Get Up prompt's label beside the movement keys while knocked down (#220): moving asks to get up, from
	-- Actions.getUpAfter (the whole slide since #287); kept as RC shows it (the owner, #303, Q88).
	GetUp: string,
}

-- How the touch controls look: the stick's ring and the buttons on `background`, the knob and the labels in
-- `foreground` (the knob knobTransparency see-through), rounded by `corner`. A label is at most textSize pixels tall,
-- shrinking to fit within textPadding pixels of its button's sides.
export type TouchStyle = {
	background: Color3,
	backgroundTransparency: number,
	foreground: Color3,
	font: Enum.Font,
	corner: UDim,
	textSize: number,
	textPadding: number,
	knobTransparency: number,
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
	-- The end screen's headline when overtime runs out (the owner, Q95).
	draw: string,
	-- At GO, the player's own team's name in capitals (one value): Roller Champions' line (the owner, Q109).
	go: string,
	mvp: string,
	scores: string,
	columns: { player: string, score: string, goals: string, assists: string, saves: string, steals: string },
	-- A player the HUD has no name for.
	unknownPlayer: string,
	-- Over a teammate calling for the ball.
	callPass: string,
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

export type Place = { position: UDim2, size: UDim2 }

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

-- A mouse on a mouse button's key cap (#354, the owner's Q207): a body width x height pixels in look C's ink `line`
-- pixels thick, its buttons `buttons` pixels deep from its rounded top. Whole pixels (a UDim's offset drops a
-- fraction).
export type MouseSizes = { width: number, height: number, buttons: number, line: number }

-- A look C key cap (Hud/Style.keyCap): `height` pixels tall and as wide as its key's name with `padding` each side,
-- never narrower than tall, its corners `corner`, its name at textSize; a mouse button's cap square, with `mouse` on
-- it. Pixels.
export type CapSizes = { height: number, padding: number, corner: UDim, textSize: number, mouse: MouseSizes }

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
export type HudLayout = {
	-- A screen whose shorter side is under compactBelow pixels is a phone's: the compact scoreboard and the small
	-- speedometer (HudScreen.compact).
	compactBelow: number,
	scoreboard: ScoreboardLayout,
	compactScoreboard: CompactScoreboardLayout,
	banner: Place,
	feed: { position: UDim2, size: UDim2, rowHeight: number },
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
	-- The kickoff count (#353) at the crosshair's place, lower where its ring would come within reticle.clearance
	-- pixels of the scoreboard (HudScreen.countDrop): `sizes` on a desktop's screen, compactSizes on a phone's.
	countdown: { sizes: CountSizes, compactSizes: CountSizes },
	-- columnWidth: each number column; the name column takes the rest.
	scoreTab: { position: UDim2, size: UDim2, rowHeight: number, columnWidth: number },
	-- The touch button that opens the score tab.
	scoreButton: Place,
	endScreen: Place,
	-- The Get Up prompt: position is its bottom centre's; its keys are as tall as it is.
	getUp: Place,
}

-- Look C, Bold arcade (Hud/Style): text in `font`, banners and the goal's worth in `bannerFont`, in the HUD's text
-- colour with an ink outline textOutline pixels thick. A box has `corner`s, an ink outline `outline` pixels wide and
-- an ink shadow dropping `shadow` pixels below it; it is its colour at the top and that colour times (1 - shade) at the
-- bottom. `box` colours a box that is no team's (the clock's, an empty lap chip); `teamColors` the HUD's team parts
-- (Style.teamColor), brighter than the world's UI.teamColors. bannerFont draws a digit's middle bannerDigitRise of
-- its text size above its line's middle; a digit centred in a shape moves down by that (Hud/Countdown). A key's
-- cap is `key` with its name in ink, `pressed` while it pops (the press's mark too); a cooling key's sweep is ink,
-- sweepTransparency see-through.
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
	teamColors: TeamColors,
	key: Color3,
	pressed: Color3,
	sweepTransparency: number,
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
-- and the viewer's row on the score tab. `look` and `motion` are look C's: the parts it restyles read them.
export type HudSettings = {
	font: Enum.Font,
	textColor: Color3,
	panel: Color3,
	panelTransparency: number,
	-- The score tab and the end screen, drawn over the game: solid, so nothing shows through them.
	overlayTransparency: number,
	dimTransparency: number,
	corner: UDim,
	textSize: number,
	titleSize: number,
	bannerSize: number,
	bannerSeconds: number,
	feedSeconds: number,
	feedMaxEntries: number,
	glowThickness: number,
	-- Pixels between the parts of a panel, and inside its edge.
	spacing: number,
	-- Pixels kept clear at each edge of the HUD's area by a panel shrunk to fit it (the score tab, the end screen).
	screenMargin: number,
	look: LookSettings,
	motion: MotionSettings,
	layout: HudLayout,
}

-- The ball's ring (pixels: ringSize wider than the ball, so it rings it at any distance), its line and ground marker
-- (studs, the marker found within groundProbe studs below the ball), and the arrows pinned edgeMargin pixels inside the
-- screen's edge.
export type MarkerSettings = {
	ringSize: number,
	ringThickness: number,
	lineWidth: number,
	groundProbe: number,
	-- The ground marker is a disc this wide and this thick.
	groundMarkerSize: number,
	groundMarkerThickness: number,
	groundMarkerTransparency: number,
	edgeMargin: number,
	arrowSize: number,
	-- The arrows' image, pointing up and white, so it takes their colour. The default is Roblox's own chevron from
	-- its content folder (found in three installed Studio versions). No Roblox page documents it, so an update could
	-- remove it and leave the arrows blank: the art pass swaps in ours, and Phase 9 checks it on real devices.
	arrowImage: string,
}

-- A name tag's size, how far above a player's root it sits (studs), and its text sizes.
export type NameTagSettings = { size: UDim2, studsOffset: Vector3, textSize: number, callSize: number }

-- The goal ring, the next gate's panel and the carrier's beam glow in `material`; the goal panel slides panelSlide
-- studs up out of the ring over panelSlideSeconds. The beam (Arena spec §5.4) is `width` studs along the track and
-- `thickness` across it, on the outer glass's face, as tall as the vertical glass.
export type ArenaGlowSettings = {
	material: Enum.Material,
	panelSlide: number,
	panelSlideSeconds: number,
	beam: { width: number, thickness: number },
}

-- The trail behind a thrown, passed or rolled ball on every screen (§9.4, #313): `lifetime` seconds long and `width`
-- studs wide in `color`, `transparency` see-through behind the ball, fading to nothing at its end.
export type BallTrailSettings = { lifetime: number, width: number, color: Color3, transparency: number }

export type UIConfig = {
	clockWarnings: { number },
	-- The world's team colours: the arena's glow and pads, the carrier's beam, the ball, the markers and name tags.
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
	ballTrail: BallTrailSettings,
}

local defaults: UIConfig = {
	clockWarnings = { 60, 30 },
	teamColors = { Blue = Color3.fromRGB(13, 105, 172), Orange = Color3.fromRGB(218, 133, 65) },
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
		GetUp = "Get Up",
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
	-- Roblox's own touch thumbstick colors; the art pass restyles them.
	touchStyle = {
		background = Color3.fromRGB(18, 18, 21),
		backgroundTransparency = 0.4,
		foreground = Color3.fromRGB(213, 215, 221),
		font = Enum.Font.BuilderSansBold,
		corner = UDim.new(0.5, 0),
		textSize = 18,
		textPadding = 6,
		knobTransparency = 0,
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
		lapCompleted = "Lap %d completed",
		goalOpen = "%s goal is active",
		scored = "%s scored!",
		wins = "%s WINS",
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
		-- A raised hand.
		callPass = "\u{270B}",
		-- A down-pointing triangle: RC floats the pass key's letter there (Video 34 at 41.6 s); a touch screen has
		-- none.
		touchPassTarget = "\u{25BC}",
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
		overlayTransparency = 0,
		dimTransparency = 0.6,
		corner = UDim.new(0, 8),
		textSize = 20,
		titleSize = 32,
		bannerSize = 96,
		bannerSeconds = 2,
		feedSeconds = 6,
		feedMaxEntries = 5,
		glowThickness = 3,
		spacing = 6,
		screenMargin = 8,
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
			-- The page's brighter pair (#3d8bff, #ff9a3c), for the HUD only (the owner, Q201: "I want the lighter
			-- one"): the world's darker teamColors made a lit lap chip hard to tell from an empty one.
			teamColors = { Blue = Color3.fromRGB(61, 139, 255), Orange = Color3.fromRGB(255, 154, 60) },
			-- The page's key caps (#354): #ffd23f with ink lettering, #ff8a2c while pressed (the page drew RC's >>
			-- beside it in a near orange, #f08a2c: one colour here), and its cooldown's 62% black sweep (Q186).
			key = Color3.fromRGB(255, 210, 63),
			pressed = Color3.fromRGB(255, 138, 44),
			sweepTransparency = 0.38,
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
			-- Its centre 200 px from the top: clear of the scoreboard on a phone too (the owner's choice); 720 px wide
			-- for its longest line, GO ORANGE TEAM! (691 px at bannerSize).
			banner = { position = UDim2.new(0.5, 0, 0, 200), size = UDim2.fromOffset(720, 110) },
			feed = { position = UDim2.new(0.5, 0, 1, -24), size = UDim2.fromOffset(460, 140), rowHeight = 24 },
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
			-- The kickoff count a third down, where RC's sits (the owner, Q185): on desktop RC's at 1918 x 1078 (Video
			-- 31 at 16.5 s), a 200 px ring with a 75 px digit (Q108); on a phone RC's share of the screen's height (a
			-- 76 px ring) with a bigger digit, big and clear on phones (Q181), as the design page drew it (Q203).
			countdown = {
				sizes = { textSize = 76, ringSize = 200, ringThickness = 8 },
				compactSizes = { textSize = 40, ringSize = 76, ringThickness = 4 },
			},
			scoreTab = {
				position = UDim2.fromScale(0.5, 0.5),
				size = UDim2.fromOffset(640, 360),
				rowHeight = 28,
				columnWidth = 80,
			},
			scoreButton = { position = UDim2.new(1, -16, 0, 16), size = UDim2.fromOffset(96, 36) },
			endScreen = { position = UDim2.fromScale(0.5, 0.5), size = UDim2.fromOffset(720, 520) },
			-- At the bottom centre like Roller Champions' prompt (Video 5 at 0:18), 8 px above the feed's 140 px.
			getUp = { position = UDim2.new(0.5, 0, 1, -172), size = UDim2.fromOffset(320, 40) },
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
		edgeMargin = 48,
		arrowSize = 28,
		arrowImage = "rbxasset://textures/ui/MenuBar/arrow_up.png",
	},
	nameTag = {
		size = UDim2.fromOffset(200, 48),
		studsOffset = Vector3.new(0, 4, 0),
		textSize = 20,
		callSize = 28,
	},
	arenaGlow = {
		material = Enum.Material.Neon,
		panelSlide = 16,
		panelSlideSeconds = 0.4,
		beam = { width = 2, thickness = 0.5 },
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

local textSize = Validate.number({ min = 1, max = 100, integer = true })
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
local place = Validate.record({ position = udim2, size = pixels })
local list = Validate.record({ position = udim2, size = pixels, rowHeight = positive })
local columns = Validate.record({ position = udim2, size = pixels, rowHeight = positive, columnWidth = positive })
local nonNegative = Validate.number({ min = 0 })
local boardTextSizes = Validate.record({ score = textSize, clock = textSize, worth = textSize, period = textSize })
local teamColors = Validate.record({ Blue = Validate.datatype("Color3"), Orange = Validate.datatype("Color3") })
local speedTextSizes = Validate.record({ speed = textSize, unit = textSize })
local ringSizes = Validate.record({ carry = positive, charge = positive, thickness = positive })
local countSizes = Validate.record({ textSize = textSize, ringSize = positive, ringThickness = positive })

-- Each text of a scoreboard is drawn inside its box (Hud/Scoreboard): the scores in their shields or chips, the clock
-- and the goal's worth, so none may be taller than its box.
local function textsFit(sizes: BoardTextSizes, score: UDim2, clock: UDim2, worth: UDim2): boolean
	return sizes.score <= score.Y.Offset and sizes.clock <= clock.Y.Offset and sizes.worth <= worth.Y.Offset
end

-- The score tab's table (StatsTable) gives each number column columnWidth and a spacing gap, inside its panel's
-- padding (spacing at each side), and the name column what is left: the score tab and the end screen draw it, and
-- both must leave the names some room.
local function namesFit(ui: UIConfig): boolean
	local hud = ui.hud
	local layout = hud.layout
	local count = 0
	for _ in ui.text.columns do
		count += 1
	end
	-- Every column but the name's.
	local taken = (count - 1) * (layout.scoreTab.columnWidth + hud.spacing) + 2 * hud.spacing
	return taken < layout.scoreTab.size.X.Offset and taken < layout.endScreen.size.X.Offset
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
	teamColors = teamColors,
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
		font = Validate.enumItem(Enum.Font),
		corner = Validate.datatype("UDim"),
		-- Roblox clamps text sizes to 1..100 (measured).
		textSize = textSize,
		textPadding = Validate.number({ min = 0 }),
		knobTransparency = transparency,
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
		callPass = label,
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
		overlayTransparency = transparency,
		dimTransparency = transparency,
		corner = Validate.datatype("UDim"),
		textSize = textSize,
		titleSize = textSize,
		bannerSize = textSize,
		bannerSeconds = positive,
		feedSeconds = positive,
		feedMaxEntries = Validate.number({ min = 1, integer = true }),
		glowThickness = Validate.number({ min = 0 }),
		spacing = Validate.number({ min = 0 }),
		screenMargin = Validate.number({ min = 0 }),
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
			teamColors = teamColors,
			key = Validate.datatype("Color3"),
			pressed = Validate.datatype("Color3"),
			-- A sweep that shows nothing would show no cooldown.
			sweepTransparency = seen,
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
			banner = place,
			feed = list,
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
			countdown = Validate.record({ sizes = countSizes, compactSizes = countSizes }),
			scoreTab = columns,
			scoreButton = place,
			endScreen = place,
			getUp = place,
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
		edgeMargin = positive,
		arrowSize = positive,
		arrowImage = label,
	}),
	nameTag = Validate.record({
		size = udim2,
		studsOffset = Validate.datatype("Vector3"),
		textSize = textSize,
		callSize = textSize,
	}),
	arenaGlow = Validate.record({
		material = Validate.enumItem(Enum.Material),
		panelSlide = positive,
		panelSlideSeconds = Validate.number({ min = 0 }),
		-- The beam is one part: Roblox would silently clamp a size outside its part limits.
		beam = Validate.record({ width = partSize, thickness = partSize }),
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
			local mouse = cap.mouse
			-- Where a round end meets the straight sides, with the line's half.
			local edge = (mouse.width + mouse.line) / 2
			return mouse.height + 2 * mouse.line <= cap.height
				and mouse.buttons >= edge
				and mouse.buttons <= mouse.height - edge
		end,
	},
	{
		message = "the score tab's number columns must leave room for names, in the tab and the end screen",
		holds = namesFit,
	},
	-- Its keys fill its height inside Style.padding (GetUp).
	{
		message = "the Get Up prompt must be taller than its padding (2 × hud.spacing)",
		holds = function(ui: UIConfig): boolean
			return ui.hud.layout.getUp.size.Y.Offset > 2 * ui.hud.spacing
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
})

return {
	defaults = defaults,
	schema = schema,
}
