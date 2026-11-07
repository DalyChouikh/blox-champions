--!strict
-- Turns the pure arena geometry into anchored, tagged parts (spec §9.2). Every piece is checked before any part
-- is created, and the model is assembled unparented and parented last, so a failed build leaves nothing in the
-- place (spec §13). The goal's meshes come later (GoalLook): dressGoal puts them on the built goal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(ReplicatedStorage.Shared.Config.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local DrawOnly = require(ReplicatedStorage.Shared.Util.DrawOnly)
local Finite = require(ReplicatedStorage.Shared.Util.Finite)
local Geometry = require(ReplicatedStorage.Shared.Arena.Geometry)
local GoalDoor = require(ReplicatedStorage.Shared.Arena.Geometry.GoalDoor)
local PartSize = require(ReplicatedStorage.Shared.Util.PartSize)
local PartsOf = require(ReplicatedStorage.Shared.Util.PartsOf)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local Types = require(ReplicatedStorage.Shared.Arena.Geometry.Types)

type ArenaConfig = Config.ArenaConfig
type Piece = Types.Piece

-- Invisible parts: the tag-only gates, an open map's ceiling, and the goal ring's blocks and panel under its meshes.
local HIDDEN = 1

local Builder = {}

-- What is wrong with a piece Roblox could not build as given, or nil.
local function problemWith(piece: Piece): string?
	local size = piece.size
	local fits = math.min(size.X, size.Y, size.Z) >= PartSize.MIN and math.max(size.X, size.Y, size.Z) <= PartSize.MAX
	if not (Finite.vector(size) and fits) then
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
		{ name = "surface glass", pieces = geometry.surfaceGlass },
		{ name = "glass", pieces = geometry.glass },
		{ name = "top", pieces = geometry.top },
		{ name = "infield", pieces = geometry.infield },
		{ name = "goal rim", pieces = geometry.goal.rim },
		{ name = "goal panel", pieces = { geometry.goal.panel } },
	}
	for index, panel in geometry.gatePanels do
		table.insert(groups, { name = `gate panel {index}`, pieces = panel.pieces })
	end
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
	local part = DrawOnly(newPart("Block", name, cframe, size))
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

-- A folder of solids carrying `tag` on the folder: what they are to the game (Tags.RideSurface, Tags.Barrier).
local function addTaggedSolids(pieces: { Piece }, name: string, tag: string, color: Color3, parent: Instance): Folder
	local folder = newFolder(name, parent)
	folder:AddTag(tag)
	addSolids(pieces, name, color, folder)
	return folder
end

-- Glass is see-through and casts no shadow, or 120 studs of it would keep the track in its shade (a roof that did was
-- seen in a playtest). Its material is the map's (Config.Arena.glass).
local function lookLikeGlass(part: BasePart, arena: ArenaConfig)
	part.Material = arena.glass.material
	part.Transparency = arena.glass.transparency
	part.CastShadow = false
end

-- Solids in the glass's colour and look (lookLikeGlass), named `prefix` and their index.
local function addGlassLooking(pieces: { Piece }, prefix: string, arena: ArenaConfig, parent: Instance)
	for index, piece in pieces do
		lookLikeGlass(addSolid(piece, `{prefix}{index}`, arena.colors.glass, parent), arena)
	end
end

-- The glass (R5): a ride surface like the floor, so skaters ride it and their rays find it, and the ball bounces off it
-- and ends its flight on its touch; only its look is glass's. Tagged Glass too: no climb holds on it (#299).
local function addGlass(pieces: { Piece }, arena: ArenaConfig, parent: Instance)
	local folder = newFolder("Glass", parent)
	folder:AddTag(Tags.RideSurface)
	folder:AddTag(Tags.Glass)
	addGlassLooking(pieces, "Glass", arena, folder)
end

-- The top (R14): skaters and the ball bounce off it and the collider's sweep finds it, and it is touchable, so the
-- ball's flight (a pass's lift included) ends on it: Roblox fires a touch only between two parts that can both touch.
-- A closed map's roof looks like the glass; an open map's ceiling and strips are invisible, casting no shadow either.
local function addTop(pieces: { Piece }, arena: ArenaConfig, parent: Instance)
	local folder = addTaggedSolids(pieces, "Top", Tags.Barrier, arena.colors.glass, parent)
	for _, child in folder:GetChildren() do
		local part = child :: BasePart
		if arena.top.kind == "Open" then
			part.Transparency = HIDDEN
			part.CastShadow = false
		else
			lookLikeGlass(part, arena)
		end
	end
end

-- The gate panels (R18): thin glass walls across the track that nothing hits, sees or touches, so skaters pass through
-- them. Each is a model carrying CornerMarker and its GateIndex, pivoted at the wall's middle, so ArenaGlow lights it
-- and the carrier's arrow points at it.
local function addGatePanels(panels: { Types.GatePanel }, arena: ArenaConfig, parent: Instance)
	for gate, panel in panels do
		local model = Instance.new("Model")
		model.Name = `GatePanel{gate}`
		for index, piece in panel.pieces do
			lookLikeGlass(DrawOnly(addSolid(piece, `Pane{index}`, arena.colors.glass, model)), arena)
		end
		model.WorldPivot = panel.pivot
		model:SetAttribute(Tags.Attribute.GateIndex, gate)
		model:AddTag(Tags.CornerMarker)
		model.Parent = parent
	end
end

