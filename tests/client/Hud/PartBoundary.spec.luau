--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local PartBoundary = require(Client.Hud.PartBoundary)
local React = require(ReplicatedStorage.Packages.React)

-- What a part throws while it renders; nothing while it works.
type PartProps = { throws: any? }

-- A part: a frame, or an error while it renders.
local function Part(props: PartProps): React.ReactElement
	if props.throws ~= nil then
		error(props.throws, 0)
	end
	return React.createElement("Frame")
end

-- The lines the boundaries reported.
local lines: { string }

local function report(line: string)
	table.insert(lines, line)
end

-- Two parts side by side, each behind its own boundary, in match `match`: Left as `left` says, Right always working.
local function parts(left: PartProps, match: number): React.ReactElement
	return React.createElement(React.Fragment, nil, {
		Left = React.createElement(PartBoundary, {
			name = "Left",
			part = React.createElement(Part, left),
			match = match,
			report = report,
		}),
		Right = React.createElement(PartBoundary, {
			name = "Right",
			part = React.createElement(Part, {}),
			match = match,
			report = report,
		}),
	})
end

local folder: Folder

beforeEach(function()
	lines = {}
	folder = Instance.new("Folder")
	folder.Name = "PartBoundaryTest"
	folder.Parent = workspace
end)

afterEach(function()
	Fixtures.unmountAll()
	folder:Destroy()
end)

-- #379 (the owner's Q242): one part's broken render took the whole HUD down until the next Play (session 78).
describe("PartBoundary", function()
	it("shows its part, named as the boundary is", function()
		local mounted = Fixtures.mount(parts({}, 1), folder)
		expect((mounted:FindFirstChild("Left") :: Instance).ClassName).toBe("Frame")
		expect((mounted:FindFirstChild("Right") :: Instance).ClassName).toBe("Frame")
		expect(lines).toEqual({})
	end)

	it("shows nothing in place of a part that throws while rendering, the others kept, and reports where", function()
		local mounted: Folder
		local reports = Fixtures.reactReports(function()
			mounted = Fixtures.mount(parts({ throws = "the part is broken" }, 1), folder)
		end)
		expect(mounted:FindFirstChild("Left")).toBeNil()
		expect(mounted:FindFirstChild("Right") ~= nil).toBe(true)
		-- React's own warning has the error alone; the boundary's line names the part and where it was thrown.
		expect(reports).toEqual({ "Error: the part is broken" })
		expect(#lines).toBe(1)
		local pattern = "^%[BloxChampions%] Hud: Left hidden until the next match: the part is broken %((.*)%)$"
		local at = string.match(lines[1], pattern) :: string
		-- One line of the stack: the throw's own.
		expect(string.find(at, "\n", 1, true)).toBeNil()
		expect(
			string.find(at, "PartBoundary.spec", 1, true) ~= nil and string.find(at, "function Part", 1, true) ~= nil
		).toBe(true)
	end)

	it("reports a thrown value that is no error message as it reads", function()
		local thrown = { code = 7 }
		Fixtures.reactReports(function()
			Fixtures.mount(parts({ throws = 42 }, 1), folder)
			Fixtures.mount(parts({ throws = thrown }, 1), folder)
		end)
		expect(lines).toEqual({
			"[BloxChampions] Hud: Left hidden until the next match: 42 (?)",
			`[BloxChampions] Hud: Left hidden until the next match: {thrown} (?)`,
		})
	end)

	it("keeps a broken part hidden for the rest of its match, untried, and tries it again in the next", function()
		local mounted: Folder
		local render: (element: any) -> ()
		local reports = Fixtures.reactReports(function()
			mounted, render = Fixtures.mount(parts({ throws = "the part is broken" }, 1), folder)
			-- Rendered again in the same match, even mended: still hidden and not tried, so not reported again.
			render(parts({}, 1))
		end)
		expect(mounted:FindFirstChild("Left")).toBeNil()
		expect(#reports).toBe(1)
		expect(#lines).toBe(1)

		render(parts({}, 2))
		expect(mounted:FindFirstChild("Left") ~= nil).toBe(true)

		-- Broken in that match too: hidden again, reported once more, however often it is rendered.
		local again = Fixtures.reactReports(function()
			render(parts({ throws = "the part is broken" }, 2))
			render(parts({ throws = "the part is broken" }, 2))
		end)
		expect(mounted:FindFirstChild("Left")).toBeNil()
		expect(#again).toBe(1)
		expect(#lines).toBe(2)
		expect(mounted:FindFirstChild("Right") ~= nil).toBe(true)
	end)
end)
