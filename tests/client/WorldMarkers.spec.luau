--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local BallSkins = require(ReplicatedStorage.Shared.Skins.BallSkins)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudStore = require(Client.HudStore)
local Look = require(ReplicatedStorage.Shared.Ball.Look)
local RideSurfaces = require(Client.RideSurfaces)
local WorldMarkers = require(Client.WorldMarkers)

local config = Config.defaults()
local markers = config.UI.markers
local colors = config.UI.teamColors
local LOCAL_ID = "1"
local DT = 1 / 60

local folder: Folder
local ball: Part?
-- What the fake ray below the ball hits; nil for nothing.
local hit: { Position: Vector3, Normal: Vector3 }?

local function snapshot(overrides: { [string]: any }?)
	HudStore:onSnapshot(Fixtures.matchSnapshot(overrides))
end

local function stroke(): UIStroke
	return WorldMarkers.ring:FindFirstChild("Stroke", true) :: UIStroke
end

-- The ball's look (#400) under `part`, as the server dresses each ball: what each screen shows of the ball.
local function newLook(part: Part): MeshPart
	local look = Instance.new("MeshPart")
	look.Name = Look.NAME
	look.Anchored = true
	look.Parent = part
	return look
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "WorldMarkersTest"
	folder.Parent = workspace
	local part = Instance.new("Part")
	part.Name = "Ball"
	part.Anchored = true
	part.Position = Vector3.new(0, 10, 0)
	part.Parent = folder
	newLook(part)
	ball = part
	hit = { Position = Vector3.new(0, 0, 0), Normal = Vector3.yAxis }
	RideSurfaces:init({})
	HudStore:init({ Config = config, LocalId = LOCAL_ID })
	snapshot()
	WorldMarkers:init({
		Config = config,
		RideSurfaces = RideSurfaces,
		BallPart = {
			get = function(_self: any): BasePart?
				return ball
			end,
			look = function(_self: any): BasePart?
				return if ball ~= nil then Look.of(ball) else nil
			end,
		},
		HudStore = HudStore,
		Parent = folder,
		World = folder,
		Raycast = function(_origin: Vector3, _direction: Vector3, _params: RaycastParams): RaycastResult?
			return hit :: any
		end,
	})
end)

afterEach(function()
	folder:Destroy()
end)

describe("WorldMarkers", function()
	it("rings the ball in the colour of the team with it, white while neutral", function()
		WorldMarkers:step(DT)
		local ring = WorldMarkers.ring
		expect(ring.AlwaysOnTop).toBe(true)
		expect(ring.Enabled).toBe(true)
		expect(ring.Adornee == ball).toBe(true)
		expect(stroke().Color == config.UI.hud.textColor).toBe(true)
		snapshot({ possessingTeam = "Blue" })
		WorldMarkers:step(DT)
		expect(stroke().Color == colors.Blue).toBe(true)
	end)

	-- The owner (#327, Q158, Q159): RC's ball wears the colour of the team that last held it, carried, flying and
	-- loose (Video 31 at 27.8, 39.1-39.5 and 47.4-48.8 s), and its own neutral colour from GO until a team holds it.
	-- The match keeps the possessing team through throws, passes, drops and respawns until a kickoff.
	it("wears the colour of the team that last held the ball, its skin's own until a team has", function()
		-- On the ball's look (#400): the ball part itself is unseen.
		local function worn(): string
			return (Look.of(ball :: Part) :: BasePart).Color:ToHex()
		end
		local neutral = BallSkins.get(BallSkins.DEFAULT).color:ToHex()
		WorldMarkers:step(DT)
		expect(worn()).toBe(neutral)
		snapshot({ possessingTeam = "Orange" })
		WorldMarkers:step(DT)
		expect(worn()).toBe(colors.Orange:ToHex())
		-- Stolen.
		snapshot({ possessingTeam = "Blue" })
		WorldMarkers:step(DT)
		expect(worn()).toBe(colors.Blue:ToHex())
		-- A new ball (the server rebuilds it for a respawn) while Blue still has possession.
		local rebuilt = Instance.new("Part")
		rebuilt.Parent = folder
		newLook(rebuilt)
		ball = rebuilt
		WorldMarkers:step(DT)
		expect(worn()).toBe(colors.Blue:ToHex())
		-- A kickoff: nobody has held the new ball yet.
		snapshot()
		WorldMarkers:step(DT)
		expect(worn()).toBe(neutral)
	end)

	it("sizes the ring to the ball at any distance: its width in studs, ringSize pixels wider", function()
		WorldMarkers:step(DT)
		local width = 2 * config.Ball.radius
		expect(WorldMarkers.ring.Size == UDim2.new(width, markers.ringSize, width, markers.ringSize)).toBe(true)
	end)

	it("drops a line from the ball to a marker on the ground below it", function()
		WorldMarkers:step(DT)
		local ground, line = WorldMarkers.ground, WorldMarkers.line
		Fixtures.expectNear(ground.Position, Vector3.new(0, markers.groundMarkerThickness / 2, 0))
		expect(ground.Transparency).toBeCloseTo(markers.groundMarkerTransparency, 5)
		expect(line.Enabled).toBe(true)
		Fixtures.expectNear((line.Attachment0 :: Attachment).WorldPosition, Vector3.new(0, 10, 0))
		Fixtures.expectNear((line.Attachment1 :: Attachment).WorldPosition, ground.Position)
		hit = nil
		WorldMarkers:step(DT)
		expect(line.Enabled).toBe(false)
		expect(ground.Transparency).toBe(1)
	end)

	it("paints a look that comes after its ball, and leaves the unseen ball part alone", function()
		local part = Instance.new("Part")
		part.Color = Color3.new(0, 1, 0)
		part.Parent = folder
		ball = part
		snapshot({ possessingTeam = "Orange" })
		expect(function()
			WorldMarkers:step(DT)
		end).never.toThrow()
		local look = newLook(part)
		WorldMarkers:step(DT)
		expect(look.Color:ToHex()).toBe(colors.Orange:ToHex())
		expect(part.Color:ToHex()).toBe("00ff00")
	end)

	it("hides every ball marker while there is no ball", function()
		WorldMarkers:step(DT)
		ball = nil
		WorldMarkers:step(DT)
		expect(WorldMarkers.ring.Enabled).toBe(false)
		expect(WorldMarkers.line.Enabled).toBe(false)
		expect(WorldMarkers.ground.Transparency).toBe(1)
	end)

	it("steps in under 0.1 ms", function()
		snapshot({ possessingTeam = "Blue", nextGate = 2 })
		local total = 0
		for step = 1, 600 do
			-- The ball moves, and loses the ground below it every 50 steps.
			(ball :: Part).Position = Vector3.new(step % 7, 10, 0)
			hit = if step % 100 < 50 then { Position = Vector3.new(0, 0, 0), Normal = Vector3.yAxis } else nil
			local started = os.clock()
			WorldMarkers:step(DT)
			total += os.clock() - started
		end
		expect(total / 600).toBeLessThan(0.0001)
	end)
end)