-- The goal (Arena spec §5.3): the hoop, a ring of blocks that gives the ring its collision and the rules its opening
-- (its pivot and OpeningRadius), and the panel that shuts it. Until the goal's meshes come (dressGoal) the blocks are
-- its look too, glowing while the goal is open.
local function buildGoal(goal: Types.Goal, arena: ArenaConfig, parent: Instance)
	local color = arena.colors.goal
	local hoop = Instance.new("Model")
	hoop.Name = "GoalHoop"
	addSolids(goal.rim, "Rim", color, hoop)
	hoop.WorldPivot = goal.frame
	hoop:SetAttribute(Tags.Attribute.OpeningRadius, goal.openingRadius)
	hoop:AddTag(Tags.GoalHoop)
	hoop:AddTag(Tags.GoalGlow)
	hoop.Parent = parent

	local panel = addSolid(goal.panel, "GoalPanel", color, parent)
	panel.Transparency = arena.goal.panelTransparency
	panel:AddTag(Tags.GoalPanel)
	-- The shut goal stops a skater as it stops the ball (#422); open, MatchService turns its collision and queries off.
	panel:AddTag(Tags.Barrier)
end

local function buildSpawns(geometry: Geometry.ArenaGeometry, config: Config.GameConfig, parent: Instance)
	local pad = config.Arena.spawnPad
	local padSize = Vector3.new(pad.width, pad.thickness, pad.width)
	for _, team: Team.Team in Team.list do
		for index, frame in geometry.teamSpawns[team] do
			local part = addGhost(`{team}{index}`, frame, padSize, pad.transparency, parent)
			part.Color = config.UI.teamColors[team]
			part:SetAttribute(Tags.Attribute.Team, team)
			part:AddTag(Tags.TeamSpawn)
		end
	end
end

function Builder.build(geometry: Geometry.ArenaGeometry, config: Config.GameConfig, parent: Instance): Model
	validate(geometry)
	local arena = config.Arena
	local colors = arena.colors
	local model = Instance.new("Model")
	model.Name = "Arena"
	-- Every client gets the whole arena soon after joining and never loses it, so client code can rely on it.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	-- Skaters' rays hit the ride surfaces only (the solid surface and the glass): not the top, and not the infield
	-- behind the glass, which no skater reaches. The surface above each wall's glass line only looks like the glass:
	-- in the Surface folder, not tagged Glass, it is climbed as before (Q309).
	local surface = addTaggedSolids(geometry.surface, "Surface", Tags.RideSurface, colors.surface, model)
	addGlassLooking(geometry.surfaceGlass, "SurfaceGlass", arena, surface)
	addGlass(geometry.glass, arena, model)
	addTop(geometry.top, arena, model)
	addSolids(geometry.infield, "Infield", colors.infield, newFolder("Infield", model))

	local gates = newFolder("Gates", model)
	for index, gate in geometry.gates do
		local size = Vector3.new(gate.width, gate.height, arena.gateThickness)
		local part = addGhost(`Gate{index}`, gate.frame, size, HIDDEN, gates)
		part:SetAttribute(Tags.Attribute.GateIndex, index)
		part:AddTag(Tags.LapGate)
	end

	buildGoal(geometry.goal, arena, newFolder("Goal", model))

	addGatePanels(geometry.gatePanels, arena, newFolder("GatePanels", model))

	buildSpawns(geometry, config, newFolder("Spawns", model))

	model.Parent = parent
	return model
end

-- Puts the goal's meshes (the Halo pylon, #410; in Arena.goalPieces' order) on a built goal: each at its box in the
-- hoop's frame, in its look, solid or only drawing (Arena.goal.solid, #422), in a GoalLook model beside the hoop, with
-- the door that shuts the opening (Q324), whose bars' ends the housing hides: solid, in the goal's colour, only
-- drawing, in a model tagged GoalDoor. The ring's blocks and the panel then hide, keeping the ring's collision, the
-- rules' opening and the shut goal's wall, and what glows while the goal is open moves from the blocks to the pieces
-- whose look glows.
function Builder.dressGoal(hoop: PVInstance, panel: BasePart, meshes: { MeshPart }, arena: ArenaConfig)
	local goal = arena.goal
	local frame = hoop:GetPivot()
	local look = Instance.new("Model")
	look.Name = "GoalLook"
	for index, name in Arena.goalPieces do
		-- A solid piece stops skaters and the ball by its own shape (a barrier, never ridden: #422); the rest draw.
		local mesh = meshes[index]
		if goal.solid[name] then
			mesh:AddTag(Tags.Barrier)
		else
			DrawOnly(mesh)
		end
		local box, wanted = goal.pieces[name], goal.looks[name]
		mesh.Name = name
		mesh.Anchored = true
		mesh.Size = box.size
		mesh.CFrame = frame * CFrame.new(box.centre)
		mesh.Color = wanted.color
		mesh.Material = wanted.material
		if wanted.glows then
			mesh:AddTag(Tags.GoalGlow)
		end
		mesh.Parent = look
	end
	local door = Instance.new("Model")
	door.Name = "GoalDoor"
	for index, bar in GoalDoor.bars(arena) do
		DrawOnly(
			addSolid(
				{ shape = bar.shape, cframe = frame * bar.cframe, size = bar.size },
				`Bar{index}`,
				arena.colors.goal,
				door
			)
		)
	end
	door:AddTag(Tags.GoalDoor)
	door.Parent = look
	for _, block in PartsOf(hoop) do
		block.Transparency = HIDDEN
	end
	panel.Transparency = HIDDEN
	hoop:RemoveTag(Tags.GoalGlow)
	look.Parent = hoop.Parent
end

return Builder
