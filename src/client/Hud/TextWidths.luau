--!strict
-- How wide the HUD's texts are (#354's rows and key caps, #356's banners): each text measured once per font and text
-- size, then kept for the session, so a render reads a width without asking TextService again. Roblox measures a
-- font that has not loaded yet in its fallback font, Source Sans, narrower than look C's (#364: "Space" at 17 px is
-- 36 px wide in it, 43 in Fredoka One; a hint's key cap 52 px instead of 59), so the HUD loads look C's fonts as it
-- starts (`load`) and, once they are in, forgets every width kept (`forget`) and renders again.

local TextService = game:GetService("TextService")

-- How wide `text` is at `size` in `font`, in pixels (TextService's GetTextSize, or a fake).
export type Measure = (text: string, size: number, font: Enum.Font) -> number

local TextWidths = {}
TextWidths.__index = TextWidths

type Fields = {
	-- How many texts were measured (tests: a render after `forget` measures again).
	measures: number,
	-- How many times every width was forgotten: a part drawn outside the Hud's render (the name tags, #358) measures
	-- again when it changes.
	generation: number,
	_measure: Measure,
	_widths: { [Enum.Font]: { [number]: { [string]: number } } },
}

export type TextWidths = typeof(setmetatable({} :: Fields, TextWidths))

function TextWidths.new(measure: Measure): TextWidths
	return setmetatable({ measures = 0, generation = 0, _measure = measure, _widths = {} } :: Fields, TextWidths)
end

-- How wide `text` is at `size` in `font`, in whole pixels rounded up so its letters fit: measured the first time, kept
-- after.
function TextWidths.width(self: TextWidths, text: string, size: number, font: Enum.Font): number
	local bySize = self._widths[font]
	if bySize == nil then
		bySize = {}
		self._widths[font] = bySize
	end
	local byText = bySize[size]
	if byText == nil then
		byText = {}
		bySize[size] = byText
	end
	local width = byText[text]
	if width == nil then
		width = math.ceil(self._measure(text, size, font))
		byText[text] = width
		self.measures += 1
	end
	return width
end

-- Forgets every width kept, so each is measured again when next asked.
function TextWidths.forget(self: TextWidths)
	table.clear(self._widths)
	self.generation += 1
end

-- Waits while `font` loads: TextService's GetTextBoundsAsync yields until it has (a loaded font returns at once,
-- whatever the text) and throws when it cannot load (probed: a missing file or asset, an empty family).
function TextWidths.waitForFont(font: Font)
	local params = Instance.new("GetTextBoundsParams")
	params.Font = font
	TextService:GetTextBoundsAsync(params)
end

-- Waits on each of `fonts` in turn (waitForFont), in a thread of its own, then calls `loaded` once. A font that cannot
-- load counts as loaded: its text draws in the fallback font, the font it is measured in then.
function TextWidths.load(fonts: { Font }, loaded: () -> ())
	task.spawn(function()
		for _, font in fonts do
			pcall(TextWidths.waitForFont, font)
		end
		loaded()
	end)
end

return TextWidths
