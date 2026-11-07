--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ArenaParts = require(Client.ArenaParts)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local GoalWorth = require(Client.GoalWorth)
local HudStore = require(Client.HudStore)
local Motion = require(ReplicatedStorage.Shared.Hud.Motion)

local config = Config.defaults()
local worth = config.UI.goalWorth
local motion = config.UI.hud.motion
local doorSeconds = config.UI.arenaGlow.doorSeconds
local DT = 1 / 60

local folder: Folder
local arena: Fixtures.HudArena

local function snapshot(overrides: { [string]: any }?)
	HudStore:onSnapshot(Fixtures.matchSnapshot(overrides))
	GoalWorth:step(DT)
end

-- Steps for `seconds` (whole frames).
local function stepFor(seconds: number)
	for _ = 1, math.round(seconds / DT) do
		GoalWorth:step(DT)
	end
end

local function disc(): BasePart
	return GoalWorth.model:FindFirstChild("Disc") :: BasePart
end

local function faces(): { SurfaceGui }
	local face = GoalWorth.model:FindFirstChild("Face") :: BasePart
	return { face:FindFirstChild("Front") :: SurfaceGui, face:FindFirstChild("Back") :: SurfaceGui }
end

local function label(gui: SurfaceGui): TextLabel
	return gui:FindFirstChild("Worth") :: TextLabel
end

local function scaleOf(gui: SurfaceGui): number
	return (label(gui):FindFirstChildWhichIsA("UIScale") :: UIScale).Scale
end

-- Whether the disc and both faces show `text`, in `team`'s colour; or nothing shows (`text` nil).
local function shows(text: string?, team: string?): boolean
	local guis = faces()
	if text == nil then
		return disc().Transparency == 1 and not guis[1].Enabled and not guis[2].Enabled
	end
	-- Glowing as the next gate's marker does (Q327): the glow's material at the glass's transparency.
	return math.abs(disc().Transparency - config.Arena.glass.transparency) < 1e-4
		and disc().Material == config.UI.arenaGlow.material
		and disc().Color == config.UI.teamColors[team :: any]
		and guis[1].Enabled
		and guis[2].Enabled
		and label(guis[1]).Text == text
		and label(guis[2]).Text == text
end

-- The goal open for Orange with the streak that opened it, its door given time to open.
local function openFor(streak: number)
	snapshot({ possessingTeam = "Orange", goalOpenFor = "Orange", streak = streak })
	stepFor(doorSeconds)
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "GoalWorthTest"
	folder.Parent = workspace
	arena = Fixtures.hudArena(folder)
	ArenaParts:init({})
	HudStore:init({ Config = config, LocalId = "1" })
	GoalWorth:init({ Config = config, HudStore = HudStore, ArenaParts = ArenaParts, Parent = folder })
	GoalWorth:start()
	snapshot()
end)

-- The folder first: it holds the module's parts, so a start that failed leaves nothing behind.
afterEach(function()
	folder:Destroy()
	ArenaParts:destroy()
end)

