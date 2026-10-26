--!strict
-- Everything in the arena besides the riding surface (spec §9.1, Arena spec §5): the glass on the two tops, the top
-- that closes the arena (a roof, or an open map's ceiling), the lap gates, the raised goal ring and its panel, the
-- corner markers, the team and ball spawns, and the infield floor.

local Centerline = require(script.Parent.Centerline)
local Config = require(script.Parent.Parent.Parent.Config)
local Crossing = require(script.Parent.Parent.Parent.Rules.Crossing)
local Profile = require(script.Parent.Profile)
local Surface = require(script.Parent.Surface)
local Team = require(script.Parent.Parent.Parent.Rules.Team)
local Triangles = require(script.Parent.Triangles)
local Types = require(script.Parent.Types)

type ArenaConfig = Config.ArenaConfig
type Piece = Types.Piece
type Team = Team.Team

-- Team spawns line up along the middle of their straight: Blue on the top one, Orange on the bottom one, which
-- mirrors Blue across the arena's long axis.
local SPAWN_SECTIONS: { [Team]: number } = { Blue = 1, Orange = 3 }
local CURVED_ENDS = { 2, 4 }

local Features = {}

local function sectionMiddle(arena: ArenaConfig, section: number): number
	local nextStart = if section < Centerline.gateCount
		then Centerline.gateDistance(arena, section + 1)
		else Centerline.length(arena)
	return (Centerline.gateDistance(arena, section) + nextStart) / 2
end

-- A cross-section that never changes along the loop (the glass, the top), swept around it with the surface's merge
-- rule, each slab `thickness` behind its face.
local function sweepFixed(arena: ArenaConfig, section: { Vector2 }, thickness: number): { Piece }
	local rings = Surface.rings(arena, function(): { Vector2 }
		return section
	end)
	return Surface.sweep(rings, thickness)
end

-- The glass (A7): two vertical strips swept around the loop, the inner one standing on the bank's top and the outer
-- one on the outer wall's top, both up to barrier.top. Each runs the way the profile does (down the inner glass, up
-- the outer one), so its slab hangs barrier.thickness behind its face, outside the track. Every strip between two
-- stations is a flat rectangle: one block per station step around the ends, one per side along each straight.
function Features.barriers(arena: ArenaConfig): { Piece }
	local top, width, thickness = arena.barrier.top, arena.trackWidth, arena.barrier.thickness
	local inner = { Vector2.new(0, top), Vector2.new(0, arena.innerBankHeight) }
	local outer = { Vector2.new(width, arena.outerWallHeight), Vector2.new(width, top) }
	local pieces = sweepFixed(arena, inner, thickness)
	for _, piece in sweepFixed(arena, outer, thickness) do
		table.insert(pieces, piece)
	end
	return pieces
end

