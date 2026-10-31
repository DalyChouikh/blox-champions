--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local ThrowArc = require(Client.ThrowArc)
local Trajectory = require(ReplicatedStorage.Shared.Ball.Trajectory)

local config = Config.defaults()
local arc = config.UI.trajectory.arc
local GRAVITY = Config.gravity(config)
local DT = 1 / 60
-- The ball in the hand, high in open air, and a throw rising along +X.
local HAND = Vector3.new(0, 50, 0)
local THROWN = Vector3.new(100, 20, 0)

local folder: Folder
local ball: Part?
-- What ActionController:throwVelocity says: nil while no throw charges.
local velocity: Vector3?
-- The arena's solid parts in a test: only the walls a test adds.
local solid: RaycastParams

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ThrowArcTest"
	folder.Parent = workspace
	local part = Instance.new("Part")
	part.Name = "Ball"
	part.Anchored = true
	part.Position = HAND
	part.Parent = folder
	ball = part
	velocity = nil
	solid = RaycastParams.new()
	solid.FilterType = Enum.RaycastFilterType.Include
	solid.FilterDescendantsInstances = {}
	ThrowArc:init({
		Config = config,
		ActionController = {
			throwVelocity = function(_self: any): Vector3?
				return velocity
			end,
		},
		BallPart = {
			get = function(_self: any): BasePart?
				return ball
			end,
		},
		RideSurfaces = { solid = solid },
		Parent = folder,
	})
	ThrowArc:start()
end)

afterEach(function()
	ThrowArc:destroy()
	folder:Destroy()
end)

-- A tall wall across +X whose near face stands at x, one of the arena's solid parts.
local function wall(x: number)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = Vector3.new(2, 80, 80)
	part.Position = Vector3.new(x + 1, HAND.Y, 0)
	part.Parent = folder
	solid:AddToFilter(part)
end

-- Where a marker of the arc stands in the world.
local function at(marker: BillboardGui): Vector3
	return (marker.Adornee :: Attachment).WorldPosition
end

local function expectHidden(from: number)
	for i = from, #ThrowArc.dots do
		expect(ThrowArc.dots[i].Enabled).toBe(false)
	end
end

-- An outline's colour and width.
local function expectStroke(frame: Frame, color: Color3, thickness: number)
	local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
	expect(stroke.Color == color).toBe(true)
	expect(stroke.Thickness).toBeCloseTo(thickness, 4)
end

describe("ThrowArc", function()
	-- The owner's look (Q145): drawn over everything, the thrower's skater too, at a fixed size on screen.
	it("makes maxDots dots and a landing ring drawn over everything, hidden while no throw charges", function()
		local anchor = ThrowArc.anchor
		expect(anchor.Anchored).toBe(true)
		expect(anchor.Transparency).toBe(1)
		expect(anchor.CanCollide or anchor.CanQuery or anchor.CanTouch).toBe(false)
		expect(anchor:IsDescendantOf(folder)).toBe(true)
		expect(#ThrowArc.dots).toBe(arc.maxDots)
		for _, dot in ThrowArc.dots do
			expect(dot.AlwaysOnTop).toBe(true)
			expect(dot.Size == UDim2.fromOffset(arc.dotSize, arc.dotSize)).toBe(true)
			expect((dot.Adornee :: Instance).Parent == anchor).toBe(true)
			local face = dot:FindFirstChild("Dot") :: Frame
			expect(face.BackgroundColor3 == arc.color).toBe(true)
			expect(face.BackgroundTransparency).toBeCloseTo(arc.transparency, 4)
			expect((face:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius == UDim.new(0.5, 0)).toBe(true)
			expectStroke(face, arc.edgeColor, arc.edgeThickness)
		end
		-- The ring: the arc's colour inside a dark edge on each side.
		local ring = ThrowArc.ring
		expect(ring.AlwaysOnTop).toBe(true)
		expect(ring.Size == UDim2.fromOffset(arc.ringSize, arc.ringSize)).toBe(true)
		expect((ring.Adornee :: Instance).Parent == anchor).toBe(true)
		expectStroke(ring:FindFirstChild("Ring") :: Frame, arc.color, arc.ringThickness)
		expectStroke(ring:FindFirstChild("Edge") :: Frame, arc.edgeColor, arc.ringThickness + 2 * arc.edgeThickness)
		ThrowArc:step(DT)
		expect(ThrowArc.shown).toBe(0)
		expectHidden(1)
		expect(ring.Enabled).toBe(false)
	end)

	-- The thrower's arc (#313, Q98): from the ball in the hand along the throw a release would make now, under the
	-- world's gravity, a dot every `spacing` studs of its launch speed: where the server's ball will fly.
	it("draws the throw a release would make now, a dot every spacing studs from the ball", function()
		velocity = THROWN
		ThrowArc:step(DT)
		expect(ThrowArc.shown).toBe(arc.maxDots)
		local step = arc.spacing / THROWN.Magnitude
		for i, dot in ThrowArc.dots do
			expect(dot.Enabled).toBe(true)
			Fixtures.expectNear(at(dot), Trajectory.positionAt(HAND, THROWN, GRAVITY, (i - 1) * step), 1e-3)
		end
		-- Nothing in the way: no landing.
		expect(ThrowArc.ring.Enabled).toBe(false)
	end)

	-- Level at 100 studs/s a dot every 4 studs: x 0, 4, ... 28, then the ball's centre stops a radius short of the
	-- wall's face at x 30, where the ring shows.
	it("ends where the ball would first touch the arena, in a ring, the dots past it hidden", function()
		velocity = Vector3.new(100, 0, 0)
		ThrowArc:step(DT)
		expect(ThrowArc.shown).toBe(arc.maxDots)
		wall(30)
		ThrowArc:step(DT)
		local shown = ThrowArc.shown
		expect(shown).toBe(9)
		expect(at(ThrowArc.dots[shown]).X).toBeCloseTo(30 - config.Ball.radius, 2)
		expect(at(ThrowArc.dots[shown - 1]).X).toBeCloseTo(28, 3)
		expect(ThrowArc.dots[shown].Enabled).toBe(true)
		expectHidden(shown + 1)
		expect(ThrowArc.ring.Enabled).toBe(true)
		Fixtures.expectNear(at(ThrowArc.ring), at(ThrowArc.dots[shown]), 1e-4)
	end)

	it("hides every dot and the ring once the charge ends, and draws nothing without a ball", function()
		velocity = Vector3.new(100, 0, 0)
		wall(30)
		ThrowArc:step(DT)
		velocity = nil
		ThrowArc:step(DT)
		expect(ThrowArc.shown).toBe(0)
		expectHidden(1)
		expect(ThrowArc.ring.Enabled).toBe(false)
		velocity = THROWN
		ball = nil
		ThrowArc:step(DT)
		expect(ThrowArc.shown).toBe(0)
		expectHidden(1)
		expect(ThrowArc.ring.Enabled).toBe(false)
	end)
end)
