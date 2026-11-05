--!strict
-- Where a marker on the screen for a point in the world sits (spec §11.1), from the point as the camera projects it
-- (Camera:WorldToViewportPoint: x and y in pixels, z the depth, negative behind the camera). A point on the screen is
-- marked where it is, by a marker pointing down at it. One off it is pinned to its path, a rectangle inside the screen
-- (on a phone inside its safe area), on the line from the viewport's centre toward it, and points along that line; a
-- point behind the camera projects mirrored, so that line is turned around. Where the HUD's parts would cover the
-- marker (#376, the owner's Q242), a pinned one slides along the path to the nearest point clear of them, still
-- pointing the same way; one on the screen stays on its point, covered (the caller hides it, the owner's Q267). Routing
-- a path, when the screen or the HUD's layout changes, gathers the stretches of the path those parts block and the
-- parts' kept-clear boxes once; placing a marker, each frame, searches only those and writes into a record the caller
-- keeps, so it allocates nothing. It never touches an Instance.

-- x and y in pixels from the screen's top left; angle in radians, 0 pointing up, growing clockwise; covered while an
-- on-screen marker's point lies where the HUD's parts would cover it.
export type Placement = { x: number, y: number, angle: number, pinned: boolean, covered: boolean }

-- What a pinned marker rides: the viewport's centre, the rectangle round it walked clockwise from its top-left corner
-- (`length` long), and the stretches of that walk it may not stop on, as distances along it: `blocks` holds each
-- stretch's start and end in turn, sorted and merged, `count` of them; one across the walk's start ends past `length`.
-- `covers` holds each keep-out box grown by what the marker keeps clear, as its left, top, right and bottom in turn.
export type Path = {
	centreX: number,
	centreY: number,
	left: number,
	top: number,
	right: number,
	bottom: number,
	length: number,
	blocks: { number },
	count: number,
	covers: { number },
}

local ScreenMarker = {}

-- Straight down, at a point on the screen.
local DOWN = math.pi
-- How near an edge a point on the path counts as on it: the line's meeting point carries rounding.
local ON_EDGE = 1e-6

function ScreenMarker.newPlacement(): Placement
	return { x = 0, y = 0, angle = 0, pinned = false, covered = false }
end

function ScreenMarker.newPath(): Path
	return {
		centreX = 0,
		centreY = 0,
		left = 0,
		top = 0,
		right = 0,
		bottom = 0,
		length = 0,
		blocks = {},
		count = 0,
		covers = {},
	}
end

-- Whether (x, y) lies inside one of `path`'s grown boxes.
local function covered(path: Path, x: number, y: number): boolean
	local covers = path.covers
	for index = 1, #covers, 4 do
		if covers[index] < x and x < covers[index + 2] and covers[index + 1] < y and y < covers[index + 3] then
			return true
		end
	end
	return false
end

-- How far along `path`'s walk a point on it lies.
local function along(path: Path, x: number, y: number): number
	local width, height = path.right - path.left, path.bottom - path.top
	if y <= path.top + ON_EDGE then
		return x - path.left
	elseif x >= path.right - ON_EDGE then
		return width + y - path.top
	elseif y >= path.bottom - ON_EDGE then
		return width + height + path.right - x
	end
	return 2 * width + height + path.bottom - y
end

-- The point `distance` along `path`'s walk, round it as often as it takes.
local function at(path: Path, distance: number): (number, number)
	local width, height = path.right - path.left, path.bottom - path.top
	local t = distance % path.length
	if t < width then
		return path.left + t, path.top
	elseif t < width + height then
		return path.right, path.top + t - width
	elseif t < 2 * width + height then
		return path.right - (t - width - height), path.bottom
	end
	return path.left, path.bottom - (t - 2 * width - height)
end

-- Adds the stretch from `first` to `last` to `spans`, where it is one.
local function add(spans: { { number } }, first: number, last: number)
	if first < last then
		table.insert(spans, { first, last })
	end
end

-- Sets `into` to the rectangle `inset` pixels inside `bounds` (pixels of the screen `viewport` measures), the
-- stretches of its walk where a marker's centre would come within `keep` pixels of one of `boxes` (keep-out boxes, in
-- the same pixels), and those boxes grown by `keep`: each blocks the part of every edge that runs through it.
function ScreenMarker.route(viewport: Vector2, bounds: Rect, inset: number, boxes: { Rect }, keep: number, into: Path)
	local left, top = bounds.Min.X + inset, bounds.Min.Y + inset
	local right, bottom = bounds.Max.X - inset, bounds.Max.Y - inset
	local width, height = right - left, bottom - top
	into.centreX, into.centreY = viewport.X / 2, viewport.Y / 2
	into.left, into.top, into.right, into.bottom = left, top, right, bottom
	into.length = 2 * (width + height)
	local covers = into.covers
	table.clear(covers)
	local spans: { { number } } = {}
	for _, box in boxes do
		local x0, y0, x1, y1 = box.Min.X - keep, box.Min.Y - keep, box.Max.X + keep, box.Max.Y + keep
		table.insert(covers, x0)
		table.insert(covers, y0)
		table.insert(covers, x1)
		table.insert(covers, y1)
		local across0, across1 = math.max(x0, left), math.min(x1, right)
		local down0, down1 = math.max(y0, top), math.min(y1, bottom)
		if y0 < top and top < y1 then
			add(spans, across0 - left, across1 - left)
		end
		if x0 < right and right < x1 then
			add(spans, width + down0 - top, width + down1 - top)
		end
		if y0 < bottom and bottom < y1 then
			add(spans, width + height + right - across1, width + height + right - across0)
		end
		if x0 < left and left < x1 then
			add(spans, 2 * width + height + bottom - down1, 2 * width + height + bottom - down0)
		end
	end
	table.sort(spans, function(a: { number }, b: { number }): boolean
		return a[1] < b[1]
	end)
	local blocks = into.blocks
	table.clear(blocks)
	local count = 0
	for _, span in spans do
		if count > 0 and span[1] <= blocks[2 * count] then
			blocks[2 * count] = math.max(blocks[2 * count], span[2])
		else
			count += 1
			blocks[2 * count - 1], blocks[2 * count] = span[1], span[2]
		end
	end
	-- A stretch reaching the walk's end goes on into one from its start: they are one, ending past the end.
	if count > 1 and blocks[1] <= 0 and blocks[2 * count] >= into.length then
		blocks[2 * count] = into.length + blocks[2]
		table.remove(blocks, 1)
		table.remove(blocks, 1)
		count -= 1
	end
	into.count = count
end

-- Writes where the marker for `point` sits into `into`: where it is while `onScreen`, covered inside one of `path`'s
-- grown boxes; else pinned to `path` and slid out of a stretch it may not stop on to that stretch's nearer end, unless
-- the stretch is the whole path.
function ScreenMarker.place(point: Vector3, onScreen: boolean, path: Path, into: Placement)
	if onScreen then
		into.x, into.y, into.angle, into.pinned = point.X, point.Y, DOWN, false
		into.covered = covered(path, point.X, point.Y)
		return
	end
	into.covered = false
	local centreX, centreY = path.centreX, path.centreY
	local dx, dy = point.X - centreX, point.Y - centreY
	if point.Z < 0 then
		dx, dy = -dx, -dy
	end
	if dx == 0 and dy == 0 then
		-- Straight behind: point down, to the bottom edge.
		dy = 1
	end
	-- How far along the line it meets the path: the nearer of its side and its top or bottom.
	local reach = math.huge
	if dx > 0 then
		reach = (path.right - centreX) / dx
	elseif dx < 0 then
		reach = (path.left - centreX) / dx
	end
	if dy > 0 then
		reach = math.min(reach, (path.bottom - centreY) / dy)
	elseif dy < 0 then
		reach = math.min(reach, (path.top - centreY) / dy)
	end
	local x, y = centreX + dx * reach, centreY + dy * reach
	local blocks, length = path.blocks, path.length
	local distance = along(path, x, y)
	for index = 1, path.count do
		local first, last = blocks[2 * index - 1], blocks[2 * index]
		local t = if distance <= first then distance + length else distance
		if first < t and t < last then
			if last - first < length then
				x, y = at(path, if t - first <= last - t then first else last)
			end
			break
		end
	end
	into.x, into.y = x, y
	into.angle = math.atan2(dx, -dy)
	into.pinned = true
end

return table.freeze(ScreenMarker)
