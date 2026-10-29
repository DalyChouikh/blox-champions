--!strict
-- Shared test data. Not a spec file, so Jest never runs it as a test.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- A screen's two areas: the HUD's (CoreUISafeInsets) and the touch controls' (DeviceSafeInsets), which also spans
-- Roblox's 58 px top bar.
export type Screen = { hud: Rect, controls: Rect }

-- A round gravity for the pure math that takes gravity as an argument (skating, the ball's path, saves): Roblox's
-- default 196.2, pointing down. The game itself pulls with the config's World.gravity (#279).
Fixtures.GRAVITY = Vector3.new(0, -196.2, 0)

-- The gates in a lap, one at each corner of the arena (spec §4.2): every fixture's gates and markers.
Fixtures.GATE_COUNT = 4

-- A point outside the arena: 10 studs past the outer glass's face and 5 up, at the top straight's middle. The ball
-- there is out, and a skater there is placed back on their spawn.
function Fixtures.outsideArena(config: Config.GameConfig): Vector3
	local arena = config.Arena
	return Centerline.at(arena, arena.straightLength / 2, arena.trackWidth + 10, 5).Position
end

-- The emulated iPhone 17 Pro in landscape (probed in Play), and a big screen, whose touch area is 1280 x 800 (the
-- touch buttons grow 1.5 times there).
Fixtures.PHONE = table.freeze({ hud = Rect.new(0, 0, 750, 323), controls = Rect.new(0, -58, 750, 323) }) :: Screen
Fixtures.BIG_SCREEN =
	table.freeze({ hud = Rect.new(0, 0, 1280, 742), controls = Rect.new(0, -58, 1280, 742) }) :: Screen

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

-- Unmounts every root Fixtures.mount made, so React lets go of them: each component spec's afterEach calls it.
-- Unmounting a root a second time does nothing (probed).
function Fixtures.unmountAll()
	for _, root in roots do
		root:unmount()
	end
	table.clear(roots)
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

-- A player's line in the score tab, with no points yet.
function Fixtures.playerStats(id: Types.PlayerId, team: Team.Team, present: boolean): Types.PlayerStats
	return {
		player = id,
		team = team,
		joinOrder = tonumber(id) :: number,
		present = present,
		score = 0,
		goals = 0,
		assists = 0,
		saves = 0,
		steals = 0,
	}
end

-- `count` players with no points, ids "1" to `count`, alternately Blue and Orange, all still in the match.
function Fixtures.roster(count: number): { Types.PlayerStats }
	local players: { Types.PlayerStats } = {}
	for index = 1, count do
		table.insert(players, Fixtures.playerStats(tostring(index), if index % 2 == 1 then "Blue" else "Orange", true))
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
		overtimeSeconds = 0,
		scores = { Blue = 0, Orange = 0 },
		streak = 0,
		lapProgress = 0,
		gateCount = Fixtures.GATE_COUNT,
		nextGate = GOAL_GATE,
		stats = {
			scores = { Blue = 0, Orange = 0 },
			players = { Fixtures.playerStats("1", "Blue", true), Fixtures.playerStats("2", "Orange", true) },
		},
	}
	local changes: { [string]: any } = overrides or {}
	for key, value in changes do
		match[key] = value
	end
	return { frame = frame or 0, match = match :: any, names = { ["1"] = "Ana", ["2"] = "Rex" } }
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

-- A rig's root part, found by the name Roblox gives it in every character.
function Fixtures.root(rig: Model): BasePart
	return rig:FindFirstChild(SkaterRig.root) :: BasePart
end

export type HudArena = { hoop: Model, rim: { BasePart }, panel: BasePart, markers: { Model } }

-- The arena parts the HUD lights and points at, tagged as the arena builder tags them: a goal hoop of two rim parts,
-- its panel, and four corner markers 100 studs apart along x, by gate index, each a model of two panes pivoted between
-- them (as a gate panel is at its wall's middle). Anchored, in `folder`.
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
	hoop.Parent = folder
	hoop:AddTag(Tags.GoalHoop)
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

-- Starts the local player's skating and actions as the client does, with fakes for the live game (a camera looking
-- along -Z, nothing sent): InputController (its context in `folder`), BallCarrier, RideSurfaces, SkateController and
-- ActionController, for the local player `localId`. Ride surfaces must be in place first, as RideSurfaces reads them
-- here. The client's modules are required here, so specs that never skate never load them.
function Fixtures.startSkating(folder: Instance, config: Config.GameConfig, localId: Types.PlayerId)
	local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
	local InputController = require(Client.InputController) :: any
	local BallCarrier = require(Client.BallCarrier) :: any
	local RideSurfaces = require(Client.RideSurfaces) :: any
	local SkateController = require(Client.SkateController) :: any
	local ActionController = require(Client.ActionController) :: any
	InputController:init({ Config = config, Parent = folder })
	BallCarrier:init({})
	RideSurfaces:init({})
	SkateController:init({
		Config = config,
		InputController = InputController,
		RideSurfaces = RideSurfaces,
		Camera = { CFrame = CFrame.new() },
		Skaters = function(): { any }
			return {}
		end,
		SendSkateState = function() end,
		SendGetUp = function() end,
		Team = function(): string?
			return "Blue"
		end,
	})
	ActionController:init({
		Config = config,
		InputController = InputController,
		BallCarrier = BallCarrier,
		SkateController = SkateController,
		Camera = { CFrame = CFrame.new() },
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

-- The local player's tackle, just into its follow-up window (#240): the tackle key names the Dive now
-- (Fixtures.startSkating first).
function Fixtures.intoDiveWindow(config: Config.GameConfig)
	local ActionController =
		require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.ActionController) :: any
	local runner = ActionController.runner
	runner:start("Tackle", { hasBall = false, knockedDown = false })
	runner:step((config.Actions.Tackle.followUp :: Config.FollowUp).from + 0.02)
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
