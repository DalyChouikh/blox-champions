--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local BallPart = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.BallPart)
local Look = require(ReplicatedStorage.Shared.Ball.Look)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local folder: Folder

local function newBall(): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Parent = folder
	part:AddTag(Tags.Ball)
	return part
end

local function newLook(ball: Part): MeshPart
	local look = Instance.new("MeshPart")
	look.Name = Look.NAME
	look.Anchored = true
	look.Parent = ball
	return look
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "BallPartTest"
	folder.Parent = workspace
end)

afterEach(function()
	BallPart:destroy()
	folder:Destroy()
end)

describe("BallPart", function()
	it("keeps the tagged ball part while it is in the workspace", function()
		BallPart:init({})
		BallPart:start()
		expect(BallPart:get()).toBeNil()
		local part = newBall()
		task.wait() -- tag signals are deferred
		expect(BallPart:get() == part).toBe(true)
		part:RemoveTag(Tags.Ball)
		task.wait()
		expect(BallPart:get()).toBeNil()
		part:AddTag(Tags.Ball)
		task.wait()
		expect(BallPart:get() == part).toBe(true)
		part.Parent = nil
		expect(BallPart:get()).toBeNil()
	end)

	it("finds a ball already in the workspace when it starts", function()
		local part = newBall()
		BallPart:init({})
		BallPart:start()
		expect(BallPart:get() == part).toBe(true)
	end)

	-- #400: the part that draws the ball (its mesh in its skin), under the ball part, which no one sees.
	it("finds the ball's look once it is there, and a rebuilt ball's, and none without a ball", function()
		BallPart:init({})
		BallPart:start()
		expect(BallPart:look()).toBeNil()
		local part = newBall()
		task.wait()
		expect(BallPart:look()).toBeNil()
		local look = newLook(part)
		expect(BallPart:look() == look).toBe(true)
		local rebuilt = newBall()
		local rebuiltLook = newLook(rebuilt)
		part:Destroy()
		task.wait()
		expect(BallPart:look() == rebuiltLook).toBe(true)
		rebuiltLook.Parent = nil
		expect(BallPart:look()).toBeNil()
		rebuilt.Parent = nil
		expect(BallPart:look()).toBeNil()
	end)
end)
