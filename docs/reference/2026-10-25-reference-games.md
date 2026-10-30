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
  - **The re-playtest of the published stack head 6bc040e** (2026-10-28, session 37, after #263 and #264), the
    owner's words: (1) "when a player jumps next or more like into the wall, he bounce back from the wall" (Video 12,
    ours), "like in recent videos, he doesn't bounce away from the wall" (RC); (2) "the camera issue, it is still
    makes players dizzy ... i don't think the camera should be fixed on the player, it should be independant from the
    player, like a spectate cam ... look how I can move the camera around the play in a 360 degree movement but I
    still move with the player with the same keys, the player don't turn with the camera" (Video 13, RC); (3) "the
    movement and players and camera, moves too fast, which I think what makes also users dizzy, it is always constant
    speedy things, unlike RC, the player feels like they have actual weights when you move them, not instantly launch
    in a speedy movement, and the camera too, not fast movement"; (4) "when a player moves close to an unpicked ball
    next to it, player picks it up, the ball goes to him like a magnetic, not only needs to go into it" (Video 13,
    under the ring).
    - **Video 12 (ours, published 6bc040e)** `D:\Screenshots\Videos\Screen Recording 2026-10-28 215815.mp4` (0:14,
      1918x1030, 30 fps): 2.3-2.7 s up the outer wall's curved foot 55 -> 15 km/h, Jump at 2.8 s: the readout (across
      the ground) 64 km/h and the skater flies away from the wall out over the floor, landing at 3.4 s: our jump
      pushes along the surface's normal, on a wall straight off it at jumpImpulse 60 studs/s. 9.4-10.6 s: a jump high
      on the glass floats beside it (6 km/h), then the glass takes them back and they ride down at 73 km/h.
    - **Video 13 (RC, Pinball Stadium)** `D:\Screenshots\Videos\Screen Recording 2026-10-28 220752.mp4` (1:45,
      1918x1076, 30 fps): 0:00-0:14 the stadium intro and ball drop; the camera sits at very different angles to the
      skater (0:32 high above, 0:40 low, 0:48 in front and to the side, 0:56-0:58 side-on) and stays where it is aimed:
      at 0:48-0:49.75 it looks at the infield while the skater runs round the curved end across the screen at 41-43
      km/h. Kickoff readout at 10 frames a second: 0 until 16.9 s, then an even 3 km/h every 0.1 s for 0.6 s (~30
      km/h per s; ours from a stop ~31: strideAccel 30 - rollingFriction 4 studs/s^2), then 6-8 every 0.1 s down the
      ring's ramp to 85. Steady skating on the flat: 50-57 km/h with the ball (1:04-1:34), 45-48 without it (0:46);
      ours strides to 72. Ball pickup (1:36.8-1:37.2): the ball lands about one skater-height beside the skater and
      flies into their hands in ~0.2 s (its trail bends toward them); 'Charge Throw' lit at 1:37.3. Ours: caught when
      the root is within pickupRadius 5 studs of the ball's centre, snapped to the carry spot at once. Not yet found:
      a jump into or along a wall in RC (Video 10 0:40.6-42.6 is a jump off the wall's top back into the arena).
  - **Round 13, after the re-playtest** (2026-10-28, session 37, AskUserQuestion, all recommended): Q29 **steering is
    skater-relative**: W pushes forward along the way the skater faces, S brakes, A/D steer left/right, and the mouse
    orbits the camera 360 deg and never steers (ours: camera-relative keys, so swinging the camera turned the
    skater); not chosen: camera-relative keys with a freer camera. Q30 **the stride's top speed drops to 55 km/h**,
    like RC's 50-57 (cruiseSpeed 60 -> ~46 studs/s; slopes, pumps and dives still go faster, softCap/hardCap
    unchanged; every measured number re-measured); not chosen: keep 72, lower more. Q31 **RC's magnet pickup comes in
    the Ball & rules part** (measure RC's pull radius and time there); not chosen: now. Still to study before asking:
    RC's jump on/into a wall (Videos 10-11), RC's camera distance, roll on walls and field of view with speed.
  - **Video 14 and the map request** (2026-10-28, session 37, answering my request for an RC clip of five wall and
    camera cases): Video 14 `D:\Screenshots\Videos\Screen Recording 2026-10-28 223430.mp4` (RC). The owner's words:
    "take a thorough look, I think at the end of the video in step 5, I think the camera have some influence to the
    player movement, anyways check it out, also it is not possible to spam jump, so we shouldn't have it, a player can
    only jump once in the air unless he touches ground/wall again, also I want to do some adjustments to the map, look
    at this screenshots: at the curved ends, look at how there is like a steep heel, more than ours, I want to have
    that, I want to have exactly the map structure of RC, and at the straight ends, look more at the bump, it is more
    up, and more steep than ours, and there is no complete straight floor in the bump, take a thorough look, for the
    videos, have it more than 1 frame per second, so you can get more details". Four screenshots (RC 'Mexico Arena',
    attached to the message, not saved as files): at the curved ends the wooden track floor is banked up toward the
    outer wall all the way from the infield's edge (a bowl), the infield a raised red platform with a checkered rim;
    on the straights the floor rises to the outer wall in one sweep. The owner's rule for the study: more than 1
    frame a second on every video.
  - **Video 14 studied** (session 38; RC 'Mexico Arena', 2:34, 1914x1078, 30 fps): the hint column and speed
    readout at 5 frames a second over the whole video (`claude-handoffs\s38\v14\hints5`), 10 frames a second at
    3.9-7.5, 55.2-57.6 and 146-153.5 s, 4 a second at 79.4-81.4 and 143-151 s, full frames for the map. The owner's
    four RC screenshots are saved: `D:\Screenshots\Photos\Screenshot 2026-10-28 222934.png`, `...222948.png`,
    `...223446.png`, `...223502.png` (all at a curved end). Seen:
    - **Jump while riding up the wall** (4.0-7.4): up the outer wall's red foot onto the glass, 43 -> 33 km/h; Jump
      at ~4.6: Air Pose offered (airborne) and the skater rose straight up ALONG the glass (vertical trail, readout
      held at 33) for ~1.0 s; Pump/Brake/Jump back at 5.6-5.8 (on the glass again); a second Jump at 5.9 (the
      press marker on Jump): airborne 6.2-7.0, readout 44 -> 59 -> 77 -> 91, down onto the wall's foot at 7.2 (37,
      then 28 km/h). The first jump did not push them away from the glass.
    - **From the floor, a jump straight at the wall** (55.2-57.6): at 59-60 km/h toward the outer wall; at the wall
      the readout fell 59 -> 27 -> 17 -> 13 (55.8-56.1, the speed into it lost), then held 18 while the skater went
      up the glass (vertical trail) with Air Pose offered the whole ~1.2 s (still in the air, not landed), and came
      back onto it at 57.4 (23 -> 40 -> 52 -> 62 km/h on the way down).
    - **Uppercut at the top of the wall's foot** (1:19.75, press marker on Uppercut, 4 km/h): straight up along the
      glass ~1.2 s, the readout 3 the whole flight, Air Pose offered, back onto the wall at 1:21.4-1:21.6 (47 km/h),
      104 by 1:22.4.
    - **Repeated jumps riding the wall** (16-24 s): every jump was followed by 0.6-1.2 s in the air (Air Pose
      offered) and a touch (Jump lit again) before the next; Jump was never offered in the air anywhere in the
      video, and Uppercut was greyed in the air (as in Videos 10-11).
    - **Riding up a high wall without the mouse** (4.0-5.8): the view rolled with the wall (by eye roughly 30-45 deg,
      looking down the glass from above); not measured.
    - **Step 5, the camera swung round** (2:26-2:33.4): the readout 51 -> 0 (2:27.6-2:28.6; the Brake hint reads
      'Tiptoe' when slow), 0 -> 31 (2:28.7-2:29.8), 31 -> 0 (2:30.0-2:30.6), 0 -> 14 (2:30.8-2:31.6, an S-shaped
      trail), 14 -> 0 (2:32.0-2:32.6), 0 -> 7 (2:32.8-2:33.4). The keys held cannot be read from the video; with W
      alone held, steering by the skater's facing (Q29) would not have stopped the skater three times.
    - Hints with the ball: Charge Throw, Pump, Brake, Jump, Magnetic Pass, Dodge, Roll Ball; while charging: Throw,
      Cancel & Dodge, Roll Ball (1:41.0, 1:59.0). Speeds: striding on the flat 45-58 km/h; after pumps and slopes
      100-130 (130 at 1:33.2).
    - **The map (Mexico Arena)**, from the four screenshots and frames 0:01, 0:03, 0:17, 0:45, 1:02, 1:13: at a
      curved end the middle is a broad raised red island (black rim, checkered edge, the goal's frame on it); the
      wooden floor around it rises from the island's edge all the way to the outer wall with no flat lane, steeper
      toward the wall (a bowl). On the straights the views show, across the track, a red bank with chevrons, the
      wooden floor, a chevron-painted ramp, a grey lane with white stripes and the red foot of the outer wall under
      the ad boards; their order and heights could not be fixed from these perspective views (no view straight
      across a straight).
  - **Round 14, after Video 14** (2026-10-28, session 38, AskUserQuestion): asked which keys were held at 2:26-2:33
    (step 5), the owner: "I think I clicked other keys, not sure, but I think the camera can't affect the movement
    when the player at high speed, but it is like slows him down if the camera in the ooposite of the player
    direction, I recorded another video, this time only clicking W, check it": **Video 15** `D:\Screenshots\Videos\
    Screen Recording 2026-10-28 231627.mp4` (RC, W only, the camera swung). Q32 **the jump on and into walls: RC's way**
    (recommended): on a wall (steeper than 30 deg) Jump goes straight up along it, like the Uppercut; a skater still
    rising who meets a wall slides up it in the air and only lands on it (getting Jump back) once falling; floors and
    gentle banks keep today's jump. Not chosen: fix the direction only; keep ours (straight off the wall). Asked for a
    cross-section clip of Mexico Arena (straight and curved end, looked at and crossed at a right angle), the owner:
    "I recorded a video before this, if it is not enough, tell me to record again".
  - **Video 15 studied** (session 38; RC 'Venice Beach Park', 0:32, 1918x1078, 30 fps; the owner held only W and
    swung the camera): the hint column and readout at 5 frames a second over the whole clip, 4 a second overview, 10 a
    second at 15.1-17.4 and 28.6-31.5 s, larger crops at 29.0-31.2 (`claude-handoffs\s38\v15`). Seen:
    - Striding with the camera behind: 53-55 km/h (0-2.4 s); later on a straight 42-48 (17.8-21.0).
    - **W follows the camera, slowly at speed:** at 16.6-17.4 the camera stayed on the curved end's island while the
      skater, W only, at 55-67 km/h, came down off the outer bank and circled the island's rim, crossing the screen
      sideways: they curved toward where the camera looked instead of going straight up the bank.
    - **Against the motion it brakes, then turns:** 29.2-30.8, after a landing at 9-13 km/h the camera swung to look
      down the straight while the skater moved the other way: 13 -> 10 -> 7 -> 3 -> 1 km/h in 0.5 s (~30 km/h per s),
      1-4 km/h for 0.9 s while they turned round to face into the screen (their back to the camera at 30.0), then
      4 -> 16 km/h in 0.3 s and 22 by 31.5, skating the way the camera looked. Read with Video 14 2:27-2:33 (51 -> 0
      in ~1 s, 31 -> 0 in 0.6 s, 14 -> 0, each time back up again, an S-shaped trail): a stick held against the motion
      brakes the skater to a stop, then they skate off the stick's way. The owner's words fit it: "the camera can't
      affect the movement when the player at high speed, but it is like slows him down if the camera in the opposite
      of the player direction". Not measured: RC's turn rate at each speed.
    - Skating off ledges drops the skater into lower lanes (Air Pose offered in the air, 3.2-4.0, 9.8-10.2, 21.2-21.8,
      25.8-26.0 s); each touchdown loses the speed into the floor (45 -> 22, 57 -> 25, 42 -> 17, 55 -> 22 km/h), then the
      slope below speeds them up (to 107-115). A drop at 29.0 greyed every hint but Ball Focus for ~0.1-0.2 s (73 -> 7
      km/h), no Get Up prompt.
    - RC's own loading tip (Video 2, 3:36): "the Follow Camera option makes the camera turn to follow your skater":
      by default RC's camera does not swing back behind the skater.
  - **Round 14, after Video 15** (2026-10-28, session 38, AskUserQuestion): Q33 **steering: RC's way** (recommended;
    REPLACES Q29): the keys push the way the camera looks, as before, with weight: holding a key against the motion
    brakes the skater to a near stop, then they turn round and skate off that way; at speed they turn gently toward
    it; the mouse orbits the camera freely (RC: Video 15 16.6-17.4 and 29.2-30.8, Video 14 2:27-2:33; ours: a key held
    against the motion carved a U-turn at full speed, half a turn in ~1.1 s at 72 km/h). Not measured yet: RC's turn
    rate at each speed. Not chosen: keep Q29 (W along the facing); keep today's. Asked for a Mexico Arena
    cross-section clip, the owner recorded **Video 16** `D:\Screenshots\Videos\Screen Recording 2026-10-28
    235206.mp4` ("take a thorough look").
  - **Video 16 studied** (session 38; 1:15, 1918x1078, 30 fps; recorded for the cross-sections, but the match was on
    **Pixel City**, not Mexico Arena): 2 frames a second over the whole clip and full frames at 1.0, 5.5, 8.0, 41.5,
    44.0 and 47.5 s (`claude-handoffs\s38\v16`). A straight seen across from a stop (0-12 s): flat lanes (grey,
    purple, a checkered strip) up to the green band rising to the middle's rim; crossing slowly (12-17 s, 3 -> 47
    km/h) the skater rode up that green band. A curved end (34-48 s): a purple bowl, flat by the low grey oval island,
    then curving up into the outer wall in one wide sweep with a white rim under the crowd; riding up it at 52.5-53.5
    and 58.5-59.0 s the camera looked straight at the crowd. No view gives heights or angles in numbers (no known
    size beside the surfaces but the skater). Mexico's shape (the owner's screenshots) still comes only from Video 14
    and Video 3 frames.
  - **Q34, while building #266** (2026-10-29, session 38, AskUserQuestion, recommended): **turn rates halved**:
    `turnRateLow` 4.0 -> 2.0 and `turnRateHigh` 1.5 -> 0.75 rad/s, so at the 55 km/h stride ~1.5 rad/s (90 deg in ~1 s,
    a circle ~60 studs across). RC judged by eye only (Video 15 16.6-17.4: ~1.3 rad/s at 55-67 km/h, a circle ~75
    across); ours was 3.0 rad/s at 55 km/h. Not chosen: two-thirds (3.0 -> 1.0); keep today's.
  - **#268 mock-ups shown** (2026-10-29, session 39; private page https://claude.ai/artifact/NSwD1bUEe3GiVBMPLpsrgT):
    candidates built in Studio from the real arena code with only `Profile.points` swapped, four camera views each
    beside the owner's four screenshots and Video 14 frames (0:01, 0:03, 0:17, 0:45, 1:02, 1:13), floor tinted by slope:
    today (ends flat 46; step 4 x 18, 19 deg, 8 flat on top); **A** bowl rising 10 (y = 10 s^2, 2.5 up halfway, 21 deg
    at the wall's foot), bump 8 over 16 (38 deg, no flat top); **B** bowl 14 (3.5 halfway, 27 deg), bump 10 over 18
    (41 deg); **C** bowl 8 (y = 8 s^1.5, 2.8 halfway, 13 deg), bump 6 over 14 (34 deg). The goal ring at gate 2 rises
    with the floor under it (today's clearance kept: A 24.8, B 27.5, C 23.0, was 18); the outer wall's upright part
    starts higher (wall top A 34, B 38, C 32, was 28); the straights' flat lower floor widens (28-32, was 20). Asked
    (recommended B for both, by eye; RC not measured). The owner did not pick yet: they recorded **Video 17**
    `D:\Screenshots\Videos\Screen Recording 2026-10-29 092147.mp4` (Mexico Arena cross-sections, on my request) and,
    for the straights: "check video first then ask me again with screenshots".
  - **Two camera requests** (same answer, 2026-10-29), the owner's words: "see how the camera gets close to the player
    and the fades him out, when I move the mouse up, and go back to till the top of the player when I move mouse down,
    check this video: **Video 18** `D:\Screenshots\Videos\Screen Recording 2026-10-29 092319.mp4`, I want to do that,
    and also do one more thing for the camera, lower its sensitivity, today I can do 360 around the player in a small
    movement of the mouse to the right or left, but in RC, I can't do it easily, I need to do more drag movement to do
    a 360, check the same video at the end". To study, then a grilling round and tickets.
  - **Video 17 studied** (session 39; RC 'Mexico Arena', 1:43, 1918x1078, 30 fps; recorded for the cross-sections):
    2 frames a second over the whole clip, 4 a second at 18-25 s, full frames at 7, 16, 19, 21-23, 29, 39, 47, 55-69 s
    (`claude-handoffs\s39\v17`). **A straight's bump is a ridge**: from the inner side, a red bank with white chevrons
    and a grey dotted lane, the wooden floor (gate numbers painted), then a wooden band with black chevrons that rises
    and falls straight back down (no flat top) to a **flat grey striped lane** running to the outer wall's red foot
    (0:07 seen from the floor side, rising to the right; 0:16-0:19 the skater stopped on the grey lane at its foot, the
    band rising to the left; 0:21-0:24 crossing it toward the wall the readout fell 24 -> 10 km/h at its top, then 12,
    15, 18, 22, 27, 30 on the far side and up the red wall). **A curved end is one bowl**: the low red island (flat,
    rideable: the skater stood on it at 1:11-1:12) with a black rim, then wood rising from the rim all the way to the
    wall, gentle by the island and steep by the wall (0:55, 0:59 stopped on it at 0 km/h, 1:04, 1:08.5). No height or
    angle can be read in numbers (no known size but the skater). Round 1's straights (a bump rising into the wall) did
    not match, so round 2 built three ridges, bowl B at the ends: **RA** 5 high over 20 (38 deg), **RB** 6 over 20
    (43 deg), both with a flat floor 16 before (u 16-32) and a flat lane 10 after (u 52-62); **RC** 8 over 24 (46 deg),
    floor 12, lane 10. With a ridge the goal ring at gate 2 rises only with the bowl (bowl B: 22.6, was 18). Page
    updated (round 2, same link).
  - **Video 18 studied, first pass** (session 39; RC Mexico, 0:22, 1918x1078, 30 fps; the owner's camera clip): 5 frames
    a second. Standing still: mouse up (2.0-2.8 s) the camera drops toward the floor and closes in on the skater, who
    turns see-through and vanishes (2.6-6.6 s, the view looking up at the roof from the skater's feet); mouse down
    (9-15 s) the camera rises until it looks down on the skater from above; then a slow orbit (16-21.6 s). Ours (code):
    pitch -70..60 deg at a fixed 12 studs, pulled in only in front of a surface, the skater never fades.
  - **Round 15** (2026-10-29, session 39, AskUserQuestion): the ridge (RB recommended) and the bowl (B recommended):
    the owner: "I couldn't determine, I can have a decision if I play those options" (both): **they play the options
    in Studio before picking**. **Q35 mouse sensitivity: half** (recommended): 0.25 deg per pixel across (1,440 px per
    full turn, was 720) and half today's up/down; RC's value not measurable from video. Not chosen: a third (2,160 px);
    two thirds (1,080 px).
  - **#268 trials in Studio** (2026-10-29, session 39; each patched into Studio's copies of `Profile` and
    `Config.Arena` only, restored after, the owner playing): **Trial 1** ridge RB + bowl B. The owner: "no, it
    shouldn't be like this, it shouldn't be a just bump like that, it should be like the state it was before, but just
    the straight floor, we raise it up, and have it over 24 or like more into 30, and have all the bump a little steep,
    no actual straight floor in the bump, and not to steep, because we still want the player to be able to skate in it
    in the middle, but if he can't just stand still on it, he will drop from it", with two RC Mexico screenshots (on a
    straight: the inner red bank, the wood, the chevron band and the grey lane all one surface rising toward the wall).
    **Trial 2** one incline instead of the step and its flat top: flat floor u 16-32, then y = 10 s^1.5 rising into the
    wall's foot curve at its arrival angle (~15 deg on average, 22 at its top, no flat part), bowl B. The owner: "rise
    it, and move the spawn positions a little closer to the middle wall, so we get more width of the bumps". **Trial 3**
    flat floor u 16-26 (spawns 5 studs nearer the middle glass: lane u 21, was 26), incline y = 14 s^1.5 (~18 deg on
    average, 26 at its top), goal ring at 27.9 (today's clearance), bowl B. The owner: "raise the bump, also currently
    the player can't get close to the wall at low speed at all, unlike RC, look at this vide, I am just clicking W, I am
    able to get close and ride the walls a little" (**Video 20** `D:\Screenshots\Videos\Screen Recording 2026-10-29
    104308.mp4`, RC Pinball Stadium, 0:37), "and another thing, currently the players turns is so hard, unlike RC,
    here is a video, that I keps turning around with the W,A,S,D keys, I am in a circle, unlike our game today, it needs
    to get to 0 km to stop and turn" (**Video 19** `D:\Screenshots\Videos\Screen Recording 2026-10-29 103956.mp4`,
    RC Pinball Stadium, 0:26), "and if you want look also at the bumps in the straight and curved ends".
  - **Video 19 studied** (session 39; RC 'Pinball Stadium', 0:26, 1918x1078, 30 fps; the owner turning with W, A, S,
    D in turn): 2 frames a second over the clip, 10 a second at 1.5-7.5 s (`claude-handoffs\s39\v19`). The skater
    circles continuously at 14-45 km/h (never below 2 after the start), loops about 1-2 skater-heights across by the
    trails (by eye, not measured). Ours, simulated (`claude-handoffs\s39\turn_sim.py`, SkateMath's steering, stride
    and friction on the flat, keys every 0.4/0.6/0.8 s from 30 km/h): today's rates (Q34: 2.0 / 0.75) drop to 0 km/h
    (0.4-1.0 s of every 6 below 5 km/h); the pre-Q34 rates (4.0 / 1.5) circle at 12-44 km/h with keys every 0.4 s and
    55 with slower keys.
  - **Video 20 studied** (session 39; RC 'Pinball Stadium', 0:37, 1918x1078, 30 fps; the owner holding only W): 2
    frames a second over the clip, 5 a second at 3-12 s and 31.5-36.5 s (`claude-handoffs\s39\v20`). From a stop
    facing a curved end's wooden bank (3.0 s): 0 -> 11 -> 18 -> 25 km/h on the flat (3.4-4.2 s), then up the bank 23
    -> 21 -> 17 -> 13 -> 9 -> 4 (4.4-5.6 s), then a crawl up the bank's upper band at 1-5 km/h for 4+ s (5.6-10.0 s;
    the hint still reads Brake, not Tiptoe: no brake held). From 61 km/h straight at the outer wall (31.4 s): 61 -> 54
    -> 46 -> 37 -> 27 -> 15 -> 3 up the wall in 1.6 s (high, by the crowd's sign), then back down 14 -> 27 -> 39 -> 40.
    Pinball's curved end: a green island with a white rim, a wooden bowl up to a green band, then a grey ramp higher
    up. Ours, simulated on trial 3's incline (`climb_sim.py`): the stride (30 studs/s^2) beats gravity only on slopes
    under 8.8 deg (asin(30/196.2)); holding W from a stop gets 3.3 studs up, from 20 km/h 4.5, from 55 km/h 9.9, never
    the wall's foot (14.7); with a 4 km/h crawl floor every start reaches it.
  - **Round 16** (2026-10-29, session 39, AskUserQuestion, all recommended): **Q36 the straights' incline rises 18**
    (from u 26, y = 18 s^1.3, ~22 deg on average, 28 at its top: the highest that stays under the 30 deg wall angle),
    "but let me playtest it first" (trial 4). **Q37 turn rates back to the pre-Q34 values** (turnRateLow 4.0,
    turnRateHigh 1.5; ~3.5 rad/s at 30 km/h); a key held straight back still brakes first (Video 15); REPLACES Q34.
    Not chosen: faster (5.0 / 2.0); no braking at all. **Q38 slow climbs: crawl up like RC**: holding the stick up a
    floor slope (under wallAngle) never lets the speed fall below ~4 km/h, so a skater creeps to the wall's foot; walls
    still slide them back. Not chosen: full stride uphill (to 55 km/h); keep today's. **Q39 the camera RC's way**
    (Video 18): looking up, the camera slides in toward the skater's feet and the skater fades out up close; looking
    down, it rises above them; distances measured from Video 18 and shown to the owner before shipping. Not chosen:
    only the fade; later (Presentation). With Q35 (mouse sensitivity halved) these make new tickets.
  - **Trial 4** (2026-10-29, session 39; Studio copies only: incline y = 18 s^1.3 from u 26, ~22 deg on average, 28
    at its top; goal ring 29.7 and its arm 51.7; spawns lane u 21; bowl B; turn rates 4.0 / 1.5 and a 4 km/h crawl
    up floor slopes as prototypes of Q37/Q38). The owner: "no I still don't like the straights, the curved ends I
    think they are fine, and I still don't like how the players can't get even close to wall, look at this video I
    recorded in RC" (**Video 21** `D:\Screenshots\Videos\Screen Recording 2026-10-29 113421.mp4`), "look at the
    straights and in the middle wall, it is in a different arena with green colors, it might help you better visualize
    the bumps and straights, it starts a little smooth curved, not real steep near the outer wall, then there is a bump
    that is curved, then goes into a steep ground, then small straight room where the spawns are, then starts to curve
    out to the middle wall, the curve next to the middle wall in RC have more width than ours today, and look at how the
    player can climb the walls and ride them a little". So the curved ends' bowl B is accepted.
  - **Video 21 studied** (session 39; RC 'Lost Civilisation', 1:21, 1912x1068, 30 fps; the owner's straights and
    middle wall): 2 frames a second over the clip, full frames at 10, 11.5, 26.8-28.6, 33.4, 34 s (`claude-handoffs\
    s39\v21`). Across a straight from the middle: a perforated grey rim and a checkered strip curving up into the
    middle glass, a mint band (gate numbers painted, white edges) sloping up and over, a green field, then a dark
    asphalt lane with white dashes curving up into the outer wall (28.6-29.5: 30 -> 22 -> 17 km/h up the outer wall,
    riding it a little). Heights not measurable. The owner's order (from the outer wall in): a gentle curve by the wall,
    a rounded bump, steep ground down from it, a small flat room for the spawns, then a curve up to the middle wall
    wider than ours. **Video 20 re-read for wall gravity** (5 frames a second, 31.8-33.0 s, straight up Pinball's outer
    wall): 59 -> 54 -> 46 -> 37 -> 27 -> 15 -> 3 km/h, at most 60 km/h per second (~50 studs/s^2 at speedometerScale
    1.2) on the steepest part; ours on an upright wall 196.2 studs/s^2 = 235 km/h per second (Q25), ~4x.
  - **Round 17** (2026-10-29, session 39, AskUserQuestion, recommended): **Q40 walls and glass (steeper than
    wallAngle) pull at a quarter of gravity** (~60 km/h per s on an upright wall, RC's measured rate); floors and the
    air keep full gravity. REVERSES Q25 (the no-input loop that drove Q25 was the filter-lag bug, fixed in #255).
    Computed on an upright wall: from 30 km/h ~6 studs up (was ~1.6), from 61 km/h ~26 (was ~7). Not chosen: a third;
    keep full. **Trial 5's straight approved as drawn** (ASCII preview; first-guess numbers to play): a wider inner
    bank (an ellipse quarter 24 wide, 16 high), a flat spawn room u 24-30, steep ground up to a rounded crest 8 high at
    u 46, a gentle descent to a valley 5 high at u 54, then a gentle foot curve r 26 up into the outer wall; the curved
    ends keep bowl B (accepted after trial 4).
  - **Trial 5** (2026-10-29, session 39; Studio copies only: the drawn straight with a valley 5 high at u 54, bowl B,
    turn rates 4.0 / 1.5, the crawl, walls at a quarter of gravity). The owner: "why there is a gap in the bump near
    the outer wall I think you are calling in gentle valley, that shoudln't be like that, it should be just a continious
    floor, and about the wall riding, the infinite wall riding issue came back, look at" (**Video 22**, ours,
    `D:\Screenshots\Videos\Screen Recording 2026-10-29 115102.mp4`, 0:50), "why is this taking so long to mimic RC
    core match & mechanic & map, what is the issue". Video 22 at 2 frames a second: the skater rides along the outer
    glass for 2-9 s and 17-46 s at 40-100 km/h, the speed holding or rising. Cause (computed): with a quarter gravity
    a level line along upright glass needs only g/4 / wallTurnRate = 49 studs/s (59 km/h; was 196 at full gravity),
    and pumping still works on walls (pumpSlopeMultiplier 1.6 adds energy riding down the glass), so a rider steers
    level and pumps forever. RC: a 90 km/h rider held a line ~2 s (Video 3 21:09), a 104 km/h entry stayed high ~6 s
    (14:25).
  - **Round 18** (2026-10-29, session 39, AskUserQuestion; told first, plainly, why it is slow: no RC numbers exist,
    every shape and constant comes from perspective video and an integer speedometer, I misread the drawings several
    times, and I changed wall gravity without its partner rule): asked how to end the endless wall rides (recommended:
    no pump on walls + half steering, 0.5 rad/s, a level line then needing 118 km/h). The owner: **"well if they are
    pumping while thery getting down they should get speed" (Q41: pumping keeps working on walls)**; the steering half
    goes into trial 6 as the prototype. **Trial 6's straight approved as drawn** (continuous, no dip): the 24-wide inner
    bank, a flat spawn room u 24-30, steep ground up (a Hermite S from slope 0 to tan 14 deg, steepest ~39 deg) to 8
    high at u 44, a gentle 14 deg incline to (63.3, 12.8), a foot arc r 22 from 14 deg to upright at u 80 (top 34.1).
  - **#268 PICKED: trial 6** (2026-10-29, session 39, the owner played it: "Keep it"). Straights (u from the inner
    glass's face, y above the lower floor; trackWidth 80): the inner bank an ellipse quarter 24 wide, 16 high (was a
    circle r 16); a flat spawn room u 24-30 (spawn lane u 27); a Hermite rise from (30, 0) flat to (44, 8) arriving at
    tan 14 deg (steepest ~39 deg); a straight 14 deg incline from (44, 8) to (63.3, 12.8); a foot arc r 22 from 14 deg
    to upright at u 80 (top 34.1); the wall up to 40, then the glass. Curved ends: the bank a circle r 16, then bowl B
    y = 14 s^2 from the bank's foot to the foot arc r 18 that starts at the bowl's arrival angle (27.3 deg), split at
    the straight's breaks; the two blended point by point by the corners' stepBlend (strip counts 4/2/5/3/5/1). The
    goal ring at gate 2 rises with the floor under it (centre 28.9, arm 50.9: today's clearance kept). Played with the
    prototypes of Q37 (turn rates 4.0 / 1.5), Q38 (a 4 km/h crawl up floor slopes), Q40 (walls at a quarter of
    gravity) with Q41 (pumping on walls kept) and wallTurnRate 1 -> 0.5 (a level line along upright glass then needs
    g/4 / 0.5 = 98 studs/s, 118 km/h): these become their own tickets, with Q35 (mouse sensitivity) and Q39 (camera).
  - **Tickets approved** (2026-10-29, session 39): five from today's answers (turn rates Q37; the crawl Q38; walls a
    quarter of gravity Q40 + pump kept Q41 + wall steering 0.5; mouse sensitivity Q35; the camera Q39), and the owner
    added two: **Q42 a magnetic tackle**: "when trying to tackle someone, it should be like a magnetic tackle, like what
    a player pres tackle with a direction, and in that direction a player coming up, he should tackle him, not only when
    passing through him"; **Q43 the Air Pose adds no forward motion**: "air posing shouldn't take player forward, if he
    jumps standing still and air pose, he shouldn't go forward, that is depending on his movement, if he is going
    forward and jump and air posing then naturally he is going forward" (today Q14's posed fall pulls along a line
    20 deg below the facing, so a standing jump's pose drifts forward). RC's tackle reach and homing to be measured
    from the videos before coding.
  - **#268 built, measured, and the owner's answer** (2026-10-29, session 40): trial 6 built test-first (no turn,
    crawl or wall-gravity prototypes; today's rules). Measured in Play, nothing pressed, from the spawn room straight
    at the outer wall: swings rock in the dip between the bank and the rise (from 72 km/h 3 round trips, stopped at
    9.0 s; old map 2 trips, 7.6 s; 108: 4 trips, 11.6 s; 145: 14.1 s); crest hops (108: two ~0.1 s; 145: 0.3 s from
    the rise's top to the wall's foot; inward at 73-94: 0.1-0.2 s); combos (108: the Uppercut from the wider foot
    curve flies up beside the glass to 53.5 and drops back to 25, old map caught at 56.1; 145: caught at 62.4; with
    the Air Pose 57.7 / 67.0); a lap along the spawn lane 15.0 s. Asked (recommended: keep, judge at the playtest).
    The owner: **"player currently can can't even go up into the outer wall from the middle straight: check this"**
    (**Video 23** `D:\Screenshots\Videos\Screen Recording 2026-10-29 131734.mp4`), **"I don't know, I feel that we
    are not getting RC gameplay too much, why is it being hard, maybe gravity is too much or something? but then wall
    riding becomes easy again, can't you jsut take a thorough look at all RC videos and notes, don't measure with
    their speedometer or ours, I think it is just confusing us"** (Q44). To do: study Video 23 and every RC video
    again by eye and by time (frames, body sizes), not by any speedometer.
  - **Gravity by time and body size** (2026-10-29, session 40, the owner's Q44 request: no speedometer). Our skater
    (the owner's avatar in Play) is 5.85 studs tall, so our gravity 196.2 studs/s^2 is 33.5 body heights/s^2. RC:
    **Video 20** 32.5-33.7 s at 10 frames a second: straight up Pinball's upright outer wall from its bottom stripe
    (32.6 s) to the crowd level (~33.15 s), 3.3 body heights (read on the wall, roughly square to the camera), back at
    the stripe ~33.65 s: up 0.55 s, down 0.5 s (a wall pulls the same going up as coming down: no lighter wall
    gravity) -> about 22 body heights/s^2. **Video 5** standing jumps: in the air 0.60-0.73 s (ours 0.61 s, 9.2 studs).
    **Video 14** 1:19.8-1:21.3: an Uppercut up the glass ~1.5 s in the air (ours 1.12 s, 31 studs). At 2/3 of our
    gravity with our jump and Uppercut heights kept, they would hang 0.75 s and 1.37 s and the wall climb fits: all
    three point to RC's gravity at about 2/3 of ours (range 0.5-0.9 from the eye-read heights). **Video 21** 28.4-29.6
    s (up a curved slope, not upright): up ~0.6 s, down ~0.5 s. **Video 23** (ours, trial 6, 0:19): in the straight's
    spawn room the skater pushes toward the outer wall at 0-26 km/h and turns back every time: at the stride's top
    speed our gravity carries ~5.4 studs uphill, the rise is 8 high and its steep middle (~39 deg) is past wallAngle
    30, where the skates only roll. Q40's quarter (#274) came from RC's readout, which does not show the full speed on
    walls. **Q45** (AskUserQuestion, recommended): **build trial 7**: gravity 2/3 everywhere, walls the same as floors
    (drops Q40's quarter), jump / Uppercut / Air Pose keep today's heights (hang 0.75 / 1.37 s), wall steering as
    today (a level line along upright glass would need g / wallTurnRate = 131 studs/s, past hardCap 121), the crawl
    up slopes on the rise's steep middle too. Not measured: RC's ball gravity (the ball changes with it; judged in
    Ball & rules). Not chosen: measure more clips first; something else.
  - **Trial 7 kept** (2026-10-29, session 40, Q46; the owner played it: "Keep it"). Studio copies + the place's
    gravity only: workspace.Gravity 130.8 (2/3), walls the same as floors; jumpImpulse 48.99, airPoseImpulse 34.29,
    the Uppercut's leapImpulse 89.82 (x sqrt(2/3): today's heights, hang 0.75 / 1.37 s); turn rates 4.0 / 1.5 (Q37);
    wallTurnRate 1; a 4 km/h crawl up any slope gentler than 45 deg while the stick points up it (the rise's 39 deg
    middle too). Checked before: from a standstill in the spawn room, the stick toward the outer wall crawled over the
    rise and up the incline (u 27 -> 54 in 8 s). Q40's quarter (#274) is dropped; tickets follow (gravity + heights
    new; #273's crawl to 45 deg).
  - **Video 18 measured for #276** (2026-10-29, session 41; 10 frames a second at 1.8-5.2 s, 5 a second at 6-16 s, 12
    key frames with a 10% grid, `claude-handoffs\s41\v18`): the skater's height on screen, head to skates, as a share of
    the frame's: 0.58 at 1.8 s (view slightly down), 0.60 at 2.2 s; at 2.4-2.5 s the camera is near the skater's level
    and the skates leave the frame; the skater fades from 2.6 s (a ghost to 3.0 s) and is gone by 3.1 s, the view then
    looking up at the roof; fading back in 6.6-7.4 s; 0.49 at 9.4 s; looking down 0.30 at 10.0 s, 0.20 at 11.0 s, 0.12 at
    12.0 s (from above), almost straight down by 13.4 s. The skater's head stays near the screen's middle (0.3-0.55).
    RC's field of view is not measurable, so distances are relative: at our 70 deg they read ~1.2 body heights at
    1.8 s, ~1.5 at 9.4 s, ~2.4 at 10.0 s, ~3.6 at 11.0 s (steep views foreshorten the body); ours is 2.05 body heights
    (12 studs) at every pitch. Pitches judged by eye only (~-10 to +35 deg up, to ~-80 down).
  - **Q47, the camera's trial** (2026-10-29, session 41, AskUserQuestion with an ASCII side view, recommended): **build
    trial A as drawn**: RC as measured, the body's foreshortening taken out and our 70 deg field of view assumed: ~8
    studs out looking slightly down (today 12), ~6 level, farther looking down (13 at 20 deg down, 17 at 35, 20 at 55),
    and looking up closing in to the skater's feet (3 out at 15 deg up, fading; at the feet by 30, the skater gone).
    Coupled, said first: the view still widens with speed (70 -> 90 deg) and the camera still stops in front of walls
    and the floor. Not chosen: trial B (the same shape scaled to keep 12 at the slightly-down view); only the fade and
    the close-in looking up.
  - **Trial A played; Q48 and Q49** (2026-10-29, session 42). Trial A in Studio (Studio's CameraController copy only:
    pitch -> distance, focus height above the root: -55 20 3, -35 17 3, -20 13 3, -10 8 3, 0 6 3, +15 3 0.5, +30 1
    -1.5, linear between; the skater fading from 4 studs out to gone at 1.5). The owner: "just bring the camera back a
    little, too close to the player, for example if he hold the balls and try to aim to shoot, the camera is almost
    attached to the player, it is not like that in RC, and what about camera sensitivity? did we do it and not yet?
    because I still feel the camera sensitivity is too fast". Told: #275 already halved it (1,440 px a full turn, their
    Roblox setting 1). **Q48** (AskUserQuestion with ASCII side views, recommended): **trial A2, 1.5x back**: slightly
    down 12 (today's), level 10, 15 deg up 8, 30 up 4 and starting to fade, at the feet and gone by 45 up; looking
    down 14 at 20 deg, 17 at 35, 20 at 55. Aiming at the ring (~29 up) from 60 studs away is ~24 deg up, from 30 ~41.
    Not chosen: 1.25x back; today's 12 with the close-in only past 30 up. **Q49** (not the recommended third): **the
    mouse at a quarter of Roblox's scale**: 0.125 deg per pixel, 2,880 px a full turn (twice slower than #275's half),
    up/down by the same share. Not chosen: a third (2,160 px); keep the half.
  - **Trial A2 played; Q50-Q52** (2026-10-29, session 42). Trial A2 (pitch -> distance, focus height: -55 20 3, -35
    17 3, -20 14 3, -10 12 3, 0 10 3, +15 8 3, +30 4 0.5, +45 1 -1.5) with the mouse at a quarter (2,880 px a turn).
    The owner: "increase the FOV again, still feels close, even the crosshair dot is like on top of the player's head,
    and also still decrease the camera sensitivity by a little bit more". Asked (AskUserQuestion, recommended first):
    **Q50** the field of view: "didn't mean FOV then, just mmeant to bring the camera back again from the player a
    little more" (the view stays 70 -> 90 deg). **Q51** the crosshair dot (it marks the screen's centre, where the
    camera's focus is; A2's focus was the head's top): "well first, it shouldn't be visible when the player don't have
    a ball, but if it is going to help us for now, use your recommendation" (the focus 1.5 studs above the head, 5
    above the hips; the dot hidden unless carrying becomes its own ticket). **Q52** the mouse: 3,600 px a full turn
    (0.1 deg per pixel, up/down by the same share). Trial A3 built from these: about 1.2x A2's distances (level 12,
    the old camera's), focus 5 above the hips.
  - **Trial A3 kept** (2026-10-29, session 42, Q53; the owner played it: "Keep A3"). Studio copies only: pitch ->
    distance, focus height above the hips (the root, 2.5 above the floor): -55 22 5, -35 19 5, -20 16 5, -10 14 5, 0
    12 5, +15 10 5, +30 5 1.5, +45 1 -1.5, linear between, held past the ends (pitch limits -70 / +60); a negative
    height reaches down toward the feet and the floor stops it as walls stop the camera; the local skater fades as the
    camera comes within 4 studs of the focus, gone at 1.5 (this client only). Measured in Play: level 12 back, 5 up;
    +15 deg 9.7 back; +24 6.6; +30 4.4; fading from ~33 deg up, gone by ~44 at the feet; -10 13.8 back 7.4 up, -20 15.0
    / 10.3, -35 15.6 / 15.7, -55 12.7 / 22.9. Mouse 0.1 deg per pixel across, 0.077 up/down (3,600 px a full turn).
    The field of view stays 70 -> 90 deg. Tickets: #276 builds the camera; #275's PR takes the mouse; the dot shown
    only while carrying the ball is a new ticket (Q51).
  - **#276 approved; Q54 and Q55** (2026-10-29, session 42). The built camera (real code, not the trial) on a
    private page beside Video 18 (https://claude.ai/artifact/SPSUaNggfDYCmEG4fzFhcT: RC 1.8 / 2.5 / 2.6 / 2.8 / 3.5 /
    10.0 / 12.0 s beside ours at 10 down, level, 15 up, 38 up (42% see-through), 50 up (gone), 20 down, 55 down).
    **Q54**: "Approved, ship it". **Q55** (the ticket for the crosshair dot shown only while carrying the ball,
    from Q51): "leave it for now, we will take care of it after HUD and UI redesign and fixing": not filed; it
    belongs to the Presentation part's HUD work.
  - **Q56, the magnet widened** (2026-10-29, session 42, while #277's RC study started; the owner's words, added to
    Q42): "by the same way for tackling or diving, or uppercutting into the air when a player is above other play in
    the air". Read as: the Dive and the Uppercut home onto an opponent in their direction the same way the Tackle
    does, and in the air too, toward an opponent above (an Uppercut up at someone in the air). #277 widened to match.
  - **Video 24** (2026-10-29, session 42, recorded on request for #277): `D:\Screenshots\Videos\Screen Recording
    2026-10-29 163427.mp4` (RC Venice Beach vs AI, 2:51, 1918x1078, 30 fps): tackles from close, ~2 and ~4 body lengths
    and to the side, tackle -> dives, Uppercuts under opponents in the air, air tackles and dives. Located so far: 23
    "Dive" episodes (a Tackle press 0.1-0.2 s before each) and 10 airborne moments ("Air Pose" offered); three strikes
    read at 10 fps (contact 0.1-0.3 s after the press; a see-through sphere bursts around the one hit; targets 1-3
    body lengths ahead or to the side). Whether RC's lunge bends toward the target is not settled yet. RC also has a
    "Magnetic Pass" (in the Jump row while carrying): a note for Ball & rules. Study log: the Feel ledger.
  - **Video 24 read for #277** (2026-10-29, session 43; 5-10 frames a second, `claude-handoffs\s43\v24`): six hits
    read (32.5, 34.6, 40.2, 57.8, 72.9, 89.4 s): targets 1-3 body lengths ahead, up to ~20-30 deg to the side, the
    contact 0.1-0.3 s after the press, the one hit flung sideways inside a see-through sphere. An airborne opponent
    flying over the owner (59.0-59.3) was not knocked. Not measurable: whether RC's lunge bends toward the target
    (the camera follows the track and the owner's stick; at 72.6-72.8 the owner drifted toward the target, which the
    stick could also explain), the reach's edges, and an Uppercut up at an airborne opponent.
  - **Round 19, #277** (2026-10-29, session 43, AskUserQuestion with ASCII views, all recommended): **Q57 the strike
    bends toward its target**: at the press it picks an opponent in its cone, the lunge points at them and keeps
    turning toward them through the strike (Tackle 0.3 s, Dive 0.7 s), up to about a quarter-turn; someone who cuts
    away hard can still slip out (not chosen: snap at the press; lock on). **Q58 reach 3 bodies, 45 deg** ("let's try
    with the 3 bodies reach first": a playable trial): the Tackle looks up to 18 studs within 45 deg, the Dive up to
    24, the Uppercut for an opponent above up to 31 studs (its leap) within 45 deg of straight up (not chosen: 2
    bodies / 30 deg; 4 bodies / 60 deg). **Q59 the cone looks along the stick** (camera-relative), else the facing
    (not chosen: always the facing; the camera's aim). **Q60 the nearest** in the cone, the rule today's hit uses
    (not chosen: most in the direction, as passes pick). The owner added: **"about the uppercut, not only when the
    user in the air, if the player comes really close to the player that is on the ground and click uppercut, he can
    uppercut him, take a look at the vide, I were uppercutting players that were on the ground"** (Video 24).
  - **Trial 277A played; round 20** (2026-10-29, session 43). Trial A (Studio copies only, a 2-player local test,
    Player2 driven in a circle and jumping every 3 s): Q57-Q60 as answered, the Uppercut's hit the front half within 6
    studs (+3). The owner: "first, make the duration of the tackle, dive, uppercut longer to stand up from, currently
    it is almost instantly, and second, there is an issue where when I pass near the player and tackle/dive/uppercut,
    it doesn't snap me to them, and I just continue on my way, like a tackle from distance, take a look at that,
    other than that looks, good". Read: passing beside someone they leave the 45 deg cone in the last ~0.1 s, and the
    server's hit counts only 50 deg around the facing. AskUserQuestion (recommended both): **Q61 snap when close**:
    within 2 bodies (12 studs) anyone in the front half (up to 90 deg aside) counts; the strike turns the skater at
    once to face and move at them (keeping the speed), then bends as tried; the hit counts anyone in the front half
    within reach; farther, the 45 deg cone and the bend (not chosen: snap at any range; a wider cone only). **Q62 the
    whole slide, every knockdown**: anyone knocked down (a Tackle, Dive or Uppercut hit, a hard landing, a posed
    fall) stays down for the whole 1.5 s slide; the keys no longer get them up sooner (replaces Q14's 0.5 s; RC:
    Video 4's tackled skater slid 50 -> 0 km/h in 1.5 s and pushed off as it stopped, Video 7's posed falls the
    same); a diver's own belly slide unchanged (not chosen: strikes only; the keys from 1.0 s).
  - **Trial 277B played; round 21** (2026-10-29, session 43). Trial B (A + Q61 + Q62) in a 2-player local test:
    **Q63** "Keep it", then: "actually the diving still have same issue ... I dived, and it didn't snap to the user"
    (**Video 25** `D:\Screenshots\Videos\Screen Recording 2026-10-29 174620.mp4`, ours, 0:34: "look at the video, I
    dived, it don't snap, and the player falls"). Measured by a recorder on the owner's client (24 Tackle-key
    presses): the Tackle was pressed with the opponent 17-27 studs away, 25-46 deg off the facing; at the failed Dive
    presses (video 0:04-0:13, 0:33) the opponent was 10-19 studs away, 62-96 deg off the facing (beside, twice a
    little behind), three times 9-10 studs up in a jump: outside the Dive's 12-stud front-half snap and its 24-stud
    45 deg cone, so the Dive flew straight and ended on the belly. The owner: "I think the tackle is fine".
    AskUserQuestion (recommended both): **Q64 the Dive snaps beside you**: to anyone within 4 bodies (24 studs) up to
    120 deg from the facing (everywhere but the 60 deg behind), on the ground or in the air, turning the skater at
    once (all 7 no-target Dive presses would have snapped; not chosen: all around within 3 bodies; the front half
    within 4). **Q65 every dive still ends on the belly**, hit or miss (RC's way, #242; not chosen: only on a miss;
    never).
  - **Trials 277C/D; Videos 26-28** (2026-10-29, session 43). Trial C: the Dive's snap zone 24 studs up to 120 deg
    (Q64). The owner, before playing it: "we forget a core functionality, a player can tackle/dive in all direction,
    like he can look at a direction, and tackle with pressing D for example, he will tackle on the right, same for
    the dive" (**Video 26** `D:\Screenshots\Videos\Screen Recording 2026-10-29 180502.mp4`, RC Zen Temple, 1:20:
    the lunge's trail runs off to the left at 50.4 s and to the right at 53.7 s, 0.2-0.3 s after the press). Trial D:
    a Tackle, Dive or Uppercut turns the skater at once toward its target, else the stick's way, keeping the speed,
    then pushes that way. Playing D the owner's skater got stuck (no moving, no action, no error) after a Dive, and
    again "tackling and pressing D": read in the code as an older bug (a dive ending already stopped is knocked
    down for one server frame, the client can miss it and keeps its dive hold); its own bug ticket. The owner also:
    **"RC players feels more loose and actual skate mechanics ... I only pressed W for a second or two I think or
    less, and look how he kept skating and following momentum much longer than ours"** (**Video 27** RC
    `D:\Screenshots\Videos\Screen Recording 2026-10-29 181831.mp4`, **Video 28** ours `...181748.mp4`): to measure
    by time and body heights, then ask.
  - **Trial 277E kept** (2026-10-29, session 43, Q66; the owner played it in a 2-player test: "Keep it"). Before
    it the owner: "basically shortern its leap distance, and with that I think we should shorten the reach too" (the
    Dive), and a new finding: "players don't stick their feet in the curved end of the middle glass wall like other
    walls, he drops vertical to it and doesn't stick its feet, fix that too" (its own ticket). The stuck skater was
    found by a client watchdog: after a Dive that ends already stopped the server's knockdown lasts one frame and the
    client can miss it, keeping its dive hold (issue #286, older than #277). Trial E as kept: a Tackle, Dive or
    Uppercut looks along the stick (else the facing); the nearest opponent in its snap zone (Tackle and Uppercut: 12
    studs, the front half; Dive: 18 studs, up to 120 deg) or else in its cone (Tackle 18 studs / 45 deg, Dive 18 / 45,
    Uppercut 31 studs within 45 deg of straight up) is its target; at the press the skater turns at once to face and
    move toward the target, else the stick's way (keeping the speed), then pushes as before; while the target stays
    in the cone the motion bends toward it (Tackle 300 deg/s, Dive 300, Uppercut 360; 3D in the air); hits count the
    front half (Tackle 7, Dive 11, Uppercut 6 studs, +3); the Dive flies 0.3 s (was 0.7) then the belly as before;
    knockdowns last the whole 1.5 s slide (Q62, its own ticket); #286's fix in.
  - **Q67, coasting by real physics** (2026-10-29, session 43, after Videos 27-28). Measured by time: in RC (Video
    27) after about 2 s of W the skater rolled ~11 s to a stop (a short bank near the end); ours (Video 28) stops
    ~3-4 s after a short press, because pressing nothing adds coastDecel 7.5 studs/s^2 on top of rolling friction 4
    and drag (#215, Q3's 5 s from 72 km/h, chosen before any RC numbers). The owner: **"don't depend your measurement
    on the speedometer, just follow RC and real physics, there is a difference between coasting between the walls
    right and left with no keys, we shouldn't be able to continue climbing the steep bumps and hills, but if we are
    going in a straight line and not clicking anything we are going to have momentum and coast longer, just forget
    the speedometer"**. Read: friction acts the same whether keys are pressed or not (no extra slowing for pressing
    nothing), slopes cost speed by gravity as they do. Without coastDecel, from the stride's top speed on flat ground
    our skater rolls ~10.4 s to a stop (RC ~11 s).
  - **Q68 and Q69** (2026-10-29, session 43). **Q68** (AskUserQuestion, recommended): drop the extra brake for
    pressing nothing (coastDecel, #215): the same rolling friction with or without keys (from the stride's top speed
    ~10 s to a stop on flat ground; slopes still slow by gravity; swings between the walls fade by friction and
    gravity only); a playable trial first. **Q69, the middle glass's rounded ends**, the owner's words: "the player
    shouldn't stick to it like from the middle wall from the straight lanes to the curved round ends, I only meant to
    stick to it by feet like the other walls, when the player come to it from the bottom or jump into it, just like
    other walls": riding along the middle wall around its rounded end may still carry a skater off (#257's rule);
    coming at a rounded end from the floor below or jumping into it must land them feet first as on other walls
    (#258). Cause to trace in Studio.
  - **Trial 288 kept** (2026-10-29, session 43, Q70; the owner played it: "Keep it"). Studio copy only: coastDecel
    0 (the same friction with or without keys). Measured in Play: 2 s of W then nothing rolled 11.2 s to a stop over
    100 studs (17 body lengths); RC's Video 27 ~11 s.
  - **#289 traced; Q71** (2026-10-29, session 45). Traced in Studio Play (every step, real code): the round end's
    glass is a half cylinder (radius 20) on the inner bank's top. Riding up into it straight at the tip, the feet
    stay on it to ~4 bodies up, then at the top the smallest drift round it (2.6 studs/s) lets go (#257: a surface only
    pushes, and on an upright wall gravity presses nothing onto it); in the air the body turns upright and the catch
    (#258) gives up because drifting round convex glass always moves off it: the drop beside it. Coming in 14 deg off
    the end's axis the drift round it grows to ~40 studs/s by the glass (pulling in toward the axis), so the feet
    leave just above the bank's top (Video 29). A jump up the bank beside it drifts 1.5 bodies off by the top and
    lands 5 bodies out on the floor. The same approach into a straight's flat glass stays feet first throughout.
    Riding along the straight's middle bank into the round end: carried 15-30 deg round, then off onto the floor.
    AskUserQuestion: first offered a grip as firm as gravity on a floor, on the glass and in the air beside it
    (picked); the owner then: **"what do you mean exactly by beside it? I don't players riding the middle wall from
    the straight side to be able to continue and stick to the wall and curve the curved edge sticking to it to the
    other straight side"** (that grip would have held riders slower than ~9 body lengths a second round the curve).
    Re-asked (recommended): **Q71 a small grip, slow drifts only**: the round glass holds the feet (on it, and in
    the air beside it after a jump up it) only while the skater moves round it slower than about 5 body lengths a
    second; riding along the middle wall from a straight (riding speed ~8 body lengths a second or more) flies off at
    the round end as today, never carried round; riding up into a round end nearly head-on (within ~10-15 deg at
    riding speed) or jumping up it keeps the feet on the glass, up and back down it feet first; coming in more from
    the side still flies off. A playable trial first; the owner may ask for a bigger or smaller speed after playing.
  - **Trial 289 kept; Q72 and Q73** (2026-10-29, session 45). Trial 289 (Studio copies only): walls grip the skates
    against a bend away from them at 38 studs/s² (wallGrip; round the round glass, slower than ~29 studs/s, 5 body
    lengths a second, holds), on them and in the air beside one they left or touched; the curve measured the way the
    surface bends (exact on the round glass whatever the rise). The owner played it: "I think it is fine, but an issue
    arised again, when I jump or uppercut into a wall, it pushes the player off ... in almost all ways, outer, middle,
    round" (**Video 30** `D:\Screenshots\Videos\Screen Recording 2026-10-29 221454.mp4`, ours, 0:37). Traced: the
    trial's first air-follow also acted on walls bending toward the skater (an Uppercut off the outer wall's curved
    foot: 7 studs/s into the upright wall above became 8.6 away); today's code caught every such press. Fixed in the
    trial (the follow only where the wall bends away); every Jump and Uppercut on the outer wall, the middle glass and
    the round ends then rose along it and was caught back on it feet first. Re-played: **Q72 "Keep it"**. The owner
    also asked: "the arena's round floor and curved walls, and the glass round walls even the top, are not smooth ...
    small rectangles ... is it not possible to smoothen it out like real skate ramps?" Told: the look gets smooth
    meshes in the art pass; the riding reads each flat panel (today's seam trouble), and could read the arena's exact
    smooth shape instead. **Q73 (recommended): ticket the smooth riding now, built right after #289**, before #278 and
    the republish.
  - **Trial 294 kept; Q74** (2026-10-29, session 46). Trial 294 (Studio copies only): the skating reads the arena's
    own smooth shape instead of each flat strip. Every ride surface is one closed cross-section (inner glass, the solid
    section, outer glass, top) swept round the stations; Profile gives each strip's direction at its two ends from the
    shape's own pieces (arcs, lines, the rise, the bowl), and a point reads them interpolated along its strip and
    between the two stations round it, turned with the centerline, so every seam is continuous and the middle glass's
    round ends are a true cylinder to the skates (measured: 0.000003 deg off radial; the lips within 0.08 deg of their
    circle, the straight's elliptic bank within 0.7 deg). The look is unchanged until the art pass. The owner played it:
    **Q74 "Keep it"** (build it test-first as trialled).
  - **#294 Studio battery; Q75** (2026-10-30, session 47). The smooth shape built test-first, then Studio Play
    (the real code, A/B against the flat strips' normals): every Jump and Uppercut on the outer wall, the middle glass
    and the round ends caught back on the wall feet first (at most 4 studs off it); rides along the middle bank into a
    round end carried 10-29 deg round, then down to the floor (Q71 holds); a steered lap turned the ground's direction
    in steps of at most 0.47 deg (the flat strips: 5.3, and 42 back-and-forth flips against 1); riding up into a round
    end 10 deg off its axis at riding speed now stays on the glass (it flew off with the flat strips), as Q71 asks
    (within ~10-15 deg of head-on). Asked (AskUserQuestion): the NormalFilter (a sharp turn of the ground's direction
    is trusted only when the next ray agrees; there for rays that hit a seam's side face) has nothing left to guard,
    and its only effect left is ignoring the first ray of new ground after a flight (a touchdown that same step would
    use the last surface's direction). The owner: "remove it, but can you explain it more clearly and simply again";
    re-asked in plain words with a picture: **Q75 "Remove it"**.
  - **#278 grilled; Q76 and Q77** (2026-10-30, session 48, AskUserQuestion with ASCII side views, both recommended).
    Timed by frames, no speedometer: **Video 7** at 10 frames a second: Uppercut ~19.4 s -> Air Pose offered 19.6 ->
    touchdown posed (Get Up) 21.4-21.5, and Uppercut ~27.3-27.4 -> Air Pose offered 27.5 -> touchdown 29.1: RC's
    Uppercut + Air Pose lands 1.7-2.0 s after the Uppercut. Ours, stepped at 60 Hz (claude-handoffs\s48\
    pose278_sim2.py, pose278_uppercut.py; gravity 130.8, the pose pressed 0.6-0.8 s after the Uppercut): today's posed
    fall slides down a line 20 deg below the facing, 2.3-2.5 s from cruise (a standing jump + pose drifts 6.1 body
    lengths forward and stays up 1.95 s); a plain fall 1.6-1.8 s (a standing jump + pose 1.08 s, landing where it took
    off). The ticket's first reading (the glide along the motion's way, straight down only when exactly still) glides a
    skater rolling a third of a body length a second 6.4 bodies on; a glide eased by speed still carries one rolling
    1 body/s 3.6 bodies on. **Q76 a posed fall is a plain fall**: the pose's hop, then gravity only; standing it lands
    where it took off, moving it goes on by its own momentum (from cruise 7.9 bodies/s: 7.9 bodies on in 1.08 s, today
    11.0 in 1.35 s). Coupled, said first: a posed fall no longer speeds up (Q14's gain goes), so posed touchdowns slide
    off slower; a playable Studio trial first. Not measured: a standing Air Pose in RC (no video shows one), how far
    RC's posed falls travel (the chase camera hides it). Not chosen: the glide eased by speed; the glide along the
    motion. **Video 5**: RC's air Dive near an Uppercut's top touched down ~1.0-1.1 s after the press; ours 1.0 s
    (13.2 bodies on), as a plain arc after its push 0.52 s (5.0 bodies). **Q77 the Dive keeps its glide**: an air Dive
    flies down its 20 deg line the way it lunges (its facing and its motion are the same way), speeding up until the
    belly. Not chosen: the Dive as a plain arc too.
  - **Trial 278 kept; Q78** (2026-10-30, session 48). Studio's SkateMath copy only: a posed skater falling flies
    like any other faller (the pose's hop, then gravity, drag and the little air steering); only a diver keeps the
    fall line. A Play built (both ready lines, gravity 130.8). The owner played it (a standing jump + pose straight
    down, a cruising one carried by its momentum, Uppercut + pose, an air Dive unchanged): **Q78 "Keep it"** (build it
    test-first as trialled).
  - **The re-playtest of the published stack head 1069c16; Q79 and Q80** (2026-10-30, session 48). Published
    10:24:42Z (GetProductInfo). Checklist in four groups (AskUserQuestion): map and walls (#268, #294, #267, #289,
    #239), the air, strikes and knockdowns (#278, posed landing, #287, #286, #277) and the camera and mouse (#276,
    #275): **"Feels right"**. Skating and steering (#265, #266, #272, #288, #273, #279), **Q79**: "make brakes when
    pressing against your motion is a little faster so player turn fast, decrease a little the turn weights, and make
    players able to climb more easily the spawn room's rise, that is pretty much it, look at" **Video 19** ("look at
    how I kept turning in a loop that I can't do a hard turn and clear the inner space, since I have speed, but if I am
    really slow, it should turn in place"). Ours, worked from the rules: from cruise (7.9 body lengths/s) S held stops
    the skater in 1.33 s over 5.2 body lengths (the stride's 30 studs/s^2 pushing back) before they turn round; a loop
    at cruise 5.2 body lengths across, 2.06 s (turn rates 4.0 / 1.5); at 2 body lengths/s a loop is 1.0 body length
    across (slow skaters already nearly turn in place); a W-only start in the spawn room tops the rise in 4.8 s (#273's
    Play measurement), creeping at 0.57 body lengths/s. RC (Video 19): loops ~1-2 body heights across by the trails
    (by eye); RC's turn rate not measurable (its camera swings with the skater). **Q80 (recommended): build trial
    S1**: the push against the motion x2 (stop from cruise in 0.71 s over 2.8 bodies), turn rates +25% (5.0 / 2.0: a
    cruise loop 4.1 bodies across in 1.63 s), the crawl up slopes x2 (6.67 studs/s, 1.1 bodies/s; the outer wall's
    foot curve too); the owner plays it and says more or less. Not chosen: smaller (x1.5, 4.5 / 1.75, crawl x1.5);
    bigger (x3, 6.0 / 2.5, crawl x3).
  - **Trial S1 played; Q81** (2026-10-30, session 48). Trial S1 (Studio copies only: SkateMath's push against the
    motion x2, Movement turnRateLow 5.0 / turnRateHigh 2.0, crawlSpeed 6.67). The owner: **"stop more sooner to turn
    around, and make players crawl faster more, like it is easy to clear that slope, even the foot of the outer wall,
    it is okay, RC does that"** (the loops: no comment, kept). Trial S2 built from it: the push x3 (stop from cruise in
    0.49 s over 1.9 bodies), the crawl x4 (13.33 studs/s, 2.3 bodies/s, under cruise 46), turn rates as S1.
  - **Trial S2 played; Q82 and Q83** (2026-10-30, session 48). Trial S2 (push x3, crawl 13.33, turn rates 5.0 / 2.0).
    The owner: **"stop more sooner, and crawl the slope more faster, almost as they are walking on a straight floor,
    but almost not quite"**. Coupled, said first: the crawl lifts a slow skater to its speed in one step (unseen at
    3.33, visible near skating speed). **Q82 (recommended): build trial S3**: the push x4 = the Brake key's 120
    studs/s^2 (stop from cruise in 0.37 s over 1.5 bodies), the crawl gaining at the stride's own rate (as on the flat)
    up to 34.5 studs/s (5.9 bodies/s, 3/4 of the flat's 7.9), turn rates as S1. The owner also asked why Studio's
    mouse feels faster than the published game. Ours: 0.1 deg per pixel x Roblox's own Camera Sensitivity setting
    (UserGameSettings.MouseSensitivity, read by InputController), and Studio and the Roblox Player each keep their own;
    Studio's read 1.0. **Q83**: "bring it back to 3600 for now and keep it like that, I guess yes my roblox player
    settings have lower camera sensitivity I guess that is why": the code stays (3,600 px a turn at a setting of 1);
    told to set the Player's slider to 1 for the same feel.
  - **Trial S3 played; Q84** (2026-10-30, session 48). Trial S3 (push x4 = 120 studs/s^2; the crawl gaining at the
    stride's rate up to 34.5 studs/s on slopes under 45 deg; turn rates 5.0 / 2.0). Measured in Play, W only from a
    stop in the spawn room: the rise's top at 1.36 s (today 4.8 s), the incline's top 1.93 s, up the outer wall's foot
    to ~22 studs before sliding back. The owner: **"looks good, just one thing I want, I want a little more power on
    the slope and wallks climb, I want the player to be able to climb all walls, just till they reach the glass then
    they start dropping, so if you can have them climb more faster or something"**. Trial S4 built from it: the climb
    on every solid ride surface whatever its steepness (the outer wall to its glass at 40, the inner bank to the inner
    glass), never on the glass (real physics there, #239); gaining at 1.5x the stride's rate (45 studs/s^2) up to 40
    studs/s (6.8 bodies/s; cruise 7.9).
  - **Trial S4 kept; Q85** (2026-10-30, session 48). Trial S4 (Studio copies only): the stick against the motion
    pushes back at 4x the stride (120 studs/s^2, the Brake key's rate: from cruise stopped in 0.37 s over 1.5 bodies);
    turn rates 5.0 / 2.0 (a cruise loop 4.1 bodies across in 1.63 s); holding the stick up any solid ride surface,
    however steep, but never the glass, gains speed at 45 studs/s^2 (1.5x the stride) up to 40 studs/s (6.8
    bodies/s). Measured in Play, W only from the spawn room: up the outer wall at 40, ~4 studs onto the glass by
    momentum, then down the whole wall and back across the track (on the upright part a stick pointing into the wall
    has no part along it), then up again (~5 s a cycle). The owner played it: **Q85 "Keep it"** (build it test-first
    as trialled).
  - **The re-playtest of the published stack head 6bfbeef; Q86** (2026-10-30, session 49). Published 11:41:43Z
    (GetProductInfo; #298 + #299 on top of 1069c16). AskUserQuestion, each with ours beside RC: the stick against the
    motion (from cruise stopped in 0.40 s over 1.4 bodies; RC Video 15 near a stop in ~0.5 s) and turns a quarter
    quicker (a cruise loop 4.1 bodies across in 1.6 s): **"Feels right"**; the climb (W up any solid surface to 40
    studs/s, 6.8 bodies/s; the rise topped in 1.27 s, the outer wall to ~3.4 studs onto the glass at 2.35 s, then
    down and across): **"Feels right"**; the mouse with the Roblox Player's Camera Sensitivity at 1 (3,600 px a turn,
    as Studio, Q83): **"Feels right at 1"**. The Feel part's skating has no open finding left.

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
