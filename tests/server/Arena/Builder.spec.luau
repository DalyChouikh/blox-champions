--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Builder = require(game:GetService("ServerScriptService").Server.Arena.Builder)
local Config = require(ReplicatedStorage.Shared.Config)
local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Features = require(ReplicatedStorage.Shared.Arena.Geometry.Features)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Geometry = require(ReplicatedStorage.Shared.Arena.Geometry)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local config = Config.defaults()
local parent: Folder
beforeEach(function()
	parent = Instance.new("Folder")
	parent.Name = "BuilderTest"
	parent.Parent = ServerStorage
end)
afterEach(function()
	parent:Destroy()
end)

local function folder(arena: Instance, name: string): Folder
	return arena:FindFirstChild(name) :: Folder
end

-- The look every glass part takes (R5): the glass's material and transparency, in its colour.
local function looksLikeGlass(part: BasePart, arena: Config.ArenaConfig): boolean
	return part.Material == arena.glass.material
		and part.Color == arena.colors.glass
		and math.abs(part.Transparency - arena.glass.transparency) < 1e-4
end

describe("Builder.build", function()
	it("builds one part per piece, grouped by what it is", function()
		local geometry = Geometry.build(config)
		local arena = Builder.build(geometry, config, parent)
		expect(arena.Parent).toBe(parent)
		expect(#folder(arena, "Surface"):GetChildren()).toBe(#geometry.surface + #geometry.surfaceGlass)
		expect(#folder(arena, "Glass"):GetChildren()).toBe(#Features.glass(config.Arena))
		expect(arena:FindFirstChild("Barriers")).toBeNil()
		expect(#folder(arena, "Top"):GetChildren()).toBe(#geometry.top)
		expect(#folder(arena, "Infield"):GetChildren()).toBe(#geometry.infield)
		expect(#folder(arena, "Gates"):GetChildren()).toBe(4)
		local panels = folder(arena, "GatePanels")
		expect(#panels:GetChildren()).toBe(4)
		for gate, panel in geometry.gatePanels do
			expect(#(panels:FindFirstChild(`GatePanel{gate}`) :: Model):GetChildren()).toBe(#panel.pieces)
		end
		expect(arena:FindFirstChild("Markers")).toBeNil()
		expect(#folder(arena, "Spawns"):GetChildren()).toBe(6)
		-- The hoop and its panel (#410: the arm went; the Halo pylon's meshes come in the background).
		expect(#folder(arena, "Goal"):GetChildren()).toBe(2)
		local hoop = folder(arena, "Goal"):FindFirstChild("GoalHoop") :: Model
		expect(#hoop:GetChildren()).toBe(16)
	end)

	it("makes gates and spawns invisible to physics and queries, and solids smooth and anchored", function()
		local arena = Builder.build(Geometry.build(config), config, parent)
		local gate = folder(arena, "Gates"):FindFirstChild("Gate2") :: Part
		expect(gate.Transparency).toBe(1)
		expect(gate.CanCollide or gate.CanQuery or gate.CanTouch).toBe(false)
		expect(gate:GetAttribute("GateIndex")).toBe(2)
		local pad = folder(arena, "Spawns"):FindFirstChild("Blue1") :: Part
		expect(pad.CanCollide or pad.CanQuery or pad.CanTouch).toBe(false)
		expect(pad.Color).toEqual(config.UI.teamColors.Blue)
		for _, part in folder(arena, "Surface"):GetChildren() do
			local solid = part :: BasePart
			if not (solid.Anchored and solid.CanCollide and solid.TopSurface == Enum.SurfaceType.Smooth) then
				error(`{solid.Name} is not an anchored, colliding, smooth part`)
			end
		end
	end)

	-- Skaters ride the glass (R5), their rays find it, the ball bounces off it and its flight ends on its touch.
	it("makes the glass a ride surface that looks like glass, which skaters, the ball and touches all meet", function()
		local arena = Builder.build(Geometry.build(config), config, parent)
		local glassFolder = folder(arena, "Glass")
		expect(glassFolder:HasTag(Tags.RideSurface)).toBe(true)
		expect(glassFolder:HasTag(Tags.Barrier)).toBe(false)
		-- Only the glass is Glass: no climb holds on it (#299).
		expect(glassFolder:HasTag(Tags.Glass)).toBe(true)
		expect(folder(arena, "Surface"):HasTag(Tags.Glass)).toBe(false)
		for _, part in glassFolder:GetChildren() do
			local glass = part :: BasePart
			if
				not (
					glass.Anchored
					and looksLikeGlass(glass, config.Arena)
					and glass.CanCollide
					and glass.CanQuery
					and glass.CanTouch
				)
			then
				error(`{glass.Name} does not look or act like glass`)
			end
		end
	end)

	-- Q309: the walls look like the glass from their lines up (Config.Arena.glassLook), ridden and climbed as the rest
	-- of the surface: in its folder, which is not Glass, so climbing is unchanged.
	it("makes the walls look like the glass above their lines, still ridden and climbed as the surface", function()
		local geometry = Geometry.build(config)
		local surface = folder(Builder.build(geometry, config, parent), "Surface")
		expect(surface:HasTag(Tags.RideSurface)).toBe(true)
		expect(surface:HasTag(Tags.Glass)).toBe(false)
		local solids, glassLooking = 0, 0
		for _, child in surface:GetChildren() do
			local part = child :: BasePart
			local solidIndex = tonumber(string.match(part.Name, "^Surface(%d+)$"))
			local glassIndex = tonumber(string.match(part.Name, "^SurfaceGlass(%d+)$"))
			local piece = if glassIndex ~= nil
				then geometry.surfaceGlass[glassIndex]
				elseif solidIndex ~= nil then geometry.surface[solidIndex]
				else nil
			local placed = piece ~= nil
				and (part.Position - piece.cframe.Position).Magnitude < 1e-3
				and (part.Size - piece.size).Magnitude < 1e-3
			local ridden = part.Anchored and part.CanCollide and part.CanQuery and part.CanTouch
			if glassIndex ~= nil then
				glassLooking += 1
				if not (placed and ridden and looksLikeGlass(part, config.Arena) and not part.CastShadow) then
					error(`{part.Name} does not look like the glass where its piece is, ridden as the surface`)
				end
			else
				solids += 1
				local solidLook = part.Color == config.Arena.colors.surface
					and part.Material == Enum.Material.SmoothPlastic
					and part.Transparency == 0
					and part.CastShadow
				if not (placed and ridden and solidLook) then
					error(`{part.Name} is not a solid surface part where its piece is`)
				end
			end
		end
		expect({ solids, glassLooking }).toEqual({ #geometry.surface, #geometry.surfaceGlass })
	end)

	-- Skaters pass through the gate walls (R18), and ArenaGlow and the carrier's arrow find them by their tag.
	it(
		"makes each gate's panel a model carrying CornerMarker and its GateIndex, of glass nothing hits, sees or "
			.. "touches",
		function()
			local geometry = Geometry.build(config)
			local arena = Builder.build(geometry, config, parent)
			for gate = 1, Centerline.gateCount do
				local panel = folder(arena, "GatePanels"):FindFirstChild(`GatePanel{gate}`) :: Model
				expect(panel:IsA("Model")).toBe(true)
				expect(panel:HasTag(Tags.CornerMarker)).toBe(true)
				expect(panel:GetAttribute(Tags.Attribute.GateIndex)).toBe(gate)
				Fixtures.expectNear(panel:GetPivot().Position, geometry.gatePanels[gate].pivot.Position)
				for _, child in panel:GetChildren() do
					local pane = child :: BasePart
					if
						not (
							pane.Anchored
							and looksLikeGlass(pane, config.Arena)
							and not (pane.CanCollide or pane.CanQuery or pane.CanTouch or pane.CastShadow)
						)
					then
						error(`{panel.Name}.{pane.Name} is not glass that nothing hits, sees or touches`)
					end
				end
			end
		end
	)

	-- The top (A7): skaters and the ball bounce off it, and its touch ends a flight (a pass's lift included), so no
	-- ball glides along it; no ray looking for ground or a view sees it.
	it("closes the arena with a top that skaters and the ball bounce off and touch, which no ray sees", function()
		local function expectTop(arena: Model, looks: (part: BasePart) -> boolean)
			local top = folder(arena, "Top")
			expect(top:HasTag(Tags.Barrier)).toBe(true)
			expect(top:HasTag(Tags.RideSurface)).toBe(false)
			for _, child in top:GetChildren() do
				local part = child :: BasePart
				if not (part.Anchored and part.CanCollide and part.CanQuery and part.CanTouch and looks(part)) then
					error(`{part.Name} does not close the arena`)
				end
			end
		end
		expectTop(Builder.build(Geometry.build(config), config, parent), function(part: BasePart): boolean
			return looksLikeGlass(part, config.Arena)
		end)
		local open = Fixtures.config({ Arena = { top = { kind = "Open" } } })
		expectTop(Builder.build(Geometry.build(open), open, parent), function(part: BasePart): boolean
			return part.Transparency == 1 and not part.CastShadow
		end)
	end)

	-- The look is the map's (R5): the default is clear plastic, since Roblox's Glass material hides every non-opaque
	-- part behind it, and any other look reaches every glass part.
	it("takes the glass's look from config: the walls, a closed map's roof and the gate panels", function()
		local custom = Fixtures.config({ Arena = { glass = { material = Enum.Material.Glass, transparency = 0.5 } } })
		local arena = Builder.build(Geometry.build(custom), custom, parent)
		local checked = 0
		for _, name in { "Glass", "Top", "GatePanels" } do
			for _, child in folder(arena, name):GetDescendants() do
				if child:IsA("BasePart") then
					checked += 1
					if not looksLikeGlass(child, custom.Arena) then
						error(`{child.Name} in {name} does not take the configured glass look`)
					end
				end
			end
		end
		-- And the walls above their glass lines (Q309).
		local glassLooking = 0
		for _, child in folder(arena, "Surface"):GetChildren() do
			if string.match(child.Name, "^SurfaceGlass") then
				glassLooking += 1
				if not looksLikeGlass(child :: BasePart, custom.Arena) then
					error(`{child.Name} in Surface does not take the configured glass look`)
				end
			end
		end
		expect(checked > 0 and glassLooking > 0).toBe(true)
	end)

	-- A roof that cast shadows kept the whole track in its shade (seen in a playtest); 120 studs of glass would too.
	it("lets the light in: the glass and the top cast no shadow, while the track still does", function()
		local arena = Builder.build(Geometry.build(config), config, parent)
		for _, name in { "Glass", "Top" } do
			for _, part in folder(arena, name):GetChildren() do
				if (part :: BasePart).CastShadow then
					error(`{part.Name} casts a shadow`)
				end
			end
		end
		expect((folder(arena, "Surface"):GetChildren()[1] :: BasePart).CastShadow).toBe(true)
	end)

	it("tags the riding surfaces so skaters' rays find only them", function()
		local arena = Builder.build(Geometry.build(config), config, parent)
		local tagged: { string } = {}
		for _, instance in arena:GetDescendants() do
			if instance:HasTag(Tags.RideSurface) then
				table.insert(tagged, instance.Name)
			end
		end
		table.sort(tagged)
		-- The glass is ridden too; not the top, and not the infield behind the glass, which no skater reaches.
		expect(tagged).toEqual({ "Glass", "Surface" })
	end)

	it("sends the whole arena to every client and never streams it out", function()
		local arena = Builder.build(Geometry.build(config), config, parent)
		expect(arena.ModelStreamingMode).toBe(Enum.ModelStreamingMode.Persistent)
	end)

	it("takes the tag-only parts' sizes and the goal panel's transparency from config", function()
		local custom = Fixtures.config({
			Arena = {
				gateThickness = 0.5,
				spawnPad = { width = 6, thickness = 0.3, transparency = 0.2 },
				goal = { panelTransparency = 0.6 },
			},
		})
		local arena = Builder.build(Geometry.build(custom), custom, parent)
		expect((folder(arena, "Gates"):FindFirstChild("Gate1") :: Part).Size.Z).toBeCloseTo(0.5, 4)
		local pad = folder(arena, "Spawns"):FindFirstChild("Orange2") :: Part
		expect(pad.Size).toEqual(Vector3.new(6, 0.3, 6))
		expect(pad.Transparency).toBeCloseTo(0.2, 4)
		expect((folder(arena, "Goal"):FindFirstChild("GoalPanel") :: Part).Transparency).toBeCloseTo(0.6, 4)
	end)

	it("leaves nothing behind when a piece is invalid", function()
		local geometry = Geometry.build(config)
		local broken = table.clone(geometry)
		broken.surface = table.clone(geometry.surface)
		broken.surface[2] = { shape = "Block", cframe = CFrame.identity, size = Vector3.new(0, 1, 1) }
		expect(function()
			Builder.build(broken, config, parent)
		end).toThrow("ArenaBuilder: surface piece 2 is invalid (size 0, 1, 1)")
		local cracked = table.clone(geometry)
		cracked.surfaceGlass = table.clone(geometry.surfaceGlass)
		cracked.surfaceGlass[3] = { shape = "Wedge", cframe = CFrame.identity, size = Vector3.new(1, 1, 0) }
		expect(function()
			Builder.build(cracked, config, parent)
		end).toThrow("ArenaBuilder: surface glass piece 3 is invalid (size 1, 1, 0)")
		local adrift = table.clone(geometry)
		adrift.infield = { { shape = "Block", cframe = CFrame.new(0 / 0, 0, 0), size = Vector3.one } }
		expect(function()
			Builder.build(adrift, config, parent)
		end).toThrow("ArenaBuilder: infield piece 1 is invalid (cframe ")
		-- Roblox would silently clamp it to 2048, leaving a hole.
		local oversized = table.clone(geometry)
		oversized.glass = { { shape = "Block", cframe = CFrame.identity, size = Vector3.new(3000, 1, 1) } }
		expect(function()
			Builder.build(oversized, config, parent)
		end).toThrow("ArenaBuilder: glass piece 1 is invalid (size 3000, 1, 1)")
		local flatTop = table.clone(geometry)
		flatTop.top = { { shape = "Block", cframe = CFrame.identity, size = Vector3.new(1, 0, 1) } }
		expect(function()
			Builder.build(flatTop, config, parent)
		end).toThrow("ArenaBuilder: top piece 1 is invalid (size 1, 0, 1)")
		local thinPanel = table.clone(geometry)
		thinPanel.gatePanels = table.clone(geometry.gatePanels)
		thinPanel.gatePanels[3] = {
			pieces = { { shape = "Block", cframe = CFrame.identity, size = Vector3.new(1, 1, 0) } },
			pivot = CFrame.identity,
		}
		expect(function()
			Builder.build(thinPanel, config, parent)
		end).toThrow("ArenaBuilder: gate panel 3 piece 1 is invalid (size 1, 1, 0)")
		expect(#parent:GetChildren()).toBe(0)
	end)

	-- Until the Halo pylon's meshes come (GoalLook), the ring's blocks are the goal's look, as before #410: they show
	-- in the goal's colour, give the ring its collision, and glow while the goal is open.
	it("builds the ring's blocks as the goal's look until its meshes come: shown, solid, glowing when open", function()
		local hoop = folder(Builder.build(Geometry.build(config), config, parent), "Goal"):FindFirstChild("GoalHoop")
		local model = hoop :: Model
		expect(model:HasTag(Tags.GoalHoop)).toBe(true)
		expect(model:HasTag(Tags.GoalGlow)).toBe(true)
		for _, child in model:GetChildren() do
			local rim = child :: BasePart
			if not (rim.Transparency == 0 and rim.Color == config.Arena.colors.goal and rim.CanCollide) then
				error(`{rim.Name} is not a shown, solid block in the goal's colour`)
			end
		end
	end)
end)

-- The Halo pylon (#410, the owner's Q314-Q315): four meshes made once in Blender, placed where the build put them.
describe("Builder.dressGoal", function()
	local Arena = require(ReplicatedStorage.Shared.Config.Arena)

	-- The goal folder of an arena built from `built`, and stand-ins for the four meshes in the build's order.
	local function goalAndMeshes(built: Config.GameConfig): (Folder, { MeshPart })
		local goal = folder(Builder.build(Geometry.build(built), built, parent), "Goal")
		local meshes: { MeshPart } = {}
		for _ in Arena.goalPieces do
			table.insert(meshes, Instance.new("MeshPart"))
		end
		return goal, meshes
	end

	it("places each mesh at its box in the goal's frame, in its look, only drawing, beside the hoop", function()
		local goal, meshes = goalAndMeshes(config)
		local hoop = goal:FindFirstChild("GoalHoop") :: Model
		local frame = hoop:GetPivot()
		Builder.dressGoal(hoop, meshes, config.Arena)
		local look = goal:FindFirstChild("GoalLook") :: Model
		expect(look:IsA("Model")).toBe(true)
		expect(#look:GetChildren()).toBe(4)
		for index, name in Arena.goalPieces do
			local mesh = meshes[index]
			local box = config.Arena.goal.pieces[name]
			local wanted = config.Arena.goal.looks[name]
			expect(mesh.Name).toBe(name)
			expect(mesh.Parent == look).toBe(true)
			expect(mesh.Size).toEqual(box.size)
			Fixtures.expectNear(mesh.Position, (frame * CFrame.new(box.centre)).Position)
			Fixtures.expectNear(mesh.CFrame.LookVector, frame.LookVector)
			Fixtures.expectNear(mesh.CFrame.UpVector, frame.UpVector)
			expect(mesh.Color).toEqual(wanted.color)
			expect(mesh.Material).toBe(wanted.material)
			expect(mesh.Anchored).toBe(true)
			expect(mesh.CanCollide or mesh.CanQuery or mesh.CanTouch).toBe(false)
		end
	end)

	-- G4: skaters and the ball meet the ring's shape, not the mesh's every face, and the rules keep their opening.
	it("hides the ring's blocks, which keep the ring's collision and the rules' opening", function()
		local goal, meshes = goalAndMeshes(config)
		local hoop = goal:FindFirstChild("GoalHoop") :: Model
		local pivot = hoop:GetPivot()
		Builder.dressGoal(hoop, meshes, config.Arena)
		expect(#hoop:GetChildren()).toBe(16)
		for _, child in hoop:GetChildren() do
			local rim = child :: BasePart
			if not (rim.Transparency == 1 and rim.CanCollide and rim.CanQuery and rim.CanTouch) then
				error(`{rim.Name} is not a hidden block that still collides`)
			end
		end
		expect(hoop:HasTag(Tags.GoalHoop)).toBe(true)
		expect(hoop:GetPivot()).toEqual(pivot)
		expect(hoop:GetAttribute(Tags.Attribute.OpeningRadius)).toBe(config.Arena.goal.ringRadius)
	end)

	-- G13: what glows when the goal opens is tagged, so each client finds it whenever the meshes come.
	it("moves the glow to the pieces whose look glows: the lip by default, any piece by config", function()
		local goal, meshes = goalAndMeshes(config)
		local hoop = goal:FindFirstChild("GoalHoop") :: Model
		Builder.dressGoal(hoop, meshes, config.Arena)
		expect(hoop:HasTag(Tags.GoalGlow)).toBe(false)
		local glowing: { string } = {}
		for _, mesh in meshes do
			if mesh:HasTag(Tags.GoalGlow) then
				table.insert(glowing, mesh.Name)
			end
		end
		expect(glowing).toEqual({ "Lip" })

		local strips = { color = Color3.fromRGB(14, 178, 247), material = Enum.Material.Glass, glows = true }
		local custom = Fixtures.config({ Arena = { goal = { looks = { Strips = strips } } } })
		local customGoal, customMeshes = goalAndMeshes(custom)
		Builder.dressGoal(customGoal:FindFirstChild("GoalHoop") :: Model, customMeshes, custom.Arena)
		local dressed = (customGoal:FindFirstChild("GoalLook") :: Model):FindFirstChild("Strips") :: MeshPart
		expect(dressed.Color).toEqual(strips.color)
		expect(dressed.Material).toBe(strips.material)
		expect(dressed:HasTag(Tags.GoalGlow)).toBe(true)
	end)
end)
