--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ArenaGlow = require(Client.ArenaGlow)
local ArenaParts = require(Client.ArenaParts)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local GoalDoor = require(ReplicatedStorage.Shared.Arena.Geometry.GoalDoor)
local HudStore = require(Client.HudStore)
local PartSize = require(ReplicatedStorage.Shared.Util.PartSize)
local Payloads = require(ReplicatedStorage.Shared.Net.Payloads)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local config = Config.defaults()
local glow = config.UI.arenaGlow
local colors = config.UI.teamColors
local DT = 1 / 60
-- An invisible part: every gate's panel but the next gate's.
local HIDDEN = 1
-- Every streak starts at the goal's gate (the snapshot fixture's next gate), then goes on to the one after it.
local GOAL_GATE = config.Arena.goalGateIndex
local AFTER_GOAL_GATE = GOAL_GATE % Fixtures.GATE_COUNT + 1

local folder: Folder
local arena: Fixtures.HudArena
-- How each part looked before anything glowed.
local plain: { color: Color3, material: Enum.Material, transparency: number }
-- A door bar's shut look.
type Shut = { frame: CFrame, size: Vector3 }

local function show(payload: Payloads.MatchSnapshot)
	HudStore:onSnapshot(payload)
	ArenaGlow:step(DT)
end

local function snapshot(overrides: { [string]: any }?)
	show(Fixtures.matchSnapshot(overrides))
end

-- Steps for `seconds` (whole frames).
local function stepFor(seconds: number)
	for _ = 1, math.round(seconds / DT) do
		ArenaGlow:step(DT)
	end
end

-- The goal's door as Builder.dressGoal makes it, at the hoop's frame, found by the arena's parts: its bars and
-- their shut looks.
local function addDoor(): ({ BasePart }, { Shut })
	local frame = arena.hoop:GetPivot()
	local door = Instance.new("Model")
	door.Name = "GoalDoor"
	local bars: { BasePart }, shut: { Shut } = {}, {}
	for index, bar in GoalDoor.bars(config.Arena) do
		local part = Instance.new("Part")
		part.Name = `Bar{index}`
		part.Anchored = true
		part.Size = bar.size
		part.CFrame = frame * bar.cframe
		part.Parent = door
		bars[index], shut[index] = part, { frame = part.CFrame, size = part.Size }
	end
	door:AddTag(Tags.GoalDoor)
	door.Parent = folder
	ArenaParts:refresh()
	return bars, shut
end

-- How far the door's edge travels: its longest bars', the middle rows'.
local function reachOf(shut: { Shut }): number
	return shut[config.Arena.goal.door.bars // 2].size.X
end

-- Every bar shows its length past the door's edge, `edge` studs from the middle, moved that much along its +X, or
-- is hidden once the edge has passed its end.
local function expectDoorAt(bars: { BasePart }, shut: { Shut }, edge: number)
	for index, bar in bars do
		local look = shut[index]
		local shown = look.size.X - edge
		if shown < PartSize.MIN then
			expect(bar.LocalTransparencyModifier).toBe(1)
		else
			expect(bar.LocalTransparencyModifier).toBe(0)
			Fixtures.expectNear(bar.Size, Vector3.new(shown, look.size.Y, look.size.Z))
			Fixtures.expectNear(bar.Position, (look.frame * CFrame.new(edge / 2, 0, 0)).Position)
			Fixtures.expectNear(bar.CFrame.RightVector, look.frame.RightVector)
		end
	end
end

-- Whether `part` glows in `color`, or looks as it did before anything glowed (`color` nil).
local function glows(part: BasePart, color: Color3?): boolean
	if color == nil then
		return part.Color == plain.color and part.Material == plain.material
	end
	return part.Color == color and part.Material == glow.material
end

-- Whether every pane of a gate's panel shows, glowing in `color` at the glass's transparency it was built with, or
-- is hidden (`color` nil).
local function panelShows(marker: Model, color: Color3?): boolean
	for _, child in marker:GetChildren() do
		local pane = child :: BasePart
		local shows = if color == nil
			then pane.Transparency == HIDDEN
			else glows(pane, color) and math.abs(pane.Transparency - config.Arena.glass.transparency) < 1e-4
		if not shows then
			return false
		end
	end
	return true
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ArenaGlowTest"
	folder.Parent = workspace
	arena = Fixtures.hudArena(folder)
	plain = { color = arena.panel.Color, material = arena.panel.Material, transparency = arena.panel.Transparency }
	-- Built as the Builder builds the gate walls: see-through glass.
	for _, marker in arena.markers do
		for _, pane in marker:GetChildren() do
			(pane :: BasePart).Transparency = config.Arena.glass.transparency
		end
	end
	ArenaParts:init({})
	HudStore:init({ Config = config, LocalId = "1" })
	ArenaGlow:init({
		Config = config,
		HudStore = HudStore,
		ArenaParts = ArenaParts,
	})
	snapshot()
end)

