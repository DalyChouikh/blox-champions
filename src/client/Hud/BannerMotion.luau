--!strict
-- How the banners move (#356, the owner's Q191, Q194), one slot for the banner line and one for the goal message: a
-- banner new to its slot (HudState makes a new table for each it shows) pops in from nothing, motion.pop's overshoot
-- and back (`watch`, whenever the HUD's state changes); over its last motion.easeSeconds it leaves, 0 to 1 eased
-- (Motion.ease), which Hud/Banner turns into its fade and its float up (`step`, each frame, writing only on a change).
-- Each slot's pop is an Animator track; its leave a binding.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animator = require(script.Parent.Animator)
local Config = require(ReplicatedStorage.Shared.Config)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local Motion = require(ReplicatedStorage.Shared.Hud.Motion)
local React = require(ReplicatedStorage.Packages.React)

export type Slot = {
	-- The banner's scale (1 at rest), and how far it has left, 0 to 1.
	scale: Animator.Track,
	leave: React.Binding<number>,
	_setLeave: (share: number) -> (),
	_leave: number,
	-- The banner last seen in this slot.
	_seen: HudState.Banner?,
}

local BannerMotion = {}
BannerMotion.__index = BannerMotion

type Fields = {
	line: Slot,
	message: Slot,
	-- How many times a leave was written (tests: nothing on a quiet step).
	writes: number,
	_motion: Config.MotionSettings,
	_animator: Animator.Animator,
}

export type BannerMotion = typeof(setmetatable({} :: Fields, BannerMotion))

local function slot(animator: Animator.Animator): Slot
	local leave, setLeave = React.createBinding(0)
	return { scale = animator:track(1), leave = leave, _setLeave = setLeave, _leave = 0, _seen = nil }
end

function BannerMotion.new(motion: Config.MotionSettings, animator: Animator.Animator): BannerMotion
	local fields: Fields = {
		line = slot(animator),
		message = slot(animator),
		writes = 0,
		_motion = motion,
		_animator = animator,
	}
	return setmetatable(fields, BannerMotion)
end

local function seen(self: BannerMotion, into: Slot, banner: HudState.Banner?)
	if banner ~= into._seen then
		into._seen = banner
		if banner ~= nil then
			self._animator:rest(into.scale, 0)
			self._animator:play(into.scale, "Pop", 1)
		end
	end
end

local function leaving(self: BannerMotion, into: Slot, banner: HudState.Banner?, left: number)
	local motion = self._motion
	local share = if banner ~= nil then Motion.ease(motion, motion.easeSeconds - left) else 0
	if share ~= into._leave then
		into._leave = share
		into._setLeave(share)
		self.writes += 1
	end
end

-- Pops in each banner new to its slot.
function BannerMotion.watch(self: BannerMotion, state: HudState.HudState)
	seen(self, self.line, state.banner)
	seen(self, self.message, state.message)
end

-- Moves each slot's leave on with its banner's time left.
function BannerMotion.step(self: BannerMotion, state: HudState.HudState)
	leaving(self, self.line, state.banner, state.bannerLeft)
	leaving(self, self.message, state.message, state.messageLeft)
end

return BannerMotion
