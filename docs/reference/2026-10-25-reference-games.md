# Reference games: Roller Champions and Illegal Soccer

- **Recorded:** 2026-10-25, from about 1,100 frames sampled every 2 s, plus the videos' captions.
- **Updated:** whenever an overhaul part's brainstorm gets a new answer from the owner, so it stays the one record
  every overhaul spec links to.

Observations of the two games the M1 overhaul follows (spec decision A6), and the owner's design answers. Read it
before designing any overhaul part. Match their feel, rules and layout ideas; never copy their art, logos, names or
music.

## The videos

- **Illegal Soccer (Roblox)**: the owner's screen recordings of 2026-10-25 (10:40, 1918x1010, 30 fps) and
  2026-10-21 (not in the repository).
- **Roller Champions gameplay (2019 E3 pre-alpha, with the tutorial)**, TmarTn2:
  https://www.youtube.com/watch?v=GItLiPXpoZw (11:03).
- **Let's Play Roller Champions in 2025 (the released game: Venice Beach and a night city arena, the practice
  park)**, SomeMold: https://www.youtube.com/watch?v=DvufnT_DigM (14:29).
- Older Roller Champions links (spec §15): t2JZw0nMcic, oTxqS3wVqGw, 4Ofq9CFUWnQ.
- The owner's list of issues with today's game (2026-10-25): summarised in spec decision A6.

**How to look again:** yt-dlp 2026.10.21 (`gh release download 2026.10.21 -R yt-dlp/yt-dlp -p yt-dlp.exe`) and
FFmpeg n9.0 (BtbN/FFmpeg-Builds `ffmpeg-n9.0-latest-win64-gpl-9.0.zip`), checksums verified, in a scratch `tools`
folder (outside the repository); contact sheets: `ffmpeg -i <video> -vf "fps=1/2,scale=480:-2,drawtext=...%{pts\:hms}...,tile=4x3"`.
Captions: `yt-dlp --write-auto-subs --sub-langs en --convert-subs srt`.

## The owner's answers (from 2026-10-25)

- Order: close Phase 9 (review + merges), then Arena -> Feel -> Ball & rules -> Presentation (HUD declutter and phone
  buttons, goal replay and celebration, intro and kickoff cutscenes). Later milestone: sound, music, visual art,
  authored animations, stadium and crowd, more maps, the tutorial. Fans: M6. Practice park: M3.
- Arena shape: RC style, open top (no roof). Outer wall a tall opaque curved half-pipe with a glass barrier on top;
  the inner wall curved glass (see across the infield). The glass tall enough that no measured launch clears it.
- Arena size: track 44 -> 60 wide, curved ends 60 -> 70, straights 160 -> 200 (lap about 840 studs).
- Gate markers: both - a glass arch across the track at each gate (no collision), glowing in the possessing team's
  colour on the next gate to cross; and a light beam on the outer glass travelling beside the ball carrier.
  They replace today's flat corner panels.
- The goal ring hangs over the track on an arm from outside, above the outer half of the track at gate 2, facing
  oncoming skaters.
- The straights keep the step (pump spot), scaled to the wider track.
- The glass is a barrier, not a ride surface. And (for the Feel part): **no more wall riding held by speed: real
  physics everywhere** - a skater can slide on a wall but cannot hold it at speed; gravity pulls them off.
- The inner side: a low curved bank (about 8 studs, a pump spot) topped by a tall glass barrier; the infield
  behind it is lower and not rideable, seen through the glass.
- Section 1 of the Arena design approved (2026-10-25): 60 wide, ends 70, straights 200, no roof, inner bank ~8 +
  glass, outer wall 28 + glass to ~80 (measured before it is fixed), glass a barrier the camera sees through,
  gates tall enough for any throw, 'outside' = past either glass or under the floor. **The floor, the banks and
  the walls are opaque, like RC: only the barriers on top are glass** (owner).
- Where these notes live: this file (memory) and, once the Arena spec is committed, a copy in the repo at
  `docs/reference/2026-10-25-reference-games.md` that every overhaul spec links to.
- Arena design sections 2 (glass gate arches glowing for the next gate, the beam following the carrier on the
  outer glass, the goal ring hanging from an arm over the outer side at gate 2) and 3 (other changes, tests)
  approved 2026-10-25. Next: close Phase 9's review fixes, then write the Arena spec.
