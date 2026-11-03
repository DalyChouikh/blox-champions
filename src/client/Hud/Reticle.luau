--!strict
-- The crosshair (spec §11.1), Roller Champions' way in X1 (the owner, Q185 and Q188b), shown while the viewer carries
-- the ball: a dot where throws, rolls and passes aim, centred across the screen and UI.hud.layout.reticle.height of the
-- way down it, above the skater as RC's sits (Q123/Q127), ringed by RC's small carrying ring (Video 32 at 2.4 s, Q143).
-- The HUD draws it in a gui spanning the whole screen, so the camera's ray through that point is the aim
-- (ActionController), and with a locked mouse it stands in for the cursor. While a throw charges, the carrying ring
-- grows out into the charge ring and fades over the charge's first growShare, as the charge ring fills from its bottom
-- up both sides at once, one stroke with no seam (Q188b), and closes at a full charge (RC's, Video 32 at 2.6-3.2 s);
-- held on, the closed ring blinks until the charge ends (Q142, Video 32 at 3.3-4.6 s). Everything is in the viewer's
-- team colour over look C's ink, at a phone's sizes on a phone's screen. Where they would touch the scoreboard the
-- rings shrink round the dot by `scale` (HudScreen.ringScale); the dot never moves. The charge ring shows inside a
-- frame that clips it and grows from its bottom, so its ink and its colour are cut on one line and it closes whole. A
-- plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local Throw = require(ReplicatedStorage.Shared.Actions.Throw)

-- `charge` is how long the throw key has been held while a throw charges, on past a full charge, and 0 otherwise
-- (ActionController:chargeSeconds). `compact`: a phone's screen (HudScreen.compact); `color`: the viewer's team's.
export type ReticleProps = {
	config: Config.GameConfig,
	compact: boolean,
	color: Color3,
	visible: boolean,
	charge: React.Binding<number>,
	scale: number,
}

local CENTRE, MIDDLE, FULL = Style.CENTRE, Style.MIDDLE, Style.FULL

-- How much of the charge ring shows, from its bottom, for a share of a full charge (0..1, Throw.share), in SWEEP_STEPS
-- even steps made once, so a charging frame allocates nothing: the clip, anchored at the ring's bottom, is
-- (1 - cos(π x share)) / 2 of the ring tall, so its top crosses the ring at the angle π x share from its bottom.
local SWEEP_STEPS = 64
local SWEEP: { UDim2 } = {}
for step = 0, SWEEP_STEPS do
	SWEEP[step + 1] = UDim2.fromScale(1, (1 - math.cos(math.pi * step / SWEEP_STEPS)) / 2)
end

local function sweepSize(share: number): UDim2
	return SWEEP[math.round(share * SWEEP_STEPS) + 1]
end

-- How see-through the ring is `past` seconds after a full charge (none before it): one blink every `blinkSeconds`,
-- lit at the full charge, gone half a blink on and lit again a whole one on, smoothly.
local function blinkTransparency(past: number, blinkSeconds: number): number
	if past <= 0 then
		return 0
	end
	return 0.5 - 0.5 * math.cos(2 * math.pi * past / blinkSeconds)
end

local function charging(held: number): boolean
	return held > 0
end

local function Reticle(props: ReticleProps): React.ReactElement
	local config, charge, color = props.config, props.charge, props.color
	local look = config.UI.hud.look
	local reticle = config.UI.hud.layout.reticle
	local rings = HudScreen.rings(config, props.compact)
	-- The charge ring's ink reaches this far across: the reticle's box.
	local reach = rings.charge + 2 * look.textOutline
	-- One charge, ChargeThrow's (Roll Ball spends it too).
	local throw = config.Actions.ChargeThrow.throw :: Config.ThrowSettings
	-- How far the carrying ring has grown out: from 0 at the press to 1 at the charge's growShare, where it has
	-- become the charge ring and hides.
	local function grown(held: number): number
		return Throw.share(throw, held) / reticle.growShare
	end
	local growth = rings.charge / rings.carry - 1
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = CENTRE,
			Position = UDim2.fromScale(0.5, reticle.height),
			Size = UDim2.fromOffset(reach, reach),
			Visible = props.visible,
		}),
		{
			Dot = React.createElement(
				"Frame",
				Style.above({
					AnchorPoint = CENTRE,
					Position = MIDDLE,
					Size = UDim2.fromOffset(reticle.size, reticle.size),
					BackgroundColor3 = color,
					BorderSizePixel = 0,
				}),
				{
					Corner = Style.round(),
					Ink = React.createElement("UIStroke", { Color = look.ink, Thickness = look.textOutline }),
				}
			),
			Rings = React.createElement(
				"Frame",
				Style.holder({ AnchorPoint = CENTRE, Position = MIDDLE, Size = FULL }),
				{
					Fit = React.createElement("UIScale", { Scale = props.scale }),
					Carry = React.createElement(
						"Frame",
						Style.holder({
							AnchorPoint = CENTRE,
							Position = MIDDLE,
							Size = FULL,
							Visible = charge:map(function(held: number): boolean
								return grown(held) < 1
							end),
						}),
						{
							Grow = React.createElement("UIScale", {
								Scale = charge:map(function(held: number): number
									return 1 + growth * grown(held)
								end),
							}),
							Ring = Style.inkedRing(
								config,
								{ AnchorPoint = CENTRE, Position = MIDDLE },
								rings.carry,
								rings.thickness,
								color,
								charge:map(grown)
							),
						}
					),
					Charge = React.createElement(
						"Frame",
						Style.holder({
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.fromScale(0, 1),
							Size = charge:map(function(held: number): UDim2
								return sweepSize(Throw.share(throw, held))
							end),
							ClipsDescendants = true,
							Visible = charge:map(charging),
						}),
						{
							-- It stays where the reticle's box is as the clip grows: its bottom on the clip's.
							Ring = Style.inkedRing(
								config,
								{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1) },
								rings.charge,
								rings.thickness,
								color,
								charge:map(function(held: number): number
									return blinkTransparency(held - throw.chargeMaxSeconds, reticle.blinkSeconds)
								end)
							),
						}
					),
				}
			),
		}
	)
end

return Reticle
