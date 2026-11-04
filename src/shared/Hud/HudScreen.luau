--!strict
-- The screen the HUD is drawn on, decided once for every HUD part: a phone's (compact), by size alone, so a phone
-- with a keyboard or a gamepad keeps a phone's layout and a small window gets one too; and where the scoreboard sits
-- under Roblox's top bar. A screen here is the device's safe area, where Roblox's top bar and the touch controls are
-- (a notched phone's whole screen reaches past it). The scoreboard is drawn from its top (Hud/App): in the top bar's
-- free band (GuiService.TopbarInset, in pixels from the safe area's top-left) when its whole reach fits inside it, else
-- just under the bar, so it never covers Roblox's own buttons. The crosshair's aim is a share of the way down the
-- WHOLE screen, where the 3D view is centred; its rings and the kickoff count keep clear of the scoreboard (#353):
-- from how deep the board reaches, the rings shrink round the dot, which throws aim through, and the count, which aims
-- nothing, moves down (the owner, Q203). The banner line (#356) sits a share of the way down the whole screen too,
-- lower where it would come near the board; the goal message sits at the stage's bottom, the feed above it (Q210,
-- Q211), and the Get Up prompt above that where the feed reaches it (#369). All in pixels from the safe area's top, but
-- the message's, the feed's and the prompt's, from the stage's bottom. The TAB board (#357) fits the HUD's area under
-- the scoreboard's ink, on touch under the SCORES button too, shrinking off touch and scrolling its rows on touch where
-- they do not fit.

local Config = require(script.Parent.Parent.Config)
local Fit = require(script.Parent.Fit)
local HudState = require(script.Parent.HudState)

-- The Switch team row under the TAB board: its words alone (on touch, where it is tapped), or a key's cap beside them.
export type SwitchRow = "Label" | "Key"

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

-- How far below a look C box's bottom another starts so `clearance` pixels show between them: the upper box's ink
-- reaches look.outline + look.shadow below it (Hud/Style.box), the lower one's look.outline above it.
function HudScreen.under(config: Config.GameConfig, clearance: number): number
	local look = config.UI.hud.look
	return look.outline + look.shadow + clearance + look.outline
end

-- How far below the safe area's top the scoreboard (`top` its top) reaches at its deepest in play (the period under it
-- while `period`): what the banner line and the TAB board keep clear of, the deepest at any moment of the period so
-- neither moves within it.
function HudScreen.boardBottom(config: Config.GameConfig, compact: boolean, top: number, period: boolean): number
	return top + HudScreen.boardDepth(config, compact, period, true)
end

-- How far below the safe area's top (`safe`) a point `share` of the way down the whole screen (`whole`) lies; both
-- in one frame (GuiService:GetInsetArea gives them so).
local function down(whole: Rect, safe: Rect, share: number): number
	return whole.Min.Y + share * (whole.Max.Y - whole.Min.Y) - safe.Min.Y
end

-- How far below the safe area's top (`safe`) the crosshair's aim lies: UI.hud.layout.reticle.height of the way down
-- the whole screen (`whole`; GuiService:GetInsetArea gives both in one frame), where the 3D view and the reticle's gui
-- are centred (a notched phone's safe area starts 20 px below it, probed).
function HudScreen.aim(config: Config.GameConfig, whole: Rect, safe: Rect): number
	return down(whole, safe, config.UI.hud.layout.reticle.height)
end

-- The crosshair's rings on a phone's screen or a desktop's.
function HudScreen.rings(config: Config.GameConfig, compact: boolean): Config.RingSizes
	local reticle = config.UI.hud.layout.reticle
	return if compact then reticle.compactSizes else reticle.sizes
end

-- The kickoff count on a phone's screen or a desktop's.
function HudScreen.count(config: Config.GameConfig, compact: boolean): Config.CountSizes
	local countdown = config.UI.hud.layout.countdown
	return if compact then countdown.compactSizes else countdown.sizes
end

-- How far the scoreboard's ink reaches below its top at its deepest (Hud/Scoreboard; its motion, Hud/BoardMotion):
-- S2's shields or S5's row; the period (OVERTIME, LAST CHANCE) under S2's clock or S5's row while `period`; and while
-- the ball is in play (`playing`) the lap chips under a shield and the goal's worth chip, grown round its centre by its
-- pop's overshoot or its bounce, whichever is bigger (never both at once), with S2's period under the worth chip's
-- place. A kickoff resets the laps and closes the goal, so neither shows then; a score bounces only with a goal, while
-- neither the crosshair nor the count shows.
function HudScreen.boardDepth(config: Config.GameConfig, compact: boolean, period: boolean, playing: boolean): number
	local hud = config.UI.hud
	local look, motion = hud.look, hud.motion
	local ink = look.outline + look.shadow
	local widest = math.max(1 + motion.pop.overshoot, motion.bounce.scale)
	if compact then
		local board = hud.layout.compactScoreboard
		local row = board.score.Y.Offset
		local depth = row + ink
		if playing then
			depth = math.max(depth, row / 2 + widest * (board.worth.Y.Offset / 2 + ink))
		end
		if period then
			depth = math.max(depth, row + board.gap + board.textSizes.period + look.textOutline)
		end
		return depth
	end
	local board = hud.layout.scoreboard
	local shield, clock, worth = board.shield.Y.Offset, board.clock.Y.Offset, board.worth.Y.Offset
	local depth = shield + ink
	local periodTop = clock + board.gap
	if playing then
		local chips = shield + HudScreen.under(config, board.chipClearance) + board.lapChip + ink
		depth = math.max(depth, chips, periodTop + worth / 2 + widest * (worth / 2 + ink))
		periodTop += worth + board.gap
	end
	if period then
		depth = math.max(depth, periodTop + board.textSizes.period + look.textOutline)
	end
	return depth
end

-- The room the scoreboard (`top` from the safe area's top) leaves above the aim (`aim`): from its deepest ink to the
-- aim, less UI.hud.layout.reticle.clearance.
local function room(
	config: Config.GameConfig,
	compact: boolean,
	top: number,
	aim: number,
	period: boolean,
	playing: boolean
): number
	local depth = HudScreen.boardDepth(config, compact, period, playing)
	return aim - top - depth - config.UI.hud.layout.reticle.clearance
end

-- How far a look C ring `size` pixels across (at its stroke's outer edge) reaches from its centre, its ink included.
local function inkedRadius(config: Config.GameConfig, size: number): number
	return size / 2 + config.UI.hud.look.textOutline
end

-- How much the crosshair's rings shrink round the dot while the ball is in play, 0 to 1 (1 where they fit), so the
-- charge ring's ink stays clear of the scoreboard; the dot never moves, as throws aim through it.
function HudScreen.ringScale(
	config: Config.GameConfig,
	compact: boolean,
	top: number,
	aim: number,
	period: boolean
): number
	local radius = inkedRadius(config, HudScreen.rings(config, compact).charge)
	return math.clamp(room(config, compact, top, aim, period, true) / radius, 0, 1)
end

-- How far below the aim the kickoff count's centre sits (0 where it fits), so its ring's ink stays clear of the
-- scoreboard at a kickoff: the count aims nothing, so it moves down rather than shrink (the owner, Q203). In whole
-- pixels, rounded up: a UDim's offset holds whole pixels (Roblox drops the fraction).
function HudScreen.countDrop(
	config: Config.GameConfig,
	compact: boolean,
	top: number,
	aim: number,
	period: boolean
): number
	local radius = inkedRadius(config, HudScreen.count(config, compact).ringSize)
	return math.max(0, math.ceil(radius - room(config, compact, top, aim, period, false)))
end

-- The banners on a phone's screen or a desktop's.
function HudScreen.banners(config: Config.GameConfig, compact: boolean): Config.BannerSizes
	local banner = config.UI.hud.layout.banner
	return if compact then banner.compactSizes else banner.sizes
end

-- A banner's text size: GOAL!'s, a completed lap's, the goal message's, else the headline's.
function HudScreen.bannerSize(config: Config.GameConfig, compact: boolean, kind: HudState.BannerKind): number
	local sizes = HudScreen.banners(config, compact)
	if kind == "Goal" then
		return sizes.goal
	elseif kind == "Lap" then
		return sizes.lap
	elseif kind == "GoalOpen" then
		return sizes.message
	end
	return sizes.headline
end

-- How far a banner's ink reaches round its text (Hud/Style.banner): look C's outline and its team's ring, the ring
-- counted even for a banner about nobody, so every banner on the line keeps the same clearance.
function HudScreen.bannerInk(config: Config.GameConfig, compact: boolean): number
	return config.UI.hud.look.textOutline + HudScreen.banners(config, compact).edge
end

-- How far below the safe area's top (`safe`) the banner line lies at its highest: UI.hud.layout.banner.height of the
-- way down the whole screen (`whole`), where RC puts GO; measured with the screen, as the aim is.
function HudScreen.bannerAt(config: Config.GameConfig, whole: Rect, safe: Rect): number
	return down(whole, safe, config.UI.hud.layout.banner.height)
end

-- The centre of a banner `size` pixels tall on the banner line: at `at` (HudScreen.bannerAt), lower where its ink would
-- come within layout.banner.clearance of the scoreboard's deepest ink in play (HudScreen.boardBottom: `top` its top,
-- the period under it while `period`), so the line never moves within a period, GO at the kickoff's end included. In
-- whole pixels, rounded up: a UDim's offset holds whole pixels.
function HudScreen.bannerLine(
	config: Config.GameConfig,
	compact: boolean,
	at: number,
	top: number,
	period: boolean,
	size: number
): number
	local banner = config.UI.hud.layout.banner
	local board = HudScreen.boardBottom(config, compact, top, period)
	local clear = board + banner.clearance + HudScreen.bannerInk(config, compact) + size / 2
	return math.ceil(math.max(at, clear))
end

-- How far above the stage's bottom the goal message's text ends: its drop shadow's ink layout.banner.bottom above
-- it, the shadow look.shadow lower than the text and inked as far round it as the text.
function HudScreen.messageBottom(config: Config.GameConfig, compact: boolean): number
	return config.UI.hud.layout.banner.bottom + config.UI.hud.look.shadow + HudScreen.bannerInk(config, compact)
end

-- How far above the stage's bottom the feed ends: over the goal message's text and ink, layout.banner.clearance
-- apart (the owner, Q211).
function HudScreen.feedBottom(config: Config.GameConfig, compact: boolean): number
	local sizes = HudScreen.banners(config, compact)
	local ink = HudScreen.bannerInk(config, compact)
	return HudScreen.messageBottom(config, compact) + sizes.message + ink + config.UI.hud.layout.banner.clearance
end

-- The feed's chips on this kind of screen.
function HudScreen.feedSizes(config: Config.GameConfig, compact: boolean): Config.FeedSizes
	local feed = config.UI.hud.layout.feed
	return if compact then feed.compactSizes else feed.sizes
end

-- How tall `lines` of the feed stand: each chip's box and its ink (an outline each side, the shadow below),
-- layout.feed.clearance apart.
function HudScreen.feedHeight(config: Config.GameConfig, compact: boolean, lines: number): number
	if lines == 0 then
		return 0
	end
	local look = config.UI.hud.look
	local chip = HudScreen.feedSizes(config, compact).height + 2 * look.outline + look.shadow
	return lines * chip + (lines - 1) * config.UI.hud.layout.feed.clearance
end

-- The Get Up prompt on this kind of screen.
function HudScreen.getUpSizes(config: Config.GameConfig, compact: boolean): Config.GetUpSizes
	local getUp = config.UI.hud.layout.getUp
	return if compact then getUp.compactSizes else getUp.sizes
end

-- How far above the stage's bottom the Get Up prompt's ink ends: at its place, or layout.feed.clearance over `lines` of
-- the feed where they reach higher, so it never covers them.
function HudScreen.getUpBottom(config: Config.GameConfig, compact: boolean, lines: number): number
	local feedTop = HudScreen.feedBottom(config, compact) + HudScreen.feedHeight(config, compact, lines)
	return math.max(HudScreen.getUpSizes(config, compact).bottom, feedTop + config.UI.hud.layout.feed.clearance)
end

-- The TAB board on a phone's screen or a desktop's (#357, the owner's Q237: one compact table on both).
function HudScreen.tabSizes(config: Config.GameConfig, compact: boolean): Config.TabSizes
	local tab = config.UI.hud.layout.scoreTab
	return if compact then tab.compactSizes else tab.sizes
end

-- How far below the top of the HUD's area (`height` pixels tall) the TAB board's area starts: under the scoreboard's
-- ink (`board` pixels below that top; none where it is above it), which the board's margin keeps it clear of (the
-- owner's rule for the HUD's parts, Q203); on touch under the SCORES button too, which stays above it to close it
-- (Q234, Q236). In whole pixels, rounded up: a UDim's offset holds whole pixels, and a share of the height reads back
-- as a float32.
function HudScreen.tabTop(config: Config.GameConfig, touch: boolean, height: number, board: number): number
	local top = math.max(0, math.ceil(board))
	if not touch then
		return top
	end
	local button = config.UI.hud.layout.scoreButton
	return math.max(top, math.round(height * button.position.Y.Scale) + button.position.Y.Offset + button.size.Y.Offset)
end

-- How tall the TAB board's teams stand: both teams' bars, however few play, and `players` rows.
function HudScreen.tabBody(config: Config.GameConfig, compact: boolean, players: number): number
	local sizes = HudScreen.tabSizes(config, compact)
	return 2 * sizes.barHeight + players * sizes.rowHeight
end

-- How far the Switch team row (`row`) reaches under the TAB board's ink: switchGap, then its words in their ink, or a
-- key's cap (UI.hud.layout.hints.cap) beside them where that is taller; nothing without the row.
function HudScreen.tabSwitch(config: Config.GameConfig, compact: boolean, row: SwitchRow?): number
	if row == nil then
		return 0
	end
	local sizes = HudScreen.tabSizes(config, compact)
	local words = sizes.switchSize + 2 * math.ceil(config.UI.hud.look.textOutline)
	local height = if row == "Key" then math.max(config.UI.hud.layout.hints.cap.height, words) else words
	return sizes.switchGap + height
end

-- How the TAB board fits its area (`area`, pixels): layout.scoreTab.margin in from each edge, shrunk only as much as it
-- must. Off touch its key is held, so nothing could scroll it: it shrinks to fit whole. On touch, where a finger drags
-- them, its teams scroll (the owner, Q190) behind its fixed parts (its ink, the header, Switch team), so it shrinks
-- only for its width or those. Returns its scale and how tall its teams show, in whole pixels (every row while the area
-- is not known yet; none where not even its margins fit).
function HudScreen.tabFit(
	config: Config.GameConfig,
	compact: boolean,
	touch: boolean,
	area: Vector2,
	players: number,
	row: SwitchRow?
): (number, number)
	local look = config.UI.hud.look
	local sizes = HudScreen.tabSizes(config, compact)
	local margin = config.UI.hud.layout.scoreTab.margin
	local body = HudScreen.tabBody(config, compact, players)
	local fixed = 2 * look.outline + look.shadow + sizes.headHeight + HudScreen.tabSwitch(config, compact, row)
	local width = sizes.width + 2 * look.outline
	local scale = Fit.scale(area, UDim2.fromOffset(width, if touch then fixed else fixed + body), margin)
	if not touch or area.X <= 0 or area.Y <= 0 then
		return scale, body
	elseif scale <= 0 then
		return 0, 0
	end
	return scale, math.clamp(math.floor((area.Y - 2 * margin) / scale - fixed), 0, body)
end

return table.freeze(HudScreen)
