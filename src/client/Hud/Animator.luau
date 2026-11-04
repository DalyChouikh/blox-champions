--!strict
-- The HUD's moving numbers (Config.UI.hud.motion; the owner, Q194): each track is a React binding a part reads (a
-- UIScale's Scale, a veil's transparency), moved along one of Motion's curves by the Hud's clock (`step`, each frame),
-- so a motion never needs a render, and tests step it by hand. A track writes its binding only when its value changes:
-- at rest, and on a quiet frame, nothing is written and nothing allocated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Motion = require(ReplicatedStorage.Shared.Hud.Motion)
local React = require(ReplicatedStorage.Packages.React)

-- Pop: in from where it is, past `to` and back; Bounce (a score) and Press (a key): about `to`, each its own
-- shape; Ease: to `to`; Lap: full, held, then to `to` (a lap chip, Motion.lap); Glow: Motion.glow's veil, cycle
-- after cycle until the next motion or a rest.
export type Curve = "Pop" | "Bounce" | "Press" | "Ease" | "Lap" | "Glow"

export type Track = {
	binding: React.Binding<number>,
	-- What the binding holds now, and where the track rests once its motion ends.
	value: number,
	target: number,
	moving: boolean,
	_set: (value: number) -> (),
	_curve: Curve,
	_from: number,
	_elapsed: number,
}

local Animator = {}
Animator.__index = Animator

type Fields = {
	-- How many times a track's binding was written (tests: nothing at rest).
	writes: number,
	_motion: Config.MotionSettings,
	_tracks: { Track },
}

export type Animator = typeof(setmetatable({} :: Fields, Animator))

function Animator.new(motion: Config.MotionSettings): Animator
	return setmetatable({ writes = 0, _motion = motion, _tracks = {} } :: Fields, Animator)
end

local function write(self: Animator, track: Track, value: number)
	if value ~= track.value then
		track.value = value
		track._set(value)
		self.writes += 1
	end
end

-- A track resting at `value`.
function Animator.track(self: Animator, value: number): Track
	local binding, set = React.createBinding(value)
	local track: Track = {
		binding = binding,
		value = value,
		target = value,
		moving = false,
		_set = set,
		_curve = "Ease",
		_from = value,
		_elapsed = 0,
	}
	table.insert(self._tracks, track)
	return track
end

-- Starts `curve` from where the track is now, toward `to`; it moves from the next step on.
function Animator.play(_self: Animator, track: Track, curve: Curve, to: number)
	track._curve = curve
	track._from = track.value
	track.target = to
	track._elapsed = 0
	track.moving = true
end

-- Stops the track at `value` now.
function Animator.rest(self: Animator, track: Track, value: number)
	track.moving = false
	track.target = value
	write(self, track, value)
end

-- How long `curve` lasts; a glow never ends.
local function seconds(motion: Config.MotionSettings, curve: Curve): number
	if curve == "Pop" then
		return motion.pop.seconds
	elseif curve == "Bounce" then
		return motion.bounce.seconds
	elseif curve == "Press" then
		return motion.press.seconds
	elseif curve == "Lap" then
		return 2 * motion.easeSeconds + motion.lapHoldSeconds
	elseif curve == "Glow" then
		return math.huge
	end
	return motion.easeSeconds
end

-- Where a moving track is `t` seconds into its curve.
local function at(motion: Config.MotionSettings, track: Track, t: number): number
	local curve, from, to = track._curve, track._from, track.target
	if curve == "Pop" then
		return from + (to - from) * Motion.pop(motion, t)
	elseif curve == "Bounce" then
		return to * Motion.bounce(motion.bounce, t)
	elseif curve == "Press" then
		return to * Motion.bounce(motion.press, t)
	elseif curve == "Lap" then
		return Motion.lap(motion, from, to, t)
	elseif curve == "Glow" then
		return Motion.glow(motion, t)
	end
	return from + (to - from) * Motion.ease(motion, t)
end

function Animator.step(self: Animator, dt: number)
	local motion = self._motion
	local tracks = self._tracks
	-- By index: luau-lsp's strict check of a for-in loop compares a track's React binding (an intersection type)
	-- exactly and rejects it, even against its own type.
	for index = 1, #tracks do
		local track = tracks[index]
		if track.moving then
			local t = track._elapsed + dt
			track._elapsed = t
			if t >= seconds(motion, track._curve) then
				track.moving = false
				write(self, track, track.target)
			else
				write(self, track, at(motion, track, t))
			end
		end
	end
end

return Animator
