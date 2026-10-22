--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach = JestGlobals.beforeEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local PlayerList = require(ReplicatedStorage.Shared.Util.PlayerList)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local first, second, joiner = Fixtures.stubPlayer(1), Fixtures.stubPlayer(2), Fixtures.stubPlayer(3)

-- The Players service as PlayerList reads it: the players already in the game and the join and leave signals.
local players: any
beforeEach(function()
	players = {
		GetPlayers = function(_self: any): { any }
			return { first, second }
		end,
		PlayerAdded = Signal.new(),
		PlayerRemoving = Signal.new(),
	}
end)

describe("PlayerList", function()
	it("starts with the players already in the game and follows joins and leaves", function()
		local list = PlayerList.new(players)
		expect(list.list).toEqual({ first, second })
		players.PlayerAdded:Fire(joiner)
		expect(list.list).toEqual({ first, second, joiner })
		players.PlayerRemoving:Fire(first)
		expect(list.list).toEqual({ second, joiner })
	end)

	it("keeps one list, so a caller can hold it", function()
		local list = PlayerList.new(players)
		local held = list.list
		players.PlayerAdded:Fire(joiner)
		players.PlayerRemoving:Fire(first)
		expect(list.list == held).toBe(true)
	end)

	-- Roblox defers events: a player who joined just before the list read the game can arrive afterwards too.
	it("lists a player once when their join arrives after the list already read them", function()
		local list = PlayerList.new(players)
		players.PlayerAdded:Fire(first)
		expect(list.list).toEqual({ first, second })
	end)

	it("stops following the game once destroyed", function()
		local list = PlayerList.new(players)
		list:destroy()
		players.PlayerAdded:Fire(joiner)
		players.PlayerRemoving:Fire(first)
		expect(list.list).toEqual({ first, second })
	end)
end)
