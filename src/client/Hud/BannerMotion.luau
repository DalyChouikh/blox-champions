--!strict
-- How the banners move (#356, the owner's Q191, Q194), one slot for the banner line and one for the goal message: a
-- banner new to its slot (HudState makes a new table for each it shows) pops in from nothing, motion.pop's overshoot
-- and back (`watch`, whenever the HUD's state changes); over its last motion.easeSeconds it leaves, 0 to 1 eased
-- (Motion.ease), which Hud/Banner turns into its fade and its float up (`step`, each frame, writing only on a change).
-- Each slot's pop is an Animator track; its leave a binding. The feed's chips move as banners do (#373, Q227), each
-- line seated in a slot of a fixed set as big as the feed's most lines, its time left the one the feed counts; a
-- replaced ball line is left only its fade (HudState), so it fades the same way. So the Animator's tracks stay few and
-- nothing is made per line. The Get Up prompt, lettered as a banner but with no time of its own, moves by a Reveal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animator = require(script.Parent.Animator)
local Config = require(ReplicatedStorage.Shared.Config)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local Motion = require(ReplicatedStorage.Shared.Hud.Motion)
local React = require(ReplicatedStorage.Packages.React)

-- What a slot shows: a new table is new to it.
type Shown = HudState.Banner | HudState.FeedEntry

export type Slot = {
	-- The banner's scale (1 at rest), and how far it has left, 0 to 1.
	scale: Animator.Track,
	leave: React.Binding<number>,
	_setLeave: (share: number) -> (),
	_leave: number,
	-- What was last seen in this slot.
	_seen: Shown?,
}

local BannerMotion = {}
BannerMotion.__index = BannerMotion

type Fields = {
	line: Slot,
	message: Slot,
	-- Each feed line's slot, by its id.
	chips: { [number]: Slot },
	-- How many times a leave was written (tests: nothing on a quiet step).
	writes: number,
	_motion: Config.MotionSettings,
	_animator: Animator.Animator,
	-- The feed's slots, each taken while it holds a line (its `_seen`).
	_seats: { Slot },
}

export type BannerMotion = typeof(setmetatable({} :: Fields, BannerMotion))

local function slot(animator: Animator.Animator): Slot
	local leave, setLeave = React.createBinding(0)
	return { scale = animator:track(1), leave = leave, _setLeave = setLeave, _leave = 0, _seen = nil }
end

-- `feedLines`: the feed's most lines at once (UI.hud.feedMaxEntries).
function BannerMotion.new(motion: Config.MotionSettings, animator: Animator.Animator, feedLines: number): BannerMotion
	local seats: { Slot } = table.create(feedLines)
	for index = 1, feedLines do
		seats[index] = slot(animator)
	end
	local fields: Fields = {
		line = slot(animator),
		message = slot(animator),
		chips = {},
		writes = 0,
		_motion = motion,
		_animator = animator,
		_seats = seats,
	}
	return setmetatable(fields, BannerMotion)
end

local function seen(self: BannerMotion, into: Slot, banner: Shown?)
	if banner ~= into._seen then
		into._seen = banner
		if banner ~= nil then
			self._animator:rest(into.scale, 0)
			self._animator:play(into.scale, "Pop", 1)
		end
	end
end

local function leaving(self: BannerMotion, into: Slot, banner: Shown?, left: number)
	local motion = self._motion
	local share = if banner ~= nil then Motion.ease(motion, motion.easeSeconds - left) else 0
	if share ~= into._leave then
		into._leave = share
		into._setLeave(share)
		self.writes += 1
	end
end

-- Frees the slots of lines gone from the feed, first, so a line that pushed the oldest out has one; then seats each new
-- line, which pops it in.
local function seatChips(self: BannerMotion, feed: { HudState.FeedEntry })
	local chips, seats = self.chips, self._seats
	-- By index: luau-lsp's strict check rejects a for-in over records holding a React binding, as Animator.step says.
	for index = 1, #seats do
		local line = seats[index]._seen :: HudState.FeedEntry?
		if line ~= nil and table.find(feed, line) == nil then
			chips[line.id] = nil
			seen(self, seats[index], nil)
		end
	end
	local seat = 1
	for _, entry in feed do
		if chips[entry.id] == nil then
			while seats[seat]._seen ~= nil do
				seat += 1
			end
			chips[entry.id] = seats[seat]
			seen(self, seats[seat], entry)
		end
	end
end

-- Pops in each banner new to its slot and each new line of the feed.
function BannerMotion.watch(self: BannerMotion, state: HudState.HudState)
	seen(self, self.line, state.banner)
	seen(self, self.message, state.message)
	seatChips(self, state.feed)
end

-- Moves each slot's leave on with its banner's or line's time left.
function BannerMotion.step(self: BannerMotion, state: HudState.HudState)
	leaving(self, self.line, state.banner, state.bannerLeft)
	leaving(self, self.message, state.message, state.messageLeft)
	local chips = self.chips
	for _, entry in state.feed do
		leaving(self, chips[entry.id], entry, entry.timeLeft)
	end
end

return BannerMotion
