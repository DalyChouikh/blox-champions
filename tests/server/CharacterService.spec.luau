--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local CharacterService = require(game:GetService("ServerScriptService").Server.CharacterService)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

local SLOTS: { [string]: { any } } = { A = { "Blue", 2 }, B = { "Orange", 1 }, C = { "Blue", 1 } }

local fakeTeams = {
	slotOf = function(_self: any, id: string): (string?, number?)
		local slot = SLOTS[id]
		if slot ~= nil then
			return slot[1], slot[2]
		end
		return nil, nil
	end,
	teamOf = function(_self: any, id: string): string?
		local slot = SLOTS[id]
		return if slot ~= nil then slot[1] else nil
	end,
}

local fakeArena = {
	arena = {
		teamSpawns = {
			Blue = { CFrame.new(10, 0, -53), CFrame.new(0, 0, -53) },
			Orange = { CFrame.new(-10, 0, 53), CFrame.new(0, 0, 53) },
		},
	},
}

local folder: Folder
beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "CharacterServiceTest"
	folder.Parent = workspace
	CharacterService:init({ Config = Fixtures.config(), ArenaService = fakeArena, TeamService = fakeTeams })
end)
afterEach(function()
	folder:Destroy()
end)

local function near(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude).toBeLessThan(1e-3)
end

describe("CharacterService", function()
	it("stands a character on its slot's team spawn, root at standing height, R15 and R6 alike", function()
		local r15 = Fixtures.rig(folder, "A", CFrame.new(0, 50, 0))
		local r6 = Fixtures.rig(folder, "B", CFrame.new(0, 50, 0), Enum.HumanoidRigType.R6)
		CharacterService:adopt("A", r15)
		CharacterService:adopt("B", r6)
		CharacterService:place("A", false)
		CharacterService:place("B", false)
		near((r15.PrimaryPart :: BasePart).Position, Vector3.new(0, 3, -53))
		near((r6.PrimaryPart :: BasePart).Position, Vector3.new(-10, 3, 53))
		expect(CharacterService.standingHeight(r6)).toBe(3)
	end)

	it("freezes characters for the kickoff countdown and frees them after", function()
		local rig = Fixtures.rig(folder, "A", CFrame.new(0, 50, 0))
		CharacterService:adopt("A", rig)
		CharacterService:placeAll(true)
		expect((rig.PrimaryPart :: BasePart).Anchored).toBe(true)
		CharacterService:freezeAll(false)
		expect((rig.PrimaryPart :: BasePart).Anchored).toBe(false)
	end)

	it("lists living characters that can hold the ball, with their hand", function()
		local r15 = Fixtures.rig(folder, "A", CFrame.new(0, 3, 0))
		local r6 = Fixtures.rig(folder, "B", CFrame.new(5, 3, 0), Enum.HumanoidRigType.R6)
		local dead = Fixtures.rig(folder, "C", CFrame.new(10, 3, 0))
		local deadHumanoid = dead:FindFirstChildOfClass("Humanoid") :: Humanoid
		deadHumanoid.Health = 0
		CharacterService:adopt("A", r15)
		CharacterService:adopt("B", r6)
		CharacterService:adopt("C", dead)
		local hands: { [string]: string } = {}
		for _, holder in CharacterService:holders() do
			hands[holder.player] = holder.hand.Name
		end
		expect(hands).toEqual({ A = "RightHand", B = "Right Arm" })
	end)

	it("lists only seated players, so nobody the match does not count can catch the ball", function()
		CharacterService:adopt("A", Fixtures.rig(folder, "A", CFrame.new(0, 3, 0)))
		CharacterService:adopt("Z", Fixtures.rig(folder, "Z", CFrame.new(5, 3, 0)))
		local players: { string } = {}
		for _, holder in CharacterService:holders() do
			table.insert(players, holder.player)
		end
		expect(players).toEqual({ "A" })
	end)

	it("announces a character that goes away and stops listing it", function()
		local rig = Fixtures.rig(folder, "A", CFrame.new(0, 3, 0))
		CharacterService:adopt("A", rig)
		local removed: { string } = {}
		CharacterService.characterRemoved:Connect(function(id: string)
			table.insert(removed, id)
		end)
		rig:Destroy()
		task.wait() -- Destroying is deferred
		expect(removed).toEqual({ "A" })
		expect(#CharacterService:holders()).toBe(0)
	end)
end)