describe("GoalWorth", function()
	it("builds a disc and two faces that only draw, and shows nothing while the goal is shut", function()
		expect(shows(nil)).toBe(true)
		for _, part in { disc(), GoalWorth.model:FindFirstChild("Face") :: BasePart } do
			expect(part.Anchored).toBe(true)
			expect(part.CanCollide or part.CanQuery or part.CanTouch or part.CastShadow).toBe(false)
		end
		expect(GoalWorth.model.Parent == folder).toBe(true)
	end)

	-- #411, the owner's Q294: the open goal's middle in the team's colour with its worth, once its door has opened.
	it("fills the open goal's opening with a disc in the team's colour once its door has opened", function()
		snapshot({ possessingTeam = "Orange", goalOpenFor = "Orange", streak = 1 })
		expect(shows(nil)).toBe(true)
		stepFor(doorSeconds - 2 * DT)
		expect(shows(nil)).toBe(true)
		stepFor(2 * DT)
		expect(shows("+1", "Orange")).toBe(true)
		-- Behind the door's plane, filling the opening as drawn, facing the way the goal faces.
		local frame = arena.hoop:GetPivot()
		local diameter = 2 * config.Arena.goal.ringRadius * worth.fill
		Fixtures.expectNear(disc().Position, (frame * CFrame.new(0, 0, -worth.behind)).Position)
		Fixtures.expectNear(disc().Size, Vector3.new(worth.thickness, diameter, diameter))
		Fixtures.expectNear(disc().CFrame.RightVector, frame.LookVector)
		local face = GoalWorth.model:FindFirstChild("Face") :: BasePart
		Fixtures.expectNear(face.Position, disc().Position)
		Fixtures.expectNear(face.CFrame.LookVector, frame.LookVector)
	end)

	-- Q306: the number reads the right way from in front and from behind.
	it("writes the worth on both of its faces, each read from its own side", function()
		openFor(1)
		local guis = faces()
		expect(guis[1].Face).toBe(Enum.NormalId.Front)
		expect(guis[2].Face).toBe(Enum.NormalId.Back)
		for _, gui in guis do
			local text = label(gui)
			expect(text.Font).toBe(config.UI.hud.look.bannerFont)
			expect(text.TextColor3).toEqual(config.UI.hud.textColor)
			expect(text.TextScaled).toBe(true)
			expect(text.Size).toEqual(UDim2.fromScale(1, worth.textHeight))
			local stroke = text:FindFirstChildWhichIsA("UIStroke") :: UIStroke
			expect(stroke.Color).toEqual(config.UI.hud.look.ink)
			expect(stroke.Thickness).toBe(config.UI.hud.look.textOutline)
			-- TextScaled draws at most 100 px: the number gets exactly that, its sharpest (measured in Studio).
			local tall = 2 * config.Arena.goal.ringRadius * worth.fill * worth.textHeight
			expect(gui.PixelsPerStud * tall).toBeCloseTo(100, 3)
		end
	end)

	it("shows the worth the rules give: +1, +3 and +5 over a streak's laps, and +5 after", function()
		openFor(1)
		expect(shows("+1", "Orange")).toBe(true)
		snapshot({ possessingTeam = "Orange", goalOpenFor = "Orange", streak = 2 })
		expect(shows("+3", "Orange")).toBe(true)
		snapshot({ possessingTeam = "Orange", goalOpenFor = "Orange", streak = 3 })
		expect(shows("+5", "Orange")).toBe(true)
		HudStore:onSnapshot(Fixtures.lapCapped("Blue"))
		stepFor(doorSeconds)
		expect(shows("+5", "Blue")).toBe(true)
	end)

	-- The banners' pop (Q294: "popping when it changes"), on its first showing too.
	it("pops the number in as it shows and on each change, with the banners' timing", function()
		openFor(1)
		-- Shown a frame or two ago: still popping in.
		for _, gui in faces() do
			expect(scaleOf(gui) < 1).toBe(true)
		end
		stepFor(motion.pop.seconds)
		for _, gui in faces() do
			expect(scaleOf(gui)).toBe(1)
		end
		snapshot({ possessingTeam = "Orange", goalOpenFor = "Orange", streak = 2 })
		for _, gui in faces() do
			expect(scaleOf(gui)).toBeCloseTo(Motion.pop(motion, DT), 5)
		end
		stepFor(motion.pop.seconds / 2 - DT)
		for _, gui in faces() do
			expect(scaleOf(gui)).toBeCloseTo(Motion.pop(motion, motion.pop.seconds / 2), 5)
		end
		stepFor(motion.pop.seconds)
		for _, gui in faces() do
			expect(scaleOf(gui)).toBe(1)
		end
	end)

	it("hides at once when the goal shuts: a goal, or the other team taking the ball", function()
		openFor(2)
		stepFor(motion.pop.seconds)
		snapshot({ possessingTeam = "Blue" })
		expect(shows(nil)).toBe(true)
		-- The same worth again pops in again.
		openFor(2)
		expect(shows("+3", "Orange")).toBe(true)
		expect(scaleOf(faces()[1]) < 1).toBe(true)
		snapshot({ possessingTeam = "Blue" })
		-- Opening again waits for the door again.
		snapshot({ possessingTeam = "Orange", goalOpenFor = "Orange", streak = 1 })
		expect(shows(nil)).toBe(true)
		stepFor(doorSeconds)
		expect(shows("+1", "Orange")).toBe(true)
		snapshot()
		expect(shows(nil)).toBe(true)
	end)

	it("follows the goal when the arena's parts change, even while it shows", function()
		openFor(1)
		arena.hoop:PivotTo(CFrame.new(50, 30, 10) * CFrame.Angles(0, math.pi / 2, 0))
		ArenaParts:refresh()
		GoalWorth:step(DT)
		local frame = arena.hoop:GetPivot()
		Fixtures.expectNear(disc().Position, (frame * CFrame.new(0, 0, -worth.behind)).Position)
		Fixtures.expectNear(disc().CFrame.RightVector, frame.LookVector)
	end)
end)
