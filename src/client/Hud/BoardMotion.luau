--!strict
-- How the scoreboard moves (the owner, Q194 and Q196), from one match snapshot to the next (`watch`, whenever the HUD's
-- state changes): a team's score bounces as it rises; the possessing team's lap chips fill as its gates are crossed,
-- and at the lap's last gate the fourth fills, the row holds full, then empties for the next lap; the chips move at
-- once to the other team when the ball changes hands, and empty when it goes loose; the goal's worth chip pops in as
-- the goal opens and glows while it is open, bounces as the worth grows, and shrinks away as the goal closes, keeping
-- its last text and team colour as it goes. The first snapshot shows everything at rest. Each value is an Animator
-- track (one per lap chip, made when the arena's gates are first known) the scoreboard reads through its binding.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animator = require(script.Parent.Animator)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local MatchEngine = require(ReplicatedStorage.Shared.Rules.MatchEngine)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

type Team = Team.Team
type Track = Animator.Track

local BoardMotion = {}
BoardMotion.__index = BoardMotion

-- What the last snapshot showed.
type Seen = {
	scores: { [Team]: number },
	team: Team?,
	streak: number,
	worth: string?,
}

type Fields = {
	-- Each score's scale (1 at rest).
	scores: { Blue: Track, Orange: Track },
	-- Each lap chip's fill, 0 to 1, in gate order.
	chips: { Track },
	-- The worth chip's scale (0 while hidden), its bounce, and the transparency of its glowing veil (1: none).
	worth: Track,
	worthBounce: Track,
	glow: Track,
	-- What the worth chip says and whose colour it is in: the goal's while it is open, kept while it shrinks away.
	worthText: string,
	worthTeam: Team?,
	_text: HudText.HudText,
	_animator: Animator.Animator,
	_seen: Seen?,
}

export type BoardMotion = typeof(setmetatable({} :: Fields, BoardMotion))

function BoardMotion.new(text: HudText.HudText, animator: Animator.Animator): BoardMotion
	return setmetatable(
		{
			scores = { Blue = animator:track(1), Orange = animator:track(1) },
			chips = {},
			worth = animator:track(0),
			worthBounce = animator:track(1),
			glow = animator:track(1),
			worthText = "",
			worthTeam = nil,
			_text = text,
			_animator = animator,
			_seen = nil,
		} :: Fields,
		BoardMotion
	)
end

-- Whether lap chip `index` is full in `match`: one per gate the possessing team has crossed this lap (none while
-- nobody has had the ball since the kickoff, which resets the laps).
local function full(match: MatchEngine.Snapshot, index: number): number
	return if index <= match.lapProgress then 1 else 0
end

local function moveChips(self: BoardMotion, match: MatchEngine.Snapshot, seen: Seen?)
	local animator = self._animator
	local chips = self.chips
	while #chips < match.gateCount do
		table.insert(chips, animator:track(0))
	end
	local sameTeam = seen ~= nil and match.possessingTeam == seen.team
	local lapped = sameTeam and match.streak > (seen :: Seen).streak
	-- By index, as Animator steps its tracks (luau-lsp's for-in check rejects a track's binding).
	for index = 1, #chips do
		local chip = chips[index]
		local target = full(match, index)
		if lapped then
			animator:play(chip, "Lap", target)
		elseif not sameTeam then
			animator:rest(chip, target)
		elseif target ~= chip.target then
			animator:play(chip, "Ease", target)
		end
	end
end

local function moveWorth(self: BoardMotion, match: MatchEngine.Snapshot, worth: string?, seen: Seen?)
	local animator = self._animator
	local wasOpen = seen ~= nil and seen.worth ~= nil
	if worth ~= nil then
		self.worthText = worth
		self.worthTeam = match.goalOpenFor
		if seen == nil then
			animator:rest(self.worth, 1)
			animator:play(self.glow, "Glow", 1)
		elseif not wasOpen then
			animator:play(self.worth, "Pop", 1)
			animator:play(self.glow, "Glow", 1)
		elseif worth ~= (seen :: Seen).worth then
			animator:play(self.worthBounce, "Bounce", 1)
		end
	elseif wasOpen then
		animator:play(self.worth, "Ease", 0)
		animator:rest(self.glow, 1)
	end
end

function BoardMotion.watch(self: BoardMotion, match: MatchEngine.Snapshot?)
	if match == nil then
		return
	end
	local seen = self._seen
	if seen ~= nil then
		for _, team: Team in Team.list do
			if match.scores[team] > seen.scores[team] then
				self._animator:play(self.scores[team], "Bounce", 1)
			end
		end
	end
	local worth = self._text:worth(match)
	moveChips(self, match, seen)
	moveWorth(self, match, worth, seen)
	local now: Seen = seen or { scores = {}, team = nil, streak = 0, worth = nil }
	for _, team: Team in Team.list do
		now.scores[team] = match.scores[team]
	end
	now.team, now.streak, now.worth = match.possessingTeam, match.streak, worth
	self._seen = now
end

return BoardMotion
