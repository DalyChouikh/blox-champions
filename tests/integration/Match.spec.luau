--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect, jest = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.jest
local beforeAll, afterAll, afterEach = JestGlobals.beforeAll, JestGlobals.afterAll, JestGlobals.afterEach

local ActionService = require(ServerScriptService.Server.ActionService)
local ArenaService = require(ServerScriptService.Server.ArenaService)
local BallService = require(ServerScriptService.Server.BallService)
local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local CharacterService = require(ServerScriptService.Server.CharacterService)
local Config = require(ReplicatedStorage.Shared.Config)
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local MatchService = require(ServerScriptService.Server.MatchService)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Schemas = require(ReplicatedStorage.Shared.Net.Schemas)
local TeamService = require(ServerScriptService.Server.TeamService)
local TaggedLayout = require(ReplicatedStorage.Shared.Arena.TaggedLayout)

-- ballAt: where the ball was when the remote fired, to tell events sent before or after the frame's reactions.
type Fired = { name: string, payload: any, to: string?, ballAt: string? }

local FRAME = 1 / 60
-- The middle of the track, where the ball spawns: carried and lined-up rigs skate along it.
local MIDDLE = Config.defaults().Arena.trackWidth / 2

local config: Config.GameConfig
local folder: Folder
local fired: { Fired } = {}
-- Stands in for MovementGuard (its own spec tests it; a real one would return the rigs these tests move by hand):
-- each step it calls `guardStep`, nothing by default.
local guardStep: () -> () = function() end
local fakeGuard = {
	step = function(_self: any, _dt: number)
		guardStep()
	end,
}

-- The name of the ball's model's parent. Assertions compare names: Jest prints a failing Instance with all its
-- descendants, which for the workspace (the whole arena) takes minutes.
local function ballAt(): string?
	local parent = BallService.model.Parent
	return if parent ~= nil then parent.Name else nil
end

-- What each remote's listener does, and the shape and rate limit NetService holds its messages to.
local handlers: { [string]: (player: string, payload: any) -> () } = {}
local limits: { [string]: { schema: any, perSecond: number } } = {}

local fakeNet = {
	listen = function(_self: any, name: string, schema: any, perSecond: number, handler: (string, any) -> ())
		handlers[name] = handler
		limits[name] = { schema = schema, perSecond = perSecond }
	end,
	fireAll = function(_self: any, name: string, payload: any)
		table.insert(fired, { name = name, payload = payload, ballAt = ballAt() })
	end,
	fireTo = function(_self: any, to: string, name: string, payload: any)
		table.insert(fired, { name = name, payload = payload, to = to })
	end,
}

beforeAll(function()
	ArenaService:init({ Config = Fixtures.config() })
end)
afterAll(function()
	(ArenaService.model :: Model):Destroy()
end)
afterEach(function()
	BallService:destroy()
	folder:Destroy()
	guardStep = function() end
end)

-- The arena ArenaService built in beforeAll.
local function tagged(): TaggedLayout.TaggedArena
	return ArenaService.arena :: TaggedLayout.TaggedArena
end

