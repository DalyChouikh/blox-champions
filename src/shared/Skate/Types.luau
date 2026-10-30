--!strict
-- The records SkateMath reads each step. The controller reuses one of each, so a step allocates nothing.

local Attributes = require(script.Parent.Parent.Net.Attributes)

export type Mode = "Grounded" | "Airborne" | "Attached"

-- One step's input: the stick as a world direction from the camera (length 0..1), the held buttons, a jump pressed
-- since the last step and whether the jump key is held (the Air Pose lasts while it is, #245), the draft's pull,
-- why the skater is knocked down, nil on their feet (which locks all the rest; each kind slides for its own time,
-- #252), and whether they dive (which locks the rest too: a diver glides, and in the air flies down the fall line,
-- #241, #242).
export type SkateInput = {
	move: Vector3,
	pump: boolean,
	brake: boolean,
	jump: boolean,
	jumpHeld: boolean,
	draftAccel: number,
	knockdown: Attributes.Knockdown?,
	diving: boolean,
}

-- What the ground ray found: the filtered surface normal, and how far below the root the surface is.
export type Ground = { hit: boolean, normal: Vector3, distance: number }

return table.freeze({})
