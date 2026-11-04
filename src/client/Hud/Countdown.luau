--!strict
-- The kickoff count (spec §11.1): Roller Champions' count a third of the way down, where the crosshair sits once
-- someone carries the ball (the owner, Q185; RC's Video 31 at 17.0 s), drawn beside the reticle in the gui spanning the
-- whole screen: the digit in look C's banner lettering inside a ring, both in the colour of the banner's team, the
-- viewer's (Q108, Q110), over look C's ink, at a phone's sizes on a phone's screen. Where its ring would touch the
-- scoreboard it sits `drop` pixels lower (HudScreen.countDrop): it aims nothing, so it moves down rather than shrink
-- (Q203). Hidden without a count and while the score tab or the end screen covers the screen. A plain function of its
-- props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

export type CountdownProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	banner: HudState.Banner?,
	-- A phone's screen (HudScreen.compact).
	compact: boolean,
	visible: boolean,
	-- Pixels below the crosshair's place (HudScreen.countDrop).
	drop: number,
}

local function Countdown(props: CountdownProps): React.ReactElement
	local config, banner = props.config, props.banner
	local count = HudScreen.count(config, props.compact)
	-- The banner while it is the kickoff's count; nil otherwise.
	local counting: HudState.Banner? = if banner ~= nil and banner.kind == "Countdown" then banner else nil
	local team: Team.Team? = if counting ~= nil then counting.team else nil
	local color = Style.teamColor(config, team)
	local look = config.UI.hud.look
	local digit: { [string]: React.Node } = {
		Digit = React.createElement(
			"TextLabel",
			Style.lettering(config, {
				Size = Style.FULL,
				-- Lower by as much as the font draws its digits high, so the digit sits at the ring's centre (Q204), in
				-- whole pixels (an offset holds whole pixels).
				Position = UDim2.fromOffset(0, math.round(look.bannerDigitRise * count.textSize)),
				Font = look.bannerFont,
				TextSize = count.textSize,
				Text = if counting ~= nil then props.text:banner(counting) else "",
				TextColor3 = color,
			}),
			{ Ink = Style.inked(config) }
		),
	}
	return Style.inkedRing(config, {
		AnchorPoint = Style.CENTRE,
		Position = UDim2.new(0.5, 0, config.UI.hud.layout.reticle.height, props.drop),
		Visible = props.visible and counting ~= nil,
	}, count.ringSize, count.ringThickness, color, nil, digit)
end

return Countdown