local function setup(match: { [string]: any }?)
	config = Fixtures.config({ Match = match })
	table.clear(fired)
	folder = Instance.new("Folder")
	folder.Name = "MatchTest"
	folder.Parent = workspace
	BallService:init({ Config = config, ArenaService = ArenaService, Random = Random.new(1) })
	TeamService:init({ Config = config })
	CharacterService:init({
		Config = config,
		ArenaService = ArenaService,
		TeamService = TeamService,
		NetService = fakeNet,
	})
	ActionService:init({
		Config = config,
		NetService = fakeNet,
		BallService = BallService,
		TeamService = TeamService,
		CharacterService = CharacterService,
		ArenaService = ArenaService,
	})
	MatchService:init({
		Config = config,
		ArenaService = ArenaService,
		NetService = fakeNet,
		BallService = BallService,
		TeamService = TeamService,
		CharacterService = CharacterService,
		ActionService = ActionService,
		MovementGuard = fakeGuard,
		NameOf = function(player: string): string
			return "Name" .. player
		end,
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
		local player = Fixtures.stubPlayer(index)
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
		for _, event in batch.payload.events do
			table.insert(names, event.name)
		end
	end
	return names
end

-- The fired rule events named `name`, in order.
local function eventsNamed(name: string): { any }
	local found: { any } = {}
	for _, batch in firedNamed(Remotes.names.RuleEvents) do
		for _, event in batch.payload.events do
			if event.name == name then
				table.insert(found, event)
			end
		end
	end
	return found
end

-- How far along the centerline the ball is.
local function ballDistance(): number
	return Centerline.distanceOf(config.Arena, BallService.part.Position)
end

-- Moves the rig along the middle of the track, one frame every 2 studs.
local function carry(rig: Model, from: number, to: number)
	local count = math.max(1, math.ceil(math.abs(to - from) / 2))
	for index = 0, count do
		rig:PivotTo(Centerline.at(config.Arena, from + (to - from) * index / count, MIDDLE, 3))
		MatchService:step(FRAME)
	end
end

-- Puts the ball at `frame` as a jump the server made: a test's shortcut, never a flight, so it crosses no gate, no
-- ring and no face of the arena (#311: a ball that goes through one is put back).
local function jumpBall(frame: CFrame)
	BallService.part.CFrame = frame
	BallService:jumped()
end

-- The ball lands on the middle of the track where it is (#321: it drops in high beside a wall), and `rig` catches it
-- there.
local function catchWith(rig: Model)
	local landing = Centerline.at(config.Arena, ballDistance(), MIDDLE, 3)
	jumpBall(landing)
	rig:PivotTo(landing)
	MatchService:step(FRAME)
end

-- Carries the ball `rig` holds at `start` on to the goal's gate, where every streak starts, then once round to 3 studs
-- before that gate: the lap that opens the goal, ready to shoot. At most two laps.
local function lapFromGoalGate(rig: Model, start: number)
	local length = Centerline.length(config.Arena)
	local goalGate = Centerline.gateDistance(config.Arena, config.Arena.goalGateIndex)
	carry(rig, start, start + (goalGate - start) % length + length - 3)
end

-- Seats `count` players (1 by default); the first catches the ball and opens the goal with a lap from the goal's gate.
-- Returns that rig and every rig.
local function openGoal(count: number?): (Model, { Model })
	local rigs = seat(count or 1)
	kickoff()
	local start = ballDistance()
	catchWith(rigs[1])
	lapFromGoalGate(rigs[1], start)
	return rigs[1], rigs
end

-- The ball is put just in front of the ring, then moves through its disc front to back.
local function throughRing(goal: CFrame)
	jumpBall(CFrame.new(goal.Position - goal.LookVector * 2))
	MatchService:step(FRAME)
	BallService.part.CFrame = CFrame.new(goal.Position + goal.LookVector * 2)
	MatchService:step(FRAME)
end

-- Opens the goal with `count` players seated (1 by default), throws the ball from just before the goal gate and sends
-- it through the ring. Returns the scorer's rig and every rig.
local function scoreOnce(count: number?): (Model, { Model })
	local rig, rigs = openGoal(count)
	local goal = tagged().layout.goal.frame
	BallService:throw("1", goal.LookVector * 60)
	throughRing(goal)
	return rig, rigs
end

-- Stands `attacker` on the track facing the way of travel, `victim` `gap` studs ahead of it, at an arbitrary spot.
-- Returns the attacker's frame.
local function lineUp(attacker: Model, victim: Model, gap: number): CFrame
	local frame = Centerline.at(config.Arena, Centerline.gateDistance(config.Arena, 1) + 10, MIDDLE, 3)
	attacker:PivotTo(frame)
	victim:PivotTo(frame * CFrame.new(0, 0, -gap))
	return frame
end

-- A client's Switch team request from `player`, as NetService hands a valid one over.
local function switchTeam(player: string)
	handlers[Remotes.names.SwitchTeam](player, {})
end

-- The team `player` plays for in a snapshot's score tab.
local function listedTeam(snapshot: any, player: string): string?
	for _, entry in snapshot.match.stats.players do
		if entry.player == player then
			return entry.team
		end
	end
	return nil
end

describe("A match on the generated arena", function()
	-- The owner (Q92): everyone is placed on their spawn, free to skate and act through the count.
	it(
		"starts once a player is seated, free through the count with the ball hidden, then drops it at a ball spawn",
		function()
			setup()
			local rigs = seat(2)
			frames(FRAME)
			expect(events()).toEqual({ "MatchStarted", "KickoffStarted" })
			expect(ballAt()).toBe("ServerStorage")
			expect(Fixtures.root(rigs[1]).Anchored).toBe(false)
			expect(rigs[1]:GetAttribute(Attributes.Placed)).toBe(1)
			lineUp(rigs[1], rigs[2], 4)
			ActionService:request("1", { action = "Tackle" })
			frames(0.2)
			expect(eventsNamed("TackleKnockdown")).toEqual({})
			expect(rigs[2]:GetAttribute(Attributes.KnockedDown)).toBe("Hit")
			frames(config.Match.kickoffCountdownSeconds + 0.05)
			expect(table.find(events(), "KickoffEnded")).never.toBeNil()
			expect(ballAt()).toBe("Workspace")
			expect(BallService.state.status).toBe("Loose")
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
		-- Each client slides the panel out of the ring; the server only lets the ball through.
		expect(panel.Transparency).toBeCloseTo(config.Arena.goal.panelTransparency, 4)
	end)

	it("scores through the open goal, then hides the ball and closes the goal for the next kickoff", function()
		setup()
		scoreOnce()
		expect(table.find(events(), "GoalScored")).never.toBeNil()
		expect(BallService.state.status).toBe("Dead")
		frames(config.Match.celebrationSeconds + 0.05)
		expect(#eventsNamed("KickoffStarted")).toBe(2)
		expect(ballAt()).toBe("ServerStorage")
		expect(tagged().goalPanel.CanCollide).toBe(true)
	end)

	it("reports a body touch to the rules after the pickups", function()
		setup()
		local _, rigs = openGoal(2)
		expect(TeamService:teamOf("2")).never.toBe(TeamService:teamOf("1"))
		local goal = tagged().layout.goal.frame
		-- A knocked-down defender beside the ring's approach: the ball touches them instead of being caught.
		local defender = rigs[2]
		defender:SetAttribute(Attributes.KnockedDown, "Hit")
		local approach = goal.Position - goal.LookVector * 2
		defender:PivotTo(CFrame.new(approach + goal.RightVector * 3))
		BallService:throw("1", goal.LookVector * 60)
		jumpBall(CFrame.new(approach))
		frames(config.Scoring.saveLookaheadSeconds + 0.1)
		expect(eventsNamed("SaveMade")).toEqual({ { name = "SaveMade", player = "2", kind = "Block" } })
		-- The save came from the touch: a knocked-down defender never takes the ball (a catch would also block).
		expect(BallService.state.carrier).never.toBe("2")
	end)

	it("reports a tackle's knockdown to the rules", function()
		setup()
		local rigs = seat(2)
		kickoff()
		lineUp(rigs[1], rigs[2], 4)
		ActionService:request("1", { action = "Tackle" })
		frames(0.2)
		expect(eventsNamed("TackleKnockdown")).toEqual({
			{ name = "TackleKnockdown", attacker = "1", victim = "2" },
		})
	end)

	it("clears actions and knockdowns at the next kickoff", function()
		setup()
		local _, rigs = scoreOnce(2)
		-- A knockdown half a second before the celebration ends would outlast it by a second.
		frames(config.Match.celebrationSeconds - 0.5)
		lineUp(rigs[1], rigs[2], 4)
		ActionService:request("1", { action = "Tackle" })
		frames(0.1)
		expect(rigs[2]:GetAttribute(Attributes.KnockedDown)).toBe("Hit")
		expect(rigs[1]:GetAttribute(Attributes.Action)).toBe("Tackle")
		for _ = 1, 60 do
			if #eventsNamed("KickoffStarted") == 2 then
				break
			end
			MatchService:step(FRAME)
		end
		expect(#eventsNamed("KickoffStarted")).toBe(2)
		expect(rigs[2]:GetAttribute(Attributes.KnockedDown)).toBeNil()
		expect(rigs[1]:GetAttribute(Attributes.Action)).toBeNil()
	end)

	it("knocks the carrier down; the ball keeps their momentum and the tackler takes it", function()
		setup()
		local rigs = seat(2)
		kickoff()
		catchWith(rigs[1])
		-- Behind the carrier halfway between the pickup's reach (radius plus lag tolerance) and the tackle's (range
		-- plus lag tolerance): it hits them but cannot catch.
		local pickupReach = config.Ball.pickupRadius + config.Network.pickupLagToleranceStuds
		local tackle = config.Actions.Tackle.hit :: Config.Hit
		local tackleReach = tackle.range + config.Network.hitLagToleranceStuds
		local frame = lineUp(rigs[2], rigs[1], (pickupReach + tackleReach) / 2)
		local momentum = frame.LookVector * 30
		Fixtures.root(rigs[1]).AssemblyLinearVelocity = momentum
		ActionService:request("2", { action = "Tackle" })
		frames(0.2)
		expect(eventsNamed("TackleKnockdown")).toEqual({
			{ name = "TackleKnockdown", attacker = "2", victim = "1" },
		})
		expect(BallService.state.status).toBe("Loose")
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, momentum)
		-- Beside the knocked-down carrier, the ball stays loose.
		jumpBall(CFrame.new(Fixtures.root(rigs[1]).Position))
		frames(FRAME)
		expect(BallService.state.carrier).toBeNil()
		-- Beside the tackler, it is theirs: a steal.
		jumpBall(CFrame.new(Fixtures.root(rigs[2]).Position))
		frames(FRAME)
		expect(BallService.state.carrier).toBe("2")
		expect(#eventsNamed("Steal")).toBe(1)
		expect(eventsNamed("PossessionChanged")[2].player).toBe("2")
	end)

	it("passes to a teammate who called; the passer cannot take it back at once", function()
		setup()
		local rigs = seat(3)
		kickoff()
		-- Of three players, the third shares a team with one of the first two: that one passes.
		local passerIndex = if TeamService:teamOf("3") == TeamService:teamOf("1") then 1 else 2
		local passer = tostring(passerIndex)
		local passerRig, receiverRig = rigs[passerIndex], rigs[3]
		catchWith(passerRig)
		local frame = lineUp(passerRig, receiverRig, 30)
		-- The opponent waits high above the infield, out of every reach.
		rigs[if passerIndex == 1 then 2 else 1]:PivotTo(CFrame.new(0, 200, 0))
		local possessions = #eventsNamed("PossessionChanged")
		ActionService:request("3", { action = "CallPass" })
		-- Aimed away from the caller: the call decides.
		ActionService:request(passer, { action = "Pass", aim = frame.RightVector })
		expect(BallService.state.status).toBe("Flying")
		-- Beside the passer, inside rethrowPickupDelay: nobody takes it.
		jumpBall(CFrame.new(Fixtures.root(passerRig).Position))
		frames(FRAME)
		expect(BallService.state.carrier).toBeNil()
		-- Beside the caller: theirs, and the team keeps possession, so no steal.
		jumpBall(CFrame.new(Fixtures.root(receiverRig).Position))
		frames(FRAME)
		expect(BallService.state.carrier).toBe("3")
		expect(#eventsNamed("PossessionChanged")).toBe(possessions)
		expect(eventsNamed("Steal")).toEqual({})
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
		setup({ pointsToWin = 1, postMatchSeconds = 2 })
		local first = MatchService.engine
		scoreOnce()
		expect(table.find(events(), "MatchEnded")).never.toBeNil()
		frames(2.05)
		expect(MatchService.engine).never.toBe(first)
		expect(lastFired(Remotes.names.MatchSnapshot).to).toBeNil()
		expect(MatchService.engine:snapshot().state).toBe("Kickoff")
		expect(#MatchService.engine:stats().players).toBe(1)
	end)

	-- The owner (Q95): overtime's 0:00 ends a level match in a draw, which ends it like a win does.
	it("ends a level match in a draw when overtime runs out, then starts the next match", function()
		setup({ durationSeconds = 1, overtimeSeconds = 1, postMatchSeconds = 1 })
		local first = MatchService.engine
		seat(1)
		kickoff()
		frames(2 + FRAME)
		expect(table.find(events(), "OvertimeStarted")).never.toBeNil()
		local ended = eventsNamed("MatchEnded")
		expect(#ended).toBe(1)
		expect(ended[1].winner).toBeNil()
		expect(ended[1].mvp).toBe("1")
		expect(ended[1].stats.players[1].player).toBe("1")
		frames(1.05)
		expect(MatchService.engine).never.toBe(first)
		expect(MatchService.engine:snapshot().state).toBe("Kickoff")
	end)

	-- The guard's placements move carriers and their ball (Phase 9 review): the ball's step must see them that frame.
	it("steps the movement guard each frame after the actions and before the ball", function()
		local actionSteps = jest.spyOn(ActionService, "step")
		local ballSteps = jest.spyOn(BallService, "step")
		local seen: { string } = {}
		guardStep = function()
			table.insert(seen, `{#actionSteps.mock.calls} actions, {#ballSteps.mock.calls} balls`)
		end
		setup()
		seat(1)
		frames(3 * FRAME)
		actionSteps.mockRestore()
		ballSteps.mockRestore()
		expect(seen).toEqual({ "1 actions, 0 balls", "2 actions, 1 balls", "3 actions, 2 balls" })
	end)

	it("sends a frame's events before reacting to them", function()
		setup()
		seat(1)
		kickoff()
		for _, batch in firedNamed(Remotes.names.RuleEvents) do
			for _, event in batch.payload.events do
				if event.name == "KickoffEnded" then
					expect(batch.ballAt).toBe("ServerStorage")
				end
			end
		end
	end)

	it("starts over with a fresh match once every player has left", function()
		setup()
		local rigs, players = seat(1)
		kickoff()
		catchWith(rigs[1])
		local first = MatchService.engine
		TeamService:leave(players[1])
		frames(FRAME)
		expect(MatchService.engine).never.toBe(first)
		expect(MatchService.engine:snapshot().state).toBe("Waiting")
		expect(ballAt()).toBe("ServerStorage")
		expect(BallService.state.carrier).toBeNil()
	end)

	it("tells a player who joins who carries the ball", function()
		setup()
		local rigs = seat(1)
		kickoff()
		catchWith(rigs[1])
		TeamService:join(Fixtures.stubPlayer(2))
		local told = lastFired(Remotes.names.BallCarrier)
		expect(told.to).toBe("2")
		expect(told.payload).toEqual({ carrier = "1" })
	end)

	it("closes the goal for the next match when a match ends on time with the goal open", function()
		-- Time for both goal openings: each carries the ball at most two laps (about 13 s at 2 studs a frame).
		setup({ durationSeconds = 40, postMatchSeconds = 1 })
		local rig = scoreOnce()
		frames(config.Match.celebrationSeconds + config.Match.kickoffCountdownSeconds + 0.1)
		catchWith(rig)
		lapFromGoalGate(rig, ballDistance())
		expect(#eventsNamed("GoalOpened")).toBe(2)
		-- The clock runs out with the goal open.
		frames(MatchService.engine:snapshot().secondsLeft + FRAME)
		expect(table.find(events(), "MatchEnded")).never.toBeNil()
		frames(config.Match.postMatchSeconds + 0.05)
		local panel = tagged().goalPanel
		expect(panel.CanCollide and panel.CanQuery).toBe(true)
		expect(panel.Transparency).toBeCloseTo(config.Arena.goal.panelTransparency, 4)
	end)

	it(
		"sends each frame's events as one batch, then a snapshot to everyone, and one to each player who joins",
		function()
			setup()
			seat(1)
			frames(FRAME)
			local batches = firedNamed(Remotes.names.RuleEvents)
			expect(#batches).toBe(1)
			expect(#batches[1].payload.events).toBe(2)
			local after = fired[(table.find(fired, batches[1]) :: number) + 1]
			expect(after.name).toBe(Remotes.names.MatchSnapshot)
			expect(after.to).toBeNil()
			expect(after.payload.match.state).toBe("Kickoff")
			local toJoiner = false
			for _, snapshot in firedNamed(Remotes.names.MatchSnapshot) do
				toJoiner = toJoiner or snapshot.to == "1"
			end
			expect(toJoiner).toBe(true)
		end
	)

	it(
		"sends a snapshot to everyone whenever a seat changes, naming this match's players, also those who left",
		function()
			setup()
			local _, players = seat(2)
			local function lastToEveryone(): any
				local snapshots = firedNamed(Remotes.names.MatchSnapshot)
				for index = #snapshots, 1, -1 do
					if snapshots[index].to == nil then
						return snapshots[index].payload
					end
				end
				return nil
			end
			expect(#lastToEveryone().match.stats.players).toBe(2)
			local before = #firedNamed(Remotes.names.MatchSnapshot)
			TeamService:leave(players[2])
			expect(#firedNamed(Remotes.names.MatchSnapshot)).toBe(before + 1)
			-- The leaver's row goes at once (#309); their name stays, for the feed.
			local left = lastToEveryone()
			expect(left.names["2"]).toBe("Name2")
			expect(#left.match.stats.players).toBe(1)
		end
	)

	-- The owner (Q104, Q117, Q120, #310).
	it("switches a player into the other team's free seat at once, numbers and all, onto its spawn", function()
		setup()
		local rigs = seat(2)
		local other = TeamService:teamOf("2")
		kickoff()
		local placed = (rigs[1]:GetAttribute(Attributes.Placed) :: number?) or 0
		local snapshots = #firedNamed(Remotes.names.MatchSnapshot)
		local resets = jest.spyOn(ActionService, "resetPlayer")
		switchTeam("1")
		expect(#resets.mock.calls).toBe(1)
		expect(resets.mock.calls[1][2]).toBe("1")
		resets:mockRestore()
		expect(TeamService:teamOf("1")).toBe(other)
		expect(#firedNamed(Remotes.names.MatchSnapshot)).toBe(snapshots + 1)
		expect(listedTeam(lastFired(Remotes.names.MatchSnapshot).payload, "1")).toBe(other)
		-- Standing on the new team's spawn, the slot after its one player's.
		local spawns: any = tagged().teamSpawns
		local spawn = spawns[other][2] * CFrame.new(0, config.Movement.hoverHeight, 0)
		Fixtures.expectNear(Fixtures.root(rigs[1]).Position, spawn.Position)
		expect(rigs[1]:GetAttribute(Attributes.Placed)).toBe(placed + 1)
	end)

	it("takes switch requests in their own shape, within their own rate limit", function()
		setup()
		local limit = limits[Remotes.names.SwitchTeam]
		expect(limit.schema == Schemas.SwitchTeam).toBe(true)
		expect(limit.perSecond).toBe(config.Network.maxTeamSwitchesPerSecond)
	end)

	-- The owner (Q104, Q119): never with the ball, but nothing holds a switch back after a throw.
	it("refuses a switch with the ball, and switches once it is thrown", function()
		setup()
		local rigs = seat(2)
		local team = TeamService:teamOf("1")
		kickoff()
		catchWith(rigs[1])
		switchTeam("1")
		expect(TeamService:teamOf("1")).toBe(team)
		BallService:throw("1", Vector3.new(0, 20, 0))
		frames(FRAME)
		switchTeam("1")
		expect(TeamService:teamOf("1")).never.toBe(team)
	end)

	it("refuses a switch into a full team, and ignores one from a spectator", function()
		setup({ teamSize = 1 })
		seat(3)
		local team = TeamService:teamOf("1")
		switchTeam("1")
		expect(TeamService:teamOf("1")).toBe(team)
		switchTeam("3")
		expect(TeamService:teamOf("3")).toBeNil()
	end)

	-- The owner (Q97): ranked (M7) never offers it.
	it("refuses a switch where the mode has no switching", function()
		setup({ teamSwitching = false })
		seat(2)
		local team = TeamService:teamOf("1")
		switchTeam("1")
		expect(TeamService:teamOf("1")).toBe(team)
	end)

	-- The owner (Q97, #310): the next match keeps everyone's team, even uneven.
	it("keeps everyone's team for the next match, where a switch after the end counts", function()
		setup({ pointsToWin = 1, postMatchSeconds = 2 })
		scoreOnce(2)
		local first = TeamService:teamOf("1")
		local second = TeamService:teamOf("2")
		switchTeam("2")
		expect(TeamService:teamOf("2")).toBe(first)
		-- The ended match's tab keeps the team they played it for.
		expect(listedTeam(lastFired(Remotes.names.MatchSnapshot).payload, "2")).toBe(second)
		frames(2.05)
		local next = lastFired(Remotes.names.MatchSnapshot).payload
		expect(listedTeam(next, "1")).toBe(first)
		expect(listedTeam(next, "2")).toBe(first)
	end)

	it("forgets, when the next match starts, the names of players no longer in the server", function()
		setup({ pointsToWin = 1, postMatchSeconds = 2 })
		local leaver = Fixtures.stubPlayer(9)
		TeamService:join(leaver)
		TeamService:leave(leaver)
		scoreOnce()
		expect(lastFired(Remotes.names.MatchSnapshot).payload.names["9"]).toBe("Name9")
		frames(2.05)
		local names = lastFired(Remotes.names.MatchSnapshot).payload.names
		expect(names["9"]).toBeNil()
		expect(names["1"]).toBe("Name1")
	end)

	it("marks each batch and each snapshot with the server frame it was sent on", function()
		setup()
		seat(1)
		-- Before the first frame: the joiner's snapshot and the seat's.
		expect(lastFired(Remotes.names.MatchSnapshot).payload.frame).toBe(0)
		frames(FRAME)
		expect(lastFired(Remotes.names.RuleEvents).payload.frame).toBe(1)
		expect(lastFired(Remotes.names.MatchSnapshot).payload.frame).toBe(1)
		-- Between frames a snapshot carries the last one's number.
		frames(5 * FRAME)
		TeamService:join(Fixtures.stubPlayer(2))
		expect(lastFired(Remotes.names.MatchSnapshot).payload.frame).toBe(6)
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
		local from = ballDistance()
		local total = 0
		-- A free ball moving along the outside of the track, over the incline (8.5 to 11.5 high there): the catch scan,
		-- the bounds check and the ball's rays (#311) every frame.
		jumpBall(Centerline.at(config.Arena, from, MIDDLE + 18, 16))
		for step = 1, 300 do
			BallService.part.CFrame = Centerline.at(config.Arena, from + step, MIDDLE + 18, 16)
			local started = os.clock()
			MatchService:step(FRAME)
			total += os.clock() - started
		end
		catchWith(rigs[1])
		for step = 1, 300 do
			rigs[1]:PivotTo(Centerline.at(config.Arena, from + step * 0.5, MIDDLE, 3))
			local started = os.clock()
			MatchService:step(FRAME)
			total += os.clock() - started
		end
		expect(total / 600).toBeLessThan(0.001)
	end)
end)