- Keeping the ball in (2026-10-26, AskUserQuestion, recommended): glass ~85 studs now, with a Config check that no
  skater clears it (measured: a skater peaks ~77 at hardCap 140; a ball-sized part launched up rose 47.9 studs at
  140 studs/s and 127.9 at 230, ~5% under v^2/2g; today's worst throw, straight up near the outer wall top, ~155-160).
  The Ball & rules part adds the same check for the ball (e.g. RC-like throw speeds); until then a ball over the glass
  is out and respawns, as today.
- Ball & rules note (owner): follow RC's ball - ours (radius 1.5, 3 studs across) is too big next to Roblox
  characters; measure RC's ball against a skater's height in the video frames before proposing a size.
- Earlier in the same talk (Feel / Ball & rules): no camera over-tilt; jumps cost speed (no jump spam); a hard
  landing on flat ground knocks the skater down until they get up; a double jump (the second is RC's "Air Pose");
  no tackle -> dive -> tackle spam; a pass to a teammate behind a wall hits the wall; a pass to one in front or
  behind flies in a line through the air, not along the ground; +1/+3/+5 points; shooting with a trajectory.


## Roller Champions

### Video 1: TmarTn2, "Roller Champions Gameplay" (E3 2019 pre-alpha, 11:03), sampled every 2 s

#### Front end
- 0:00 title screen (key art, "PRESS START TO PLAY"); 0:24 "CONNECTING..."; info cards on a red patterned background.
- 0:34-1:36 cinematic intro trailer (skippable).
- 1:38-1:46 arena fly-over: Acapulco, an oval track in a stadium on a beach, stands all around, a city behind, sea, palms. The track is OPEN-TOPPED (no roof); tall CLEAR GLASS/plexi panels on white steel frames ring the outer edge.

#### Tutorial (1:48-3:36): skippable, narrated, a controller diagram bottom left lights up the button being taught
- RT held = skate; left stick steer; camera on the right stick; "touch the ball to grab it".
- "Get to the starting line in any direction"; then "make a lap counter-clockwise"; a big red circled number (gate number 1-4) floats over the track at each gate (1:48 "4", 1:50 "2", 3:38 "5"?).
- "Once one lap is complete the goal lights up"; "points depend on the number of laps your team completes before scoring": 1 lap 1 pt, 2 laps 3 pts, 3 laps 5 pts (2:26-2:34 big white "1 POINT", "3 POINTS", "5 POINTS" over the goal); "passing the ball to an opponent resets your team's progression".
- "Release [the trigger] to shoot". "Match lasts... first team to 5 points wins instantly". Text: "MATCH TIME: 7MIN + OVERTIME: 3MIN".
- "When on top of a slope bend your knees" (pump), "surf the walls", "release the left trigger as soon as you start going on" (?), A jump, B brake hard, X with the ball + stick = juke (dodge), X without = tackle; "steal the ball"; "draft to gain speed by pursuing them from behind"; Y = a hand over a teammate means calling for the ball.

#### Track geometry (pre-alpha Acapulco)
- Very WIDE track: flat floor lanes ~3-4 skater-heights... the floor is wide, with painted lanes (yellow, pink/magenta, teal) with checkered borders, chevrons, big lap numbers painted on the floor.
- The floor curves smoothly into a TALL half-pipe outer wall (a quarter-pipe that goes past vertical into an overhanging lip) topped by a glass panel; the inner side has a lower curb/bank into the infield.
- The infield is a separate lower area (bowl with a ramp).
- The goal: a big upright RING hanging above the track on a mechanical arm (2:14: an orange glowing disc in a white robotic housing, "eye"); lit up (glowing orange/team colour) when open.

#### HUD (pre-alpha)
- Top centre: a small dark pill: blue circle icon | match clock "00:24" | orange circle icon; the team scores (laps?) as small icons. Very small, unobtrusive.
- Bottom right: speed in big white digits with "KM/H" small under it (e.g. "52 KM/H").
- Bottom centre small text "LAP 1".
- Ball carrier: none of our clutter; ball shown as a glowing ball in the carrier's hand.
- Teammate/opponent name tags: small coloured name plates (blue/orange) over players (players' names).
- Pass reticle: a circle reticle around the targeted teammate (4:20-5:30: blue/orange ring reticle on the target).
- Goal: "GOAL!" big white italic text with a slash, bottom banner "<NAME> SCORED 1 PT!", then a ROLLER CHAMPIONS logo wipe transition (4:12) and a replay? (4:14-4:24 an overhead camera of the skaters).
- Call-for-pass: a hand icon (Y) bottom centre.

#### Feel
- Camera: low, close behind the skater, slightly above the shoulders, wide FOV; tilts/rolls with the surface when wall riding (the horizon rolls on the walls, 3:46, 3:54, 5:16); speed lines and coloured skate trails (the team colour: blue/orange streaks behind the skates).
- Skater animations: deep crouch while pumping, arms swinging, leaning into turns, ball held in one hand.

#### Video 1, 5:36-10:22 (match play)
- Goal: a big glowing ring on a white mechanical stand/arm hanging over the track; lit with a team-coloured beam when open (4:00, 6:24, 8:44, 10:22: a blinding blue/white burst on scoring).
- Goal flow: "GOAL!" italic + "<NAME> SCORED 1 PT!"/"5 PTS!" banner at the bottom; ~2 s later a ROLLER CHAMPIONS logo wipe, then a top-down overview camera of everyone skating back (reset), then normal play. Score in the top pill updates.
- 6:30 end: "6 VS 0 / BLUE WINS!" card left, the winning team's three skaters posed on a blue backdrop, names + fans; 6:44-6:56 a fans grandstand tally ("246 FANS", "+100 GAME WON, +20 PERFECT MATCH, +20 OVERKILL VICTORY, +20 SCORED A 1PT GOAL, +60 5PTS GOAL").
- 7:00-7:06 a pre-match overview of the arena with the players' name tags; the red circled gate number "5" ... "3" ... "1" floating = the countdown? (7:06 "5", 7:08 "3", 7:10 "1") — it is the kickoff countdown drawn as a circled number floating in the world at the ball spawn/goal.
- Skate trail: two glowing team-coloured ribbons from the skates (orange or blue), fading.
- Knockdowns: the skater flips and lies flat sliding (5:58, 7:16, 8:26 a superman-dive on the floor).
- Speed shown 1-80 km/h; slow corners ~40, fast ~70.

### Video 2: SomeMold, "Let's Play Roller Champions in 2025" (the released game, Venice Beach arena, 14:29)

#### Front end
- 0:06 main menu: the player's skater posed in front of a big "Disco Fever" season art; left a card stack ("Choose reward", "Gameplay statistics: highest altitude 35 M", "Daily bonus: match 1/2/3", "Champions" leaderboard), invite slots either side, currency top right, news ticker bottom.
- 3:36 loading: a stylised flat map of the arena (oval, "VENICE BEACH PARK", gate numbers 1-4 with arrows) + tips ("the Follow Camera option makes the camera turn to follow your skater"), "LOADING ARENA..." / "PREPARING SKATERS...".
- 3:46-4:04 intro cutscene: a coaster/rail camera over the arena, the neon "VENICE BEACH PARK" sign, then the skaters skate out of a tunnel one by one with a name plate (avatar icon, name, title "ALPHA HALL OF FAME", "Standard AI").
- 4:06 kickoff: the camera behind the skater in the tunnel mouth looking at the arena.

#### Arena (Venice Beach)
- Much larger and more varied: a long oval with banked ends AND an infield island track; the floor has multiple lanes and levels (yellow raised island with a ramp, blue lanes, red-brown wood-look track), chevrons, checkered lines, big painted gate numbers "<1", "<2" with arrows.
- The OUTER wall is a tall curved half-pipe that rolls over into a CLEAR GLASS barrier (you see the crowd through it). The stands are FULL of animated crowd (teal and orange fans) right behind the glass; a fairground (roller coaster, Ferris wheel, neon arches) beyond.
- No roof over the track: open sky.
- The goal: a big ring in a white housing on a long red/white robotic arm hanging over the track from the outside; it glows team colour when open.
- Gate markers: a big circled number hologram (orange outline, e.g. "5"... no: "4", "3") floating over the track ahead at the next gate; light pillars/beams (vertical team-coloured light shafts) on the walls at the gates (4:32, 5:14 orange vertical beams).

#### HUD (released game) — very sparse
- Top centre: a small pill: orange square with the orange score, "07:00" clock, blue square with the blue score; a thin lap progress bar under it (segments).
- Bottom right: a compact control-hint list (L2 Ball Focus, R2 Pump, R1 Brake, X Jump, ... Tackle, Uppercut), each line a pad icon + a word; very small, semi-transparent.
- Bottom right corner: speed in team-colour digits with "KM/H".
- Centre: a small circle reticle.
- Name tags: small coloured pills over players.
- Event toasts: "GO ORANGE TEAM!", "DENIED!" in white italic caps in the upper centre; bottom-left a scorer plate (avatar, name, title, stars) with "+1 PT".
- "GOAL" small text with sparks, then the replay/reset.

#### Video 2, the rest
- Kickoff: the countdown is a big circled number shown IN THE GOAL RING (5..1) while the clock holds at 07:00; skaters already skate during it (82 km/h at 4:12) - movement is NOT frozen in the released game (video 1 shows the same: 3:38-3:42, 7:06-7:10).
- After a goal (4:58 "GOAL" + sparks; bottom-left scorer plate "+1 PT", "+5 PTS"): a ROLLER CHAMPIONS logo wipe (6:04), then the REPLAY: cinematic cameras following the ball into the ring with a fiery explosion (6:06-6:14), then a loading/next card; in match 2 (11:00+) the reset shows the countdown on the ring again.
- Gate markers ("corner markers"): (a) a curved CLEAR GLASS panel across the track at the gate, with a curtain of thin vertical team-coloured light lines on it (4:30-4:34, 11:36-11:40); (b) bright vertical light beams on the outer wall that move along with the carrier (5:14, 5:22 orange shafts beside the skater).
- "DENIED!" toast when a goal attempt is blocked; "GO ORANGE TEAM!" toast at kickoff/possession.
- End: "ORANGE TEAM WINS" toast in the arena (12:26), then a podium scene: both teams posed in front of giant "5" (orange) and "0" (blue) numerals, emoting (12:32-12:42), names on plates, "STAY AS GROUP" / "CONTINUE"; then the menu.
- Match 2 arena (10:48+): a night neon city arena (NYC, Ferris wheel, Statue of Liberty, balloons): a different map, picked per match; the team tunnel intro with name plates again (10:48-10:52).
- Practice map / playground (6:16-9:30, "Shulter" skatepark by the beach): free roam, no match HUD, bowls, half-pipes, ramps, rails, banks, a giant mirror ball; pink/yellow/teal; timed activities "STAR DASH SUPERNOVA - Throw bombs, avoid blasts and grab stars to win!" with a countdown, Winner 200 fans / Participant 175 fans rewards, a score counter top-left.
- Control hints bottom right change with context (with the ball: Charge Throw, Pump, Brake, Jump, Dodge; without: Ball Focus, Pump, Brake, Jump, Tackle, Uppercut; in the air: Air Pose).
- Speed readout bottom right goes to 105-137 KM/H on fast laps.

## Illegal Soccer (the owner's recording of 2026-10-25), sampled every 2 s

### Lobby (0:00-0:04)
- Wooden hall; two glowing floor pads "Join Red" (pink) / "Join Blue" (blue) with small floating name labels.
- Bottom centre: big green "PLAY" button, a hint line above it ("Get <coin> 200 after completing a match!"), under it Shop / Inventory / Friends pills.
- Top right: "Level 68" with an XP bar and a currency counter. Right edge: key hints. Top centre: the live match's score + timer.
- 0:06: black fade into the match.

### Match HUD (constant)
- Top centre: tiny white score card: red square, "2 - 3", blue square; under it a small timer pill (e.g. 3:46). In overtime an "OVERTIME" tag above it and the clock counts up (+0:00).
- Right edge, vertically centred-low: a column of small key hints (Kick Q?, Pass, Flick, Tackle, Lob, Request, Dribble SPACE, Sprint SHIFT): small dark labels with key caps, low contrast, never in the way.
- Bottom left: "Stats TAB", "Return to Lobby L" small.
- Bottom centre: a small 2-slot item bar (slots "1" "2", dotted outline) above a 4-segment green bar (stamina/sprint) that empties and refills.
- Top right: score toasts that stack: "Tackle +15", "Steal +15", "Pass +15", "Direct Hit +10", "Receive +10", "Long Goal! +125".
- Player ring: a team-coloured ring on the ground under every player (pink for red team, blue for blue).
- Ball carrier/target markers: a small team-coloured down-triangle above players/ball.
- Kick charge: a small segmented yellow meter right under the player while charging.
- Ground reticle (5:04): a white circle with 4 arrows on the ground, aim marker.

### Goal sequence (0:10-0:32, 1:08-1:32, 2:34-2:56, 3:20-3:42, 5:22-5:44)
1. GOAL: a team-coloured banner at top centre: small "GOAL!" tag over the scorer's name, assister's name under it; an explosion effect (dark smoke + orange fire) at the goal.
2. ~2 s later: REPLAY with a camcorder look: letterbox bars, "• REC" top-left, white viewfinder corners; a cinematic camera re-plays the goal from another angle (ball trail visible, white kick trajectory arc drawn from the foot at 2:40). ~6-8 s.
3. Celebration: the scorer's FIFA-style player card on the left (avatar, name, three stats), the scorer stands posed; a grid of 8 celebration/emote slots under the scorer (1:20). Score updated.
4. Black fade, everyone reset; kickoff countdown big "3", "2", "1" numbers over the centre circle; the ball drops at centre with a burst.
- Card backgrounds differ per player (purple swirl, orange flame, plain white).

### Stats (TAB, 3:14, 5:34)
- "Match Stats" panel, cream/white, dark header bar; per team a header (team colour square, "Red Team — 5"); rows: avatar, display name over @handle, Points, Goals, Shots, Assists, Saves; local player row highlighted green. Simple, flat, readable.

### Arena / world
- Football pitch on stylised grass with painted white lines (centre circle, boxes); goals at both ends with hexagon-pattern nets (pink/red and blue).
- Surrounded by glass walls on dark-red frames with cyan diamond/zig-zag light strips on the posts; glass shows a dotted hologram pattern (cyan or pink) when a player is close (0:48, 4:42).
- Outside: sea, viking ships with pink sails, mountains, a village; a painted, colourful backdrop. Sun glare.
- Light: bright daylight, soft shadows, sun rays.

### Items (M5 reference)
- "?" item boxes float on the pitch; picked items show in the 2 slots; seen: cardboard-box disguise, wooden wall with stars, ink/oil trail (black), green slime trail, ice burst, purple lightning, bubble shield (pink sphere), a gun aimed over the shoulder ("Focus" hint), speed aura.

### Feel
- Camera: third-person, close behind and slightly above, steady (no roll); speed lines when sprinting; slight FOV push.
- Knockdowns: tackled players lie flat on the ground for a moment (3:02, 4:10, 5:08).

### Full-size frames (0:40, 1:20, 9:24)
- Score card: off-white card with thin corner brackets, team colour squares at the sides, big bold black digits "3 - 3", a tiny "YOU" tag under the local team's score; under it a dark pill "(stopwatch) 3:32". Font: bold condensed sans.
- Key hints (bottom right): white label + black key cap ("Kick [mouse]", "Pass", "Flick Q", "Tackle E", "Lob F", "Request R", "Dribble SPACE", "Sprint SHIFT"); usable ones bright white, others dimmed. Bottom left the same style: "Stats TAB", "Return to Lobby L".
- Centre of screen: a faint "( )" bracket reticle.
- Pass/shot: a white dashed trail arc behind the ball.
- Toast top right: white pill "Pass" + green "+15".
- Player list top left: small avatars + names, faint.
- Goal card (1:20): tall card with a swirl pattern, avatar render, white name plate (the player's name) with career "66 Goals | 62 Assists | 56 Saves". Emote grid under the scorer: "Emotes" label, 8 dashed slots numbered 1-8 with mannequin icons (Glad / None).
- End of match (9:16-9:44): the winning golden-goal scorer's card; then the winning team lined up on the centre line doing emotes; ribbon award banners above each player: "MVP — Highest score (1330)", "Showstopper — Scored the Golden Goal", "Sniper — Scored from 133 studs out", "Free Samples — Had 6 passes intercepted", "Collateral Damage — Tackled teammates 4 times", "Sacrificial Lamb — Hit by their own team 4 times", "Guardian Angel — Most saves (2)", "Target Practice — Hit or tackled 12 times", plus Playmaker (most assists), Quarterback, Middleman, Safe Hands; confetti; "Match Complete"; top right "Level 60 930/1750" XP bar and coins "250".
- Golden goal: bottom toast "Victory! Red Team won!".
- Then black fade to the lobby: "Intermission" header + timer; Daily Reward modal (Day 8..14, coins/items, Claim); Shop (Daily Shop / Item Rolls / Collections / Passes; coins 450): items with rarities (Mythic 1%, Epic 7%, Uncommon), "10 Rolls" bundle, card-roll spinner animation (a horizontal strip of cards scrolling to a pick), "Passes": "Exclusive VIP Kit", "Upgraded Emotes", "Lead Your Club", "Own the pitch. VIP 279".
