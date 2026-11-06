--!strict
-- Dresses each ball the server builds (spec §9.4, #400, the owner's Q275-Q277): its look, the ball mesh made in Blender
-- (Config.Ball.meshId) in a skin's colour with the skin's picture copied on (Skins/BallSkins), goes under the ball
-- part, and the ball part, which keeps the physics, is hidden. The look only draws: anchored, it never falls, pushes,
-- touches or meets a ray; each screen moves it to where it draws the ball (Client/BallView).
-- The mesh is asked of Roblox once, in the background (Meshes). Until it comes, a look is a plain sphere in the skin's
-- colour; when it comes, each ball dressed before it that is still in the game is dressed again. If it does not load,
-- the looks stay plain spheres, and the Output says why once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallSkins = require(ReplicatedStorage.Shared.Skins.BallSkins)
local Config = require(ReplicatedStorage.Shared.Config)
local DrawOnly = require(ReplicatedStorage.Shared.Util.DrawOnly)
local Look = require(ReplicatedStorage.Shared.Ball.Look)
local Meshes = require(script.Parent.Meshes)

-- A ball dressed before the mesh came, and its skin.
type Early = { ball: BasePart, skin: string }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type BallLook = {
	name: string,
	dependencies: { string },
	init: (self: BallLook, deps: { [string]: any }) -> (),
	start: (self: BallLook) -> (),
	-- Puts `skin`'s look under `ball` and hides the ball part.
	dress: (self: BallLook, ball: BasePart, skin: string) -> (),
	-- What every look is copied from: the mesh once it has come, else a plain sphere.
	_template: BasePart,
	_meshed: boolean,
	-- The balls dressed while the mesh is on its way; nil once the download is over, either way.
	_early: { Early }?,
	-- Counts the starts: a download from before the latest one changes nothing.
	_generation: number,
}

local function logLine(line: string)
	warn(line)
end

-- A part made ready to be copied as a look: named for Ball/Look, anchored and only drawing.
local function readied(part: BasePart): BasePart
	part.Name = Look.NAME
	part.Anchored = true
	return DrawOnly(part)
end

-- A plain sphere: today's ball, with no band (Roblox's default part is studded Plastic).
local function sphere(): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- A copy of the template under `ball`, at its size and place, in `skin`'s colour, with its picture on the mesh.
local function put(self: BallLook, ball: BasePart, skin: string)
	local look = self._template:Clone()
	look.Size = ball.Size
	look.Color = BallSkins.get(skin).color
	look.CFrame = ball.CFrame
	if self._meshed then
		BallSkins.look(skin):Clone().Parent = look
	end
	look.Parent = ball
end

-- The mesh has come: each ball dressed before it that is still in the game is dressed again.
local function meshed(self: BallLook, mesh: BasePart)
	self._template = readied(mesh)
	self._meshed = true
	local dressed: { Early } = self._early or {}
	for _, early in dressed do
		if early.ball.Parent ~= nil then
			local plain = Look.of(early.ball) :: BasePart
			plain:Destroy()
			put(self, early.ball, early.skin)
		end
	end
	self._early = nil
end

local BallLook: BallLook = {
	name = "BallLook",
	dependencies = { "Config" },
	_template = nil :: any,
	_meshed = false,
	_early = nil,
	_generation = 0,

	-- deps.MakeMesh replaces Roblox's mesh service (a test never reaches it), deps.Log the Output.
	init = function(self: BallLook, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		local make: Meshes.Make = deps.MakeMesh or Meshes.make
		local log: (line: string) -> () = deps.Log or logLine
		local id = config.Ball.meshId
		self._generation += 1
		local generation = self._generation
		self._template = readied(sphere())
		self._meshed = false
		self._early = {}
		Meshes.fetch({ id }, make, function(meshes: { MeshPart })
			if generation == self._generation then
				meshed(self, meshes[1])
			end
		end, function(_id: string, why: string)
			if generation == self._generation then
				self._early = nil
				log(`BallLook: the ball's mesh {id} did not load ({why}); drawing a plain sphere`)
			end
		end)
	end,

	start = function(_self: BallLook) end,

	dress = function(self: BallLook, ball: BasePart, skin: string)
		put(self, ball, skin)
		local early = self._early
		if early ~= nil then
			table.insert(early, { ball = ball, skin = skin })
		end
		ball.Transparency = 1
	end,
}

return BallLook
