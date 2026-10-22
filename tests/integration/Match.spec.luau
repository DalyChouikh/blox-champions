--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeAll, afterAll, afterEach = JestGlobals.beforeAll, JestGlobals.afterAll, JestGlobals.afterEach

local ArenaService = require(ServerScriptService.Server.ArenaService)
local BallService = require(ServerScriptService.Server.BallService)
local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local CharacterService = require(ServerScriptService.Server.CharacterService)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local MatchService = require(ServerScriptService.Server.MatchService)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local TeamService = require(ServerScriptService.Server.TeamService)
local TaggedLayout = require(ReplicatedStorage.Shared.Arena.TaggedLayout)

type Fired = { name: string, payload: any, to: string? }

local FRAME = 1 / 60
local BASE_MATCH = { lapsToOpenGoal = 1, lapsForStreakPoint = 2 }

local config: Config.GameConfig
local folder: Folder
local fired: { Fired } = {}

local fakeNet = {
	fireAll = function(_self: any, name: string, payload: any)
		table.insert(fired, { name = name, payload = payload })
	end,
	fireTo = function(_self: any, to: string, name: string, payload: any)
		table.insert(fired, { name = name, payload = payload, to = to })
	end,
}

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

beforeAll(function()
	ArenaService:init({ Config = Fixtures.config() })
end)
afterAll(function()
	(ArenaService.model :: Model):Destroy()
end)
afterEach(function()
	BallService:destroy()
	folder:Destroy()
end)

-- The arena ArenaService built in beforeAll.
local function tagged(): TaggedLayout.TaggedArena
	return ArenaService.arena :: TaggedLayout.TaggedArena
end

local function setup(match: { [string]: any }?)
	config = Fixtures.config({ Match = match or BASE_MATCH })
	table.clear(fired)
	folder = Instance.new("Folder")
	folder.Name = "MatchTest"
	folder.Parent = workspace
	BallService:init({ Config = config, ArenaService = ArenaService, Random = Random.new(1) })
	TeamService:init({ Config = config })
	CharacterService:init({ Config = config, ArenaService = ArenaService, TeamService = TeamService })
	MatchService:init({
		Config = config,
		ArenaService = ArenaService,
		NetService = fakeNet,
		BallService = BallService,
		TeamService = TeamService,
		CharacterService = CharacterService,
	})
end

local function frames(seconds: number)
	for _ = 1, math.max(1, math.round(seconds / FRAME)) do
		MatchService:step(FRAME)
	end
end

-- Joins `count` stub players and gives each a rig standing high above the infield.
local function seat(count: number): ({ Model }, { any })
	local rigs: { Model }, players: { any } = {}, {}
	for index = 1, count do
		local player = stubPlayer(index)
		TeamService:join(player)
		local rig = Fixtures.rig(folder, tostring(index), CFrame.new(0, 50 + 5 * index, 0))
		CharacterService:adopt(tostring(index), rig)
		table.insert(rigs, rig)
		table.insert(players, player)
	end
	return rigs, players
end

local function kickoff()
	for _ = 1, 600 do
		MatchService:step(FRAME)
		if BallService.state.status == "Loose" then
			return
		end
	end
	error("the kickoff never ended")
end

local function firedNamed(name: string): { Fired }
	local found: { Fired } = {}
	for _, record in fired do
		if record.name == name then
			table.insert(found, record)
		end
	end
	return found
end

