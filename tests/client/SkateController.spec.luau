--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local InputController = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.InputController)
local RideSurfaces = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.RideSurfaces)
local SkateController = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.SkateController)
local SkaterBody = require(ServerScriptService.Server.SkaterBody)
local SkateMath = require(ReplicatedStorage.Shared.Skate.SkateMath)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local config = Config.defaults()
local movement = config.Movement
-- Looking toward -Z, so the stick's forward is -Z.
local CAMERA = { CFrame = CFrame.lookAt(Vector3.new(0, 5, 10), Vector3.new(0, 5, 0)) }

local folder: Folder
-- Roblox's menu: opening it pauses the controls.
local menu: Fixtures.Menu
local floor: Folder
local rig: Model
local sent: { { boolean } }
-- How many times the client asked the server to get the skater up.
local getUps: number
local others: { any }

local function velocityOf(model: Model): Vector3
	return (Fixtures.root(model):FindFirstChild(SkaterRig.velocity) :: LinearVelocity).VectorVelocity
end

local function alignOf(model: Model): AlignOrientation
	return Fixtures.root(model):FindFirstChild(SkaterRig.align) :: AlignOrientation
end

-- A rig with its skater body, its root at hoverHeight above `ground`.
local function skaterAt(name: string, ground: Vector3): Model
	local model = Fixtures.rig(folder, name, CFrame.new(ground + Vector3.new(0, movement.hoverHeight, 0)))
	SkaterBody.build(model, movement)
	return model
end

-- A sphere cast's normal is off by up to about 1.5e-5 (measured), so a velocity of 120 studs/s it blocks keeps up to
-- about 0.002 studs/s into the surface.
local CAST_TOLERANCE = 0.01

-- Another ride surface beside the floor: a slab in the floor's folder.
local function addSlab(cframe: CFrame, size: Vector3)
	local slab = Instance.new("Part")
	slab.Anchored = true
	slab.Size = size
	slab.CFrame = cframe
	slab.Parent = floor
end

-- Puts the skater in the air at `position`, flying at `velocity`.
local function flying(position: Vector3, velocity: Vector3)
	rig:PivotTo(CFrame.new(position))
	local skater = SkateController.skater :: any
	skater.mode = "Airborne"
	skater.velocity = velocity
end

local function setup(overrides: { [string]: any }?)
	RideSurfaces:init({})
	local deps: { [string]: any } = {
		Config = config,
		InputController = InputController,
		RideSurfaces = RideSurfaces,
		Camera = CAMERA,
		Skaters = function(): { any }
			return others
		end,
		SendSkateState = function(pump: boolean, brake: boolean, airPose: boolean)
			table.insert(sent, { pump, brake, airPose })
		end,
		SendGetUp = function()
			getUps += 1
		end,
		Gravity = Fixtures.GRAVITY,
		Team = function(): string?
			return "Blue"
		end,
	}
	local extra: { [string]: any } = overrides or {}
	for key, value in extra do
		deps[key] = value
	end
	SkateController:init(deps)
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "SkateControllerTest"
	folder.Parent = workspace
	-- Only the floor is a ride surface: the skater's own parts must never be.
	floor = Instance.new("Folder")
	floor.Name = "Floor"
	local slab = Instance.new("Part")
	slab.Anchored = true
	slab.Size = Vector3.new(400, 1, 400)
	slab.CFrame = CFrame.new(0, -0.5, 0)
	slab.Parent = floor
	floor.Parent = folder
	floor:AddTag(Tags.RideSurface)
	sent = {}
	getUps = 0
	others = {}
	menu = Fixtures.menu()
	InputController:init({ Config = config, Parent = folder, GuiService = menu })
	rig = skaterAt("Skater", Vector3.zero)
	setup()
	SkateController:bind(rig)
end)
afterEach(function()
	InputController:destroy()
	folder:Destroy()
end)

