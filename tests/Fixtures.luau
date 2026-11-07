--!strict
-- Shared test data. Not a spec file, so Jest never runs it as a test.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local Crossing = require(ReplicatedStorage.Shared.Rules.Crossing)
local GeometryTypes = require(ReplicatedStorage.Shared.Arena.Geometry.Types)
local MatchEngine = require(ReplicatedStorage.Shared.Rules.MatchEngine)
local Payloads = require(ReplicatedStorage.Shared.Net.Payloads)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)

local Fixtures = {}

-- A stand-in for GuiService's menu (InputController's deps.GuiService): fire MenuOpened and MenuClosed to open
-- and close Roblox's menu, which pauses the controls.
export type Menu = { MenuOpened: Signal.Signal<>, MenuClosed: Signal.Signal<>, MenuIsOpen: boolean? }

-- A screen's areas: the whole screen (ScreenInsets.None), the HUD's (CoreUISafeInsets), the device's safe area
-- (DeviceSafeInsets: the touch controls' and
-- the scoreboard's), which also spans Roblox's 58 px top bar, and the part of the top bar its buttons leave free
-- (GuiService.TopbarInset, in pixels from the safe area's top-left).
export type Screen = { whole: Rect, hud: Rect, controls: Rect, topbar: Rect }

-- A stand-in for the camera the controllers read: the skating steers by its CFrame, and throws and passes aim along
-- the crosshair's line (CameraController:crosshair, #312, #315), which runs from the camera along `aim` (unit);
-- `crosshairs` counts the calls.
export type Camera = {
	CFrame: CFrame,
	aim: Vector3,
	crosshairs: number,
	crosshair: (self: Camera) -> (Vector3, Vector3),
}

-- A round gravity for the pure math that takes gravity as an argument (skating, the ball's path, saves): Roblox's
-- default 196.2, pointing down. The game itself pulls with the config's World.gravity (#279).
Fixtures.GRAVITY = Vector3.new(0, -196.2, 0)

-- A skater's speed after 0.1 s of the stride from rest on flat ground, with the default config: strideAccel 33
-- × 0.1 = 3.3, then 3.3 − (rollingFriction 4 + airDrag 0.02 × 3.3) × 0.1 (#328).
Fixtures.FIRST_STRIDE = 2.8934

-- The gates in a lap, one at each corner of the arena (spec §4.2): every fixture's gates and markers.
Fixtures.GATE_COUNT = 4

-- A camera at `cframe` whose crosshair's line goes along `aim` (its look without one), made unit as the camera's is.
function Fixtures.camera(cframe: CFrame, aim: Vector3?): Camera
	return {
		CFrame = cframe,
		aim = (aim or cframe.LookVector).Unit,
		crosshairs = 0,
		crosshair = function(self: Camera): (Vector3, Vector3)
			self.crosshairs += 1
			return self.CFrame.Position, self.aim
		end,
	}
end

-- A point outside the arena: 10 studs past the outer glass's face and 5 up, at the top straight's middle. The ball
-- there is out, and a skater there is placed back on their spawn.
function Fixtures.outsideArena(config: Config.GameConfig): Vector3
	local arena = config.Arena
	return Centerline.at(arena, arena.straightLength / 2, arena.trackWidth + 10, 5).Position
end

-- The emulated phone in landscape, its safe area 750 x 381 in its whole 874 x 401 screen (a notch's strips round it,
-- probed in Play), and a big screen, whose touch area is 1280 x 800 (the touch buttons grow 1.5 times there) and
-- whose whole screen is its safe area, as on a desktop. Roblox's buttons take the top bar's first 164 px on both, as
-- on our desktop Play view (probed).
Fixtures.PHONE = table.freeze({
	whole = Rect.new(-62, -78, 812, 323),
	hud = Rect.new(0, 0, 750, 323),
	controls = Rect.new(0, -58, 750, 323),
	topbar = Rect.new(164, 0, 750, 58),
}) :: Screen
Fixtures.BIG_SCREEN = table.freeze({
	whole = Rect.new(0, -58, 1280, 742),
	hud = Rect.new(0, 0, 1280, 742),
	controls = Rect.new(0, -58, 1280, 742),
	topbar = Rect.new(164, 0, 1280, 58),
}) :: Screen

-- Roblox's menu, closed unless `isOpen`.
function Fixtures.menu(isOpen: boolean?): Menu
	return { MenuOpened = Signal.new(), MenuClosed = Signal.new(), MenuIsOpen = isOpen }
end

-- Asserts two vectors are within `tolerance` (default 1e-3) of each other.
function Fixtures.expectNear(actual: Vector3, expected: Vector3, tolerance: number?)
	JestGlobals.expect((actual - expected).Magnitude).toBeLessThan(tolerance or 1e-3)
end

-- The same for screen and stick vectors.
function Fixtures.expectNear2(actual: Vector2, expected: Vector2, tolerance: number?)
	JestGlobals.expect((actual - expected).Magnitude).toBeLessThan(tolerance or 1e-3)
end

-- Step-time budgets (#404, the owner's Q286): each is set in seconds as Studio runs on the owner's PC; a slower machine
-- (a slow cloud run: the HUD's 0.1 ms step read 0.144 and 0.166 ms there) scales them by how much slower it runs a
-- fixed workload, plain Luau maths and a property write as a frame's steps are, timed here (its fastest of
-- REFERENCE_ROUNDS) against REFERENCE_SECONDS, its time in Studio there (2.6-3.0 ms, measured). A faster machine keeps
-- the budgets as set, so a step that is itself made slower still fails anywhere.
Fixtures.REFERENCE_SECONDS = 0.0028
Fixtures.REFERENCE_ROUNDS = 5

local function workload(part: Part)
	local sum = Vector3.zero
	local slots = table.create(64, 0)
	for i = 1, 20000 do
		slots[i % 64 + 1] += i
		sum += Vector3.new(i % 7, i % 11, i % 13) * 0.5
		if i % 4 == 0 then
			part.Position = sum
		end
	end
end

-- How many times a budget stretches for a machine that ran the workload in `measured` seconds: never below 1.
function Fixtures.budgetScale(measured: number): number
	return math.max(1, measured / Fixtures.REFERENCE_SECONDS)
end

-- The least of `rounds` calls of `measure` (seconds each): a round the machine was interrupted in reads slow.
function Fixtures.fastest(rounds: number, measure: () -> number): number
	local best = math.huge
	for _ = 1, rounds do
		best = math.min(best, measure())
	end
	return best
end

local slowness: number? = nil

-- This machine's budgetScale, measured once per spec file.
function Fixtures.slowness(): number
	if slowness == nil then
		local part = Instance.new("Part")
		slowness = Fixtures.budgetScale(Fixtures.fastest(Fixtures.REFERENCE_ROUNDS, function(): number
			local started = os.clock()
			workload(part)
			return os.clock() - started
		end))
		part:Destroy()
	end
	return slowness :: number
end

-- Asserts `seconds`, a time measured here, is within `budget` (seconds in Studio on the owner's PC) on this machine.
function Fixtures.expectWithinBudget(seconds: number, budget: number)
	JestGlobals.expect(seconds).toBeLessThan(budget * Fixtures.slowness())
end

-- Where a gravity-only flight from `from` at `velocity` is once it has covered `across` studs at right angles to
-- `gravity`: the kinematics alone, to check where a throw comes down apart from how it was aimed (#313).
function Fixtures.flightAcross(from: Vector3, velocity: Vector3, gravity: Vector3, across: number): Vector3
	local down = gravity.Unit
	local time = across / (velocity - down * velocity:Dot(down)).Magnitude
	return from + velocity * time + gravity * (0.5 * time * time)
end

-- A slope of the arena beside a carrier (#345): a slab in `parent` whose top face is the plane through `point`, rising
-- `degrees` from the root's own floor toward its right. A root upright over it leans less than the slope, as a skater
-- just landed on one does, so the hand on its uphill side dips into it. Returns the face's normal too.
function Fixtures.slopeBeside(parent: Instance, root: CFrame, point: Vector3, degrees: number): (Part, Vector3)
	local tilt = math.rad(degrees)
	local rising = root.RightVector * math.cos(tilt) + root.UpVector * math.sin(tilt)
	local normal = root.UpVector * math.cos(tilt) - root.RightVector * math.sin(tilt)
	local slab = Instance.new("Part")
	slab.Anchored = true
	slab.Size = Vector3.new(40, 1, 40)
	slab.CFrame = CFrame.fromMatrix(point - normal * 0.5, rising, normal)
	slab.Parent = parent
	return slab, normal
end

-- Where a sphere of `radius` moving from `from` to `to` first touches the plane through `point` with `normal`, from
-- the side the normal faces: its centre then, or nil if it stays clear of the plane all the way (#345). The closed
-- form, to check a shapecast apart from Roblox's (it matched stepping the sphere in 1e-6 steps, #345).
function Fixtures.sphereMeetsPlane(
	from: Vector3,
	to: Vector3,
	radius: number,
	point: Vector3,
	normal: Vector3
): Vector3?
	local start = (from - point):Dot(normal) - radius
	local finish = (to - point):Dot(normal) - radius
	if finish >= 0 then
		return nil
	end
	return from + (to - from) * (start / (start - finish))
end

-- Jest's toBeCloseTo as a plain check: `value` within half of 10^-digits of `expected`.
function Fixtures.closeTo(value: number, expected: number, digits: number): boolean
	return math.abs(value - expected) < 10 ^ -digits / 2
end

-- How many failed checks Fixtures.checks names; the rest are only counted.
local CHECKS_NAMED = 10

-- Many checks gathered into one expect, for tests over thousands of pieces: Jest's expect is slow, and one call per
-- corner took a test to about 4 s, near Jest's 5 s limit for a test, which timed out CI's cloud run (#208).
-- - `check(ok, what, piece?)` notes a failed check; `what` is a constant, so a passing check builds no string;
-- - `expectNone()`, once at the end, fails naming the first few and counting the rest.
function Fixtures.checks(): ((ok: boolean, what: string, piece: number?) -> (), () -> ())
	local failed: { string } = {}
	local count = 0
	local function check(ok: boolean, what: string, piece: number?)
		if ok then
			return
		end
		count += 1
		if #failed < CHECKS_NAMED then
			table.insert(failed, if piece ~= nil then `{what} (piece {piece})` else what)
		end
	end
	local function expectNone()
		if count > #failed then
			table.insert(failed, `and {count - #failed} more`)
		end
		JestGlobals.expect(failed).toEqual({})
	end
	return check, expectNone
end

-- Every root Fixtures.mount made since the last Fixtures.unmountAll.
local roots: { any } = {}

-- Renders `element` into a new folder under `parent` with React Luau's legacy root, which renders synchronously, so
-- its instances exist as soon as this returns. Returns the folder, a function that renders another element in its
-- place, and one that unmounts it. React is required here, so specs that never mount never load it.
function Fixtures.mount(element: any, parent: Instance): (Folder, (element: any) -> (), () -> ())
	local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox) :: any
	local folder = Instance.new("Folder")
	folder.Name = "Mount"
	folder.Parent = parent
	local root = ReactRoblox.createLegacyRoot(folder)
	root:render(element)
	table.insert(roots, root)
	return folder, function(nextElement: any)
		root:render(nextElement)
	end, function()
		root:unmount()
	end
end

-- Whether `object` shows anything: a filled frame, words or a picture.
local function inked(object: GuiObject): boolean
	if object:IsA("TextLabel") then
		return object.Text ~= ""
	elseif object:IsA("ImageLabel") then
		return object.Image ~= ""
	end
	return object.BackgroundTransparency < 1
end

-- Pixels from each edge of a laid-out `group` to the nearest ink inside it: every part that shows and its outline's
-- ink (a UIStroke's thickness outside it). A CanvasGroup cuts off what reaches past its edges (#355, #383, #386).
function Fixtures.inkRoom(group: GuiObject): { [string]: number }
	local at, size = group.AbsolutePosition, group.AbsoluteSize
	local sides = { left = math.huge, top = math.huge, right = math.huge, bottom = math.huge }
	for _, object in group:GetDescendants() do
		if object:IsA("GuiObject") and object.Visible and inked(object) then
			local stroke = object:FindFirstChildOfClass("UIStroke")
			local ink = if stroke ~= nil and stroke.Enabled then stroke.Thickness else 0
			local from, to = object.AbsolutePosition, object.AbsolutePosition + object.AbsoluteSize
			sides.left = math.min(sides.left, from.X - ink - at.X)
			sides.top = math.min(sides.top, from.Y - ink - at.Y)
			sides.right = math.min(sides.right, at.X + size.X - to.X - ink)
			sides.bottom = math.min(sides.bottom, at.Y + size.Y - to.Y - ink)
		end
	end
	return sides
end

-- Unmounts every root Fixtures.mount made, so React lets go of them: each component spec's afterEach calls it.
-- Unmounting a root a second time does nothing (probed).
function Fixtures.unmountAll()
	for _, root in roots do
		root:unmount()
	end
	table.clear(roots)
end

-- The console React Luau reports to outside __DEV__ (the luau-polyfill's), found by its package's name so no version
-- is written here.
local function reactConsole(): any
	for _, package in ReplicatedStorage.Packages._Index:GetChildren() do
		if string.find(package.Name, "^roblox_luau%-polyfill%-console@") ~= nil then
			return require(package:FindFirstChild("luau-polyfill-console") :: ModuleScript) :: any
		end
	end
	error("Fixtures.reactReports: React's console package was not found", 0)
end

-- What React reports while `run` runs: each error an error boundary catches, which React warns of outside __DEV__.
-- Kept out of the Output, so a test that breaks a part on purpose leaves it clean; React's console is put back after,
-- even when `run` throws.
function Fixtures.reactReports(run: () -> ...any): { string }
	local console = reactConsole()
	local report = console.error
	local reports: { string } = {}
	console.error = function(message: any)
		table.insert(reports, tostring(message))
	end
	local ok, problem = pcall(run)
	console.error = report
	if not ok then
		error(problem, 0)
	end
	return reports
end

-- A binding tests can drive with Fire, added to the context's input action called `name`.
function Fixtures.scriptedBinding(context: InputContext, name: string): InputBinding
	local binding = Instance.new("InputBinding")
	binding.Type = Enum.InputBindingType.Scriptable
	binding.Parent = context:FindFirstChild(name) :: InputAction
	return binding
end

local GATE_SPACING = 100
local GATE_SIZE = 40
-- Every streak starts at the goal's gate (spec §4.2), so it is the next gate from the kickoff on.
local GOAL_GATE = Config.defaults().Arena.goalGateIndex

function Fixtures.mode(overrides: { [string]: any }?): Config.Mode
	return { id = "Test", displayName = "Test", itemsEnabled = false, overrides = overrides or {} }
end

function Fixtures.config(overrides: { [string]: any }?): Config.GameConfig
	return Config.forMode(Fixtures.mode(overrides))
end

-- The server's BallLook (#400) started with a mesh maker that never reaches Roblox (an empty MeshPart), for the
-- services that dress each ball they build (BallService). Required here, not at the top: only server specs use it.
function Fixtures.ballLook(config: Config.GameConfig): any
	local BallLook = require(game:GetService("ServerScriptService").Server.BallLook) :: any
	BallLook:init({
		Config = config,
		MakeMesh = function(_id: string): MeshPart
			return Instance.new("MeshPart")
		end,
	})
	return BallLook
end

-- A player's line in the score tab, with no points yet.
function Fixtures.playerStats(id: Types.PlayerId, team: Team.Team): Types.PlayerStats
	return {
		player = id,
		team = team,
		joinOrder = tonumber(id) :: number,
		score = 0,
		goals = 0,
		assists = 0,
		saves = 0,
		steals = 0,
	}
end

-- `count` players with no points, ids "1" to `count`, alternately Blue and Orange.
function Fixtures.roster(count: number): { Types.PlayerStats }
	local players: { Types.PlayerStats } = {}
	for index = 1, count do
		table.insert(players, Fixtures.playerStats(tostring(index), if index % 2 == 1 then "Blue" else "Orange"))
	end
	return players
end

-- What the server sends the HUD: a live match two minutes from the end with players "1" (Blue, Ana) and "2" (Orange,
-- Rex), no lap progress yet (the goal's gate next), its fields changed by `overrides`, taken on server frame `frame`
-- (default 0).
function Fixtures.matchSnapshot(overrides: { [string]: any }?, frame: number?): Payloads.MatchSnapshot
	local match: { [string]: any } = {
		state = "Live",
		period = "Regulation",
		phaseSecondsLeft = 0,
		secondsLeft = 120,
		scores = { Blue = 0, Orange = 0 },
		streak = 0,
		lapProgress = 0,
		gateCount = Fixtures.GATE_COUNT,
		nextGate = GOAL_GATE,
		stats = {
			scores = { Blue = 0, Orange = 0 },
			players = { Fixtures.playerStats("1", "Blue"), Fixtures.playerStats("2", "Orange") },
		},
	}
	local changes: { [string]: any } = overrides or {}
	for key, value in changes do
		match[key] = value
	end
	return { frame = frame or 0, match = match :: any, names = { ["1"] = "Ana", ["2"] = "Rex" } }
end

-- The match once `team`'s streak has counted its last lap (#384, the owner's Q255): the goal open at its most, the
-- lap held full and no gate next, taken on server frame `frame` (default 0).
function Fixtures.lapCapped(team: Team.Team, frame: number?): Payloads.MatchSnapshot
	local payload = Fixtures.matchSnapshot({
		possessingTeam = team,
		goalOpenFor = team,
		streak = #Config.defaults().Match.goalPointsByLap,
		lapProgress = Fixtures.GATE_COUNT,
	}, frame)
	payload.match.nextGate = nil
	return payload
end

-- One server frame's rule events as the server sends them, on frame `frame` (default 1: after matchSnapshot's).
function Fixtures.ruleEvents(events: { Types.Event }, frame: number?): Payloads.RuleEvents
	return { frame = frame or 1, events = events }
end

-- A straight synthetic "track": every gate faces +X, so a segment moving +X crosses it forward.
function Fixtures.gate(x: number): Crossing.Rectangle
	local position = Vector3.new(x, 0, 0)
	return { frame = CFrame.lookAt(position, position + Vector3.xAxis), width = GATE_SIZE, height = GATE_SIZE }
end

function Fixtures.gates(): { Crossing.Rectangle }
	local gates = {}
	for index = 1, Fixtures.GATE_COUNT do
		table.insert(gates, Fixtures.gate(GATE_SPACING * index))
	end
	return gates
end

-- Like the arena's goal at Gate 2: on Gate 2's plane, raised, and inside its rectangle.
function Fixtures.ring(): Crossing.Disc
	local position = Vector3.new(2 * GATE_SPACING, 15, 0)
	return { frame = CFrame.lookAt(position, position + Vector3.xAxis), radius = 3 }
end

function Fixtures.arena(): MatchEngine.ArenaLayout
	return { gates = Fixtures.gates(), goal = Fixtures.ring() }
end

function Fixtures.throughGate(index: number): (Vector3, Vector3)
	local x = GATE_SPACING * index
	return Vector3.new(x - 1, 0, 0), Vector3.new(x + 1, 0, 0)
end

-- The triangular face of a wedge piece on the side `normal` points to: right-angle corner, top corner, front corner.
function Fixtures.wedgeFace(piece: GeometryTypes.Piece, normal: Vector3): { Vector3 }
	local half = piece.size / 2
	local side = if piece.cframe.RightVector:Dot(normal) > 0 then half.X else -half.X
	return {
		piece.cframe:PointToWorldSpace(Vector3.new(side, -half.Y, half.Z)),
		piece.cframe:PointToWorldSpace(Vector3.new(side, half.Y, half.Z)),
		piece.cframe:PointToWorldSpace(Vector3.new(side, -half.Y, -half.Z)),
	}
end

-- A stand-in for a Player: Roblox cannot create one in Edit, so it has just the members the services use.
function Fixtures.stubPlayer(userId: number): any
	local attributes: { [string]: any } = {}
	return {
		UserId = userId,
		SetAttribute = function(_self: any, key: string, value: any)
			attributes[key] = value
		end,
		GetAttribute = function(_self: any, key: string): any
			return attributes[key]
		end,
	}
end

-- A stand-in for a player's character: a Humanoid rig whose hand is welded to its root, R15 unless R6 is asked
-- for. R15: RightHand, HipHeight 2. R6: Right Arm and Left Leg, HipHeight 0. Nothing is anchored.
function Fixtures.rig(parent: Instance, name: string, cframe: CFrame, rigType: Enum.HumanoidRigType?): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = SkaterRig.root
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = cframe
	root.Parent = model
	local function limb(limbName: string, size: Vector3, offset: CFrame)
		local part = Instance.new("Part")
		part.Name = limbName
		part.Size = size
		part.CFrame = cframe * offset
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	local humanoid = Instance.new("Humanoid")
	if rigType == Enum.HumanoidRigType.R6 then
		limb("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 0, 0))
		limb("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, -2, 0))
		humanoid.RigType = Enum.HumanoidRigType.R6
		humanoid.HipHeight = 0
	else
		limb("RightHand", Vector3.new(1, 1, 1), CFrame.new(1.5, -0.5, -0.5))
		humanoid.RigType = Enum.HumanoidRigType.R15
		humanoid.HipHeight = 2
	end
	humanoid.Parent = model
	model.PrimaryPart = root
	model.Parent = parent
	return model
end

-- A server placement as the rig's client sees it (#307): its Placed count moves on, which holds the skater still
-- for that step and starts them over from rest.
function Fixtures.placed(rig: Model)
	local count: number? = rig:GetAttribute(Attributes.Placed) :: number?
	rig:SetAttribute(Attributes.Placed, (count or 0) + 1)
end

-- A server placement as CharacterService announces it (#424): the rig stood at `cframe`, then `placed` fired with where
-- its root stood before and after.
function Fixtures.announcePlacement(
	placed: Signal.Signal<Types.PlayerId, Vector3, Vector3>,
	id: Types.PlayerId,
	rig: Model,
	cframe: CFrame
)
	local root = Fixtures.root(rig)
	local from = root.Position
	rig:PivotTo(cframe)
	placed:Fire(id, from, root.Position)
end

-- A rig's root part, found by the name Roblox gives it in every character.
function Fixtures.root(rig: Model): BasePart
	return rig:FindFirstChild(SkaterRig.root) :: BasePart
end

export type HudArena = { hoop: Model, rim: { BasePart }, panel: BasePart, markers: { Model } }

-- The arena parts the HUD lights and points at, tagged as the arena builder tags them: a goal hoop of two rim parts,
-- pivoted at its opening's centre between them, facing along z, with the builder's opening radius (Arena.goal
-- .ringRadius), glowing while the goal is open as before its meshes come; its panel; and four corner markers 100
-- studs apart along x, by gate index, each a model of two panes pivoted between them (as a gate panel is at its
-- wall's middle). Anchored, in `folder`.
function Fixtures.hudArena(folder: Instance): HudArena
	local function part(name: string, position: Vector3, parent: Instance): Part
		local made = Instance.new("Part")
		made.Name = name
		made.Anchored = true
		made.Size = Vector3.new(2, 2, 2)
		made.Position = position
		made.Parent = parent
		return made
	end
	local hoop = Instance.new("Model")
	hoop.Name = "GoalHoop"
	local rim: { BasePart } =
		{ part("Rim1", Vector3.new(0, 20, -40), hoop), part("Rim2", Vector3.new(4, 20, -40), hoop) }
	hoop.WorldPivot = CFrame.new(2, 20, -40)
	hoop:SetAttribute(Tags.Attribute.OpeningRadius, Config.defaults().Arena.goal.ringRadius)
	hoop.Parent = folder
	hoop:AddTag(Tags.GoalHoop)
	hoop:AddTag(Tags.GoalGlow)
	local panel = part("GoalPanel", Vector3.new(2, 20, -40), folder)
	panel:AddTag(Tags.GoalPanel)
	local markers: { Model } = {}
	for index = 1, Fixtures.GATE_COUNT do
		local marker = Instance.new("Model")
		marker.Name = `Marker{index}`
		part("Pane1", Vector3.new(index * 100, 1, 0), marker)
		part("Pane2", Vector3.new(index * 100, 9, 0), marker)
		marker.WorldPivot = CFrame.new(index * 100, 5, 0)
		marker:SetAttribute(Tags.Attribute.GateIndex, index)
		marker:AddTag(Tags.CornerMarker)
		marker.Parent = folder
		markers[index] = marker
	end
	return { hoop = hoop, rim = rim, panel = panel, markers = markers }
end

-- A wide ride surface whose top is the plane y = 0, in `folder`.
function Fixtures.floor(folder: Instance): Part
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(400, 1, 400)
	floor.CFrame = CFrame.new(0, -0.5, 0)
	floor.Parent = folder
	floor:AddTag(Tags.RideSurface)
	return floor
end

-- A ride surface's normal read as the face its ray met (SmoothNormals.reader's shape): for specs whose slabs are
-- not the arena (#294).
function Fixtures.faceNormal(_position: Vector3, face: Vector3): Vector3
	return face
end

-- Another player's skater as the skating sees it (SkateController's views): a character in `folder` named `player`
-- with an anchored root at `position`, on `team`. Returns the view and the character.
function Fixtures.otherSkater(folder: Instance, player: Types.PlayerId, position: Vector3, team: string): (any, Model)
	local character = Instance.new("Model")
	character.Name = player
	local root = Instance.new("Part")
	root.Name = SkaterRig.root
	root.Anchored = true
	root.CanCollide = false
	root.Size = Vector3.new(2, 2, 1)
	root.Position = position
	root.Parent = character
	character.Parent = folder
	return { player = player, team = team, root = root }, character
end

-- Starts the local player's skating and actions as the client does, with fakes for the live game (a camera looking
-- along -Z, nothing sent): InputController (its context in `folder`), BallCarrier, RideSurfaces, SkateController and
-- ActionController, for the local player `localId` on Blue. The skating sees the other players in `others` (none
-- without it; a spec may fill the list later). Ride surfaces must be in place first, as RideSurfaces reads them here.
-- The client's modules are required here, so specs that never skate never load them.
function Fixtures.startSkating(folder: Instance, config: Config.GameConfig, localId: Types.PlayerId, others: { any }?)
	local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
	local InputController = require(Client.InputController) :: any
	local BallCarrier = require(Client.BallCarrier) :: any
	local RideSurfaces = require(Client.RideSurfaces) :: any
	local SkateController = require(Client.SkateController) :: any
	local ActionController = require(Client.ActionController) :: any
	local camera = Fixtures.camera(CFrame.new())
	local views = others or {}
	-- No goal: the arena's parts have not reached this client.
	local arenaParts = { parts = nil }
	InputController:init({ Config = config, Parent = folder })
	BallCarrier:init({})
	RideSurfaces:init({})
	SkateController:init({
		Config = config,
		InputController = InputController,
		RideSurfaces = RideSurfaces,
		SmoothNormal = Fixtures.faceNormal,
		Camera = camera,
		Skaters = function(): { any }
			return views
		end,
		SendSkateState = function() end,
		SendGetUp = function() end,
		Team = function(): string?
			return "Blue"
		end,
		ArenaParts = arenaParts,
	})
	ActionController:init({
		Config = config,
		InputController = InputController,
		BallCarrier = BallCarrier,
		SkateController = SkateController,
		-- What hides a pass's receiver (#315 Q155).
		RideSurfaces = RideSurfaces,
		ArenaParts = arenaParts,
		Camera = camera,
		SendRequest = function() end,
		LocalId = localId,
	})
end

-- The local player's skater: a rig built as the server builds it, standing at the origin and taken by the skating
-- (Fixtures.startSkating first).
function Fixtures.spawnSkater(folder: Instance, config: Config.GameConfig): Model
	local SkaterBody = require(game:GetService("ServerScriptService").Server.SkaterBody) :: any
	local SkateController = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.SkateController) :: any
	local rig = Fixtures.rig(folder, "Skater", CFrame.new(0, config.Movement.hoverHeight, 0))
	SkaterBody.build(rig, config.Movement)
	SkateController:bind(rig)
	return rig
end

-- The local player's tackle (#240), or with the ball their dodge (#314), just into its follow-up window: the tackle key
-- names the Dive now (Fixtures.startSkating first).
function Fixtures.intoDiveWindow(config: Config.GameConfig, from: Config.ActionName?)
	local ActionController =
		require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.ActionController) :: any
	local source: Config.ActionName = from or "Tackle"
	local runner = ActionController.runner
	runner:start(source, { hasBall = source == "Dodge", knockedDown = false })
	runner:step((config.Actions[source].followUp :: Config.FollowUp).from + 0.02)
end

-- An R15 rig whose joints are Motor6Ds, named as the avatar's own joints are. The parts all sit on `cframe`: only the
-- joints matter to the tests that use it.
function Fixtures.jointedRig(parent: Instance, name: string, cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = name
	local parts: { [string]: BasePart } = {}
	for _, partName in
		{
			SkaterRig.root,
			"LowerTorso",
			"UpperTorso",
			"LeftUpperLeg",
			"LeftLowerLeg",
			"RightUpperLeg",
			"RightLowerLeg",
			"RightUpperArm",
		}
	do
		local part = Instance.new("Part")
		part.Name = partName
		part.Size = if partName == SkaterRig.root then Vector3.new(2, 2, 1) else Vector3.new(1, 1, 1)
		part.CFrame = cframe
		part.Parent = model
		parts[partName] = part
	end
	local joints = {
		{ name = "Root", from = SkaterRig.root, to = "LowerTorso" },
		{ name = "Waist", from = "LowerTorso", to = "UpperTorso" },
		{ name = "LeftHip", from = "LowerTorso", to = "LeftUpperLeg" },
		{ name = "LeftKnee", from = "LeftUpperLeg", to = "LeftLowerLeg" },
		{ name = "RightHip", from = "LowerTorso", to = "RightUpperLeg" },
		{ name = "RightKnee", from = "RightUpperLeg", to = "RightLowerLeg" },
		{ name = "RightShoulder", from = "UpperTorso", to = "RightUpperArm" },
	}
	for _, joint in joints do
		local motor = Instance.new("Motor6D")
		motor.Name = joint.name
		motor.Part0 = parts[joint.from]
		motor.Part1 = parts[joint.to]
		motor.Parent = parts[joint.from]
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = parts[SkaterRig.root]
	model.Parent = parent
	return model
end

-- Also crosses Gate 2, whose rectangle contains the ring.
function Fixtures.throughRing(): (Vector3, Vector3)
	local x = 2 * GATE_SPACING
	return Vector3.new(x - 1, 15, 0), Vector3.new(x + 1, 15, 0)
end

return Fixtures
