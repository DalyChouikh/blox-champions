--!strict
-- How high a skater can get (Arena spec §4.2). A skater never moves faster than Movement.hardCap, on the ground or in
-- the air, and every action's push is capped there too (SkateMath). The highest ride surface is the higher of the
-- inner bank's and the outer wall's tops, so a skater launched straight up from it at hardCap is the highest any
-- skater's root can rise: speed² / (2 · gravity) above it. Measured in Play (2026-10-26): a ball-sized part launched
-- straight up rose 47.9 studs at 140 studs/s, under the 49.9 this gives, so it is an upper bound. The Feel part's jumps
-- must keep it true.

local Config = require(script.Parent.Parent.Parent.Config)

local Reach = {}

-- The highest a skater's root can rise above the lower floor, in a world whose gravity pulls `gravity` studs/s² down.
function Reach.skaterTop(config: Config.GameConfig, gravity: number): number
	local arena, speed = config.Arena, config.Movement.hardCap
	return math.max(arena.outerWallHeight, arena.innerBankHeight) + speed * speed / (2 * gravity)
end

return Reach
