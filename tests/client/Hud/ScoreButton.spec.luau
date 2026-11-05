--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local React = require(ReplicatedStorage.Packages.React)
local ScoreButton = require(Client.Hud.ScoreButton)
local Style = require(Client.Hud.Style)

-- SCORES at settings of this spec's own: an 80 x 30 box 30 px under the top bar, a 5 px corner, 14 px words; a 2 px
-- outline.
local config = Fixtures.config({
	UI = {
		hud = {
			look = { outline = 2 },
			layout = {
				scoreButton = { top = 30, size = UDim2.fromOffset(80, 30), corner = UDim.new(0, 5), textSize = 14 },
			},
		},
	},
})

local folder: Folder?

afterEach(function()
	Fixtures.unmountAll()
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
end)

local function mount(left: React.Binding<number>): TextButton
	local parent = Instance.new("Folder")
	parent.Name = "ScoreButtonTest"
	parent.Parent = workspace
	folder = parent
	local element = React.createElement(ScoreButton, {
		config = config,
		left = left,
		moving = Style.stillCap,
		onActivated = function() end,
	})
	local mounted = Fixtures.mount(React.createElement(React.Fragment, nil, { ScoreButton = element }), parent)
	return mounted:FindFirstChild("ScoreButton") :: TextButton
end

describe("ScoreButton", function()
	-- S2 (#355, the owner's Q250): its right edge where the touch buttons' sits (`left`), its top under the top bar.
	it("sits its right edge at `left` and its top under Roblox's top bar, as big as its settings say", function()
		local left, setLeft = React.createBinding(500)
		local button = mount(left)
		expect(button.AnchorPoint).toEqual(Vector2.new(1, 0))
		expect(button.Position).toEqual(UDim2.fromOffset(500, 30))
		expect(button.Size).toEqual(UDim2.fromOffset(80, 30))
		setLeft(620)
		expect(button.Position).toEqual(UDim2.fromOffset(620, 30))
		-- Its face as big as it: the fill 30 - 2 x 2 tall, its sweep's square too.
		local face = button:FindFirstChild("Face") :: Frame
		expect((face:FindFirstChild("Sweep", true) :: Frame).Size).toEqual(UDim2.fromOffset(26, 26))
		local words = face:FindFirstChild("Words", true) :: TextLabel
		expect((words:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint).MaxTextSize).toBe(14)
	end)
end)
