--!strict
-- How much a HUD panel shrinks to fit the HUD's area on a small screen (an emulated iPhone 17 Pro's safe area is
-- 750 x 323 pixels): enough for its size, in pixels (its offsets), to sit `margin` pixels inside each edge, keeping
-- its shape. A panel that fits keeps its size, and so does every panel while the area is not known yet (zero).

local Fit = {}

function Fit.scale(area: Vector2, size: UDim2, margin: number): number
	if area.X <= 0 or area.Y <= 0 then
		return 1
	end
	local wide = (area.X - 2 * margin) / size.X.Offset
	local tall = (area.Y - 2 * margin) / size.Y.Offset
	return math.max(0, math.min(1, wide, tall))
end

return table.freeze(Fit)
