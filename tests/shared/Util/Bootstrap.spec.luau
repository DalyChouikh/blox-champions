--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Bootstrap = require(ReplicatedStorage.Shared.Util.Bootstrap)
local Config = require(ReplicatedStorage.Shared.Config)
local NormalChampions = require(ReplicatedStorage.Shared.Modes.NormalChampions)

describe("Bootstrap.run", function()
	it("resolves config, gives it to modules, and logs the ready line", function()
		local lines = {}
		local received: any = nil
		local probe = {
			name = "Probe",
			dependencies = { "Config" },
			init = function(_self: any, deps: { [string]: any })
				received = deps.Config
			end,
		}
		local config, registry = Bootstrap.run({
			realm = "Server",
			mode = NormalChampions,
			modules = { probe },
			log = function(message)
				table.insert(lines, message)
			end,
		})
		expect(config).toEqual(Config.defaults())
		expect(received).toBe(config)
		expect(registry.Probe).toBe(probe)
		expect(lines).toEqual({ "[BloxChampions] Server ready: mode=NormalChampions, modules=1" })
	end)

	it("fails on invalid config before any module initializes", function()
		local initialized = false
		local probe = {
			name = "Probe",
			init = function()
				initialized = true
			end,
		}
		expect(function()
			Bootstrap.run({
				realm = "Client",
				mode = {
					id = "Bad",
					displayName = "Bad",
					itemsEnabled = false,
					overrides = { Match = { teamSize = 0 } },
				},
				modules = { probe },
				log = function() end,
			})
		end).toThrow("Match.teamSize: must be >= 1 (got 0)")
		expect(initialized).toBe(false)
	end)
end)
