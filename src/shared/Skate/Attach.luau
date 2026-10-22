--!strict
-- Attaching behind a teammate (spec §7.2, Roller Champions' Grapple Whip). A skater holding Attach right behind a
-- teammate is pulled along behind them; letting go, holding too long or losing the leader releases them with a
-- boost along the leader's facing, then a cooldown. This module decides when; SkateMath.follow and release move.

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
	-- The leader's facing at the last update while attached: the way the release boosts.
	releaseDirection: Vector3,
	_movement: Config.MovementConfig,
}

export type Attach = typeof(setmetatable({} :: Fields, Attach))

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
function Attach.update(self: Attach, dt: number, holding: boolean, leader: Candidate?): Change
	local movement = self._movement
	self.cooldownLeft = math.max(0, self.cooldownLeft - dt)
	if self.leader == nil then
		if holding and self.cooldownLeft == 0 and leader ~= nil then
			self.leader = leader.player
			self.attachedFor = 0
			self.releaseDirection = leader.forward
			return "Attached"
		end
		return "None"
	end

	self.attachedFor += dt
	if leader ~= nil then
		self.releaseDirection = leader.forward
	end
	if not holding or leader == nil or self.attachedFor >= movement.attachMaxSeconds then
		self.leader = nil
		self.cooldownLeft = movement.attachCooldown
		return "Released"
	end
	return "None"
end

return Attach
