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
		InputController = {
			watchOverlays = function(_self: any)
				table.insert(order, "overlays")
			end,
		},
		SkateController = recorder("skate"),
		ActionController = recorder("actions"),
		PoseController = recorder("poses"),
		BallView = recorder("ballView"),
		CameraController = recorder("camera"),
		TouchControls = recorder("touch"),
		HudStore = recorder("hudStore"),
		Hud = recorder("hud"),
		WorldMarkers = recorder("worldMarkers"),
		ArenaGlow = recorder("arenaGlow"),
		CarrierBeam = recorder("carrierBeam"),
		NameTags = recorder("nameTags"),
	})
end)

describe("FrameController", function()
	it("steps the skating, then the actions, then the poses", function()
		FrameController:step(0.5)
		expect(order).toEqual({ "skate 0.5", "actions 0.5", "poses 0.5" })
	end)

	it(
		"checks Roblox's overlays, then draws the ball, then renders the camera, touch controls, HUD state, HUD, "
			.. "world markers, arena glow, carrier's beam and name tags before each frame",
		function()
			FrameController:render(0.25)
			expect(order).toEqual({
				"overlays",
				"ballView 0.25",
				"camera 0.25",
				"touch 0.25",
				"hudStore 0.25",
				"hud 0.25",
				"worldMarkers 0.25",
				"arenaGlow 0.25",
				"carrierBeam 0.25",
				"nameTags 0.25",
			})
		end
	)
end)
