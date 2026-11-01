--!strict
-- Ball skins by id (spec §9.4). M1 ships only Default; later skins are data added here, chosen by the carrier. A skin's
-- colour is the ball's until a team first holds it after a kickoff; then every screen shows the colour of the team
-- that last held it (the owner, #327, Q158: Client/WorldMarkers).

local Freeze = require(script.Parent.Parent.Util.Freeze)

export type BallSkin = { color: Color3, material: Enum.Material }

local skins: { [string]: BallSkin } = {
	-- White, Roller Champions' neutral ball (the owner, Q159: Video 31 at 27.2 s), apart from both teams' colours.
	Default = { color = Color3.new(1, 1, 1), material = Enum.Material.SmoothPlastic },
}
Freeze.deep(skins)

local BallSkins = {}

BallSkins.DEFAULT = "Default"

function BallSkins.get(id: string): BallSkin
	local skin = skins[id]
	if skin == nil then
		error(`BallSkins: unknown skin "{id}"`, 0)
	end
	return skin
end

return table.freeze(BallSkins)
