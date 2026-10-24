--!strict
-- Where the touch controls sit on a screen (spec §8.3, §11.1): how much larger than Config.Input.touch the stick and
-- the buttons are there, how far the buttons reach in from its right edge, and the HUD's stage on touch, the part of
-- the HUD's area left of the buttons, where the HUD centres its banner, feed, score tab and end screen. A screen is big
-- when its shorter side exceeds bigScreenSide pixels, as Roblox grows its own stick and jump button. `screen` is the
-- touch controls' size in pixels: their gui's, inside the device's safe area.

local Config = require(script.Parent.Parent.Config)
local Input = require(script.Parent.Parent.Config.Input)

local TouchArea = {}

local function big(touch: Config.TouchLayout, screen: Vector2): boolean
	return math.min(screen.X, screen.Y) > touch.bigScreenSide
end

function TouchArea.stickScale(touch: Config.TouchLayout, screen: Vector2): number
	return if big(touch, screen) then touch.bigScreenStickScale else 1
end

function TouchArea.buttonScale(touch: Config.TouchLayout, screen: Vector2): number
	return if big(touch, screen) then touch.bigScreenButtonScale else 1
end

-- Pixels from the screen's right edge to the leftmost button's left edge, the buttons `scale` times their size. Every
-- button sits at the bottom-right corner (Config.Input's rule), its centre −X.Offset pixels in.
function TouchArea.reach(touch: Config.TouchLayout, scale: number): number
	local half = touch.buttonSize.X.Offset / 2
	local reach = 0
	for _, place in Input.buttonPlaces(touch) do
		reach = math.max(reach, -place.X.Offset + half)
	end
	return reach * scale
end

-- The stage's size in pixels: the HUD's area (`hud`, its gui's CoreUISafeInsets) from its left edge to the leftmost
-- button, which sits in the touch controls' area (`controls`, their gui's DeviceSafeInsets), as tall as the HUD's
-- area. Both are measured from the same origin (GuiService:GetInsetArea), so their right edges may differ.
function TouchArea.stage(touch: Config.TouchLayout, hud: Rect, controls: Rect): Vector2
	local screen = controls.Max - controls.Min
	local edge = controls.Max.X - TouchArea.reach(touch, TouchArea.buttonScale(touch, screen))
	local width = math.clamp(edge - hud.Min.X, 0, hud.Max.X - hud.Min.X)
	return Vector2.new(width, hud.Max.Y - hud.Min.Y)
end

return table.freeze(TouchArea)
