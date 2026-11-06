--!strict
-- The ball's trail (spec §9.4, #313; the owner, Q98): on every screen, a fading streak behind the ball while it flies
-- loose from a throw, a pass or a roll, from the server's mark (Attributes.Thrown) until the next catch. Roblox draws
-- it, a Trail between two attachments UI.ballTrail.width apart and facing the camera, on a part of its own
-- that keeps to where this screen draws the ball (BallView), without the ball's spin, which would twist it. The part
-- keeps to the ball while no trail shows too, so each trail starts at the ball, never with a streak from where the
-- last one ended. It stays on this client; nothing hits, sees or touches it. Stepped before each frame is drawn
-- (FrameController), after the ball is drawn: a step moves the part by its Position and switches the trail only when
-- that changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local BallCarrier = require(script.Parent.BallCarrier)
local BallPart = require(script.Parent.BallPart)
local Config = require(ReplicatedStorage.Shared.Config)
local DrawOnly = require(ReplicatedStorage.Shared.Util.DrawOnly)

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type BallTrail = {
	name: string,
	dependencies: { string },
	init: (self: BallTrail, deps: { [string]: any }) -> (),
	start: (self: BallTrail) -> (),
	step: (self: BallTrail, dt: number) -> (),
	-- Removes what start made (tests).
	destroy: (self: BallTrail) -> (),
	-- The part that keeps to the ball, and its trail, made at start.
	holder: BasePart,
	trail: Trail,
	_config: Config.GameConfig,
	_ballPart: BallPart.BallPart,
	_carrier: BallCarrier.BallCarrier,
	_parent: Instance,
}

-- One of the trail's two edges, `offset` studs up the holder.
local function edge(holder: BasePart, name: string, offset: number): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = Vector3.new(0, offset, 0)
	attachment.Parent = holder
	return attachment
end

local BallTrail: BallTrail = {
	name = "BallTrail",
	dependencies = { "Config", "BallPart", "BallCarrier" },
	holder = nil :: any,
	trail = nil :: any,
	_config = nil :: any,
	_ballPart = nil :: any,
	_carrier = nil :: any,
	_parent = nil :: any,

	-- deps.Parent (where the holder goes) replaces the workspace in tests.
	init = function(self: BallTrail, deps: { [string]: any })
		self._config = deps.Config
		self._ballPart = deps.BallPart
		self._carrier = deps.BallCarrier
		self._parent = deps.Parent or workspace
	end,

	start = function(self: BallTrail)
		local settings = self._config.UI.ballTrail
		local holder = DrawOnly(Instance.new("Part"))
		holder.Name = "BallTrail"
		holder.Anchored = true
		holder.CastShadow = false
		holder.Transparency = 1
		local trail = Instance.new("Trail")
		trail.Attachment0 = edge(holder, "Top", settings.width / 2)
		trail.Attachment1 = edge(holder, "Bottom", -settings.width / 2)
		trail.FaceCamera = true
		trail.Lifetime = settings.lifetime
		trail.Color = ColorSequence.new(settings.color)
		trail.Transparency = NumberSequence.new(settings.transparency, 1)
		trail.Enabled = false
		trail.Parent = holder
		holder.Parent = self._parent
		self.holder = holder
		self.trail = trail
	end,

	step = function(self: BallTrail, _dt: number)
		local ball = self._ballPart:get()
		local trailing = false
		if ball ~= nil then
			self.holder.Position = ball.Position
			trailing = self._carrier.carrier == nil and ball:GetAttribute(Attributes.Thrown) == true
		end
		local trail = self.trail
		if trail.Enabled ~= trailing then
			trail.Enabled = trailing
		end
	end,

	destroy = function(self: BallTrail)
		self.holder:Destroy()
	end,
}

return BallTrail
