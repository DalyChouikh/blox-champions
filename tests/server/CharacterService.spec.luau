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

describe("CharacterService", function()
	it("stands a character on its slot's team spawn, root at standing height, R15 and R6 alike", function()
		local r15 = Fixtures.rig(folder, "A", CFrame.new(0, 50, 0))
		local r6 = Fixtures.rig(folder, "B", CFrame.new(0, 50, 0), Enum.HumanoidRigType.R6)
		CharacterService:adopt("A", r15)
		CharacterService:adopt("B", r6)
		CharacterService:place("A", false)
		CharacterService:place("B", false)
		Fixtures.expectNear((r15.PrimaryPart :: BasePart).Position, Vector3.new(0, 3, -53))
		Fixtures.expectNear((r6.PrimaryPart :: BasePart).Position, Vector3.new(-10, 3, 53))
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

	it("lists living characters that can hold the ball, with their root", function()
		local r15 = Fixtures.rig(folder, "A", CFrame.new(0, 3, 0))
		local r6 = Fixtures.rig(folder, "B", CFrame.new(5, 3, 0), Enum.HumanoidRigType.R6)
		local dead = Fixtures.rig(folder, "C", CFrame.new(10, 3, 0))
		local deadHumanoid = dead:FindFirstChildOfClass("Humanoid") :: Humanoid
		deadHumanoid.Health = 0
		CharacterService:adopt("A", r15)
		CharacterService:adopt("B", r6)
		CharacterService:adopt("C", dead)
		local roots: { [string]: string } = {}
		for _, holder in CharacterService:holders() do
			roots[holder.player] = holder.root.Name
		end
		expect(roots).toEqual({ A = "HumanoidRootPart", B = "HumanoidRootPart" })
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

	it("never makes whoever seats a player wait for the character to load", function()
		local loads = 0
		CharacterService:init({
			Config = Fixtures.config(),
			ArenaService = fakeArena,
			TeamService = fakeTeams,
			LoadCharacter = function(_id: string)
				task.wait(0.1)
				loads += 1
			end,
		})
		local returned = false
		local caller = coroutine.create(function()
			CharacterService:requestLoad("A")
			returned = true
		end)
		coroutine.resume(caller)
		expect(returned).toBe(true)
		task.wait(0.2)
		expect(loads).toBe(1)
	end)

	it("loads a character once, and only for a player who has none", function()
		local loads: { string } = {}
		CharacterService:init({
			Config = Fixtures.config(),
			ArenaService = fakeArena,
			TeamService = fakeTeams,
			LoadCharacter = function(id: string)
				table.insert(loads, id)
				task.wait(0.05)
			end,
		})
		CharacterService:adopt("A", Fixtures.rig(folder, "A", CFrame.new(0, 3, 0)))
		CharacterService:requestLoad("A")
		CharacterService:requestLoad("B")
		CharacterService:requestLoad("B")
		task.wait(0.1)
		expect(loads).toEqual({ "B" })
	end)

	it("stands a character that loads during the kickoff countdown on its spawn, frozen", function()
		CharacterService:init({
			Config = Fixtures.config(),
			ArenaService = fakeArena,
			TeamService = fakeTeams,
			-- Like Player:LoadCharacterAsync: the character exists when it returns, but Roblox announces it
			-- (CharacterAdded, deferred) only later.
			LoadCharacter = function(id: string): Model
				return Fixtures.rig(folder, id, CFrame.new(0, 50, 0))
			end,
		})
		CharacterService:placeAll(true)
		CharacterService:requestLoad("A")
		task.wait()
		local rigA = folder:FindFirstChild("A") :: Model
		Fixtures.expectNear((rigA.PrimaryPart :: BasePart).Position, Vector3.new(0, 3, -53))
		expect((rigA.PrimaryPart :: BasePart).Anchored).toBe(true)
		CharacterService:freezeAll(false)
		CharacterService:requestLoad("B")
		task.wait()
		expect(((folder:FindFirstChild("B") :: Model).PrimaryPart :: BasePart).Anchored).toBe(false)
	end)

	it("skips a character missing its Humanoid or root when placing everyone", function()
		local broken = Instance.new("Model")
		broken.Name = "Broken"
		local torso = Instance.new("Part")
		torso.Parent = broken
		broken.Parent = folder
		CharacterService:adopt("A", broken)
		expect(function()
			CharacterService:placeAll(true)
		end).never.toThrow()
		expect(#CharacterService:holders()).toBe(0)
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

	-- Humanoid.Died never fires in Edit, so these call what it runs.
	it("announces a character that dies, so a carrier's ball drops", function()
		local rig = Fixtures.rig(folder, "A", CFrame.new(0, 3, 0))
		CharacterService:adopt("A", rig)
		local removed: { string } = {}
		CharacterService.characterRemoved:Connect(function(id: string)
			table.insert(removed, id)
		end)
		CharacterService:onDied("A", rig)
		expect(removed).toEqual({ "A" })
	end)

	it("loads a dead character again after respawnSeconds, only while its player is seated", function()
		local loads: { string } = {}
		CharacterService:init({
			Config = Fixtures.config({ Match = { respawnSeconds = 0.2 } }),
			ArenaService = fakeArena,
			TeamService = fakeTeams,
			LoadCharacter = function(id: string): Model?
				table.insert(loads, id)
				return nil
			end,
		})
		local seated = Fixtures.rig(folder, "A", CFrame.new(0, 3, 0))
		local unseated = Fixtures.rig(folder, "Z", CFrame.new(5, 3, 0))
		CharacterService:adopt("A", seated)
		CharacterService:adopt("Z", unseated)
		CharacterService:onDied("A", seated)
		CharacterService:onDied("Z", unseated)
		task.wait()
		expect(loads).toEqual({})
		task.wait(0.3)
		expect(loads).toEqual({ "A" })
	end)

	it(
		"waits the full respawnSeconds after the latest death, even if an earlier character's wait is still running",
		function()
			local loads: { string } = {}
			CharacterService:init({
				Config = Fixtures.config({ Match = { respawnSeconds = 0.4 } }),
				ArenaService = fakeArena,
				TeamService = fakeTeams,
				LoadCharacter = function(id: string): Model?
					table.insert(loads, id)
					return nil
				end,
			})
			local first = Fixtures.rig(folder, "A1", CFrame.new(0, 3, 0))
			CharacterService:adopt("A", first)
			CharacterService:onDied("A", first)
			task.wait(0.2)
			-- A new match gave the player a new character, which dies too.
			local second = Fixtures.rig(folder, "A2", CFrame.new(0, 3, 0))
			CharacterService:adopt("A", second)
			CharacterService:onDied("A", second)
			task.wait(0.3)
			expect(loads).toEqual({})
			task.wait(0.2)
			expect(loads).toEqual({ "A" })
		end
	)
end)
