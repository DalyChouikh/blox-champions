--!strict
-- The screen the HUD is drawn on, decided once for every HUD part: a phone's (compact), by size alone, so a phone
-- with a keyboard or a gamepad keeps a phone's layout and a small window gets one too; and where the scoreboard sits
-- under Roblox's top bar. A screen here is the device's safe area, where Roblox's top bar and the touch controls are
-- (a notched phone's whole screen reaches past it). The scoreboard is drawn from its top (Hud/App): in the top bar's
-- free band (GuiService.TopbarInset, in pixels from the safe area's top-left) when its whole reach fits inside it, else
-- just under the bar, so it never covers Roblox's own buttons.

local Config = require(script.Parent.Parent.Config)

local HudScreen = {}

-- Whether `screen` (its size in pixels) is a phone's: its shorter side under UI.hud.layout.compactBelow.
function HudScreen.compact(config: Config.GameConfig, screen: Vector2): boolean
	return math.min(screen.X, screen.Y) < config.UI.hud.layout.compactBelow
end

-- The scoreboard's own width in pixels (Hud/Scoreboard): S2's shields round the clock, or S5's score chips round it.
function HudScreen.boardWidth(config: Config.GameConfig, compact: boolean): number
	local layout = config.UI.hud.layout
	if compact then
		local board = layout.compactScoreboard
		return 2 * board.score.X.Offset + board.clock.X.Offset + 2 * board.gap
	end
	local board = layout.scoreboard
	return 2 * board.shield.X.Offset + board.clock.X.Offset + 2 * board.gap
end

-- How far the scoreboard reaches either side of its centre, in pixels: half its width, and on a phone beyond either
-- end of S5's row the worth chip, which hangs beside the team the goal is open for.
function HudScreen.boardReach(config: Config.GameConfig, compact: boolean): number
	local half = HudScreen.boardWidth(config, compact) / 2
	if compact then
		local board = config.UI.hud.layout.compactScoreboard
		return half + board.gap + board.worth.X.Offset
	end
	return half
end

-- The scoreboard's top, in pixels from the top of a screen `width` pixels wide whose top bar leaves `topbar` free: its
-- position's offset inside the band while its reach round its centre stays in the band, else that far under the bar.
function HudScreen.boardTop(config: Config.GameConfig, compact: boolean, width: number, topbar: Rect): number
	local layout = config.UI.hud.layout
	local position = if compact then layout.compactScoreboard.position else layout.scoreboard.position
	local centre = width * position.X.Scale + position.X.Offset
	local reach = HudScreen.boardReach(config, compact)
	local clear = centre - reach >= topbar.Min.X and centre + reach <= topbar.Max.X
	return if clear then position.Y.Offset else topbar.Max.Y + position.Y.Offset
end

return table.freeze(HudScreen)
