--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local BallLook = require(ServerScriptService.Server.BallLook)
local BallSkins = require(ReplicatedStorage.Shared.Skins.BallSkins)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Look = require(ReplicatedStorage.Shared.Ball.Look)

local config = Fixtures.config()
local DIAMETER = 2 * config.Ball.radius
local DEFAULT = BallSkins.get(BallSkins.DEFAULT)

local folder: Folder
-- The mesh ids asked for, and the lines logged, since the last init.
local asked: { string }
local logged: { string }

-- BallLook started with a mesh maker that never reaches Roblox: an empty MeshPart, or what `make` does.
local function init(make: ((id: string) -> MeshPart)?)
	asked, logged = {}, {}
	BallLook:init({
		Config = config,
		MakeMesh = function(id: string, solid: boolean): MeshPart
			-- The look only draws (the ball's own part collides): a solid ask would show in `asked`.
			table.insert(asked, if solid then `{id} (solid)` else id)
			return if make ~= nil then make(id) else Instance.new("MeshPart")
		end,
		Log = function(line: string)
			table.insert(logged, line)
		end,
	})
end

-- A ball part as BallService makes one, somewhere off the origin.
local function newBall(): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * DIAMETER
	part.CFrame = CFrame.new(3, 4, 5) * CFrame.Angles(0, 0.5, 0)
	part.Parent = folder
	return part
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "BallLookTest"
	folder.Parent = workspace
end)

afterEach(function()
	folder:Destroy()
end)

