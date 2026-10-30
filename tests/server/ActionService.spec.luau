--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeAll, afterAll = JestGlobals.beforeAll, JestGlobals.afterAll
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local ActionService = require(ServerScriptService.Server.ActionService)
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local BallService = require(ServerScriptService.Server.BallService)
local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local CharacterService = require(ServerScriptService.Server.CharacterService)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Profile = require(ReplicatedStorage.Shared.Arena.Geometry.Profile)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Schemas = require(ReplicatedStorage.Shared.Net.Schemas)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)
local TeamService = require(ServerScriptService.Server.TeamService)

local defaults = Fixtures.config()
-- Get Up's own tests ask for it sooner than the whole slide (#287), so its rules still show.
local earlyGetUp = Fixtures.config({ Actions = { getUpAfter = 0.5 } })
-- The config every service starts with (beforeEach).
local config = defaults
local throwSettings = config.Actions.ChargeThrow.throw :: Config.ThrowSettings
-- The Tackle's Dive (#240).
local FOLLOW_UP = config.Actions.Tackle.followUp :: Config.FollowUp
local DT = 1 / 60
-- Far from each other and from every test's play, until a test moves them.
local PARKED = Vector3.new(0, 300, 0)
-- On the middle of a straight: a free ball there is in play.
local ON_TRACK = Vector3.new(0, 3, config.Arena.endRadius)
-- High over the track spot: a root there is out of the ground ray's reach (Movement.groundProbeLength).
local AIR = Vector3.new(0, 30, 0)

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

