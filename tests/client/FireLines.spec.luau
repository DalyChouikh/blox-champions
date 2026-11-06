--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local FireLines = require(Client.FireLines)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudStore = require(Client.HudStore)
local WallLine = require(ReplicatedStorage.Shared.Arena.Geometry.WallLine)

local config = Config.defaults()
local arena = config.Arena
local lines = config.UI.arenaGlow.fireLines
local DT = 1 / 60
-- Every streak starts at the goal's gate (LapTracker): its first line runs from there to the next gate.
local GOAL_GATE = arena.goalGateIndex
local LAPS = #config.Match.goalPointsByLap
local GATES = Centerline.gateCount
-- Each line rests on the wall: lifted half its thickness and a 0.05 gap off the surface.
local LIFT = lines.thickness / 2 + 0.05

local folder: Folder

-- Lap n's line sits at the outer wall's glass line, each lap's spacing above the last (the owner's Q329).
local function heightOf(lap: number): number
	return arena.glassLook.outerWall + (lap - 1) * lines.spacing
end

local function snapshot(overrides: { [string]: any }?)
	HudStore:onSnapshot(Fixtures.matchSnapshot(overrides))
	FireLines:step(DT)
end

-- Steps for `seconds` (whole frames).
local function stepFor(seconds: number)
	for _ = 1, math.round(seconds / DT) do
		FireLines:step(DT)
	end
end

local function line(lap: number, gate: number): Model
	return FireLines.model:FindFirstChild(`Lap{lap}Gate{gate}`) :: Model
end

-- A line's pieces in travel order.
local function piecesOf(lap: number, gate: number): { Part }
	local model, parts = line(lap, gate), {}
	while true do
		local part = model:FindFirstChild(`Piece{#parts + 1}`)
		if part == nil then
			return parts
		end
		table.insert(parts, part :: Part)
	end
end

local function fireballOf(lap: number, gate: number): Part
	return line(lap, gate):FindFirstChild("Fireball") :: Part
end

local function shapeOf(lap: number, gate: number): { WallLine.Piece }
	return WallLine.section(arena, gate, heightOf(lap), LIFT)
end

-- Whether the line shows whole, every piece its full length in its place, in `team`'s colour, its fireball gone.
local function whole(lap: number, gate: number, team: string): boolean
	local shape = shapeOf(lap, gate)
	for index, part in piecesOf(lap, gate) do
		local piece = shape[index]
		if
			part.Transparency ~= 0
			or part.Color ~= config.UI.teamColors[team :: any]
			or math.abs(part.Size.X - (piece.finish - piece.start).Magnitude) > 1e-3
			or (part.Position - (piece.start + piece.finish) / 2).Magnitude > 1e-3
		then
			return false
		end
	end
	return fireballOf(lap, gate).Transparency == 1
end

local function hidden(lap: number, gate: number): boolean
	for _, part in piecesOf(lap, gate) do
		if part.Transparency ~= 1 then
			return false
		end
	end
	return fireballOf(lap, gate).Transparency == 1
end

-- Orange's streak having passed `count` gates of its first lap.
local function passGates(count: number)
	snapshot({ possessingTeam = "Orange", lapProgress = count, nextGate = (GOAL_GATE + count - 1) % GATES + 1 })
end

local function restart(with: Config.GameConfig)
	HudStore:init({ Config = with, LocalId = "1" })
	FireLines:init({ Config = with, HudStore = HudStore, Parent = folder })
	FireLines:start()
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "FireLinesTest"
	folder.Parent = workspace
	restart(config)
	snapshot()
end)

afterEach(function()
	folder:Destroy()
end)

