--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach = JestGlobals.beforeEach

local FrameController = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.FrameController)

-- What the stepped modules were asked to do, in order, and the lines FrameController reported.
local order: { string } = {}
local logs: { string } = {}

type Stepped = { step: (self: any, dt: number) -> () }

-- A module that records each step it is given.
local function recorder(name: string): Stepped
	return {
		step = function(_self: any, dt: number)
			table.insert(order, `{name} {dt}`)
		end,
	}
end

-- A module that records each step it is given, then throws (with no position in its message, so the report's throw
-- site comes from the stack).
local function thrower(name: string): Stepped
	return {
		step = function(_self: any, dt: number)
			table.insert(order, `{name} {dt}`)
			error(`{name} broke`, 0)
		end,
	}
end

-- FrameController's dependencies: recorders, but for `overrides`.
local function deps(overrides: { [string]: Stepped }?): { [string]: any }
	local modules: { [string]: any } = {
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
		BallTrail = recorder("ballTrail"),
		NameTags = recorder("nameTags"),
		Log = function(line: string)
			table.insert(logs, line)
		end,
	}
	local given: { [string]: Stepped } = overrides or {}
	for name, module in given do
		modules[name] = module
	end
	return modules
end

beforeEach(function()
	table.clear(order)
	table.clear(logs)
	FrameController:init(deps())
end)

describe("FrameController", function()
	it("depends on every module it steps", function()
		expect(FrameController.dependencies).toEqual({
			"InputController",
			"SkateController",
			"ActionController",
			"PoseController",
			"BallView",
			"CameraController",
			"TouchControls",
			"HudStore",
			"Hud",
			"WorldMarkers",
			"ArenaGlow",
			"CarrierBeam",
			"BallTrail",
			"NameTags",
		})
	end)

	it("steps the skating, then the actions, then the poses", function()
		FrameController:step(0.5)
		expect(order).toEqual({ "skate 0.5", "actions 0.5", "poses 0.5" })
	end)

	it(
		"checks Roblox's overlays, then draws the ball, then renders the camera, touch controls, HUD state, HUD, "
			.. "world markers, arena glow, carrier's beam, ball's trail and name tags before each frame",
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
				"ballTrail 0.25",
				"nameTags 0.25",
			})
		end
	)

	-- #392, the owner's Q263: an error in one module's step (a HUD binding's update, say) no longer skips the steps
	-- after it that frame, and it is reported once, with where it was thrown, not every frame.
	it("steps every module after one whose step throws, and reports that module once with where it threw", function()
		FrameController:init(deps({ SkateController = thrower("skate"), Hud = thrower("hud") }))
		local frame = {
			"skate 0.5",
			"actions 0.5",
			"poses 0.5",
			"overlays",
			"ballView 0.25",
			"camera 0.25",
			"touch 0.25",
			"hudStore 0.25",
			"hud 0.25",
			"worldMarkers 0.25",
			"arenaGlow 0.25",
			"carrierBeam 0.25",
			"ballTrail 0.25",
			"nameTags 0.25",
		}
		local expected: { string } = {}
		for _ = 1, 3 do
			FrameController:step(0.5)
			FrameController:render(0.25)
			table.move(frame, 1, #frame, #expected + 1, expected)
		end
		expect(order).toEqual(expected)
		expect(#logs).toBe(2)
		for index, failed in { { "SkateController", "skate" }, { "Hud", "hud" } } do
			local head = `[BloxChampions] FrameController: {failed[1]}'s step failed: {failed[2]} broke (`
			expect(string.sub(logs[index], 1, #head)).toBe(head)
			-- The throw site: the thrower's step in this spec (Jest names it `[string
			-- "...FrameController.spec"]:<line>`).
			local at = string.match(logs[index], "%((.*)%)$") :: string
			expect(string.find(at, "FrameController.spec", 1, true) ~= nil).toBe(true)
			expect(string.sub(at, -#"function step")).toBe("function step")
		end
	end)
end)
