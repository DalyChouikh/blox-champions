--!strict
-- The TAB board (spec §6.4, §11.1; #357): the table of every player still in the match (Hud/TeamTable, one compact
-- table on desktop and phones, the owner's Q236, Q237; a leaver's row goes at once, #309). Under it, where the mode
-- offers it, Switch team (#310): its key on look C's cap (none on touch, where it is tapped), greyed whole while a
-- switch can't happen (Q117, Q118). It fits the HUD's area under the scoreboard's ink (HudScreen.tabTop, tabFit; Q203's
-- rule), on touch under the SCORES button too, which stays above it (Q234, Q236): off touch it shrinks to fit; on touch
-- its teams scroll where they do not fit (Q190), and while open it takes the touches over that area, so the touch
-- buttons under it are not pressed (the HUD's gui draws over theirs). It pops in and fades out whole (a Reveal's
-- bindings, Q194), drawn above the HUD's stage. A plain function of its props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local React = require(ReplicatedStorage.Packages.React)
local Style = require(script.Parent.Style)
local TeamTable = require(script.Parent.TeamTable)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

export type SwitchTeam = {
	-- Whether a switch works now; greyed while it doesn't (Q118).
	open: boolean,
	-- Its key on this device (Q117); none on touch, where it is tapped.
	key: Style.KeyView?,
	onActivated: () -> (),
}

export type ScoreTabProps = {
	config: Config.GameConfig,
	text: HudText.HudText,
	stats: Types.MatchStats,
	names: { [Types.PlayerId]: string },
	localId: Types.PlayerId,
	-- A phone's screen (HudScreen.compact): the board's compact sizes.
	compact: boolean,
	-- Played by touch: under the SCORES button, its rows scrolling, taking the touches over its area while open.
	touch: boolean,
	-- Open, not only fading out after it closed.
	open: boolean,
	-- Its pop (1 at rest) and how far it has faded out, 0 to 1 (Reveal).
	scale: React.Binding<number>,
	leave: React.Binding<number>,
	-- The HUD's whole area, in pixels, and how far below its top the scoreboard's ink reaches (HudScreen.boardBottom
	-- less the HUD's top; 0 without a scoreboard).
	area: React.Binding<Vector2>,
	boardBottom: number,
	-- The Switch team button; nil where the board has none.
	switchTeam: SwitchTeam?,
}

-- Switch team at `position` under the box, `height` pixels tall: its key's cap (the hints' sizes, still), then its
-- words, centred, greyed whole while a switch can't happen.
local function switchButton(
	config: Config.GameConfig,
	sizes: Config.TabSizes,
	switchTeam: SwitchTeam,
	position: React.Binding<UDim2>,
	height: number
): React.ReactElement
	local words = config.UI.text.switchTeam
	local parts: Style.Children = {
		Layout = Style.list(config, Enum.FillDirection.Horizontal, { Padding = UDim.new(0, sizes.switchGap) }),
		Label = React.createElement(
			"TextLabel",
			Style.lettering(config, {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(Style.textWidth(config, words, sizes.switchSize), sizes.switchSize),
				Text = words,
				TextSize = sizes.switchSize,
			}),
			{ Ink = Style.inked(config) }
		),
	}
	local view = switchTeam.key
	if view ~= nil then
		local name, key = Style.keyCap(config, view, config.UI.hud.layout.hints.cap, 1, Style.stillCap)
		parts[name] = key
	end
	return React.createElement(
		"TextButton",
		Style.holder({
			Position = position,
			Size = UDim2.new(1, 0, 0, height),
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			[React.Event.Activated] = switchTeam.onActivated,
		}),
		{
			Row = React.createElement(
				"CanvasGroup",
				Style.holder({ Size = Style.FULL, GroupTransparency = Style.dim(config, not switchTeam.open) }),
				parts
			),
		}
	)
end

local function ScoreTab(props: ScoreTabProps): React.ReactElement
	local config = props.config
	local hud = config.UI.hud
	local look = hud.look
	local compact, touch, switchTeam = props.compact, props.touch, props.switchTeam
	local sizes = HudScreen.tabSizes(config, compact)
	local switchRow: HudScreen.SwitchRow? = if switchTeam == nil
		then nil
		elseif switchTeam.key ~= nil then "Key"
		else "Label"
	local switchHeight = HudScreen.tabSwitch(config, compact, switchRow)
	local players = #props.stats.players
	local line, shadow = look.outline, look.shadow
	local area, boardBottom = props.area, props.boardBottom
	-- Where its part of the HUD's area starts, and its scale and how tall its teams show there.
	local function topOf(shown: Vector2): number
		return HudScreen.tabTop(config, touch, shown.Y, boardBottom)
	end
	local function fitted(shown: Vector2): (number, number)
		local top = topOf(shown)
		return HudScreen.tabFit(config, compact, touch, Vector2.new(shown.X, shown.Y - top), players, switchRow)
	end
	local rows = area:map(function(shown: Vector2): number
		local _, teamsShown = fitted(shown)
		return teamsShown
	end)
	return React.createElement(
		"Frame",
		Style.topmost(Style.holder({
			Position = area:map(function(shown: Vector2): UDim2
				return UDim2.fromOffset(0, topOf(shown))
			end),
			Size = area:map(function(shown: Vector2): UDim2
				return UDim2.new(1, 0, 1, -topOf(shown))
			end),
			Active = touch and props.open,
		})),
		{
			Board = React.createElement(
				"Frame",
				Style.holder({
					AnchorPoint = Style.CENTRE,
					Position = Style.MIDDLE,
					Size = rows:map(function(teamsShown: number): UDim2
						return UDim2.fromOffset(
							sizes.width + 2 * line,
							2 * line + shadow + sizes.headHeight + teamsShown + switchHeight
						)
					end),
				}),
				{
					Fit = React.createElement("UIScale", {
						Scale = area:map(function(shown: Vector2): number
							local scale = fitted(shown)
							return scale
						end),
					}),
					Group = React.createElement(
						"CanvasGroup",
						Style.holder({
							AnchorPoint = Style.CENTRE,
							Position = Style.MIDDLE,
							Size = Style.FULL,
							GroupTransparency = props.leave,
						}),
						{
							Pop = React.createElement("UIScale", { Scale = props.scale }),
							Box = React.createElement(TeamTable, {
								config = config,
								text = props.text,
								stats = props.stats,
								names = props.names,
								localId = props.localId,
								compact = compact,
								position = UDim2.fromOffset(line, line),
								shown = rows,
							}),
							SwitchTeam = if switchTeam ~= nil
								then switchButton(
									config,
									sizes,
									switchTeam,
									rows:map(function(teamsShown: number): UDim2
										local under = 2 * line
											+ sizes.headHeight
											+ teamsShown
											+ shadow
											+ sizes.switchGap
										return UDim2.fromOffset(0, under)
									end),
									switchHeight - sizes.switchGap
								)
								else nil,
						}
					),
				}
			),
		}
	)
end

return ScoreTab
