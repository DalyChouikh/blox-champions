--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ArenaParts = require(Client.ArenaParts)
local BallCarrier = require(Client.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudStore = require(Client.HudStore)
local RideSurfaces = require(Client.RideSurfaces)
local WorldMarkers = require(Client.WorldMarkers)

local config = Config.defaults()
local markers = config.UI.markers
local colors = config.UI.teamColors
local LOCAL_ID = "1"
local VIEWPORT = Vector2.new(1000, 500)
local DT = 1 / 60

-- Where the fake camera puts something on the screen, and whether it is on it.
type Screen = { point: Vector3, onScreen: boolean }

local folder: Folder
local ball: Part?
-- What the fake ray below the ball hits; nil for nothing.
local hit: { Position: Vector3, Normal: Vector3 }?
-- The ball's screen, and every other point's (the gates').
local ballScreen: Screen
local gateScreen: Screen
-- The last point other than the ball's that was put on the screen: where the gate arrow aims.
local gateAimed: Vector3?
local arena: Fixtures.HudArena

local function snapshot(overrides: { [string]: any }?)
	HudStore:onSnapshot(Fixtures.matchSnapshot(overrides))
end

local function stroke(): UIStroke
	return WorldMarkers.ring:FindFirstChild("Stroke", true) :: UIStroke
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
	ball = part
	hit = { Position = Vector3.new(0, 0, 0), Normal = Vector3.yAxis }
	ballScreen = { point = Vector3.new(300, 200, 10), onScreen = true }
	gateScreen = { point = Vector3.new(600, 100, 20), onScreen = true }
	gateAimed = nil
	arena = Fixtures.hudArena(folder)
	ArenaParts:init({})
	ArenaParts:refresh()
	RideSurfaces:init({})
	BallCarrier:init({})
	HudStore:init({ Config = config })
	snapshot()
	WorldMarkers:init({
		Config = config,
		RideSurfaces = RideSurfaces,
		BallPart = {
			get = function(_self: any): BasePart?
				return ball
			end,
		},
		BallCarrier = BallCarrier,
		HudStore = HudStore,
		ArenaParts = ArenaParts,
		Parent = folder,
		World = folder,
		LocalId = LOCAL_ID,
		Project = function(position: Vector3): (Vector3, boolean)
			local current = ball
			if current ~= nil and position == current.Position then
				return ballScreen.point, ballScreen.onScreen
			end
			gateAimed = position
			return gateScreen.point, gateScreen.onScreen
		end,
		ViewportSize = function(): Vector2
			return VIEWPORT
		end,
		Raycast = function(_origin: Vector3, _direction: Vector3, _params: RaycastParams): RaycastResult?
			return hit :: any
		end,
	})
end)

afterEach(function()
	ArenaParts:destroy()
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

	it("points to the ball from the screen's edge when it is off-screen", function()
		WorldMarkers:step(DT)
		local arrow = WorldMarkers.ballArrow
		expect(arrow.Visible).toBe(false)
		ballScreen = { point = Vector3.new(2000, 250, 10), onScreen = false }
		WorldMarkers:step(DT)
		expect(arrow.Visible).toBe(true)
		expect(arrow.Position == UDim2.fromOffset(VIEWPORT.X - markers.edgeMargin, 250)).toBe(true)
		expect(arrow.Rotation).toBeCloseTo(90, 3)
		ballScreen = { point = Vector3.new(300, 200, 10), onScreen = true }
		WorldMarkers:step(DT)
		expect(arrow.Visible).toBe(false)
	end)

	it("points the carrier to their team's next gate, and nobody else", function()
		local arrow = WorldMarkers.gateArrow
		BallCarrier:set(LOCAL_ID)
		snapshot({ possessingTeam = "Blue", nextGate = 3 })
		WorldMarkers:step(DT)
		expect(arrow.Visible).toBe(true)
		expect(arrow.Position == UDim2.fromOffset(600, 100)).toBe(true)
		-- At the gate panel's pivot: its wall's middle.
		Fixtures.expectNear(gateAimed :: Vector3, arena.markers[3]:GetPivot().Position)
		BallCarrier:set("2")
		WorldMarkers:step(DT)
		expect(arrow.Visible).toBe(false)
		-- Every streak starts at the goal's gate (the snapshot fixture's next gate): the arrow shows from the pickup.
		BallCarrier:set(LOCAL_ID)
		snapshot({ possessingTeam = "Blue" })
		WorldMarkers:step(DT)
		expect(arrow.Visible).toBe(true)
		Fixtures.expectNear(gateAimed :: Vector3, arena.markers[config.Arena.goalGateIndex]:GetPivot().Position)
	end)

	it("hides every ball marker while there is no ball", function()
		ballScreen = { point = Vector3.new(2000, 250, 10), onScreen = false }
		WorldMarkers:step(DT)
		ball = nil
		WorldMarkers:step(DT)
		expect(WorldMarkers.ring.Enabled).toBe(false)
		expect(WorldMarkers.line.Enabled).toBe(false)
		expect(WorldMarkers.ground.Transparency).toBe(1)
		expect(WorldMarkers.ballArrow.Visible).toBe(false)
	end)

	it("steps in under 0.1 ms", function()
		BallCarrier:set(LOCAL_ID)
		snapshot({ possessingTeam = "Blue", nextGate = 2 })
		local onScreen: Screen = { point = Vector3.new(300, 200, 10), onScreen = true }
		local offScreen: Screen = { point = Vector3.new(2000, 250, -10), onScreen = false }
		local total = 0
		for step = 1, 600 do
			-- The ball moves, and goes off screen and back every 50 steps.
			(ball :: Part).Position = Vector3.new(step % 7, 10, 0)
			ballScreen = if step % 100 < 50 then onScreen else offScreen
			local started = os.clock()
			WorldMarkers:step(DT)
			total += os.clock() - started
		end
		expect(total / 600).toBeLessThan(0.0001)
	end)
end)
