--!strict
-- What the pure arena geometry hands the builder: each piece becomes one anchored part.

-- Block is a Part, Wedge a WedgePart, Cylinder a Part with Shape = Cylinder (its axis is the part's X axis).
export type Shape = "Block" | "Wedge" | "Cylinder"

export type Piece = { shape: Shape, cframe: CFrame, size: Vector3 }

return table.freeze({})
