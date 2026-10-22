--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach = JestGlobals.beforeEach

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local TeamService = require(game:GetService("ServerScriptService").Server.TeamService)

-- Roblox cannot create a Player in Edit, so tests use a table with the members TeamService reads.
local function stubPlayer(userId: number): any
	local attributes: { [string]: any } = {}
	return {
		UserId = userId,
		SetAttribute = function(_self: any, key: string, value: any)
			attributes[key] = value
		end,
		GetAttribute = function(_self: any, key: string): any
			return attributes[key]
		end,
	}
end

beforeEach(function()
	TeamService:init({ Config = Fixtures.config({ Match = { teamSize = 1 } }) })
end)

describe("TeamService", function()
	it("seats joining players, marks their team on the player and announces it", function()
		local joined: { string }, seated: { string } = {}, {}
		TeamService.joined:Connect(function(id: string)
			table.insert(joined, id)
		end)
		TeamService.seated:Connect(function(id: string, team: string)
			table.insert(seated, id .. ":" .. team)
		end)
		local a, b, c = stubPlayer(1), stubPlayer(2), stubPlayer(3)
		for _, player in { a, b, c } do
			TeamService:join(player)
		end
		expect(joined).toEqual({ "1", "2", "3" })
		expect(#seated).toBe(2)
		expect(a:GetAttribute(Attributes.Team)).toBe(TeamService:teamOf("1"))
		expect(TeamService:teamOf("1")).never.toBe(TeamService:teamOf("2"))
		expect(c:GetAttribute(Attributes.Team)).toBeNil()
		expect(TeamService:seatedCount()).toBe(2)
	end)

	it("gives a leaving player's seat to a spectator and clears the leaver's team", function()
		local a, b, c = stubPlayer(1), stubPlayer(2), stubPlayer(3)
		for _, player in { a, b, c } do
			TeamService:join(player)
		end
		local aTeam = TeamService:teamOf("1")
		local unseated: { string } = {}
		TeamService.unseated:Connect(function(id: string)
			table.insert(unseated, id)
		end)
		TeamService:leave(a)
		expect(unseated).toEqual({ "1" })
		expect(a:GetAttribute(Attributes.Team)).toBeNil()
		expect(TeamService:teamOf("3")).toBe(aTeam)
		expect(c:GetAttribute(Attributes.Team)).toBe(aTeam)
	end)

	it("reseats everyone for a new match and announces every seat", function()
		local a, b = stubPlayer(1), stubPlayer(2)
		TeamService:join(a)
		TeamService:join(b)
		local seated: { string } = {}
		TeamService.seated:Connect(function(id: string)
			table.insert(seated, id)
		end)
		TeamService:newMatch()
		table.sort(seated)
		expect(seated).toEqual({ "1", "2" })
		expect(a:GetAttribute(Attributes.Team)).toBe(TeamService:teamOf("1"))
	end)

	it("gives each seated player a slot on their team", function()
		TeamService:join(stubPlayer(1))
		local team, slot = TeamService:slotOf("1")
		expect(team).toBe(TeamService:teamOf("1"))
		expect(slot).toBe(1)
		local ghostTeam, ghostSlot = TeamService:slotOf("Ghost")
		expect(ghostTeam).toBeNil()
		expect(ghostSlot).toBeNil()
	end)
end)