-- The ride surfaces' direction at a point a ray found: the floor slab's own face unless a test gives it a shape
-- (#294).
local smoothNormal: (Vector3, Vector3) -> Vector3 = Fixtures.faceNormal

-- Its model (the test's folder) and its ride surfaces (a floor under the track spot, tagged as the arena's are), set
-- for each test.
local fakeArena = {
	model = nil :: Instance?,
	arena = { teamSpawns = { Blue = {}, Orange = {} }, rideSurfaces = {} :: { Instance } },
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
	smoothNormal = Fixtures.faceNormal
	-- Its top at y 0: a root standing on the track spot is 3 studs above it.
	local floor = Instance.new("Folder")
	floor.Name = "Floor"
	floor:AddTag(Tags.RideSurface)
	local slab = Instance.new("Part")
	slab.Anchored = true
	slab.Size = Vector3.new(400, 1, 400)
	slab.CFrame = CFrame.new(ON_TRACK.X, -0.5, ON_TRACK.Z)
	slab.Parent = floor
	floor.Parent = folder
	fakeArena.model = folder
	fakeArena.arena.rideSurfaces = { floor }
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
		ArenaService = fakeArena,
		SmoothNormal = function(position: Vector3, face: Vector3): Vector3
			return smoothNormal(position, face)
		end,
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

-- Stands the player `offset` from a spot on the track, facing -Z: a server placement, as CharacterService announces
-- one, so no fall.
local function stand(id: string, offset: Vector3)
	rigs[id]:PivotTo(CFrame.new(ON_TRACK + offset))
	CharacterService.placed:Fire(id)
end

-- `id`'s root moving at `speed` along -Z, as their client's physics reports it: a diver's slide (#242).
local function slide(id: string, speed: number)
	Fixtures.root(rigs[id]).AssemblyLinearVelocity = Vector3.new(0, 0, -speed)
end

-- The offset from the track spot that puts a root `drop` studs above where it comes to rest there (hoverHeight over
-- the floor).
local function above(drop: number): Vector3
	return Vector3.new(0, config.Movement.hoverHeight + drop - ON_TRACK.Y, 0)
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

-- Steps a frame where `id` is, then moves them to `offset` from the track spot a frame at a time at the speed ceiling,
-- as the server sees a skater fly, adding the knockdowns of each frame to `listed`. Returns the frames it stepped.
local function glide(id: string, offset: Vector3, listed: { string }?): number
	local target = ON_TRACK + offset
	local stride = config.Movement.hardCap * DT
	local at = Fixtures.root(rigs[id]).Position
	local frames = 0
	while true do
		for _, knockdown in advance(DT) do
			if listed ~= nil then
				table.insert(listed, knockdown)
			end
		end
		frames += 1
		if at == target then
			return frames
		end
		local left = target - at
		at = if left.Magnitude <= stride then target else at + left.Unit * stride
		rigs[id]:PivotTo(CFrame.new(at))
	end
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

-- Roller Champions' tackle key (#240): `id` tackles, then dives as soon as the tackle's follow-up window opens.
local function dive(id: string)
	ActionService:request(id, { action = "Tackle" })
	advance(FOLLOW_UP.from + 0.02)
	ActionService:request(id, { action = "Dive" })
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
		expect(attribute(b, Attributes.KnockedDown)).toBe("Hit")
		expect(attribute(c, Attributes.KnockedDown)).toBeNil()
		expect(attribute(d, Attributes.KnockedDown)).toBeNil()
		-- Down for knockdownSeconds from the strike, early in the active phase.
		advance(0.7)
		expect(attribute(b, Attributes.KnockedDown)).toBe("Hit")
		advance(0.3)
		expect(attribute(b, Attributes.KnockedDown)).toBeNil()
	end)

	-- The owner (#287, Q62): every knockdown lasts the whole slide, keys or not, like RC's (Video 4: a tackled skater
	-- slid 1.5 s and pushed off as the slide stopped; Video 7: posed falls the same).
	it("keeps a struck or fallen skater who moves down for the whole slide", function()
		local a, b = blue[1], orange[1]
		tackled(blue[2], b)
		getUp(b)
		advance(1.4)
		expect(attribute(b, Attributes.KnockedDown)).toBe("Hit")
		advance(0.15)
		expect(attribute(b, Attributes.KnockedDown)).toBeNil()
		stand(a, above(config.Movement.hardLanding.drop + 0.5))
		glide(a, Vector3.zero)
		expect(attribute(a, Attributes.KnockedDown)).toBe("Fall")
		getUp(a)
		advance(1.4)
		expect(attribute(a, Attributes.KnockedDown)).toBe("Fall")
		advance(0.15)
		expect(attribute(a, Attributes.KnockedDown)).toBeNil()
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
		local a = blue[1]
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

		-- The first tackle ended at 0.65 s; its cooldown runs to 1 s.
		advance(0.47)
		ActionService:request(a, { action = "Tackle" })
		expect(rejected(a)).toEqual({ "ChargeThrow", "Tackle" })
		expect(attribute(a, Attributes.Action)).toBeNil()
	end)

	it("accepts an action that arrives up to actionTimingTolerance early, and rejects one earlier", function()
		local a, b = blue[1], orange[1]
		local early = config.Actions.Tackle.cooldown - config.Network.actionTimingTolerance
		stand(a, Vector3.zero)
		stand(b, Vector3.new(50, 0, 0))
		ActionService:request(a, { action = "Tackle" })
		ActionService:request(b, { action = "Tackle" })
		-- Both past the tackle's phases: B asks 0.02 s before the tolerance allows (0.88 s of the 1 s cooldown), A
		-- 0.05 s after (0.95 s).
		advance(early - 0.02)
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
			expect(attribute(pair[1], Attributes.KnockedDown)).toBe("Hit")
			expect(attribute(pair[2], Attributes.KnockedDown)).toBe("Hit")
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

	-- The owner (#240): RC's dive is the Tackle's follow-up, on the ground or in the air.
	it("refuses a dive with no tackle before it, or past the tackle's follow-up window", function()
		local a = blue[1]
		stand(a, Vector3.zero)
		ActionService:request(a, { action = "Dive" })
		expect(rejected(a)).toEqual({ "Dive" })
		ActionService:request(a, { action = "Tackle" })
		advance(FOLLOW_UP.to + config.Network.actionTimingTolerance + 0.05)
		ActionService:request(a, { action = "Dive" })
		expect(rejected(a)).toEqual({ "Dive", "Dive" })
	end)

	it("dives on the ground after a tackle, ending on the belly once the dive's active phase is over", function()
		local a = blue[1]
		stand(a, Vector3.zero)
		slide(a, 30)
		dive(a)
		expect(rejected(a)).toEqual({})
		expect(attribute(a, Attributes.Action)).toBe("Dive")
		local phases = config.Actions.Dive.phases
		advance(phases.windup + phases.active - 0.05)
		expect(attribute(a, Attributes.KnockedDown)).toBeNil()
		advance(0.1)
		expect(attribute(a, Attributes.KnockedDown)).toBe("Dive")
	end)

	-- The server can't tell when a client left the ground (its view lags), so it takes the client's dive (#221).
	it("dives: strikes an opponent within the dive's reach", function()
		local a, b = blue[1], orange[1]
		stand(a, AIR)
		-- Inside a dive's reach (11 + the lag tolerance), outside a tackle's.
		stand(b, AIR + Vector3.new(0, 0, -12))
		dive(a)
		expect(rejected(a)).toEqual({})
		expect(attribute(a, Attributes.Action)).toBe("Dive")
		expect(advance(0.4)).toEqual({ `{a}>{b}` })
	end)

	-- Roller Champions' dive ends on the diver's belly (#221); nothing else starts meanwhile.
	it("knocks a diver down at their first touch of the ground after the dive's active phase", function()
		local a = blue[1]
		local landing = config.Actions.Dive.landing :: Config.Landing
		stand(a, AIR)
		dive(a)
		ActionService:request(a, { action = "Uppercut" })
		expect(rejected(a)).toEqual({ "Uppercut" })
		-- On the floor during the active phase: not yet.
		local phases = config.Actions.Dive.phases
		advance(0.1)
		stand(a, Vector3.zero)
		advance(phases.active / 2)
		expect(attribute(a, Attributes.KnockedDown)).toBeNil()
		-- Still flying once the dive's phases are over: not yet either, and nothing else starts.
		stand(a, AIR)
		advance(phases.windup + phases.active + phases.recovery)
		expect(attribute(a, Attributes.KnockedDown)).toBeNil()
		ActionService:request(a, { action = "Uppercut" })
		expect(rejected(a)).toEqual({ "Uppercut", "Uppercut" })
		-- The touchdown: their own knockdown, which no one scored. Still sliding at the landing's knockdownSeconds,
		-- they are up then (a slope can keep a slide going).
		stand(a, Vector3.zero)
		slide(a, 30)
		expect(advance(DT)).toEqual({})
		expect(attribute(a, Attributes.KnockedDown)).toBe("Dive")
		expect(attribute(a, Attributes.Action)).toBeNil()
		advance(landing.knockdownSeconds - 0.05)
		expect(attribute(a, Attributes.KnockedDown)).toBe("Dive")
		advance(0.1)
		expect(attribute(a, Attributes.KnockedDown)).toBeNil()
		-- Free again.
		ActionService:request(a, { action = "Uppercut" })
		expect(rejected(a)).toEqual({ "Uppercut", "Uppercut" })
	end)

	it("looks for no touchdown under a diver whose character has died", function()
		local a = blue[1]
		stand(a, AIR)
		dive(a)
		stand(a, Vector3.zero)
		local humanoid = rigs[a]:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Health = 0
		expect(advance(1)).toEqual({})
		expect(attribute(a, Attributes.KnockedDown)).toBeNil()
	end)

	-- The owner (#222): a fall of 40 studs or more onto flat ground knocks the skater down like a tackle.
	it("knocks down a skater who lands hard, for hardLanding.knockdownSeconds; no one scores it", function()
		local a = blue[1]
		local hard = config.Movement.hardLanding
		stand(a, above(hard.drop + 0.5))
		giveBall(a)
		local listed: { string } = {}
		glide(a, Vector3.zero, listed)
		expect(listed).toEqual({})
		expect(attribute(a, Attributes.KnockedDown)).toBe("Fall")
		expect(BallService.state.status).toBe("Loose")
		advance(hard.knockdownSeconds - 0.1)
		expect(attribute(a, Attributes.KnockedDown)).toBe("Fall")
		advance(0.2)
		expect(attribute(a, Attributes.KnockedDown)).toBeNil()
		-- From just under the drop: no knockdown.
		stand(a, above(hard.drop - 0.5))
		glide(a, Vector3.zero)
		expect(attribute(a, Attributes.KnockedDown)).toBeNil()
	end)

	-- The owner (#303, Q87): a dive that touches flat ground a hard landing's drop below its top is a hard landing.
	it("knocks a diver who lands hard down as a fall, not as a dive", function()
		local a = blue[1]
		local hard = config.Movement.hardLanding
		local phases = config.Actions.Dive.phases
		stand(a, above(hard.drop + 0.5))
		dive(a)
		-- Past the dive's active phase, when its own touchdown could take the landing.
		advance(phases.windup + phases.active + 0.05)
		expect(attribute(a, Attributes.KnockedDown)).toBeNil()
		glide(a, Vector3.zero)
		expect(attribute(a, Attributes.KnockedDown)).toBe("Fall")
	end)

	-- #294: the server judges a landing by the ground's smooth shape, as the skating rides it: a fall onto ground its
	-- ray finds flat, where the shape is steeper than wallAngle, is no hard landing.
	it("judges a landing by the ground's smooth shape at the point its ray finds", function()
		local a = blue[1]
		local steep = math.rad(config.Movement.wallAngle + 5)
		local asked: { Vector3 } = {}
		smoothNormal = function(position: Vector3, _face: Vector3): Vector3
			table.insert(asked, position)
			return Vector3.new(0, math.cos(steep), math.sin(steep))
		end
		stand(a, above(config.Movement.hardLanding.drop + 5))
		glide(a, Vector3.zero)
		expect(attribute(a, Attributes.KnockedDown)).toBeNil()
		Fixtures.expectNear(asked[#asked], Vector3.new(ON_TRACK.X, 0, ON_TRACK.Z))
	end)

	-- By default the server reads the arena's own shape (SmoothNormals.reader), as the skating does: 5 studs out from
	-- the inner glass a straight's bank is over 40° steep, so a 45-stud fall onto a flat slab there is no hard
	-- landing.
	it("reads the arena's own smooth shape by default", function()
		ActionService:init({
			Config = config,
			NetService = fakeNet,
			BallService = BallService,
			TeamService = TeamService,
			CharacterService = CharacterService,
			ArenaService = fakeArena,
		})
		local arena = config.Arena
		local bank = Centerline.pose(arena, 50, 5, Profile.heightAt(Profile.points(arena, 1), 5) :: number)
		local slab = Instance.new("Part")
		slab.Anchored = true
		slab.Size = Vector3.new(4, 1, 4)
		slab.CFrame = CFrame.new(bank - Vector3.new(0, 0.5, 0))
		slab.Parent = fakeArena.arena.rideSurfaces[1]
		local a = blue[1]
		local rest = bank + Vector3.new(0, config.Movement.hoverHeight, 0) - ON_TRACK
		stand(a, rest + Vector3.new(0, config.Movement.hardLanding.drop + 5, 0))
		glide(a, rest)
		expect(attribute(a, Attributes.KnockedDown)).toBeNil()
	end)

	-- The owner (#245, Q13): touching down still posing is a fall at any height, judged like a hard landing; a pose
	-- let go before the touchdown is none (the client keeps reporting a pose it landed in: SkateController).
	it("knocks down a skater who touches down still posing, from any height; no one scores it", function()
		local a, b = blue[1], blue[2]
		stand(a, above(10))
		rigs[a]:SetAttribute(Attributes.AirPosing, true)
		local listed: { string } = {}
		glide(a, Vector3.zero, listed)
		expect(listed).toEqual({})
		expect(attribute(a, Attributes.KnockedDown)).toBe("Fall")
		stand(b, above(10) + Vector3.new(10, 0, 0))
		rigs[b]:SetAttribute(Attributes.AirPosing, false)
		glide(b, Vector3.new(10, 0, 0))
		expect(attribute(b, Attributes.KnockedDown)).toBeNil()
	end)

	it("adds nothing to a knockdown when the skater lands hard while down", function()
		local b = orange[1]
		local hit = config.Actions.Tackle.hit :: Config.Hit
		tackled(blue[1], b)
		stand(b, above(config.Movement.hardLanding.drop + 5))
		local seconds = glide(b, Vector3.zero) * DT
		expect(attribute(b, Attributes.KnockedDown)).toBe("Hit")
		-- Up at the tackle's knockdownSeconds, as if they never fell.
		advance(hit.knockdownSeconds - seconds + 0.05)
		expect(attribute(b, Attributes.KnockedDown)).toBeNil()
	end)

	it("ends a dive at a kickoff", function()
		local a = blue[1]
		stand(a, AIR)
		dive(a)
		ActionService:reset()
		ActionService:request(a, { action = "Uppercut" })
		expect(rejected(a)).toEqual({})
		-- Its touchdown knocks no one down.
		stand(a, Vector3.zero)
		advance(1)
		expect(attribute(a, Attributes.KnockedDown)).toBeNil()
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
		-- A dive, high in the air: shown through its active phase, not its recovery.
		local active = config.Actions.Dive.phases.active
		stand(b, AIR + Vector3.new(50, 0, 0))
		dive(b)
		advance(active - 0.05)
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

describe("ActionService's front-half hits (#277)", function()
	-- The owner (Q61): passing beside an opponent and striking must reach them.
	it("strikes anyone in its front half within reach, beside too, and never behind", function()
		local a, b, c = blue[1], orange[1], orange[2]
		stand(a, Vector3.zero)
		-- 6 studs away, 85 deg right of the facing; 4 studs behind, nearer.
		stand(b, Vector3.new(6, 0, -0.5))
		stand(c, Vector3.new(0, 0, 4))
		ActionService:request(a, { action = "Tackle" })
		expect(advance(0.7)).toEqual({ `{a}>{b}` })
	end)

	it("dives into anyone in its front half within its reach, beside too", function()
		local a, b = blue[1], orange[1]
		stand(a, AIR)
		-- 10.5 studs away, 85 deg right of the facing: past the Tackle's reach, within the Dive's.
		stand(b, AIR + Vector3.new(10.5, 0, -1))
		dive(a)
		expect(rejected(a)).toEqual({})
		expect(advance(0.4)).toEqual({ `{a}>{b}` })
	end)

	-- The owner's note (RC's Uppercuts at Video 24's 119.6 and 153.8 s): a close Uppercut hits a skater on the ground.
	it("uppercuts a close skater on the ground in its front half as the leap starts", function()
		local a, b = blue[1], orange[1]
		stand(a, Vector3.zero)
		-- 5.1 studs away, level, 79 deg right of the facing.
		stand(b, Vector3.new(5, 0, -1))
		ActionService:request(a, { action = "Uppercut" })
		expect(rejected(a)).toEqual({})
		expect(advance(0.3)).toEqual({ `{a}>{b}` })
	end)
end)

describe("ActionService's Get Up, sooner than the whole slide", function()
	beforeAll(function()
		config = earlyGetUp
	end)
	afterAll(function()
		config = defaults
	end)

	-- Roller Champions' Get Up (#220): moving gets a knocked-down skater up sooner, the server deciding when.
	it("gets a knocked-down skater up once they move, never before getUpAfter", function()
		local b = orange[1]
		-- Moving from their first frame down: down until getUpAfter, then up.
		tackled(blue[1], b)
		getUp(b)
		advance(config.Actions.getUpAfter - 0.05)
		expect(attribute(b, Attributes.KnockedDown)).toBe("Hit")
		advance(0.1)
		expect(attribute(b, Attributes.KnockedDown)).toBeNil()
		-- Moving late in a knockdown: up on the next frame.
		tackled(blue[2], b)
		advance(1)
		expect(attribute(b, Attributes.KnockedDown)).toBe("Hit")
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
		expect(attribute(b, Attributes.KnockedDown)).toBe("Hit")
	end)

	-- The owner (#242): RC's diver is up exactly when the slide stops (Videos 4 and 6), and moving changes nothing.
	it("keeps a sliding diver down whatever the stick, up the frame the slide stops, that knockdown only", function()
		local a = blue[1]
		local landing = config.Actions.Dive.landing :: Config.Landing
		stand(a, Vector3.zero)
		slide(a, 30)
		dive(a)
		local phases = config.Actions.Dive.phases
		advance(phases.windup + phases.active + 0.05)
		expect(attribute(a, Attributes.KnockedDown)).toBe("Dive")
		getUp(a)
		advance(config.Actions.getUpAfter + 0.1)
		expect(attribute(a, Attributes.KnockedDown)).toBe("Dive")
		-- Under stopSpeed along the ground; the hover's pull off the floor is no slide.
		Fixtures.root(rigs[a]).AssemblyLinearVelocity = Vector3.new(0, 5, -(landing.stopSpeed - 0.5))
		advance(DT)
		expect(attribute(a, Attributes.KnockedDown)).toBeNil()
		-- The next knockdown, a strike's, waits for Get Up however still they lie.
		tackled(orange[1], a)
		advance(config.Actions.getUpAfter + 0.1)
		expect(attribute(a, Attributes.KnockedDown)).toBe("Hit")
	end)
end)
