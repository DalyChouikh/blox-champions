--!strict
-- The fire lines (#412, the owner's Q300-Q303 and Q329; Arena spec §5.4): each gate the team with the ball passes sends
-- a fireball in its colour forward along the outer wall to the next gate, and the line it draws stays. Each lap of
-- the streak adds a line above the last: lap 1's at the wall's glass line, each next lap's arenaGlow.fireLines.spacing
-- higher, one a lap the streak counts (Match.goalPointsByLap). When the streak ends (a goal, a steal, a kickoff) the
-- lines fade out quickly; the next streak's start again from its first gate. Read from the HUD's state: every streak
-- starts at the goal's gate (LapTracker), so its snapshot's laps and lap progress say which gates it has passed. A gate
-- this client sees passed sends its fireball; those already passed when it first sees the match show at once. Each
-- client draws its own: the parts stay on this client, and nothing hits, sees or touches them. Stepped before each
-- frame is drawn (FrameController), after the goal's worth: it acts when the HUD's state changes, and each frame only
-- while a fireball flies or the lines fade, writing Size, Position and Transparency (no new CFrame).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local DrawnPart = require(ReplicatedStorage.Shared.Util.DrawnPart)
local HudStore = require(script.Parent.HudStore)
local MatchEngine = require(ReplicatedStorage.Shared.Rules.MatchEngine)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local WallLine = require(ReplicatedStorage.Shared.Arena.Geometry.WallLine)

type Team = Team.Team

local SHOWN, HIDDEN = 0, 1
-- How far a line stands off the wall beyond its own half thickness, so it never sinks into the surface.
local GAP = 0.05
-- A cylinder's axis is its X: turned to run along its piece.
local ALONG = CFrame.Angles(0, math.pi / 2, 0)

-- One straight piece of a line: its part, the distances along the track it runs between, its two ends, its
-- direction, and its full size and middle.
type Piece = {
	part: Part,
	from: number,
	to: number,
	start: Vector3,
	finish: Vector3,
	along: Vector3,
	size: Vector3,
	middle: Vector3,
}

-- One line, from a gate to the next on one lap of a streak: its pieces in travel order and its fireball, the
-- distances along the track it runs between, and what it shows: how many pieces show (the first `shown`), how many of
-- them whole, whether its fireball shows, the seconds since its gate was passed while its fireball has yet to arrive
-- (nil otherwise), and its colour.
type Line = {
	pieces: { Piece },
	fireball: Part,
	from: number,
	to: number,
	shown: number,
	whole: number,
	ball: boolean,
	flying: number?,
	color: Color3?,
}

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type FireLines = {
	name: string,
	dependencies: { string },
	init: (self: FireLines, deps: { [string]: any }) -> (),
	start: (self: FireLines) -> (),
	step: (self: FireLines, dt: number) -> (),
	-- Every line, built at start.
	model: Model,
	_config: Config.GameConfig,
	_store: HudStore.HudStore,
	_parent: Instance,
	-- In the order a streak passes their gates: lap 1's from the goal's gate round, then lap 2's.
	_lines: { Line },
	-- What was last acted on: the HUD state's version, the team with the ball and how many gates its streak has passed
	-- (the first `_passed` lines lit), whether a match has been seen, the lines in flight, and the fade: how many lines
	-- it takes out (the first `_fadeCount`) and the seconds into it (nil when none fades).
	_version: number?,
	_team: Team?,
	_passed: number,
	_seen: boolean,
	_flights: number,
	_fadeCount: number,
	_fading: number?,
}

-- How many gates the streak of the team with the ball has passed: its whole laps' and those of the lap it is on.
-- Once it has counted its last lap, that lap stays full with no gate next (LapTracker): counted once.
local function passedOf(match: MatchEngine.Snapshot?): number
	if match == nil or match.possessingTeam == nil then
		return 0
	end
	local laps = if match.nextGate == nil then match.streak - 1 else match.streak
	return laps * match.gateCount + match.lapProgress
end

local function buildLine(self: FireLines, parent: Instance, lap: number, gate: number, height: number): Line
	local settings = self._config.UI.arenaGlow
	local thickness = settings.fireLines.thickness
	local model = Instance.new("Model")
	model.Name = `Lap{lap}Gate{gate}`
	local pieces: { Piece } = {}
	for index, piece in WallLine.section(self._config.Arena, gate, height, thickness / 2 + GAP) do
		local along = piece.finish - piece.start
		local middle = (piece.start + piece.finish) / 2
		local size = Vector3.new(along.Magnitude, thickness, thickness)
		local part = DrawnPart(`Piece{index}`, Enum.PartType.Cylinder)
		part.Material = settings.material
		part.Size = size
		part.CFrame = CFrame.lookAt(middle, piece.finish) * ALONG
		part.Parent = model
		table.insert(pieces, {
			part = part,
			from = piece.from,
			to = piece.to,
			start = piece.start,
			finish = piece.finish,
			along = along.Unit,
			size = size,
			middle = middle,
		})
	end
	local fireball = DrawnPart("Fireball", Enum.PartType.Ball)
	fireball.Material = settings.material
	fireball.Size = Vector3.one * settings.fireLines.fireball
	fireball.Parent = model
	model.Parent = parent
	return {
		pieces = pieces,
		fireball = fireball,
		from = pieces[1].from,
		to = pieces[#pieces].to,
		shown = 0,
		whole = 0,
		ball = false,
		flying = nil,
		color = nil,
	}
end

local function showPiece(line: Line, index: number)
	if index > line.shown then
		line.shown = index
		line.pieces[index].part.Transparency = SHOWN
	end
end

-- Shows `line` up to `reach` along the track: every piece before it whole, the one it is on up to it. Returns where
-- that is: the line's end once it shows whole.
local function reveal(line: Line, reach: number): Vector3
	local pieces = line.pieces
	for index = line.whole + 1, #pieces do
		local piece = pieces[index]
		local part = piece.part
		showPiece(line, index)
		if reach < piece.to then
			local length = piece.size.X * (reach - piece.from) / (piece.to - piece.from)
			local tip = piece.start + piece.along * length
			part.Size = Vector3.new(length, piece.size.Y, piece.size.Z)
			part.Position = (piece.start + tip) / 2
			return tip
		end
		part.Size = piece.size
		part.Position = piece.middle
		line.whole = index
	end
	return pieces[#pieces].finish
end

local function showBall(line: Line, shown: boolean)
	if shown ~= line.ball then
		line.ball = shown
		line.fireball.Transparency = if shown then SHOWN else HIDDEN
	end
end

-- Lights `line` for `team`: its fireball sets off, or the whole line shows at once.
local function light(self: FireLines, line: Line, team: Team, atOnce: boolean)
	local color = self._config.UI.teamColors[team]
	if color ~= line.color then
		line.color = color
		for _, piece in line.pieces do
			piece.part.Color = color
		end
		line.fireball.Color = color
	end
	if atOnce then
		reveal(line, line.to)
	else
		line.flying = 0
		self._flights += 1
	end
end

-- Moves `line`'s fireball `dt` on: it waits delaySeconds, then flies to the next gate in flightSeconds, evenly along
-- the track, the line growing behind it, and is gone once there, at once for a flight that takes no time.
local function fly(self: FireLines, line: Line, dt: number)
	local settings = self._config.UI.arenaGlow.fireLines
	local flying = (line.flying :: number) + dt
	local flown = flying - settings.delaySeconds
	if flown < settings.flightSeconds then
		line.flying = flying
		if flown >= 0 then
			line.fireball.Position = reveal(line, line.from + (line.to - line.from) * flown / settings.flightSeconds)
			showBall(line, true)
		end
	else
		line.flying = nil
		self._flights -= 1
		reveal(line, line.to)
		showBall(line, false)
	end
end

-- The lines the fade took out, hidden, ready to light again.
local function endFade(self: FireLines)
	for index = 1, self._fadeCount do
		local line = self._lines[index]
		for shown = 1, line.shown do
			line.pieces[shown].part.Transparency = HIDDEN
		end
		line.shown, line.whole = 0, 0
	end
	self._fadeCount = 0
	self._fading = nil
end

local function fade(self: FireLines, dt: number)
	local fading = (self._fading :: number) + dt
	local seconds = self._config.UI.arenaGlow.fireLines.fadeSeconds
	if fading < seconds then
		self._fading = fading
		local transparency = SHOWN + (HIDDEN - SHOWN) * fading / seconds
		for index = 1, self._fadeCount do
			local line = self._lines[index]
			for shown = 1, line.shown do
				line.pieces[shown].part.Transparency = transparency
			end
		end
	else
		endFade(self)
	end
end

-- The streak has ended (Q303): its fireballs go at once and its lines start fading.
local function endStreak(self: FireLines)
	for index = 1, self._passed do
		showBall(self._lines[index], false)
	end
	-- A line still marked flying is never stepped again: only lit lines fly, and lighting one sets it off anew.
	self._flights = 0
	self._fadeCount = self._passed
	self._fading = 0
	self._passed = 0
end

local function changed(self: FireLines, match: MatchEngine.Snapshot?)
	local team: Team? = if match ~= nil then match.possessingTeam else nil
	local passed = passedOf(match)
	if self._passed > 0 and (team ~= self._team or passed < self._passed) then
		endStreak(self)
	end
	self._team = team
	if passed > self._passed then
		-- The next streak's first gate ends what is left of the last one's fade.
		if self._fading ~= nil then
			endFade(self)
		end
		for index = self._passed + 1, passed do
			light(self, self._lines[index], team :: Team, not self._seen)
		end
		self._passed = passed
	end
	self._seen = self._seen or match ~= nil
end

local FireLines: FireLines = {
	name = "FireLines",
	dependencies = { "Config", "HudStore" },
	model = nil :: any,
	_config = nil :: any,
	_store = nil :: any,
	_parent = nil :: any,
	_lines = {},
	_version = nil,
	_team = nil,
	_passed = 0,
	_seen = false,
	_flights = 0,
	_fadeCount = 0,
	_fading = nil,

	-- deps.Parent replaces the workspace in tests.
	init = function(self: FireLines, deps: { [string]: any })
		self._config = deps.Config
		self._store = deps.HudStore
		self._parent = deps.Parent or workspace
		self._lines = {}
		self._version = nil
		self._team = nil
		self._passed = 0
		self._seen = false
		self._flights = 0
		self._fadeCount = 0
		self._fading = nil
	end,

	start = function(self: FireLines)
		local config = self._config
		local arena, gates = config.Arena, Centerline.gateCount
		local model = Instance.new("Model")
		model.Name = "FireLines"
		for lap = 1, #config.Match.goalPointsByLap do
			local height = arena.glassLook.outerWall + (lap - 1) * config.UI.arenaGlow.fireLines.spacing
			for step = 1, gates do
				-- The streak's step-th gate of the lap, counted from the goal's.
				local gate = (arena.goalGateIndex + step - 2) % gates + 1
				table.insert(self._lines, buildLine(self, model, lap, gate, height))
			end
		end
		model.Parent = self._parent
		self.model = model
	end,

	step = function(self: FireLines, dt: number)
		local state = self._store.state
		if state.version ~= self._version then
			self._version = state.version
			changed(self, state.match)
		end
		if self._fading ~= nil then
			fade(self, dt)
		end
		if self._flights > 0 then
			for index = 1, self._passed do
				local line = self._lines[index]
				if line.flying ~= nil then
					fly(self, line, dt)
				end
			end
		end
	end,
}

return FireLines
