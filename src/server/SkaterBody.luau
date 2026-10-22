--!strict
-- The skater body (spec §7.1), added by the server to each character it loads:
-- - one collider of the same size for every avatar, welded to the root;
-- - avatar parts that touch nothing;
-- - the velocity and facing constraints the owning client drives.
-- Default animations never start: StarterCharacterScripts holds our own Animate (src/character).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)

-- The PhysicsService methods registering the groups uses, so tests can pass a fake.
export type Physics = {
	IsCollisionGroupRegistered: (self: any, name: string) -> boolean,
	RegisterCollisionGroup: (self: any, name: string) -> (),
	CollisionGroupSetCollidable: (self: any, first: string, second: string, collidable: boolean) -> (),
}

local SkaterBody = {}

local function addCollider(root: BasePart, movement: Config.MovementConfig, character: Model)
	local collider = Instance.new("Part")
	collider.Name = SkaterRig.collider
	-- Before Size: a Ball part keeps whatever non-uniform size it is given.
	collider.Shape = Enum.PartType.Ball
	collider.Size = Vector3.one * movement.colliderDiameter
	collider.CFrame = root.CFrame
	collider.Transparency = 1
	collider.CanQuery = false
	collider.CanTouch = false
	collider.CollisionGroup = SkaterRig.groups.collider
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = collider
	weld.Parent = collider
	collider.Parent = character
end

local function addConstraints(root: BasePart)
	local attachment = Instance.new("Attachment")
	attachment.Name = SkaterRig.attachment
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = SkaterRig.velocity
	velocity.Attachment0 = attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	-- Unlimited force: the velocity is exactly what the skating step decided.
	velocity.ForceLimitsEnabled = false
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root

	local align = Instance.new("AlignOrientation")
	align.Name = SkaterRig.align
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = true
	align.PrimaryAxis = root.CFrame.RightVector
	align.SecondaryAxis = root.CFrame.UpVector
	align.Parent = root
end

function SkaterBody.build(character: Model, movement: Config.MovementConfig)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = SkaterRig.groups.body
		end
	end
	local root = character:FindFirstChild(SkaterRig.root) :: BasePart
	addCollider(root, movement, character)
	addConstraints(root)
end

-- Bodies touch nothing; colliders touch the arena and the ball but pass through each other (owner, 2026-10-22).
function SkaterBody.registerGroups(physics: Physics)
	local body, collider = SkaterRig.groups.body, SkaterRig.groups.collider
	for _, name in { body, collider } do
		if not physics:IsCollisionGroupRegistered(name) then
			physics:RegisterCollisionGroup(name)
		end
	end
	physics:CollisionGroupSetCollidable(body, SkaterRig.groups.arena, false)
	physics:CollisionGroupSetCollidable(body, body, false)
	physics:CollisionGroupSetCollidable(body, collider, false)
	physics:CollisionGroupSetCollidable(collider, SkaterRig.groups.arena, true)
	physics:CollisionGroupSetCollidable(collider, collider, false)
end

return table.freeze(SkaterBody)