afterEach(function()
	ArenaParts:destroy()
	folder:Destroy()
end)

describe("ArenaGlow", function()
	it("lights the goal ring in the team's colour while the goal is open, and puts it back after", function()
		for _, rim in arena.rim do
			expect(glows(rim, nil)).toBe(true)
		end
		snapshot({ possessingTeam = "Blue", goalOpenFor = "Blue" })
		for _, rim in arena.rim do
			expect(glows(rim, colors.Blue)).toBe(true)
		end
		snapshot({ possessingTeam = "Blue" })
		for _, rim in arena.rim do
			expect(glows(rim, nil)).toBe(true)
		end
	end)

	-- #410: the goal's meshes come after the arena; the server moves the glow from the ring's blocks to the lip.
	it("lights the goal's lip once its meshes come, even while the goal is open, and puts it back after", function()
		snapshot({ possessingTeam = "Orange", goalOpenFor = "Orange" })
		local lip = Instance.new("Part")
		lip.Name = "Lip"
		lip.Anchored = true
		lip.Color = Color3.fromRGB(245, 242, 236)
		lip.Material = Enum.Material.SmoothPlastic
		lip:AddTag(Tags.GoalGlow)
		lip.Parent = folder
		arena.hoop:RemoveTag(Tags.GoalGlow)
		ArenaParts:refresh()
		ArenaGlow:step(DT)
		expect(lip.Color).toEqual(colors.Orange)
		expect(lip.Material).toBe(glow.material)
		snapshot({ possessingTeam = "Orange" })
		expect(lip.Color).toEqual(Color3.fromRGB(245, 242, 236))
		expect(lip.Material).toBe(Enum.Material.SmoothPlastic)
	end)

	-- The owner's choices (2026-10-27): only the next gate's panel shows, every other one is invisible, and every
	-- streak starts at the goal's gate.
	it("shows only the next gate's panel, lit for the team with the ball, the goal gate's from the pickup", function()
		local markers = arena.markers
		-- Nobody has the ball: no panel shows, though the goal's gate is next.
		snapshot()
		for _, marker in markers do
			expect(panelShows(marker, nil)).toBe(true)
		end
		snapshot({ possessingTeam = "Blue" })
		for gate, marker in markers do
			expect(panelShows(marker, if gate == GOAL_GATE then colors.Blue else nil)).toBe(true)
		end
		-- A kickoff (after a goal at the goal's gate) leaves nobody with the ball and the goal's gate still next.
		snapshot()
		expect(panelShows(markers[GOAL_GATE], nil)).toBe(true)
		snapshot({ possessingTeam = "Blue" })
		-- The panel the carrier passed disappears as the next one lights.
		snapshot({ possessingTeam = "Blue", nextGate = AFTER_GOAL_GATE })
		expect(panelShows(markers[GOAL_GATE], nil)).toBe(true)
		expect(panelShows(markers[AFTER_GOAL_GATE], colors.Blue)).toBe(true)
		snapshot({ possessingTeam = "Orange", nextGate = AFTER_GOAL_GATE })
		expect(panelShows(markers[AFTER_GOAL_GATE], colors.Orange)).toBe(true)
		snapshot()
		expect(panelShows(markers[AFTER_GOAL_GATE], nil)).toBe(true)
	end)

	-- The owner's Q255: once the streak has counted its last lap, no gate is next, so no gate's panel shows; the goal
	-- still glows.
	it("shows no gate's panel once the streak has counted its last lap", function()
		snapshot({ possessingTeam = "Blue", goalOpenFor = "Blue", nextGate = AFTER_GOAL_GATE })
		expect(panelShows(arena.markers[AFTER_GOAL_GATE], colors.Blue)).toBe(true)
		show(Fixtures.lapCapped("Blue"))
		for _, marker in arena.markers do
			expect(panelShows(marker, nil)).toBe(true)
		end
		for _, rim in arena.rim do
			expect(glows(rim, colors.Blue)).toBe(true)
		end
	end)

	it("hides every gate's panel from the start, and never the goal", function()
		-- beforeEach stepped once with no match.
		for _, marker in arena.markers do
			expect(panelShows(marker, nil)).toBe(true)
		end
		local function goalShows(): boolean
			for _, rim in arena.rim do
				if rim.Transparency ~= plain.transparency then
					return false
				end
			end
			return arena.panel.Transparency == plain.transparency
		end
		expect(goalShows()).toBe(true)
		snapshot({ possessingTeam = "Blue", goalOpenFor = "Blue", nextGate = 1 })
		expect(goalShows()).toBe(true)
		snapshot()
		expect(goalShows()).toBe(true)
	end)

	it("keeps each part's first look when the arena's parts are found again while they glow", function()
		snapshot({ possessingTeam = "Blue", goalOpenFor = "Blue", nextGate = AFTER_GOAL_GATE })
		-- A new record of the same parts, the ring still glowing and the goal gate's panel hidden.
		ArenaParts:refresh()
		ArenaGlow:step(DT)
		snapshot({ possessingTeam = "Blue" })
		for _, rim in arena.rim do
			expect(glows(rim, nil)).toBe(true)
		end
		-- The panel shows at the transparency it was first seen with, not the hidden one.
		expect(panelShows(arena.markers[GOAL_GATE], colors.Blue)).toBe(true)
	end)

	-- The panel stays the shut goal's wall on the server; on screen the door shuts the opening once the goal's
	-- meshes come, and until then the panel does.
	it("hides the goal's panel while the goal is open, and shows it after", function()
		expect(arena.panel.LocalTransparencyModifier).toBe(0)
		snapshot({ possessingTeam = "Blue", goalOpenFor = "Blue" })
		expect(arena.panel.LocalTransparencyModifier).toBe(1)
		expect(arena.panel.Transparency).toBe(plain.transparency)
		snapshot({ possessingTeam = "Blue" })
		expect(arena.panel.LocalTransparencyModifier).toBe(0)
	end)

	-- Q324: elevator doors parting from the middle over doorSeconds, eased as a tween's default (Quad, Out): half
	-- the time takes the edge three quarters of the way.
	it("opens the door from the middle while the goal is open, every bar's edge in one line, and shuts it", function()
		local bars, shut = addDoor()
		local reach = reachOf(shut)
		ArenaGlow:step(DT)
		expectDoorAt(bars, shut, 0)
		snapshot({ possessingTeam = "Blue", goalOpenFor = "Blue" })
		stepFor(glow.doorSeconds / 2 - DT)
		expectDoorAt(bars, shut, reach * 0.75)
		stepFor(glow.doorSeconds / 2)
		expectDoorAt(bars, shut, reach)
		stepFor(glow.doorSeconds)
		expectDoorAt(bars, shut, reach)
		snapshot({ possessingTeam = "Blue" })
		stepFor(glow.doorSeconds / 2 - DT)
		expectDoorAt(bars, shut, reach * 0.25)
		stepFor(glow.doorSeconds / 2)
		expectDoorAt(bars, shut, 0)
	end)

	it("turns the door back from wherever it is when the goal shuts while it opens", function()
		local bars, shut = addDoor()
		ArenaGlow:step(DT)
		snapshot({ possessingTeam = "Blue", goalOpenFor = "Blue" })
		stepFor(glow.doorSeconds / 2 - DT)
		snapshot({ possessingTeam = "Blue" })
		stepFor(glow.doorSeconds / 2 - DT)
		-- From three quarters open, three quarters of the way back.
		expectDoorAt(bars, shut, reachOf(shut) * 0.75 * 0.25)
	end)

	-- The goal's meshes, and the door with them, may reach a client while the goal is open.
	it("puts a door that comes while the goal is open open at once", function()
		snapshot({ possessingTeam = "Orange", goalOpenFor = "Orange" })
		stepFor(glow.doorSeconds)
		local bars, shut = addDoor()
		ArenaGlow:step(DT)
		expectDoorAt(bars, shut, reachOf(shut))
	end)

	it("opens and shuts the door at once when it takes no time, even on a frame that took none", function()
		local instant = Fixtures.config({ UI = { arenaGlow = { doorSeconds = 0 } } })
		ArenaGlow:init({ Config = instant, HudStore = HudStore, ArenaParts = ArenaParts })
		local bars, shut = addDoor()
		HudStore:onSnapshot(Fixtures.matchSnapshot({ possessingTeam = "Blue", goalOpenFor = "Blue" }))
		ArenaGlow:step(0)
		expectDoorAt(bars, shut, reachOf(shut))
		snapshot({ possessingTeam = "Blue" })
		expectDoorAt(bars, shut, 0)
	end)
end)
