--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local FrameController = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.FrameController)

describe("FrameController", function()
	it("steps the skating, then the actions, then the poses", function()
		local order: { string } = {}
		local function recorder(name: string): { step: (self: any, dt: number) -> () }
			return {
				step = function(_self: any, dt: number)
					table.insert(order, `{name} {dt}`)
				end,
			}
		end
		FrameController:init({
			SkateController = recorder("skate"),
			ActionController = recorder("actions"),
			PoseController = recorder("poses"),
		})
		FrameController:step(0.5)
		expect(order).toEqual({ "skate 0.5", "actions 0.5", "poses 0.5" })
	end)
end)
