--!strict
-- What the pure arena geometry hands the builder: each piece becomes one anchored part.

-- Block is a Part, Wedge a WedgePart, Cylinder a Part with Shape = Cylinder (its axis is the part's X axis).
export type Shape = "Block" | "Wedge" | "Cylinder"

export type Piece = { shape: Shape, cframe: CFrame, size: Vector3 }

-- Floor-level spawn frames per team, in slot order. A record (not a [Team] indexer) so both `spawns.Blue` and
-- `spawns[team]` type-check.
export type TeamSpawns = { Blue: { CFrame }, Orange: { CFrame } }

-- The upright goal ring. frame faces oncoming skaters; its opening is also the scoring disc.
export type Goal = { frame: CFrame, openingRadius: number, rim: { Piece }, panel: Piece }

return table.freeze({})
