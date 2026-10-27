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
		expect(#folder(arena, "Surface"):GetChildren()).toBe(#geometry.surface)
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
		expect(#folder(arena, "Spawns"):GetChildren()).toBe(8)
		-- The hoop, its panel and the arm's two blocks.
		expect(#folder(arena, "Goal"):GetChildren()).toBe(4)
		local hoop = folder(arena, "Goal"):FindFirstChild("GoalHoop") :: Model
		expect(#hoop:GetChildren()).toBe(16)
	end)

	-- Arena spec §5.3: decoration in the goal's colour that skaters and the ball pass through.
	it("builds the goal's arm from blocks nothing hits, sees or touches", function()
		local geometry = Geometry.build(config)
		local goal = folder(Builder.build(geometry, config, parent), "Goal")
		expect(#geometry.goal.arm).toBe(2)
		for index, piece in geometry.goal.arm do
			local part = goal:FindFirstChild(`Arm{index}`) :: BasePart
			expect(part:IsA("Part")).toBe(true)
			Fixtures.expectNear(part.Position, piece.cframe.Position)
			Fixtures.expectNear(part.Size, piece.size)
			expect(part.Anchored and part.Color == config.Arena.colors.goal).toBe(true)
			expect(part.CanCollide or part.CanQuery or part.CanTouch).toBe(false)
		end
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
		expect(checked > 0).toBe(true)
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
				ballSpawnSize = 2,
				goal = { panelTransparency = 0.6 },
			},
		})
		local arena = Builder.build(Geometry.build(custom), custom, parent)
		expect((folder(arena, "Gates"):FindFirstChild("Gate1") :: Part).Size.Z).toBeCloseTo(0.5, 4)
		local pad = folder(arena, "Spawns"):FindFirstChild("Orange2") :: Part
		expect(pad.Size).toEqual(Vector3.new(6, 0.3, 6))
		expect(pad.Transparency).toBeCloseTo(0.2, 4)
		expect((folder(arena, "Spawns"):FindFirstChild("Ball1") :: Part).Size).toEqual(Vector3.new(2, 2, 2))
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
		local longArm = table.clone(geometry)
		longArm.goal = table.clone(geometry.goal)
		longArm.goal.arm = {
			geometry.goal.arm[1],
			{ shape = "Block", cframe = CFrame.identity, size = Vector3.new(3000, 1, 1) },
		}
		expect(function()
			Builder.build(longArm, config, parent)
		end).toThrow("ArenaBuilder: goal arm piece 2 is invalid (size 3000, 1, 1)")
		expect(#parent:GetChildren()).toBe(0)
	end)
end)
