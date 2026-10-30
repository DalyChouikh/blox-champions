--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local BallCarrier = require(Client.BallCarrier)
local CameraController = require(Client.CameraController)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local InputController = require(Client.InputController)
local RideSurfaces = require(Client.RideSurfaces)
local SkateController = require(Client.SkateController)
local SkaterBody = require(ServerScriptService.Server.SkaterBody)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local config = Config.defaults()
local movement = config.Movement
local DT = 1 / 60

type FakeCamera = { CFrame: CFrame, FieldOfView: number, CameraType: Enum.CameraType }

local folder: Folder
-- Roblox's menu: opening it pauses the controls.
local menu: Fixtures.Menu
local rig: Model
local camera: FakeCamera
local mouse: { MouseBehavior: Enum.MouseBehavior, MouseIconEnabled: boolean }
local preferred: Enum.PreferredInput
local ball: BasePart?
local LOCAL_ID = "1"

-- A rig with its skater body standing on the floor at `position`, facing `facing`.
local function skaterAt(name: string, position: Vector3, facing: Vector3): Model
	local at = position + Vector3.new(0, movement.hoverHeight, 0)
	local model = Fixtures.rig(folder, name, CFrame.lookAt(at, at + facing))
	SkaterBody.build(model, movement)
	return model
end

local function skater(): any
	return SkateController.skater
end

-- Where the camera looks past: the root, `height` up along the camera's up.
local function focus(): Vector3
	return Fixtures.root(rig).Position + CameraController.chase.up * config.Camera.height
end

-- A ball part at `position`, which the controller sees as the ball.
local function ballAt(position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.Shape = Enum.PartType.Ball
	part.Position = position
	part.Parent = folder
	ball = part
	return part
end

-- Presses the Ball Focus key once (Pressed is deferred).
local function tapBallFocus(binding: InputBinding)
	binding:Fire(true)
	task.wait()
	binding:Fire(false)
end

-- (Re)builds the controller on the fakes above, with a fresh chase.
local function initCamera()
	CameraController:init({
		Config = config,
		InputController = InputController,
		RideSurfaces = RideSurfaces,
		SkateController = SkateController,
		BallCarrier = BallCarrier,
		Camera = camera,
		Mouse = mouse,
		PreferredInput = function(): Enum.PreferredInput
			return preferred
		end,
		BallPart = {
			get = function(_self: any): BasePart?
				return ball
			end,
		},
		LocalId = LOCAL_ID,
	})
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "CameraControllerTest"
	folder.Parent = workspace
	Fixtures.floor(folder)
	camera = { CFrame = CFrame.new(), FieldOfView = 70, CameraType = Enum.CameraType.Custom }
	mouse = { MouseBehavior = Enum.MouseBehavior.Default, MouseIconEnabled = true }
	preferred = Enum.PreferredInput.KeyboardAndMouse
	ball = nil
	menu = Fixtures.menu()
	InputController:init({
		Config = config,
		Parent = folder,
		GuiService = menu,
		LookSettings = function(): (number, number, boolean)
			return 1, 1, false
		end,
	})
	BallCarrier:init({})
	RideSurfaces:init({})
	SkateController:init({
		Config = config,
		InputController = InputController,
		RideSurfaces = RideSurfaces,
		Camera = { CFrame = CFrame.lookAt(Vector3.new(0, 5, 10), Vector3.new(0, 5, 0)) },
		Skaters = function(): { any }
			return {}
		end,
		SendSkateState = function() end,
		Gravity = Fixtures.GRAVITY,
		Team = function(): string?
			return "Blue"
		end,
	})
	rig = skaterAt("Skater", Vector3.zero, -Vector3.zAxis)
	SkateController:bind(rig)
	initCamera()
end)

afterEach(function()
	InputController:destroy()
	folder:Destroy()
end)

