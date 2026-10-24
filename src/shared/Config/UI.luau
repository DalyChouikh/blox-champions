--!strict
-- HUD settings (spec §11.2). The clock-warning marks also drive the rules' ClockWarning events (spec §5.1).
-- Team colors are the one source for everything drawn in a team's color (spawn pads, the HUD, the arena's glow).
-- Control labels name each control as it acts now: a touch button reads Dodge with the ball, Tackle without. Every
-- string the HUD shows, its style and layout, the world markers, the name tags and the arena's glow live here too.

local Validate = require(script.Parent.Validate)

-- One label per action, plus the controls that start none (Ball Focus and the skating buttons).
export type ControlLabels = {
	Jump: string,
	Pump: string,
	Brake: string,
	Attach: string,
	Tackle: string,
	Dive: string,
	Dodge: string,
	Uppercut: string,
	ChargeThrow: string,
	Pass: string,
	CallPass: string,
	BallFocus: string,
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
	-- The possessing team's completed laps, of Match.lapsToOpenGoal (two values).
	lap: string,
	-- Their streak once the goal is open for them, of Match.lapsForStreakPoint (two values).
	streak: string,
	overtime: string,
	goal: string,
	streakPoint: string,
	denied: string,
	-- The seconds left (one value).
	clockWarning: string,
	lastChance: string,
	-- The speedometer's reading (one value).
	speed: string,
	-- The new holder's name (one value).
	possession: string,
	-- The streak (one value).
	lapCompleted: string,
	-- The team's name (one value).
	goalOpen: string,
	-- The scorer's name (one value).
	scored: string,
	-- The holder's name (one value).
	scoredStreak: string,
	-- The winning team's name (one value).
	wins: string,
	mvp: string,
	scores: string,
	columns: { player: string, score: string, goals: string, assists: string, saves: string, steals: string },
	-- A player the HUD has no name for.
	unknownPlayer: string,
	-- Over a teammate calling for the ball.
	callPass: string,
}

export type Place = { position: UDim2, size: UDim2 }

-- Where each part of the HUD sits; sizes and row heights are pixels.
export type HudLayout = {
	scoreboard: Place,
	banner: Place,
	feed: { position: UDim2, size: UDim2, rowHeight: number },
	hints: { position: UDim2, size: UDim2, rowHeight: number },
	-- touchPosition clears the touch buttons.
	speedometer: { position: UDim2, touchPosition: UDim2, size: UDim2 },
	reticle: { size: number },
	-- columnWidth: each number column; the name column takes the rest.
	scoreTab: { position: UDim2, size: UDim2, rowHeight: number, columnWidth: number },
	-- The touch button that opens the score tab.
	scoreButton: Place,
	endScreen: Place,
}

-- How the HUD looks and how long its messages last. dimTransparency fades an empty pip or a departed player's row;
-- glowThickness (pixels) outlines the lap bar while the goal is open, and the touch throw button while Ball Focus is
-- on.
export type HudSettings = {
	font: Enum.Font,
	textColor: Color3,
	panel: Color3,
	panelTransparency: number,
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
	-- A score pip's side and the lap bar's height, in pixels.
	pipSize: number,
	layout: HudLayout,
}

-- The ball's ring (pixels), its line and ground marker (studs, the marker found within groundProbe studs below the
-- ball), and the arrows pinned edgeMargin pixels inside the screen's edge.
export type MarkerSettings = {
	ringSize: number,
	ringThickness: number,
	lineWidth: number,
	groundProbe: number,
	groundMarkerSize: number,
	groundMarkerTransparency: number,
	edgeMargin: number,
	arrowSize: number,
}

-- A name tag's size, how far above a player's root it sits (studs), and its text sizes.
export type NameTagSettings = { size: UDim2, studsOffset: Vector3, textSize: number, callSize: number }

-- The goal ring and the next gate's corner marker glow in `material`; the goal panel slides panelSlide studs up out
-- of the ring over panelSlideSeconds.
export type ArenaGlowSettings = { material: Enum.Material, panelSlide: number, panelSlideSeconds: number }

export type UIConfig = {
	clockWarnings: { number },
	teamColors: { Blue: Color3, Orange: Color3 },
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
}

