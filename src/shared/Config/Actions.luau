--!strict
-- The players' actions (spec §8.1–8.2): one entry per action, with its phases, cooldown, what it requires and what it
-- does. Adding an action is an entry here plus one effect function in ActionService. Times are in seconds, speeds in
-- studs/s and cones are half-angles in degrees, as Movement's are. The values the spec doesn't give (Dive's push and
-- cooldown, Dodge's and Uppercut's phases, the aim of each strike) are starting points for tuning, like the spec's own.

local Validate = require(script.Parent.Validate)

export type ActionName = "Tackle" | "Dive" | "Dodge" | "Uppercut" | "ChargeThrow" | "Pass" | "CallPass"
-- What the server does with an action: knock down who it reaches, make the player immune, throw, pass or call.
export type Effect = "Knockdown" | "Dodge" | "Throw" | "Pass" | "CallPass"
-- How a skater is posed while the action winds up and strikes.
export type PoseName = "Lunge" | "None"

export type Phases = { windup: number, active: number, recovery: number }
-- Whether an action needs the ball in hand, needs empty hands, or either.
export type BallRequirement = "with" | "without" | "any"
export type Requires = {
	ball: BallRequirement,
	grounded: "grounded" | "airborne" | "any",
	notKnockedDown: boolean,
}
-- Who a strike reaches: within range, and within coneDeg of the facing pitched up by aimUpDeg.
export type Hit = { range: number, coneDeg: number, aimUpDeg: number, knockdownSeconds: number }
-- The push an action gives its skater when it starts.
export type Motion = {
	lungeSpeed: number?,
	sideSpeed: number?,
	-- Straight up, anywhere: the Uppercut's leap (#219).
	leapImpulse: number?,
}
export type ThrowSettings = {
	-- Holding this long charges the throw fully.
	chargeMaxSeconds: number,
	minSpeed: number,
	maxSpeed: number,
	-- The share of the carrier's velocity the ball keeps.
	inheritCarrierVelocity: number,
}
export type PassSettings = {
	speed: number,
	homingAccel: number,
	-- Without a caller, a pass goes to the best teammate within coneDeg of the aim and maxRange, scored by
	-- angleWeight × (1 − angle / coneDeg) + distanceWeight × (1 − distance / maxRange).
	coneDeg: number,
	maxRange: number,
	angleWeight: number,
	distanceWeight: number,
}
export type ActionConfig = {
	phases: Phases,
	-- From the action's start.
	cooldown: number,
	requires: Requires,
	effect: Effect,
	pose: PoseName,
	hit: Hit?,
	motion: Motion?,
	-- Another action that may start during this one's `window` phase, replacing it.
	followUp: { action: ActionName, window: "Active" }?,
	throw: ThrowSettings?,
	pass: PassSettings?,
}
export type ActionsConfig = {
	-- Pushes in the air are this much of their ground value (spec's air tackle and air dodge).
	airMultiplier: number,
	-- A call for a pass lasts this long.
	callPassWindow: number,
	-- A knocked-down skater who moves gets up this long after the knockdown, or at once if it is later; one who never
	-- moves gets up at the end of their hit's knockdownSeconds.
	getUpAfter: number,
	Tackle: ActionConfig,
	Dive: ActionConfig,
	Dodge: ActionConfig,
	Uppercut: ActionConfig,
	ChargeThrow: ActionConfig,
	Pass: ActionConfig,
	CallPass: ActionConfig,
}

-- Every action, in a fixed order.
local names: { ActionName } = { "Tackle", "Dive", "Dodge", "Uppercut", "ChargeThrow", "Pass", "CallPass" }
table.freeze(names)

-- The same names as plain strings, for the schema's one-of checks.
local nameStrings: { string } = {}
for _, name in names do
	table.insert(nameStrings, name)
end

-- The action called `name`, or nil: a name read back as a plain string (an attribute, a message) typed again.
local function nameOf(name: string?): ActionName?
	for _, action: ActionName in names do
		if action == name then
			return action
		end
	end
	return nil
end

local function requires(ball: BallRequirement): Requires
	return { ball = ball, grounded = "any", notKnockedDown = true }
end

local INSTANT: Phases = { windup = 0, active = 0, recovery = 0 }

local defaults: ActionsConfig = {
	airMultiplier = 0.8,
	callPassWindow = 3,
	-- The owner (#220): any movement key gets a skater up, not before 0.5 s; RC's knockdown lasted under 1.8 s.
	getUpAfter = 0.5,
	Tackle = {
		phases = { windup = 0.05, active = 0.25, recovery = 0.35 },
		cooldown = 0.8,
		requires = requires("without"),
		effect = "Knockdown",
		pose = "Lunge",
		hit = { range = 7, coneDeg = 50, aimUpDeg = 0, knockdownSeconds = 1.5 },
		motion = { lungeSpeed = 40 },
		followUp = { action = "Dive", window = "Active" },
	},
	Dive = {
		phases = { windup = 0, active = 0.35, recovery = 0.9 },
		cooldown = 0.8,
		requires = requires("without"),
		effect = "Knockdown",
		pose = "Lunge",
		hit = { range = 11, coneDeg = 50, aimUpDeg = 0, knockdownSeconds = 1.5 },
		motion = { lungeSpeed = 60 },
	},
	-- Tackle-immune exactly while active.
	Dodge = {
		phases = { windup = 0, active = 0.3, recovery = 0.2 },
		cooldown = 1.5,
		requires = requires("with"),
		effect = "Dodge",
		pose = "None",
		motion = { sideSpeed = 45 },
	},
	-- Aimed up, so its cone covers "in front and above"; it leaps the skater up anywhere, 110² / (2 × 196.2) = 31 studs
	-- from the ground (the owner, #219: RC's uppercut launches on open floor).
	Uppercut = {
		phases = { windup = 0.05, active = 0.2, recovery = 0.4 },
		cooldown = 1.2,
		requires = requires("without"),
		effect = "Knockdown",
		pose = "None",
		hit = { range = 6, coneDeg = 60, aimUpDeg = 30, knockdownSeconds = 1.5 },
		motion = { leapImpulse = 110 },
	},
	ChargeThrow = {
		phases = INSTANT,
		cooldown = 0,
		requires = requires("with"),
		effect = "Throw",
		pose = "None",
		throw = { chargeMaxSeconds = 1, minSpeed = 60, maxSpeed = 160, inheritCarrierVelocity = 0.5 },
	},
	Pass = {
		phases = INSTANT,
		cooldown = 0,
		requires = requires("with"),
		effect = "Pass",
		pose = "None",
		pass = { speed = 90, homingAccel = 60, coneDeg = 70, maxRange = 120, angleWeight = 0.6, distanceWeight = 0.4 },
	},
	CallPass = {
		phases = INSTANT,
		cooldown = 1,
		requires = requires("without"),
		effect = "CallPass",
		pose = "None",
	},
}

local positive = Validate.number({ above = 0 })
local nonNegative = Validate.number({ min = 0 })
local fraction = Validate.number({ min = 0, max = 1 })
local cone = Validate.number({ above = 0, max = 180 })

local phases = Validate.record({ windup = nonNegative, active = nonNegative, recovery = nonNegative })
local requiresSchema = Validate.record({
	ball = Validate.string({ oneOf = { "with", "without", "any" } }),
	grounded = Validate.string({ oneOf = { "grounded", "airborne", "any" } }),
	notKnockedDown = Validate.boolean(),
})
local hit = Validate.record({
	range = positive,
	coneDeg = cone,
	aimUpDeg = Validate.number({ min = 0, max = 90 }),
	knockdownSeconds = positive,
})
local throw = Validate.check(
	Validate.record({
		chargeMaxSeconds = positive,
		minSpeed = positive,
		maxSpeed = positive,
		inheritCarrierVelocity = fraction,
	}),
	function(settings: ThrowSettings): boolean
		return settings.maxSpeed >= settings.minSpeed
	end,
	"maxSpeed must be at least minSpeed"
)
local pass = Validate.check(
	Validate.record({
		speed = positive,
		homingAccel = nonNegative,
		coneDeg = cone,
		maxRange = positive,
		angleWeight = nonNegative,
		distanceWeight = nonNegative,
	}),
	function(settings: PassSettings): boolean
		return settings.angleWeight + settings.distanceWeight > 0
	end,
	"angleWeight + distanceWeight must be above 0"
)

local function followUp(own: ActionName): Validate.Validator
	return Validate.record({
		action = Validate.check(Validate.string({ oneOf = nameStrings }), function(action: string): boolean
			return action ~= own
		end, "must name another action"),
		window = Validate.string({ oneOf = { "Active" } }),
	})
end

-- An action's record: the fields every action has, plus its own. Its effect is the default's and no other: modes
-- change an action's numbers, never what it does (Net/Schemas shapes each action's request by its effect).
local function action(default: ActionConfig, own: { [string]: Validate.Validator }): Validate.Validator
	-- A plain string: luau tables are invariant, so { Effect } is not the { string } oneOf takes.
	local effect: string = default.effect
	local fields: { [string]: Validate.Validator } = {
		phases = phases,
		cooldown = nonNegative,
		requires = requiresSchema,
		effect = Validate.string({ oneOf = { effect } }),
		pose = Validate.string({ oneOf = { "Lunge", "None" } }),
	}
	for name, validator in own do
		fields[name] = validator
	end
	return Validate.record(fields)
end

local schema = Validate.record({
	airMultiplier = fraction,
	callPassWindow = positive,
	getUpAfter = positive,
	Tackle = action(defaults.Tackle, {
		hit = hit,
		motion = Validate.record({ lungeSpeed = positive }),
		followUp = followUp("Tackle"),
	}),
	Dive = action(defaults.Dive, { hit = hit, motion = Validate.record({ lungeSpeed = positive }) }),
	Dodge = action(defaults.Dodge, { motion = Validate.record({ sideSpeed = positive }) }),
	Uppercut = action(defaults.Uppercut, {
		hit = hit,
		motion = Validate.record({ leapImpulse = positive }),
	}),
	ChargeThrow = action(defaults.ChargeThrow, { throw = throw }),
	Pass = action(defaults.Pass, { pass = pass }),
	CallPass = action(defaults.CallPass, {}),
})

return {
	defaults = defaults,
	schema = schema,
	names = names,
	nameOf = nameOf,
}
