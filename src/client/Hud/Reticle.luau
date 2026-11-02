--!strict
-- The reticle (spec §11.1): RC's crosshair (#312). A dot where throws, rolls and passes aim, centred across the screen
-- and UI.hud.layout.reticle.height of the way down it, above the skater as RC's sits (the owner, Q123/Q127). The HUD
-- draws it in a gui spanning the whole screen, so the camera's ray through that point is the aim (ActionController),
-- and with a locked mouse it stands in for the cursor. While a throw charges, a ring builds round the dot as RC's does
-- (Video 32 at 2.6-3.2 s): its two halves, a gap apart at the top and the bottom, grow from the bottom up both sides at
-- once, evenly by angle, and close at a full charge; held on, the closed ring blinks until the charge ends, as RC's
-- does (Q142, Video 32 at 3.3-4.6 s). Each half is the whole ring clipped to its side of the gap, shown below the sharp
-- edge of a gradient on its outline, an edge that rises with the charge. It hides while the score tab or the end
-- screen covers the screen (the owner's choice, 2026-10-24). A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local Throw = require(ReplicatedStorage.Shared.Actions.Throw)

-- `charge` is how long the throw key has been held while a throw charges, on past a full charge, and 0 otherwise
-- (ActionController:chargeSeconds).
export type ReticleProps = { config: Config.GameConfig, visible: boolean, charge: React.Binding<number> }

-- Hidden above the gradient's middle, shown below it: one sharp edge.
local EDGE = 0.5
local SHOWN_BELOW_EDGE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(EDGE - 1e-4, 1),
	NumberSequenceKeypoint.new(EDGE, 0),
	NumberSequenceKeypoint.new(1, 0),
})

-- The edge's offset for a share of a full charge (0..1, Throw.share), in SWEEP_STEPS even steps made once, so a
-- charging frame allocates nothing. A point of the ring at the angle a from its bottom lies 0.5 + 0.5 cos a of the way
-- down it (half its height round its middle), and the edge at offset o lies EDGE + o down: showing the arc up to
-- a = π × share takes the edge there.
local SWEEP_STEPS = 64
local SWEEP: { Vector2 } = {}
for step = 0, SWEEP_STEPS do
	SWEEP[step + 1] = Vector2.new(0, 0.5 + 0.5 * math.cos(math.pi * step / SWEEP_STEPS) - EDGE)
end

local function sweepOffset(share: number): Vector2
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

-- One half of the ring, the left (side 0) or the right (side 1): the whole ring, ringThickness in from the reticle's
-- edges (its outline lies outside it, so the ring is ringSize across), in a frame that clips it to its side of the gap.
-- `offset` places its gradient's edge and `fade` how see-through its outline is.
local function half(
	config: Config.GameConfig,
	side: number,
	offset: React.Binding<Vector2>,
	fade: React.Binding<number>
): React.ReactElement
	local hud = config.UI.hud
	local reticle = hud.layout.reticle
	local size, thickness, gap = reticle.ringSize, reticle.ringThickness, reticle.ringGap
	local sweep: { [string]: React.Node } = {
		Sweep = React.createElement("UIGradient", {
			Rotation = 90,
			Transparency = SHOWN_BELOW_EDGE,
			Offset = offset,
		}),
	}
	return React.createElement(
		"Frame",
		Style.holder({
			Position = UDim2.new(side * 0.5, side * gap / 2, 0, 0),
			Size = UDim2.new(0.5, -gap / 2, 1, 0),
			ClipsDescendants = true,
		}),
		{
			Arc = Style.ring({
				Position = UDim2.fromOffset(thickness - side * (size + gap) / 2, thickness),
				Size = UDim2.fromOffset(size - 2 * thickness, size - 2 * thickness),
			}, { Color = hud.textColor, Thickness = thickness, Transparency = fade }, sweep),
		}
	)
end

local function Reticle(props: ReticleProps): React.ReactElement
	local config, charge = props.config, props.charge
	local hud = config.UI.hud
	local reticle = hud.layout.reticle
	-- One charge, ChargeThrow's (Roll Ball spends it too): the ring sweeps by its share and blinks past it.
	local throw = config.Actions.ChargeThrow.throw :: Config.ThrowSettings
	local offset = charge:map(function(held: number): Vector2
		return sweepOffset(Throw.share(throw, held))
	end)
	local fade = charge:map(function(held: number): number
		return blinkTransparency(held - throw.chargeMaxSeconds, reticle.blinkSeconds)
	end)
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, reticle.height),
			Size = UDim2.fromOffset(reticle.ringSize, reticle.ringSize),
			Visible = props.visible,
		}),
		{
			Dot = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(reticle.size, reticle.size),
				BackgroundColor3 = hud.textColor,
				BorderSizePixel = 0,
			}, { Corner = Style.round() }),
			Ring = React.createElement(
				"Frame",
				Style.holder({ Size = UDim2.fromScale(1, 1), Visible = charge:map(charging) }),
				{ Left = half(config, 0, offset, fade), Right = half(config, 1, offset, fade) }
			),
		}
	)
end

return Reticle
