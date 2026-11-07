--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Meshes = require(ServerScriptService.Server.Meshes)

-- A mesh maker that never reaches Roblox: each id it is asked for is noted, and gets a MeshPart named after it.
local function maker(asked: { string }, wait: BindableEvent?): Meshes.Make
	return function(id: string, _solid: boolean): MeshPart
		table.insert(asked, id)
		if wait ~= nil then
			wait.Event:Wait()
		end
		local mesh = Instance.new("MeshPart")
		mesh.Name = id
		return mesh
	end
end

-- Requests for the meshes `ids`, none solid.
local function requests(ids: { string }): { Meshes.Request }
	local made: { Meshes.Request } = {}
	for _, id in ids do
		table.insert(made, { id = id, solid = false })
	end
	return made
end

-- #422, measured in Studio: a mesh's Default collision kept the goal's opening open (the tunnel wall at 9.0, its
-- radius) in 0.43 s a make; the precise kind took ~31 s every make. A look that never collides needs no shape: Box.
describe("Meshes.fidelity", function()
	it("gives a solid mesh Roblox's Default collision and one that only draws a box", function()
		expect(Meshes.fidelity(true)).toBe(Enum.CollisionFidelity.Default)
		expect(Meshes.fidelity(false)).toBe(Enum.CollisionFidelity.Box)
	end)
end)

describe("Meshes.fetch", function()
	-- #422 (the owner's Q335-Q337): a solid mesh is made with its collision shape, the rest only draw.
	it("asks for each mesh with whether it is solid", function()
		local seen: { string } = {}
		Meshes.fetch(
			{ { id = "a", solid = true }, { id = "b", solid = false } },
			function(id: string, solid: boolean): MeshPart
				table.insert(seen, `{id} {solid}`)
				return Instance.new("MeshPart")
			end,
			function(_meshes: { MeshPart }) end,
			function(_id: string, _why: string)
				error("nothing fails here")
			end
		)
		task.wait()
		expect(seen).toEqual({ "a true", "b false" })
	end)

	-- Found in Play (#400): a start held up by a mesh's download let Roblox load a joining player's default character.
	it("never holds up its caller, then hands over every mesh in the ids' order once all have come", function()
		local asked: { string } = {}
		local arrived = Instance.new("BindableEvent")
		local got: { MeshPart }? = nil
		Meshes.fetch(requests({ "a", "b", "c" }), maker(asked, arrived), function(meshes: { MeshPart })
			got = meshes
		end, function(_id: string, _why: string)
			error("nothing fails here")
		end)
		expect(asked).toEqual({ "a" })
		expect(got).toBeNil()
		for _ = 1, 3 do
			arrived:Fire()
			task.wait()
		end
		expect(asked).toEqual({ "a", "b", "c" })
		local meshes = got :: { MeshPart }
		expect(#meshes).toBe(3)
		expect({ meshes[1].Name, meshes[2].Name, meshes[3].Name }).toEqual({ "a", "b", "c" })
		arrived:Destroy()
	end)

	it("stops at the first mesh that does not come: says which and why once, and keeps none of the others", function()
		local asked: { string } = {}
		local made: { MeshPart } = {}
		local fails: { string } = {}
		local doneCalled = false
		Meshes.fetch(requests({ "a", "b", "c" }), function(id: string, _solid: boolean): MeshPart
			table.insert(asked, id)
			if id == "b" then
				error("HTTP 403 (Forbidden)", 0)
			end
			local mesh = Instance.new("MeshPart")
			table.insert(made, mesh)
			return mesh
		end, function(_meshes: { MeshPart })
			doneCalled = true
		end, function(id: string, why: string)
			table.insert(fails, `{id}: {why}`)
		end)
		task.wait()
		expect(asked).toEqual({ "a", "b" })
		expect(fails).toEqual({ "b: HTTP 403 (Forbidden)" })
		expect(doneCalled).toBe(false)
		-- The one that came is let go: destroyed, its parent locked (tried on a folder outside the game).
		expect(#made).toBe(1)
		local movable = pcall(function()
			made[1].Parent = Instance.new("Folder")
		end)
		expect(movable).toBe(false)
	end)
end)
