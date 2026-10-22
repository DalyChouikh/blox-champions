--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Roster = require(ReplicatedStorage.Shared.Rules.Roster)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

local function blueFirst(): Team.Team
	return "Blue"
end

describe("Roster", function()
	it("seats newcomers on the smaller team until both are full, then makes them spectate", function()
		local roster = Roster.new(3, blueFirst)
		for index = 1, 6 do
			roster:join("P" .. index)
		end
		expect(#roster:members("Blue")).toBe(3)
		expect(#roster:members("Orange")).toBe(3)
		expect(roster:seatedCount()).toBe(6)
		expect(roster:join("P7")).toBeNil()
		expect(roster:seatedCount()).toBe(6)
		expect(roster:teamOf("P7")).toBeNil()
		expect(roster:spectators()).toEqual({ "P7" })
	end)

	it("breaks a tie with the tie-breaker", function()
		local roster = Roster.new(3, function(): Team.Team
			return "Orange"
		end)
		expect(roster:join("A")).toBe("Orange")
		expect(roster:join("B")).toBe("Blue")
	end)

	it("lists each team's players in the order they took their seats", function()
		local roster = Roster.new(2, blueFirst)
		for _, id in { "A", "B", "C", "D" } do
			roster:join(id)
		end
		expect(roster:members("Blue")).toEqual({ "A", "C" })
		expect(roster:members("Orange")).toEqual({ "B", "D" })
	end)

	it("seats a returning player back on their old team", function()
		local roster = Roster.new(2, blueFirst)
		roster:join("A")
		roster:join("B")
		roster:leave("A")
		roster:join("C")
		expect(roster:join("A")).toBe("Blue")
		expect(roster:teamOf("C")).toBe("Blue")
	end)

	it("keeps a returning player off the other team, even when only the other team has room", function()
		local roster = Roster.new(2, blueFirst)
		for _, id in { "A", "B", "C", "D" } do
			roster:join(id)
		end
		roster:leave("A")
		roster:join("E")
		expect(roster:teamOf("E")).toBe("Blue")
		expect(roster:join("A")).toBeNil()
		expect(roster:leave("B")).toEqual({})
		expect(roster:join("F")).toBe("Orange")
	end)

	it("promotes the longest-waiting spectator who may take a freed seat", function()
		local roster = Roster.new(1, blueFirst)
		for _, id in { "A", "B", "C", "D" } do
			roster:join(id)
		end
		expect(roster:leave("A")).toEqual({ { player = "C", team = "Blue" } })
		expect(roster:teamOf("C")).toBe("Blue")
		expect(roster:spectators()).toEqual({ "D" })
	end)

	it("reseats everyone present for a new match and forgets who played where", function()
		local roster = Roster.new(1, blueFirst)
		roster:join("A")
		roster:join("B")
		roster:leave("A")
		expect(roster:newMatch()).toEqual({ { player = "B", team = "Blue" } })
		expect(roster:join("A")).toBe("Orange")
	end)

	it("rejects joining twice and leaving unseen", function()
		local roster = Roster.new(1, blueFirst)
		roster:join("A")
		expect(function()
			roster:join("A")
		end).toThrow('Roster: player "A" already joined')
		expect(function()
			roster:leave("Ghost")
		end).toThrow('Roster: unknown player "Ghost"')
	end)
end)
