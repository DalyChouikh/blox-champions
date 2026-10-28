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
- **Roller Champions, 45 minutes of pure gameplay (two maps: a closed glass top, then an open top)**, given by the
  owner 2026-10-26: https://www.youtube.com/watch?v=r2xWeAFSEMw ("Video 3" below).
- Older Roller Champions links (spec §15): t2JZw0nMcic, oTxqS3wVqGw, 4Ofq9CFUWnQ.
- **Video 4 and Video 5**: the owner's own Roller Champions games, recorded 2026-10-27 (not in the repository):
  a full match on Pixel City (8:34; the players start in the arena) and a short game on the Mayan Stadium (1:44;
  jumps, and uppercut -> tackle -> dive, shown on purpose).
- The owner's list of issues with today's game (2026-10-25): summarised in spec decision A6.
- **Video 6, the owner's RC solo match on Hidden Cenote** (2026-10-28, 1:41; wall/bank rides, mashed Tackle → Dive,
  Uppercut → Tackle → Dive): `D:\Screenshots\Videos\Screen Recording 2026-10-28 020627.mp4`.
- **Video 7, the owner's second RC solo match on Hidden Cenote** (2026-10-28, 0:47; riding backwards after a
  climb, Air Pose held into a landing → a fall): `D:\Screenshots\Videos\Screen Recording 2026-10-28 021412.mp4`.

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


## The owner's answers, 2026-10-26 (during the Arena plan's Task 2; Task 1 = PR #192)

Said in one message while Task 2's play check ran; it changes the approved Arena spec (R4, R5, A7), so the spec is
revised before any more Arena code. Their words, then what still needs a question:
- "make the walls more longer" (taller? longer straights? - ask) and "make the track, like the infield more wider, on
  both sides the straight side and the round edges" (a wider track, or a wider infield? - ask).
- **The top's closure is per map:** "a map can have closed top and a map don't, but they both should have at the top a
  curved end on both walls" (both walls curve over at their tops, on every map).
- **Glass is rideable:** "the glass walls, the player should be able to skate on them, not just falls" (replaces R5,
  "glass is a barrier, not a ride surface"). How it squares with the earlier "no wall riding held by speed: real
  physics everywhere" (Feel) is open - see the new video's wall riding.
- **Scoring by markers, not laps:** the goal opens after 4 markers (gates) passed, worth +1; 4 more -> +3; 4 more ->
  +5 "and game ends". (Today: lapsToOpenGoal = 4 laps = 16 gates; streak point at 12 laps.) Ball & rules part.
- **Clock:** 7-minute matches, 3 minutes of overtime, and a **draw** if nobody wins after overtime (replaces golden
  goal without limit + Last Chance? - ask when the Ball & rules part starts). Ball & rules part.
- **An invisible ceiling for the ball on an open-top map:** in the new video at 21:13 a ball shot at the open sky hit
  an invisible roof and came back (replaces R10's "a ball over the glass is out").
- **Charge throw:** study how a player charges a throw and cancels it, and how the crosshair shows the charge.
- **New reference video** (45 min, two maps: the first with a closed glass top, the second open): 
  https://www.youtube.com/watch?v=r2xWeAFSEMw - study wall riding, how players get high (jumps, pump, uppercut), the
  arena's shapes, the straights' bump ("not very straight on top ... like an inclined road" a pump spot, the same at
  the ends), the 21:13 bounce, the charge/cancel and its crosshair. Notes: "Video 3" below.

## The owner's answers, 2026-10-26 (after the full study of Video 3; one question at a time)

- **Walls** ("more longer" = taller, recommended): the wall plus the rideable glass reach **120** studs (was 85), about
  0.6 of a curved end's width (the proportion judged by eye in the video), curling inward at the top.
- **Track width** (recommended): the track widens **60 -> 80** on the straights and the ends, into the middle; the
  arena's outside stays 200 across, so the middle (infield) narrows 80 -> 40, like RC's narrow middle (endRadius 70 ->
  60, lap ~777 studs, was 839.8).
- Wall riding vs "real physics" (my reading, told to the owner): the video shows both together - skaters ride the glass
  with speed and slow ones slide back down - so rideable glass fits the Feel rule "gravity pulls them off".
- **The top** (recommended): one setting per map (closed or open), **both kinds built and tested now**; **our map is
  closed** like Mexico (a glass roof with hoops that stops skaters and the ball); the open kind, with the ball's
  invisible ceiling, is ready for the next map. Both kinds have walls curling inward at the top.
- **The top of the wall** (recommended): the lip is rideable and curls a fast skater back toward the track; the roof is
  NOT rideable (they bump off it like a ceiling); gravity brings them down - no riding upside down.
- **The inner side** (recommended): the low bank (8) curves up into rideable glass all the way to the roof, on the
  straights and the ends, with its own lip; the 40-wide middle stays closed off behind it.
- **The open map's invisible ceiling** (recommended): **20 studs above the wall tops (140 with walls at 120)**; it
  stops **the ball and skaters** (both bounce off it), so nothing leaves an open map. (Told plainly first: at 21:13 the
  ball rose above the rails, so any RC ceiling sits above the wall tops; no ceiling was confirmed.)
- **Rules, for the Ball & rules part** (recommended, "RC's rules as seen"): a goal is worth +1 after 4 markers (1 lap),
  +3 after 8, +5 after 12; the first team to 5 or more points wins at once; a 7:00 clock; Last Chance - a team holding
  the ball at 0:00 plays on until its attack ends, whatever the deficit (seen at 1 and 3 behind; only ever seen for the
  trailing team - a leader holding the ball wins at 0:00 anyway, a detail for that spec); overtime 3:00, the next goal
  wins, then a **draw**. Replaces: 5:00, 4 laps to open the goal, +1 goals, the 12-lap streak point, Last Chance only
  1 behind, endless golden-goal overtime.
- **Gate markers** (recommended, replaces the approved thin arch of R6): RC's **hanging panel** - a glass panel fills
  the track's cross-section from the top down to a rounded opening that skaters pass through; nothing collides with it;
  lit in the team's colour on the next gate as before (the carrier's beam on the outer glass stays).
- **The revised Arena spec approved** (2026-10-26, main 979ce49), with its 14 smaller decisions (2.3): among them the
  widths x4/3 (foot curve 18, step 18, upper floor 8), lips r 12, the reach check removed (the top holds everyone), A3's
  loop rule kept for the lips, the top touchable, the goal's arm from the outer glass. Next: a new plan file.
