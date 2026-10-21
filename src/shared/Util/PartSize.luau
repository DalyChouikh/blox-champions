--!strict
-- Roblox's part size limits per axis (verified in Studio): it silently clamps any other size, which would leave a
-- gap or an overlap in generated geometry, so config bounds and the arena builder check against these instead.

return table.freeze({
	MIN = 0.001,
	MAX = 2048,
})
