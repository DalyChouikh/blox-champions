--!strict
-- Reads an arena's tagged features (spec §9.2) back into what gameplay needs: the rules' ArenaLayout (gates and the
-- goal's scoring disc), the goal panel to open and close, the corner markers, the spawn frames and the surfaces skaters
-- ride, which the server's own rays look for (a diver's touchdown, #221); and what a skater's ground ray found there.
-- Only tagged instances under `root` count, so a leftover arena or an art model elsewhere in the place is ignored.
-- Anything malformed fails fast, naming the tag at fault: a mis-tagged arena must never silently miss laps or goals.

local CollectionService = game:GetService("CollectionService")

local Crossing = require(script.Parent.Parent.Rules.Crossing)
local Freeze = require(script.Parent.Parent.Util.Freeze)
local MatchEngine = require(script.Parent.Parent.Rules.MatchEngine)
local SkateTypes = require(script.Parent.Parent.Skate.Types)
local SmoothNormals = require(script.Parent.Geometry.SmoothNormals)
local Tags = require(script.Parent.Tags)
local Team = require(script.Parent.Parent.Rules.Team)
local Types = require(script.Parent.Geometry.Types)

type Team = Team.Team

export type TaggedArena = {
	layout: MatchEngine.ArenaLayout,
	goalPanel: BasePart,
	-- Indexed by GateIndex: each a model (the builder's gate panel) or a single part.
	markers: { PVInstance },
	-- Each team's spawn parts' frames, sorted by part name.
	teamSpawns: Types.TeamSpawns,
	-- Sorted by part name.
	ballSpawns: { CFrame },
	-- Everything tagged RideSurface (folders of the floors, banks, walls and glass), for a RaycastParams include list.
	rideSurfaces: { Instance },
}

local TaggedLayout = {}

local function fail(message: string): never
	error(`TaggedLayout: {message}`, 0)
end

-- The one place tags are looked up, so every lookup is limited to root.
local function taggedUnder(root: Instance, tag: string): { Instance }
	local found: { Instance } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(root) then
			table.insert(found, instance)
		end
	end
	return found
end

local function single(root: Instance, tag: string): Instance
	local found = taggedUnder(root, tag)
	if #found ~= 1 then
		fail(`expected exactly one {tag}, found {#found}`)
	end
	return found[1]
end

local function asPart(instance: Instance, tag: string): BasePart
	if not instance:IsA("BasePart") then
		fail(`{tag} "{instance.Name}" must be a part (got {instance.ClassName})`)
	end
	return instance :: BasePart
end

local function asModelOrPart(instance: Instance, tag: string): PVInstance
	if not (instance:IsA("Model") or instance:IsA("BasePart")) then
		fail(`{tag} "{instance.Name}" must be a model or a part (got {instance.ClassName})`)
	end
	return instance :: PVInstance
end

-- Instances tagged `tag`, sorted by name, so the first malformed one is always the one named.
local function sortedTagged(root: Instance, tag: string): { Instance }
	local found = taggedUnder(root, tag)
	table.sort(found, function(a: Instance, b: Instance): boolean
		return a.Name < b.Name
	end)
	return found
end

-- Parts tagged `tag`, sorted by name.
local function partsTagged(root: Instance, tag: string): { BasePart }
	local parts: { BasePart } = {}
	for _, instance in sortedTagged(root, tag) do
		table.insert(parts, asPart(instance, tag))
	end
	return parts
end

-- Instances tagged `tag`, each passed through `cast`, sorted by their GateIndex attribute, and those indices in the
-- same order.
local function byGateIndex<T>(root: Instance, tag: string, cast: (Instance, string) -> T): ({ T }, { number })
	local entries: { { item: T, index: number } } = {}
	for _, instance in sortedTagged(root, tag) do
		local item = cast(instance, tag)
		local index = instance:GetAttribute(Tags.Attribute.GateIndex)
		-- `% 1 == 0` is false for NaN and the infinities too.
		if type(index) == "number" and index % 1 == 0 then
			table.insert(entries, { item = item, index = index })
		else
			fail(`{tag} "{instance.Name}" needs a whole-number {Tags.Attribute.GateIndex} attribute`)
		end
	end
	table.sort(entries, function(a: { item: T, index: number }, b: { item: T, index: number }): boolean
		return a.index < b.index
	end)
	local items: { T } = {}
	local indices: { number } = {}
	for position, entry in entries do
		items[position] = entry.item
		indices[position] = entry.index
	end
	return items, indices
end

-- True when the sorted indices are exactly 1..n.
local function isSequence(indices: { number }): boolean
	for position, index in indices do
		if index ~= position then
			return false
		end
	end
	return true
end

local function readGates(root: Instance): { Crossing.Rectangle }
	local parts, indices = byGateIndex(root, Tags.LapGate, asPart)
	if #parts == 0 then
		fail(`no {Tags.LapGate} found`)
	end
	if not isSequence(indices) then
		local got = table.concat(indices, ", ")
		fail(`{Tags.LapGate} {Tags.Attribute.GateIndex} values must be 1..n without gaps or repeats (got {got})`)
	end
	local gates: { Crossing.Rectangle } = {}
	for _, part in parts do
		table.insert(gates, { frame = part.CFrame, width = part.Size.X, height = part.Size.Y })
	end
	return gates
end

local function readGoal(root: Instance): Crossing.Disc
	local hoop = single(root, Tags.GoalHoop)
	local radius = hoop:GetAttribute(Tags.Attribute.OpeningRadius)
	if hoop:IsA("PVInstance") and type(radius) == "number" and radius > 0 then
		return { frame = hoop:GetPivot(), radius = radius }
	end
	return fail(`{Tags.GoalHoop} needs a positive {Tags.Attribute.OpeningRadius} attribute`)
end

local function readMarkers(root: Instance, gateCount: number): { PVInstance }
	local markers, indices = byGateIndex(root, Tags.CornerMarker, asModelOrPart)
	if #indices ~= gateCount or not isSequence(indices) then
		local got = table.concat(indices, ", ")
		fail(`{Tags.CornerMarker} {Tags.Attribute.GateIndex} values must match the gates (got {got})`)
	end
	return markers
end

local function readTeamSpawns(root: Instance): Types.TeamSpawns
	local spawns: Types.TeamSpawns = { Blue = {}, Orange = {} }
	for _, part in partsTagged(root, Tags.TeamSpawn) do
		local team = part:GetAttribute(Tags.Attribute.Team)
		if not Team.is(team) then
			local expected = table.concat(Team.list, " or ")
			fail(`{Tags.TeamSpawn} "{part.Name}" has {Tags.Attribute.Team} "{tostring(team)}"; expected {expected}`)
		end
		table.insert(spawns[team :: Team], part.CFrame)
	end
	for _, team: Team in Team.list do
		if #spawns[team] == 0 then
			fail(`no {Tags.TeamSpawn} found for {team}`)
		end
	end
	return spawns
end

local function readBallSpawns(root: Instance): { CFrame }
	local spawns: { CFrame } = {}
	for _, part in partsTagged(root, Tags.BallSpawn) do
		table.insert(spawns, part.CFrame)
	end
	if #spawns == 0 then
		fail(`no {Tags.BallSpawn} found`)
	end
	return spawns
end

local function readRideSurfaces(root: Instance): { Instance }
	local surfaces = taggedUnder(root, Tags.RideSurface)
	if #surfaces == 0 then
		fail(`no {Tags.RideSurface} found`)
	end
	return surfaces
end

function TaggedLayout.read(root: Instance): TaggedArena
	local gates = readGates(root)
	local arena: TaggedArena = {
		layout = { gates = gates, goal = readGoal(root) },
		goalPanel = asPart(single(root, Tags.GoalPanel), Tags.GoalPanel),
		markers = readMarkers(root, #gates),
		teamSpawns = readTeamSpawns(root),
		ballSpawns = readBallSpawns(root),
		rideSurfaces = readRideSurfaces(root),
	}
	return Freeze.deep(arena)
end

-- Whether a ride surface's part is glass, by its folder's tag (#299: no climb holds on the glass).
function TaggedLayout.isGlass(part: Instance): boolean
	local folder = part.Parent
	return folder ~= nil and folder:HasTag(Tags.Glass)
end

-- What a skater's ground ray found, into `ground`: the ride surface's direction at the point from the arena's smooth
-- shape (`smoothNormal`, #294), how far it lies, and whether it is glass (#299); no result, no ground. The client's
-- skating and the server's look-down read the ground alike (the review, #303).
function TaggedLayout.readGround(ground: SkateTypes.Ground, result: RaycastResult?, smoothNormal: SmoothNormals.Reader)
	if result == nil then
		ground.hit = false
		return
	end
	ground.hit = true
	ground.normal = smoothNormal(result.Position, result.Normal)
	ground.distance = result.Distance
	ground.glass = TaggedLayout.isGlass(result.Instance)
end

return TaggedLayout
