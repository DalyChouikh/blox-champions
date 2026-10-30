--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Bootstrap = require(ReplicatedStorage.Shared.Util.Bootstrap)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local NormalChampions = require(ReplicatedStorage.Shared.Modes.NormalChampions)

describe("Bootstrap.run", function()
	it("resolves config, gives the world its gravity and modules their config, and logs the ready line", function()
		local lines = {}
		local received: any = nil
		local world = { Gravity = 196.2 }
		local seenGravity: number? = nil
		local probe = {
			name = "Probe",
			dependencies = { "Config" },
			init = function(_self: any, deps: { [string]: any })
				received = deps.Config
				seenGravity = world.Gravity
			end,
		}
		local config, registry = Bootstrap.run({
			realm = "Server",
			mode = NormalChampions,
			modules = { probe },
			world = world,
			log = function(message)
				table.insert(lines, message)
			end,
		})
		expect(config).toEqual(Config.defaults())
		expect(received).toBe(config)
		-- Two thirds of Roblox's default (#279), set before any module starts.
		expect(world.Gravity).toBe(130.8)
		expect(seenGravity).toBe(130.8)
		expect(registry.Probe).toBe(probe)
		expect(lines).toEqual({ "[BloxChampions] Server ready: mode=NormalChampions, modules=1" })
	end)

	it("fails on invalid config before any module initializes", function()
		local initialized = false
		local world = { Gravity = 196.2 }
		local probe = {
			name = "Probe",
			init = function()
				initialized = true
			end,
		}
		expect(function()
			Bootstrap.run({
				realm = "Client",
				mode = Fixtures.mode({ Match = { teamSize = 0 } }),
				modules = { probe },
				world = world,
				log = function() end,
			})
		end).toThrow("Match.teamSize: must be >= 1 (got 0)")
		expect(initialized).toBe(false)
		expect(world.Gravity).toBe(196.2)
	end)
end)
