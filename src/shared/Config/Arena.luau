--!strict
-- The graybox arena (spec §9.1, Arena spec §3): the track loop, its cross-section, the rideable glass walls with their
-- lips, the top that closes it, the goal ring, the gate panels, spawns and colors. Lengths are in studs. Arena/Geometry
-- turns these numbers into parts; the cross-field checks here, and the goal ring's fit checked in Arena/Geometry,
-- reject sizes that could not be built without overlaps or gaps.

local PartSize = require(script.Parent.Parent.Util.PartSize)
local Validate = require(script.Parent.Validate)

-- A map's top (Arena spec R14): Closed, a glass roof across the walls' top; Open, an invisible ceiling above it.
export type TopKind = "Closed" | "Open"

export type ArenaConfig = {
	straightLength: number,
	-- Radius of the track's centerline around each curved end.
	endRadius: number,
	trackWidth: number,
	outerWallHeight: number,
	-- The inner bank: a quarter circle this high and this wide, from its top down to the lower floor. The owner (#217):
	-- 16, a wide ramp up into the middle glass like Roller Champions' Pixel City (was 8).
	innerBankHeight: number,
	-- Radius of the floor's curve up into the outer wall.
	wallCurveRadius: number,
	stepHeight: number,
	stepWidth: number,
	-- The flat floor between the top of the step and the outer wall's curve.
	upperFloorWidth: number,
	-- Length of the blend between the straights' stepped profile and the curved ends' flat one.
	profileBlendLength: number,
	-- Longest distance between two cross-sections of the swept surface.
	segmentLength: number,
	-- Strips across one cross-section, from the inner bank's top to the outer wall's top.
	stripsPerSection: number,
	-- Every surface part is a slab this thick behind the riding surface.
	surfaceThickness: number,
	-- The rideable glass (R5) rising from the inner bank's and the outer wall's tops up to `top` above the lower floor,
	-- each wall curling inward at the top into a lip (R15): a quarter circle of `lipRadius` in `lipStrips` strips. Its
	-- slabs are surfaceThickness thick behind its faces, outside the track; it never darkens the track. It looks like
	-- `material` at `transparency`, as do a closed map's roof and the gate panels: clear plastic, because Roblox's
	-- Glass material hides every non-opaque part behind it (the far glass, the gate panels, the carrier's beam).
	glass: { top: number, lipRadius: number, lipStrips: number, transparency: number, material: Enum.Material },
	-- The top that closes the arena, set per map (R14): a closed map's roof spans the walls' top between the lips'
	-- ends; an open map's ceiling stands `ceilingAbove` higher, joined to the lips by strips. Either stops skaters and
	-- the ball, and neither is ridden.
	top: { kind: TopKind, ceilingAbove: number },
	goalGateIndex: number,
	goal: {
		-- The opening's radius, which is also the scoring disc's.
		ringRadius: number,
		heightAboveFloor: number,
		panelThickness: number,
		-- The panel starts closed: see-through enough to show the ring is shut.
		panelTransparency: number,
		rimThickness: number,
		rimSegments: number,
		-- Where the ring's centre hangs across the track (R7): a fraction of trackWidth from the inner glass's face.
		across: number,
		-- The decorative arm the ring hangs from (Arena spec §5.3): a post from the rim's top up to `height` above the
		-- lower floor, then a beam at that height out to the outer glass's face, both `thickness` square.
		arm: { thickness: number, height: number },
	},
	-- The glass panel at each gate (R18): a thin wall across the track, filling its whole cross-section from the
	-- surface up to the walls' top, `depth` thick along the track (thinner than the goal's parts: a rule below).
	-- Skaters pass through it.
	gatePanel: { depth: number },
	teamSpawnSpacing: number,
	ballSpawnHeight: number,
	-- Parts that only carry a tag: lap gates (invisible; only their plane counts), team spawn pads (a square in the
	-- team's color) and ball spawns (invisible).
	gateThickness: number,
	spawnPad: { width: number, thickness: number, transparency: number },
	ballSpawnSize: number,
	-- glass: the glass walls', a closed map's roof and the gate walls.
	colors: { surface: Color3, infield: Color3, goal: Color3, glass: Color3 },
}

local defaults: ArenaConfig = {
	straightLength = 200,
	endRadius = 60,
	trackWidth = 80,
	outerWallHeight = 28,
	innerBankHeight = 16,
	wallCurveRadius = 18,
	stepHeight = 4,
	stepWidth = 18,
	upperFloorWidth = 8,
	profileBlendLength = 20,
	segmentLength = 4,
	stripsPerSection = 20,
	surfaceThickness = 1,
	glass = { top = 120, lipRadius = 12, lipStrips = 4, transparency = 0.85, material = Enum.Material.SmoothPlastic },
	top = { kind = "Closed", ceilingAbove = 20 },
	goalGateIndex = 2,
	goal = {
		ringRadius = 7,
		heightAboveFloor = 18,
		panelThickness = 0.5,
		panelTransparency = 0.3,
		rimThickness = 1,
		rimSegments = 16,
		across = 0.75,
		arm = { thickness = 1, height = 40 },
	},
	gatePanel = { depth = 0.2 },
	teamSpawnSpacing = 10,
	ballSpawnHeight = 6,
	gateThickness = 0.2,
	spawnPad = { width = 4, thickness = 0.2, transparency = 0.4 },
	ballSpawnSize = 1,
	colors = {
		surface = Color3.fromRGB(163, 162, 165),
		infield = Color3.fromRGB(99, 95, 98),
		goal = Color3.fromRGB(248, 248, 248),
		glass = Color3.fromRGB(200, 225, 240),
	},
}

local size = Validate.number({ above = 0 })
-- Sizes one part directly (the infield, a gate, a wall slab, a glass slab, a gate panel, the goal's panel and arm), so
-- it must be a size Roblox builds as given instead of clamping.
local partSize = Validate.number({ min = PartSize.MIN, max = PartSize.MAX })
local nonNegative = Validate.number({ min = 0 })
local fraction = Validate.number({ min = 0, max = 1 })
local transparency = fraction
local color = Validate.datatype("Color3")

local fields = Validate.record({
	straightLength = partSize,
	-- The infield block between the straights is almost 2·endRadius deep.
	endRadius = Validate.number({ above = 0, max = PartSize.MAX / 2 }),
	trackWidth = partSize,
	outerWallHeight = partSize,
	innerBankHeight = size,
	wallCurveRadius = size,
	stepHeight = nonNegative,
	stepWidth = size,
	upperFloorWidth = size,
	profileBlendLength = size,
	segmentLength = size,
	-- At least one strip for each of the profile's six pieces.
	stripsPerSection = Validate.number({ min = 6, integer = true }),
	surfaceThickness = partSize,
	-- The glass's height sizes each of its slabs.
	glass = Validate.record({
		top = partSize,
		lipRadius = size,
		lipStrips = Validate.number({ min = 1, integer = true }),
		transparency = transparency,
		material = Validate.enumItem(Enum.Material),
	}),
	-- The ceiling's height above the walls sizes the strips up to it.
	top = Validate.record({ kind = Validate.string({ oneOf = { "Closed", "Open" } }), ceilingAbove = partSize }),
	-- The loop has four sections (two straights, two curved ends), and a lap gate starts each one.
	goalGateIndex = Validate.number({ min = 1, max = 4, integer = true }),
	goal = Validate.record({
		ringRadius = size,
		heightAboveFloor = size,
		panelThickness = partSize,
		panelTransparency = transparency,
		rimThickness = partSize,
		rimSegments = Validate.number({ min = 3, integer = true }),
		across = fraction,
		-- Its height is judged against the ring and the lips by Arena/Geometry.
		arm = Validate.record({ thickness = partSize, height = size }),
	}),
	gatePanel = Validate.record({ depth = partSize }),
	teamSpawnSpacing = size,
	ballSpawnHeight = size,
	gateThickness = partSize,
	spawnPad = Validate.record({ width = partSize, thickness = partSize, transparency = transparency }),
	ballSpawnSize = partSize,
	colors = Validate.record({ surface = color, infield = color, goal = color, glass = color }),
})

-- Checked in order; the first that fails is reported. Whether the goal ring and its arm fit is judged by Arena/Geometry
-- against the arena as built (Features.goal), which config cannot require.
local crossFieldRules: { Validate.Rule } = {
	{
		message = "trackWidth must fit the inner bank, the outer wall's foot curve, the step, the upper floor and a "
			.. "lower floor",
		holds = function(arena: ArenaConfig): boolean
			return arena.trackWidth
					- arena.innerBankHeight
					- arena.wallCurveRadius
					- arena.stepWidth
					- arena.upperFloorWidth
				> 0
		end,
	},
	{
		message = "endRadius must leave room for the infield behind the inner glass",
		holds = function(arena: ArenaConfig): boolean
			return arena.endRadius - arena.trackWidth / 2 - arena.surfaceThickness > 0
		end,
	},
	{
		message = "the outer wall must rise above its foot curve and the step",
		holds = function(arena: ArenaConfig): boolean
			return arena.outerWallHeight > arena.wallCurveRadius + arena.stepHeight
		end,
	},
	{
		message = "the glass must rise above the inner bank's and the outer wall's tops before its lip",
		holds = function(arena: ArenaConfig): boolean
			-- Where the lip starts curling inward: Arena/Geometry's Profile.lipStart, which config cannot require.
			local start = arena.glass.top - arena.glass.lipRadius
			return start > arena.outerWallHeight and start > arena.innerBankHeight
		end,
	},
	{
		message = "the lips must leave the top open between them",
		holds = function(arena: ArenaConfig): boolean
			return 2 * arena.glass.lipRadius < arena.trackWidth
		end,
	},
	{
		-- The blend is centered on each corner, so the two blends of one straight or one curved end must not overlap.
		message = "profileBlendLength must fit within a straight and a curved end",
		holds = function(arena: ArenaConfig): boolean
			return arena.profileBlendLength <= arena.straightLength
				and arena.profileBlendLength <= math.pi * arena.endRadius
		end,
	},
	{
		-- The goal's parts are centred on the goal gate's plane, and that gate's wall hangs behind it, so a wall as
		-- thick as half a goal part would put their faces in one plane, where they flicker (seen at 0.5 on the rim).
		message = "the gate panel must be thinner than half the goal's thinnest part, so its faces never meet the "
			.. "goal's",
		holds = function(arena: ArenaConfig): boolean
			local goal = arena.goal
			return arena.gatePanel.depth < math.min(goal.rimThickness, goal.panelThickness, goal.arm.thickness) / 2
		end,
	},
}

local schema = Validate.checkAll(fields, crossFieldRules)

return {
	defaults = defaults,
	schema = schema,
}
