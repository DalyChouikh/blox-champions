--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local NetService = require(game:GetService("ServerScriptService").Server.NetService)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Schemas = require(ReplicatedStorage.Shared.Net.Schemas)

local parent: Folder
beforeEach(function()
	parent = Instance.new("Folder")
	parent.Name = "NetServiceTest"
	parent.Parent = ReplicatedStorage
end)
afterEach(function()
	parent:Destroy()
end)

describe("NetService", function()
	it("creates the remotes under its parent and removes them on destroy", function()
		NetService:init({ Parent = parent })
		expect(parent:FindFirstChild(Remotes.FOLDER)).never.toBeNil()
		NetService:destroy()
		expect(parent:FindFirstChild(Remotes.FOLDER)).toBeNil()
	end)

	it("rejects an unknown remote and skips a player who is not here", function()
		NetService:init({ Parent = parent })
		expect(function()
			NetService:fireAll("Ghost", {})
		end).toThrow('NetService: unknown remote "Ghost"')
		expect(function()
			NetService:fireTo("999999999", Remotes.names.MatchSnapshot, {})
		end).never.toThrow()
		NetService:destroy()
	end)

	-- #316: the loose ball's state goes to everyone each frame it moves, on an unreliable remote.
	it("streams to every client and rejects an unknown stream", function()
		NetService:init({ Parent = parent })
		expect(function()
			NetService:streamAll(Remotes.streams.BallState, Vector3.one, Vector3.zero, true, 1.5)
		end).never.toThrow()
		expect(function()
			NetService:streamAll(Remotes.names.BallCarrier, {})
		end).toThrow('NetService: unknown stream "BallCarrier"')
		NetService:destroy()
	end)

	it("hands a valid message to its listener with the sender's id", function()
		NetService:init({
			Parent = parent,
			Clock = function(): number
				return 0
			end,
		})
		local got: { any } = {}
		NetService:listen(Remotes.names.SkateState, Schemas.SkateState, 20, function(player: string, payload: any)
			table.insert(got, { player = player, pump = payload.pump, brake = payload.brake })
		end)
		NetService:receive(Remotes.names.SkateState, "7", { pump = true, brake = false, airPose = false })
		expect(got).toEqual({ { player = "7", pump = true, brake = false } })
		NetService:destroy()
	end)

	it("drops malformed and too-frequent messages and counts them per player", function()
		NetService:init({
			Parent = parent,
			Clock = function(): number
				return 0
			end,
		})
		local handled = 0
		NetService:listen(Remotes.names.SkateState, Schemas.SkateState, 2, function()
			handled += 1
		end)
		for _ = 1, 3 do
			NetService:receive(Remotes.names.SkateState, "7", { pump = true, brake = false, airPose = false })
		end
		NetService:receive(Remotes.names.SkateState, "8", { pump = 1, brake = false, airPose = false })
		expect(handled).toBe(2)
		expect(NetService:dropped("7")).toBe(1)
		expect(NetService:dropped("8")).toBe(1)
		NetService:forget("7")
		expect(NetService:dropped("7")).toBe(0)
		NetService:destroy()
	end)
end)