-- #400 (the owner's Q275-Q277): Roller Champions' ball, a black band round its middle, drawn by a mesh made once in
-- Blender whose paint map takes a skin's picture; the round ball part keeps the physics.
describe("BallLook", function()
	it(
		"dresses a ball in its skin: the mesh at the ball's size and place, its picture over the skin's colour",
		function()
			init()
			local ball = newBall()
			BallLook:dress(ball, BallSkins.DEFAULT)
			local look = Look.of(ball) :: BasePart
			expect(look:IsA("MeshPart")).toBe(true)
			expect(look.Size).toEqual(ball.Size)
			expect(look.CFrame).toEqual(ball.CFrame)
			expect(look.Color).toEqual(DEFAULT.color)
			local picture = look:FindFirstChildOfClass("SurfaceAppearance") :: SurfaceAppearance
			local skin = BallSkins.look(BallSkins.DEFAULT)
			expect(picture ~= skin).toBe(true)
			expect(picture.AlphaMode).toBe(Enum.AlphaMode.Overlay)
			expect(picture.ColorMapContent.Uri).toBe(skin.ColorMapContent.Uri)
		end
	)

	-- The client draws the look where it draws the ball (BallView); the server never moves it, so it must not fall,
	-- push, touch or be found by a ray. The ball part, still the one that bounces and rolls, is no longer seen.
	it("only draws: the look stays put, collides, touches and meets rays never, and the ball part is hidden", function()
		init()
		local ball = newBall()
		BallLook:dress(ball, BallSkins.DEFAULT)
		local look = Look.of(ball) :: BasePart
		expect(look.Anchored).toBe(true)
		expect(look.CanCollide).toBe(false)
		expect(look.CanTouch).toBe(false)
		expect(look.CanQuery).toBe(false)
		expect(ball.Transparency).toBe(1)
	end)

	it("asks Roblox for the configured mesh once, however many balls it dresses", function()
		init()
		local first, second = newBall(), newBall()
		BallLook:dress(first, BallSkins.DEFAULT)
		BallLook:dress(second, BallSkins.DEFAULT)
		expect(asked).toEqual({ config.Ball.meshId })
		expect(Look.of(first) ~= Look.of(second)).toBe(true)
		expect(logged).toEqual({})
	end)

	it("draws a plain sphere in the skin's colour when the mesh does not load, and says so once", function()
		init(function(_id: string): MeshPart
			error("HTTP 403 (Forbidden)")
		end)
		local ball = newBall()
		BallLook:dress(ball, BallSkins.DEFAULT)
		BallLook:dress(newBall(), BallSkins.DEFAULT)
		local look = Look.of(ball) :: Part
		expect(look:IsA("MeshPart")).toBe(false)
		expect(look.Shape).toBe(Enum.PartType.Ball)
		-- Today's ball before the mesh (Roblox's default part is studded Plastic).
		expect(look.Material).toBe(Enum.Material.SmoothPlastic)
		expect(look.TopSurface).toBe(Enum.SurfaceType.Smooth)
		expect(look.BottomSurface).toBe(Enum.SurfaceType.Smooth)
		expect(look.Size).toEqual(ball.Size)
		expect(look.Color).toEqual(DEFAULT.color)
		expect(look:FindFirstChildOfClass("SurfaceAppearance")).toBeNil()
		expect(look.Anchored and not look.CanCollide and not look.CanTouch and not look.CanQuery).toBe(true)
		expect(ball.Transparency).toBe(1)
		expect(#logged).toBe(1)
		expect((BallLook :: any)._early).toBeNil()
		local said = logged[1]
		local opening = `BallLook: the ball's mesh {config.Ball.meshId} did not load`
		expect(string.find(said, opening, 1, true) ~= nil).toBe(true)
		expect(string.find(said, "HTTP 403 (Forbidden)", 1, true) ~= nil).toBe(true)
	end)

	-- Found in Play: a start held up by the mesh's download let Roblox load a joining player's default character
	-- before CharacterService turned that off, and the skater's controls waited for a rig it never got.
	it("never holds up the start: plain spheres until the mesh comes, then the mesh on each ball left", function()
		local arrived = Instance.new("BindableEvent")
		init(function(_id: string): MeshPart
			arrived.Event:Wait()
			return Instance.new("MeshPart")
		end)
		local early, gone = newBall(), newBall()
		BallLook:dress(early, BallSkins.DEFAULT)
		BallLook:dress(gone, BallSkins.DEFAULT)
		expect((Look.of(early) :: BasePart):IsA("MeshPart")).toBe(false)
		expect(early.Transparency).toBe(1)
		gone.Parent = nil
		arrived:Fire()
		task.wait()
		local looks = {}
		for _, child in early:GetChildren() do
			if child.Name == Look.NAME then
				table.insert(looks, child)
			end
		end
		expect(#looks).toBe(1)
		local look = looks[1] :: BasePart
		expect(look:IsA("MeshPart")).toBe(true)
		expect(look:FindFirstChildOfClass("SurfaceAppearance")).never.toBeNil()
		expect(look.Color).toEqual(DEFAULT.color)
		expect(look.Size).toEqual(early.Size)
		expect(look.CFrame).toEqual(early.CFrame)
		expect((Look.of(gone) :: BasePart):IsA("MeshPart")).toBe(false)
		local later = newBall()
		BallLook:dress(later, BallSkins.DEFAULT)
		expect((Look.of(later) :: BasePart):IsA("MeshPart")).toBe(true)
		expect(logged).toEqual({})
		-- The download is over: no list of balls is kept, however many more are dressed.
		expect((BallLook :: any)._early).toBeNil()
		arrived:Destroy()
	end)

	it("lets a download from before a new start change nothing", function()
		local arrived = Instance.new("BindableEvent")
		init(function(_id: string): MeshPart
			arrived.Event:Wait()
			return Instance.new("MeshPart")
		end)
		local before = newBall()
		BallLook:dress(before, BallSkins.DEFAULT)
		init(function(_id: string): MeshPart
			error("offline")
		end)
		arrived:Fire()
		task.wait()
		local ball = newBall()
		BallLook:dress(ball, BallSkins.DEFAULT)
		expect((Look.of(ball) :: BasePart):IsA("MeshPart")).toBe(false)
		expect((Look.of(before) :: BasePart):IsA("MeshPart")).toBe(false)
		expect(#logged).toBe(1)
		arrived:Destroy()
	end)

	it("says nothing of a download from before a new start that does not load, and keeps the new mesh", function()
		local arrived = Instance.new("BindableEvent")
		init(function(_id: string): MeshPart
			arrived.Event:Wait()
			error("offline")
		end)
		init()
		arrived:Fire()
		task.wait()
		expect(logged).toEqual({})
		local ball = newBall()
		BallLook:dress(ball, BallSkins.DEFAULT)
		expect((Look.of(ball) :: BasePart):IsA("MeshPart")).toBe(true)
		arrived:Destroy()
	end)
end)
