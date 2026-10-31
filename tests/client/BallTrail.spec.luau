--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local BallCarrier = require(Client.BallCarrier)
local BallTrail = require(Client.BallTrail)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

local config = Config.defaults()
local settings = config.UI.trajectory.trail
local DT = 1 / 60

local folder: Folder
local ball: Part?

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "BallTrailTest"
	folder.Parent = workspace
	local part = Instance.new("Part")
	part.Name = "Ball"
	part.Anchored = true
	part.Position = Vector3.new(10, 5, -20)
	part.Parent = folder
	ball = part
	BallCarrier:init({})
	BallTrail:init({
		Config = config,
		BallCarrier = BallCarrier,
		BallPart = {
			get = function(_self: any): BasePart?
				return ball
			end,
		},
		Parent = folder,
	})
	BallTrail:start()
end)

afterEach(function()
	BallTrail:destroy()
	folder:Destroy()
end)

-- The server's mark (BallService, #313): the ball flies loose from a throw, a pass or a roll.
local function thrown(value: boolean?)
	(ball :: Part):SetAttribute(Attributes.Thrown, value)
end

describe("BallTrail", function()
	-- Its own part, so the ball's spin never twists the trail: two attachments `width` apart, the trail between them
	-- facing the camera, `lifetime` seconds long, fading from `transparency` behind the ball to nothing.
	it("builds a holder no ray, touch or shadow finds, carrying a trail that starts off", function()
		local holder = BallTrail.holder
		expect(holder.Anchored).toBe(true)
		expect(holder.Transparency).toBe(1)
		expect(holder.CanCollide).toBe(false)
		expect(holder.CanQuery).toBe(false)
		expect(holder.CanTouch).toBe(false)
		expect(holder.CastShadow).toBe(false)
		expect(holder.Parent == folder).toBe(true)
		local trail = BallTrail.trail
		expect(trail.Enabled).toBe(false)
		expect(trail.FaceCamera).toBe(true)
		expect(trail.Lifetime).toBeCloseTo(settings.lifetime, 4)
		local a0, a1 = trail.Attachment0 :: Attachment, trail.Attachment1 :: Attachment
		expect(a0.Parent == holder and a1.Parent == holder).toBe(true)
		expect((a0.Position - a1.Position).Magnitude).toBeCloseTo(settings.width, 4)
		expect(trail.Color.Keypoints[1].Value == settings.color).toBe(true)
		local fade = trail.Transparency.Keypoints
		expect(fade[1].Value).toBeCloseTo(settings.transparency, 4)
		expect(fade[#fade].Value).toBe(1)
	end)

	-- On every screen (#313), from the server's mark until the next catch.
	it("trails the ball while it flies loose from a throw, a pass or a roll", function()
		local part = ball :: Part
		thrown(true)
		BallTrail:step(DT)
		expect(BallTrail.trail.Enabled).toBe(true)
		Fixtures.expectNear(BallTrail.holder.Position, part.Position, 1e-4)
		-- Where this screen draws it next (BallView moves the part).
		part.Position = Vector3.new(14, 5, -20)
		BallTrail:step(DT)
		Fixtures.expectNear(BallTrail.holder.Position, Vector3.new(14, 5, -20), 1e-4)
	end)

	it("trails nothing behind a ball nobody threw, a carried ball or no ball", function()
		BallTrail:step(DT)
		expect(BallTrail.trail.Enabled).toBe(false)
		thrown(true)
		BallCarrier:set("1")
		BallTrail:step(DT)
		expect(BallTrail.trail.Enabled).toBe(false)
		BallCarrier:set(nil)
		BallTrail:step(DT)
		expect(BallTrail.trail.Enabled).toBe(true)
		thrown(nil)
		BallTrail:step(DT)
		expect(BallTrail.trail.Enabled).toBe(false)
		thrown(true)
		ball = nil
		BallTrail:step(DT)
		expect(BallTrail.trail.Enabled).toBe(false)
	end)

	-- The holder keeps to the drawn ball while there is no trail too, so the next one starts at the ball, never with
	-- a streak from wherever the last one ended.
	it("keeps to the ball while it trails nothing, so each trail starts at the ball", function()
		local part = ball :: Part
		BallCarrier:set("1")
		part.Position = Vector3.new(-30, 2, 40)
		BallTrail:step(DT)
		expect(BallTrail.trail.Enabled).toBe(false)
		Fixtures.expectNear(BallTrail.holder.Position, Vector3.new(-30, 2, 40), 1e-4)
	end)
end)
