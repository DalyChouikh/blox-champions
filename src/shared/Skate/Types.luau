--!strict
-- The records SkateMath reads each step. The controller reuses one of each, so a step allocates nothing.

export type Mode = "Grounded" | "Airborne" | "Attached"

-- One step's input: the stick as a world direction from the camera (length 0..1), the held buttons, a jump pressed
-- since the last step, the draft's pull, and whether the skater is knocked down (which locks all the rest).
export type SkateInput = {
	move: Vector3,
	pump: boolean,
	brake: boolean,
	jump: boolean,
	draftAccel: number,
	knockedDown: boolean,
}

-- What the ground ray found: the filtered surface normal, and how far below the root the surface is.
export type Ground = { hit: boolean, normal: Vector3, distance: number }

return table.freeze({})