local function lastFired(name: string): Fired
	local found = firedNamed(name)
	return found[#found]
end

local function events(): { string }
	local names: { string } = {}
	for _, batch in firedNamed(Remotes.names.RuleEvents) do
		for _, event in batch.payload do
			table.insert(names, event.name)
		end
	end
	return names
end

local function eventsNamed(name: string): { string }
	local found: { string } = {}
	for _, eventName in events() do
		if eventName == name then
			table.insert(found, eventName)
		end
	end
	return found
end

-- The distance along the centerline of the curved end's apex where the ball spawned.
local function ballDistance(): number
	local section = if BallService.part.Position.X < 0 then 2 else 4
	return Centerline.gateDistance(config.Arena, section) + math.pi * config.Arena.endRadius / 2
end

-- Moves the rig along the middle of the track, one frame every 2 studs.
local function carry(rig: Model, from: number, to: number)
	local count = math.max(1, math.ceil(math.abs(to - from) / 2))
	for index = 0, count do
		rig:PivotTo(Centerline.at(config.Arena, from + (to - from) * index / count, 22, 3))
		MatchService:step(FRAME)
	end
end

local function catchWith(rig: Model)
	rig:PivotTo(CFrame.new(BallService.part.Position))
	MatchService:step(FRAME)
end

-- One seated player catches the ball and carries it one lap, which opens the goal. Returns the rig and where it is.
local function openGoal(): (Model, number)
	local rigs = seat(1)
	kickoff()
	local start = ballDistance()
	carry(rigs[1], start, start)
	local finish = start + Centerline.length(config.Arena) + 2
	carry(rigs[1], start, finish)
	return rigs[1], finish % Centerline.length(config.Arena)
end

-- The ball is moved through the ring's disc front to back in two frames.
local function throughRing(goal: CFrame)
	BallService.part.CFrame = CFrame.new(goal.Position - goal.LookVector * 2)
	MatchService:step(FRAME)
	BallService.part.CFrame = CFrame.new(goal.Position + goal.LookVector * 2)
	MatchService:step(FRAME)
end

-- Opens the goal, carries the ball back to just before the goal gate (crossing gates backwards counts nothing),
-- throws it and sends it through the ring.
local function scoreOnce(): Model
	local rig, at = openGoal()
	carry(rig, at, Centerline.gateDistance(config.Arena, config.Arena.goalGateIndex) - 3)
	local goal = tagged().layout.goal.frame
	BallService:throw("1", goal.LookVector * 60)
	throughRing(goal)
	return rig
end

describe("A match on the generated arena", function()
	it(
		"starts once a player is seated, keeps the ball hidden through the countdown, then drops it at a ball spawn",
		function()
			setup()
			local rigs = seat(1)
			frames(FRAME)
			expect(events()).toEqual({ "MatchStarted", "KickoffStarted" })
			expect(BallService.part.Parent).toBe(ServerStorage)
			expect((rigs[1].PrimaryPart :: BasePart).Anchored).toBe(true)
			frames(config.Match.kickoffCountdownSeconds + 0.05)
			expect(table.find(events(), "KickoffEnded")).never.toBeNil()
			expect(BallService.part.Parent).toBe(workspace)
			expect(BallService.state.status).toBe("Loose")
			expect((rigs[1].PrimaryPart :: BasePart).Anchored).toBe(false)
		end
	)

	it("counts a lap carried around the generated track and opens the goal", function()
		setup()
		openGoal()
		expect(table.find(events(), "PossessionChanged")).never.toBeNil()
		expect(table.find(events(), "LapCompleted")).never.toBeNil()
		expect(table.find(events(), "GoalOpened")).never.toBeNil()
		local panel = tagged().goalPanel
		expect(panel.CanCollide or panel.CanQuery).toBe(false)
		expect(panel.Transparency).toBe(1)
	end)

	it("scores through the open goal, then hides the ball and closes the goal for the next kickoff", function()
		setup()
		scoreOnce()
		expect(table.find(events(), "GoalScored")).never.toBeNil()
		expect(BallService.state.status).toBe("Dead")
		frames(config.Match.celebrationSeconds + 0.05)
		expect(#eventsNamed("KickoffStarted")).toBe(2)
		expect(BallService.part.Parent).toBe(ServerStorage)
		expect(tagged().goalPanel.CanCollide).toBe(true)
	end)

	it("drops the ball where a leaving carrier was, and the team keeps possession", function()
		setup()
		local rigs, players = seat(2)
		kickoff()
		catchWith(rigs[1])
		expect(BallService.state.carrier).toBe("1")
		local team = TeamService:teamOf("1")
		TeamService:leave(players[1])
		frames(FRAME)
		expect(BallService.state.status).toBe("Loose")
		expect(MatchService.engine:snapshot().possessingTeam).toBe(team)
	end)

	it("keeps the ball dead whenever play is not live", function()
		setup()
		local rig = scoreOnce()
		-- Past the thrower's own lockout, but still celebrating.
		frames(config.Ball.rethrowPickupDelay + 0.1)
		rig:PivotTo(CFrame.new(BallService.part.Position))
		frames(FRAME)
		expect(BallService.state.carrier).toBeNil()
		expect(#eventsNamed("PossessionChanged")).toBe(1)
	end)

	it("starts a new match with everyone reseated after the post-match pause", function()
		setup({ lapsToOpenGoal = 1, lapsForStreakPoint = 2, pointsToWin = 1, postMatchSeconds = 2 })
		local first = MatchService.engine
		scoreOnce()
		expect(table.find(events(), "MatchEnded")).never.toBeNil()
		frames(2.05)
		expect(MatchService.engine).never.toBe(first)
		expect(lastFired(Remotes.names.MatchSnapshot).to).toBeNil()
		expect(MatchService.engine:snapshot().state).toBe("Kickoff")
	end)

	it("closes the goal for the next match when a match ends on time with the goal open", function()
		setup({ lapsToOpenGoal = 1, lapsForStreakPoint = 2, durationSeconds = 25, postMatchSeconds = 1 })
		local rig = scoreOnce()
		frames(config.Match.celebrationSeconds + config.Match.kickoffCountdownSeconds + 0.1)
		catchWith(rig)
		local start = ballDistance()
		carry(rig, start, start + Centerline.length(config.Arena) + 2)
		expect(#eventsNamed("GoalOpened")).toBe(2)
		frames(10)
		expect(table.find(events(), "MatchEnded")).never.toBeNil()
		frames(config.Match.postMatchSeconds + 0.05)
		local panel = tagged().goalPanel
		expect(panel.CanCollide and panel.CanQuery).toBe(true)
		expect(panel.Transparency).toBeCloseTo(config.Arena.goal.panelTransparency, 4)
	end)

	it("sends each frame's events as one batch and a snapshot to each player who joins", function()
		setup()
		seat(1)
		frames(FRAME)
		local batches = firedNamed(Remotes.names.RuleEvents)
		expect(#batches).toBe(1)
		expect(#batches[1].payload).toBe(2)
		expect(lastFired(Remotes.names.MatchSnapshot).to).toBe("1")
	end)

	it("tells everyone who carries the ball", function()
		setup()
		local rigs = seat(1)
		kickoff()
		catchWith(rigs[1])
		expect(lastFired(Remotes.names.BallCarrier).payload).toEqual({ carrier = "1" })
		BallService:throw("1", Vector3.new(0, 20, 0))
		frames(FRAME)
		expect(lastFired(Remotes.names.BallCarrier).payload).toEqual({})
	end)

	it("runs a frame for six players in under a millisecond", function()
		setup()
		local rigs = seat(6)
		kickoff()
		catchWith(rigs[1])
		local from = ballDistance()
		local total = 0
		for step = 1, 600 do
			rigs[1]:PivotTo(Centerline.at(config.Arena, from + step * 0.5, 22, 3))
			local started = os.clock()
			MatchService:step(FRAME)
			total += os.clock() - started
		end
		expect(total / 600).toBeLessThan(0.001)
	end)
end)
