--!strict
-- Turns the pure arena geometry into anchored, tagged parts (spec §9.2). Every piece is checked before any part
-- is created, and the model is assembled unparented and parented last, so a failed build leaves nothing in the
-- place (spec §13).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Finite = require(ReplicatedStorage.Shared.Util.Finite)
local Geometry = require(ReplicatedStorage.Shared.Arena.Geometry)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local Types = require(ReplicatedStorage.Shared.Arena.Geometry.Types)

type Piece = Types.Piece

-- Sizes and looks of the parts that only carry a tag: none of them has a gameplay size of its own.
local GATE_THICKNESS = 0.2
local SPAWN_PAD_SIZE = Vector3.new(4, 0.2, 4)
local SPAWN_PAD_TRANSPARENCY = 0.4
local BALL_SPAWN_SIZE = Vector3.one
local PANEL_TRANSPARENCY = 0.3

local Builder = {}

-- What is wrong with a piece Roblox could not build as given, or nil.
local function problemWith(piece: Piece): string?
	local size = piece.size
	if not (Finite.vector(size) and math.min(size.X, size.Y, size.Z) >= Types.MIN_PART_SIZE) then
		return `size {size}`
	end
	if not Finite.frame(piece.cframe) then
		return `cframe {piece.cframe}`
	end
	return nil
end

local function validate(geometry: Geometry.ArenaGeometry)
	local groups: { { name: string, pieces: { Piece } } } = {
		{ name = "surface", pieces = geometry.surface },
		{ name = "infield", pieces = geometry.infield },
		{ name = "goal rim", pieces = geometry.goal.rim },
		{ name = "goal panel", pieces = { geometry.goal.panel } },
		{ name = "marker", pieces = geometry.markers },
	}
	for _, group in groups do
		for index, piece in group.pieces do
			local problem = problemWith(piece)
			if problem ~= nil then
				error(`ArenaBuilder: {group.name} piece {index} is invalid ({problem})`, 0)
			end
		end
	end
end

-- An anchored, smooth, unparented part.
local function newPart(shape: Types.Shape, name: string, cframe: CFrame, size: Vector3): BasePart
	local part: BasePart
	if shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		-- Before Size, so the cylinder keeps the size it is given.
		if shape == "Cylinder" then
			block.Shape = Enum.PartType.Cylinder
		end
		part = block
	end
	part.Name = name
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cframe
	return part
end

local function addSolid(piece: Piece, name: string, color: Color3, parent: Instance): BasePart
	local part = newPart(piece.shape, name, piece.cframe, piece.size)
	part.Color = color
	part.Parent = parent
	return part
end

-- Carries a tag for gameplay code but takes no part in collisions, touches or raycasts.
local function addGhost(name: string, cframe: CFrame, size: Vector3, transparency: number, parent: Instance): BasePart
	local part = newPart("Block", name, cframe, size)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = transparency
	part.Parent = parent
	return part
end

local function newFolder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function addSolids(pieces: { Piece }, prefix: string, color: Color3, parent: Instance)
	for index, piece in pieces do
		addSolid(piece, `{prefix}{index}`, color, parent)
	end
end

local function buildGoal(goal: Types.Goal, color: Color3, parent: Instance)
	local hoop = Instance.new("Model")
	hoop.Name = "GoalHoop"
	addSolids(goal.rim, "Rim", color, hoop)
	hoop.WorldPivot = goal.frame
	hoop:SetAttribute(Tags.Attribute.OpeningRadius, goal.openingRadius)
	hoop:AddTag(Tags.GoalHoop)
	hoop.Parent = parent

	local panel = addSolid(goal.panel, "GoalPanel", color, parent)
	panel.Transparency = PANEL_TRANSPARENCY
	panel:AddTag(Tags.GoalPanel)
end

local function buildSpawns(geometry: Geometry.ArenaGeometry, ui: Config.UIConfig, parent: Instance)
	for _, team: Team.Team in Team.list do
		for index, frame in geometry.teamSpawns[team] do
			local pad = addGhost(`{team}{index}`, frame, SPAWN_PAD_SIZE, SPAWN_PAD_TRANSPARENCY, parent)
			pad.Color = ui.teamColors[team]
			pad:SetAttribute(Tags.Attribute.Team, team)
			pad:AddTag(Tags.TeamSpawn)
		end
	end
	for index, frame in geometry.ballSpawns do
		addGhost(`Ball{index}`, frame, BALL_SPAWN_SIZE, 1, parent):AddTag(Tags.BallSpawn)
	end
end

function Builder.build(geometry: Geometry.ArenaGeometry, config: Config.GameConfig, parent: Instance): Model
	validate(geometry)
	local colors = config.Arena.colors
	local model = Instance.new("Model")
	model.Name = "Arena"

	addSolids(geometry.surface, "Surface", colors.surface, newFolder("Surface", model))
	addSolids(geometry.infield, "Infield", colors.infield, newFolder("Infield", model))

	local gates = newFolder("Gates", model)
	for index, gate in geometry.gates do
		local size = Vector3.new(gate.width, gate.height, GATE_THICKNESS)
		local part = addGhost(`Gate{index}`, gate.frame, size, 1, gates)
		part:SetAttribute(Tags.Attribute.GateIndex, index)
		part:AddTag(Tags.LapGate)
	end

	buildGoal(geometry.goal, colors.goal, newFolder("Goal", model))

	local markers = newFolder("Markers", model)
	for index, piece in geometry.markers do
		local marker = addSolid(piece, `Marker{index}`, colors.marker, markers)
		marker:SetAttribute(Tags.Attribute.GateIndex, index)
		marker:AddTag(Tags.CornerMarker)
	end

	buildSpawns(geometry, config.UI, newFolder("Spawns", model))

	model.Parent = parent
	return model
end

return Builder
