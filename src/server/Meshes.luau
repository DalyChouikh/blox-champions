--!strict
-- The meshes the server's looks are drawn with (the ball's, BallLook; the goal's, GoalLook), asked of Roblox's asset
-- service. A mesh's download yields, and a start held up by one let Roblox load a joining player's default character
-- before CharacterService turned that off (found in Play, #400), so they are only ever asked for in the background.

local AssetService = game:GetService("AssetService")

-- A mesh to ask for, and whether it is solid (collides) or only draws.
export type Request = { id: string, solid: boolean }

-- Makes the MeshPart for a mesh id: Roblox's service, or a stand-in that never reaches it (tests).
export type Make = (id: string, solid: boolean) -> MeshPart

local Meshes = {}

-- The collision shape a mesh is made with. A solid one gets Roblox's Default shape: on the goal's housing it kept
-- the opening open (its tunnel wall at 9.0, the opening's radius) in 0.43 s a make, measured, where the precise kind
-- took ~31 s every make (#422). One that only draws never collides, so its shape is never built in full: a box.
function Meshes.fidelity(solid: boolean): Enum.CollisionFidelity
	return if solid then Enum.CollisionFidelity.Default else Enum.CollisionFidelity.Box
end

-- Roblox's MeshPart for `id`, solid or only drawing.
function Meshes.make(id: string, solid: boolean): MeshPart
	return AssetService:CreateMeshPartAsync(Content.fromUri(id), {
		CollisionFidelity = Meshes.fidelity(solid),
		RenderFidelity = Enum.RenderFidelity.Precise,
	})
end

-- Asks `make` for each of `ids` in turn in a task of its own, so the caller goes on at once. Once all have come,
-- `done` gets them in the ids' order; at the first that does not, `failed` gets its id and why, the rest are not asked
-- for, and those that came are destroyed.
function Meshes.fetch(
	requests: { Request },
	make: Make,
	done: (meshes: { MeshPart }) -> (),
	failed: (id: string, why: string) -> ()
)
	task.spawn(function()
		local meshes: { MeshPart } = {}
		for _, request in requests do
			local id = request.id
			local ok, made = pcall(make, id, request.solid)
			if not ok then
				for _, mesh in meshes do
					mesh:Destroy()
				end
				failed(id, tostring(made))
				return
			end
			table.insert(meshes, made)
		end
		done(meshes)
	end)
end

return Meshes
