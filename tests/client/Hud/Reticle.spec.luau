--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local React = require(ReplicatedStorage.Packages.React)
local Reticle = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Reticle)

-- Round sizes of this spec's own: a 2 px ink; on a desktop's screen a 40 px carrying ring and a 100 px charge ring
-- with 4 px strokes (the charge ring's ink reaching 104 across), on a phone's 20 and 50 with 2 px strokes; the
-- carrying ring grown out and gone over the first half of the charge.
local config = Fixtures.config({
	UI = {
		hud = {
			look = { ink = Color3.fromRGB(10, 20, 30), textOutline = 2 },
			layout = {
				reticle = {
					size = 6,
					height = 0.3,
					blinkSeconds = 0.4,
					growShare = 0.5,
					sizes = { carry = 40, charge = 100, thickness = 4 },
					compactSizes = { carry = 20, charge = 50, thickness = 2 },
				},
			},
		},
	},
})
local INK = Color3.fromRGB(10, 20, 30)
local TEAM = Color3.fromRGB(200, 120, 40)
-- A full charge's seconds: the binding carries how long the throw key has been held.
local FULL = (config.Actions.ChargeThrow.throw :: Config.ThrowSettings).chargeMaxSeconds

local folder: Folder?

afterEach(function()
	Fixtures.unmountAll()
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
end)

type Shown = { visible: boolean?, compact: boolean?, scale: number? }

-- The reticle as the HUD draws it, keyed as App keys it: shown or hidden, the charge's binding (#312), the screen's
-- kind and the scale that keeps it clear of the scoreboard (#353).
local function element(charge: React.Binding<number>, shown: Shown?): React.ReactElement
	local options: Shown = shown or {}
	return React.createElement(React.Fragment, nil, {
		Reticle = React.createElement(Reticle, {
			config = config,
			compact = options.compact == true,
			color = TEAM,
			visible = options.visible ~= false,
			charge = charge,
			scale = options.scale or 1,
		}),
	})
end

-- Mounts the reticle; returns its frame and a rerender.
local function mount(charge: React.Binding<number>, shown: Shown?): (Frame, (element: any) -> ())
	local parent = Instance.new("Folder")
	parent.Name = "ReticleTest"
	parent.Parent = workspace
	folder = parent
	local mounted, rerender = Fixtures.mount(element(charge, shown), parent)
	return mounted:FindFirstChild("Reticle") :: Frame, rerender
end

-- A ring's colour stroke and its ink stroke (Style.inkedRing).
local function strokes(ring: Instance): (UIStroke, UIStroke)
	local line = (ring:FindFirstChild("Line") :: Instance):FindFirstChildOfClass("UIStroke") :: UIStroke
	local ink = (ring:FindFirstChild("Ink") :: Instance):FindFirstChildOfClass("UIStroke") :: UIStroke
	return line, ink
end

local function carry(reticle: Frame): Frame
	return (reticle :: any).Rings.Carry
end

-- The frame that clips the charge ring, growing from its bottom.
local function clip(reticle: Frame): Frame
	return (reticle :: any).Rings.Charge
end

describe("Reticle", function()
	-- RC's crosshair sits above the skater, 30% down the screen here (#312, Q123/Q127): throws and passes aim through
	-- it; X1 in the viewer's team colour over look C's ink (the owner, Q188b).
	it("draws a dot in the team colour over its ink, centred across the screen at the crosshair's height", function()
		local charge = React.createBinding(0)
		local reticle, rerender = mount(charge)
		expect(reticle.AnchorPoint == Vector2.new(0.5, 0.5)).toBe(true)
		expect(reticle.Position).toEqual(UDim2.fromScale(0.5, 0.3))
		expect(reticle.Size).toEqual(UDim2.fromOffset(104, 104))
		expect(reticle.BackgroundTransparency).toBe(1)
		local dot = reticle:FindFirstChild("Dot") :: Frame
		expect(dot.AnchorPoint == Vector2.new(0.5, 0.5)).toBe(true)
		expect(dot.Position).toEqual(UDim2.fromScale(0.5, 0.5))
		expect(dot.Size).toEqual(UDim2.fromOffset(6, 6))
		expect(dot.BackgroundColor3 == TEAM).toBe(true)
		expect((dot:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toEqual(UDim.new(0.5, 0))
		local ink = dot:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(ink.Color == INK).toBe(true)
		expect(ink.Thickness).toBe(2)
		-- Above the rings.
		expect(dot.ZIndex > ((reticle :: any).Rings :: Frame).ZIndex).toBe(true)
		expect(reticle.Visible).toBe(true)
		rerender(element(charge, { visible = false }))
		expect(reticle.Visible).toBe(false)
	end)

	-- RC's small ring round the dot while carrying (Video 32 at 2.4 s; Q143), 40 px here.
	it("rings the dot with the carrying ring while no throw charges, the charge ring hidden", function()
		local reticle = mount((React.createBinding(0)))
		expect(carry(reticle).Visible).toBe(true)
		local ring = (carry(reticle) :: any).Ring :: Frame
		expect(ring.Size).toEqual(UDim2.fromOffset(44, 44))
		local line, ink = strokes(ring)
		expect(line.Thickness).toBe(4)
		expect(line.Color == TEAM).toBe(true)
		expect(ink.Color == INK).toBe(true)
		expect(line.Transparency).toBe(0)
		expect((carry(reticle):FindFirstChildOfClass("UIScale") :: UIScale).Scale).toBe(1)
		expect(clip(reticle).Visible).toBe(false)
	end)

	-- X1 (the page, Q188b): over the first growShare of the charge (half, here) the carrying ring grows out to the
	-- charge ring's size (100 / 40 = 2.5 times) and fades; a quarter of the charge is half of that.
	it("grows the carrying ring out into the charge ring and fades it over the charge's first growShare", function()
		local charge, setCharge = React.createBinding(0)
		local reticle = mount(charge)
		local grow = carry(reticle):FindFirstChildOfClass("UIScale") :: UIScale
		local line, ink = strokes((carry(reticle) :: any).Ring)
		setCharge(FULL / 4)
		expect(grow.Scale).toBeCloseTo(1.75, 4)
		expect(line.Transparency).toBeCloseTo(0.5, 4)
		expect(ink.Transparency).toBeCloseTo(0.5, 4)
		expect(carry(reticle).Visible).toBe(true)
		setCharge(FULL / 2)
		expect(carry(reticle).Visible).toBe(false)
		setCharge(0)
		expect(carry(reticle).Visible).toBe(true)
		expect(grow.Scale).toBe(1)
	end)

	-- RC's ring (Video 32 at 2.6-3.2 s) fills from its bottom up both sides at once as one stroke, no seam and no gap
	-- (the owner, Q188b), and closes at a full charge: the clip, anchored at the ring's bottom, is (1 - cos(π x share))
	-- / 2 of the ring's height tall, so its top crosses the ring at the angle π x share from its bottom.
	it("fills the charge ring from its bottom up both sides as a throw charges, until it closes", function()
		local charge, setCharge = React.createBinding(0)
		local reticle = mount(charge)
		local cut = clip(reticle)
		expect(cut.ClipsDescendants).toBe(true)
		expect(cut.AnchorPoint == Vector2.new(0, 1)).toBe(true)
		expect(cut.Position).toEqual(UDim2.fromScale(0, 1))
		-- The ring inside stays put as the clip grows: its bottom on the clip's, which is the reticle's.
		local ring = (cut :: any).Ring :: Frame
		expect(ring.AnchorPoint == Vector2.new(0.5, 1)).toBe(true)
		expect(ring.Position).toEqual(UDim2.fromScale(0.5, 1))
		expect(ring.Size).toEqual(UDim2.fromOffset(104, 104))
		local cases = {
			{ share = 0.25, shown = (1 - math.cos(math.pi / 4)) / 2 },
			{ share = 0.5, shown = 0.5 },
			{ share = 0.75, shown = (1 + math.cos(math.pi / 4)) / 2 },
			{ share = 1, shown = 1 },
		}
		for _, case in cases do
			setCharge(case.share * FULL)
			expect(cut.Visible).toBe(true)
			expect(cut.Size.X.Scale).toBe(1)
			expect(cut.Size.Y.Scale).toBeCloseTo(case.shown, 4)
			expect(cut.Size.X.Offset + cut.Size.Y.Offset).toBe(0)
		end
		-- Held past a full charge: still closed.
		setCharge(3 * FULL)
		expect(cut.Size.Y.Scale).toBe(1)
		setCharge(0)
		expect(cut.Visible).toBe(false)
	end)

	-- RC's closed ring blinks until the release (Q142; Video 32 at 3.3-4.6 s, every 0.40 s): lit at a full charge,
	-- fading to nothing half a blink on and back, 0.5 - 0.5 cos(2π t / blinkSeconds) see-through t seconds past it.
	it("blinks the closed ring every blinkSeconds past a full charge, never the dot", function()
		local charge, setCharge = React.createBinding(0)
		local reticle = mount(charge)
		local dot = reticle:FindFirstChild("Dot") :: Frame
		local line, ink = strokes((clip(reticle) :: any).Ring)
		local cases = {
			{ held = FULL / 2, transparency = 0 },
			{ held = FULL, transparency = 0 },
			{ held = FULL + 0.1, transparency = 0.5 },
			{ held = FULL + 0.2, transparency = 1 },
			{ held = FULL + 0.3, transparency = 0.5 },
			{ held = FULL + 0.4, transparency = 0 },
			{ held = FULL + 1, transparency = 1 },
		}
		for _, case in cases do
			setCharge(case.held)
			expect(line.Transparency).toBeCloseTo(case.transparency, 4)
			expect(ink.Transparency).toBeCloseTo(case.transparency, 4)
			expect(dot.BackgroundTransparency).toBe(0)
		end
	end)

	it("draws a phone's sizes on a phone's screen", function()
		local reticle = mount((React.createBinding(0)), { compact = true })
		expect(reticle.Size).toEqual(UDim2.fromOffset(54, 54))
		local line = strokes((carry(reticle) :: any).Ring)
		expect(((carry(reticle) :: any).Ring :: Frame).Size).toEqual(UDim2.fromOffset(24, 24))
		expect(line.Thickness).toBe(2)
		expect(((clip(reticle) :: any).Ring :: Frame).Size).toEqual(UDim2.fromOffset(54, 54))
	end)

	-- Where the scoreboard would touch them, the rings shrink round the dot, which stays as it is
	-- (HudScreen.ringScale).
	it("shrinks the rings by its scale, never the dot", function()
		local charge = React.createBinding(0)
		local reticle, rerender = mount(charge, { scale = 0.8 })
		local rings = (reticle :: any).Rings :: Frame
		expect(rings.AnchorPoint == Vector2.new(0.5, 0.5)).toBe(true)
		expect(rings.Position).toEqual(UDim2.fromScale(0.5, 0.5))
		expect((rings:FindFirstChildOfClass("UIScale") :: UIScale).Scale).toBeCloseTo(0.8, 6)
		expect((reticle:FindFirstChild("Dot") :: Frame):FindFirstChildOfClass("UIScale")).toBeNil()
		rerender(element(charge, { scale = 1 }))
		expect((rings:FindFirstChildOfClass("UIScale") :: UIScale).Scale).toBe(1)
	end)
end)
