--!strict
-- Ball skins by id (spec §9.4). M1 ships only Default; later skins are data added here, chosen by the carrier. A skin
-- is the ball's colour and its look:
-- - its colour is the ball's until a team first holds it after a kickoff; then every screen shows the colour of the
--   team that last held it (the owner, #327, Q158: Client/WorldMarkers);
-- - its look names a SurfaceAppearance in the BallLooks folder beside this module (one data file each): the skin's
--   picture over the ball mesh's paint map, laid over the ball's colour wherever the picture is see-through (Overlay,
--   #400, Q277), so a team's colour shows through any skin. Roblox lets no script set a picture at run time, so each
--   skin's look is made ahead, as data, and copied onto the ball (BallLook).

local Freeze = require(script.Parent.Parent.Util.Freeze)

local BallLooks = script.Parent.BallLooks

export type BallSkin = { color: Color3, look: string }

local skins: { [string]: BallSkin } = {
	-- White, Roller Champions' neutral ball (the owner, Q159: Video 31 at 27.2 s), apart from both teams' colours,
	-- with RC's black band round its middle (#400, Q275: 0.8 studs on the 2-stud ball; scripts/art/build_ball.py).
	Default = { color = Color3.new(1, 1, 1), look = "Default" },
}
Freeze.deep(skins)

local ids: { string } = {}
for id in skins do
	table.insert(ids, id)
end
table.freeze(ids)

local BallSkins = {}

BallSkins.DEFAULT = "Default"

function BallSkins.get(id: string): BallSkin
	local skin = skins[id]
	if skin == nil then
		error(`BallSkins: unknown skin "{id}"`, 0)
	end
	return skin
end

-- Every skin's id, in no set order.
function BallSkins.ids(): { string }
	return ids
end

-- The skin's look, to copy onto a ball (never to change: every ball shares it).
function BallSkins.look(id: string): SurfaceAppearance
	return BallLooks:FindFirstChild(BallSkins.get(id).look) :: SurfaceAppearance
end

return table.freeze(BallSkins)
