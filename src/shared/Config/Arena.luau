--!strict
-- The graybox arena (spec §9.1, Arena spec §3): the track loop, its cross-section, the glass on its tops, the goal
-- ring, corner markers, spawns and colors. Lengths are in studs. Arena/Geometry turns these numbers into parts; the
-- cross-field checks here, and the goal ring's fit and the skaters' reach checked in Arena/Geometry, reject sizes that
-- could not be built without overlaps or gaps, or that a skater could leave.

local PartSize = require(script.Parent.Parent.Util.PartSize)
local Validate = require(script.Parent.Validate)

export type ArenaConfig = {
	straightLength: number,
	-- Radius of the track's centerline around each curved end.
	endRadius: number,
	trackWidth: number,
	outerWallHeight: number,
	-- The inner bank: a quarter circle this high and this wide, from its top down to the lower floor.
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
	-- The glass standing on the inner bank's and the outer wall's tops (A7): up to `top` above the lower floor, a slab
	-- `thickness` thick behind its face, outside the track. Skaters and the ball bounce off it; it never darkens the
	-- track.
	barrier: { top: number, thickness: number, transparency: number },
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
		-- Gap between the ring's outer edge and the outer wall.
		wallGap: number,
	},
	marker: { width: number, height: number },
	teamSpawnSpacing: number,
	ballSpawnHeight: number,
	-- Parts that only carry a tag: lap gates (invisible; only their plane counts), team spawn pads (a square in the
	-- team's color) and ball spawns (invisible).
	gateThickness: number,
	spawnPad: { width: number, thickness: number, transparency: number },
	ballSpawnSize: number,
	-- glass: the barriers'.
	colors: { surface: Color3, infield: Color3, goal: Color3, marker: Color3, glass: Color3 },
}

local defaults: ArenaConfig = {
	straightLength = 200,
	endRadius = 70,
	trackWidth = 60,
	outerWallHeight = 28,
	innerBankHeight = 8,
	wallCurveRadius = 14,
	stepHeight = 4,
	stepWidth = 14,
	upperFloorWidth = 6,
	profileBlendLength = 20,
	segmentLength = 4,
	stripsPerSection = 20,
	surfaceThickness = 1,
	barrier = { top = 85, thickness = 1, transparency = 0.7 },
	goalGateIndex = 2,
	goal = {
		ringRadius = 7,
		heightAboveFloor = 18,
		panelThickness = 0.5,
		panelTransparency = 0.3,
		rimThickness = 1,
		rimSegments = 16,
		wallGap = 1,
	},
	marker = { width = 2, height = 8 },
	teamSpawnSpacing = 10,
	ballSpawnHeight = 6,
	gateThickness = 0.2,
	spawnPad = { width = 4, thickness = 0.2, transparency = 0.4 },
	ballSpawnSize = 1,
	colors = {
		surface = Color3.fromRGB(163, 162, 165),
		infield = Color3.fromRGB(99, 95, 98),
		goal = Color3.fromRGB(248, 248, 248),
		marker = Color3.fromRGB(27, 42, 53),
		glass = Color3.fromRGB(200, 225, 240),
	},
}

local size = Validate.number({ above = 0 })
-- Sizes one part directly (the infield, a gate, a wall slab, a glass slab, a marker, the panel), so it must be a size
-- Roblox builds as given instead of clamping.
local partSize = Validate.number({ min = PartSize.MIN, max = PartSize.MAX })
local nonNegative = Validate.number({ min = 0 })
local transparency = Validate.number({ min = 0, max = 1 })
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
	barrier = Validate.record({ top = partSize, thickness = partSize, transparency = transparency }),
	-- The loop has four sections (two straights, two curved ends), and a lap gate starts each one.
	goalGateIndex = Validate.number({ min = 1, max = 4, integer = true }),
	goal = Validate.record({
		ringRadius = size,
		heightAboveFloor = size,
		panelThickness = partSize,
		panelTransparency = transparency,
		rimThickness = partSize,
		rimSegments = Validate.number({ min = 3, integer = true }),
		-- A ring touching the wall would put a rim face in the wall's plane, where the two flicker.
		wallGap = size,
	}),
	marker = Validate.record({ width = partSize, height = partSize }),
	teamSpawnSpacing = size,
	ballSpawnHeight = size,
	gateThickness = partSize,
	spawnPad = Validate.record({ width = partSize, thickness = partSize, transparency = transparency }),
	ballSpawnSize = partSize,
	colors = Validate.record({ surface = color, infield = color, goal = color, marker = color, glass = color }),
})

-- Checked in order; the first that fails is reported. Whether the goal ring fits is judged by Arena/Geometry
-- against the surface as built (Features.goal), which config cannot require; so is whether a skater could clear the
-- glass, which depends on the world's gravity (Reach).
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
			return arena.endRadius - arena.trackWidth / 2 - arena.barrier.thickness > 0
		end,
	},
	{
		message = "the outer wall must rise above its foot curve and the step",
		holds = function(arena: ArenaConfig): boolean
			return arena.outerWallHeight > arena.wallCurveRadius + arena.stepHeight
		end,
	},
	{
		message = "the glass must rise above the inner bank's and the outer wall's tops",
		holds = function(arena: ArenaConfig): boolean
			return arena.barrier.top > arena.outerWallHeight and arena.barrier.top > arena.innerBankHeight
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
}

local schema = Validate.checkAll(fields, crossFieldRules)

return {
	defaults = defaults,
	schema = schema,
}
