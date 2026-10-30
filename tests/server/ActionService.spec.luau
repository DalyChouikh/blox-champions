--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local ActionService = require(ServerScriptService.Server.ActionService)
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local BallService = require(ServerScriptService.Server.BallService)
local CharacterService = require(ServerScriptService.Server.CharacterService)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Schemas = require(ReplicatedStorage.Shared.Net.Schemas)
local TeamService = require(ServerScriptService.Server.TeamService)

local config = Fixtures.config()
local throwSettings = config.Actions.ChargeThrow.throw :: Config.ThrowSettings
local DT = 1 / 60
local SPAWNS = { CFrame.new(0, 500, 0) }
-- Far from each other and from every test's play, until a test moves them.
local PARKED = Vector3.new(0, 300, 0)
-- On the middle of a straight: a free ball there is in play.
local ON_TRACK = Vector3.new(0, 3, config.Arena.endRadius)

type Sent = { to: string, name: string, payload: any }

-- Records what ActionService listens to and sends.
local fakeNet = {
	handlers = {} :: { [string]: (player: string, payload: any) -> () },
	-- The shape and rate limit NetService would hold each remote's messages to.
	limits = {} :: { [string]: { schema: any, perSecond: number } },
	sent = {} :: { Sent },
	listen = function(self: any, name: string, schema: any, perSecond: number, handler: (string, any) -> ())
		self.handlers[name] = handler
		self.limits[name] = { schema = schema, perSecond = perSecond }
	end,
	fireTo = function(self: any, to: string, name: string, payload: any)
		table.insert(self.sent, { to = to, name = name, payload = payload })
	end,
}

local fakeArena = {
	arena = { ballSpawns = SPAWNS, teamSpawns = { Blue = {}, Orange = {} } },
}

local folder: Folder
local rigs: { [string]: Model } = {}
-- The stub players TeamService seated, by id.
local stubs: { [string]: any } = {}
-- The seated players by team: three each.
local blue: { string } = {}
local orange: { string } = {}

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ActionServiceTest"
	folder.Parent = workspace
	table.clear(fakeNet.handlers)
	table.clear(fakeNet.limits)
	table.clear(fakeNet.sent)
	table.clear(rigs)
	table.clear(stubs)
	blue, orange = {}, {}
	BallService:init({ Config = config, ArenaService = fakeArena })
	TeamService:init({ Config = config })
	CharacterService:init({
		Config = config,
		ArenaService = fakeArena,
		TeamService = TeamService,
		NetService = fakeNet,
	})
	ActionService:init({
		Config = config,
		NetService = fakeNet,
		BallService = BallService,
		TeamService = TeamService,
		CharacterService = CharacterService,
	})
	-- Teams take turns, with a random first pick: sort the six seated players by the team they got.
	for index = 1, 6 do
		local id = tostring(index)
		stubs[id] = Fixtures.stubPlayer(index)
		TeamService:join(stubs[id])
		local rig = Fixtures.rig(folder, id, CFrame.new(PARKED + Vector3.new(index * 50, 0, 0)))
		CharacterService:adopt(id, rig)
		rigs[id] = rig
		table.insert(if TeamService:teamOf(id) == "Blue" then blue else orange, id)
	end
end)
afterEach(function()
	BallService:destroy()
	folder:Destroy()
end)

-- Stands the player `offset` from a spot on the track, facing -Z.
local function stand(id: string, offset: Vector3)
	rigs[id]:PivotTo(CFrame.new(ON_TRACK + offset))
end

local function giveBall(id: string)
	BallService:spawn()
	BallService.part.CFrame = CFrame.new(Fixtures.root(rigs[id]).Position)
	BallService:step(DT, CharacterService:holders())
	assert(BallService.state.carrier == id, `{id} should carry the ball`)
end

local function attribute(id: string, name: string): any
	return rigs[id]:GetAttribute(name)
end

