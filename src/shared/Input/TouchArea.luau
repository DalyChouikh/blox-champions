--!strict
-- Where the touch controls sit on a screen (spec §8.3, §11.1): how much larger than Config.Input.touch the stick and
-- the buttons are there, how far in from its right edge the buttons start and reach, the HUD's stage on touch, the
-- part of the HUD's area left of the buttons, where the HUD centres its banner, feed, score tab and end screen, and
-- where across that area the buttons' right edge sits, which SCORES lines up with (#355, the owner's Q250). A screen
-- is big when its shorter side exceeds bigScreenSide pixels, as Roblox grows its own stick and jump button. `screen`
-- is the whole screen's size in pixels: the buttons sit at its physical corner (the owner's Q246, Q249), past a
-- notched phone's safe area.

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
	local reach = 0
	for _, button in Input.buttonList(touch) do
		reach = math.max(reach, -button.place.X.Offset + button.size / 2)
	end
	return reach * scale
end

-- Pixels from the screen's right edge to the rightmost button's right edge, the buttons `scale` times their size.
function TouchArea.inset(touch: Config.TouchLayout, scale: number): number
	local inset = math.huge
	for _, button in Input.buttonList(touch) do
		inset = math.min(inset, -button.place.X.Offset - button.size / 2)
	end
	return inset * scale
end

-- The buttons on the whole screen (`whole`): how much they grow there, and its right edge's x.
local function onScreen(touch: Config.TouchLayout, whole: Rect): (number, number)
	return TouchArea.buttonScale(touch, whole.Max - whole.Min), whole.Max.X
end

-- The stage's size in pixels: the HUD's area (`hud`, its gui's CoreUISafeInsets) from its left edge to the leftmost
-- button, which sits on the whole screen (`whole`, ScreenInsets.None), as tall as the HUD's area. Both are measured
-- from the same origin (GuiService:GetInsetArea), so their right edges may differ.
function TouchArea.stage(touch: Config.TouchLayout, hud: Rect, whole: Rect): Vector2
	local scale, right = onScreen(touch, whole)
	local width = math.clamp(right - TouchArea.reach(touch, scale) - hud.Min.X, 0, hud.Max.X - hud.Min.X)
	return Vector2.new(width, hud.Max.Y - hud.Min.Y)
end

-- Where the buttons' right edge sits across the HUD's area (`hud`), in pixels from its left edge: on a notched phone
-- past that area's right edge, as the buttons sit on the whole screen (`whole`).
function TouchArea.lineUp(touch: Config.TouchLayout, hud: Rect, whole: Rect): number
	local scale, right = onScreen(touch, whole)
	return right - TouchArea.inset(touch, scale) - hud.Min.X
end

return table.freeze(TouchArea)
