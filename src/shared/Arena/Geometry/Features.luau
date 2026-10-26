--!strict
-- Everything in the arena besides the solid riding surface (spec §9.1, Arena spec §5): the rideable glass walls with
-- their lips, the top that closes the arena (a roof, or an open map's ceiling), the lap gates, the goal ring hanging
-- from its arm with its panel, the glass panels hanging at the gates, the team and ball spawns, and the infield floor.

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

-- The rideable glass (R5, R15): the inner and the outer glass sections, each rising from a solid top and curling into
-- its lip, swept around the loop with their slabs surfaceThickness behind their faces, outside the track. A vertical
-- face between two stations is a flat rectangle (one block per station step around the ends, one per side along each
-- straight); a lip's strips run whole along the straights and are wedges around the ends.
function Features.glass(arena: ArenaConfig): { Piece }
	local pieces = sweepFixed(arena, Profile.innerGlass(arena), arena.surfaceThickness)
	for _, piece in sweepFixed(arena, Profile.outerGlass(arena), arena.surfaceThickness) do
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

-- The height of the rim's top: segment 0 faces straight up, so the outline is flat there, where the arm's post stands.
local function rimTop(arena: ArenaConfig): number
	local goal = arena.goal
	return goal.heightAboveFloor + goal.ringRadius + goal.rimThickness
end

-- The ring must hang inside the track's cross-section at the goal gate, judged by its real outline (its corners)
-- against the glass faces and the surface as built (the step half blended there, the wall's foot curve as strips),
-- and under its arm, whose beam must stay under the lips.
local function checkFit(arena: ArenaConfig, corners: { Vector2 }, lateral: number, gateDistance: number)
	if lateral - reach(corners, -Vector2.xAxis) < 0 or lateral + reach(corners, Vector2.xAxis) > arena.trackWidth then
		fail("the goal ring must stay inside the glass")
	end
	local surface = Profile.points(arena, arena.stepHeight * Centerline.stepBlend(arena, gateDistance))
	for _, corner in corners do
		-- The riding surface under the corner, or nil at a wall.
		local floor = Profile.heightAt(surface, lateral + corner.X)
		if floor == nil or arena.goal.heightAboveFloor + corner.Y <= floor then
			fail("the goal ring must clear the track's surface at the goal gate")
		end
	end
	local armHeight = arena.goal.arm.height
	if rimTop(arena) >= armHeight then
		fail("the goal ring must hang under its arm")
	end
	if armHeight >= Profile.lipStart(arena) then
		fail("the goal's arm must stay under the lips")
	end
end

-- The arm the ring hangs from (Arena spec §5.3), in the goal gate's plane: a post from the rim's top up to arm.height,
-- then a beam at that height from over the ring's centre out to the outer glass's face. It is decoration that the art
-- pass replaces.
local function arm(arena: ArenaConfig, gateDistance: number, lateral: number): { Piece }
	local thickness, height = arena.goal.arm.thickness, arena.goal.arm.height
	local base = rimTop(arena)
	local beamLength = arena.trackWidth - lateral
	return {
		{
			shape = "Block",
			cframe = Centerline.at(arena, gateDistance, lateral, (base + height) / 2),
			size = Vector3.new(thickness, height - base, thickness),
		},
		{
			shape = "Block",
			cframe = Centerline.at(arena, gateDistance, lateral + beamLength / 2, height),
			size = Vector3.new(beamLength, thickness, thickness),
		},
	}
end

-- The ring hangs over the track in the goal gate's plane (R7), its centre goal.across of the way from the inner glass's
-- face to the outer one, its front facing oncoming skaters.
function Features.goal(arena: ArenaConfig): Types.Goal
	local goal = arena.goal
	local outerRadius = goal.ringRadius + goal.rimThickness
	local corners = rimCorners(arena)
	local gateDistance = Centerline.gateDistance(arena, arena.goalGateIndex)
	local lateral = goal.across * arena.trackWidth
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
		arm = arm(arena, gateDistance, lateral),
	}
end

-- The rounded opening's edge at a lateral position (R18): half an ellipse whose feet stand on the outer wall's top at
-- both glass faces, its apex gatePanel.openingHeight at the track's middle.
local function openingEdge(arena: ArenaConfig, lateral: number): number
	local half = arena.trackWidth / 2
	local across = (lateral - half) / half
	local rise = arena.gatePanel.openingHeight - arena.outerWallHeight
	return arena.outerWallHeight + rise * math.sqrt(math.max(0, 1 - across * across))
end

-- Each gate's glass panel (R18, Arena spec §5.2), in gate order: in the gate's plane, glass fills the track's
-- cross-section from the walls' top as built (Profile.topOutline) down to the rounded opening skaters pass through.
-- It is gatePanel.segments slices across the track, each a quad gatePanel.depth thick behind the plane (a block when
-- it is a rectangle, wedges otherwise, as the surface's quads). Its pivot is the opening's apex, facing the travel
-- direction.
function Features.gatePanels(arena: ArenaConfig): { Types.GatePanel }
	local panel, width = arena.gatePanel, arena.trackWidth
	local panels: { Types.GatePanel } = {}
	for gate = 1, Centerline.gateCount do
		local distance = Centerline.gateDistance(arena, gate)
		local function point(lateral: number, height: number): Vector3
			return Centerline.at(arena, distance, lateral, height).Position
		end
		local pieces: { Piece } = {}
		for slice = 0, panel.segments - 1 do
			local from, to = width * slice / panel.segments, width * (slice + 1) / panel.segments
			-- Across the slice toward the outer glass, and up from the opening to the walls' top.
			local quad = Surface.quadPieces(
				point(from, openingEdge(arena, from)),
				point(to, openingEdge(arena, to)),
				point(from, Profile.topOutline(arena, from)),
				point(to, Profile.topOutline(arena, to)),
				panel.depth
			)
			for _, piece in quad do
				table.insert(pieces, piece)
			end
		end
		table.insert(panels, { pieces = pieces, apex = Centerline.at(arena, distance, width / 2, panel.openingHeight) })
	end
	return panels
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
-- floor's height, meeting the back of the glass's slab (surfaceThickness behind its face) instead of overlapping it:
-- a block between the straights, and under each curved end a fan of prisms from the end's center to the glass's back
-- at every station, because the glass there is flat strips, not a circle. It is no ride surface: no skater reaches it.
function Features.infield(arena: ArenaConfig): { Piece }
	local thickness = arena.surfaceThickness
	local behindGlass = -thickness
	local pieces: { Piece } = {
		{
			shape = "Block",
			cframe = CFrame.new(0, -thickness / 2, 0),
			size = Vector3.new(
				arena.straightLength,
				thickness,
				2 * (arena.endRadius - arena.trackWidth / 2 + behindGlass)
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
