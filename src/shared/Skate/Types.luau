--!strict
-- The records SkateMath reads each step. The controller reuses one of each, so a step allocates nothing.

export type Mode = "Grounded" | "Airborne" | "Attached"

-- Why a skater is knocked down (the server shows it in the character's KnockedDown attribute): a strike ("Hit") and a
-- fall ("Fall": a hard landing, or touching down still posing, #245) end once the skater has asked to get up (Get Up,
-- #220) and Actions.getUpAfter has passed, else after their seconds; a diver's own touchdown ("Dive") ends when the
-- slide stops (#242).
export type Knockdown = "Hit" | "Fall" | "Dive"

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
	knockdown: Knockdown?,
	diving: boolean,
}

-- What the ground ray found: the ride surface's smooth normal (#294), how far below the root the surface is, and
-- whether it is glass, where no climb holds (#299; only the client's skating reads it, nil means not glass).
export type Ground = { hit: boolean, normal: Vector3, distance: number, glass: boolean? }

return table.freeze({})
