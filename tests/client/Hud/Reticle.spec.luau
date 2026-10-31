--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local React = require(ReplicatedStorage.Packages.React)
local Reticle = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Hud.Reticle)

local config = Fixtures.config()
local hud = config.UI.hud
local layout = hud.layout.reticle

local folder: Folder?

afterEach(function()
	Fixtures.unmountAll()
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
end)

-- The reticle as the HUD draws it: shown or hidden, with the charge's binding (#312).
local function element(visible: boolean, charge: React.Binding<number>): React.ReactElement
	return React.createElement(
		React.Fragment,
		nil,
		{ Reticle = React.createElement(Reticle, { config = config, visible = visible, charge = charge }) }
	)
end

-- Mounts the reticle; returns its frame and a rerender.
local function mount(visible: boolean, charge: React.Binding<number>): (Frame, (element: any) -> ())
	local parent = Instance.new("Folder")
	parent.Name = "ReticleTest"
	parent.Parent = workspace
	folder = parent
	local mounted, rerender = Fixtures.mount(element(visible, charge), parent)
	return mounted:FindFirstChild("Reticle") :: Frame, rerender
end

-- A ring half's gradient, which shows the half below its edge.
local function sweep(reticle: Frame, side: string): UIGradient
	return (reticle :: any).Ring[side].Arc.Stroke.Sweep
end

describe("Reticle", function()
	-- RC's crosshair sits above the skater, 31.5% down the screen (#312, Q123/Q127): throws and passes aim through it.
	it("draws a dot centred across the screen at the crosshair's height, unless told to hide", function()
		local charge = React.createBinding(0)
		local reticle, rerender = mount(true, charge)
		expect(reticle.AnchorPoint == Vector2.new(0.5, 0.5)).toBe(true)
		expect(reticle.Position == UDim2.fromScale(0.5, layout.height)).toBe(true)
		expect(reticle.Size == UDim2.fromOffset(layout.ringSize, layout.ringSize)).toBe(true)
		expect(reticle.BackgroundTransparency).toBe(1)
		local dot = reticle:FindFirstChild("Dot") :: Frame
		expect(dot.AnchorPoint == Vector2.new(0.5, 0.5)).toBe(true)
		expect(dot.Position == UDim2.fromScale(0.5, 0.5)).toBe(true)
		expect(dot.Size == UDim2.fromOffset(layout.size, layout.size)).toBe(true)
		expect(dot.BackgroundColor3 == hud.textColor).toBe(true)
		expect((dot:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius == UDim.new(0.5, 0)).toBe(true)
		expect(reticle.Visible).toBe(true)
		rerender(element(false, charge))
		expect(reticle.Visible).toBe(false)
	end)

	-- RC's ring (Video 32 at 2.6-3.2 s): its two halves grow from the bottom up both sides at once, evenly by angle,
	-- and close at a full charge. A half shows below its gradient's edge, which sits 0.5 + offset of the way down the
	-- ring: up to the angle π x charge from the bottom, cos of that angle x 0.5 below the middle.
	it("shows no ring until a throw charges, then builds it from the bottom up both sides until it closes", function()
		local charge, setCharge = React.createBinding(0)
		local reticle = mount(true, charge)
		local ring = (reticle :: any).Ring :: Frame
		expect(ring.Visible).toBe(false)
		local cases = {
			{ charge = 0.25, offset = 0.5 * math.cos(math.pi / 4) },
			{ charge = 0.5, offset = 0 },
			{ charge = 0.75, offset = -0.5 * math.cos(math.pi / 4) },
			{ charge = 1, offset = -0.5 },
		}
		for _, case in cases do
			setCharge(case.charge)
			expect(ring.Visible).toBe(true)
			for _, side in { "Left", "Right" } do
				local gradient = sweep(reticle, side)
				expect(gradient.Offset.X).toBe(0)
				expect(gradient.Offset.Y).toBeCloseTo(case.offset, 4)
			end
		end
		setCharge(0)
		expect(ring.Visible).toBe(false)
	end)

	it("hides each half above its gradient's edge, from the top down the ring", function()
		local reticle = mount(true, (React.createBinding(1)))
		for _, side in { "Left", "Right" } do
			local gradient = sweep(reticle, side)
			expect(gradient.Rotation).toBe(90)
			local keypoints = gradient.Transparency.Keypoints
			expect(keypoints[1].Time).toBe(0)
			expect(keypoints[#keypoints].Time).toBe(1)
			-- One sharp edge, at the middle: hidden above it, shown below it.
			for _, keypoint in keypoints do
				expect(keypoint.Value).toBe(if keypoint.Time < 0.5 then 1 else 0)
			end
		end
	end)

	-- Each half is the whole ring, ringSize across with a ringThickness stroke, clipped to its side of a ringGap:
	-- both rings start ringThickness in from the reticle's left edge, so they are one circle.
	it("cuts one ring into two halves a gap apart, ringSize across, in the HUD's text colour", function()
		local reticle = mount(true, (React.createBinding(1)))
		local size, thickness, gap = layout.ringSize, layout.ringThickness, layout.ringGap
		local ring = (reticle :: any).Ring :: Frame
		expect(ring.Size == UDim2.fromScale(1, 1)).toBe(true)
		for _, side in { "Left", "Right" } do
			local clip = (ring :: any)[side] :: Frame
			expect(clip.ClipsDescendants).toBe(true)
			expect(clip.Size == UDim2.new(0.5, -gap / 2, 1, 0)).toBe(true)
			local arc = (clip :: any).Arc :: Frame
			expect(arc.Size == UDim2.fromOffset(size - 2 * thickness, size - 2 * thickness)).toBe(true)
			expect(arc.Position.Y.Offset).toBe(thickness)
			local left = clip.Position.X.Scale * size + clip.Position.X.Offset + arc.Position.X.Offset
			expect(left).toBeCloseTo(thickness, 6)
			expect(arc.BackgroundTransparency).toBe(1)
			expect((arc:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius == UDim.new(0.5, 0)).toBe(true)
			local stroke = (arc :: any).Stroke :: UIStroke
			expect(stroke.Thickness).toBe(thickness)
			expect(stroke.Color == hud.textColor).toBe(true)
		end
		expect((ring :: any).Left.Position == UDim2.new()).toBe(true)
		expect((ring :: any).Right.Position == UDim2.new(0.5, gap / 2, 0, 0)).toBe(true)
	end)
end)
