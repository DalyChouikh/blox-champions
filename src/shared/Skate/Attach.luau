--!strict
-- Attaching behind a teammate (spec §7.2, Roller Champions' Grapple Whip). A skater holding Attach right behind a
-- teammate is pulled along behind them; letting go, holding too long or losing the leader releases them with a
-- boost toward the stick held then, or the way the leader travels, then a cooldown. This module decides when;
-- SkateMath.follow and release move.

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Rules.Types)
local Vectors = require(script.Parent.Parent.Util.Vectors)

type PlayerId = Types.PlayerId

-- A teammate who could lead: where they are, how they move and which way they face.
export type Candidate = { player: PlayerId, position: Vector3, velocity: Vector3, forward: Vector3 }
export type Change = "None" | "Attached" | "Released"

local Attach = {}
Attach.__index = Attach

type Fields = {
	leader: PlayerId?,
	attachedFor: number,
	cooldownLeft: number,
	-- The way the release boosts: the stick held at the release, else the leader's travel at the last update.
	releaseDirection: Vector3,
	_movement: Config.MovementConfig,
}

export type Attach = typeof(setmetatable({} :: Fields, Attach))

-- The way a leader travels, or their facing while they stand still: a leader riding backwards (#246) faces against
-- their travel, and the boost goes their way (#214, the review #303).
local function travelOf(leader: Candidate): Vector3
	local velocity = leader.velocity
	return if velocity.Magnitude > Vectors.EPSILON then velocity.Unit else leader.forward
end

function Attach.new(movement: Config.MovementConfig): Attach
	local self: Fields = {
		leader = nil,
		attachedFor = 0,
		cooldownLeft = 0,
		releaseDirection = Vector3.zero,
		_movement = movement,
	}
	return setmetatable(self, Attach)
end

-- The nearest teammate within attachRange whose back the skater is in: within attachConeDeg of straight behind.
function Attach.findLeader(movement: Config.MovementConfig, position: Vector3, teammates: { Candidate }): Candidate?
	local coneCos = math.cos(math.rad(movement.attachConeDeg))
	local nearest: Candidate? = nil
	local nearestDistance = math.huge
	for _, candidate in teammates do
		local offset = position - candidate.position
		local distance = offset.Magnitude
		if
			distance > Vectors.EPSILON
			and distance <= movement.attachRange
			and distance < nearestDistance
			and -offset:Dot(candidate.forward) / distance >= coneCos
		then
			nearest = candidate
			nearestDistance = distance
		end
	end
	return nearest
end

-- Where an attached skater is pulled to: attachFollowDistance behind the leader.
function Attach.target(movement: Config.MovementConfig, leader: Candidate): Vector3
	return leader.position - leader.forward * movement.attachFollowDistance
end

-- Let go with no boost and no cooldown: everyone starts a kickoff unattached and free to attach.
function Attach.reset(self: Attach)
	self.leader = nil
	self.attachedFor = 0
	self.cooldownLeft = 0
	self.releaseDirection = Vector3.zero
end

-- `leader` is the best candidate while not attached, and the current leader's record (nil once gone) while attached.
-- `aim` is the stick's direction on the surface (zero at rest): a release boosts toward it, else the leader's way.
function Attach.update(self: Attach, dt: number, holding: boolean, leader: Candidate?, aim: Vector3): Change
	local movement = self._movement
	self.cooldownLeft = math.max(0, self.cooldownLeft - dt)
	if self.leader == nil then
		if holding and self.cooldownLeft == 0 and leader ~= nil then
			self.leader = leader.player
			self.attachedFor = 0
			self.releaseDirection = travelOf(leader)
			return "Attached"
		end
		return "None"
	end

	self.attachedFor += dt
	if leader ~= nil then
		self.releaseDirection = travelOf(leader)
	end
	if not holding or leader == nil or self.attachedFor >= movement.attachMaxSeconds then
		self.leader = nil
		self.cooldownLeft = movement.attachCooldown
		if aim.Magnitude > Vectors.EPSILON then
			self.releaseDirection = aim.Unit
		end
		return "Released"
	end
	return "None"
end

return Attach
