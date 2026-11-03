--!strict
-- How the HUD's parts move (Config.UI.hud.motion; the owner, Q194), as plain functions of the seconds since a motion
-- began, so the HUD can step them with its own clock (Hud/Animator) and tests can work them by hand. Every part of a
-- motion eases out: fast at first, slowing into its end.

local Config = require(script.Parent.Parent.Config)

local Motion = {}

-- How far along an eased part is at `p` (0 to 1) of its time.
local function out(p: number): number
	local left = 1 - math.clamp(p, 0, 1)
	return 1 - left * left * left
end

-- A part popping in: its scale `t` seconds in, from nothing to 1 + overshoot over the first half, back to 1 over the
-- second (and 1 from then on: each part eases to its end and stays).
function Motion.pop(motion: Config.MotionSettings, t: number): number
	local pop = motion.pop
	local p = t / pop.seconds
	local peak = 1 + pop.overshoot
	if p < 0.5 then
		return peak * out(2 * p)
	end
	return peak - pop.overshoot * out(2 * p - 1)
end

-- A bounce (a score that changes): its scale `t` seconds in, up to `scale`, back to `rebound`, then to 1, in three
-- equal parts (and 1 from then on).
function Motion.bounce(motion: Config.MotionSettings, t: number): number
	local bounce = motion.bounce
	local p = 3 * t / bounce.seconds
	if p < 1 then
		return 1 + (bounce.scale - 1) * out(p)
	elseif p < 2 then
		return bounce.scale + (bounce.rebound - bounce.scale) * out(p - 1)
	end
	return bounce.rebound + (1 - bounce.rebound) * out(p - 2)
end

-- How far an easing part (a meter filling or emptying, a part shrinking away) has come `t` seconds in, 0 to 1.
function Motion.ease(motion: Config.MotionSettings, t: number): number
	return out(t / motion.easeSeconds)
end

-- A lap chip when a lap completes (the owner, Q196): from `from` it fills over easeSeconds, stays full lapHoldSeconds
-- (an ease that has not begun has not moved), then eases to `to`, where the next lap starts it.
function Motion.lap(motion: Config.MotionSettings, from: number, to: number, t: number): number
	local filled = motion.easeSeconds
	if t < filled then
		return from + (1 - from) * Motion.ease(motion, t)
	end
	return 1 + (to - 1) * Motion.ease(motion, t - filled - motion.lapHoldSeconds)
end

-- The transparency of a glowing part's white veil `t` seconds in: none (1) at the start of each cycle, thinning to
-- glow.transparency halfway, and back.
function Motion.glow(motion: Config.MotionSettings, t: number): number
	local glow = motion.glow
	local bright = (1 - math.cos(2 * math.pi * t / glow.seconds)) / 2
	return 1 - (1 - glow.transparency) * bright
end

-- `shown` eased toward `target` over `dt` seconds, closing `rate` of the gap a second; the same pace at any frame rate.
function Motion.approach(shown: number, target: number, rate: number, dt: number): number
	return target + (shown - target) * math.exp(-rate * dt)
end

return table.freeze(Motion)
