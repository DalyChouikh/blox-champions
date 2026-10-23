--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach = JestGlobals.beforeEach

local FrameController = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.FrameController)

-- What the stepped modules were asked to do, in order.
local order: { string } = {}

-- A module that records each step it is given.
local function recorder(name: string): { step: (self: any, dt: number) -> () }
	return {
		step = function(_self: any, dt: number)
			table.insert(order, `{name} {dt}`)
		end,
	}
end

beforeEach(function()
	table.clear(order)
	FrameController:init({
		SkateController = recorder("skate"),
		ActionController = recorder("actions"),
		PoseController = recorder("poses"),
		CameraController = recorder("camera"),
	})
end)

describe("FrameController", function()
	it("steps the skating, then the actions, then the poses", function()
		FrameController:step(0.5)
		expect(order).toEqual({ "skate 0.5", "actions 0.5", "poses 0.5" })
	end)

	it("renders the camera before each frame is drawn", function()
		FrameController:render(0.25)
		expect(order).toEqual({ "camera 0.25" })
	end)
end)
