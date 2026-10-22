--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)

describe("PlayerIds", function()
	it("names a player by their UserId, which a returning player keeps", function()
		expect(PlayerIds.of(Fixtures.stubPlayer(7))).toBe("7")
		expect(PlayerIds.of(Fixtures.stubPlayer(-2))).toBe("-2")
	end)

	it("finds no player for an id that is not a player in this server", function()
		expect(PlayerIds.player("999999999")).toBeNil()
		expect(PlayerIds.player("Ghost")).toBeNil()
	end)
end)
