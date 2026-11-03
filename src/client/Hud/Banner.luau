--!strict
-- A banner in look C (spec §11.1; #356, the owner's Q191, Q210): GO <team> TEAM!, GOAL!, DENIED!, the clock
-- warnings, LAST CHANCE, OVERTIME and a completed lap on the banner line, its text's centre `line` pixels down the
-- stage (HudScreen.bannerLine); or, with no line, the goal message at the stage's bottom (HudScreen.messageBottom). At
-- its kind's size (HudScreen.bannerSize), in its team's colour, lettered by Style.banner. It pops in round its text's
-- centre (`scale`, an Animator track) and, while it leaves (`leave`, 0 to 1), fades whole and floats up
-- layout.banner.rise of its size, in whole pixels from positions made once a render, so no frame allocates. Hidden
-- without a banner, and for the kickoff's count, which Hud/Countdown draws a third of the way down (#353). It shrinks
-- to fit the HUD's stage (left of the touch buttons on touch). A plain function of its props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)

export type BannerProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	banner: HudState.Banner?,
	-- A phone's screen (HudScreen.compact).
	compact: boolean,
	-- The banner line's place, pixels down the stage; nil for the goal message.
	line: number?,
	scale: React.Binding<number>,
	leave: React.Binding<number>,
	-- The HUD's stage, which the banner fits in.
	area: React.Binding<Vector2>,
}

local function Banner(props: BannerProps): React.ReactElement
	local config, banner, compact = props.config, props.banner, props.compact
	local shown = banner ~= nil and banner.kind ~= "Countdown"
	local look = config.UI.hud.look
	local size = HudScreen.bannerSize(config, compact, if banner ~= nil then banner.kind else "Go")
	local ink = HudScreen.bannerInk(config, compact)
	local words = if banner ~= nil and shown then props.text:banner(banner) else ""
	local color = if banner ~= nil and banner.team ~= nil then Style.teamColor(config, banner.team) else nil
	local width = Style.textWidth(config, words, size, look.bannerFont) + 2 * ink
	local height = size + 2 * ink + look.shadow
	local box = UDim2.fromOffset(width, height)
	-- The text's centre and its bottom, shares of the holder's height: the line holds the centre, the stage's bottom
	-- the message's bottom; the pop grows round the centre.
	local centre = (ink + size / 2) / height
	local line = props.line
	local anchor = if line ~= nil then centre else (ink + size) / height
	-- Up to `rise` whole pixels, one position each, made here so a leaving frame allocates nothing.
	local rise = math.round(config.UI.hud.layout.banner.rise * size)
	local lifts: { UDim2 } = table.create(rise + 1)
	for pixels = 0, rise do
		lifts[pixels + 1] = UDim2.new(0.5, 0, centre, -pixels)
	end
	return React.createElement(
		"Frame",
		Style.holder({
			AnchorPoint = Vector2.new(0.5, anchor),
			Position = if line ~= nil
				then UDim2.new(0.5, 0, 0, line)
				else UDim2.new(0.5, 0, 1, -HudScreen.messageBottom(config, compact)),
			Size = box,
			Visible = shown,
		}),
		{
			Fit = Style.fit(config, props.area, box),
			Group = Style.banner(
				config,
				{
					AnchorPoint = Vector2.new(0.5, centre),
					Position = props.leave:map(function(share: number): UDim2
						return lifts[math.round(rise * share) + 1]
					end),
					Size = Style.FULL,
					GroupTransparency = props.leave,
				},
				words,
				size,
				color,
				HudScreen.banners(config, compact).edge,
				ink,
				{
					Pop = React.createElement("UIScale", { Scale = props.scale }),
				}
			),
		}
	)
end

return Banner
