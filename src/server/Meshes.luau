--!strict
-- The meshes the server's looks are drawn with (the ball's, BallLook; the goal's, GoalLook), asked of Roblox's asset
-- service. A mesh's download yields, and a start held up by one let Roblox load a joining player's default character
-- before CharacterService turned that off (found in Play, #400), so they are only ever asked for in the background.

local AssetService = game:GetService("AssetService")

-- Makes the MeshPart for a mesh id: Roblox's service, or a stand-in that never reaches it (tests).
export type Make = (id: string) -> MeshPart

local Meshes = {}

-- Roblox's MeshPart for `id`. Box: a look never collides, so its collision shape is never built in full.
function Meshes.make(id: string): MeshPart
	return AssetService:CreateMeshPartAsync(Content.fromUri(id), {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Precise,
	})
end

-- Asks `make` for each of `ids` in turn in a task of its own, so the caller goes on at once. Once all have come,
-- `done` gets them in the ids' order; at the first that does not, `failed` gets its id and why, the rest are not asked
-- for, and those that came are destroyed.
function Meshes.fetch(
	ids: { string },
	make: Make,
	done: (meshes: { MeshPart }) -> (),
	failed: (id: string, why: string) -> ()
)
	task.spawn(function()
		local meshes: { MeshPart } = {}
		for _, id in ids do
			local ok, made = pcall(make, id)
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