local defaults: UIConfig = {
	clockWarnings = { 60, 30 },
	teamColors = { Blue = Color3.fromRGB(13, 105, 172), Orange = Color3.fromRGB(218, 133, 65) },
	teamNames = { Blue = "Blue", Orange = "Orange" },
	controlLabels = {
		Jump = "Jump",
		Pump = "Pump",
		Brake = "Brake",
		Attach = "Attach",
		Tackle = "Tackle",
		Dive = "Dive",
		Dodge = "Dodge",
		Uppercut = "Uppercut",
		ChargeThrow = "Throw",
		Pass = "Pass",
		CallPass = "Call",
		BallFocus = "Focus",
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
		lap = "Lap %d/%d",
		streak = "Streak %d/%d",
		overtime = "OVERTIME",
		goal = "GOAL!",
		streakPoint = "STREAK POINT!",
		denied = "DENIED!",
		clockWarning = "%d SECONDS",
		lastChance = "LAST CHANCE",
		speed = "%d km/h",
		possession = "%s has the ball",
		lapCompleted = "Lap %d completed",
		goalOpen = "%s goal is active",
		scored = "%s scored!",
		scoredStreak = "%s scored a streak point!",
		wins = "%s WINS",
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
	},
	-- The HUD's graybox look; the art pass restyles it.
	hud = {
		font = Enum.Font.BuilderSansBold,
		textColor = Color3.fromRGB(245, 245, 245),
		panel = Color3.fromRGB(18, 18, 21),
		panelTransparency = 0.35,
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
		pipSize = 10,
		layout = {
			scoreboard = { position = UDim2.new(0.5, 0, 0, 8), size = UDim2.fromOffset(440, 84) },
			banner = { position = UDim2.fromScale(0.5, 0.3), size = UDim2.fromOffset(640, 110) },
			feed = { position = UDim2.new(0.5, 0, 1, -24), size = UDim2.fromOffset(460, 140), rowHeight = 24 },
			hints = { position = UDim2.new(1, -24, 0.5, 0), size = UDim2.fromOffset(220, 300), rowHeight = 30 },
			speedometer = {
				position = UDim2.new(1, -24, 1, -24),
				touchPosition = UDim2.new(1, -24, 1, -300),
				size = UDim2.fromOffset(160, 40),
			},
			reticle = { size = 6 },
			scoreTab = {
				position = UDim2.fromScale(0.5, 0.5),
				size = UDim2.fromOffset(640, 360),
				rowHeight = 28,
				columnWidth = 80,
			},
			scoreButton = { position = UDim2.new(1, -16, 0, 16), size = UDim2.fromOffset(96, 36) },
			endScreen = { position = UDim2.fromScale(0.5, 0.5), size = UDim2.fromOffset(720, 520) },
		},
	},
	markers = {
		ringSize = 56,
		ringThickness = 3,
		lineWidth = 0.2,
		groundProbe = 100,
		groundMarkerSize = 4,
		groundMarkerTransparency = 0.4,
		edgeMargin = 48,
		arrowSize = 28,
	},
	nameTag = {
		size = UDim2.fromOffset(200, 48),
		studsOffset = Vector3.new(0, 4, 0),
		textSize = 20,
		callSize = 28,
	},
	arenaGlow = { material = Enum.Material.Neon, panelSlide = 16, panelSlideSeconds = 0.4 },
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

-- How many values `text` takes: its %d and %s, each with an optional width (%02d).
local function placeholders(text: string): number
	local _, count = string.gsub(text, "%%%d*[ds]", "")
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
local positive = Validate.number({ above = 0 })
local udim2 = Validate.datatype("UDim2")
local place = Validate.record({ position = udim2, size = udim2 })
local list = Validate.record({ position = udim2, size = udim2, rowHeight = positive })
local columns = Validate.record({ position = udim2, size = udim2, rowHeight = positive, columnWidth = positive })

local schema = Validate.record({
	clockWarnings = Validate.check(
		Validate.list(Validate.number({ min = 1, integer = true })),
		noDuplicates,
		"must not contain duplicates"
	),
	teamColors = Validate.record({ Blue = Validate.datatype("Color3"), Orange = Validate.datatype("Color3") }),
	teamNames = Validate.record({ Blue = label, Orange = label }),
	controlLabels = Validate.record({
		Jump = label,
		Pump = label,
		Brake = label,
		Attach = label,
		Tackle = label,
		Dive = label,
		Dodge = label,
		Uppercut = label,
		ChargeThrow = label,
		Pass = label,
		CallPass = label,
		BallFocus = label,
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
		lap = template(2),
		streak = template(2),
		overtime = label,
		goal = label,
		streakPoint = label,
		denied = label,
		clockWarning = template(1),
		lastChance = label,
		speed = template(1),
		possession = template(1),
		lapCompleted = template(1),
		goalOpen = template(1),
		scored = template(1),
		scoredStreak = template(1),
		wins = template(1),
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
		bannerSize = textSize,
		bannerSeconds = positive,
		feedSeconds = positive,
		feedMaxEntries = Validate.number({ min = 1, integer = true }),
		glowThickness = Validate.number({ min = 0 }),
		spacing = Validate.number({ min = 0 }),
		pipSize = positive,
		layout = Validate.record({
			scoreboard = place,
			banner = place,
			feed = list,
			hints = list,
			speedometer = Validate.record({ position = udim2, touchPosition = udim2, size = udim2 }),
			reticle = Validate.record({ size = positive }),
			scoreTab = columns,
			scoreButton = place,
			endScreen = place,
		}),
	}),
	markers = Validate.record({
		ringSize = positive,
		ringThickness = positive,
		lineWidth = positive,
		groundProbe = positive,
		groundMarkerSize = positive,
		groundMarkerTransparency = transparency,
		edgeMargin = positive,
		arrowSize = positive,
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
	}),
})

return {
	defaults = defaults,
	schema = schema,
}