- **The revised plan approved** (2026-10-26, `docs/superpowers/plans/2026-10-26-m1-arena-revised.md`): Tasks 2-7
  stacked on PR #192 (top, rideable glass + sizes, gate panels, hanging goal, beam, playtest), Native, 680 -> 698.

## The owner's answers, 2026-10-27 (the Arena playtest, after the republish)

- **The glass must be see-through**, "specially the middle glass so players can see through the other side". Roblox's
  Glass material hides every non-opaque part behind it (Roblox's DevForum announcement of 2017-12-06: "Non-opaque
  objects are currently not visible through glass"): in Studio the far glass and the gate panels vanished behind it
  at 0.7 and 0.9, and showed with SmoothPlastic at 0.8-0.9. Asked with the two screenshots (recommended): **clear
  plastic, SmoothPlastic at 85% see-through**, for the walls, lips, roof and gate markers; it looks the same on phones;
  the Glass sheen waits for the art pass.
- **The gate markers: a thin glass WALL across the whole track, not an arch over an opening** ("just like in rc, it is a
  wall not an arch ... it feels more satisfying to pass through a wall"); skaters still pass through it. Asked with
  ASCII previews (recommended): **floor to roof, all lit** - it fills the gate's whole cross-section from the track's
  surface (bank, floor, step, wall foot) up to the lips and the roof, thin (0.5), the glass's look, nothing hits it;
  the whole wall glows in the team's colour (still see-through) on the next gate; the carrier's arrow points at its
  middle. Not chosen: lighting it as thin vertical light lines (RC's curtain look). Replaces the hanging panel above.
- **The walls' thickness**, after their play check (screenshots): at 0.5 the goal gate's wall shared the rim's face
  plane and the rim flickered. The owner: "lets try 0.2 studs thick" (recommended: 0.2, with a settings check keeping
  the wall thinner than half the goal's thinnest part).
- **Only the lit wall shows** (the owner, same answer): "the wall marker shouldn't always be visible with the white
  color when a ball is not picked up or the player pass a marker and the marker becomes white and next one lit, we
  should only show the lit marker the other ones become invisible". Every gate wall is invisible except the next
  gate's, lit in the team's colour: none while nobody has the ball or before the first gate, and a passed wall
  disappears.
- Asked: "are the physics and camera in future tasks?" - yes, the Feel part (next after the Arena part).
- **The loose ball's 15 s respawn** (the owner, playing PlaceVersion 9: the ball "keeps respawning in a default spot
  when not picked"; their issue list: "Ball gets spawned randomly again when not being picked after a while at the
  start"). Asked (recommended): the timer (`Ball.ballIdleResetSeconds`) waits for the **Ball & rules** part. A carried
  ball does not respawn ("I tried picking it up and standing for a while it didn't respawn").
- **Lap markers start at the goal's gate** (the owner, same playtest): "when a player picks a ball make sure to show
  the marker that is on the same level of the goal, no need to wait for player to pass a certain marker to start the
  lap markers, it should start from the marker that is close to the goal". Asked to pick the order, they gave it in
  their own words: "it should be the marker next to the goal, then the marker that is on the same level of the goal
  but on the other straight side, then the other marker on the other straight side, then the marker that is before
  the goal marker, so that then players just see the goal open and ready to shoot". So every streak starts at the
  goal's gate: Gate 2 -> 3 -> 4 -> 1, and its wall lights on the pickup. Replaces "the first gate crossed starts the
  sequence" (any gate, nothing shown before it).
- **When the goal opens** (asked next, recommended): **after 4 laps, for now**. Only the marker order changes in the
  Arena part; the goal opening after 1 lap (+1), 2 (+3) and 3 (+5), first to 5 wins, comes with the whole scoring set
  in the Ball & rules part. Not chosen: opening after 1 lap now.
- **The middle glass** (playing PlaceVersion 11): "did you make the middle glass not skateable like the outer glass?
  it shouldn't be the case if yes". It is built like the outer glass and rideable (measured: a sharp turn into it rode
  its face to about 21 studs); from a shallow angle a skater mostly stays on its tight 8-stud bank. Asked
  (recommended): getting onto it from a shallow angle is the **Feel** part's.
- **The playtest of PlaceVersion 11:** "Everything works" (the 8-point checklist).
- **A gate counts either way** (after the end-of-phase review found that a carrier picking the ball up just past
  gate 2 could turn back to it): "the player can record passing the gate either ways, from the back or the front,
  but the order of the gates is the same, doesn't change based on his way of clearing a marker". So a crossing counts
  from the gate's front or its back; only the order (2 -> 3 -> 4 -> 1) matters.
- **The goal scores either way too** (answering the amendment's approval question): "also the goal should be able to
  get scored by either way, front or back". A save's block follows (a thrown ball headed through the ring either way).

## The owner's answers, 2026-10-27 (the Feel part's planning)

Planned by questions in rounds, each with a recommended answer; the owner accepted every recommendation unless noted.
Measured first in our game: a skater who lets go of every key at cruise (72 km/h) on a straight rolled for 28 s,
about two thirds of a lap, swinging from wall to wall.
- **The camera** tilts only part of the way with the surface, up to a limit the owner picks from screenshots.
- **Riding the glass:** real physics. The minimum wall speed (42 km/h) goes: a skater stays on the glass at any
  speed and gravity pulls them along it, so a slow rider slides back down. While riding the glass or a wall gravity
  pulls about **a third** as hard (a ranked player's ride up the glass lost speed about three times slower than our
  full gravity would); in the air it stays full. The lips keep the loop rule; the glass stays 120 studs, because
  "experienced players can use mechanic and reach high".
- **Coasting:** a skater pressing nothing stops from 72 km/h in about 5 s on flat ground; swings between the walls
  die out after one or two. Holding the stick or pump skates as before.
- **Jumps** cost 10% of the speed. **Air Pose:** one more press in the air, until landing: a small hop of about half
  a jump, costing speed like a jump, with a pose; the hint reads "Air Pose" while airborne.
- **Hard landings:** a drop of about 20 studs or more onto flat ground knocks the skater down like a tackle (a
  carrier drops the ball); landing along a curved wall or bank the way it slopes is safe.
- **The Uppercut** leaps about 31 studs up anywhere, not only beside a wall.
- **The dive**, as in Roller Champions: in the air the tackle input dives; it ends with the diver on their belly,
  sliding, then getting up. No extra wait after it.
- **Getting up:** a "Get Up" prompt with the movement keys; moving gets a knocked-down skater up, not before 0.5 s, and
  they are up after 1.5 s at the latest.
- **The middle curve:** the inner bank doubles to a smooth 16-stud quarter curve into the middle glass, like Pixel
  City's (the owner: "it is more curved than our map currently, we should follow that curve"); screenshots first.
- **Speed:** the owner asked whether the first answer's 115 km/h top speed was really Roller Champions' ("are you
  sure that is like that in RC? and it follows real physics? and not just hardcoded"). It was not measured; the
  measurement below replaced it: speed above **108 km/h** bleeds off quickly, the further over the faster, on the
  ground; **one ceiling of 145 km/h** for everything (skating, the whip, dives, drops).
- **The Grapple Whip** adds about 90 km/h on release, toward the direction held as the skater lets go (straight ahead
  with no input).
- Process (the owner, 2026-10-27): no more spec and plan documents for a part; it is planned by these questions and
  written as GitHub issues (#214 to #224), then built issue by issue, test-first.
- **Where the light wall gravity starts** (asked while building it, #216, with measurements): **from a 30° tilt**, not
  the 60° first planned. Our outer wall rises from an 18-stud curved foot, and below 60° a skater lost most of its
  speed there at full gravity; Roller Champions' glass rises almost straight from a low foot. Measured in Studio, a
  skater sent straight at the outer glass from the middle lane, nothing pressed: from 60°, a 108 km/h ride climbed 30
  studs, a whip release 44 and 145 km/h 42; from 45°, 40, 49 and 49; from 30°, 46, 61 and 55. The pump step (19° at
  its steepest) keeps full gravity.
- **How high a hard landing is** (asked before building it, #222, 2026-10-27): **a fall of 40 studs or more**, judged
  by the height fallen, not the 20 first planned. Our Uppercut leaps 31.5 studs (29.3 from cruise) and an Air Pose at
  its top adds about 4 (~36), so with 20 every uppercut coming down on flat floor would have knocked its own user
  down. And the 145 km/h ceiling holds in the air too: a free fall reaches it after 121² / (2 × 196.2) = 37.3 studs,
  so every fall over that lands at the same speed, which is why the height fallen decides. A jump + Air Pose (~13)
  and an uppercut land safely; a fall from the glass (rides reach 46 to 80 studs) onto flat floor knocks down. Not
  chosen: 20 with the landing after one's own uppercut exempt; 20 with no exemption.
- **An Air Pose breaks a fall** (same answer, recommended): it stops the fall and hops the skater about 4.5 studs up, so
  the height counts from its hop: a skater falling 60 studs off the glass who strikes an Air Pose just above the
  floor lands safely. Not chosen: the whole fall counts from the highest point since leaving the ground.
- **Screenshots for the middle curve and the camera** (2026-10-27, on a private review page: the owner's Pixel City
  frames at 4:04.6, 1:12.9 and 0:04.5, beside Studio shots of our arena; for the camera, the owner's frames at 0:23.5
  and 5:41.5 and the ranked games at 21:01.5 and 27:51, beside a skater on our outer glass 45 studs up with the camera
  tilted 0°, 15°, 30°, 45°, 60° and the full 90°). The owner chose every recommendation:
  - **The middle curve: 16 studs**, as shown (#217): a quarter curve 16 studs high and wide into the middle glass; the
    low floor narrows from 28 to 20; the track stays 80 wide.
  - **The camera tilts at most 30°** (#223): the top of what the owner's own games showed (about 15–30° by eye), close
    to the ranked player's ride at 21:01; the ranked ride at 27:51 rolled about 60–90°.
  - **The speedometer reads like Roller Champions'**: the speed along the surface on the ground and the walls, the
    horizontal speed in the air. Roller Champions read 0 during a standing jump (Video 5) and held steady through an
    Air Pose (Video 4); ours showed the full 3D speed (85 km/h right after a jump at 71).
  - **How high skilled combos reach** (measured 70–80 studs; the lips start at 108): judged at the Feel playtest; if
    too low, measured options then (a stronger whip or uppercut, lighter wall gravity).

## The owner's answers, 2026-10-28 (the Feel playtest, the published build at the stack's head)

- **Combo heights: high enough** (recommended): today's 70–80 studs stay.
- **Climbing the glass costs speed** (recommended). Told first: since the glass fix (#234), holding the stick toward
  the glass kept a skater at cruise while climbing it (20–60° entries reached 39–64 studs within one straight), while
  a ranked RC rider climbing the glass lost speed fast (98 to 21 km/h in about a second, Video 3, 21:01). So on a wall
  the stride no longer pushes uphill. Not chosen: keep it.
- **Findings, in the owner's words:** "why the player can just ride the wall and be stick to it like skating on the
  ground floor? and abiliting to keep spaming Tackle in short durations, and also even when on the ground, he should
  be able to dive after a tackle, like tackle then dive in the ground, and when he dive, there should be a duration for
  him to get up, give him like a real human being weight, just like RC, always follow RC, we try to get 1:1". So:
  - wall riding feels like skating on the floor (the skater sticks to it);
  - tackles can be spammed in short intervals;
  - on the ground a tackle should be followed by a dive (tackle, then dive), as in RC;
  - after a dive the skater should take a weighty, human time to get up, as in RC.
- **The findings' round** (2026-10-28; the owner: "do your recommendations"). RC measured first from Video 4's hint
  column at 10 frames a second (five ground tackles) and Video 3's glass rides; ours in Studio:
  - **Wall riding:** on a wall (steeper than 30°) the stick no longer pushes and steers at most **1 rad/s** (on the
    floor 2.8 at cruise). Measured on an upright wall, stick held level along it: today every rider stays above 20 studs
    for the whole 20 s tested and ends at 72 km/h (a slow one speeds up); with the rule only a rider faster than
    ~78 km/h holds a line (90 km/h: level ~1.9 s, then curves down), a 30 km/h rider is back on the floor in 1.6 s at
    86 km/h, a 104 km/h entry stays above 20 studs 4.4 s. RC: slow riders swing up and down low on the glass (Video 3,
    31:16, 1–41 km/h), a 104 km/h entry stayed high ~6 s with the readout swinging 9–56 (14:25), a 90 km/h rider held a
    line ~2 s (21:09). Pumping on walls unchanged. Not chosen: no push only (still ~16 s above 20 studs); no steering.
  - **Tackle, then Dive, on the ground and in the air:** the Dive is only a follow-up of a Tackle, pressed 0.1–1.0 s
    after the Tackle press; the hints and the touch button read "Dive" then. RC: "Dive" replaces "Tackle" 0.1–0.2 s
    after the press for 0.7–0.8 s, and "Tackle" is back 0.9–1.0 s after it; in the air the first press is a Tackle
    (Video 5). Replaces #221's "the first press in the air dives".
  - **The tackle's wait: 1.0 s** (was 0.8): RC's plain tackles come ~1.0 s apart.
  - **The tackle's push:** a lunge to **72 km/h** along the facing for its strike, then the slower of that and the speed
    before it, so a tackle never makes a skater faster (in the air 0.8 as strong, 58 km/h). RC's lunge peaked at
    65–75 km/h from 31–96 km/h and fell back within ~0.3 s. Today: +48 km/h that stays.
  - **The dive's push:** a lunge to 72 km/h along the way, or the speed already had if faster; falling adds the rest
    (cap 145). RC: a ground dive 47 → 71 km/h, an air dive 27 → 82 in 0.33 s and 124 at the bottom. Today: +72 km/h.
  - **A diver gets up when the slide stops** (at 1.5 s at the latest), with no early get-up by the stick and no Get Up
    prompt; tackled skaters and hard landings keep today's Get Up. RC: actions back exactly at 0 km/h, 0.7–1.0 s after
    touchdown. Today: up from 0.5 s with the stick (measured: 0.53 s after touchdown, still at 37 km/h).
  - **The look of weight:** a diver lies face-down and forward (not tipped back), and every knockdown eases down and back
    up over ~0.3 s instead of snapping; judged on screenshots and at the playtest. RC (Video 4, 0:32.2–0:33.7): the
    diver stretches out low, lands on the knees and belly, slides kneeling and rises as the slide ends.
  - **An air Tackle soon after an Uppercut** (round 2, recommended): the Uppercut's 0.4 s recovery goes, so a Tackle
    may start once its strike ends, 0.25 s after the press (the Uppercut's 1.2 s cooldown stays). RC (Video 5, 1:19.5):
    Tackle ready 0.13 s after the Uppercut, the chain Uppercut → Tackle 0.33 s later → Dive 0.53 s after that. Today:
    busy 0.65 s. The owner approved the five tickets (walls; Dive after Tackle; lunges to 72 km/h; a diver up when the
    slide stops; face-down diver and eased knockdowns).
  - **The brake on a wall** (2026-10-28, while building #239, AskUserQuestion, recommended): **it does nothing** on a
    wall (steeper than 30°), like the stride. Measured first on an upright wall: holding Brake stopped a skater dead
    and kept them there (34.9 studs up, 0 speed, all 6 s), and Brake with the stick up tiptoed them straight up the
    glass at 12 studs/s (14 km/h), 40 to 112 studs in 6 s. Not chosen: the brake slows but cannot hold; keep it.
  - **Round 3, after Video 6** (2026-10-28, the owner: "yes", all recommended): Q9 wall gravity stays a third, judged at
    the re-playtest with #239's changes; Q10 the tackle ADDS 48 km/h (40 studs/s) but never past 72 km/h, a faster skater
    slows to 72, and when the strike ends they keep the slower of that and the speed before (refines Q4: RC 14 → 59,
    31 → 75, 47 → 71, 82 → 73, 96 → 74); Q11 the dive's strike lasts 0.7 s with no extra slowing (a glide), then the
    belly slide, up at the stop, ~1.5 s in all (RC: 67-70 km/h within ~0.4 s, glide ~0.3 s, slide 0.7-0.8 s, up 1.5-1.6 s
    after the press); Q12 the dive flies along a line 20° below the facing and gravity speeds the diver along it
    (cap 145), so the readout climbs like RC's (19 → 65 at the press, +7.5 km/h every 0.1 s, 133 at touchdown 1.1 s later).
  - **Two more, the owner's words (same message):** "when a player is coming on a certain speed I think and pressing S on
    the direction of the player that is dropping from, he starts skating but his back on the front, I want that
    mechanic, I want it to be smooth like RC, but I am not sure if this is now or later in arts and animations" and
    "when a player jumps in the air and do an airpose, and keeps holding the airpose and drops to the ground with the
    airpose, he should fall, because his feets are not in a normal position, it is like a human being, like RC". Video 7:
    `D:\Screenshots\Videos\Screen Recording 2026-10-28 021412.mp4`.
  - **Round 4, after Video 7** (2026-10-28, the owner: "yes", all recommended): Q13 the Air Pose lasts while the jump key
    is held (letting go ends it); touching down still posing is a fall at any height, a knockdown like a hard landing
    (Get Up prompt, the stick from 0.5 s); a pose let go before touchdown still breaks a fall. Q14 while posing and
    falling, gravity pulls along a line 20° below the facing (Q12's dive rule), so a posed fall gains forward speed like
    RC's (~85 km/h per s). Q15 riding backwards: moving against the way they face (back down a wall or bank, or slowing
    past a stop) while holding the stick the way they move (S), the skater keeps facing and rides backwards; letting go
    of S or steering elsewhere turns them round smoothly in ~0.3 s; never a snap. Its own ticket now; finer animation in
    the art milestone. Q10–Q12 fold into #241/#242; Q13–Q14 one new Air Pose ticket, Q15 one new ticket, after #243.
  - **Round 5, while building #241** (2026-10-28, session 32, AskUserQuestion, all recommended): Q16 after a Tackle's
    lunge the speed **eases back** to the speed before over the Tackle's 0.35 s recovery, no jolt (RC's readout falls back
    in ~0.3 s: 75 → 33, 71 → 46, 73 → 50 km/h, Video 4); not chosen: a drop at the strike's end. Q17 **the air Tackle
    matches RC**: it adds 16 studs/s (19 km/h), 0.4 of the ground's 48 km/h (RC: 27 → 42 km/h, Video 5; 18 → 37, Video
    6); the air dodge and uppercut keep 0.8; not chosen: 0.8 (38 km/h added). Q18 the air Tackle's ceiling is the
    ground's **72 km/h** (one rule everywhere; RC's air tackles never came near a ceiling, so the videos can't tell);
    not chosen: 0.8 of it (58 km/h).
  - **Round 6, after #242's Studio check** (2026-10-28, session 33, AskUserQuestion, recommended): Q19 **a belly
    touchdown from the air keeps about 2/3 of the speed**, like RC: landing from the air while diving or still
    posing loses a third of the speed shown at that moment, then the slide (RC: 133 → 84 km/h, Video 6 dive; 139 →
    101, Video 5 dive; 104 → 70 and 97 → 57, Video 7 posed falls: 59–73% kept; slide 0.7–0.8 s). Ours kept ~95% (an
    air dive touched down at 121 km/h and slid 117 → 0 in 1.2 s). A ground dive loses nothing (RC Video 4; ours
    too). A new setting, built test-first in #245; not chosen: its own ticket now; keep ours.
  - **Round 7, #243's screenshots** (2026-10-28, session 33, private page
    https://claude.ai/artifact/C6ScXy34F1bKJbmS5399me, AskUserQuestion, both recommended): Q20 **the diver's pose
    stays as shown**: face-down, kneeling on the belly (body tipped 70° forward, thighs 70° forward under it, shins
    folded back 90°, sunk 1.5 studs), beside RC's kneeling slide (Video 4, 32.3–33.4 s); not chosen: flatter (~85°).
    Q21 **a tackled or hard-landing skater lies flat on the back on the floor** (tipped 85°, sunk 2.2 studs, eased
    like the diver), in #243: before, they tipped 60° back at standing height and floated at a slant; RC's tackled
    skaters lie flat sliding (Video 1); not chosen: keep the 60° tilt. Then fitted (my ruling, measured by forward
    kinematics on the owner's avatar): the shots had the diver's shins and feet up to 1.2 studs below the floor and the
    flat skater half sunk, so the diver's thighs go 50° (shins 110°, sink 0.7: shins on the floor, torso 0.6 up) and
    the tackled skater sinks 1.3 (back 0.18 up, feet touching); the tips (70° forward, 85° back) are unchanged.
  - **Round 8, #245's Studio check** (2026-10-28, session 34, AskUserQuestion, recommended): Q22 **knockdowns from a
    fall slide longer, like RC**: a posed touchdown or a hard landing slows at ~40 studs/s² (~48 km/h per s), tackles
    and dives keep today's rate; a new setting, its own ticket after #246, RC's tackle and hard-landing slides
    measured from the videos first. RC (Video 7): a posed fall's slide took 1.3–1.4 s to stop (70 → 0 km/h, ~50 km/h
    per s); a dive's 0.7–0.8 s (84 → 10, ~92 per s, Video 6). Ours, measured in #245: every knockdown ~82 km/h per s
    (88 → 42 km/h in 0.57 s after a posed fall, 78 → 34 after a dive). Not chosen: keep one rate; judge at the
    playtest.
  - **Round 9, while building #246** (2026-10-28, session 34, AskUserQuestion, recommended): Q23 **S from a
    standstill turns the skater round smoothly** (~0.3 s) and they skate off facing the way they go: today's
    behaviour without its one-frame snap. Riding backwards happens only when the skater is carried back against their
    facing (rolling back down a bank or a wall they climbed, Video 7). None of the videos show S from a standstill in
    RC. Not chosen: S from a stop skates off backwards while held.
  - **Round 10, measuring for #252** (2026-10-28, session 35, AskUserQuestion, recommended): Q24 **every knockdown
    slides RC's way: it slows evenly to a stop in a set time, whatever the speed: 1.5 s after a tackle, a hard
    landing or a posed fall, 0.8 s after a dive.** It replaces the one fixed rate (`knockdownDecel`, ~82 km/h per s
    for every knockdown) and Q22's "tackles and dives keep today's rate"; the Get Up rules are unchanged (the stick
    gets a tackled or fallen skater up from 0.5 s, keeping the speed left). Measured first at 10 frames a second
    (the speed readout): a tackle (Video 4, 2:37.2) 50 -> 0 km/h in 1.5 s, evenly (3.3-3.7 km/h every 0.1 s); posed
    falls (Video 7) 70 -> 0 (21.5-23.0 s) and 57 -> 0 (29.1-30.6 s) in 1.5 s each, evenly; a hard landing (Video 5,
    over the wall onto the grass outside) 31 -> 1 km/h in ~1.4 s (18.1-19.5 s; 31 -> 21 in the first 0.2 s); dives
    68 -> 0 in 0.7 s (Video 4), 84 -> 10 in 0.8 s (Video 6), 101 -> 16 in 0.67 s (Video 5). In RC the skater pushed
    off right as each slide stopped (0 -> 22 -> 43 km/h within 0.2 s, Video 7). Only one RC tackle knockdown was
    found: the Get Up prompt searched by template over Videos 4 and 6 (one in Video 4, none in Video 6; Video 7's
    frames differ in size, so its posed falls were read at the times already noted); none found in Video 3 (2021).
    Not chosen: 1.5 s with dives as today; the issue's fixed ~48 km/h per s for falls only.
  - **The re-playtest of the published stack head bf426a2** (2026-10-28, session 35), the owner's words: "it is still
    far from RC gamepaly and real physics and realism"; (1) Video 8 (ours, `D:\Screenshots\Videos\Screen Recording
    2026-10-28 145738.mp4`, 1:24): "the player can still ride the walls outer and middle, and specially the middle how
    he can turn the hard curved turns and being able to stick to the wall"; "I think it is wrong that we keep
    measuring by the physics and stuff from the speedometer, I am not sure I don't know"; (2) Video 9 (ours,
    `...2026-10-28 150133.mp4`, 0:15): "the player can still be in a ride loop between walls, even when not clicking
    on any buttons"; (3) "when a player jump, or uppercut or goes into a wall, make sure that his legs are riding the
    wall, and not just drop down vertical next to it" (RC reference: Video 7's start).
    Measured (session 35): Video 9 swings middle glass -> outer glass -> middle -> outer for 13 s, crossing the floor at
    104-113 km/h every time (3 frames a second). Video 8 0:02.0-2.8 and 0:04.8-5.5: our skater comes off the glass and
    falls upright beside it to the floor. RC Video 7 0:01.1-3.0 and 0:05.9-7.3 (10 frames a second): up the bank,
    straight up off its top, a flip, then back down feet first onto the bank's face and down it. Cause of (2), found
    with a harness stepping SkateMath over the real arena (no Roblox physics): the ground-normal filter's smoothing
    lags the surface on curves and adds energy each wall visit: from 108 km/h, nothing pressed, floor crossings 96,
    107, 97, 104, 90, 95, 77, 78, 54, 47, 29 km/h (32 s); raw normals 61, 38 (stop 6.1 s); smoothing 120: 65, 44, 20;
    smoothing 10: 111, 145. In Play with the lag removed: 107 -> 62 -> 38 -> 8, stopped at 6.2 s (Play with it: 7 visits
    in 20 s). Cause of (1): only an overhang can throw a rider off; a pure-SkateMath test kept a skater on the outside
    of an upright round pillar (r 20) at any speed (196 deg round at 108 km/h). Cause of (3): in the air the skater turns
    upright and only a surface along their feet's ray lands them, so a wall beside them never does. Wall gravity, lag
    removed, real arena, nothing pressed: straight at the outer wall 108 / 145 km/h climbs 28 / 39 studs (a third), 22 /
    30 (half), 16 / 21 (full); along the glass 40 up with the stick along it, 72 / 108 km/h stay above 20 for 2.5 / 4.5 s
    (a third), 1.0 / 2.0 (half), 0.55 / 0.63 (full). The third (Q16) came from RC's readout at Video 3 21:01, assumed to
    be the full speed on the glass; RC's air readout is speed across the ground, so on the glass it may not be.
  - **Round 11, after the re-playtest** (2026-10-28, session 35, AskUserQuestion, all recommended): Q25 **one gravity
    everywhere: walls and glass pull at full gravity, like the air** (reverses Q16's third; real physics; the owner's
    Video 6 note on RC: "the gravity is strong and pull him, it is hard to go up"): riding alone climbs 16 / 21 studs at
    108 / 145 km/h and a line along the glass lasts ~0.6 s; higher only through combos, re-measured for the next
    playtest. Not chosen: half (22 / 30, 2.0 s); keep a third (28 / 39, 4.5 s). Q26 **skaters fly off surfaces that
    bend away from them** (real physics: a surface only pushes): off the middle glass's round ends at any speed, off a
    floor crest when gravity cannot hold them on at that speed; overhangs keep today's rule; the outer wall's curves
    (bending toward the skater) still hold them. Not chosen: walls only. Q27 **a skater in the air who touches a ride
    surface lands on it feet first**: the feet turn onto it, the speed along it is kept and the speed into it lost, then
    the wall rules apply; one who flies straight up off a wall stays turned to it and comes back down onto it (RC Video
    7). Not chosen: only coming back down. The no-input loop (the ground filter's lag adding energy) is a bug, fixed
    without a question.
  - **Round 12, while building #258** (2026-10-28, session 36, AskUserQuestion): asked what an Uppercut does while
    riding the upright glass (its leap is straight up, along the glass): (A, recommended) stay on the glass, the leap
    pushes them up along it feet on it, no Air Pose / air Tackle / Dive during it; or (B) fly up turned to the glass
    (Air Pose, air Tackle and Dive work), landing back on it feet first once falling within ~6 studs. The owner, Q28:
    "Well I think it should be both, if they somehow manage to get a good speed and uppercut into the well or jump,
    they should be able to tackle, pose, dive, but also should stay on the glass if you understand what I mean, if you
    always need anything from RC to check mechanics or anything, let me know, I can record and you see, like for
    example spamming jump on the wall ,or uppercut or anything like that, and edge cases". Read as B: in the air they
    keep every air action and stay turned to the glass, and the glass catches them (they come back onto it feet
    first, not down beside it). The owner offers RC recordings of wall edge cases (jump spam on a wall, uppercut).
  - **Videos 10 and 11, the owner's RC wall edge cases** (2026-10-28, session 36, recorded for #258 on request; map
    "Fallen Stadium": a low curved outer wall with the crowd right behind it, open top, a curved inner glass):
    Video 10 `D:\Screenshots\Videos\Screen Recording 2026-10-28 174406.mp4` (2:37, 1918x1078, 30 fps), Video 11
    `...2026-10-28 174631.mp4` (1:52, 1892x1076, 30 fps). The owner's words: "make sure if a player jump, he can't
    sequence it with an uppercut unless he touches a ground or wall, basically something solid, take a look, be
    really thorough, notice the mechanics, gameplay, physics, gravity, I couldn't spam jump, and about the uppercut and
    jump and air posing, if the player airpose next to the wall, he falls like in the video, same for the dive of
    course". Seen (1 frame/s over both, 10 frames/s on Video 10 45.8-49.3, full-size hint crops): **in the air RC
    greys Uppercut** (and Pump, Brake): the hint column shows Air Pose and Tackle (or Dive) lit and Uppercut dim at
    Video 10 82.0 and 107.0 s and Video 11 51.0 s; on the ground every hint is lit (Video 10 21.0, 28.5, 41.0 s, the
    last with the press marker on Jump). Video 10 46.2-48.9: Uppercut pressed at the outer wall (32 km/h), the skater
    rises beside it, flips (Air Pose) at the top, falls back 56 -> 77 km/h and touches down on the wall's curved foot
    at 57 km/h with the Get Up prompt: a fall. Get Up prompts after wall excursions with an Air Pose offered: Video 10
    0:43, 0:48, 0:54, 0:59, 1:04, 1:54, 2:22, 2:34. Excursions over the wall top without a pose came back onto the
    wall or track riding (Video 10 0:29-0:31, 1:10-1:13).

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

### Video 3: Suppraa, "45 minutes of Top 100 Ranked games | Raw Gameplay - Roller Champions" (2021-08-29, 46:07)

https://www.youtube.com/watch?v=r2xWeAFSEMw - given by the owner 2026-10-26. No captions (raw gameplay). Chapters:
Game 1 0:00, Game 2 8:26, Game 3 17:36, Game 4 22:31, Game 5 28:14, Game 6 35:53. **Maps: Mexico (indoor, 25,000
seats) in games 1, 2, 4, 6; Acapulco (outdoor beach, "sold out", 6000 seats) in games 3, 5.** Studied in full:
all 58 contact sheets (one frame every 4 s) plus dense clips of the
topics below.

First pass (verified in frames):
- **Mexico** (flyovers 0:20, 0:24, 8:44, 22:48): the track is enclosed by tall clear glass walls that curve inward at
  their top, with dark hoop frames over it (the owner calls it the closed glass top). Orange wooden floor, red banks,
  chevrons, painted gate numbers ("<1", "<2"), a raised inner island with chevrons.
- **Acapulco** (flyovers 17:36-17:48, 28:12-28:28): an oval with tall clear glass walls curling inward at the top and a
  white rail frame hooping over it; an inner channel (blue water) fenced by a curved glass rail; pink inclined ramps
  at the corners (the "inclined road" pump spots); yellow lanes. Live at 21:00-21:07: the recorder rides the tall outer
  glass at 90 km/h (camera rolled with it); the glass curls over at its top.
- **Rules:** a 07:00 clock counting down from kickoff; the kickoff countdown is a big circled number in the world
  ("4", "3", "2"), then "GO ORANGE TEAM!"; "LAP 1 COMPLETED" toast, then a goal = "+1 PT" (3:20-3:32, 9:52-10:04);
  "LAP 2 COMPLETED" (4:52); "+3 PTS" (28:00); "DENIED!" (2:40, 5:32); "LAST CHANCE" banner at 8:00 (game 1 ended 0-1,
  "ORANGE WINS!!!" at 8:20); game 4 ended 0-6 (28:08: a +3 goal past 5), game 5 ended 0-5 (35:32). An orange "L1" badge
  over the ball carrier (7:20, 9:20, 23:08): the team's laps. The clock holds during the replay and kickoff.
- Speeds to about 115 km/h. The reticle: an orange circle with tick marks on the targeted player.
- **21:13 (the owner's "invisible roof"):** 21:07.5 GOAL, 21:12.5 logo wipe, 21:13.5-21:17.5 its replay. The scorer
  flips in the air near the goal's arm and throws up; the ball rises above the overhead glass rails, slows to a near
  stop over ~0.3 s (21:14.85-21:15.18) and falls into the ring (21:16.5-17). The replay camera turns with the ball; no
  abrupt reversal was visible (it looks like a gravity apex), so a ceiling can neither be confirmed nor ruled out from
  it. Tell the owner this plainly; their request (an invisible ceiling for the ball on open maps) stands as their call.

The full pass (facts seen in frames; times are video times):
- **Shapes, from the flyovers (0:22-0:24, 36:12-36:14 Mexico; 17:34-17:44, 28:12-28:22 Acapulco):** both arenas are a
  long oval walled all round by TALL vertical clear glass, roughly 0.6-0.8 of a curved end's diameter high (judged by
  eye in perspective, not measured). The opaque outer wall is short: on Acapulco's straight (18:28) the floor meets a
  low curved white foot (well under a skater's height) and the glass rises from it. Mexico: a dark metal ring runs
  round the glass top with dark hoops arching over the track (the owner's "closed top"; whether glass fills the top
  between the hoops could not be told from the frames). Acapulco: white rails round the glass top, the glass and rails
  curling inward at the top, white hoops arching over the track, open sky between them.
- **The infield:** Acapulco's is a long sunken blue channel down the middle of the straights, fenced by a low curved
  glass rail; skaters ride down into it (29:08, 29:32, 32:44: "ARENA" painted on its floor). Each curved end has a
  round raised pad in its middle (yellow, checkered edge) with a tall glass column on it (18:48, 19:20, 21:44).
  Mexico's curved ends have a round red island with chevrons and a logo, a tall column at its centre (12:40, 15:32,
  24:48); a low red bank lines the inner side of the straights.
- **Pump spots ("inclined road"):** Mexico's straights have a chevron-marked ramp strip between a lower grey lane and
  the wooden floor (0:16, 13:24, 15:20); Acapulco has pink inclined ramps on the straights near the outer side (17:36,
  30:29) and the inner channel's banks.
- **Wall riding:** skaters ride the glass itself in both maps, camera rolled with it. Mexico 14:25-14:30: high on the
  outer glass at 18-41 km/h for about 5 s, then back to the floor at 76 km/h. Acapulco 31:16-31:22: along the outer
  glass at 16, 9, 16, 7, 20, 4, 2 km/h, sliding back down to the floor by 31:23 (slow riding stays low on the glass and
  comes back down). 21:00-21:07: up the tall outer glass at 90 km/h.
- **Getting high:** loading tip (28:12) "Tackle and then Jump to perform an Uppercut. Gain height and intercept the
  ball mid-air!"; skaters high in the air near the goal or the top rails at 18:40, 21:12, 27:52, 29:16, 30:00.
  Another tip (17:36): "You can roll the ball along the arena by throwing it on the floor in front of you."
- **The charge crosshair (36:57.4-36:59.7, cropped at full size):** the catch shows the ball icon (an orange disc with
  white bands in a white ring, sparks) that fades; then a small orange ring with a centre dot at the screen's centre
  (36:58.15); it widens into a bigger ring of four orange arcs with white inner arcs (36:58.75-36:59.2); after the
  throw four dashed arcs follow the ball in flight (36:59.35-59.65), which went into the ring (GOAL 37:00). A
  loose or targeted ball shows as a white ball in brackets "( o )" (13:56, 14:33, 36:56). **No charge cancel was seen.**
- **The ball in the air:** a thin vertical line drops from the ball to a white ring on the floor (14:32).
- **Gate markers:** a big curved glass panel across the track at each gate, hanging from above with a rounded lower
  edge that skaters pass under, lit in a team's colour with vertical light lines (blue 12:12, 26:44, 38:16; orange
  14:16, 14:28).
- **The goal:** a ring in a white housing on an arm, hanging high near the outer glass (Mexico 11:16, 40:04, 42:00;
  Acapulco 18:44, 29:56); a goal flashes white or explodes in smoke (33:56, 37:08), "GOAL", then the logo wipe and a
  replay with the scorer plate "+1 PT" / "+3 PTS".
- **Rules seen:** "LAP n COMPLETED" toasts; the "L1" badge over the carrier (15:48, 30:52). The game ends the moment a
  team reaches 5 or more: game 3 ended 6-0 at 22:04 (a +3 goal from 3, 4:05 left), game 4 ended 6-0 at 27:48 (+3 from
  3, 2:40 left), game 5 ended 5-0. Clock at 0:00: the leader wins, except **"LAST CHANCE"**: in game 1 (8:00, 1-0) and
  game 2 (17:07, 3-0) the trailing team held the ball at 0:00, the clock turned red at 03:00 counting down, and play
  went on until their attack ended ("DENIED!" 8:02, "SPARE!" 17:10), then "ORANGE TEAM WINS". Not seen: a Last Chance
  for the leading team. **Overtime** (game 6, 3-3 at 0:00, 44:56): "OVERTIME", a red 03:00 countdown, the next goal wins
  (Orange +1 at 02:15 left, 45:40, 4-3). Not seen: overtime running out (the owner wants a draw then).
- End card: "ORANGE WINS!!!" with the big score numerals and both teams posed (8:14, 17:28, 22:16, 46:00).

Tools: yt-dlp 2026.10.21 and FFmpeg n9.0, as above: the video at 1080p60, contact sheets every 4 s, and dense clips
and full-resolution crops of each topic, each frame stamped with its video time (outside the repository).

### Video 4: the owner's own match on Pixel City (8:34, 30 fps), at 1 frame per second, dense clips at 2-6

- **Start:** a flyover, then the skaters stand still in the arena behind the gate-1 line; the clock reads 00:00; the
  countdown is a circled number in the goal ring (5 ... 1), and skaters already skate during it; "GO ORANGE TEAM!",
  then the 07:00 clock starts. No tunnel on this map.
- **The middle:** a raised island shaped like a stadium, ringed by a wide grey band that rises from the track to a
  white rounded rim, with clear glass on the rim. Riding into it (4:04-4:05, 1:13) the skater goes up the band, over
  the rim and high up the glass in one smooth curve at 37-50 km/h, then flies over the island (4:05-4:06) and lands at
  96 km/h, reading 16 a sixth of a second later (the speed into the ground lost on landing).
- **Wall riding:** a slow skater stays on the outer glass and comes back down it, speeding up (0:28.8-0:29.5:
  30 -> 65 km/h). The camera's horizon leans about 15-30 degrees on the glass (judged by eye).
- **Air Pose:** in the air the hints swap Jump for "Air Pose" and Tackle for "Dive". The pose is a flip or a
  superman stretch; its trail kinks up as it starts (a small hop); the speed holds through it.
- **Throwing:** while charging, the hints read Throw, "Cancel & Dodge" (the dodge input cancels the charge) and "Roll
  Ball"; a big white hand over a teammate calling for the ball; a key letter over the teammate a pass would reach.
- **The Grapple Whip:** the hint "Hold & Release F + movement keys: Speed Boost". Every frame at 2:08.5-2:10.5: the
  readout rose 53 -> 66 -> 91 -> 121 -> 138 -> **144** km/h in 0.3 s, then bled off 144 -> 121 in 0.2 s, -> 114 in
  0.13 s, -> 108 in 0.4 s, and hovered 103-108; the game then showed the achievement "Reach a speed of 141.622 km/h or
  more in any arena match type". The same shape at 2:51 (53 -> 128 -> 114) and 7:17 (65 -> 136 -> 114).

### Video 5: the owner's game on the Mayan Stadium (1:44, 30 fps), every frame of the jumps

- **Standing jumps** (0:40.7-0:42.9): 0.60-0.73 s in the air, rising roughly one to two body heights; ours: 0.61 s
  and about two. So Roller Champions' gravity is in our range (judged roughly, not measured precisely).
- **Uppercut -> tackle -> dive** (1:13-1:21): an Uppercut on flat floor, away from any wall, launches the skater up;
  in the air Tackle becomes "Dive"; the dive's readout rose 69 -> 139 km/h in the air, then the diver landed on their
  belly and slid (101 -> 16 km/h in 0.67 s), unable to act, then got up.
- **Knocked down** (0:18): a "Get Up" prompt shows the movement keys; skating again in under 1.8 s.

### Roller Champions' speedometer, measured

Video 3's readout every 2 s for 46 minutes (about 1,380 readings): 100-120 km/h is common; the peaks are 140 (0:42),
136 (11:44 and 11:46), 131, 130, 128; never above 140. With Video 4 (144 after a whip) and Video 5 (139 in a dive):
skating, pumping and slopes reach about 100-110; boosts (a whip, a dive, a drop) reach about 140-145; anything above
about 110 bleeds off within a second, faster the further above it is. The game's code is not public, so whether that
is a physical drag or a tuned limit cannot be known; the behaviour is what the game copies.

### Video 6: the owner's RC solo match on "Hidden Cenote" (recorded 2026-10-28 02:06, 1:41, 1918x1078, 30 fps)

`D:\Screenshots\Videos\Screen Recording 2026-10-28 020627.mp4`. The owner (2026-10-28, session 31): "wall riding in the
game currently is completely broklen and unrealistic, a player can't ride the wall like that like it is a ground ...
look at the player just easily ride the wall, the gravity is strong and pull him, it is hard to go up, and bonus, look
at the diving, tackling, uppercut the tackling and diving". Studied at 1 frame/s, 5 frames/s on the rides and 10
frames/s on the hint column (speed readout, ">>" press marker):
- **Walls and banks:** no straight climb up the upright glass in this video. Up the curved ends' banks the speed trades
  hard with height: 74 → 21 km/h in 1.6 s (0:35.8) and back down 21 → 51 in 1.6 s; 78 → 22 in 1.4 s (1:33.2) and
  22 → 47 in 1 s; along an end's bank 43 → 16 km/h over ~3 s, staying low (0:13-0:16). 0:41.4 is an Uppercut beside
  a banner (Air Pose at 42.6), not a wall ride.
- **Tackle then Dive, mashed on the ground (1:01.9-1:08):** four cycles, each: Tackle press → "Dive" 0.1-0.2 s later
  → Dive pressed 0.15-0.4 s after the Tackle → the dive builds to 67-70 km/h within ~0.4 s, glides ~0.3 s → a belly
  slide to 0-3 km/h in 0.7-0.8 s (55-92 km/h per s) → every action back exactly at the stop, 1.5-1.6 s after the Dive
  press → Tackle at once. The tackle's lunge from low speed: 14 → 59, ~0 → 43-47 (cut short by the dive).
- **Uppercut → Tackle → Dive in the air (1:09.65):** Tackle ready 0.2-0.3 s after the Uppercut press; the air Tackle
  (pressed 0.45 s after) lunges 18 → 37 km/h; "Dive" 0.2 s after it; the Dive press: 19 → 65 at once, then the
  readout climbs ~7.5 km/h every 0.1 s while diving down, 133 at the touchdown 1.1 s later; 133 → 84 at the
  touchdown, then the slide 84 → 10 in 0.8 s. Same at 1:24-1:25 (Air Pose and Dive offered, 121 km/h).

### Video 7: the owner's RC solo match on Hidden Cenote, 2 (recorded 2026-10-28 02:14, 0:47, 1916x1072, 30 fps)

`D:\Screenshots\Videos\Screen Recording 2026-10-28 021412.mp4`. Studied at 1 frame/s, 5/s and 10/s (skater zoom, hint column):
- **Riding backwards (0:16.1-0:18.4):** up the end's bank to ~17 km/h at its top, then back down it BACKWARDS (still
  facing up the bank) for ~0.7 s (16.9-17.6), then a smooth half-turn over ~0.3 s (17.6-17.9) to face the way they go.
  Which key was held can't be read from the video.
- **Holding the Air Pose into a landing = a fall (0:19.4, 0:27.2):** Uppercut (">>" beside it) → Air Pose offered
  0.1-0.2 s later → Air Pose pressed 0.6-0.8 s after the Uppercut (speed 54 → 46, 49 → 46 at the press) → while
  falling posed the forward readout climbs ~8-9 km/h every 0.1 s (46 → 104 in 1.0 s; 46 → 97 in 1.0 s) → touching
  down still posed: 104 → 70 and 97 → 57, every action greyed and the Get Up prompt → a slide to a stop in 1.3-1.4 s
  (~30-42 studs/s², slower than a dive's).
- Video 5's standing jump (re-read at 15 frames/s, 0:40.8-0:42.5): the readout is 0 through the whole flight, the
  falling half included (15 for one frame at the landing): RC's air readout is speed across the ground.

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
