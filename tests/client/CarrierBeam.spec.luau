--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local BallCarrier = require(Client.BallCarrier)
local CarrierBeam = require(Client.CarrierBeam)
local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local HudStore = require(Client.HudStore)

local config = Config.defaults()
local arena = config.Arena
local beam = config.UI.arenaGlow.beam
local DT = 1 / 60
-- The beam covers the vertical outer glass, from the solid wall's top (28) up to where the lip starts (108), its back
-- on the glass's face.
local LIP_START = arena.glass.top - arena.glass.lipRadius
local LATERAL = arena.trackWidth - beam.thickness / 2
local HEIGHT = (arena.outerWallHeight + LIP_START) / 2

local folder: Folder
local ball: Part?

local function snapshot(overrides: { [string]: any }?)
	HudStore:onSnapshot(Fixtures.matchSnapshot(overrides))
end

-- Puts the ball `distance` along the track, over the middle of the floor.
local function ballAt(distance: number)
	(ball :: Part).Position = Centerline.at(arena, distance, arena.trackWidth / 2, 3).Position
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "CarrierBeamTest"
	folder.Parent = workspace
	local part = Instance.new("Part")
	part.Name = "Ball"
	part.Anchored = true
	part.Parent = folder
	ball = part
	BallCarrier:init({})
	HudStore:init({ Config = config })
	snapshot()
	CarrierBeam:init({
		Config = config,
		BallCarrier = BallCarrier,
		BallPart = {
			get = function(_self: any): BasePart?
				return ball
			end,
		},
		HudStore = HudStore,
		Parent = folder,
	})
	CarrierBeam:start()
end)

afterEach(function()
	CarrierBeam:destroy()
	folder:Destroy()
end)

describe("CarrierBeam", function()
	it("hides the beam while nobody carries the ball", function()
		local part = CarrierBeam.part
		snapshot({ possessingTeam = "Orange" })
		ballAt(50)
		CarrierBeam:step(DT)
		expect(part.Transparency).toBe(1)
		BallCarrier:set("2")
		CarrierBeam:step(DT)
		expect(part.Transparency).toBe(0)
		-- Hidden the moment the ball is thrown, before the server says so.
		BallCarrier:predictRelease()
		CarrierBeam:step(DT)
		expect(part.Transparency).toBe(1)
		-- And while the HUD does not know whose ball it is, or there is no ball.
		BallCarrier:set("2")
		CarrierBeam:step(DT)
		expect(part.Transparency).toBe(0)
		snapshot()
		CarrierBeam:step(DT)
		expect(part.Transparency).toBe(1)
		snapshot({ possessingTeam = "Orange" })
		CarrierBeam:step(DT)
		expect(part.Transparency).toBe(0)
		ball = nil
		CarrierBeam:step(DT)
		expect(part.Transparency).toBe(1)
	end)

	it("stands the beam on the outer glass beside the carried ball, in the possessing team's colour", function()
		BallCarrier:set("2")
		snapshot({ possessingTeam = "Orange" })
		ballAt(50)
		CarrierBeam:step(DT)
		local part = CarrierBeam.part
		-- 50 along the top straight: x 50, its back on the outer glass's face (z -100), halfway up the vertical glass.
		Fixtures.expectNear(part.Position, Vector3.new(50, HEIGHT, -100 + beam.thickness / 2))
		Fixtures.expectNear(part.Size, Vector3.new(beam.thickness, LIP_START - arena.outerWallHeight, beam.width))
		expect(part.Color == config.UI.teamColors.Orange and part.Transparency == 0).toBe(true)
		expect(part.Material == config.UI.arenaGlow.material and part.Anchored).toBe(true)
		-- A skater riding the glass passes through it, and no ray sees it.
		expect(part.CanCollide or part.CanQuery or part.CanTouch or part.CastShadow).toBe(false)
		expect(part.Parent == folder).toBe(true)
	end)

	it("moves with the ball around a curved end, upright and facing across the track", function()
		BallCarrier:set("2")
		snapshot({ possessingTeam = "Blue" })
		local part = CarrierBeam.part
		-- Around the left end, its apex, and around the right end.
		for _, distance in { 230, 200 + 30 * math.pi, 700 } do
			ballAt(distance)
			CarrierBeam:step(DT)
			local expected = Centerline.at(arena, distance, LATERAL, HEIGHT)
			Fixtures.expectNear(part.Position, expected.Position)
			Fixtures.expectNear(part.CFrame.UpVector, Vector3.yAxis)
			-- Its thickness across the track (toward the outer glass), its width along it.
			Fixtures.expectNear(part.CFrame.RightVector, expected.RightVector)
		end
		-- At the left end's apex the outer glass faces +X: the beam stands at x -160 - 40 + its half thickness.
		ballAt(200 + 30 * math.pi)
		CarrierBeam:step(DT)
		Fixtures.expectNear(part.Position, Vector3.new(-200 + beam.thickness / 2, HEIGHT, 0))
		Fixtures.expectNear(part.CFrame.RightVector, Vector3.new(-1, 0, 0))
	end)

	it("writes the colour and the transparency only when they change", function()
		BallCarrier:set("2")
		snapshot({ possessingTeam = "Blue" })
		ballAt(50)
		CarrierBeam:step(DT)
		local part = CarrierBeam.part
		-- Changed behind its back: a step that would write the same values again leaves them as they are.
		part.Color = Color3.new(1, 1, 1)
		part.Transparency = 0.5
		ballAt(60)
		CarrierBeam:step(DT)
		expect(part.Color == Color3.new(1, 1, 1) and part.Transparency == 0.5).toBe(true)
		-- A new team is written.
		snapshot({ possessingTeam = "Orange" })
		CarrierBeam:step(DT)
		expect(part.Color == config.UI.teamColors.Orange).toBe(true)
		-- Hidden once, then left alone while it stays hidden.
		BallCarrier:set(nil)
		CarrierBeam:step(DT)
		expect(part.Transparency).toBe(1)
		part.Transparency = 0.25
		CarrierBeam:step(DT)
		expect(part.Transparency).toBe(0.25)
	end)

	it("steps in under 0.1 ms", function()
		BallCarrier:set("2")
		snapshot({ possessingTeam = "Blue" })
		ballAt(0)
		CarrierBeam:step(DT)
		local length = Centerline.length(arena)
		local total = 0
		-- Once around the lap.
		for step = 1, 600 do
			ballAt(step * length / 600)
			local started = os.clock()
			CarrierBeam:step(DT)
			total += os.clock() - started
		end
		expect(total / 600).toBeLessThan(0.0001)
	end)
end)
