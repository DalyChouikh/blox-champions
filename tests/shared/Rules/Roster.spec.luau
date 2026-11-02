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

	-- The owner (Q97, #310): the next match keeps everyone's team, even uneven: no auto-balance.
	it("keeps everyone's team for a new match, in seat order, even when the teams are uneven", function()
		local roster = Roster.new(3, blueFirst)
		for _, id in { "A", "B", "C" } do
			roster:join(id)
		end
		roster:switch("C")
		expect(roster:newMatch()).toEqual({
			{ player = "A", team = "Blue" },
			{ player = "B", team = "Orange" },
			{ player = "C", team = "Orange" },
		})
		expect(roster:members("Orange")).toEqual({ "B", "C" })
	end)

	it("forgets who left the last match, and seats its spectators as newcomers", function()
		local roster = Roster.new(2, blueFirst)
		for _, id in { "A", "B", "C" } do
			roster:join(id)
		end
		-- A played for Blue, where D takes their seat; back, A waits for Blue although Orange has room.
		roster:leave("A")
		roster:join("D")
		roster:join("A")
		expect(roster:members("Blue")).toEqual({ "C", "D" })
		expect(roster:spectators()).toEqual({ "A" })
		-- A new match forgets that: A is a newcomer, who takes the smaller team.
		expect(roster:newMatch()).toEqual({
			{ player = "B", team = "Orange" },
			{ player = "C", team = "Blue" },
			{ player = "D", team = "Blue" },
			{ player = "A", team = "Orange" },
		})
		expect(roster:spectators()).toEqual({})
	end)

	-- The owner (Q104, #310): a switch takes the other team's free seat, at the end of its seat order.
	it("moves a switching player to the other team's last seat, and counts each team's seats", function()
		local roster = Roster.new(2, blueFirst)
		for _, id in { "A", "B", "C" } do
			roster:join(id)
		end
		expect(roster:seatedOn("Blue")).toBe(2)
		expect(roster:seatedOn("Orange")).toBe(1)
		expect(roster:switch("A")).toEqual({})
		expect(roster:teamOf("A")).toBe("Orange")
		expect(roster:members("Orange")).toEqual({ "B", "A" })
		expect(roster:members("Blue")).toEqual({ "C" })
		expect(roster:seatedOn("Orange")).toBe(2)
		expect(roster:seatedCount()).toBe(3)
		-- Back after leaving, they play for the team they switched to.
		roster:leave("A")
		expect(roster:join("A")).toBe("Orange")
	end)

	it("gives the seat a switch frees to the longest-waiting spectator who may take it", function()
		local roster = Roster.new(2, blueFirst)
		for _, id in { "A", "B", "C", "D" } do
			roster:join(id)
		end
		-- A played for Blue, whose seat E takes; back, A waits for Blue, as Orange has room only after D leaves.
		roster:leave("A")
		roster:join("E")
		roster:join("A")
		roster:leave("D")
		expect(roster:spectators()).toEqual({ "A" })
		expect(roster:switch("C")).toEqual({ { player = "A", team = "Blue" } })
		expect(roster:spectators()).toEqual({})
		expect(roster:members("Blue")).toEqual({ "E", "A" })
	end)

	it("rejects a switch into a full team, by a spectator or by a player it never seated", function()
		local roster = Roster.new(1, blueFirst)
		for _, id in { "A", "B", "C" } do
			roster:join(id)
		end
		expect(function()
			roster:switch("A")
		end).toThrow('Roster: Orange has no free seat for "A"')
		expect(function()
			roster:switch("C")
		end).toThrow('Roster: player "C" has no seat to switch from')
		expect(function()
			roster:switch("Ghost")
		end).toThrow('Roster: player "Ghost" has no seat to switch from')
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
