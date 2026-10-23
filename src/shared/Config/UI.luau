--!strict
-- HUD settings (spec §11.2). The clock-warning marks also drive the rules' ClockWarning events (spec §5.1).
-- Team colors are the one source for everything drawn in a team's color (spawn pads now, the HUD later). Control
-- labels name each control as it acts now: a touch button reads Dodge with the ball, Tackle without.

local Validate = require(script.Parent.Validate)

-- One label per action, plus the controls that start none (Ball Focus and the skating buttons).
export type ControlLabels = {
	Jump: string,
	Pump: string,
	Brake: string,
	Attach: string,
	Tackle: string,
	Dive: string,
	Dodge: string,
	Uppercut: string,
	ChargeThrow: string,
	Pass: string,
	CallPass: string,
	BallFocus: string,
}

-- How the touch controls look: the stick's ring and the buttons on `background`, the knob and the labels in
-- `foreground` (the knob knobTransparency see-through), rounded by `corner`. A label is at most textSize pixels tall,
-- shrinking to fit within textPadding pixels of its button's sides.
export type TouchStyle = {
	background: Color3,
	backgroundTransparency: number,
	foreground: Color3,
	font: Enum.Font,
	corner: UDim,
	textSize: number,
	textPadding: number,
	knobTransparency: number,
}

export type UIConfig = {
	clockWarnings: { number },
	teamColors: { Blue: Color3, Orange: Color3 },
	controlLabels: ControlLabels,
	touchStyle: TouchStyle,
}

local defaults: UIConfig = {
	clockWarnings = { 60, 30 },
	teamColors = { Blue = Color3.fromRGB(13, 105, 172), Orange = Color3.fromRGB(218, 133, 65) },
	controlLabels = {
		Jump = "Jump",
		Pump = "Pump",
		Brake = "Brake",
		Attach = "Attach",
		Tackle = "Tackle",
		Dive = "Dive",
		Dodge = "Dodge",
		Uppercut = "Uppercut",
		ChargeThrow = "Throw",
		Pass = "Pass",
		CallPass = "Call",
		BallFocus = "Focus",
	},
	-- Roblox's own touch thumbstick colors; the art pass restyles them.
	touchStyle = {
		background = Color3.fromRGB(18, 18, 21),
		backgroundTransparency = 0.4,
		foreground = Color3.fromRGB(213, 215, 221),
		font = Enum.Font.BuilderSansBold,
		corner = UDim.new(0.5, 0),
		textSize = 18,
		textPadding = 6,
		knobTransparency = 0,
	},
}

local function noDuplicates(values: { number }): boolean
	local seen: { [number]: boolean } = {}
	for _, value in values do
		if seen[value] then
			return false
		end
		seen[value] = true
	end
	return true
end

local label = Validate.string({ nonEmpty = true })

local schema = Validate.record({
	clockWarnings = Validate.check(
		Validate.list(Validate.number({ min = 1, integer = true })),
		noDuplicates,
		"must not contain duplicates"
	),
	teamColors = Validate.record({ Blue = Validate.datatype("Color3"), Orange = Validate.datatype("Color3") }),
	controlLabels = Validate.record({
		Jump = label,
		Pump = label,
		Brake = label,
		Attach = label,
		Tackle = label,
		Dive = label,
		Dodge = label,
		Uppercut = label,
		ChargeThrow = label,
		Pass = label,
		CallPass = label,
		BallFocus = label,
	}),
	touchStyle = Validate.record({
		background = Validate.datatype("Color3"),
		backgroundTransparency = Validate.number({ min = 0, max = 1 }),
		foreground = Validate.datatype("Color3"),
		font = Validate.enumItem(Enum.Font),
		corner = Validate.datatype("UDim"),
		-- Roblox clamps text sizes to 1..100 (measured).
		textSize = Validate.number({ min = 1, max = 100, integer = true }),
		textPadding = Validate.number({ min = 0 }),
		knobTransparency = Validate.number({ min = 0, max = 1 }),
	}),
})

return {
	defaults = defaults,
	schema = schema,
}
