--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeAll, afterAll = JestGlobals.beforeAll, JestGlobals.afterAll

local Builder = require(game:GetService("ServerScriptService").Server.Arena.Builder)
local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Geometry = require(ReplicatedStorage.Shared.Arena.Geometry)
local MatchEngine = require(ReplicatedStorage.Shared.Rules.MatchEngine)
local TaggedLayout = require(ReplicatedStorage.Shared.Arena.TaggedLayout)

local config = Fixtures.config({ Match = { lapsToOpenGoal = 1, lapsForStreakPoint = 2 } })
local root: Folder
local arena: Model
local buildSeconds = 0

-- Built once into the workspace: raycasts only hit parts in the workspace.
beforeAll(function()
	root = Instance.new("Folder")
	root.Name = "ArenaIntegrationTest"
	root.Parent = workspace
	local started = os.clock()
	arena = Builder.build(Geometry.build(config), config, root)
	buildSeconds = os.clock() - started
end)
afterAll(function()
	root:Destroy()
end)

-- Rays from under the top (A7) find the floors below them, the walls and the glass across, and the top above.
local function cast(origin: Vector3, direction: Vector3): RaycastResult
	return workspace:Raycast(origin, direction) :: RaycastResult
end

describe("The generated arena", function()
	it("builds in under a second", function()
		expect(buildSeconds).toBeLessThan(1)
	end)

	-- The heights below are worked out independently of the code: on the top straight u = -z - 20; around the left
	-- curved end u is the distance from (-100, 0) less 20, and between two stations the built surface is the plane
	-- through the two strips' chords.
	it("puts the riding surface where the profile says, including the blend at a corner", function()
		local floors: { { any } } = {
			{ Vector3.new(30, 60, -47), 0 }, -- top straight, the spawn room (u 27)
			{ Vector3.new(30, 60, -74), 10.493 }, -- top straight, the incline (u 54): 8 + 10 tan 14°
			-- Top straight, the rise's third strip (u 35.6 to 38.4, 2.481 to 4.681 high), halfway across.
			{ Vector3.new(30, 60, -57), 3.581 },
			-- Gate 2, halfway between the two sections: u 45 on the chord from (43.798, 5.811) to (55.293, 9.187).
			{ Vector3.new(-100, 60, -65), 6.164 },
			-- Left curved end, the bowl: a stud past the apex, whose station is a seam a ray exactly on misses.
			{ Vector3.new(-160, 60, 1), 2.752 },
			{ Vector3.new(0, 60, 0), 0 }, -- the infield, at the lowest floor's height
			-- The infield under the left curved end, a stud off the station line at 135° (another seam).
			{ Vector3.new(-110, 60, 11), 0 },
		}
		for _, case in floors do
			local hit = cast(case[1], Vector3.new(0, -100, 0))
			expect(hit).never.toBeNil()
			expect(hit.Position.Y).toBeCloseTo(case[2], 2)
		end
		-- Inside a rise strip, not on a seam: a ray exactly on a seam may report the neighboring slab's side face.
		expect(cast(Vector3.new(30, 60, -61.4), Vector3.new(0, -100, 0)).Normal.Z).toBeGreaterThan(0)
	end)

	-- Between stations and between profile points, where only correctly oriented wedges cover the surface.
	it("covers the curved ends and the blend at a corner without holes", function()
		local function floorAt(distance: number, lateral: number): number?
			local hit: RaycastResult? =
				cast(Centerline.at(config.Arena, distance, lateral, 60).Position, Vector3.new(0, -100, 0))
			return if hit then hit.Position.Y else nil
		end
		-- The left curved end's bowl, mid-way between two stations (48 of them, 3.927 studs apart, from 200), across
		-- its strips: each on the plane through its two chords.
		local bowl = { { 20, 0.158 }, { 28, 0.69 }, { 36, 1.911 }, { 44, 3.765 }, { 52, 6.373 }, { 60, 9.377 } }
		for _, case in bowl do
			expect(floorAt(241.2, case[1])).toBeCloseTo(case[2], 2)
		end
		-- u 45 just before and just after Gate 2 (distance 200), where the section is blending: on the triangles
		-- between the neighboring stations' strips (the incline's first, from 44 to 53.7 on a straight and 43.6 to 56.9
		-- at a curved end, blended 0.794, 0.5 and 0.211 at 196, 200 and 203.9).
		expect(floorAt(198, 45)).toBeCloseTo(6.79, 2)
		expect(floorAt(202, 45)).toBeCloseTo(5.584, 2)
	end)

	it("stands the walls, the glass and the roof where the profile says", function()
		local glass, top = arena:FindFirstChild("Glass"), arena:FindFirstChild("Top")
		-- The upright wall, above the straights' foot curve (34.16) and under its top (40).
		local outer = cast(Vector3.new(30, 37, -60), Vector3.new(0, 0, -100))
		expect(outer.Position.Z).toBeCloseTo(-100, 2)
		expect(outer.Instance.Parent == arena:FindFirstChild("Surface")).toBe(true)
		local outerGlass = cast(Vector3.new(30, 60, -60), Vector3.new(0, 0, -100))
		expect(outerGlass.Position.Z).toBeCloseTo(-100, 2)
		expect(outerGlass.Instance.Parent == glass).toBe(true)
		local innerGlass = cast(Vector3.new(30, 60, -60), Vector3.new(0, 0, 100))
		expect(innerGlass.Position.Z).toBeCloseTo(-20, 2)
		expect(innerGlass.Instance.Parent == glass).toBe(true)
		-- The outer lip at 115: on its chord from (79.087, 112.592) to (76.485, 116.485), u 77.48.
		local lip = cast(Vector3.new(30, 115, -60), Vector3.new(0, 0, -100))
		expect(lip.Position.Z).toBeCloseTo(-97.48, 2)
		expect(lip.Instance.Parent == glass).toBe(true)
		local roof = cast(Vector3.new(30, 60, -60), Vector3.new(0, 100, 0))
		expect(roof.Position.Y).toBeCloseTo(120, 2)
		expect(roof.Instance.Parent == top).toBe(true)

		-- Finds the glass from inside the track on a curved end, facing in. The ray runs out from the left end's
		-- center along the track's middle, toward the middle of the chord just past the apex: half a station step on,
		-- so not on a seam between two slabs.
		local center = Vector3.new(-config.Arena.straightLength / 2, 60, 0)
		local steps = #Centerline.sectionStations(config.Arena, 2) - 1
		local halfStep = math.pi / steps / 2
		local out = Vector3.new(-math.cos(halfStep), 0, math.sin(halfStep))
		local chord = cast(center + out * config.Arena.endRadius, out * config.Arena.trackWidth)
		local outerRadius = config.Arena.endRadius + config.Arena.trackWidth / 2
		expect((chord.Position - center).Magnitude).toBeCloseTo(outerRadius * math.cos(halfStep), 2)
		expect(chord.Instance.Parent == glass).toBe(true)
		expect(chord.Normal:Dot(-out)).toBeGreaterThan(0.99)
	end)

	it("lets the rules count a lap around the generated track and score through its goal", function()
		local tagged = TaggedLayout.read(arena)
		local engine = MatchEngine.new({ config = config, arena = tagged.layout, gravity = Fixtures.GRAVITY })
		engine:addPlayer("B1", "Blue")
		engine:start()
		engine:tick(3)
		engine:pickedUp("B1", Vector3.zero, Vector3.zero)
		local length = Centerline.length(config.Arena)
		local middle = config.Arena.trackWidth / 2
		local previous = Centerline.at(config.Arena, 1, middle, 5).Position
		-- On past gate 1 at `length`, whatever the length: the lap's fourth crossing.
		for distance = 3, length + 3, 2 do
			local current = Centerline.at(config.Arena, distance, middle, 5).Position
			engine:ballMoved(previous, current)
			previous = current
		end
		local names: { string } = {}
		for _, event in engine:drainEvents() do
			table.insert(names, event.name)
		end
		expect(table.find(names, "LapCompleted")).never.toBeNil()
		expect(table.find(names, "GoalOpened")).never.toBeNil()
		local goal = tagged.layout.goal.frame
		engine:ballMoved(goal.Position - goal.LookVector * 2, goal.Position + goal.LookVector * 2)
		expect(engine:drainEvents()[1]).toMatchObject({ name = "GoalScored", team = "Blue", scorer = "B1" })
	end)
end)
