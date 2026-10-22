--!strict
-- Ball skins by id (spec §9.4). M1 ships only Default; later skins are data added here, chosen by the carrier.

local Freeze = require(script.Parent.Parent.Util.Freeze)

export type BallSkin = { color: Color3, material: Enum.Material }

local skins: { [string]: BallSkin } = {
	-- A warm yellow that stands out against the gray track.
	Default = { color = Color3.fromRGB(255, 196, 0), material = Enum.Material.SmoothPlastic },
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
