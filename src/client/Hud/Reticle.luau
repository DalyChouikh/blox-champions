--!strict
-- The reticle (spec §11.1): RC's crosshair (#312). A dot where throws, rolls and passes aim, centred across the screen
-- and UI.hud.layout.reticle.height of the way down it, above the skater as RC's sits (the owner, Q123/Q127). The HUD
-- draws it in a gui spanning the whole screen, so the camera's ray through that point is the aim (ActionController),
-- and with a locked mouse it stands in for the cursor. While a throw charges, a ring builds round the dot as RC's does
-- (Video 32 at 2.6-3.2 s): its two halves, a gap apart at the top and the bottom, grow from the bottom up both sides at
-- once, evenly by angle, and close at a full charge. Each half is the whole ring clipped to its side of the gap, shown
-- below the sharp edge of a gradient on its outline, an edge that rises with the charge. It hides while the score tab
-- or the end screen covers the screen (the owner's choice, 2026-10-24). A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)

-- `charge` is the throw's share of a full charge while one charges, 0 otherwise (ActionController:chargeProgress).
export type ReticleProps = { config: Config.GameConfig, visible: boolean, charge: React.Binding<number> }

-- Hidden above the gradient's middle, shown below it: one sharp edge.
local EDGE = 0.5
local SHOWN_BELOW_EDGE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(EDGE - 1e-4, 1),
	NumberSequenceKeypoint.new(EDGE, 0),
	NumberSequenceKeypoint.new(1, 0),
})

-- The edge's offset for a charge, in SWEEP_STEPS even steps made once, so a charging frame allocates nothing. A point
-- of the ring at the angle a from its bottom lies 0.5 + 0.5 cos a of the way down it (half its height round its
-- middle), and the edge at offset o lies EDGE + o down: showing the arc up to a = π × charge takes the edge there.
local SWEEP_STEPS = 64
local SWEEP: { Vector2 } = {}
for step = 0, SWEEP_STEPS do
	SWEEP[step + 1] = Vector2.new(0, 0.5 + 0.5 * math.cos(math.pi * step / SWEEP_STEPS) - EDGE)
end

-- A charge is a share of a full one, 0..1 (ActionController:chargeProgress).
local function sweepOffset(charge: number): Vector2
	return SWEEP[math.round(charge * SWEEP_STEPS) + 1]
end

local function charging(charge: number): boolean
	return charge > 0
end

-- One half of the ring, the left (side 0) or the right (side 1): the whole ring, ringThickness in from the reticle's
-- edges (its outline lies outside it, so the ring is ringSize across), in a frame that clips it to its side of the gap.
local function half(config: Config.GameConfig, side: number, charge: React.Binding<number>): React.ReactElement
	local hud = config.UI.hud
	local reticle = hud.layout.reticle
	local size, thickness, gap = reticle.ringSize, reticle.ringThickness, reticle.ringGap
	local sweep: { [string]: React.Node } = {
		Sweep = React.createElement("UIGradient", {
			Rotation = 90,
			Transparency = SHOWN_BELOW_EDGE,
			Offset = charge:map(sweepOffset),
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
			Arc = Style.ring(hud.textColor, thickness, {
				Position = UDim2.fromOffset(thickness - side * (size + gap) / 2, thickness),
				Size = UDim2.fromOffset(size - 2 * thickness, size - 2 * thickness),
			}, sweep),
		}
	)
end

local function Reticle(props: ReticleProps): React.ReactElement
	local config, charge = props.config, props.charge
	local hud = config.UI.hud
	local reticle = hud.layout.reticle
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
				{ Left = half(config, 0, charge), Right = half(config, 1, charge) }
			),
		}
	)
end

return Reticle
