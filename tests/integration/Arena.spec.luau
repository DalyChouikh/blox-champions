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
	arena = Builder.build(Geometry.build(config, Fixtures.GRAVITY.Magnitude), config, root)
	buildSeconds = os.clock() - started
end)
afterAll(function()
	root:Destroy()
end)

-- The top is open (A7): a ray from above finds the floors, and one across finds the walls and the glass.
local function cast(origin: Vector3, direction: Vector3): RaycastResult
	return workspace:Raycast(origin, direction) :: RaycastResult
end

describe("The generated arena", function()
	it("builds in under a second", function()
		expect(buildSeconds).toBeLessThan(1)
	end)

	it("puts the riding surface where the profile says, including the blend at a corner", function()
		local floors: { { any } } = {
			{ Vector3.new(30, 60, -57), 0 }, -- top straight, lower floor
			{ Vector3.new(30, 60, -83), 4 }, -- top straight, upper floor
			{ Vector3.new(30, 60, -73), 2 }, -- top straight, middle of the step
			{ Vector3.new(-100, 60, -73), 1 }, -- Gate 2: the step is half blended away
			{ Vector3.new(-160, 60, 0), 0 }, -- left curved end, flat floor
			{ Vector3.new(0, 60, 0), 0 }, -- the infield, at the lower floor's height
			{ Vector3.new(-130, 60, 15), 0 }, -- the infield under the left curved end
		}
		for _, case in floors do
			local hit = cast(case[1], Vector3.new(0, -100, 0))
			expect(hit).never.toBeNil()
			expect(hit.Position.Y).toBeCloseTo(case[2], 2)
		end
		-- Inside a step strip, not on a seam: a ray exactly on a seam may report the neighboring slab's side face.
		expect(cast(Vector3.new(30, 60, -70), Vector3.new(0, -100, 0)).Normal.Z).toBeGreaterThan(0)
	end)

	-- Between stations and between profile points, where only correctly oriented wedges cover the surface.
	it("covers the curved ends and the step's blend without holes", function()
		local function floorAt(distance: number, lateral: number): number?
			local hit: RaycastResult? =
				cast(Centerline.at(config.Arena, distance, lateral, 60).Position, Vector3.new(0, -100, 0))
			return if hit then hit.Position.Y else nil
		end
		-- The left curved end's flat floor, mid-way between two stations (55 of them, 3.998 studs apart, from 200),
		-- across every floor strip: the lower floor, the step's five and the upper floor.
		for _, lateral in { 17, 27.4, 30.2, 33, 35.8, 38.6, 43 } do
			expect(floorAt(242, lateral)).toBeCloseTo(0, 2)
		end
		-- The middle of the step's third strip (31.6 to 34.4) just before and just after Gate 2 (distance 200): between
		-- the heights of the strip's corners on the neighboring stations (the step there is 3.18 and 2 high, then 2
		-- and 0.82).
		local before = floorAt(198, 33) :: number
		expect(before > 0.69 and before < 2.08).toBe(true)
		local after = floorAt(202, 33) :: number
		expect(after > 0.28 and after < 1.31).toBe(true)
	end)

	it("stands the walls and the glass where the profile says", function()
		local outer = cast(Vector3.new(30, 24, -70), Vector3.new(0, 0, -100))
		expect(outer.Position.Z).toBeCloseTo(-100, 2)
		expect(outer.Instance.Parent == arena:FindFirstChild("Surface")).toBe(true)
		local outerGlass = cast(Vector3.new(30, 50, -70), Vector3.new(0, 0, -100))
		expect(outerGlass.Position.Z).toBeCloseTo(-100, 2)
		expect(outerGlass.Instance.Parent == arena:FindFirstChild("Barriers")).toBe(true)
		local innerGlass = cast(Vector3.new(30, 40, -70), Vector3.new(0, 0, 100))
		expect(innerGlass.Position.Z).toBeCloseTo(-40, 2)
		expect(innerGlass.Instance.Parent == arena:FindFirstChild("Barriers")).toBe(true)
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