describe("FireLines", function()
	it("builds every lap's line from gate to gate, hidden, as parts that only draw", function()
		expect(FireLines.model.Parent == folder).toBe(true)
		expect(#FireLines.model:GetChildren()).toBe(LAPS * GATES)
		for lap = 1, LAPS do
			for gate = 1, GATES do
				expect(hidden(lap, gate)).toBe(true)
				local fireball = fireballOf(lap, gate)
				expect(fireball.Shape).toBe(Enum.PartType.Ball)
				Fixtures.expectNear(fireball.Size, Vector3.one * lines.fireball)
				local parts = piecesOf(lap, gate)
				table.insert(parts, fireball)
				for _, part in parts do
					expect(part.Anchored).toBe(true)
					expect(part.CanCollide or part.CanQuery or part.CanTouch or part.CastShadow).toBe(false)
					expect(part.Material).toBe(config.UI.arenaGlow.material)
				end
			end
		end
	end)

	-- The owner's Q329: lap n's line at the outer wall's glass line, each next lap's spacing higher, resting on the
	-- wall as built (WallLine), one cylinder a piece.
	it("rests each lap's line on the outer wall, spacing above the last lap's", function()
		for lap = 1, LAPS do
			for gate = 1, GATES do
				local shape, parts = shapeOf(lap, gate), piecesOf(lap, gate)
				expect(#parts).toBe(#shape)
				for index, part in parts do
					local piece = shape[index]
					local along = piece.finish - piece.start
					expect(part.Shape).toBe(Enum.PartType.Cylinder)
					Fixtures.expectNear(part.Position, (piece.start + piece.finish) / 2, 1e-3)
					Fixtures.expectNear(part.CFrame.RightVector, along.Unit, 1e-3)
					Fixtures.expectNear(part.Size, Vector3.new(along.Magnitude, lines.thickness, lines.thickness), 1e-3)
				end
			end
		end
	end)

	-- Q300, Q301: at each gate passed a fireball flies forward to the next gate and its line stays.
	it("flies a fireball from the gate passed to the next, its line growing behind it and staying", function()
		passGates(1)
		expect(hidden(1, GOAL_GATE)).toBe(true)
		stepFor(lines.delaySeconds - 2 * DT)
		expect(hidden(1, GOAL_GATE)).toBe(true)
		-- Part way there (0.3 of the curved end's 48 equal chords: inside the 15th): the pieces behind it whole, the
		-- one it is on up to it, those ahead hidden.
		stepFor(0.3 * lines.flightSeconds + DT)
		local shape, parts = shapeOf(1, GOAL_GATE), piecesOf(1, GOAL_GATE)
		local reach = shape[1].from + 0.3 * (shape[#shape].to - shape[1].from)
		local fireball = fireballOf(1, GOAL_GATE)
		expect(fireball.Transparency).toBe(0)
		expect(fireball.Color).toEqual(config.UI.teamColors.Orange)
		for index, part in parts do
			local piece = shape[index]
			if piece.to <= reach then
				expect(part.Transparency).toBe(0)
				expect(part.Size.X).toBeCloseTo((piece.finish - piece.start).Magnitude, 3)
			elseif piece.from >= reach then
				expect(part.Transparency).toBe(1)
			else
				local fraction = (reach - piece.from) / (piece.to - piece.from)
				local tip = piece.start:Lerp(piece.finish, fraction)
				expect(part.Transparency).toBe(0)
				expect(part.Size.X).toBeCloseTo((tip - piece.start).Magnitude, 3)
				Fixtures.expectNear(part.Position, (piece.start + tip) / 2, 1e-3)
				Fixtures.expectNear(fireball.Position, tip, 1e-3)
			end
		end
		stepFor(0.7 * lines.flightSeconds + DT)
		expect(whole(1, GOAL_GATE, "Orange")).toBe(true)
		-- It stays.
		stepFor(1)
		expect(whole(1, GOAL_GATE, "Orange")).toBe(true)
	end)

	-- Q302: one line per lap, stacked; the streak's laps start at the goal's gate.
	it("lights each gate passed lap after lap, from the goal's gate round, up to the streak's last lap", function()
		snapshot({ possessingTeam = "Orange", streak = 1, lapProgress = 2, nextGate = 4 })
		stepFor(lines.delaySeconds + lines.flightSeconds)
		for gate = 1, GATES do
			expect(whole(1, gate, "Orange")).toBe(true)
		end
		expect(whole(2, 2, "Orange")).toBe(true)
		expect(whole(2, 3, "Orange")).toBe(true)
		expect(hidden(2, 4)).toBe(true)
		expect(hidden(2, 1)).toBe(true)
		for gate = 1, GATES do
			expect(hidden(3, gate)).toBe(true)
		end
		-- The streak's last lap counted (Q255: its lap stays full, no gate next): every line lit.
		HudStore:onSnapshot(Fixtures.lapCapped("Orange"))
		FireLines:step(DT)
		stepFor(lines.delaySeconds + lines.flightSeconds)
		for lap = 1, LAPS do
			for gate = 1, GATES do
				expect(whole(lap, gate, "Orange")).toBe(true)
			end
		end
	end)

	it("shows nothing while no team has the ball", function()
		snapshot({ lapProgress = 2, nextGate = 4 })
		stepFor(lines.delaySeconds + lines.flightSeconds)
		for gate = 1, GATES do
			expect(hidden(1, gate)).toBe(true)
		end
	end)

	-- A player who joins mid-streak sees its lines as they stand, even when a batch of rule events reached it first.
	it("shows the lines a streak already has when it first sees the match, without fireballs", function()
		restart(config)
		HudStore:onEvents(Fixtures.ruleEvents({ { name = "LapCompleted", team = "Blue", streak = 1, holder = "1" } }))
		FireLines:step(DT)
		snapshot({ possessingTeam = "Blue", streak = 1, lapProgress = 1, nextGate = 3 })
		for gate = 1, GATES do
			expect(whole(1, gate, "Blue")).toBe(true)
		end
		expect(whole(2, GOAL_GATE, "Blue")).toBe(true)
		expect(hidden(2, 3)).toBe(true)
	end)

	-- Q303: at a goal or when the other team takes the ball the lines fade out quickly, as the lap chips empty.
	local ends: { { name: string, overrides: { [string]: any } } } = {
		{ name = "a goal", overrides = { possessingTeam = "Orange" } },
		{ name = "a steal", overrides = { possessingTeam = "Blue" } },
		{ name = "a kickoff", overrides = { state = "Kickoff", phaseSecondsLeft = 3 } },
	}
	for _, case in ends do
		it(`fades the lines out over a moment when the streak ends at {case.name}`, function()
			passGates(2)
			stepFor(lines.delaySeconds + lines.flightSeconds)
			snapshot(case.overrides)
			stepFor(lines.fadeSeconds / 2 - DT)
			for _, gate in { 2, 3 } do
				for _, part in piecesOf(1, gate) do
					expect(part.Transparency).toBeCloseTo(0.5, 3)
					expect(part.Color).toEqual(config.UI.teamColors.Orange)
				end
			end
			stepFor(lines.fadeSeconds / 2 + DT)
			expect(hidden(1, 2)).toBe(true)
			expect(hidden(1, 3)).toBe(true)
		end)
	end

	it("hides a fireball still flying when the streak ends, at once", function()
		passGates(1)
		stepFor(lines.delaySeconds + lines.flightSeconds / 2)
		expect(fireballOf(1, GOAL_GATE).Transparency).toBe(0)
		snapshot({ possessingTeam = "Blue" })
		expect(fireballOf(1, GOAL_GATE).Transparency).toBe(1)
		stepFor(lines.fadeSeconds + DT)
		expect(hidden(1, GOAL_GATE)).toBe(true)
	end)

	-- The other team's lines then start from their first gate (Q303), in their colour.
	it("ends a fade at once when the next streak passes a gate, and lights its line in that team's colour", function()
		passGates(2)
		stepFor(lines.delaySeconds + lines.flightSeconds)
		snapshot({ possessingTeam = "Blue" })
		stepFor(lines.fadeSeconds / 2)
		snapshot({ possessingTeam = "Blue", lapProgress = 1, nextGate = 3 })
		expect(hidden(1, 2)).toBe(true)
		expect(hidden(1, 3)).toBe(true)
		stepFor(lines.delaySeconds + lines.flightSeconds)
		expect(whole(1, 2, "Blue")).toBe(true)
		expect(hidden(1, 3)).toBe(true)
	end)

	-- Taken back within the fade: the lines that were fading still go.
	it("lets a fade finish when the ball changes hands again while it runs", function()
		passGates(2)
		stepFor(lines.delaySeconds + lines.flightSeconds)
		snapshot({ possessingTeam = "Blue" })
		stepFor(lines.fadeSeconds / 2)
		snapshot({ possessingTeam = "Orange" })
		stepFor(lines.fadeSeconds / 2 + DT)
		expect(hidden(1, 2)).toBe(true)
		expect(hidden(1, 3)).toBe(true)
	end)

	-- A match update may already show the new team's gates (two changes on one server frame): its lines take over.
	it("lights a new team's streak in its colour even when the update already shows it past more gates", function()
		passGates(1)
		stepFor(lines.delaySeconds + lines.flightSeconds)
		snapshot({ possessingTeam = "Blue", lapProgress = 2, nextGate = 4 })
		stepFor(lines.delaySeconds + lines.flightSeconds)
		expect(whole(1, 2, "Blue")).toBe(true)
		expect(whole(1, 3, "Blue")).toBe(true)
	end)

	it("shows a line whole once its fireball's wait is over when the flight takes no time", function()
		restart(Fixtures.config({ UI = { arenaGlow = { fireLines = { flightSeconds = 0 } } } }))
		snapshot()
		passGates(1)
		stepFor(lines.delaySeconds - 2 * DT)
		expect(hidden(1, GOAL_GATE)).toBe(true)
		stepFor(2 * DT)
		expect(whole(1, GOAL_GATE, "Orange")).toBe(true)
	end)
end)