describe("CameraController", function()
	it("takes over the camera: behind and above the skater, level", function()
		CameraController:step(DT)
		expect(camera.CameraType).toBe(Enum.CameraType.Scriptable)
		Fixtures.expectNear(camera.CFrame.Position, Fixtures.root(rig).Position + Vector3.new(0, 4, 12))
		Fixtures.expectNear(camera.CFrame.LookVector, Vector3.new(0, 0, -1))
		expect(camera.FieldOfView).toBeCloseTo(70, 3)
	end)

	it("turns with the look input", function()
		local look = Fixtures.scriptedBinding(InputController.context, "Look")
		look:Fire(Vector2.new((math.pi / 2) / DT, 0))
		CameraController:step(DT)
		Fixtures.expectNear(camera.CFrame.LookVector, Vector3.new(1, 0, 0))
	end)

	it(
		"locks the mouse to the center with a mouse, and frees it on other devices or while the controls are paused",
		function()
			CameraController:step(DT)
			expect(mouse.MouseBehavior).toBe(Enum.MouseBehavior.LockCenter)
			menu.MenuOpened:Fire()
			CameraController:step(DT)
			expect(mouse.MouseBehavior).toBe(Enum.MouseBehavior.Default)
			menu.MenuClosed:Fire()
			preferred = Enum.PreferredInput.Touch
			CameraController:step(DT)
			expect(mouse.MouseBehavior).toBe(Enum.MouseBehavior.Default)
			preferred = Enum.PreferredInput.KeyboardAndMouse
			CameraController:step(DT)
			expect(mouse.MouseBehavior).toBe(Enum.MouseBehavior.LockCenter)
		end
	)

	it("hides the cursor while the mouse is locked, and shows it when free", function()
		CameraController:step(DT)
		expect(mouse.MouseIconEnabled).toBe(false)
		menu.MenuOpened:Fire()
		CameraController:step(DT)
		expect(mouse.MouseIconEnabled).toBe(true)
		menu.MenuClosed:Fire()
		preferred = Enum.PreferredInput.Gamepad
		CameraController:step(DT)
		expect(mouse.MouseIconEnabled).toBe(true)
		preferred = Enum.PreferredInput.KeyboardAndMouse
		CameraController:step(DT)
		expect(mouse.MouseIconEnabled).toBe(false)
	end)

	it("pulls in in front of a wall behind the skater", function()
		CameraController:step(DT)
		-- Its near face 5.5 studs behind the focus: the camera stops collisionMargin in front of it.
		local wall = Instance.new("Part")
		wall.Anchored = true
		wall.Size = Vector3.new(40, 40, 1)
		wall.CFrame = CFrame.new(focus() + Vector3.new(0, 0, 6))
		wall.Parent = folder
		wall:AddTag(Tags.RideSurface)
		RideSurfaces:refresh()
		CameraController:step(DT)
		expect((camera.CFrame.Position - focus()).Magnitude).toBeCloseTo(5, 3)
	end)

	-- A barrier (the arena's top, A7) stops skaters and the ball, never the view.
	it("looks through a barrier behind the skater", function()
		CameraController:step(DT)
		local barrier = Instance.new("Part")
		barrier.Anchored = true
		barrier.Size = Vector3.new(40, 40, 1)
		barrier.CFrame = CFrame.new(focus() + Vector3.new(0, 0, 6))
		barrier.Parent = folder
		barrier:AddTag(Tags.Barrier)
		RideSurfaces:refresh()
		CameraController:step(DT)
		expect((camera.CFrame.Position - focus()).Magnitude).toBeCloseTo(config.Camera.distance, 3)
	end)

	it("keeps its focus inside the arena, under a roof just above the skater", function()
		local root = Fixtures.root(rig)
		local roof = Instance.new("Part")
		roof.Anchored = true
		roof.Size = Vector3.new(400, 1, 400)
		-- Its underside 2 studs above the root: the focus, 4 up, would be past it.
		roof.CFrame = CFrame.new(root.Position + Vector3.new(0, 2.5, 0))
		roof.Parent = folder
		roof:AddTag(Tags.RideSurface)
		RideSurfaces:refresh()
		CameraController:step(DT)
		local underside = roof.Position.Y - roof.Size.Y / 2
		expect(camera.CFrame.Position.Y < underside).toBe(true)
		Fixtures.expectNear(
			camera.CFrame.Position,
			root.Position + Vector3.new(0, 2 - config.Camera.collisionMargin, 12)
		)
	end)

	it("rolls with the skater riding a wall", function()
		CameraController:step(DT)
		skater().up = Vector3.xAxis
		CameraController:step(10)
		Fixtures.expectNear(camera.CFrame.UpVector, Vector3.new(1, 0, 0))
	end)

	it("swings behind the travel on a gamepad but not with a mouse", function()
		skater().velocity = Vector3.new(50, 0, 0)
		preferred = Enum.PreferredInput.Gamepad
		for _ = 1, 60 do
			CameraController:step(DT)
		end
		expect(camera.CFrame.LookVector:Dot(Vector3.xAxis)).toBeGreaterThan(0.5)

		preferred = Enum.PreferredInput.KeyboardAndMouse
		initCamera()
		for _ = 1, 60 do
			CameraController:step(DT)
		end
		Fixtures.expectNear(camera.CFrame.LookVector, Vector3.new(0, 0, -1))
	end)

	it("faces down the skater's facing during the kickoff freeze", function()
		local look = Fixtures.scriptedBinding(InputController.context, "Look")
		look:Fire(Vector2.new((math.pi / 2) / DT, 0))
		CameraController:step(DT)
		look:Fire(Vector2.zero)
		Fixtures.expectNear(camera.CFrame.LookVector, Vector3.new(1, 0, 0))
		Fixtures.root(rig).Anchored = true
		SkateController:step(DT)
		CameraController:step(DT)
		Fixtures.expectNear(camera.CFrame.LookVector, skater().forward)
		expect(camera.CFrame.LookVector:Dot(Vector3.xAxis)).toBeLessThan(0.5)
	end)

	it("starts behind a new character", function()
		CameraController:step(DT)
		local second = skaterAt("Second", Vector3.new(30, 0, 0), Vector3.xAxis)
		SkateController:bind(second)
		rig = second
		CameraController:step(DT)
		Fixtures.expectNear(camera.CFrame.LookVector, Vector3.new(1, 0, 0))
	end)

	it("widens the view with speed", function()
		CameraController:step(DT)
		skater().velocity = Vector3.new(0, 0, -movement.hardCap)
		CameraController:step(10)
		expect(camera.FieldOfView).toBeCloseTo(90, 3)
	end)

	it("steps in under 0.1 ms", function()
		local look = Fixtures.scriptedBinding(InputController.context, "Look")
		local total = 0
		for step = 1, 600 do
			-- The look held for the first half, then still.
			look:Fire(if step <= 300 then Vector2.new(1, 0) else Vector2.zero)
			local started = os.clock()
			CameraController:step(DT)
			total += os.clock() - started
		end
		expect(total / 600).toBeLessThan(0.0001)
	end)

	it("turns toward the ball while Ball Focus is held", function()
		CameraController:step(DT)
		local target = ballAt(focus() + Vector3.new(30, 0, 0))
		local hold = Fixtures.scriptedBinding(InputController.context, "BallFocus")
		hold:Fire(true)
		CameraController:step(10)
		Fixtures.expectNear(camera.CFrame.LookVector, (target.Position - focus()).Unit, 1e-2)
		expect(CameraController.focusing).toBe(true)
		hold:Fire(false)
		CameraController:step(1)
		expect(CameraController.focusing).toBe(false)
		Fixtures.expectNear(camera.CFrame.LookVector, (target.Position - focus()).Unit, 1e-2)
	end)

	it("ignores Ball Focus while carrying the ball", function()
		CameraController:step(DT)
		ballAt(focus() + Vector3.new(30, 0, 0))
		BallCarrier:set(LOCAL_ID)
		Fixtures.scriptedBinding(InputController.context, "BallFocus"):Fire(true)
		CameraController:step(10)
		Fixtures.expectNear(camera.CFrame.LookVector, Vector3.new(0, 0, -1))
		expect(CameraController.focusing).toBe(false)
	end)

	it("ignores Ball Focus while there is no ball in the arena", function()
		CameraController:step(DT)
		Fixtures.scriptedBinding(InputController.context, "BallFocus"):Fire(true)
		CameraController:step(10)
		Fixtures.expectNear(camera.CFrame.LookVector, Vector3.new(0, 0, -1))
	end)

	it("forgets a touch toggle once the device holds Ball Focus instead", function()
		preferred = Enum.PreferredInput.Touch
		CameraController:step(DT)
		local target = ballAt(focus() + Vector3.new(30, 0, 0))
		tapBallFocus(Fixtures.scriptedBinding(InputController.context, "BallFocus"))
		CameraController:step(10)
		Fixtures.expectNear(camera.CFrame.LookVector, (target.Position - focus()).Unit, 1e-2)
		-- A gamepad, its key up, ends the toggle: turned back by hand and on touch again, the camera stays.
		preferred = Enum.PreferredInput.Gamepad
		CameraController:step(DT)
		local look = Fixtures.scriptedBinding(InputController.context, "Look")
		look:Fire(Vector2.new(-(math.pi / 2) / DT, 0))
		CameraController:step(DT)
		look:Fire(Vector2.zero)
		preferred = Enum.PreferredInput.Touch
		CameraController:step(1)
		Fixtures.expectNear(camera.CFrame.LookVector, Vector3.new(0, 0, -1), 1e-2)
	end)

	it("toggles Ball Focus with a tap on touch", function()
		preferred = Enum.PreferredInput.Touch
		CameraController:step(DT)
		local target = ballAt(focus() + Vector3.new(30, 0, 0))
		local tap = Fixtures.scriptedBinding(InputController.context, "BallFocus")
		tapBallFocus(tap)
		CameraController:step(10)
		Fixtures.expectNear(camera.CFrame.LookVector, (target.Position - focus()).Unit, 1e-2)
		-- A second tap lets the camera go: turned away by hand, it stays away.
		tapBallFocus(tap)
		local look = Fixtures.scriptedBinding(InputController.context, "Look")
		look:Fire(Vector2.new(-(math.pi / 2) / DT, 0))
		CameraController:step(DT)
		look:Fire(Vector2.zero)
		CameraController:step(1)
		Fixtures.expectNear(camera.CFrame.LookVector, Vector3.new(0, 0, -1), 1e-2)
	end)

	it("follows the ball when the player has no character", function()
		SkateController.skater = nil
		SkateController.root = nil
		ballAt(Vector3.new(0, 10, 0))
		CameraController:step(DT)
		Fixtures.expectNear(camera.CFrame.Position, Vector3.new(0, 16, 30))
		Fixtures.expectNear(camera.CFrame.LookVector, Vector3.new(0, 0, -1))
	end)

	it("watches the ball once the character it followed is gone, before the next one is bound", function()
		CameraController:step(DT)
		ballAt(Vector3.new(0, 10, 0))
		rig:Destroy()
		CameraController:step(DT)
		Fixtures.expectNear(camera.CFrame.Position, Vector3.new(0, 16, 30))
	end)

	it("holds still with neither a character nor a ball", function()
		SkateController.skater = nil
		SkateController.root = nil
		camera.CFrame = CFrame.new(1, 2, 3)
		CameraController:step(DT)
		Fixtures.expectNear(camera.CFrame.Position, Vector3.new(1, 2, 3))
	end)
end)