-- Steps for `seconds` in steps of `dt`, collecting every knockdown as "attacker>victim".
local function advance(seconds: number, dt: number?): { string }
	local step = dt or DT
	local knockdowns: { string } = {}
	for _ = 1, math.max(1, math.round(seconds / step)) do
		for _, knockdown in ActionService:step(step) do
			table.insert(knockdowns, `{knockdown.attacker}>{knockdown.victim}`)
		end
	end
	return knockdowns
end

-- `attacker` tackles `victim` from 5 studs behind, stepping until the strike lands: the victim's first frame down.
local function tackled(attacker: string, victim: string)
	stand(attacker, Vector3.zero)
	stand(victim, Vector3.new(0, 0, -5))
	ActionService:request(attacker, { action = "Tackle" })
	for _ = 1, 30 do
		if #advance(DT) > 0 then
			return
		end
	end
	error(`{attacker}'s tackle never reached {victim}`)
end

-- A validated GetUp from `id`, as its client sends one when it moves while knocked down.
local function getUp(id: string)
	fakeNet.handlers[Remotes.names.GetUp](id, {})
end

-- The actions refused to `id`, by name.
local function rejected(id: string): { string }
	local names: { string } = {}
	for _, sent in fakeNet.sent do
		if sent.to == id and sent.name == Remotes.names.ActionRejected then
			table.insert(names, sent.payload.action)
		end
	end
	return names
end

