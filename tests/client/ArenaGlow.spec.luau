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

local folder: Folder
local arena: Fixtures.HudArena
-- How each part looked before anything glowed.
local plain: { color: Color3, material: Enum.Material }
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

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ArenaGlowTest"
	folder.Parent = workspace
	arena = Fixtures.hudArena(folder)
	plain = { color = arena.panel.Color, material = arena.panel.Material }
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

	it("lights the next gate's corner marker for the team with the ball, and none before their first gate", function()
		local markers = arena.markers
		snapshot({ possessingTeam = "Blue" })
		for _, marker in markers do
			expect(glows(marker, nil)).toBe(true)
		end
		snapshot({ possessingTeam = "Blue", nextGate = 2 })
		expect(glows(markers[2], colors.Blue)).toBe(true)
		expect(glows(markers[1], nil) and glows(markers[3], nil) and glows(markers[4], nil)).toBe(true)
		snapshot({ possessingTeam = "Blue", nextGate = 3 })
		expect(glows(markers[2], nil)).toBe(true)
		expect(glows(markers[3], colors.Blue)).toBe(true)
		snapshot({ possessingTeam = "Orange", nextGate = 3 })
		expect(glows(markers[3], colors.Orange)).toBe(true)
		snapshot()
		expect(glows(markers[3], nil)).toBe(true)
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
