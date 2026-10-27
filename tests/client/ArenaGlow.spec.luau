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
local HudStore = require(Client.HudStore)

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
-- Every slide asked for: the part's name, where to, over how long.
local slides: { { part: string, to: CFrame, seconds: number } }

local function snapshot(overrides: { [string]: any }?)
	HudStore:onSnapshot(Fixtures.matchSnapshot(overrides))
	ArenaGlow:step(DT)
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
	slides = {}
	ArenaParts:init({})
	HudStore:init({ Config = config })
	ArenaGlow:init({
		Config = config,
		HudStore = HudStore,
		ArenaParts = ArenaParts,
		Slide = function(part: BasePart, to: CFrame, seconds: number)
			table.insert(slides, { part = part.Name, to = to, seconds = seconds })
		end,
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

	it("slides the panel out of the ring while the goal is open, and back", function()
		local closed = arena.panel.CFrame
		local up = arena.hoop:GetPivot().UpVector
		expect(#slides).toBe(0)
		snapshot({ possessingTeam = "Blue", goalOpenFor = "Blue" })
		ArenaGlow:step(DT)
		expect(#slides).toBe(1)
		expect(slides[1].part).toBe("GoalPanel")
		Fixtures.expectNear(slides[1].to.Position, closed.Position + up * glow.panelSlide)
		expect(slides[1].seconds).toBe(glow.panelSlideSeconds)
		snapshot({ possessingTeam = "Blue" })
		expect(#slides).toBe(2)
		Fixtures.expectNear(slides[2].to.Position, closed.Position)
		expect(slides[2].to.LookVector:Dot(closed.LookVector)).toBeCloseTo(1, 5)
	end)
end)