describe("ActionService", function()
	it("throws the carrier's ball at the charged speed along the aim", function()
		local a = blue[1]
		stand(a, Vector3.zero)
		giveBall(a)
		-- Held long enough for a full charge.
		BallService:step(throwSettings.chargeMaxSeconds, CharacterService:holders())
		-- A validated message reaches the request the service listens with.
		fakeNet.handlers[Remotes.names.ActionRequest](
			a,
			{ action = "ChargeThrow", aim = Vector3.new(0, 0, -1), charge = 1 }
		)
		expect(BallService.state.status).toBe("Flying")
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.new(0, 0, -160))
		expect(rejected(a)).toEqual({})
	end)

	it("bounds a throw's charge by how long the thrower has held the ball", function()
		local a = blue[1]
		stand(a, Vector3.zero)
		giveBall(a)
		-- Thrown at once, claiming a full charge: none.
		ActionService:request(a, { action = "ChargeThrow", aim = Vector3.new(0, 0, -1), charge = 1 })
		expect(BallService.part.AssemblyLinearVelocity.Magnitude).toBeCloseTo(throwSettings.minSpeed, 3)
		-- Held for half the charge time, claiming a full charge: half.
		giveBall(a)
		BallService:step(throwSettings.chargeMaxSeconds / 2, CharacterService:holders())
		ActionService:request(a, { action = "ChargeThrow", aim = Vector3.new(0, 0, -1), charge = 1 })
		local half = (throwSettings.minSpeed + throwSettings.maxSpeed) / 2
		expect(BallService.part.AssemblyLinearVelocity.Magnitude).toBeCloseTo(half, 3)
		-- A smaller claim stands.
		giveBall(a)
		BallService:step(throwSettings.chargeMaxSeconds, CharacterService:holders())
		ActionService:request(a, { action = "ChargeThrow", aim = Vector3.new(0, 0, -1), charge = 0 })
		expect(BallService.part.AssemblyLinearVelocity.Magnitude).toBeCloseTo(throwSettings.minSpeed, 3)
	end)

	it("trusts no client velocity beyond what the movement guard allows", function()
		local limit = config.Movement.hardCap * config.Network.speedTolerance
		local a, b = blue[1], orange[1]
		stand(a, Vector3.zero)
		stand(b, Vector3.new(0, 0, -4))
		-- A thrower whose client claims 10000 studs/s keeps only the allowed speed's share.
		giveBall(a)
		BallService:step(throwSettings.chargeMaxSeconds, CharacterService:holders())
		Fixtures.root(rigs[a]).AssemblyLinearVelocity = Vector3.new(0, 0, -10000)
		ActionService:request(a, { action = "ChargeThrow", aim = Vector3.new(0, 0, -1), charge = 1 })
		local thrown = throwSettings.maxSpeed + throwSettings.inheritCarrierVelocity * limit
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.new(0, 0, -thrown))
		-- A knocked-down carrier whose client claims 10000 studs/s drops it at the allowed speed.
		Fixtures.root(rigs[a]).AssemblyLinearVelocity = Vector3.zero
		giveBall(b)
		Fixtures.root(rigs[b]).AssemblyLinearVelocity = Vector3.new(0, 0, 10000)
		ActionService:request(a, { action = "Tackle" })
		expect(advance(0.2)).toEqual({ `{a}>{b}` })
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.new(0, 0, limit))
	end)

	it("passes to the teammate who called", function()
		local a, b = blue[1], blue[2]
		stand(a, Vector3.zero)
		stand(b, Vector3.new(0, 0, -40))
		giveBall(a)
		ActionService:request(b, { action = "CallPass" })
		expect(attribute(b, Attributes.CallingPass)).toBe(true)
		ActionService:request(a, { action = "Pass", aim = Vector3.xAxis })
		local velocity = BallService.part.AssemblyLinearVelocity
		expect(velocity.Magnitude).toBeCloseTo(90, 3)
		Fixtures.expectNear(velocity.Unit, (Fixtures.root(rigs[b]).Position - BallService.part.Position).Unit)
		-- The call ends after its window.
		advance(config.Actions.callPassWindow + 0.1)
		expect(attribute(b, Attributes.CallingPass)).toBeNil()
	end)

	it("knocks down the nearest opponent a tackle reaches, once", function()
		local a, d = blue[1], blue[2]
		local b, c = orange[1], orange[2]
		stand(a, Vector3.zero)
		stand(d, Vector3.new(0, 0, -2))
		stand(b, Vector3.new(0, 0, -5))
		stand(c, Vector3.new(0, 0, -6))
		ActionService:request(a, { action = "Tackle" })
		expect(attribute(a, Attributes.Action)).toBe("Tackle")
		expect(advance(0.7)).toEqual({ `{a}>{b}` })
		expect(attribute(a, Attributes.Action)).toBeNil()
		expect(attribute(b, Attributes.KnockedDown)).toBe(true)
		expect(attribute(c, Attributes.KnockedDown)).toBeNil()
		expect(attribute(d, Attributes.KnockedDown)).toBeNil()
		-- Down for knockdownSeconds from the strike, early in the active phase.
		advance(0.7)
		expect(attribute(b, Attributes.KnockedDown)).toBe(true)
		advance(0.3)
		expect(attribute(b, Attributes.KnockedDown)).toBeNil()
	end)

	-- Roller Champions' Get Up (#220): moving gets a knocked-down skater up sooner, the server deciding when.
	it("gets a knocked-down skater up once they move, never before getUpAfter", function()
		local b = orange[1]
		-- Moving from their first frame down: down until getUpAfter, then up.
		tackled(blue[1], b)
		getUp(b)
		advance(config.Actions.getUpAfter - 0.05)
		expect(attribute(b, Attributes.KnockedDown)).toBe(true)
		advance(0.1)
		expect(attribute(b, Attributes.KnockedDown)).toBeNil()
		-- Moving late in a knockdown: up on the next frame.
		tackled(blue[2], b)
		advance(1)
		expect(attribute(b, Attributes.KnockedDown)).toBe(true)
		getUp(b)
		advance(DT)
		expect(attribute(b, Attributes.KnockedDown)).toBeNil()
	end)

	it("forgets a request to get up made on their feet", function()
		local b = orange[1]
		local hit = config.Actions.Tackle.hit :: Config.Hit
		tackled(blue[1], b)
		advance(hit.knockdownSeconds + 0.05)
		expect(attribute(b, Attributes.KnockedDown)).toBeNil()
		getUp(b)
		tackled(blue[2], b)
		advance(config.Actions.getUpAfter + 0.1)
		expect(attribute(b, Attributes.KnockedDown)).toBe(true)
	end)

	it("takes requests to get up in their own shape, within their own rate limit", function()
		local limits = fakeNet.limits[Remotes.names.GetUp]
		expect(limits.schema == Schemas.GetUp).toBe(true)
		expect(limits.perSecond).toBe(config.Network.maxGetUpsPerSecond)
	end)

	it("drops the ball of a knocked-down carrier with their momentum", function()
		local a, b = blue[1], orange[1]
		stand(a, Vector3.zero)
		stand(b, Vector3.new(0, 0, -4))
		giveBall(b)
		Fixtures.root(rigs[b]).AssemblyLinearVelocity = Vector3.new(0, 0, 30)
		ActionService:request(a, { action = "Tackle" })
		expect(advance(0.2)).toEqual({ `{a}>{b}` })
		expect(BallService.state.status).toBe("Loose")
		Fixtures.expectNear(BallService.part.AssemblyLinearVelocity, Vector3.new(0, 0, 30))
	end)

	it("never reaches a teammate, a knocked-down or a dodging player", function()
		local a, d = blue[1], blue[2]
		local b = orange[1]
		stand(a, Vector3.zero)
		stand(d, Vector3.new(0, 0, -3))
		ActionService:request(a, { action = "Tackle" })
		expect(advance(0.9)).toEqual({})

		-- Knocked down by one tackle, then left alone by the next while still down.
		stand(d, PARKED)
		stand(b, Vector3.new(0, 0, -3))
		ActionService:request(a, { action = "Tackle" })
		expect(advance(0.9)).toEqual({ `{a}>{b}` })
		ActionService:request(a, { action = "Tackle" })
		expect(advance(0.5)).toEqual({})
		expect(rejected(a)).toEqual({})
	end)

	it("never reaches a carrier who dodges as the tackle starts, until the dodge is over", function()
		local a, b = blue[1], orange[1]
		stand(a, Vector3.zero)
		stand(b, Vector3.new(0, 0, -3))
		giveBall(b)
		ActionService:request(a, { action = "Tackle" })
		ActionService:request(b, { action = "Dodge" })
		expect(ActionService:isImmune(b)).toBe(true)
		-- In 0.04 s steps both the dodge (0.3 s) and the tackle's active phase (to 0.3 s) end on the step to 0.32 s.
		expect(advance(0.4, 0.04)).toEqual({})
		expect(ActionService:isImmune(b)).toBe(false)
		advance(0.5)
		ActionService:request(a, { action = "Tackle" })
		expect(advance(0.3)).toEqual({ `{a}>{b}` })
	end)

	it("rejects what the player cannot do now, and tells them", function()
		local a, d = blue[1], blue[2]
		local b, c = orange[1], orange[2]
		stand(a, Vector3.zero)
		stand(b, Vector3.new(0, 0, -3))
		stand(c, Vector3.new(50, 0, 0))
		giveBall(c)

		ActionService:request(a, { action = "ChargeThrow", aim = Vector3.xAxis, charge = 1 })
		expect(rejected(a)).toEqual({ "ChargeThrow" })
		expect(BallService.state.carrier).toBe(c)

		ActionService:request(c, { action = "Tackle" })
		expect(rejected(c)).toEqual({ "Tackle" })
		expect(attribute(c, Attributes.Action)).toBeNil()

		ActionService:request(a, { action = "Tackle" })
		expect(advance(0.2)).toEqual({ `{a}>{b}` })
		ActionService:request(b, { action = "Tackle" })
		expect(rejected(b)).toEqual({ "Tackle" })

		Fixtures.root(rigs[d]).Anchored = true
		ActionService:request(d, { action = "CallPass" })
		expect(rejected(d)).toEqual({ "CallPass" })
		expect(attribute(d, Attributes.CallingPass)).toBeNil()

		-- The first tackle ended at 0.65 s; its cooldown runs to 0.8 s.
		advance(0.47)
		ActionService:request(a, { action = "Tackle" })
		expect(rejected(a)).toEqual({ "ChargeThrow", "Tackle" })
		expect(attribute(a, Attributes.Action)).toBeNil()
	end)

	it("accepts an action that arrives up to actionTimingTolerance early, and rejects one earlier", function()
		local a, b = blue[1], orange[1]
		stand(a, Vector3.zero)
		stand(b, Vector3.new(50, 0, 0))
		ActionService:request(a, { action = "Tackle" })
		ActionService:request(b, { action = "Tackle" })
		-- A: 0.75 s in, 0.05 s of cooldown left. B: 0.68 s in, 0.12 s left (after the tackle's 0.65 s).
		advance(0.68)
		ActionService:request(b, { action = "Tackle" })
		advance(0.07)
		ActionService:request(a, { action = "Tackle" })
		expect(rejected(a)).toEqual({})
		expect(attribute(a, Attributes.Action)).toBe("Tackle")
		expect(rejected(b)).toEqual({ "Tackle" })
	end)

	it("knocks both down when two opponents' strikes land on the same frame", function()
		-- Two head-on pairs, one per team order; in each, the second player's record is the older (they called first).
		local pairs = { { blue[1], orange[1] }, { orange[2], blue[2] } }
		for index, pair in pairs do
			local a, b = pair[1], pair[2]
			ActionService:request(b, { action = "CallPass" })
			local at = ON_TRACK + Vector3.new(index * 40, 0, 0)
			rigs[a]:PivotTo(CFrame.lookAt(at, at - Vector3.zAxis))
			rigs[b]:PivotTo(CFrame.lookAt(at - Vector3.zAxis * 8, at))
		end
		for _, pair in pairs do
			ActionService:request(pair[1], { action = "Tackle" })
			ActionService:request(pair[2], { action = "Tackle" })
		end
		local knockdowns = advance(0.2)
		table.sort(knockdowns)
		local expected: { string } = {}
		for _, pair in pairs do
			table.insert(expected, `{pair[1]}>{pair[2]}`)
			table.insert(expected, `{pair[2]}>{pair[1]}`)
		end
		table.sort(expected)
		expect(knockdowns).toEqual(expected)
		for _, pair in pairs do
			expect(attribute(pair[1], Attributes.KnockedDown)).toBe(true)
			expect(attribute(pair[2], Attributes.KnockedDown)).toBe(true)
		end
	end)

	it("strikes even when one long frame passes through the active phase", function()
		local a, b = blue[1], orange[1]
		stand(a, Vector3.zero)
		stand(b, Vector3.new(0, 0, -5))
		ActionService:request(a, { action = "Tackle" })
		-- From the windup straight into the recovery.
		expect(advance(0.4, 0.4)).toEqual({ `{a}>{b}` })
	end)

	it("rejects a dive that does not follow a tackle", function()
		local a, b = blue[1], orange[1]
		stand(a, Vector3.zero)
		-- Inside a dive's reach (11 + the lag tolerance), outside a tackle's.
		stand(b, Vector3.new(0, 0, -12))
		ActionService:request(a, { action = "Dive" })
		expect(rejected(a)).toEqual({ "Dive" })
		expect(attribute(a, Attributes.Action)).toBeNil()
		expect(advance(0.4)).toEqual({})
	end)

	it("accepts a next action that arrives within actionTimingTolerance of the running one's end", function()
		local a, b = blue[1], orange[1]
		stand(a, Vector3.zero)
		stand(b, Vector3.new(50, 0, 0))
		ActionService:request(a, { action = "Tackle" })
		ActionService:request(b, { action = "Tackle" })
		-- B: 0.5 s in, 0.15 s of its tackle left. A: 0.58 s in, 0.07 s left.
		advance(0.5)
		ActionService:request(b, { action = "Uppercut" })
		advance(0.08)
		ActionService:request(a, { action = "Uppercut" })
		expect(rejected(b)).toEqual({ "Uppercut" })
		expect(rejected(a)).toEqual({})
		expect(attribute(a, Attributes.Action)).toBe("Uppercut")
	end)

	it("shows a running action only until its recovery", function()
		local a, b = blue[1], blue[2]
		stand(a, Vector3.zero)
		stand(b, Vector3.new(50, 0, 0))
		ActionService:request(a, { action = "Tackle" })
		advance(0.1)
		expect(attribute(a, Attributes.Action)).toBe("Tackle")
		-- The tackle recovers from 0.3 s.
		advance(0.3)
		expect(attribute(a, Attributes.Action)).toBeNil()
		-- A dive from a tackle: shown through its active phase (0.35 s), not its recovery.
		ActionService:request(b, { action = "Tackle" })
		advance(0.1)
		ActionService:request(b, { action = "Dive" })
		advance(0.3)
		expect(attribute(b, Attributes.Action)).toBe("Dive")
		advance(0.1)
		expect(attribute(b, Attributes.Action)).toBeNil()
	end)

	it("stops a call once the caller has the ball", function()
		local a = blue[1]
		stand(a, Vector3.zero)
		ActionService:request(a, { action = "CallPass" })
		advance(0.1)
		expect(attribute(a, Attributes.CallingPass)).toBe(true)
		giveBall(a)
		advance(DT)
		expect(attribute(a, Attributes.CallingPass)).toBeNil()
	end)

	it("forgets a player who loses their seat, and starts them clean when seated again", function()
		local a = blue[1]
		stand(a, Vector3.zero)
		ActionService:request(a, { action = "Tackle" })
		advance(0.1)
		TeamService:leave(stubs[a])
		TeamService:join(stubs[a])
		-- Their tackle's cooldown (0.7 s left) went with them.
		ActionService:request(a, { action = "Tackle" })
		expect(rejected(a)).toEqual({})
		expect(attribute(a, Attributes.Action)).toBe("Tackle")
	end)

	it("clears every action, knockdown and call at a kickoff", function()
		local a, d = blue[1], blue[2]
		local b = orange[1]
		stand(a, Vector3.zero)
		stand(b, Vector3.new(0, 0, -3))
		ActionService:request(a, { action = "Tackle" })
		ActionService:request(d, { action = "CallPass" })
		expect(advance(0.1)).toEqual({ `{a}>{b}` })
		expect(attribute(a, Attributes.Action)).toBe("Tackle")
		ActionService:reset()
		for _, id in { a, b, d } do
			expect(attribute(id, Attributes.Action)).toBeNil()
			expect(attribute(id, Attributes.KnockedDown)).toBeNil()
			expect(attribute(id, Attributes.CallingPass)).toBeNil()
		end
		ActionService:request(a, { action = "Tackle" })
		ActionService:request(b, { action = "Uppercut" })
		ActionService:request(d, { action = "CallPass" })
		expect(#fakeNet.sent).toBe(0)
	end)

	it("forgets a player who leaves, and starts a respawned character clean", function()
		local a, b = blue[1], orange[1]
		stand(a, Vector3.zero)
		stand(b, Vector3.new(0, 0, -3))
		ActionService:request(a, { action = "Tackle" })
		expect(advance(0.1)).toEqual({ `{a}>{b}` })
		rigs[b]:Destroy()
		task.wait()
		local respawned = Fixtures.rig(folder, b, CFrame.new(PARKED))
		CharacterService:adopt(b, respawned)
		rigs[b] = respawned
		advance(0.1)
		expect(attribute(b, Attributes.KnockedDown)).toBeNil()
		ActionService:request(b, { action = "Tackle" })
		expect(rejected(b)).toEqual({})
		expect(attribute(b, Attributes.Action)).toBe("Tackle")
	end)

	it("steps six striking players in under 0.2 ms", function()
		-- In a ring facing its center, each one tackling in turn.
		local players: { string } = {}
		for index, id in { blue[1], orange[1], blue[2], orange[2], blue[3], orange[3] } do
			local angle = index * math.pi / 3
			local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 4
			rigs[id]:PivotTo(CFrame.lookAt(position, Vector3.zero))
			table.insert(players, id)
		end
		local total = 0
		for step = 1, 600 do
			ActionService:request(players[step % 6 + 1], { action = "Tackle" })
			local started = os.clock()
			ActionService:step(DT)
			total += os.clock() - started
		end
		expect(total / 600).toBeLessThan(0.0002)
	end)
end)
