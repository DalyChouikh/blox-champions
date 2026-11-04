--!strict
-- A HUD part with no time of its own to count, which the game opens and closes (the owner, Q194: every HUD change
-- animates): the Get Up prompt (#369), the TAB board (#357). Opening it pops it in from nothing, solid (motion.pop's
-- overshoot and back); closing it fades it out over motion.easeSeconds; it shows from its opening until it has gone
-- (`shown`), so its part stays drawn while it fades. On two Animator tracks: its pop (`scale`, 1 at rest) and its fade
-- (`leave`, 0 to 1), which the part reads as a UIScale and a group's transparency.

local Animator = require(script.Parent.Animator)

local Reveal = {}
Reveal.__index = Reveal

type Fields = {
	scale: Animator.Track,
	leave: Animator.Track,
	_animator: Animator.Animator,
	_open: boolean,
}

export type Reveal = typeof(setmetatable({} :: Fields, Reveal))

function Reveal.new(animator: Animator.Animator): Reveal
	local fields: Fields = {
		scale = animator:track(1),
		leave = animator:track(0),
		_animator = animator,
		_open = false,
	}
	return setmetatable(fields, Reveal)
end

-- Opens or closes it; nothing starts again while it stays as it is.
function Reveal.set(self: Reveal, open: boolean)
	if open == self._open then
		return
	end
	self._open = open
	local animator = self._animator
	if open then
		animator:rest(self.leave, 0)
		animator:rest(self.scale, 0)
		animator:play(self.scale, "Pop", 1)
	else
		animator:play(self.leave, "Ease", 1)
	end
end

-- Whether it is on the screen: from its opening until it has faded out.
function Reveal.shown(self: Reveal): boolean
	return self._open or self.leave.moving
end

return Reveal
