--!strict
-- Finite-number checks for values that arrive from outside a module's control (engine inputs, arena geometry,
-- and later remote payloads), so NaN or an infinity is rejected where it enters instead of spreading.

local Finite = {}

function Finite.number(n: number): boolean
	return n > -math.huge and n < math.huge -- false for NaN too
end

function Finite.vector(v: Vector3): boolean
	return Finite.number(v.X) and Finite.number(v.Y) and Finite.number(v.Z)
end

return Finite
