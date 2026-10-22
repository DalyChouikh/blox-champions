--!strict
-- Drafting (spec §7.2): a skater inside the cone behind any other skater, teammate or opponent, gets extra
-- acceleration, more the closer they are. The strongest pull wins. Allocates nothing.

local Config = require(script.Parent.Parent.Config)
local Vectors = require(script.Parent.Parent.Util.Vectors)

export type Source = { position: Vector3, velocity: Vector3 }

local Draft = {}

function Draft.accel(movement: Config.MovementConfig, position: Vector3, sources: { Source }): number
	local coneCos = math.cos(math.rad(movement.draftConeDeg))
	local strongest = 0
	for _, source in sources do
		local speed = source.velocity.Magnitude
		local offset = position - source.position
		local distance = offset.Magnitude
		if speed > Vectors.EPSILON and distance > Vectors.EPSILON and distance <= movement.draftRange then
			-- The cone opens backward from the source, against its velocity.
			if -offset:Dot(source.velocity) / (distance * speed) >= coneCos then
				strongest = math.max(strongest, movement.draftMaxAccel * (1 - distance / movement.draftRange))
			end
		end
	end
	return strongest
end

return table.freeze(Draft)