describe("SkateController", function()
	it("takes over a character and drives its skater body from the stick", function()
		expect((rig:FindFirstChildOfClass("Humanoid") :: Humanoid).EvaluateStateMachine).toBe(false)
		Fixtures.scriptedBinding(InputController.context, "Move"):Fire(Vector2.new(0, 1))
		SkateController:step(0.1)
		Fixtures.expectNear(velocityOf(rig), Vector3.new(0, 0, -2.594)) -- SkateMath's first push, at hover height
		Fixtures.expectNear(alignOf(rig).SecondaryAxis, Vector3.yAxis)
		Fixtures.expectNear(alignOf(rig).PrimaryAxis, Vector3.xAxis)
	end)

	-- A player who joins a running match is placed unfrozen, and the arena can reach their client after their
	-- character: with no floor below, the skater fell far under the arena and stayed there (#177).
	it("holds still until the arena reaches this client, then skates", function()
		floor:RemoveTag(Tags.RideSurface)
		RideSurfaces:refresh()
		Fixtures.scriptedBinding(InputController.context, "Move"):Fire(Vector2.new(0, 1))
		SkateController:step(0.1)
		expect(SkateController.frozen).toBe(true)
		Fixtures.expectNear(velocityOf(rig), Vector3.zero)

		floor:AddTag(Tags.RideSurface)
		RideSurfaces:refresh()
		SkateController:step(0.1)
		expect(SkateController.frozen).toBe(false)
		Fixtures.expectNear(velocityOf(rig), Vector3.new(0, 0, -2.594))
	end)

	it("holds still while the root is anchored, then starts from rest", function()
		Fixtures.scriptedBinding(InputController.context, "Move"):Fire(Vector2.new(0, 1))
		for _ = 1, 10 do
			SkateController:step(0.1)
		end
		Fixtures.root(rig).Anchored = true
		SkateController:step(0.1)
		Fixtures.expectNear((SkateController.skater :: any).velocity, Vector3.zero)
		Fixtures.root(rig).Anchored = false
		SkateController:step(0.1)
		Fixtures.expectNear(velocityOf(rig), Vector3.new(0, 0, -2.594))
	end)

	-- The kickoff freeze anchors every root while the server places them (spec §4.5). Nothing held or pressed during
	-- it may carry into the kickoff.
	it(
		"starts the kickoff from rest, upright, facing its spawn, whatever was held or pressed during the freeze",
		function()
			local leader = skaterAt("Leader", Vector3.new(0, 0, -5))
			table.insert(others, { player = "2", team = "Blue", root = Fixtures.root(leader) })
			local attachKey = Fixtures.scriptedBinding(InputController.context, "Attach")
			attachKey:Fire(true)
			SkateController:step(1 / 60)
			local skater = SkateController.skater :: any
			expect(skater.mode).toBe("Attached")
			-- Riding a wall when the point is scored.
			skater.up = Vector3.xAxis

			Fixtures.root(rig).Anchored = true
			local spawn = Vector3.new(0, movement.hoverHeight, 0)
			rig:PivotTo(CFrame.lookAt(spawn, spawn + Vector3.xAxis))
			attachKey:Fire(false)
			local jumpKey = Fixtures.scriptedBinding(InputController.context, "Jump")
			jumpKey:Fire(true)
			task.wait()
			jumpKey:Fire(false)
			for _ = 1, 3 do
				SkateController:step(1 / 60)
			end

			Fixtures.root(rig).Anchored = false
			SkateController:step(1 / 60)
			expect(skater.mode).toBe("Grounded")
			expect(velocityOf(rig).Magnitude).toBeLessThan(1)
			Fixtures.expectNear(alignOf(rig).SecondaryAxis, Vector3.yAxis)
			-- Facing +X, so the skater's right is +Z.
			Fixtures.expectNear(alignOf(rig).PrimaryAxis, Vector3.zAxis)
		end
	)

	it("locks a knocked-down skater's input and lets go of the attach", function()
		local skater = SkateController.skater :: any
		skater.velocity = Vector3.new(0, 0, -60)
		local stick = Fixtures.scriptedBinding(InputController.context, "Move")
		stick:Fire(Vector2.new(1, 0))
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		SkateController:step(0.1)
		expect(SkateController.knockedDown).toBe(true)
		-- No steering: 60 − (4 + 0.02 × 60) × 0.1 − knockdownDecel 75 × 0.1, still along -Z.
		Fixtures.expectNear(velocityOf(rig), Vector3.new(0, 0, -51.98))

		stick:Fire(Vector2.zero)
		rig:SetAttribute(Attributes.KnockedDown, nil)
		local leader = skaterAt("Leader", Vector3.new(0, 0, -5))
		table.insert(others, { player = "2", team = "Blue", root = Fixtures.root(leader) })
		local attachKey = Fixtures.scriptedBinding(InputController.context, "Attach")
		attachKey:Fire(true)
		SkateController:step(1 / 60)
		expect(skater.mode).toBe("Attached")
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		SkateController:step(1 / 60)
		SkateController:step(1 / 60)
		expect(skater.mode).never.toBe("Attached")
		-- Let go while down: the attach ended with the knockdown, so no release boost comes once it is over.
		attachKey:Fire(false)
		rig:SetAttribute(Attributes.KnockedDown, nil)
		SkateController:step(1 / 60)
		expect(velocityOf(rig).Magnitude).toBeLessThan(movement.attachBoostSpeed)
	end)

	-- Roller Champions' Get Up (#220): the server decides when the skater is up (ActionService).
	it("asks the server to get up once per knockdown, as soon as the knocked-down skater moves", function()
		local stick = Fixtures.scriptedBinding(InputController.context, "Move")
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		SkateController:step(1 / 60)
		expect(getUps).toBe(0)
		stick:Fire(Vector2.new(0, 1))
		for _ = 1, 3 do
			SkateController:step(1 / 60)
		end
		expect(getUps).toBe(1)
		-- Up and moving: nothing more. Down again with the stick still held: it asks at once.
		rig:SetAttribute(Attributes.KnockedDown, nil)
		SkateController:step(1 / 60)
		expect(getUps).toBe(1)
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		SkateController:step(1 / 60)
		expect(getUps).toBe(2)
		expect(SkateController.promptsGetUp).toBe(true)
		-- A hard landing's knockdown too.
		rig:SetAttribute(Attributes.KnockedDown, nil)
		SkateController:step(1 / 60)
		rig:SetAttribute(Attributes.KnockedDown, "Fall")
		SkateController:step(1 / 60)
		expect(getUps).toBe(3)
	end)

	-- The owner (#242): a diver is up when the slide stops, so moving asks nothing (ActionService decides).
	it("never asks to get up from a dive's own knockdown", function()
		local stick = Fixtures.scriptedBinding(InputController.context, "Move")
		stick:Fire(Vector2.new(0, 1))
		rig:SetAttribute(Attributes.KnockedDown, "Dive")
		for _ = 1, 3 do
			SkateController:step(1 / 60)
		end
		expect(SkateController.knockedDown).toBe(true)
		expect(SkateController.knockdown).toBe("Dive")
		expect(SkateController.promptsGetUp).toBe(false)
		expect(getUps).toBe(0)
	end)

	-- A dive ends on the belly (#221): the diver does nothing more. The owner (#242): until the server's knockdown at
	-- the touchdown they glide, slowed only by friction and drag (RC's dive glides ~0.3 s at ~70 km/h, Video 6).
	it("locks a diver's input and glides them until the server's knockdown ends the dive", function()
		local skater = SkateController.skater :: any
		SkateController.diving = true
		-- In the air the jump strikes no Air Pose.
		flying(Vector3.new(0, 20, 0), Vector3.new(0, 0, -30))
		Fixtures.scriptedBinding(InputController.context, "Jump"):Fire(true)
		task.wait() -- the press arrives with the deferred events
		SkateController:step(1 / 60)
		expect(skater.airPosing).toBe(false)
		-- On the ground, no steering, and a glide: 60 − (4 + 0.02 × 60) × 0.1, no coasting or knockdown slowing.
		rig:PivotTo(CFrame.new(0, movement.hoverHeight, 0))
		skater.mode = "Grounded"
		skater.velocity = Vector3.new(0, 0, -60)
		Fixtures.scriptedBinding(InputController.context, "Move"):Fire(Vector2.new(1, 0))
		SkateController:step(0.1)
		Fixtures.expectNear(velocityOf(rig), Vector3.new(0, 0, -59.48))
		expect(SkateController.diving).toBe(true)
		-- Nor does a teammate right ahead take them in tow.
		local leader = skaterAt("Leader", Vector3.new(0, 0, -5))
		table.insert(others, { player = "2", team = "Blue", root = Fixtures.root(leader) })
		Fixtures.scriptedBinding(InputController.context, "Attach"):Fire(true)
		SkateController:step(1 / 60)
		expect(skater.mode).never.toBe("Attached")
		-- The server's knockdown takes over; a kickoff freeze or a new character ends a dive too.
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		SkateController:step(1 / 60)
		expect(SkateController.diving).toBe(false)
		rig:SetAttribute(Attributes.KnockedDown, nil)
		SkateController.diving = true
		Fixtures.root(rig).Anchored = true
		SkateController:step(1 / 60)
		expect(SkateController.diving).toBe(false)
		SkateController.diving = true
		SkateController:bind(skaterAt("Respawned", Vector3.new(50, 0, 0)))
		expect(SkateController.diving).toBe(false)
	end)

	it("knows when a teammate is close enough to attach behind", function()
		local leader = skaterAt("Leader", Vector3.new(0, 0, -5))
		table.insert(others, { player = "2", team = "Blue", root = Fixtures.root(leader) })
		SkateController:step(1 / 60)
		expect(SkateController.attachable).toBe(true)

		leader:PivotTo(CFrame.new(0, movement.hoverHeight, -40))
		SkateController:step(1 / 60)
		expect(SkateController.attachable).toBe(false)

		-- Attached, then let go: during the cooldown the teammate right ahead is no one to attach behind.
		leader:PivotTo(CFrame.new(0, movement.hoverHeight, -5))
		local attachKey = Fixtures.scriptedBinding(InputController.context, "Attach")
		attachKey:Fire(true)
		SkateController:step(1 / 60)
		expect((SkateController.skater :: any).mode).toBe("Attached")
		expect(SkateController.attachable).toBe(true)
		attachKey:Fire(false)
		SkateController:step(1 / 60)
		SkateController:step(1 / 60)
		expect(SkateController.attachable).toBe(false)
	end)

	it("boosts a release toward the stick held as the skater lets go", function()
		local leader = skaterAt("Leader", Vector3.new(0, 0, -5))
		table.insert(others, { player = "2", team = "Blue", root = Fixtures.root(leader) })
		local attachKey = Fixtures.scriptedBinding(InputController.context, "Attach")
		attachKey:Fire(true)
		SkateController:step(1 / 60)
		expect((SkateController.skater :: any).mode).toBe("Attached")
		-- The stick's right is +X; the leader faces -Z.
		Fixtures.scriptedBinding(InputController.context, "Move"):Fire(Vector2.new(1, 0))
		attachKey:Fire(false)
		SkateController:step(1 / 60)
		local velocity = velocityOf(rig)
		expect(velocity.X).toBeGreaterThan(0.95 * movement.attachBoostSpeed)
		expect(math.abs(velocity.Z)).toBeLessThan(0.2 * movement.attachBoostSpeed)
	end)

	it("steers along the screen on a wall, as the camera shows it rolled or only leaning", function()
		-- Both cameras look along -Z beside a wall whose up is -X. Rolled onto it, the camera's right is +Y, up the
		-- wall. Leaning only Camera.maxTiltDeg (30°) toward it (#223), its right is (cos 30°, sin 30°, 0), mostly into
		-- the wall: laid on the wall it still points straight up, at full strength.
		local leaning = Vector3.new(-math.sin(math.rad(30)), math.cos(math.rad(30)), 0)
		for _, up in { -Vector3.xAxis, leaning } do
			setup({ Camera = { CFrame = CFrame.lookAlong(Vector3.zero, -Vector3.zAxis, up) } })
			SkateController:bind(rig)
			local skater = SkateController.skater :: any
			skater.up = -Vector3.xAxis
			Fixtures.scriptedBinding(InputController.context, "Move"):Fire(Vector2.new(1, 0))
			SkateController:step(1 / 60)
			Fixtures.expectNear(SkateController.move, Vector3.new(0, 1, 0))
		end
	end)

	it("lets go of an attach without its boost when Roblox's menu opens", function()
		local leader = skaterAt("Leader", Vector3.new(0, 0, -5))
		table.insert(others, { player = "2", team = "Blue", root = Fixtures.root(leader) })
		Fixtures.scriptedBinding(InputController.context, "Attach"):Fire(true)
		SkateController:step(1 / 60)
		expect((SkateController.skater :: any).mode).toBe("Attached")
		-- The menu lets go of the key, not the player: no release boost.
		menu.MenuOpened:Fire()
		SkateController:step(1 / 60)
		expect((SkateController.skater :: any).mode).never.toBe("Attached")
		expect(velocityOf(rig).Magnitude).toBeLessThan(movement.attachBoostSpeed)
	end)

	it("keeps telling the server about pump and brake during the freeze", function()
		Fixtures.root(rig).Anchored = true
		Fixtures.scriptedBinding(InputController.context, "Pump"):Fire(true)
		SkateController:step(1 / 60)
		expect(sent).toEqual({ { true, false, false } })
	end)

	-- Everyone else poses the Air Pose from the server's attribute (#218). The owner (#245): it lasts while the jump
	-- key is held.
	it("tells the server when the Air Pose starts and when letting go of the key ends it", function()
		local skater = SkateController.skater :: any
		skater.mode = "Airborne"
		skater.velocity = Vector3.new(0, 30, 0)
		local jump = Fixtures.scriptedBinding(InputController.context, "Jump")
		jump:Fire(true)
		-- The press arrives with the deferred events.
		task.wait()
		SkateController:step(1 / 60)
		expect(sent).toEqual({ { false, false, true } })
		jump:Fire(false)
		task.wait()
		SkateController:step(1 / 60)
		expect(skater.mode).toBe("Airborne")
		expect(sent).toEqual({ { false, false, true }, { false, false, false } })
	end)

	-- The owner (#245): touching down still posing is a fall, which the server judges from the attribute, behind this
	-- screen. So a pose held into the ground is still reported for posedLandingTolerance, or until the knockdown.
	it(
		"still reports a pose held into the ground for posedLandingTolerance, or until a knockdown or a freeze",
		function()
			local skater = SkateController.skater :: any
			local jump = Fixtures.scriptedBinding(InputController.context, "Jump")
			local POSED, STANDING = { false, false, true }, { false, false, false }
			-- Strikes the pose on a hop and holds it down to the floor, then lets go.
			local function landPosed()
				skater.mode = "Airborne"
				skater.velocity = Vector3.new(0, 30, 0)
				jump:Fire(true)
				task.wait()
				for _ = 1, 60 do
					SkateController:step(1 / 60)
					if skater.mode == "Grounded" then
						break
					end
				end
				expect(skater.mode).toBe("Grounded")
				jump:Fire(false)
				task.wait()
			end
			landPosed()
			-- 0.3 s is 18 frames: one short of them, still posed; one past them, not.
			local frames = math.round(config.Network.posedLandingTolerance * 60)
			for _ = 1, frames - 1 do
				SkateController:step(1 / 60)
			end
			expect(sent).toEqual({ POSED })
			SkateController:step(1 / 60)
			SkateController:step(1 / 60)
			expect(sent).toEqual({ POSED, STANDING })
			landPosed()
			expect(sent).toEqual({ POSED, STANDING, POSED })
			rig:SetAttribute(Attributes.KnockedDown, "Fall")
			SkateController:step(1 / 60)
			expect(sent).toEqual({ POSED, STANDING, POSED, STANDING })
			-- So do a kickoff freeze and a new character.
			rig:SetAttribute(Attributes.KnockedDown, nil)
			landPosed()
			Fixtures.root(rig).Anchored = true
			SkateController:step(1 / 60)
			expect(sent).toEqual({ POSED, STANDING, POSED, STANDING, POSED, STANDING })
			Fixtures.root(rig).Anchored = false
			landPosed()
			SkateController:bind(skaterAt("Respawned", Vector3.new(50, 0, 0)))
			SkateController:step(1 / 60)
			expect(sent).toEqual({ POSED, STANDING, POSED, STANDING, POSED, STANDING, POSED })
		end
	)

	it("drops a jump pressed while it had no character", function()
		local jumpKey = Fixtures.scriptedBinding(InputController.context, "Jump")
		jumpKey:Fire(true)
		task.wait()
		jumpKey:Fire(false)
		SkateController:bind(skaterAt("Respawned", Vector3.new(50, 0, 0)))
		SkateController:step(1 / 60)
		expect((SkateController.skater :: any).mode).toBe("Grounded")
	end)

	it("falls when no riding surface is below", function()
		rig:PivotTo(CFrame.new(1000, 50, 1000))
		SkateController:step(0.1)
		expect((SkateController.skater :: any).mode).toBe("Airborne")
		Fixtures.expectNear(velocityOf(rig), Vector3.new(0, -19.5808, 0))
	end)

	-- The skater body's velocity has no force limit, so a skater flying into a wall pressed its collider through the
	-- arena's 1-stud slab (#176; in Studio, 5 launches in 8 at 120 studs/s and over). The collider is a ball of
	-- radius 1 around the root; one step at 120 studs/s travels 2 studs.
	it("slides along a ride surface its collider reaches before the next step, or already touches", function()
		local dt = 1 / 60
		-- A wall facing -X at x = 2.5, high above the floor.
		addSlab(CFrame.new(3, 20, 0), Vector3.new(1, 40, 40))
		local fall = Fixtures.GRAVITY * dt * (1 - movement.airDrag * dt)
		-- 1.5 studs short of the wall, then 0.5 into it.
		for _, x in { 0, 2 } do
			flying(Vector3.new(x, 20, 0), Vector3.new(120, 0, 0))
			SkateController:step(dt)
			Fixtures.expectNear(velocityOf(rig), fall, CAST_TOLERANCE)
		end
		-- Beyond this step's travel, the wall takes nothing.
		flying(Vector3.new(-10, 20, 0), Vector3.new(120, 0, 0))
		SkateController:step(dt)
		expect(velocityOf(rig).X).toBeCloseTo(120 * (1 - movement.airDrag * dt), 3)
	end)

	-- Every arena surface is slabs side by side (spec §7.1): sliding along a wall crosses their seams.
	it("keeps its speed along a wall across a seam between two of its slabs", function()
		local dt = 1 / 60
		-- One wall facing -X at x = 2.5, in two slabs meeting at z = 0.
		addSlab(CFrame.new(3, 20, 10), Vector3.new(1, 40, 20))
		addSlab(CFrame.new(3, 20, -10), Vector3.new(1, 40, 20))
		-- Touching the wall (0.5 studs in), 1 stud before the seam, flying along it.
		flying(Vector3.new(2, 20, 1), Vector3.new(0, 0, -120))
		SkateController:step(dt)
		expect(velocityOf(rig).Z).toBeCloseTo(-120 * (1 - movement.airDrag * dt), 3)
	end)

	-- A barrier (the arena's top, A7) stops a skater's collider like a ceiling, but no ground ray sees it: a skater
	-- sliding under it keeps its speed along it, and one on the floor below still rides the floor.
	it("slides under a barrier its collider reaches, which no ground ray sees", function()
		local dt = 1 / 60
		local barrier = Instance.new("Folder")
		barrier.Name = "Top"
		barrier.Parent = folder
		barrier:AddTag(Tags.Barrier)
		local function addBarrier(cframe: CFrame, size: Vector3)
			local slab = Instance.new("Part")
			slab.Anchored = true
			slab.Size = size
			slab.CFrame = cframe
			slab.Parent = barrier
		end
		-- A ceiling facing -Y 0.5 studs above the collider's top, and a sheet tilted 30 degrees across the ground ray,
		-- under the collider.
		local ceiling = 20 + movement.colliderDiameter / 2 + 0.5
		addBarrier(CFrame.new(0, ceiling + 0.5, 0), Vector3.new(40, 1, 40))
		addBarrier(CFrame.new(-20, 0.6, 0) * CFrame.Angles(0, 0, math.rad(30)), Vector3.new(2, 0.2, 2))
		RideSurfaces:refresh()

		-- At 120 studs/s, 72 of them up: it reaches the ceiling within the step.
		flying(Vector3.new(0, 20, 0), Vector3.new(0, 72, -96))
		SkateController:step(dt)
		expect(velocityOf(rig).Y).toBeLessThan(CAST_TOLERANCE)
		expect(velocityOf(rig).Z).toBeCloseTo(-96 * (1 - movement.airDrag * dt), 1)

		rig:PivotTo(CFrame.new(-20, movement.hoverHeight, 0))
		local skater = SkateController.skater :: any
		skater.mode = "Grounded"
		skater.velocity = Vector3.zero
		for _ = 1, 10 do
			SkateController:step(dt)
		end
		expect(skater.mode).toBe("Grounded")
		expect(skater.up:Dot(Vector3.yAxis)).toBeCloseTo(1, 4)
		expect(Fixtures.root(rig).Position.Y).toBeCloseTo(movement.hoverHeight, 1)
	end)

	it("sweeps nothing for a skater brought to rest", function()
		local casts = 0
		setup({
			Spherecast = function(): RaycastResult?
				casts += 1
				return nil
			end,
		})
		SkateController:bind(rig)
		flying(Vector3.new(0, 20, 0), Vector3.zero)
		SkateController:step(1 / 60)
		local before = casts
		-- The falling step swept through the cast it was given.
		expect(before > 0).toBe(true)
		SkateController:push(-velocityOf(rig), false)
		expect(casts).toBe(before)
		Fixtures.expectNear(velocityOf(rig), Vector3.zero)
	end)

	it("slides into a corner, losing its velocity into both surfaces", function()
		-- Both 2 studs from the root: the collider (radius 1) reaches either in one step at hardCap's share along it.
		addSlab(CFrame.new(2.5, 20, 0), Vector3.new(1, 40, 40)) -- a wall facing -X at x = 2
		addSlab(CFrame.new(0, 22.5, 0), Vector3.new(40, 1, 40)) -- a ceiling facing -Y at y = 22
		flying(Vector3.new(0, 20, 0), Vector3.new(120, 120, 0))
		SkateController:step(1 / 60)
		Fixtures.expectNear(velocityOf(rig), Vector3.zero, CAST_TOLERANCE)
	end)

	it("slides along a ride surface an action pushes it into", function()
		addSlab(CFrame.new(3, 20, 0), Vector3.new(1, 40, 40))
		flying(Vector3.new(0, 20, 0), Vector3.zero)
		SkateController:step(1 / 60)
		SkateController:push(Vector3.new(120, 0, 0), true)
		expect(math.abs(velocityOf(rig).X)).toBeLessThan(CAST_TOLERANCE)
	end)

	it("drives a new character after a respawn", function()
		Fixtures.scriptedBinding(InputController.context, "Move"):Fire(Vector2.new(0, 1))
		SkateController:step(0.1)
		local before = velocityOf(rig)
		local respawned = skaterAt("Respawned", Vector3.new(50, 0, 0))
		SkateController:bind(respawned)
		SkateController:step(0.1)
		Fixtures.expectNear(velocityOf(respawned), Vector3.new(0, 0, -2.594))
		Fixtures.expectNear(velocityOf(rig), before)
	end)

	it("tells the server about pump and brake only when they change", function()
		local pump = Fixtures.scriptedBinding(InputController.context, "Pump")
		pump:Fire(true)
		for _ = 1, 3 do
			SkateController:step(1 / 60)
		end
		expect(sent).toEqual({ { true, false, false } })
		pump:Fire(false)
		SkateController:step(1 / 60)
		expect(sent).toEqual({ { true, false, false }, { false, false, false } })
	end)

	-- The server drops states beyond its rate limit, and nothing resends one: the client keeps to the same limit and
	-- sends the latest state once it may, so the server always ends up with what the keys hold.
	it("keeps to the server's rate for pump and brake, then sends the latest state", function()
		local now = 0
		setup({
			Clock = function(): number
				return now
			end,
		})
		SkateController:bind(rig)
		local pump = Fixtures.scriptedBinding(InputController.context, "Pump")
		local perSecond = config.Network.maxSkateStatesPerSecond
		-- An odd count of toggles ends on pump held, unlike the last state the burst sends.
		for toggle = 1, perSecond + 11 do
			pump:Fire(toggle % 2 == 1)
			SkateController:step(1 / 60)
		end
		expect(#sent).toBe(perSecond)
		expect(sent[perSecond]).toEqual({ false, false, false })
		now = 1
		SkateController:step(1 / 60)
		expect(#sent).toBe(perSecond + 1)
		expect(sent[perSecond + 1]).toEqual({ true, false, false })
	end)

	it("ignores one seam ray's side face, so the skater's up holds", function()
		-- Measured in Phase 3: a downward ray exactly on a seam of the step hit a slab's side face.
		local seam = Vector3.new(0, 0.49, -0.87)
		local normals = { Vector3.yAxis, Vector3.yAxis, seam, Vector3.yAxis }
		local ray = 0
		setup({
			Raycast = function(): any
				ray += 1
				return { Normal = normals[ray], Distance = movement.hoverHeight }
			end,
		})
		SkateController:bind(rig)
		local turnCos = math.cos(math.rad(movement.normalFilter.maxTurnDeg))
		for _ = 1, #normals do
			-- Riding at cruise: a steep normal is ridden, not fallen from, so only the filter keeps the skater's up.
			local riding = SkateController.skater :: any
			riding.velocity = Vector3.new(60, 0, 0)
			SkateController:step(1 / 60)
			expect(riding.up:Dot(Vector3.yAxis) >= turnCos).toBe(true)
		end
	end)

	it("steps in under half a millisecond", function()
		local spots: { { any } } = {
			{ Vector3.new(0, 0, -5), "Blue" },
			{ Vector3.new(3, 0, -6), "Blue" },
			{ Vector3.new(-8, 0, 4), "Orange" },
			{ Vector3.new(10, 0, -12), "Orange" },
			{ Vector3.new(-4, 0, -15), "Orange" },
		}
		for index, spot in spots do
			local other = skaterAt(`Other{index}`, spot[1])
			Fixtures.root(other).AssemblyLinearVelocity = Vector3.new(0, 0, -40)
			table.insert(others, { player = tostring(index + 1), team = spot[2], root = Fixtures.root(other) })
		end
		Fixtures.scriptedBinding(InputController.context, "Move"):Fire(Vector2.new(0, 1))
		Fixtures.scriptedBinding(InputController.context, "Pump"):Fire(true)
		local started = os.clock()
		for _ = 1, 600 do
			SkateController:step(1 / 60)
		end
		expect((os.clock() - started) / 600).toBeLessThan(0.0005)
	end)
end)

-- The controller over an overhang's arc (A3, the rule the glass's lips use): its ray returns the arc's normal, and
-- the test drives the skater along it.
describe("SkateController over an overhang", function()
	local RADIUS = 22
	local DT = 1 / 60

	-- Whether the skater stays on from a wall up to the top of the arc at `speed`. With `strips`, the arc is that many
	-- flat strips over a half circle, as the arena builds its lips of flat strips, so the ray's normal turns only at
	-- strip edges.
	local function holdsOverTheTop(speed: number, strips: number?): boolean
		local phi = 0
		setup({
			Raycast = function(): any
				local facing = phi
				if strips ~= nil then
					local width = math.pi / strips
					facing = (math.floor(phi / width) + 0.5) * width
				end
				local normal = Vector3.new(-math.cos(facing), -math.sin(facing), 0)
				return { Normal = normal, Distance = movement.hoverHeight }
			end,
		})
		SkateController:bind(rig)
		local skater = SkateController.skater :: SkateMath.Skater
		local step = speed * DT / RADIUS
		for frame = 0, math.ceil((math.pi / 2) / step) do
			phi = frame * step
			skater.velocity = Vector3.new(-math.sin(phi), math.cos(phi), 0) * speed
			SkateController:step(DT)
			if skater.mode == "Airborne" then
				return false
			end
		end
		return true
	end

	it("holds a skater over the top of the arc at 70 studs/s and drops one at 60, as the loop rule says", function()
		expect(holdsOverTheTop(70)).toBe(true)
		expect(holdsOverTheTop(60)).toBe(false)
	end)

	it("does the same over an arc of 21 flat strips, through its own normal filter", function()
		expect(holdsOverTheTop(70, 21)).toBe(true)
		expect(holdsOverTheTop(60, 21)).toBe(false)
	end)
end)