-- The top (R14): Profile.top swept around the loop, its slabs surfaceThickness thick above it (and behind an open
-- map's strips), outside the track.
function Features.top(arena: ArenaConfig): { Piece }
	return sweepFixed(arena, Profile.top(arena), arena.surfaceThickness)
end

-- Gate g spans the track at the start of section g and faces the travel direction, as tall as the top, so no ball in
-- play passes over it (Bounds.inArena).
function Features.gates(arena: ArenaConfig): { Crossing.Rectangle }
	local gates: { Crossing.Rectangle } = {}
	local top = Profile.topHeight(arena)
	for gate = 1, Centerline.gateCount do
		table.insert(gates, {
			frame = Centerline.at(arena, Centerline.gateDistance(arena, gate), arena.trackWidth / 2, top / 2),
			width = arena.trackWidth,
			height = top,
		})
	end
	return gates
end

local function fail(message: string): never
	error(`Arena: {message}`, 0)
end

-- The rim's outline in the ring's plane (x toward the outer wall, y up): its blocks' outer faces form a regular
-- polygon around the opening, whose corners reach past ringRadius + rimThickness.
local function rimCorners(arena: ArenaConfig): { Vector2 }
	local goal = arena.goal
	local count = goal.rimSegments
	local radius = (goal.ringRadius + goal.rimThickness) / math.cos(math.pi / count)
	local corners: { Vector2 } = {}
	for corner = 0, count - 1 do
		-- Segment j faces 90° + 360°·j/n (see the rim below); its outer corners sit half a segment either side.
		local angle = math.pi / 2 + math.pi / count + 2 * math.pi * corner / count
		table.insert(corners, radius * Vector2.new(math.cos(angle), math.sin(angle)))
	end
	return corners
end

-- How far the outline reaches from the ring's center along a unit direction.
local function reach(corners: { Vector2 }, direction: Vector2): number
	local farthest = -math.huge
	for _, corner in corners do
		farthest = math.max(farthest, corner:Dot(direction))
	end
	return farthest
end

-- The height of the cross-section's riding surface at a lateral position between the walls, or nil at a wall.
local function surfaceHeight(points: { Vector2 }, lateral: number): number?
	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		if from.X < to.X and from.X <= lateral and lateral <= to.X then
			return from.Y + (to.Y - from.Y) * (lateral - from.X) / (to.X - from.X)
		end
	end
	return nil
end

-- The ring must fit inside the track's cross-section at the goal gate, judged by its real outline against the
-- surface as built (the step half blended there, the wall's foot curve as strips).
local function checkFit(arena: ArenaConfig, corners: { Vector2 }, lateral: number, gateDistance: number)
	local height = arena.goal.heightAboveFloor
	if lateral - reach(corners, -Vector2.xAxis) < 0 then
		fail("the goal ring must fit across the track")
	end
	if
		height - reach(corners, -Vector2.yAxis) < arena.stepHeight
		or height + reach(corners, Vector2.yAxis) > arena.outerWallHeight
	then
		fail("the goal ring must sit between the upper floor and the outer wall top")
	end
	local surface = Profile.points(arena, arena.stepHeight * Centerline.stepBlend(arena, gateDistance))
	for _, corner in corners do
		local floor = surfaceHeight(surface, lateral + corner.X)
		if floor == nil or height + corner.Y <= floor then
			fail("the goal ring must clear the track's surface at the goal gate")
		end
	end
end

-- The ring stands on the goal gate's plane with its outline wallGap from the outer wall face, so it sits on the
-- carrier's right shoulder and its front faces oncoming skaters.
function Features.goal(arena: ArenaConfig): Types.Goal
	local goal = arena.goal
	local outerRadius = goal.ringRadius + goal.rimThickness
	local corners = rimCorners(arena)
	local gateDistance = Centerline.gateDistance(arena, arena.goalGateIndex)
	local lateral = arena.trackWidth - goal.wallGap - reach(corners, Vector2.xAxis)
	checkFit(arena, corners, lateral, gateDistance)
	local frame = Centerline.at(arena, gateDistance, lateral, goal.heightAboveFloor)

	-- Blocks whose outer faces form a regular polygon around the opening.
	local rim: { Piece } = {}
	local segmentLength = 2 * outerRadius * math.tan(math.pi / goal.rimSegments)
	for segment = 0, goal.rimSegments - 1 do
		table.insert(rim, {
			shape = "Block",
			cframe = frame
				* CFrame.Angles(0, 0, 2 * math.pi * segment / goal.rimSegments)
				* CFrame.new(0, goal.ringRadius + goal.rimThickness / 2, 0),
			size = Vector3.new(segmentLength, goal.rimThickness, goal.rimThickness),
		})
	end

	return {
		frame = frame,
		openingRadius = goal.ringRadius,
		rim = rim,
		-- A cylinder's axis is its X axis; turned to lie along the frame's LookVector it covers the opening.
		panel = {
			shape = "Cylinder",
			cframe = frame * CFrame.Angles(0, math.pi / 2, 0),
			size = Vector3.new(goal.panelThickness, 2 * goal.ringRadius, 2 * goal.ringRadius),
		},
	}
end

-- A flat panel on the outer wall's inner face at each gate, its top flush with the wall top, under the glass. Its
-- thickness is the surface's, and it stays out of the skaters' way.
function Features.markers(arena: ArenaConfig): { Piece }
	local markers: { Piece } = {}
	for gate = 1, Centerline.gateCount do
		table.insert(markers, {
			shape = "Block",
			cframe = Centerline.at(
				arena,
				Centerline.gateDistance(arena, gate),
				arena.trackWidth - arena.surfaceThickness / 2,
				arena.outerWallHeight - arena.marker.height / 2
			),
			size = Vector3.new(arena.surfaceThickness, arena.marker.height, arena.marker.width),
		})
	end
	return markers
end

-- teamSize floor-level frames per team, teamSpawnSpacing apart on the lower floor, facing the travel direction.
function Features.teamSpawns(arena: ArenaConfig, teamSize: number): Types.TeamSpawns
	local lane = Profile.lowerFloorCenter(arena)
	local spawns: Types.TeamSpawns = { Blue = {}, Orange = {} }
	for _, team: Team in Team.list do
		local middle = sectionMiddle(arena, SPAWN_SECTIONS[team])
		for slot = 1, teamSize do
			local distance = middle + (slot - (teamSize + 1) / 2) * arena.teamSpawnSpacing
			table.insert(spawns[team], Centerline.at(arena, distance, lane, 0))
		end
	end
	return spawns
end

-- ballSpawnHeight above the middle of the track at each curved end's apex: equally far from both teams' spawns.
function Features.ballSpawns(arena: ArenaConfig): { CFrame }
	local spawns: { CFrame } = {}
	for _, section in CURVED_ENDS do
		table.insert(
			spawns,
			Centerline.at(arena, sectionMiddle(arena, section), arena.trackWidth / 2, arena.ballSpawnHeight)
		)
	end
	return spawns
end

-- The infield floor behind the inner glass (Arena spec §5.5): a slab surfaceThickness thick, its top at the lower
-- floor's height, meeting the back of the glass's slab (barrier.thickness behind its face) instead of overlapping it:
-- a block between the straights, and under each curved end a fan of prisms from the end's center to the glass's back
-- at every station, because the glass there is flat strips, not a circle. It is no ride surface: no skater reaches it.
function Features.infield(arena: ArenaConfig): { Piece }
	local behindGlass = -arena.barrier.thickness
	local thickness = arena.surfaceThickness
	local pieces: { Piece } = {
		{
			shape = "Block",
			cframe = CFrame.new(0, -thickness / 2, 0),
			size = Vector3.new(
				arena.straightLength,
				thickness,
				2 * (arena.endRadius - arena.trackWidth / 2 - arena.barrier.thickness)
			),
		},
	}
	for _, section in CURVED_ENDS do
		local stations = Centerline.sectionStations(arena, section)
		-- The end's center: endRadius from the centerline, on the infield side.
		local center = Centerline.at(arena, stations[1], arena.trackWidth / 2 - arena.endRadius, 0).Position
		local previous = Centerline.at(arena, stations[1], behindGlass, 0).Position
		for step = 2, #stations do
			local current = Centerline.at(arena, stations[step], behindGlass, 0).Position
			-- Each wedge's slab hangs `thickness` below the top face.
			for _, wedge in Triangles.wedges(center, previous, current, Vector3.yAxis, thickness) do
				table.insert(pieces, wedge)
			end
			previous = current
		end
	end
	return pieces
end

return Features
