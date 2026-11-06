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
  - **The Feel part's end-of-phase review; Q87-Q89** (2026-10-30, session 49, AskUserQuestion, plain words). The
    review (Standards + Spec, main deb87b9 -> dd8dc14) found three behaviours no answer settled. **Q87** (not the
    recommended): a Dive touching flat ground 40+ studs (7 bodies) below its last top (an Uppercut high on the glass,
    56-83 up, then Tackle, Dive) stays **a hard landing** (on the back, 1.5 s, the Get Up prompt), as built; not
    chosen: always a dive (Q65's "every dive still ends on the belly"; no RC video shows a dive from that high).
    **Q88** (recommended): **keep RC's Get Up prompt** during tackle and fall knockdowns although since #287 (Q62)
    pressing no longer shortens them (RC shows it, Videos 5 and 7; whether pressing helps in RC can't be told); the
    texts saying it gets them up sooner are fixed; not chosen: remove it. **Q89** (recommended): **the Uppercut homes
    only as far as it hits**: its hit counts the first 0.25 s, the leap then 18 studs up, the hit 6 (+3 lag), so its
    bend reaches about 27 studs (4.7 bodies), not 31 (Q58), timing unchanged; not chosen: the hit for the whole rise
    (0.69 s, delaying the air Tackle; RC's was ready 0.13-0.3 s after, Video 5); keep the 31-stud bend.

## The owner's answers, 2026-10-30 (session 50, the Ball & rules part's grilling, round 1)

Before asking (session 50, frames of the owner's recordings; ledger `.superpowers/sdd/ball/progress.md`): RC's carried
ball measured against its holder in Video 13 at 99.0 s (at the hip: 0.18-0.19 of a skating crouch) and Video 4 at
365.0-365.25 s (before the face, nearer the camera: 0.14), so about 1/7 to 1/6 of a skater's height; RC's pickups in
Video 13 (1:36.8-1:37.2, 0:37.8-0:38.1): a loose ball about a body length away flies into the hand in ~0.2 s; RC's
kickoff (Video 4 0:08-0:13, Video 13 0:22-0:27): 5, 4, 3, 2, 1 in the goal ring, a number a second, skaters free to
skate and act, the ball in play and the clock started at "GO" (where the ball comes from was off-screen). The Feel
stack (#225-#304) was approved for merging the same turn ("Merge now").
- **Q90 the ball's size** (recommended): **1 stud across, RC's proportion** (about 1/6 of our 5.85-stud skater; ours
  was 3, half a skater); the ring marker stays; built first as a playable Studio trial with Q91. Not chosen: 1.5
  studs; keep 3.
- **Q91 the magnet pickup** (recommended): a loose ball within **1 body length (6 studs)** of the skater becomes theirs
  at once (the server decides then, so nobody steals it mid-pull) and **flies into their hand over 0.2 s**; a thrower
  still waits 0.4 s before catching their own throw; tried in the same trial. Not measured: RC's exact edge, whether
  an opponent can cut in during the pull. Not chosen: 2 bodies; keep today's 5 studs from the middle, snapped.
- **Q92 the kickoff** (recommended): **RC's 5 s count, 5-4-3-2-1 in the goal ring, everyone free** to skate and act
  from their team's spawn; at GO the ball appears at a random ball spawn (as today) and the clock starts. Not chosen:
  the count in the ring with everyone frozen; keep today's 3 s frozen with the number on screen.
- **Q93 the loose ball** (recommended, the owner's issue list: "Ball gets spawned randomly again when not being picked
  after a while at the start"): **the 15 s respawn goes**; a loose ball stays where it rolls until someone picks it
  up; it respawns only if it ever leaves the arena (a fault) or rests 5 s on something nobody can skate on (the goal's
  housing or arm). No RC video studied (3, 4, 13) showed a loose ball vanish. Not chosen: no exceptions; keep 15 s.
- **Round 2** (session 50, after reading Video 3 at 44:50-45:13: at overtime's start RC shows "OVERTIME" and play
  goes on with a 3:00 clock, no reset, laps kept, as ours already does). **Q94 Last Chance** (recommended): **one attack
  only, any deficit**: it ends when the leaders pick up the ball (they win) or when the trailing team scores (level =
  overtime, ahead = they win, still behind = the leaders win); a missed throw left loose does not end it while the
  trailing team can still pick it up. Not chosen: a goal that leaves them behind gives a new kickoff and Last Chance
  goes on (today's rule, only 1 behind). **Q95 overtime's end** (recommended): **a draw the moment the overtime clock
  reaches 0:00**, even if a team holds the ball (RC's no-goal overtime end was never seen). Not chosen: a last attack,
  then a draw. **Q96 leavers** (recommended, the owner's list: "When a player leaves, remove their name from
  scoreboard"): **the row disappears at once**; the team's score keeps their goals; a rejoin in the same match returns
  them to their team with their row and numbers back. Not chosen: gone for good; keep it dimmed (today). **Q97 team
  switching**, the owner's words: "first, team switching not offered in upcoming ranked mode, only offered in normal
  games, and yes they switch by choice, and shouldn't have auto balance, every player leaves a match they get switched
  by a bot, in all modes, normal, ranked, everything, and yes, we should always keep the same team for next match, even
  if the other team is less players". So: **switching by choice in normal games only** (never ranked, M7); **no
  auto-balance**; **a leaver is replaced by a bot in every mode** (bots arrive in M2); **the next match keeps everyone's
  team**, even when the teams are uneven.
- **Round 3** (session 50, after reading RC's charge in Video 4 at 6:05.9-6:07.4 at 10 frames a second: a dot at the
  press, four arcs complete by ~0.4-0.5 s, released ~1.15 s after the press, dashed rings following the ball into the
  ring; Video 3 at 36:58 the same in ~0.6 s). **Q98 the shooting trajectory** (not the recommended): **both** - a
  predicted arc from the hand while charging (neither RC nor Illegal Soccer has it) and a trail behind the thrown ball;
  RC's building crosshair stays. Not chosen: RC's way + a trail only; the predicted arc only. **Q99 the charge**
  (recommended): **a full charge in 0.5 s** like RC's crosshair (ours 1.0 s); the speeds (60 at a tap, 160 at full,
  10-27 body lengths a second) stay and are judged in the same Studio trial as the 1-stud ball and the magnet. Not
  chosen: keep 1.0 s. **Q100** (recommended): **add RC's "Cancel & Dodge" and "Roll Ball"**: while charging, E (Dodge)
  drops the charge and dodges, Q (Uppercut) rolls the ball along the floor ahead at the charge's speed; the hints show
  them while charging. The owner recorded two RC clips for it ("ball throwing, cancel & dodge, charge speed and power,
  and roll ball, take a thorough look"): **Video 31** `D:\Screenshots\Videos\Screen Recording 2026-10-30 153307.mp4`
  and **Video 32** `D:\Screenshots\Videos\Screen Recording 2026-10-30 153401.mp4`. **Q101 networking**: "for now
  mostly about the ball steps/trails, if anything else you find fix it": make the ball smooth on every screen (the
  carried ball in the carrier's hand on each screen, a loose or flying ball moved smoothly between the server's
  updates). The owner also pointed at GitHub's incident (2026-10-30 14:31 UTC, "Disruption with GitHub services"):
  use HTTPS for now (the merges' SSH pushes were refused).
- **Videos 31-32 studied** (session 50; 2 frames a second throughout, 5-10 at the moments): **Video 31** (Hidden
  Cenote, standing throws along the straight): the kickoff again (hints greyed 14.0-15.5, "5" at 16.0 ... "1" at
  20.5, GO 21.0); five pickups, each followed by a charge of 1.5-2.5 s while slowing to 0-6 km/h and a throw that flies
  down the straight (its marker near the far end within ~1 s; no side view, so its speed is not measurable); **Roll
  Ball** at 1:19.4 (the press marker on its row): the ball drops to the floor beside the skater and its marker travels
  away along the floor. **Video 32**: a Cancel & Dodge at ~4.6 s turns the Dodge row into **"Dive" for ~1 s**
  (4.6-5.6), then "Dodge" again (again at ~8.5): RC's Dodge with the ball has a Dive follow-up like the Tackle; Pump
  is greyed while charging; after a goal (24.5) play goes on with the clock held.
- **Round 4** (session 50). **Q102** (not the recommended): **add the Dodge -> Dive with the ball; the carrier keeps
  the ball**, and the owner recorded it: **Video 33** `D:\Screenshots\Videos\Screen Recording 2026-10-30 155246.mp4`.
  Not chosen: wait for a clip; leave it out. **Q103** (the owner's words): "name it magnetic pass like RC, and player
  should aim in the direction of his teamaate and we show a hint that he can pass to him, otherwise pagnetic pass
  should be greyed out like RC, watch this video, I recorded for passing in RC: ... take a thorough look, today our
  passing and ball mechanics is bad, follow RC": **Video 34** `D:\Screenshots\Videos\Screen Recording 2026-10-30
  155713.mp4`. So: the pass is **"Magnetic Pass"**, available only while the player aims toward a teammate (a hint
  shows they can pass to them), **greyed otherwise**, RC's way; RC's passing and ball mechanics are to be followed.
  **Q104** (recommended): a **"Switch team" button on the score tab works whenever the other team has a free seat**
  (from M2 a bot's seat counts as free: the bot leaves), even if that makes teams uneven; not while holding the ball;
  the player re-spawns on the new team's side at once. Not chosen: only to the smaller team.
- **The Feel stack merged** (session 50, the owner's OK "Merge now"): 45 squash merges #225 -> #304 onto main
  (bfc0e1d, tree equal to #304's head); GitHub's incident of 2026-10-30 (502s, cut-off API replies, SSH refused) was
  ridden out over HTTPS with retries; every Feel issue closed with its PR.
- **Videos 33-34 studied** (session 50; 2 frames a second throughout, 10 at the moments). **Video 33** (Fallen
  Stadium): a Cancel & Dodge at ~17.0 s (24 -> 57 km/h readout in 0.1 s), the row reads "Dive" 17.0-17.6, the Dive at
  ~17.6 (56), on the belly by 18.0, sliding 33 -> 0 by 19.0 (1.0 s) with every hint greyed but Charge Throw, all back
  at 19.1: **the carrier keeps the ball through the dive** (twice more at 21-22 and 26-28 s). **Video 34** (Venice
  Beach with AI teammates): with the ball a key letter ("E") floats over the teammate in the aim's direction and
  "Magnetic Pass" lights, greyed otherwise; the owner's pass at ~43.0 is a straight streak into the teammate's hands
  by ~43.15 (3-4 body lengths); a call puts a hand over the caller, and the AI teammate passes within ~0.5-1 s of the
  owner's call (the ball streaks in from ahead, ~49.9 -> 50.3, then a catch flash at the screen's centre); an "F"
  letter and a "Hold & Release [F] ... Speed Boost" prompt behind a teammate are the Attach whip (1:06.5-1:09.5).
- **Round 5** (session 50). **Q105 the Magnetic Pass** (recommended): the target is a teammate **within 70 deg of the
  aim and 120 studs** (a caller first, else the one nearest the aim's line); **the pass key's letter shows over them
  and the hint lights**; with no target the hint is **greyed and the key does nothing**; the pass **flies straight to
  their hand at 150 studs/s** (4 body lengths in ~0.15 s), homing hard so it arrives unless glass is in the way (then
  it bounces off, loose); the speed is judged in the Studio trial. Not chosen: another speed now. The owner also
  approved deleting the 45 merged local Feel branches (done).
- **Q106 pumping while charging** (session 50, asked after #305's PR #318; RC greys Pump while a throw charges:
  Videos 13, 31, 32): the owner, "yes pumping should stop, like RC": **no pumping while a throw charges** (#312).
- **Q107 overtime's warnings** (session 51, while building #306: overtime now counts 3:00 down to a draw; no RC
  clip shows an overtime reaching its end): **the same "60 SECONDS" and "30 SECONDS" banners in overtime** as in
  regulation (recommended), since overtime now ends the match too. Not chosen: no banners in overtime.
- **Q108-Q110 the kickoff's look** (session 51, before building #307). **Q108** (the owner's words, correcting my
  reading of Video 4): "no it is not in the goal ring, the goal ring is closed, it shows in the middle of the screen,
  like this" (Videos 31 and 33). So RC's count is **on the screen**: an orange ring about 19% of the screen's height
  across with the digit inside, centred, about a third down (Video 31 at 1918x1078: ring centre (959, 340), 200 px
  across, digit ~75 px tall), one number a second, 5 at 16.0 s to 1 gone at 21.0 s; the clock holds 07:00 until GO
  (06:59 at 22.0). It replaces #307's "in the goal ring". **Q109** (recommended): **"GO <team> TEAM!" at GO**, as RC
  (Video 31 21.0-23.0 s: white letters with an orange outline, ~60 px tall, centred ~22% down, ~2 s). Not chosen: no
  text at GO. **Q110** (recommended): **the count in each player's own team colour** (RC's was orange for an Orange
  player, one sample). Not chosen: white.
- **Q111 the ball enters by dropping from above** (session 52, the owner's words while Connecting Rojo for #308):
  "just like RC, at kickoff, I want the ball to drop from above and roll next to the outer wall or middle wall at
  random spots, not just at the curved rounds, otherwise players will get used to it and stay there ... most
  importantly, not just spawn instantly at the ground in a random spot, I want it to drop from above and roll with the
  wall". Ours today: two ball spawns, 6 studs over the middle of the track at each curved end's apex, the ball placed
  there at GO. RC, **Video 31** (4 frames a second 20.5-28.5, full-size frames 21.75-24.25): at GO (21.0) the ball's
  off-screen icon already shows at the screen's top; its ring marker with a thin vertical line under it comes into
  view high above the far curved end (21.75-22.75), reaches the floor by that end's wall about 23.5, and the ball then
  rolls along the foot of a wall ahead of the skater, who catches it at 27.8 (6.8 s after GO). Not measurable (no side
  view, one sample): the drop's height, its fall speed, the roll's way and speed. Video 3 at 37.4-38.8 (Mexico): the
  recorder was high on the glass; the ball's entry was not readable.
- **Q112-Q115 the ball's drop** (session 52, AskUserQuestion right after Q111, all recommended). **Q112** where:
  **a new random spot every time, anywhere round the loop** (straights and curved ends), **half the time by the outer
  wall** (landing on its curved foot), **half the time by the middle glass** (landing on the inner bank). Not chosen:
  the outer wall only; a fixed set of 8 spots. **Q113** the fall: **slowed like RC's ~2.5 s**: from just under the
  glass's top lip (~108 studs, 18 body heights) at a quarter of gravity until it first touches something (lands ~2.6
  s after GO), then a normal ball. Not chosen: full gravity (lands 1.3 s after GO at ~170 studs/s). **Q114** the roll:
  **it falls already moving along the wall the way skaters lap** (gate 1 to 2 to 3 to 4) **at a slow skate, ~20
  studs/s** (3.4 body lengths/s), so it rolls along the wall's foot and round the curved ends. Not chosen: a random
  way; no push. **Q115** respawns (out of the arena; 5 s on something nobody skates, #308): **drop the same way**. Not
  chosen: only at kickoffs. Built after a playable Studio trial (the owner's rule for feel choices).
- **Trial 321 kept; Q116** (session 52). Trial 1 (Studio copies only, as Q112-Q115 said: a quarter of gravity until
  the first touch, launched along the heading): on a curved end the ball flew straight on (the tangent), touched the
  outer glass high up 1.8 s after appearing, then fell at full gravity and rolled across the arena at 50-70 studs/s.
  **Trial 2**: it appears just under the lip (~102 studs, 17 body heights), half the time 8 studs in from the outer
  wall's face, half 6 studs in from the middle glass's, anywhere round the loop; until its first touch it falls
  steadily at 42 studs/s while moving 20 studs/s (3.4 body lengths/s) the lap's way **along the track's curve** (no
  drift into the glass); first touch 2.0 s after appearing (the outer foot, ~17 up) or 2.3 s (the inner bank, ~5 up);
  then real physics: our cross-section slopes from the outer wall down into a low lane beside the inner bank, so the
  ball rolls down across the track and rocks across that lane while creeping along (it does not hug the outer wall as
  RC's did on a flatter floor). Said before playing: the steady fall replaces Q113's quarter of gravity. The owner
  played it (re-dropped every 12 s while nobody held the ball): **Q116 "Keep it as it is"** (build it test-first as
  trialled). Not chosen: landing in the low lane beside the inner bank; other numbers.
- **#310 switch team, Q117-Q120** (session 53, all recommended; RC frames not used: the switch is the owner's own
  request, Q97/Q104). **Q117 how to press it:** on PC the score tab shows only while Tab is held and the mouse stays
  locked, so the "Switch team" button shows a key: **T** on the keyboard, **D-pad Up** on a gamepad, pressed while the
  tab is open; on phones the button is tapped (the touch score button keeps the tab open). The switch is at once. Not
  chosen: freeing the mouse cursor while Tab is held. **Q118 unavailable:** while a switch can't happen (the other team
  has no free seat, or the player holds the ball) the button **stays, greyed** (the pips' fade), and its key does
  nothing. Not chosen: hidden. **Q119 throw then switch:** a ball the switcher threw that then scores for their old
  team **counts as earned**: the point to the old team, the goal in the switcher's numbers, which move with them (as a
  leaver's does today); nothing blocks a switch after a throw. Not chosen: greyed until a pickup or a kickoff.
  **Q120 cooldown:** **none**; each switch puts the player back on the new team's spawn, and the server drops spam (at
  most one request a second). Not chosen: a cooldown between switches.
- **Trial 311, Q121** (session 54). The trial (Studio copies only): the ball 1 stud across, carried low in the right
  hand at the hip with the arm down, the magnet at 6 studs (+2 lag) pulling the ball into the hand over 0.2 s, a full
  charge in 0.5 s (60-160 studs/s), passes at 150, plus an anti-tunnel guard (a loose ball whose centre crossed a
  solid face since the last frame goes back there, bounced; holds the floor, the closed goal panel, the outer wall
  and both glasses at 400-500 studs/s). The owner played it solo and answered in their own words: "increase the ball
  size by a bit more, it is too small now, it is hard to see from far away, and also, when a player holding a ball
  and he is charing it, zoom the camera out a little, so if player tries to aim straight forward, the camera doesn't
  be under the player and fades him out, it is not like that in RC, and bring the crosshair a little bit more above
  the player like RC, i don't know, basically check RC videos, I think RC is not zooming the camera out, but the
  crosshair is above the player: [Video 32] and [Video 34] also the ball feels more faster then the player, like when
  I try to reach it, it is more faster, and while we are at it, I want to note two things to do: first: make the
  player climb diagonaly the walls and the bump easily and faster and of course not the glass walls and second, the
  ball should be on the color of the holding team". So: **the ball a bit bigger** (1 stud is hard to see from far);
  **aiming a charge must not drop the camera under the skater and fade them**: study RC's camera and crosshair while
  charging (Videos 32 and 34; the owner thinks RC keeps the camera and puts the crosshair higher, above the
  skater); **a loose ball feels faster than the skater chasing it** (to measure); two new to-dos: **climbing the
  walls and the bump diagonally, easier and faster** (never the glass), and **the ball in the carrying team's
  colour**. Not commented on: the carry spot, the magnet and its pull, the 0.5 s charge; passes not yet played.
- **Trial 311 round 2, Q122-Q125** (session 54, AskUserQuestion after Q121; RC frames first: Video 32 at 2.0, 3.2
  and 4.4 s, the crosshair's centre about 31% of the screen's height from the top, above the skater's head, with and
  without a charge; the skater's size on screen the same before and while charging, so RC does not zoom; Video 34's
  catch flash centred ~38% down). Measured in the trial: a loose ball never slows rolling on the flat (Roblox gives a
  rolling ball no resistance): after a tap throw (60) it still rolls ~40 studs/s seconds later, after a full throw
  ~110 at 1.5 s and ~60 at 6 s, while a skater strides to 46 and coasting loses 4 studs/s each second. **Q122 the
  ball's size** (recommended): **1.5 studs**, a quarter of a skater (the trial's 1 stud was hard to see from far);
  the carry spot moves out so it still sits in the hand. Not chosen: 1.25; 2. **Q123 aiming** (recommended): **RC's
  crosshair above the skater**: while carrying, the dot sits about a third of the way down the screen (~15 deg above
  where the camera looks) and throws and passes aim through it; the camera stays as today, no zoom while charging.
  Not chosen: zooming out while charging; both. **Q124 a loose ball rolling**, the owner's words: "Slow like a
  coasting skater, and also make players a little faster, and if possible, make the arena more longer, like longer
  straights": **a loose ball loses 4 studs/s each second on any surface, as a coasting skater does** (a 40 roll
  stops in ~10 s, ~34 body lengths; bounces and slopes stay real physics); and two new requests, **skaters a little
  faster** and **a longer arena, longer straights** (to grill). Not chosen: 10 studs/s each second; no slow-down.
  **Q125 the two to-dos** (recommended): **filed now, built after #316** (before the playtest record #317), each
  grilled with RC frames first; the owner on the climbing: "what I mean never the glass, is like if player go
  straight into the outer wall or middle wall, without any mechanics, like jump or uppercut or anything, he can't
  climb the glass, just like what we have now, but I just noticed if he goes diaganoly, he can't reach the end of the
  gray wall that is next to the glass, players don't have good speed": so W keeps stopping at the glass as today,
  and **a skater riding diagonally up the grey (solid) walls and the bump must reach the glass's foot**, with more
  speed. Not chosen: right after #311; a later part.
- **Trial 311 round 2, Q126-Q129** (session 54). Round 2 (Studio copies): the ball 1.5 studs carried low in the
  right hand, RC's crosshair a third of the way down the screen (throws and passes aim through it), a loose ball
  slowing 4 studs/s each second, the magnet (6 studs, a 0.2 s pull), a 0.5 s charge, passes at 150 homing hard
  (homingAccel 300). Played in a 2-player Studio test with my bot teammate (it caught the owner's passes and passed
  back 10 times, 16-133 studs). **Q126 the ball's size**, the owner: "let's try 2 studs" (a third of a skater;
  another round). **Q127 the crosshair**: **keep it** (build in #312). **Q128 the rolling slow-down**: **keep it**
  (4 studs/s each second). **Q129 the pass and the magnet**, the owner's words: "first passing is snapping like
  insatant, shouldn't be that fast, because other players should be able to intercept it when they are on its way,
  slow it more, same magnet pulling, slow it a little bit more, but not too much for the magnet": **a slower pass**
  that opponents can step into on its way, and **a slightly slower magnet pull**. Not commented on: the 0.5 s charge.
  The anti-tunnel guard fired twice in ~8 minutes of their play: both real crossings (a ball landing at 63-109
  studs/s whose centre passed the face of a thin triangle-filler wedge in a curved end's floor), bounced back.
- **Trial 311 round 3, Q130-Q133** (session 54, AskUserQuestion before it: Q129's follow-ups chosen as recommended,
  passes at 90 studs/s with gentler homing (150), the magnet's pull 0.3 s). Round 3 (Studio copies, a 2-player test
  with my bot teammate): the ball 2 studs (a third of a skater) carried low in the right hand, passes at 90 homing
  150, the pull 0.3 s, the crosshair above, the rolling slow-down, the 0.5 s charge. **Q130**: **keep the 2-stud
  ball**. **Q131 the pass**, the owner's words: "more speed, but also I don't know maybe it is a server networking
  issue but basically the ball snaps to the player's hands, can we fix that?": **faster than 90** (150 felt
  instant), and **the ball must not snap into the hands** (to measure: how the ball replicates to each screen).
  **Q132**: **keep the 0.3 s pull**. **Q133**: **keep the 0.5 s charge** (60 at a tap, 160 full).
- **The snap measured, Q134-Q135** (session 54). In solo Play a screen shows the flying ball every frame and the
  pull in 9 steps (no snap); in a 2-player test (my probes driving both skaters) a 50-stud pass at 90: the
  receiver's screen last showed the free ball 36.6 studs out and the next frame (0.067 s later) the ball welded
  5.8 from them, a 31-stud jump: the catch (decided by the server 8 studs out) reaches a screen while it still
  shows the ball short of the hand. **Q134 the order** (recommended): **#311 now** (the 2-stud ball, the magnet,
  each screen drawing the 0.3 s pull from where it last showed the ball, the rolling slow-down, the anti-tunnel
  guard), **then the smooth ball #316 right after**, then #312 (the throw, the crosshair above, the 0.5 s charge),
  #313, #314, #315 (the Magnetic Pass; its speed, Q131 "more speed" than 90, judged on the smooth ball). Not
  chosen: the planned order (#316 last). **Q135** (recommended): **skaters a little faster and a longer arena with
  longer straights** (Q124) are filed as issues with the diagonal climb and the team-coloured ball (Q125), grilled
  with RC measured by time and body lengths, trialled, and built **after #316, before the playtest record #317**.
  Not chosen: right after #311; a separate part later.
- **Q136 the new issues** (session 54, to-tickets breakdown): four issues, each grilled with RC frames (time and
  body lengths) and trialled before it is built, all after #316 and blocking the playtest record #317: diagonal
  climbing of the grey walls and the bump (skate), the team-coloured ball (ball), skaters a little faster (skate),
  a longer arena (arena, after the speed issue: together they set the lap time). The owner approved ("yes file
  them") and clarified the arena in their words: "what I meant by logner arena and longer straights is just to make
  the arena straight ends like the top and bottom of the arena longer, the curved ends the same": **only the two
  straights grow** (today 200 studs each, Arena.straightLength); the curved ends keep their shape and size.
- **Q137 a slower carrier** (session 55, unprompted, while starting #316's 2-player measurement): "also wanted to
  note something about making players more speedy, we need to also have a little debuff for players that are holding
  the ball, like make them a little more slower than players without the ball, so we discourage players to play
  selfish and encourage passing, but not too much debuff". Goes with #328 (skaters a little faster): the two set the
  chase together, so they are grilled (RC frames first: does RC slow its carrier?) and trialled together.
- **Q138 a pass at 100, a 0.2 s pull** (session 55, starting #316's 'after' 2-player test): "can you make it 100
  instead of 90 for the ball, and 0.2 for the pull, want to see it". The first look at the pass speed on the smooth
  ball (#316 built: each screen draws the loose ball from the server's stamped states, no lag, even steps), as Q131
  asked; Q132 had kept the pull at 0.3. Trialled in Studio copies (Actions.Pass.pass.speed 100,
  Ball.pickupPullSeconds 0.2) with my bot teammate passing to them.
- **Q139 the trial's verdict** (session 55, after playing Q138's trial in a 2-player test, my bot teammate passing
  to them 8 times): "Keep 100 and 0.2": a pass flies at **100 studs/s** with **homing 150** (as trialled; the repo
  still had 90 and 60, so #315 sets both), and a caught ball flies into the hand over **0.2 s** (was 0.3, Q132; RC's
  took ~0.2 s, Video 13 at 1:36.8), set with #316.
- **Q140 no pass while charging** (session 55, #312, recommended): RC's hints grey Pump AND Magnetic Pass while a
  throw charges (Video 32 at 2.6-3.2 s: Throw, Cancel & Dodge, Roll Ball lit); ours likewise: while charging the pass
  key does nothing and its hint hides; Cancel & Dodge or letting go are the ways out.
- **Q141 the crosshair's colour** (session 55, #312, recommended): RC's charge crosshair is an orange ring of four
  arcs building round the aim dot (Video 32 at 3.2 s, ~31.5% down the screen); ours is **white, the HUD's text
  colour**, readable on both teams' floors (orange is one of our team colours).
- **RC's charge ring, read again** (session 56, #312; corrects Q141's "four arcs"): at full resolution (Video 32,
  1918x1078, 2.5-4.2 s) the ring is **two halves**, left and right, a gap apart at the top and the bottom, growing
  from the bottom up both sides at once until they close: short arcs at the bottom at 2.7 s, past the middle at 3.0,
  closed at 3.2 (the press at ~2.6); fixed size round the dot, ~130 px across, a ~4-5 px stroke, the dot ~8 px, the
  bottom gap ~29 px (the top one ~60 px at 3.2); past the full charge it fades and pulses (3.5-4.2). #312 builds
  that shape in white (Q141), the gap 29 px top and bottom, no pulse.
- **RC's ring past a full charge, measured** (session 57, Video 32 at 30 fps, 2.4-5.4 s, the ring's crop at full
  resolution): closed at ~3.23 s, it then **blinks until the release**: lit ~0.2 s, almost gone ~0.2 s (its red
  0-8% of lit at 3.47, 3.87, 4.27), lit again at 3.67, 4.07, 4.47: **every 0.40 s**. While carrying and not
  charging RC shows a **small ring** round the dot (centre-line radius ~27.5 px, ~55-60 px across; the charge ring's
  is ~59, 130 outer): before the press (2.4-2.55) and again after the Cancel & Dodge (4.7-5.4); Video 3 at 36:58.15
  showed the same. **Q142** (recommended): **add RC's blink**: once full, the white ring blinks every 0.4 s (lit
  0.2, nearly gone 0.2) until a throw, a roll or a cancel; added to #312's PR #332. Not chosen: steady. **Q143**
  (recommended): **the small carrying ring waits for Q55** (what the crosshair shows with and without the ball) in
  the Presentation part; ours keeps the dot. Not chosen: now in #332. **Q144** (recommended): **file the
  ring/scoreboard overlap now** as an M1 issue for the Presentation part (at 793 px tall the closed ring's top sits
  ~8 px under the scoreboard panel; under ~770 px tall and on phones the 130-px ring 31.5% down overlaps it). Not
  chosen: notes only.
- **Q145 the arc's look** (session 57, #313, recommended). Measured in Play first (the arc built as small white
  world dots): from our chase camera a throw flies almost straight away, so its whole predicted path (89 studs on a
  full throw along the straight) shows as a thin vertical line from the ball up through the skater's head; the near
  dots hide behind the body and the landing point sits right behind the head; the server's ball then followed the
  drawn arc within 0.31 studs to its end (a bounce). The owner chose **dots drawn on top of everything** (the skater
  too) at a fixed size on screen with a dark edge, **ending in a ring where the ball would first touch**. Not chosen:
  a landing ring only; the world dots as built.
- **Q146-Q147 #313's look, after screenshots** (session 57, both recommended). Built: the arc as Q145 (edged
  white dots over everything, a landing ring), measured in Play: a full throw stayed within 1.5 studs of the drawn
  arc over 97 studs and passed 0.8 studs from the ring; from the chase camera the far half and the ring gather at
  the skater's head. The trail as first built (white, 1 stud wide, 0.3 s, 30% see-through) was faint on our light
  floors from the side. **Q146**: **a bolder trail**: as wide as the ball (2 studs), solid at the ball fading out,
  0.4 s long (64 studs behind a full throw). Not chosen: keep it; the team's colour later with #327. **Q147**:
  **ship the arc as built** (judged again at the #317 playtest). Not chosen: the owner plays it first.
- **Q148 the throw lands on the crosshair** (session 58, recommended), the owner's words first: "the throw trail
  is coming from the ball, and not the crosshair dot, it is not making sense, the crosshair hae no use then ... even
  the ball isn't coming from the crosshair, it should be from there so the crosshair makes sense, like RC ... in a
  realistic way of course" (Video 31). RC, at 10 frames a second: Video 31 at 38.5-39.5 s (standing, the charge ring
  on the far end of the straight ~32% down): released at ~39.0, the ball leaves the HAND, rises into the crosshair by
  ~39.3 (0.3 s), sits on it (a hair above at 39.4) as it flies down the straight, and its marker stays at the far end
  where the ring was (39.5-44.5); a white trail from the hand to the ball. Video 4 at 365.8 s: the charge ring on the
  goal ring, the ball flies into it (GOAL 367.6). Ours: the ball leaves the hand PARALLEL to the crosshair's line,
  ~1 body height under it, so on screen it tops out at the head and never reaches the dot. **Q148**: **the ball lands
  on the crosshair's spot with real gravity**: it leaves the hand on the arc that comes down where the crosshair's
  line meets the arena (or through the goal ring's centre); a full charge flies flat (a floor spot 100 studs out:
  0.64 s, ~1 body height up), a weak one lobs; a spot too far for the charge -> the farthest point of the line it
  reaches, then it falls; the arc dots run into the dot, the landing ring on it. Coupling said: looking level, the
  dot's line climbs 15 deg, so a flat throw needs a slightly lowered look (as RC's player's). Trial first. Not
  chosen: a straight line with no drop until a touch (RC's flat look); aimed at it with gravity after (~28 studs).
- **Trial 148, Q149** (session 58). Trial 148 (Studio copies): Q148 as chosen; in Play a full throw with the view
  15 deg down (the crosshair's line level, meeting the curved end's floor 177 studs out) flew a 36 deg lob 6.5 body
  heights high and came down 1.7 studs from the spot after 1.3 s; the arc's dots ran from the hand into the dot,
  its ring on it (the dot cap raised 40 -> 100 for long lobs). The owner played it: "just remove the arc trail
  entirely, and make the throw not in a arc, but more flatter and direct, the arc trail is confusing and not in RC
  anyways". So: **the predicted arc goes** (Q98's arc part reversed: neither RC nor Illegal Soccer has one); **a
  throw flies flat and direct at the crosshair's spot**. Read: the trail BEHIND a thrown ball stays (RC draws one:
  Video 4 at 366.6-367.8, Video 31 at 39.1). Trial 149 (Studio copies): the ball flies STRAIGHT from the hand at the
  spot, its weight cancelled by the pass's lift until it first touches anything (then real physics), the carrier's
  share kept on that line; measured in Play: a full throw (168 studs/s) stayed on the line (0.00 studs off) and
  reached the spot 33 studs out in 0.20 s, a tap (72) in 0.47 s.
- **Trial 149, Q150** (session 58). The owner played trial 149 (dead straight, no drop until a touch): "add drop,
  not like that in direction direction, remember we want real physics, gravity, etc..., like RC". So: **real
  gravity, a visible drop**, yet flatter and more direct than trial 148's lob (Q149). With real gravity a flatter
  flight means a faster throw (RC's ball reaches the far end of Video 31's straight in ~1 s); RC's own ball gravity
  is not measurable in the clips at hand (Video 3's replays: short throws, cuts, maybe slowed). Trial 150 (Studio
  copies): trial 148's throw landing on the crosshair's spot under real gravity, the predicted arc removed, the
  ChargeThrow speeds 60-160 -> **90-240 studs/s** (Roll Ball shares them). On paper at 240: a spot 100 studs out =
  6 deg, 0.4 body heights up, 0.42 s; 177 out = 14.8 deg, 2.4 body heights, 0.76 s. Measured in Play: a full throw
  down the straight at 13 deg rose 12 studs (2 body heights) and came down 2.4 studs from the spot 174 studs out
  after 0.73 s.
- **Q151 trial 150 kept** (session 58, recommended): **"Keep it, build it"**: a charged throw leaves the hand on
  the real-gravity arc that comes down on the crosshair's spot (where its line first meets the arena, or the goal
  ring's centre when it passes the opening; out of the charge's reach, the farthest point of that line it reaches),
  at 90 studs/s for a tap to 240 for a full charge (Roll Ball the same); no predicted arc; the trail behind a thrown
  ball stays. Built on #313's PR #334 as a second commit. Not chosen: faster (~300); slower (~200).
- **Q152-Q153 the Dive after a Dodge with the ball** (session 59, #314). RC first (Video 33 at 5 frames a second,
  16.0-19.6 s): charging 16.2-17.0, a Cancel & Dodge at ~17.0, the Dodge hint reads "Dive" at 17.2-17.4 (pressed at
  17.4), the dive in the air at 17.6, on the belly 17.8-19.0 sliding to a stop, every hint back at 19.2, "Charge
  Throw" lit throughout (the ball kept); no opponent near, so the clip cannot show a strike or a tackle. Ours: a
  dive's belly slide is a knockdown, which drops a carried ball and makes the player untouchable. **Q152** (not the
  recommended): **the carrier's dive knocks down an opponent it reaches, like the Tackle's Dive** (11 studs, homing),
  and the carrier keeps the ball. Not chosen: an escape that hits nobody. **Q153** (recommended): **a carrier sliding
  on the belly after that dive can be tackled like any carrier**, which knocks the ball loose. Not chosen: today's
  rule (nobody on the ground can be hit), which with the Dodge's 0.3 s would leave ~2 s nobody could take the ball.
- **Q154 a throw during the carrier's dive** (session 59, #314, recommended). RC (Video 33 at 17.6-19.0 s): while
  the carrier flies in the dive and slides on the belly, every hint is greyed but "Charge Throw", which stays lit (no
  throw from the belly is shown, so that it works there is not proven). Ours: no action until the skater is up.
  **Q154**: **yes, like RC's lit hint**: during their own dive and belly slide the carrier's throw key charges and
  throws as usual; Roll Ball, Pump and Jump stay off (RC greys them). Not chosen: throw once up.
- **Q155 no Magnetic Pass through an obstacle** (session 61, #315, the owner's words during #315's 2-player Play
  check, where a pass at a teammate on the other straight met the passer's own inner bank 7 studs out and rolled back
  loose): "passing through the middle glass shouldn't be possible, so don't show the R icon above players when there
  is an obstacle between them". So a teammate is a Magnetic Pass's target only while the line between the two
  skaters is clear of the arena (its floors, banks, walls and glass, the middle glass above all): otherwise no pass
  key's letter over them, the hint greyed, the key does nothing, and the server refuses such a pass too. Read as a
  ruling (not asked): players are no obstacle, so opponents can still step into a pass on its way (Q129).
- **Q156 diagonal climbs hold their line** (session 61, #326, recommended). RC (Video 4 at 343.4-344.9 s, 10 frames
  a second): a skater rides diagonally up from the track and along Pixel City's outer wall (its solid barrier only
  about a body height, the ride along the glass above it) for ~1.5 s, then back down. Ours (worked from SkateMath's
  wall case, s61 climb326.py): holding the stick diagonally up the upright grey wall (40 studs, 6.8 body heights) at
  cruise, a ride 30/45/60 deg up peaks 0.4/1.0/2.2 body heights up and arcs back; only rides steeper than ~72 deg reach
  the glass's foot (the stick turns at most 1 rad/s on walls, gravity bends a 40-studs/s ride up to 3.3 rad/s).
  **Q156**: **hold the line**: while the stick pushes up a grey (solid) surface, a diagonal ride keeps its angle at
  the climb speed instead of bending down, so 30-60 deg rides reach the glass's foot in 1.2-2.0 s; on the glass, real
  physics again (it arcs back down). W straight at the glass still stops there; the glass gets no climb. Not chosen:
  the stick steering uphill 3.5x faster on grey walls (a path curling up). Next: a playable Studio trial.
- **Q157 trial 326 kept** (session 61): the owner played trial 326 (Studio copy of SkateMath: while the stick
  pushes up a solid surface, gravity's part across the heading is dropped; its part along the heading still slows
  the climber, topped up by the climb as before; the glass unchanged) on the outer wall, the middle wall's bank and
  the bump, and W straight at the glass: **"Keep it, build it"** (test-first, as trialled).
- **Q158-Q160 the team-coloured ball** (session 62, #327, all recommended). RC first (Video 31 at 10 frames a
  second, full resolution): the ball dropping in at GO is neutral (white and dark, in a white marker ring, 27.2 s);
  caught at ~27.7 s by the owner (Orange), it shows orange-red with a yellow glow in the hand by 27.8 s; thrown at
  ~39.1 s it flies orange inside an orange ring, a white trail behind it; 8-10 s later (47.4-48.8 s) it still rolls
  loose orange with an orange ring until picked up again. So RC colours the ball by the last team that held it. Ours:
  the ball always warm yellow (the Default skin); its marker ring and arrows already take the last team's colour
  (white after a kickoff). **Q158**: **the ball wears the colour of the team that last held it**, carried, flying and
  loose, on every screen, until the other team picks it up; neutral from a kickoff until the first pickup; it changes
  the moment the pickup happens. Not chosen: only while carried. **Q159**: **the neutral ball is white, like RC** (the
  Default skin; yellow sat close to our orange). Not chosen: keep yellow. **Q160**: **the thrown ball's trail stays
  white, like RC** (the ball itself shows the team). Not chosen: the team's colour.
- **Q161-Q162 the stride and the carrier** (session 62, #328). RC's flat speed could not be measured by frames and
  body heights in the clips at hand (Video 13 at 47.9-49.8 s and 55.6-56.0 s: the camera moves with the skater and
  looks along the motion, or the floor's only marks are wood grain), so it is decided by playing. **Q161**
  (recommended): **trial the stride's top 10% faster: 51 studs/s** (8.7 body lengths a second; today 46, 7.9), its
  push 30 -> 33 so the top still comes in ~1.8 s; pumping, slopes, dives, climbs and the caps unchanged. Not chosen:
  +20% (55); +5% (48). **Q162** (the owner's words): "ignore this issue, all players the same speed": **no slower
  carrier**; Q137's debuff is dropped. Not chosen: 5/10/15% under the others.
- **Q163 trial 328 kept** (session 62): the owner played trial 328 (Studio copy of the movement settings: the
  stride's top 46 -> 51 studs/s and its push 30 -> 33, so the top still comes in ~1.8 s; measured in Play: 51.0
  steady, 98% of it at 1.77 s; every player the same speed, Q162): **"Keep it, build it"** (test-first, as trialled).
- **Q164 the straights' length** (session 62, #329, recommended). RC's straight-to-end proportion could not be read
  cleanly (the only overhead view, Video 4's flyover at 3 s, is oblique: the far rail and the ends sit at different
  depths). Ours: each straight 200 studs (34 body lengths), a lap along the spawn lane ~13.5 s at #328's stride.
  **Q164**: **trial straights of 260 studs (+30%, 44 body lengths)**, the curved ends unchanged (Q136): a lap ~897
  studs, ~15.6 s; the gates, lap markers, spawns, drop-in spots, the goal's place and the beams move with it. Not
  chosen: 240 (+20%); 300 (+50%). Next: trial 329 in Studio copies.
- **Q165 trial 329 kept** (session 62): the owner played trial 329 (Studio copy of the arena settings: both
  straights 200 -> 260 studs, the curved ends unchanged; the gates, lap markers, the goal beside gate 2, the spawns,
  the drop-in spots and the beams moved with them; 12,772 parts built): **"Keep it, build it"** (test-first).
- **Q166-Q168 a throw drops with distance** (session 62, after #328; changes #313's Q148/Q151 rule). The owner's
  words: "about the ball throwing, I noticed, that whereever the crosshair aims, the ball hits that, but that
  shouldn't be the case, it should also depend on the distance, like if the player is aiming at something far away,
  the ball should have more drop, so the player needs to aim higher to hit the target". Told first: RC's throw down
  Video 31's straight (38.5-40.5 s) did land on the crosshair. The owner recorded **Video 35** (RC, throws at the goal
  from several distances, 1:07, 1918x1078, 30 fps): `D:\Screenshots\Videos\Screen Recording 2026-11-01 211344.mp4`
  (not yet studied frame by frame: next session). **Q166**: **the farther, the more it falls** ("and watch the video
  if it is going to correct something or you notice something"): close throws land almost on the crosshair, far ones
  fall below it more and more (read as: the ball leaves the hand straight at the crosshair's spot at the charge's
  speed, 90-240, and real gravity pulls it down from there; full charge ~0.5 body height under at 50 studs, ~1.9 at
  100, ~6.1 at 177). Not chosen: exact within ~50 studs then falling; copying the video without a rule. **Q167**:
  **the aim still corrects for the thrower's own motion** (the ball keeps half the carrier's speed and still leaves
  heading at the spot). Not chosen: no correction. **Q168**: **built right after #329** (its own issue, a playable
  trial first, before the playtest record #317). Not chosen: now, before #329.
- **Video 35 studied** (session 63, #342; RC 'Fallen Stadium', the owner's full-charge throws; 2 frames a second
  throughout, 10-15 at each throw, full-resolution crops round the crosshair (959, 342), s63\v35\): **throw 1**
  (released ~5.97 s, aimed across the curved end at the far side): the ball rises from the hand to the crosshair's
  height 0.3 s after the release, sits ~10 px above it (6.33-6.53), crosses back under it at ~0.75 s and is ~50 px
  under it by 1.3 s; "Lap 1 Completed" at 6.93 while the thrower stood still: the thrown ball through the lit marker
  counts the lap (ours already counts the ball's own path, MatchEngine.ballMoved). **Throw 3** (released ~44.73 s,
  aimed dead centre at the goal ring far down the straight, worth +3): the ball sits on the ring for ~0.8 s, then
  sinks under it (45.6-46.0) and lands under the ring (~46.1-46.3): a miss. **Throw 4** (released ~58.1 s, aimed at
  the goal from across the curved end, ~1.6x nearer by the ring's size on screen): on the ring the whole flight, in
  at ~58.95 (0.85 s): GOAL, +3. So RC's full-charge throw is exact out to about 0.8 s of flight, then falls under
  the crosshair more and more; its flight looks flat (only ~10 px above the crosshair). Also seen: the goal shows its
  current worth on its housing ("+1", "+3"); a "Lap n Completed" caption and a fiery streak on each lap (Presentation).
- **Q169 the throw is exact, then falls** (session 63, #342, recommended; refines Q166): **a charged throw comes down
  on the crosshair's spot when it gets there within ~0.8 s of flight** (a full charge, 240 studs/s: ~190 studs, 33
  body lengths, most of a straight); **a farther spot: the ball flies the same arc through the point that far along
  the crosshair's line and goes on falling under the line** (full charge, aimed level: 1.8 body heights under at
  230 studs, 3.6 at 260, a whole straight, 6.6 at 300), so far targets need a higher aim; weaker throws stop being
  exact sooner. A playable trial first. Not chosen: falls from the start (Q166 as first read: straight at the spot,
  then gravity from the hand: 1.9 body heights under at 100 studs, 7.8 at 200; RC's goal at ~0.85 s would have
  missed by ~8); keep it always exact (today).
- **Q170 trial 342 kept** (session 63): the owner played trial 342 (Studio copies of Ball/Trajectory and
  Actions/Throw: a charged throw comes down on the crosshair's spot when it gets there within 0.8 s of flight; a
  farther spot, the arc through the farthest point of the crosshair's line it reaches within 0.8 s, falling on past
  it; measured in Play at a full charge: a floor spot 101 studs out hit, a wall spot 224 out hit 12.6 studs, 2.2 body
  heights, under it): **"Keep it, build it"** (test-first, as trialled).
- **Q171 the Ball & rules playtest, alone** (session 64, #317; the published stack head 494333e, 09:19:15Z, in the
  Roblox Player at Camera Sensitivity 1; AskUserQuestion in four groups, each with RC beside ours): start and scoring
  (the on-screen count and GO <TEAM> TEAM! #307, the drop-in #321, +1/+3/+5 after 1/2/3 laps from the goal's gate
  #305, the 7:00 clock #306, a loose ball stays #308), the ball (2 studs low in the right hand, the 0.2 s magnet,
  the rolling slow-down #311, smooth on every screen #316, no bobbing #337, the last holding team's colour, white
  until then, a white trail #327), throwing (the 0.5 s charge, the ring a third down blinking every 0.4 s, no pump
  or pass while charging, Cancel & Dodge, Roll Ball #312, exact to ~0.8 s of flight then falling #313/#342, the
  Dodge -> Dive keeping the ball and throwing from the belly #314) and skating and the arena (the diagonal climb
  #326, the stride 51 #328, the 260-stud straights #329): **"Feels right"**, all four. Next: the two-player items
  (the Magnetic Pass #315, switching team #310, leavers #309, Last Chance and overtime #306).
- **Q172 the playtest's two-player round** (session 64, #317; a 2-player Studio test, the owner Player2 and my bot
  Player1, the clock shortened in Studio's copy only to 1:40 + 1:10, restored after): the bot switched team both ways
  with T on the open tab (#310); the Magnetic Pass to the bot: the key's letter over it, greyed aiming away or through
  the middle glass, Switch team greyed while holding the ball (#315, #310); overtime at 0-0 with its 60 and 30
  SECONDS banners and a draw at its 0:00 (#306, Q95, Q107); Last Chance: the bot scored +1 (a lap from the goal's
  gate), the owner held the ball at 0:00 (LAST CHANCE), scored 1-1 and overtime began (Q94); the bot left: its row
  gone at once, Orange kept its point (#309, Q96): **"Feels right"**, all of them. One finding, measured: a pass
  released on the straight's rise (~32 deg) died: the carried ball's bottom sat 0.14 studs inside the floor, so the
  pass touched it at once (its lift off 0.02 s after the release) and rolled away, 50 studs from the receiver; on
  flat floor the ball sits 0.74 clear (that pass was caught in 0.37 s). A bug, its own issue, fixed test-first.
- **Q173 a slightly faster Magnetic Pass** (session 64, the owner's words while Connecting Rojo for #345): "after
  fixing this bug, can you make the magnetic pass just a little [faster], the reason for it, is I want to give the
  players more room to pass accurately when the player that is getting the magnetic ball from a pass where he is in
  a high speed to get the ball accurately, and not just the ball miss his place, just a little more speed I guess, we
  still want high speedy players going left and right have a chance to miss the magnetic pass ... RC is like that,
  players most of the time get the ball, but can still miss it if they leave the place where the other teamate have
  passed to them too fast". So: a little faster than today's 100 studs/s (homing 150, Q139), so a fast receiver
  holding their line catches it; one cutting away hard can still miss. Its own issue after #345, a playable trial.
- **Q174 the pass trial's finding** (session 64, #346; trial 346, the pass at 120 studs/s, Studio copy, a 2-player
  test with my bot weaving at full stride and passing back): the owner: "can we try to predict where the player is
  going to move based on his movements, and try to fix the ball trajectory?, currently it is missing quite often ...
  take a thorough look, never speculate". Measured (a server recorder, 40 released passes): 24 caught, 15 missed;
  every miss touched the arena first (10 a floor or bank, 5 the glass), which ends a pass's steering; in 13 of the 15
  the receiver turned 88-159 deg during the flight (round a curved end, a hard cut); the server's view of the
  receiver's velocity matched their motion (a few studs/s, 2-22 deg); the ball sped up to 180-240 studs/s by its
  closest approach (homing adds 150 studs/s^2 toward a straight-line lead), so it turns slowly late on; 3 passes lost
  their steering in their very first frame (cause not yet traced). **Q174** (recommended): **predict along the
  receiver's curve** (their turning now), **steer by turning the ball at a steady speed** instead of speeding it up,
  **aim at the chest** so it does not graze floors and banks; first replay the receivers' real paths in Studio to
  show how many each change would have caught, then a playable trial. Widens #346.
- **#346's replay** (session 65): a fresh 2-player test at today's pass (100, homing 150), the owner Player1 and my
  bot weaving lanes 20/36 at full stride; a server recorder kept every frame (443 s, 52 released passes: 26 caught
  clean, 10 caught after touching the arena, 15 missed, 1 back to the passer). Session 64's first-frame losses traced:
  9 of 52 passes touched the floor or a bank within 0.12 s, because the ball leaves the low hand (0.8 under the root,
  0.06-1.0 studs off the floor) on a straight line toward the receiver's root that dips into the floor or a bank's
  rise at once. A replay harness then stepped pass models frame by frame over the receivers' real paths against the
  real arena (it reproduced 50 of the 52 real outcomes); 1,414 passes (the 52 + one every quarter second between the
  two players): **today 64% caught clean** (32% touched a floor or bank, 4% the glass); curve prediction alone 66%;
  turning at a steady speed (no speeding up) 75-78%; + aiming 1.5 above the root (the chest) 83%; + letting go at root
  height (0.8 above the hand) 86%; curve prediction on top gave nothing (81-83%: weaves reverse within the window).
- **Q175 the pass to trial** (session 65, #346, recommended): **a steady 150 studs/s** (RC's ~4 body lengths in
  0.15 s, Video 34; today speeds up from 100 to 200+), **turning toward the receiver** at most 300 studs/s^2 sideways
  instead of speeding up, **aimed at the chest** (1.5 above the root) and **let go beside the chest** (0.8 above the
  hand); **no curve prediction** (measured: no gain). Replay: 90% caught clean (today 64%), arriving in 0.22 s within
  10 body lengths, 0.48 s at 10-15, 0.69 s at 15-20 (today 0.26/0.51/0.64); a receiver turning more than a right angle
  within 0.6 s still misses 1 in 5 (today 2 in 3). Not chosen: the same at 160 (91%, a touch quicker) or 140 (90%,
  slower far); keeping the speeding-up pass with the chest aim and the higher release (79%, quickest). Next: a playable
  trial in Studio copies.
- **Q176 trial 346b kept** (session 65): the owner played trial 346b (Studio copies: a steady 150 studs/s pass
  turning toward where its receiver will be at most 300 studs/s^2 sideways, aimed 1.5 above their root, let go 0.8
  above the hand, clear of the arena) in a 2-player test with my bot weaving at full stride: **"Keep it, build it"**
  (test-first, as trialled). Recorded (the same server recorder): 42 released passes in 117 s, **37 caught clean
  (88%)**, 1 caught after touching the arena, 3 missed, 1 back to the passer (before, at today's pass: 26 of 52
  clean, 50%); clean catches in 0.20 / 0.49 / 0.77 s within 10, at 10-15 and 15-20 body lengths; 2 of the misses
  touched the glass at the release (the passer skating along it).
- **Q177 the built pass played** (session 65, #346's Play check, logged in session 66): the owner played the built
  code (not the trial) in a fresh 2-player test with my bot weaving at full stride: **"Same as the trial"**. Recorded
  (the same server recorder): 72 released passes in 169 s, **70 caught clean (97%)**, 1 after touching the arena, 1
  missed; 2 first touches on a floor (both within 0.15 s of the release), none on the glass; clean catches in 0.24 /
  0.56 / 0.75 s within 10, at 10-15 and 15-20 body lengths. Built as PR #348 and published (65adf98, 17:50:59Z).
- **The Ball & rules part's end-of-part review; Q178-Q180** (session 66, AskUserQuestion, plain words, all
  recommended). The review (Standards + Spec, main bfc0e1d -> 76ea830) found a Dive with the ball no answer allowed and
  two points no answer settled. **Q178**: **a Dive keeps to the move it follows**: after a Tackle only with empty
  hands, after a Dodge only while holding the ball (#314 said "no Dive with the ball without a Dodge first", yet a
  Tackle, a magnet catch and the key within 1 s dived holding it); so a Dodge then a throw gives no Dive (the key
  tackles). RC's clips show neither case. Not chosen: block only the ball case. **Q179**: **the kickoff count stays at
  the banner's place** (its centre 200 px from the top, about a fifth down at 1080 px; RC's a third down, Video 31,
  where our always-shown crosshair dot sits) until the Presentation part's HUD redesign places it with the dot (Q55)
  and the ring/scoreboard overlap (#333). Not chosen: RC's third now. **Q180**: **no live play of 65adf98 needed**
  before the review's fixes and the merges (the built #345/#346 were played in Studio, Q177). Not chosen: play it now.
- **Correction to Q116** (session 66, from the ledger's trial log): trial 2 as run started 105 studs up (lateral 72
  outer / 6 inner) and fell a steady 40 studs/s (not ~102 and 42), first touch 2.0 s (outer foot) / 2.3 s (inner bank);
  the build matches it (#321's Play check: 2.13 / 2.45 s); since #311's 2-stud ball it starts at 106 (the lip less the
  ball's width).
- **The Presentation part's grilling, round 1; Q181-Q183** (session 67, AskUserQuestion, after the Ball & rules
  stack's merge OK). **Q181 scope** (my list of 7: the HUD redesign on desktop and phones with #333, Q55, Q143, the
  kickoff count's place; the lap and goal captions incl. the goal's worth on its housing and a fiery streak per lap;
  the goal sequence GOAL! -> replay -> celebration -> kickoff; the intro flyover with the skaters' names and the
  kickoff camera; the end-of-match podium; the drop-in's look; the default camera pitch so a level throw flies
  flat): **all 7**, in the owner's words: "I want the HUD and everything to be modern, animated, and most importantly
  clear and big text specially on mobiles, because largest users in roblox are in mobiles, and it needs to be clear
  and modern, just like RC and illegal soccer in roblox, and also control hints, coldown, hints on what the user
  pressed, and it needs to be well adjusted in mobiles". So the HUD is mobile-first (big, clear text), animated, and
  its control hints also show cooldowns and which key was just pressed. Sound, music, art, stadium/crowd stay in the
  later milestone. **Q182 order** (recommended): **the HUD first**, then the captions, the goal sequence, the
  intro/kickoff cameras and the podium, the drop-in and the camera pitch last; each piece RC's (and IS's) frames
  beside ours on a private page first, a playable Studio trial where it is about feel, then built test-first.
  **Q183 the look**: not RC's layout alone: "it should be a combination of all, mix between RC and IS, and our arts
  specially": each piece picks from RC and Illegal Soccer, drawn in our own art (our name, logo, fonts, colours;
  never Ubisoft's or IS's art).
- **HUD round 2; Q184-Q187** (session 67, AskUserQuestion beside the private page
  https://claude.ai/artifact/AzDJLnLXcTPeyuaZ4pvi7a: RC Videos 4/31-34 frames, IS 0:11/0:40, ours, and three looks
  drawn over our game at desktop and the 750 x 381 phone emulator). **Q184 the look**: **C Bold arcade** (chunky
  rounded shapes, thick dark outlines and drop shadows, Fredoka with Luckiest Guy banners; not the recommended A
  Broadcast glass). **Q185 the crosshair**: **RC's way** (nothing at the centre without the ball, a small ring with
  the dot while carrying, the charge ring while charging; the kickoff count a third down where RC's sits, never
  touching the scoreboard: #333), and in the owner's words: "can you give me more crosshair iterations? also I think
  the crosshair follow the team color, and indicator of the score the team can score like +1, +3, +5, depending on
  the laps, so keep that c mockup and have more iterations on the top scoreboard, more designs, and also what about
  the TAB scoreboard, give me designs about it". So next: crosshair iterations in the team colour (this replaces
  Q141's white) with the goal's current worth (+1/+3/+5) shown by it; more top-scoreboard designs in look C; TAB
  scoreboard designs in look C. **Q186 feedback** (recommended): **as drawn**: the pressed key pops with RC's orange
  >> beside it, a key on cooldown fills back clockwise with the seconds left on it, an unusable one greyed; the same
  on phone buttons. **Q187 phones** (recommended): **no hint column on phones** (the buttons with big labels are the
  hints), Jump big bottom right with the actions in an arc round it, Roblox's stick bottom left, the scoreboard
  compact at the top, the speed small top left; placement tuned in a playable Studio trial on the phone emulator.
- **HUD round 3; Q188-Q190** (session 67, page version 2: five crosshairs, five top scoreboards, three TAB
  boards, all in look C). **Q188 the crosshair**: not chosen yet; the owner's words: "I didn't mean the goal worth
  hint next to the crosshair, I meant it in the top scoreboard, and if you can show me the transition form the
  crosshair to charging crosshair". So the goal's worth (+1/+3/+5) lives in the TOP SCOREBOARD only; the crosshair
  is in the team colour with no worth; next: animated crosshair designs showing carrying -> charging (0.5 s) ->
  full (blinks) -> release. **Q189 the top scoreboard** (recommended): **S4 Two tiers on desktop** (scores round
  the clock on top; under it a four-gate lap meter filled by the possessing team with the goal's worth chip at its
  end) **and S5 Compact chips on phones** (score chips round the clock in one short row, the worth chip glowing
  beside the possessing team). **Q190 the TAB board** (recommended): **T1 side by side** (an Orange and a Blue
  panel, the team score in each header; rows: avatar, name, score, goals, assists, saves, steals; the viewer's row
  outlined; the Switch team row under the table; on phones from the score button, scrolling if needed).
- **Q188b the crosshair** (session 67, page version 3: five designs animated carrying -> 0.5 s charge -> full,
  blinking -> thrown, in both team colours, no worth beside it): **X1 Classic ring** (the recommended): RC's small
  carrying ring with the dot, in the team colour (replaces Q141's white), growing into the charge ring; in the
  owner's words: "jsut try to connect the two halves at the bottom when they start connection, currently one is
  overlapping with the other and it shows that they are not in continuation and one circle". So the charge grows
  both ways from the bottom as ONE continuous stroke, no seam and no bottom gap (today's game keeps #312's 29-px
  gap at the bottom and the top: the top gap closes last); page version 4 shows it.
- **HUD round 4; Q191-Q194** (session 67, asked in words; all recommended). **Q191 banners**: **yes**: GO <TEAM>
  TEAM!, LAP n COMPLETED, GOAL!, DENIED!, 60/30 SECONDS, LAST CHANCE, OVERTIME and "<Team> goal is active!" in look C
  (Luckiest Guy, white with a thick dark outline and a team-colour edge) at RC's places (GO and GOAL ~22% down, the
  lap caption just under the scoreboard, "goal is active" at the bottom centre), popping in with a quick overshoot,
  holding, floating up as they fade; on phones ~1.3x their share of the screen. **Q192 the speedometer**: **yes**:
  big outlined digits in the team colour with a small KM/H, bottom right on desktop, small top left on phones, the
  number easing. **Q193 phone buttons**: **big text labels now, icons with the art milestone** (icons need image
  assets the owner uploads). **Q194 motion**: **yes**: every HUD change animates briefly (0.15-0.25 s: pop/slide
  in, a score change bounces, the lap meter fills smoothly, greyed keys fade, cooldowns sweep), from settings, no
  per-frame redraw of what does not change. With each: the owner's standing rule, "always show me in the artificat
  page, so I can visualize" ("Yes, show me" on Q192 and Q194): every look or motion is drawn, animated, on the
  private page before it is asked or built (memory feedback-show-on-artifact-page.md).
- **Q195 the whole HUD, animated** (session 67, page version 5: the picks so far on one 10-second loop, desktop
  and phone): not yet; the owner's words: "the desktop top scoreboard, is not what I have chosen, I chose S2
  Shields, let me see it also in phone, but I think we can keep that S5 Compact Chips on phone too, but want to see
  shields on phone first". So **Q189 is corrected: S2 Shields on desktop** (each team a big shield with its score,
  the clock between them with the goal's worth chip under it, lap dots under the possessing team's shield); the
  phone is S2 or S5, to be chosen from page version 6 (desktop S2, phone S2 and phone S5 side by side).
- **Q196 and Q195b, the HUD settled** (session 67, page version 6). **Q196**: **S2 Shields on desktop, S5 Compact
  chips on phones** (not the recommended S2 on both), with the owner's note for the build: "for desktop, make sure the
  lap chips are equal height and width, and that the fourth chip gets filled then reset to 0 for the next lap". So
  the four lap chips under the possessing team's shield are squares of one size; the fourth fills at the lap's last
  gate, then all four empty for the next lap. **Q195b** (recommended): **yes, write the HUD's issues** (then the phone
  button trial, then the test-first build), with: "just about the hints with press pop arrows, don't leave a
  predefined space in the controls boxes, make the arrows outside the box, like with the game background and no the
  box". So RC's orange >> of a pressed key is drawn outside the hint's box, over the game, and the box keeps no room
  for it.
- **Q197 the marks over a teammate** (session 67, the owner's question before #352: "what about the pass hint
  on the player request and the hand gesture request, show me visual"; page version 7: M1 Stacked, M2 Bubble, M3
  Ring marker, animated, desktop key F and phone PASS chip): **M1 Stacked** (the name tag, the pass key's cap with a
  small pointer over it, the hand popping in to the key's left while they call), with: "but I don't like the hand,
  do you have better iteration". Page version 8 shows H1 Glove, H2 Badge, H3 Wave and H4 Badge + ripple, each drawn
  as one merged silhouette with one outline (the first hand's parts each had their own outline). Goes into #358.
- **Q198 the call's hand** (session 67, page version 8): **H4 Badge + ripple** (not the recommended H3 Wave): a round
  team-colour badge with a dark rim, a white cartoon glove waving inside, a ring rippling out every second; with:
  "but the hand fingers are not correctly placed". Page version 9 fixes the glove: four fingers evenly across the
  palm's top and rooted inside it (the middle longest, a short little finger), the thumb from the palm's left side
  leaning out, all one silhouette with one outline. It sits left of the pass key's cap in M1 (#358).
- **Q199 the hand stays open** (session 67, after page version 9): the owner, "I still don't like the hand, but we
  will come to it later": H4's place (left of the key in M1) and badge + ripple idea stand; the glove's drawing is
  redone later (with #358 or the art milestone). Next: #352, look C.
- **Q200 the lap chips clear of the shield** (session 69, #352's Play screenshots; the owner interrupted the shots):
  "Just one thing, the lap chips under the shield score are touching the shield, bring them down a bit, just a
  little". The shield's ink (outline + drop shadow, 7 px below its box) overlapped the chips' 3 px outline across the
  6 px gap; now `UI.hud.layout.scoreboard.chipClearance` 3 leaves 3 px of the game between the shield's shadow and the
  chips (the row starts 13 px under the shield's box). The gap between the chips themselves is unchanged.
- **Q201 the HUD's team colours** (session 69, beside page version 10's "Built in the game" section): asked
  whether to ship #352 and which colours the HUD uses (today's #0d69ac / #da8541, the world's, vs the page's
  #3d8bff / #ff9a3c); the owner: "Is it possible to do the lighter color or we cant in roblox? I want the lighter
  one if possible", and picked **Brighter, HUD only** (recommended). So the screen HUD gets the page's brighter pair
  as its own setting (`UI.hud.look.teamColors`, read through Style.teamColor); the arena glow, spawn pads, carrier
  beam, ball, world markers and name tags keep `UI.teamColors`. The brighter shot on the page was the real game code
  with only that colour changed (Roblox shows it fine). #352 ships after this change is shown.
- **Q202 #352 shipped** (session 69, after the brighter pair was built and shown on the new page
  https://claude.ai/artifact/EQmcWw9Ywe8n1GeeUMPBD8, the old AzDJLnLXcTPeyuaZ4pvi7a being the previous account's):
  **"Yes, ship it"** (recommended). Next: #353 the crosshair.
- **Q203 the kickoff count beside a tall scoreboard** (session 70, #353; page version 3's to-scale section: the
  desktop view 1556 x 793, the phone's whole 874 x 401 screen with its 750 x 381 safe area, a 1280 x 600 window,
  over the built S2/S5, animated). Throws aim through the dot, so it never moves: the rings shrink just enough where
  they would come within 3 px of the scoreboard (the phone while OVERTIME or LAST CHANCE hangs under S5: 46 -> 41
  px; a short window). Found while drawing it: overtime can begin with a kickoff (a Last Chance equaliser), and then
  the phone's OVERTIME sits where the count would. **A: the count moves down just enough** (recommended), keeping
  its size (the phone in overtime: 18 px lower, 36% down instead of 31.5%). Not chosen: B, the count shrinks in
  place (to 0.56 there). Sizes as drawn and kept: desktop charge ring 130, carrying ring 61, stroke 4, the count's
  ring 200 with a 76 px digit and an 8 px stroke; phone 46 / 24 / 3, the count's ring 76 with a 40 px digit and a 4
  px stroke; every stroke on look C's 2.5 px ink; the dot 6 px in the team colour.
- **Q204 the count's digit centred** (session 71, #353's built screenshots on the new page
  https://claude.ai/artifact/CJkm6TCEoYNBkti4y6N82t, the earlier EQmcWw9Ywe8n1GeeUMPBD8 being the previous
  account's; asked whether to ship #353): "Just fix one thing, center the number of the countdown in the circle
  currently it feels is a little up from the center of the circle". So the digit's drawn shape sits at the ring's
  centre (a font draws digits above the middle of its text line); fixed in #353 before it ships, then shown again.
- **Q205 #353 shipped** (session 71, after the digit was centred, shown as a before/after close-up on the page:
  Luckiest Guy draws 1-5 0.150-0.165 of the text size high, so `look.bannerDigitRise` 0.16 moves the digit down;
  measured after: within 0.5 px of the ring's centre on desktop, 0 on the phone): **"Yes, ship it"**
  (recommended). Next: #354 the desktop hints.
- **Q206 mouse buttons as mouse icons** (session 73, asked whether to ship #354 as built, shown on the new page
  https://claude.ai/artifact/Rsh5nQcGHQoRbhRrr3RNW1, the earlier CJkm6TCEoYNBkti4y6N82t being the previous
  account's; with four rulings to confirm: the >> 0.3 s vs RC's ~0.13 s, the sweep clockwise from 12 o'clock, one
  orange, the inked >>): not yet; the owner's words: "For LMB and RMB can we show mouse icons with the button
  highlighted show me a visualization in the artificat first to see if that is possible". So the hint caps of the
  mouse's buttons (Focus/Throw on RMB, today lettered "LMB"/"RMB") show a mouse with the pressed button lit, drawn
  on the page first. The phone screenshot waits ("Check my mouse icon request first then ill switch").
- **Q207 the mouse icon: A1** (session 73, recommended; three versions rendered by Studio in the real hint rows on
  the page, built from released UI with no image upload: Roblox ships no mouse-button picture): **a white mouse on
  the yellow key cap, the button filled in ink** (Throw lights the left button, Focus the right; the cap turns
  orange and pops on a press like every key). Not chosen: A2 (the mouse in the cap's own colour, an ink outline, the
  button in ink); B (no cap, a white mouse, the button yellow, orange while pressed, like the gamepad's bare glyphs).
- **Q208 the rest of #354 as built** (session 73, recommended): the >> 0.3 s (the page's; RC ~0.13 s, Video 24), the
  sweep clearing clockwise from 12 o'clock, one orange (#ff8a2c) for the pressed cap and the >>, the >> inked like
  look C's lettering. Not chosen: RC's shorter >>. Next: the mouse icon test-first in #354, the phone shot, the PR.
- **Q209 #354 shipped** (session 74, recommended; the built mouse caps shown on the page
  https://claude.ai/artifact/Rsh5nQcGHQoRbhRrr3RNW1 version 3: the live game carrying, four frozen columns, 3x
  close-ups): **"Yes, ship it"** as built (A1), after the phone screenshot. The owner Connected Rojo and switched
  Studio's emulator to the phone. Next: the phone shot, #354's PR, then #356 the banners.
- **RC banners measured** (session 74, for #356; 15-30 fps crops): Video 31 GO ORANGE TEAM! 22% down (centre ~234 of
  1078), white with an orange edge and a dark shadow, ~35% of the screen wide; it grows in from tiny at 20.93 s to full
  by 21.2 s (~0.27 s, ~2% overshoot) and is gone ~2.5 s after it appeared. Video 4 'Lap 1 Completed' (small, in the
  team colour, ~16.7% down under the pill) fades in over ~0.13 s rising a few px (442.70-442.83 s), holds, fades out
  over ~0.15 s (446.2-446.37): ~3.6 s; 'Orange goal is active!' at the bottom centre (~94% down) from 443.0 to ~447.9
  (~5 s), both captions together.
- **Q210 #356's banners as drawn** (session 74, recommended; the new page https://claude.ai/artifact/UaGHjfHfGuy2QeirmBNZyG,
  the earlier Rsh5nQcGHQoRbhRrr3RNW1 being the previous account's; to scale on desktop 1556 x 793 and the phone 874 x
  401, animated): **"Yes, as drawn"**: one banner line centred 22% down (RC's GO), moved down just enough to stay 3 px
  clear of the scoreboard's lowest ink in play (Q203's rule); GO, GOAL!, DENIED!, 60/30 SECONDS, LAST CHANCE, OVERTIME
  and LAP n COMPLETED on it, the newer replacing the older; '<TEAM> GOAL IS ACTIVE!' on its own line at the bottom
  centre (94% down); white Luckiest Guy, look C's 2.5 px ink outline, a team-colour ring (3 px; 2 on phones; none for
  a banner about nobody), a 4 px ink drop shadow; the board's pop in (0.2 s to 1.12), hold, float up 40% of its height
  while fading over 0.25 s; GO/DENIED!/clock 2.5 s, the lap 3.6 s, the goal message 5 s, GOAL! until the next
  kickoff; desktop 50 px (GOAL! 67, lap 36, goal message 29), phones 32 (43, 23, 18) centred in the stage left of the
  touch buttons; the crosshair draws over them. Not chosen: today's 96 px. **Q211 the feed** (recommended): **banners
  only**: the bottom feed keeps possession and points and sits above the goal message; its lap and goal-open lines go.
- **Q212 the key caps' centre line** (session 75, while #356's desktop shots were taken; the owner's words: "also why
  buttons on the right have a vertical line on the center? don't show that"): measured on the shots, a 1-px dark line
  down the middle of the Space, Shift, A and R caps (not Ctrl, E or the mouse caps). Cause: #354's cooldown sweep is
  two half-clips whose gradient steps from ink to clear exactly on the cap's middle even with no cooldown running, so
  a cap whose middle falls between pixels shows a sliver of the ink (also in a cooldown's second half). **Its own
  small bug fix right after #356** (recommended): each half drawn only while it holds ink, so a key with no cooldown
  draws no sweep. Not chosen: folding it into #356. The mouse caps' line between their buttons is the mouse's drawing
  (Q207's A1) and stays.
- **Q213 #356 shipped** (session 75, recommended; the built banners shown on the page
  https://claude.ai/artifact/UaGHjfHfGuy2QeirmBNZyG version 2, 'Built: #356': desktop and phone Play shots of GO, LAP 1
  COMPLETED with ORANGE GOAL IS ACTIVE! while carrying, and GOAL!; Studio's copy of the banner times held at 30 s for
  the captures only, then restored): **"Yes, ship it"** as built. Next: #356's commit and PR, then Q212's fix.
- **Q214 the Uppercut cap touching its box** (session 75, answering whether to ship #363, shown on the page
  https://claude.ai/artifact/UaGHjfHfGuy2QeirmBNZyG version 3; the owner's words: "why the uppercut button, is
  touching the left border, the yellow box is touching the border"): measured on two Plays of the same build, the
  Uppercut row with the font ready has ~8 px of its box between the border and the A cap; in a Play whose hint
  widths were measured before Fredoka One loaded (Space's cap 52 px instead of 59) the row is too narrow, the real
  'Uppercut' is wider than its row and pushes the cap onto the border. That is #364 (filed the same session), not
  #363. **Q215** (recommended): **ship #363 as built, then fix #364** test-first and show the Uppercut row
  before/after. Not chosen: hold #363 until #364 is built.
- **Q216 three asks after playing** (session 76, given with the cold-start restart for #364's last check; the
  design page moved to https://claude.ai/artifact/H6nXzFP8Q6MKyA6gWjux5y, the earlier UaGHjfHfGuy2QeirmBNZyG being
  the previous account's). The owner's words: "keep the hint controls when a user clicks something active, like when
  user keeps clicking on the pump, we keep showing the arrowws hint and the pressed button, same for other actions
  that can be holded, and second, don't disappear action when that action is clicked, for example uppercut, don't
  disappear it, but just either show a coldown or gray it out, same for the dive, and finally, the get up hints and
  the player has the ball text, update them also with out new HUD/UI, take a thorough look". So: (1) a key held down
  keeps its cap pressed and its >> showing for as long as it is held (today the press pops for motion.press only);
  (2) an action's row never vanishes after its use (the Uppercut in the air, the Dive): it stays, greyed or sweeping
  its cooldown. RC does the same (this file: in the air RC greys Uppercut, Pump and Brake, Videos 10-11; through a
  carrier's dive every hint is greyed but Charge Throw, Video 33; knocked down every action is greyed), and Q186
  already chose 'an unusable one greyed'; ours hid rows by context since before #354; (3) the Get Up prompt and the
  event feed (the possession line) in look C. Each its own issue, drawn on the page first.
- **Q217 their order** (session 76, recommended): **right after #364**, before #357, #358 and #355 (they refine the
  hint rows #354 built). Not chosen: after the HUD issues.
- **Q218 #364 shipped** (session 76, recommended; shown on the page
  https://claude.ai/artifact/H6nXzFP8Q6MKyA6gWjux5y version 2, 'Hint rows measured with the real font': session
  75's two Plays, a Play with the fonts held back by a Studio-only patch (before: Space 52, Shift 45, Ctrl 38, the A
  cap on Uppercut's border; after one redraw 59/50/45, every cap 8 px in), four normal desktop Plays incl. the first
  after a Studio restart (the same widths from the first frame) and the phone): **"Yes, ship it"** as built. Next:
  #364's commit and PR, then Q216's three asks drawn on the page.
- **Q219-Q222, Q216's asks as drawn** (session 76; page https://claude.ai/artifact/H6nXzFP8Q6MKyA6gWjux5y version 3,
  'Held keys, rows that stay, and the Get Up prompt and feed in look C': one 16 s moment animated, today beside the
  proposal, desktop 1556 x 745 and phone 874 x 401, with the game's timings). **Q219 held keys** (recommended):
  **every key** shows pressed (the orange cap and the >>) for as long as it is held, and a quick tap still pops for
  motion.press. Not chosen: only the hold actions. **Q220 rows stay** (recommended): **as drawn**: every row stays
  while there is a skater; one that can do nothing now is greyed, sweeping its seconds while it cools (Uppercut, Pump
  and Brake in the air; everything but the throw/Focus while diving or knocked down; Pump and the pass while a throw
  charges), the touch buttons the same. Not chosen: only after their use. **Q221 the Get Up prompt and the feed**:
  **Option 2, banner style** (not the recommended boxed Option 1): no box, bigger look C key caps and 'GET UP!' in
  Luckiest Guy with look C's ink outline and drop shadow; the feed's lines as small look C chips with a team-colour
  edge, the name in the team's colour. **Q222 details** (recommended): **keep both**: the Attach row shows only with a
  teammate right ahead (an offer); a greyed row is named for the action it would start, else the one still running
  from that key (the Dive through the dive), else its usual one (Tackle, Uppercut, Call). Not chosen: Attach always
  shown, greyed.
- **Q223 #367 shipped** (session 76, recommended; page https://claude.ai/artifact/H6nXzFP8Q6MKyA6gWjux5y version 4,
  'A held key stays pressed': in a real Play Shift held for seconds kept Pump's cap orange with its >>, back to
  yellow when let go): **"Yes, ship it"**. Next: #367's commit and PR, then #368 (rows stay).
- **Q224 #368 shipped** (session 77, recommended; the design page moved to
  https://claude.ai/artifact/XWrav5BHeWqVQ8eebfqrP9, the earlier H6nXzFP8Q6MKyA6gWjux5y being the previous account's;
  section 'Rows and buttons stay, greyed or cooling': Play shots of an Uppercut's leap, a carrier's dive, knocked down,
  and the phone's buttons in the air and knocked down; asked with one ruling to check: while attached to a teammate,
  Jump, Pump and Brake grey too, because the skates do nothing there): **"Yes, ship it"**. Next: #368's commit and PR,
  then #369 (the Get Up prompt and the feed, banner style).
- **Q225 the feed's edge and its box** (session 78, the owner's interruption while #369 was being finished; they had
  seen Option 2's chips built): "for the player has ball feed remove the team color border on the left and can i see
  version without the background banner". So the feed's team-colour edge goes (the name's colour stays, as Q221 chose),
  and a version with no box behind the words is shown on the page beside the chip, over the real game, before it is
  chosen.
- **Q226 the feed's look** (session 78; the page https://claude.ai/artifact/XWrav5BHeWqVQ8eebfqrP9, section 'The "has the
  ball" line', Play shots over the real game, desktop and the phone's text size; the recommended was C, no box at 22 px):
  **A: the chip with no edge**: the look C box all in look.box, the name in its team's colour and the rest white, at the
  chip's sizes (18 px, 15 on phones). Not chosen: B (no box, 18 px), C (no box, 22 px). This corrects Q221's team-colour
  edge.
- **Q227 the feed's motion, and one ball line at a time** (session 78; the page's 'Built #369' section drew today's instant
  chip beside a pop in 0.2 s and fade out 0.25 s; recommended): **yes, as its own small issue right after #369**, and in
  the owner's words: "make sure also we don't spam the player has ball feed, only one at once if carrier changes very
  fast and the recent ball feed still there it fades and new one come". So at most one possession line shows: a new
  carrier's line pops in while the previous one fades out.
- **Q228 the owner's question about the prompt's keys** (session 78, with Q227): "is it showing key caps based on the user
  controls or is it hardcoded zqsd because many players can also have wasd". Answered from the code: not hardcoded (see
  the answer given that turn; Hud's moveKeys reads the binding's KeyCodes and names them by the player's own layout).
- **Q229 #369 shipped** (session 78, recommended; the page's 'Built #369' section: desktop and phone Play shots, with two
  feed lines and alone; asked with one thing to check: the prompt moves up to stay clear of the chips, where the earlier
  drawing overlapped them): **"Yes, ship it"**. Next: #369's commit and PR, then the chips' pop and fade with one possession
  line at a time (Q227), then #357, #358, #355.
- **Q230 the owner's question before #369's merge** (session 78): "did we test the get up prompt and the player has ball with
  other prompts that is their place? Like for example the orange goal active prompt". Not in Play until then; measured
  then in Play, desktop 1556 x 793 and phone 750 x 381, shots on the page ('With everything else on screen'): prompt to
  goal message 17.5 px (phone); with two lines, prompt to chips 3, chips to message 3.5, LAP banner to prompt 377.5
  (desktop), 98 (phone); with five lines, 248.5 (desktop), and on the phone the prompt overlaps the LAP banner by 13 px;
  an open score tab covers the prompt's top half.
- **Q231** (recommended): **ship #369 as it is**; the one-line rule (Q227) removes the five-line overlap, tested there; the
  score tab's overlap goes to #357, which rebuilds the tab. Not chosen: fixing both inside #369.
- **Q232** (recommended): #372's commit says "3 survivors" where 2 survived and 3 gaps were foreseen: **corrected in the PR
  text now and in the squash message at merge**, no force push (the auto-mode check had refused the amend and force
  push). Not chosen: amending now.
- **Q233 #373 shipped** (session 78, recommended; the page's 'One ball line at a time, and chips that pop and fade' section: a
  looping drawing at the game's timings, a frame-by-frame strip of the real chips, the worst stacks in Play; asked with two
  rulings to check: at most 3 lines (a fourth pushes the oldest out), and a wider old chip showing past a narrower new one for
  the 0.25 s swap): **"Yes, ship it"**. Next: #373's commit and PR, then #357 (the TAB board, also not cutting the prompt in
  half, Q231), #358, #355.
- **Q234 the TAB board on a phone** (session 78, #357; the page's section 'The TAB board on desktop and phone', to scale at 750 x
  381: P1 two panels left of the buttons at 13 px, P2 two panels on the whole screen at 15 px): "The whole screen, but didn't
  chose a compact scoreboard instead each scoreboard for a team?". So the whole screen, and a question. From this file: S5
  Compact chips (Q196) is the TOP scoreboard on phones; the TAB board was T1 side by side (Q190), and no compact TAB board was
  ever drawn or chosen. Next: draw P3, one compact table for both teams on the whole screen, beside P2, and ask.
- **Q235** (recommended): **the Get Up prompt and the feed's chips hide while the board is open** and come back when it closes
  (a chip's 6 s keep counting; moving still gets a knocked-down skater up). Not chosen: the board drawing over them.
- **Q236 the phone's TAB board** (session 78, recommended; the page, to scale at 750 x 381): **P3 one compact table** on the whole
  screen: both teams in one table with a coloured bar per team, the viewer's first, 17 px text, full column names, under the
  SCORES button and over the touch buttons while it is open. Desktop keeps T1's two panels. Not chosen: P2 (two panels, 15 px).
- **Q237 desktop's TAB board too** (session 78, the owner's words: "No even desktop should be compact"): **one compact table on
  desktop as well as phones**, a coloured bar per team, the viewer's first. This replaces T1's two panels (Q190) everywhere, and
  Q236's "Desktop keeps T1's two panels". Sizes differ by screen, the layout does not.
- **Q238 the banners under the open board** (session 79, #357 built; the design page moved to
  https://claude.ai/artifact/VPCRWP4Y399pP2cFJ8vQqP, the earlier XWrav5BHeWqVQ8eebfqrP9 being the previous account's; section
  'The TAB board, built': Play shots, desktop 1556 x 793 and the phone 750 x 381). Measured with the other messages (Q230's
  lesson): on a phone at 3 a side the bottom 6 px of ORANGE GOAL IS ACTIVE! show as a dark strip under the board's ink; on desktop
  at 5 a side the board's top crosses LAP 2 COMPLETED, only the top 13 px of its letters showing (at 3-4 a side it clears the
  banner, at 6 the banner is wholly behind the board). **Hide them too** (recommended): while the board shows, the banner line and
  the goal message hide like the prompt and the chips (Q235), and come back when it has faded, their time counting on. Not chosen:
  hiding the goal message only; leaving them. Also shown there, a correction of the plan: the rows do not fit a phone from 4 a side;
  they scroll on touch (Q190's "scrolling if needed"), and off touch the board shrinks to fit (TAB is held).
- **Q239 #357 shipped** (session 80, recommended; the design page https://claude.ai/artifact/VPCRWP4Y399pP2cFJ8vQqP version 2,
  section 'The open board hides the banners, and keeps clear of the scoreboard': Play shots of Q238 built, desktop 1556 x 793
  and the phone 750 x 381, a LAP banner and the goal message fired before each capture). Found while shooting it: at 6 a side on
  desktop the board's top ink sat 6 px into the lap chips under the shield (chips to y 76, the board from y 70, Hud frame); so
  off touch the board's area now starts under the scoreboard's deepest ink in play (HudScreen.boardBottom, the period counted
  while it shows), its 3 px margin keeping Q203's clearance; on touch under SCORES or that ink, whichever is lower. Asked with
  the rulings to check: the pop 0.2 s and fade 0.25 s (Q194); scroll on touch, shrink to fit off touch; the area under SCORES
  takes taps only while open; plain white circles for ids that are no Roblox user. **"Yes, ship it"**. Next: #357's commit and
  PR, then #358, #355.
- **Q240 the call's glove** (session 80, #358; the design page version 3, section 'A better glove for the call': three new gloves
  beside H4's, each waving in H4's badge with its ripple, in M1's stack on desktop (F) and phone (PASS) and close up; all built from
  rounded bars the game can draw now, each drawn twice so the glove has one outline): **G3 Bold icon** (recommended: four straight
  fingers side by side with lines between them, a short thumb, a thick outline), with the owner's words: "but just the hand is not
  quite good, I don't like that curve between the thumb and the rest of the hand, try to make it more human and continuous". So the
  thumb rises from the palm's side in one curve (a pad under the thumb fills the notch where it met the palm), drawn again before
  it is built. Not chosen: G1 Mitten, G2 Cartoon glove.
- **Q241 the thumb joined** (session 80, recommended; the design page version 4, section 'G3 with a more human thumb': G3 as shown,
  E2 and E3, waving in the badge on desktop, phone and close up): **E2 Joined, thumb out**: G3's four straight fingers with seams, a
  palm [-9, -6, 18, 16, r5], a pad under the thumb [-9, -2, 7, 12, r3.5, turned -4] that carries the outline from the wrist up into
  the thumb [-9.6, -6, 5, 12, r2.5, turned -26] in one curve, a gentle web before the index finger (units of the page's glove; each
  part turns round the middle of its bottom edge). Not chosen: E3 (the thumb more upright). This closes Q199.
- **Q242 four findings get issues** (session 80, recommended): **all four**: the off-screen ball arrow over the hint column (and its
  stray chevrons), the lap chips lit through the goal celebration, hint rows on half pixels, and no error boundary (one part's broken
  render took the whole HUD down, session 78). Each its own issue, after #358 and #355, before M1 closes. Not chosen: only the error
  boundary; none for now.
- **Q243 the end screen's layout** (session 80, #358; the design page version 5, section 'The end screen, on the TAB board's table',
  to scale on desktop 1556 x 793 and the phone 750 x 381, popping in): **B, today's parts in look C** (not the recommended A, the
  result over the table with an MVP chip on the MVP's row): the result ("BLUE WINS!" / DRAW) in GOAL!'s lettering and size (67 px,
  43 on phones) with the team ring, the MVP's card (a look C box: avatar, the name with a key-yellow MVP chip, score, goals and
  steals), the two team totals as team-colour look C chips, then the TAB board's compact table (desktop). On phones the result, the
  MVP's card and the totals, no table (SCORES opens the board over it, as before).
- **Q244 #358 shipped** (session 82, recommended; the design page moved to https://claude.ai/artifact/2yuQnxDna9x8W2nHcocSUf after the
  owner's /login, section 'The end screen and the name tags, built': Play shots on desktop 1556 x 793 and the phone 750 x 381, and a
  real 2-player test on the phone). Asked with the rulings to check: the pill and badge in the HUD's brighter team colours although
  Q201 kept the world's old tags in UI.teamColors; the tags' phone sizes; the end screen popping in whole with the dim fading in, not
  the page's two steps; the hints, speedometer, banners, goal message, feed and Get Up prompt going under the dim; PASS on the tag while
  the touch button still reads Magnetic Pass; long names truncating; the tag resting just over the head at any distance, tall ears
  poking under it and hats possibly covered. Said plainly: my first build was an opaque panel on the stage only, not the page's
  see-through ink over the whole screen. Found on the phone this round and fixed: the result's top stuck out above the open board (the
  end screen now goes while the board shows, so the board opens in its place, not over it as Q243 said); the dim and the touch buttons
  shared one draw order (the dim now covers them, SCORES stays bright); a pass key on a mouse's button would have broken its tag (it
  now goes by its name). **"Yes, ship it"**. Next: #358's commit and PR, then #355, #376-#379.
- **Q245 the phone's buttons to try first** (session 82, #355, recommended; the design page version 2, section 'The phone's buttons: today, and
  two arrangements to try', to scale at 750 x 381, looping 8 s of play with the game's timings): **A, sized by use**: the owner's Q187 drawing with
  Uppercut and Attach added (that drawing left them out): Jump 96, Throw 70, Tackle, Pump, Pass and Uppercut 64, Brake 58, Attach 50, centres from
  the bottom right corner Jump (70, 70), Throw (163, 53), Tackle (150, 132), Pump (72, 160), Brake (235, 59), Pass (225, 133), Uppercut (150, 206),
  Attach (77, 229). Not chosen: B, two even arcs of 64 px buttons; trying both. On the page without RC's >> beside a pressed button (no room, a thumb
  covers it): the pop and the orange show. Next: a playable trial of A on the phone emulator (Studio copies only).
- **Q246 trial A, round 1, and the Attach mark** (session 82, #355; the owner's words): "is this just a trial? because the text is not white, and the
  buttons are not totally on the right, and second, I have a question, the attach feature, I don't want it to be on the right only, I want it to be
  like the pass button, the F button that appears on the player, I want to also show the attach button next to a teamate when the player is close to
  other teamate, so it is better for hint and player understand when he can attach". Found: a UIGradient on a TextButton tints its text too (a trial
  patch's slip, the real build keeps its fill apart from its words); the touch gui sits in the device's safe area, 62 px in from the right edge of the
  emulated iPhone and 20 px up from the bottom. Corrected to the owner: the F in my #358 tag shots was a stand-in; in the game Magnetic Pass is R and F
  is Attach. The Attach mark over a teammate gets its own issue, drawn on the page first.
- **Q247 the Attach mark's look** (session 82, recommended; the design page version 3, section 'Showing when you can attach, right on the teammate', at the tags'
  real sizes on desktop and phone): **Look 1, the key and the word**: a dark look C box with the F cap and "Attach" over the teammate, the word alone on a
  phone, with the owner's words: "no need for an attach icon". It shows while the game allows attaching (within attachRange, behind them, off cooldown); the Attach
  button on the right stays. Not chosen: Look 2, the key alone (a yellow F cap, a yellow ATTACH chip on phones). Its own issue, right after #355.
- **Q248 the owner's question on the call's hand** (session 82): "the hand icon for the teammate pass, should only show for a brief moment when the other teammate
  press the call pass button, is that correct? not permanent over a teamamate". Answered: correct: it shows only while their call lasts,
  Actions.callPassWindow = 3 s from their last press or until they get the ball (measured in the real 2-player test: gone 2.93 s after the last call).
- **Q249 trial A kept, and SCORES** (session 82, #355, round 2: white words, the touch gui at ScreenInsets.None so the buttons sit in the phone's physical corner, Jump 22 px
  from each edge): **"feels right build it, but what about the scores button? is it next on the todolist or no, because we should update it too"**. So A is built as
  played, and SCORES goes to look C inside #355, drawn on the page first (design page section 'The SCORES button in look C').
- **Q250 where SCORES sits** (session 82, #355, recommended; the owner's /login moved the design page to
  https://claude.ai/artifact/L7fJyQ7iJax4PGW4H5pn5A, section 'The SCORES button in look C', the whole phone screen 874 x 401): **S2, lined up with Jump**: its
  right edge 22 px from the screen's edge like Jump's, 96 x 36, top 74 px from the screen's top as today, in look C (box, ink, shadow, white words, the press pop).
  Not chosen: S1, today's place inside the safe area (78 px in).
- **Q251 merge the HUD stack** (session 82, the owner's words at the session's end): "for the PRs waiting to merge, yes merge them": the
  owner's OK to squash-merge the stack #359, #360, #361, #362, #365, #366, #370, #371, #372 (with handoffs/s78/commit-369.txt), #374, #375, #380.
  The Presentation part's ONE end-of-part review still runs at the part's end, over its whole diff from d409866.
- **Q252 the merge confirmed** (session 83, recommended; asked again because the auto-mode check could not see Q251 from the
  session before): **"Yes, merge all 12"**: #359, #360, #361, #362, #365, #366, #370, #371, #372, #374, #375, #380, squashed in
  order, each later branch rebased onto the new main with its tree checked, CI green before each merge. Then #355 is built on
  the new main.
- **Q253 the buttons cut off** (session 84, #355's ship question; the design page
  https://claude.ai/artifact/L7fJyQ7iJax4PGW4H5pn5A version 2, section '#355 built'): "the buttons looks cut off". Zoomed, every
  touch button's bottom and SCORES' were cut flat: each face's box took the size of its fading CanvasGroup (4 px taller than the
  button, for the shadow), so its ink ran past the group's bottom and was clipped. Fixed test-first (the box takes the button's
  size; a laid-out test measures fill, ink and group); shown on page version 3.
- **Q254 the sides cut too** (session 84, version 3 shown): "some buttons still cut off from the sides and a little from the
  bottom like the brake". Zoomed 5x: Call's and Brake's left sides and Jump's right side ran flat for a few pixels. A Studio probe
  (the same 58 px face in a group ending at its ink, in a group with 2 px of room, and in no group) showed a CanvasGroup shaves a
  disc's outer pixels where its ink touches the group's edges on the phone emulator; with 2 px of room it matches no group. Fixed
  test-first: UI.touchStyle.groupRoom 2 (whole px >= 1) of room round each face's ink; shown on page version 4.
- **Q255 #355 shipped, and two findings** (session 84, recommended): **"Yes Ship it"**, with "fix it now or later, two more
  things": (1) on desktop, the TAB board's "T Switch Team" button is cut off at its sides too; (2) "Max Lap 3, don't show markers
  and register laps after that, because maximum is +5 points, so when player reaches +5, don't show markers and count the laps".
  Today (Match.goalPointsByLap {1, 3, 5}) a goal is worth +1, +3, +5 after 1, 2, 3 laps of a streak and keeps +5 past that, while
  the streak keeps counting laps. Each finding gets its own issue.
- **Q256 #383 shipped** (session 84, recommended; the design page version 5, section '#383 built', desktop Play zoomed 6x):
  **"Yes, ship it"**. Found by measuring in Play: Switch team's row group was exactly the T cap's 34 px, and the cap's 2.5 px
  outline sits outside it, so the group cut it at the top and bottom (and the board's group 2.5 px under it). The row now counts
  the cap's ink (40 px), and both groups fade in Style.fadeGroup with UI.hud.look.groupRoom (moved from UI.touchStyle: one
  setting, one helper).
- **Q257 the other fading groups** (session 84, recommended): the desktop hint rows' ink touches their groups' edges exactly
  (0 px measured), and the feed chips, the Get Up prompt and the banners are built the same way: **"Yes, as its own issue
  next"**: every remaining fading group gets the same room through the shared helper, checked by a laid-out test.
- **Q258 #386 shipped** (session 84, recommended; the design page version 7, section '#386', Play measurements desktop and
  phone, the hint column zoomed, the phone with the board open, which also showed #383 on the phone): **"Yes, ship it"**. The
  hint rows, feed chips, Get Up prompt and banners fade in Style.fadeGroup, now centred on its part so a pop inside scales round
  the part's middle (a banner's round its letters); every group measured 2 px or more round its ink.
- **Q259 #381 shipped, its 2-player check later** (session 85; the design page version 8, section 'The Attach mark over
  your teammate, built': the real tags drawn by the game's code in Studio at desktop and phone sizes, every combination, zoomed
  4x; asked to try it in a real 2-player test with both windows recording): "Currently I am not near the pc, so ship it for now
  and ill test later if any issue ill mention them". So #381 ships on its tests and the Studio render; the owner's own
  2-player check comes later, and anything found then gets its own fix. Rulings shown on the page with it: the word at the
  key's text size and padding; the pointer in the box's colour where they meet; no pop-in, like the pass key; no drop shadow.
- **Q260 #377 shipped** (session 86, recommended; the design page https://claude.ai/artifact/L7fJyQ7iJax4PGW4H5pn5A version 10,
  section 'A goal empties the lap chips': the real scoreboard rendered by the game's code in Studio, the chips lit through the
  celebration before and empty after): **"Yes, ship it"**. A goal ends its streak in the rules (MatchEngine.pointScored resets the
  laps once the goal's worth is judged), so the chips empty through the celebration and the end screen. Next: #378 (hint rows
  on whole pixels), #379, #376, #384.
- **Q261 #378 shipped** (session 86, recommended; the design page version 11, section 'Hint rows on whole pixels': each row's
  top measured in Play, before 198.5 ... 522.5 in a 772 px HUD area (last session's 2-player window), after 179 ... 503 in a
  734 px area and 180 ... 504 in the usual 735 px one; 4x zooms before and after): **"Yes, ship it"**. The column's top is a
  whole pixel (HudScreen.hintsTop: its middle at its place's or half a pixel above), from the HUD's area and the rows shown.
  Next: #379 (a HUD error boundary), #376, #384.
- **Q262 #379 shipped** (session 86, recommended; the owner's /login moved the design page to
  https://claude.ai/artifact/2VPvUoeq1YxxQFhw3quNhw, the earlier L7fJyQ7iJax4PGW4H5pn5A being the previous account's; section
  'One broken part no longer blanks the whole HUD': the real HUD drawn by the game's code in Studio's editor, a normal LAP
  banner beside session 78's broken lap message, where only the banner line goes; the Output line shown; said plainly: not a
  live Play, since Studio 0.746 lets no probe fire a remote, and not shown on the phone emulator): **"Yes, ship it"**. Each
  part (each touch face too) behind its own error boundary, App behind one; a broken part hidden until the next match
  (HudState.matchNumber), one Output line naming the part, the error and the throw site.
- **Q263 three findings get issues** (session 86, recommended, all three): (1) an error inside a per-frame binding update escapes
  Hud:step, and FrameController's render phase skips the later steps that frame; (2) every full test run prints Roblox's
  'Remote event invocation discarded event ... BallState' message (NetService.spec's stream test fires to no client, since
  #331); (3) in an idle single-player Play the server logged 'MovementGuard: returned <id>' (cause not known). Each its own
  issue, after #376 and #384.
- **Q264 the off-screen ball marker** (session 87, #376; the design page https://claude.ai/artifact/2VPvUoeq1YxxQFhw3quNhw
  version 2, section 'Where the ball is when you can't see it': today's chevron, A RC's ball badge in look C, B a look C arrow,
  to scale on desktop 1556 x 793 and the phone 874 x 401 with the HUD's parts as keep-out boxes, the ball circling off screen
  for 12 s, an enlarged close-up). **A, RC's ball badge**, with the owner's words: "I like the RC Ball badge but can you make
  it more similar to rc ball because it is already in my todo list to update the ball, so can you add that band in the middle
  of the ball like the two lines take a thorough look". So the badge's ball is drawn like RC's ball (its band across the
  middle, edged by two lines), studied in the RC frames and drawn again before it is built; the 3D ball's own new look stays
  on the owner's list for later. **Sizes as drawn** (recommended): the badge 52 px on desktop (RC's ~70 px at 1078 px tall),
  34 px on phones. **All three** (recommended): the next-gate arrow becomes a look C arrow and keeps clear of the same parts at
  the edge; both markers hide while the TAB board or the end screen shows, like the crosshair; both use the HUD's brighter
  team colours (Q201), white before any team has held the ball (the ball and its ring in the world keep the world's).
- **Q265 the badge with RC's ball** (session 87, #376, both recommended; the design page version 3, same section, with RC's
  held badge zoomed beside the kickoff one). RC's badge, read frame by frame: Video 31 at 20.6-21.6 s (no team yet): a dark
  ring, a white ball crossed by two dark lines (the band's edges, leaning ~35 degrees), a small dark pointer apart from the
  ring; Video 34 (`...2026-10-30 155713.mp4`) at 24.5-25.5 s and 97.6-98.6 s (Orange holding it, the ball above the screen,
  the badge pinned over the scoreboard): the same in orange, the ring 79 px across at 1918 x 1078, ring 0.115 of it, the
  lines +-0.2 of it from the middle and 0.04 thick, the pointer 21 x 11.5 px with a 4.5 px gap, the lines' lean changing
  as the ball turns. **"Yes, build it"** as drawn: RC's white ball with its band's two lines in a ring, the ring, lines and
  a separate pointer in the team's colour (the HUD's brighter pair), look C's ink outline and drop shadow; the pointer a
  little bigger and further out than RC's (0.2 x 0.34 of the width, 5 px past the shadow) so the ink keeps it apart.
  **Keep all three**: dark (look C's ink) before any team has held the ball, like RC's kickoff, not white; the band leans
  a little and stays put until the 3D ball gets a band to follow; the badge's ball stays white whoever holds it (the world's
  ball keeps its team colour, Q158).
- **Q266 the pointer and the chevron** (session 87, #376, recommended; the design page version 4, same section). Probed in
  Studio's editor first: a GuiObject's children turn with it, and a hard-step UIGradient cuts a frame at its true angle
  through the frame's centre, so a square turned 45 degrees and cut in half is a clean right-angled triangle, Roblox's
  screen parts having no triangle of their own. **"Yes, build both"**: the badge's pointer gets a right-angled tip (RC's
  measures 21 x 11.5 px, nearly that); the next-gate arrow is a bold look C chevron of two rounded bars with a 60 degree
  tip (look C's ink round rounded bars is exact; B's notched arrowhead would spike its ink in the notch; a 90 degree
  chevron read as an "L").
- **Q267 the chevron behind the scoreboard, and #376 shipped** (session 88, both recommended; the design page
  https://claude.ai/artifact/2VPvUoeq1YxxQFhw3quNhw version 5, section 'Where the ball is when you can't see it, built':
  Play shots on desktop 1556 x 793, the real parts drawn by the game's code, zoomed). Measured over 40 s of carried laps:
  the chevron over an on-screen gate sits on the gate panel's middle (62 studs up), within 3 px of the scoreboard in 39
  of 207 frames (19%), drawn under it there, half hidden; aimed at the gate's foot (3 studs up) it never came near the
  scoreboard but came within 60 px of the crosshair in 32 of 138 frames (23%). **B, hide it there**: the on-screen
  chevron hides while it would come within the markers' clearance of a HUD part (the same keep-out boxes as at the
  edge); the gate's glowing wall still shows. Not chosen: A (aim at the gate's foot), C (keep it as built). **"Yes,
  ship it"**, with B built in and the page's rulings as shown: the pointer's pixel-stepped cut edge, the small step in
  its shadow, the fixed band, the >> press mark not counted in the hints' box; the phone not shown in Play.
- **Q268 the lap chips at the cap, and Q269 the cap's rule** (session 88, #384, both recommended; the design page
  version 6, section 'The lap cap at +5': the real S2 scoreboard drawn by the game's code in four states, and RC's lap
  meter under its score pill, Video 4 at 7:23; none of the owner's RC recordings shows a third lap, Video 4 ending 5-2 on
  +1 goals, so RC's look at the cap is not known). Settled by Q255's words: once a goal is worth +5 (after lap 3), no more
  lap banners, lap points or gate progress, and the next gate's glowing wall and chevron go until the streak ends; since
  the first team to 5 wins at once, a goal then always wins. **Q268 A: all four lap chips stay lit** from lap 3's last
  gate until the streak ends. Not chosen: B (empty, stay empty), C (the row goes). **Q269: the cap follows the list of
  goal worths** (`Match.goalPointsByLap`'s length: 3 today; a list of four would cap after 4). Not chosen: always 3.
- **Q270 #384 shipped** (session 89, recommended; the design page https://claude.ai/artifact/2VPvUoeq1YxxQFhw3quNhw
  version 7, section 'The lap cap at +5, built': a single-player desktop Play driven round the track by a test script, the
  real scoreboard zoomed 3x): **"Yes, ship it"**. A streak counts as many laps as there are goal worths (3); the third lap
  counts like the others (its gates, LAP 3 COMPLETED, its lap points), then nothing counts until the streak ends: no LAP 4
  banner, no lap points, no glowing gate wall, no chevron; the four lap chips stay lit and the goal stays +5. Measured in
  the Play: LAP 1/2/3 COMPLETED at 28.0/43.3/58.4 s; the wall and the chevron went in the same frame as LAP 3's; 20+ s of
  carried laps after it changed nothing. Next: #394, #393, #392 (Q263).
- **Q271 #394's next step, and Rojo** (session 89, both recommended). #394 (MovementGuard returning an honest skater)
  was not reproduced: Studio's guard instrumented in place, 8 Plays (~10 min: idle, driven laps, session 88's exact
  driving probe, window-shot bursts, a resize, a full test run right before an idle Play) gave no strike at all; flat
  skating stays near 51 studs/s against the guard's 145.2, so only a jump in position could trip it. **"Make the line tell
  why"**: the guard's 'returned' line says what it measured (how far, in what time, from where to where, one jump or a run
  of strikes), built test-first, so any later case shows its cause; #394 stays open meanwhile, and #393 and #392 go on.
  Not chosen: keep hunting now; the owner describing a repro. Also: **"Yes, restart it"** (Rojo serve, the previous
  session's process having exited with that session).
- **Q272 the stack merged, and two more items** (session 89, recommended; after #384, #394's line, #393 and #392 were
  built, 13 PRs CI-green: #382 #385 #387 #388 #389 #390 #391 #395 #396 #397 #398 #399): "yes, also in the milestone, in
  addition, I want to do the ball redesign and the speeding up the player movements a little more". So the stack is
  squash-merged in order, and M1 gains two items: **the ball's redesign** (the 3D ball with Roller Champions' look, its
  band across the middle edged by two lines, Q264/Q265; the HUD badge's band can then follow the ball's roll) and
  **faster player movement, "a little more"** (feel: measured against RC by frames and body heights, decided by a
  playable trial, coupled rules changed together).
- **Q273 no faster movement after all** (session 89; asked with the stride at 51 studs/s, 8.7 body lengths a second,
  a lap ~15.6 s; options stride +10% (recommended), +20%, everything +10%, two trials): "actually, never mind about the
  speeding the players, we already did it before, it is fine for now". The movement stays as it is (#328's stride, Q161-
  Q163); Q272's speed item is dropped. The ball's redesign stays.
- **Q274 published, and the local branches gone** (session 89, both recommended): **"Yes, publish now"**: main 3332f73
  (both HUD stacks, the phone controls, the screen markers, the lap cap, the guard's line, the frame guard) built to
  build/game.rbxl and published by the owner into Blox Champions (place 74253300416513; its Updated time 2026-11-02
  17:50:59Z -> 2026-11-05 21:22:20Z); the publish window closed by me. **"Yes, delete them"**: the 12 merged local
  branches deleted.
- **Q275-Q277 the ball's black band, its roll, and Blender** (session 90; the design page
  https://claude.ai/artifact/2VPvUoeq1YxxQFhw3quNhw version 8, section 'The ball with a black band': Studio renders of
  the 2-stud ball, nothing uploaded, the band a 2.04-stud shell cut by a slab (IntersectAsync) in look C's ink; white,
  orange, blue at 0.5; widths 0.3/0.5/0.8 on orange; a slowed roll; the cut band zoomed 3x showing 1-px light specks
  where its pieces meet). Before it, in the owner's words: "the ball need to be like RC, it needs to have a black band
  in the middle around the ball", and: "later I want to have ball skins, that players can buy skins with robux, so do
  we use blender for the ball design or what? I would like to use blender if it is better, but only if necessary and
  that it would be good". So session 89's three looks (team lines C, white band B, team band A) are replaced by a
  BLACK band; the ball's own colour keeps Q158/Q159 (white neutral, then the last holder's team). **Q275**: **0.8
  studs** (40% of the ball's height; not the recommended 0.5; 0.3 not chosen). **Q276** (recommended): **the band
  turns with the ball's roll and spin** (the HUD badge's band can then follow it: a follow-up issue). Not chosen: a
  fixed lean. **Q277** (recommended): **a ball made once in Blender**: a ball mesh with a paint map (UVs), the black
  band painted into the Default skin's picture, the picture see-through elsewhere so the ball's colour shows through
  (SurfaceAppearance AlphaMode Overlay, Roblox docs read this session), imported once by the owner in Studio (it
  uploads to their account); a later skin = its picture(s) + one line of data; the round ball part keeps the physics.
  Not chosen: the band built in Studio by CSG at server start (no owner step, but the specks, and skins limited to
  colours and materials).
- **Q278 the ball's issues, and Q279 Rojo** (session 90, both recommended). **Q278 "Yes, file these 3"**, in order, one
  issue, branch and PR each, milestone M1: (1) the ball made in Blender with its black band (a script builds the mesh
  and the Default picture; the owner imports it once in Studio; the game draws it, team colours as today, physics
  unchanged); (2) the band turns with the ball's roll on every screen (blocked by 1); (3) the HUD badge's band follows
  the roll (blocked by 2). Not chosen: 1 and 2 merged; one issue for all. **Q279 "Yes, restart it"** (Rojo serve,
  stopped with session 89's CLI; then the owner's Disconnect + Connect).
- **Q280 the ball imported, the picture uploaded** (session 90, #400, recommended): the owner clicked Rojo's Connect and
  imported `assets/ball/ball.obj` with Studio's Import 3D (a Model "ball" with a 2 x 2 x 2 MeshPart; the mesh uploaded
  to their account), then **"Done; you upload it"**: I uploaded `assets/ball/ball_default.png` through Studio's MCP as an
  image on their account. Not chosen: the owner uploading it through the Asset Manager; stopping there.
- **Q281 #400's ship question** (session 90; the design page version 9, section 'The ball with a black band, built':
  Play close-ups, white with the band after the drop-in, orange with the band carried; the band level, its roll being
  #401): not chosen yet; the owner's words: "the ball is not rolling, the band is on place". So the band's roll is
  wanted now; #401 (the roll) comes straight after #400.
- **Q282 ship #400, the roll now** (session 90, recommended): **"Ship #400, build #401 now"**: #400's pull request goes
  up as built, and #401 (the band turning with the roll) starts at once on a branch stacked on it, shown on the design
  page (the roll animated) before anything merges. Not chosen: holding #400 until the roll is built.
- **Q283 the spin too fast** (session 91, #401's ship question; the design page
  https://claude.ai/artifact/2VPvUoeq1YxxQFhw3quNhw version 10, section 'The band turns with the roll, built': a Roll
  Ball filmed in Play with a camera following the ball; each drawn frame turned by exactly the server's physics spin,
  76 of 76 frames checked): not shipped yet; the owner's words: "can you make the ball spin a little slower, it is fast
  now". Measured: right after a Roll Ball the server's ball spins about 250 rad/s (40 turns a second, two thirds of a
  turn between frames at 60 frames a second), so the band flickers until the ball slows.
- **Q284 a limited spin, tried by playing** (session 91): **"Try a limited spin"** (not the recommended "keep the true
  spin"): a playable Studio trial in which the band's drawn turn is capped, so a fast ball's band reads as rolling,
  slower than the real spin; the cap chosen by playing it.
- **Q285 #394 next** (session 91, recommended): **"Next, before #402"**. The caught case (a character loaded by
  Roblox itself mid-match at about (0, 103.6, 0), returned by the guard, the skater stuck; evidence on #394) is
  reproduced on purpose first (a slow server start), then fixed test-first on its own branch; the leading fix is
  Roblox's own character loading switched off in the place file. Not chosen: after #402.
- **Q286 the CI flake gets an issue** (session 91, recommended): **"Yes, file it"**: #403's first cloud run failed once
  (the HUD's step-time test read 0.144 ms against 0.1 ms, then the match spec ran past the 5-minute limit) and passed on
  a rerun; the issue finds the hang and makes the cloud speed test steady without hiding a real slowdown.
- **Q287 the spin trial: at most 2.5 turns a second** (session 91, #401; a playable Studio trial patched into Studio's
  copy only: keys 1-4 switched the drawn spin's limit while playing, 1 the true spin (up to 40 turns a second), 2 at
  most 10, 3 at most 5 (recommended), 4 at most 2.5; a slow ball spun the same in all four; checked in Play first: 249
  of 249 frames turned by exactly the capped spin): **"4: at most 2.5 turns/s"** (15 rad/s). So each screen turns the
  band by the server's spin up to 15 rad/s about the spin's own axis; a faster ball's band turns at that rate. Not
  chosen: 1, 2, 3.
- **Q288 #401 shipped** (session 91, recommended; the design page version 11, section 'The band turns with the roll,
  built': the limit built as `Ball.lookSpinLimit = 15`, a Roll Ball by Orange up the banked curve, 339 of 339 Play
  frames turned by exactly the limited spin): **"Yes, ship it"**. #401's pull request goes up stacked on #403; the
  owner's 2-player check of #400 + #401 stays open; then #394 (Q285).
- **Q289 the badge stays as it is** (session 91, #402; the design page version 12, section 'The ball badge follows the
  roll: two ways': one ball rolling away, across and tumbling, drawn live from its real band; A RC's two lines leaning,
  B the black band as seen (recommended), at 2x and at 52 / 34 px): neither; the owner's words: "no don't animate the
  ball hint, keep it like now, you mean the hint of the ball ofscreen right?" (yes: the off-screen ball badge, #376).
  So the badge keeps RC's two lines at their fixed lean (Q265), and #402 is closed as not planned.
- **Q290 the ball's 2-player check** (session 92, #400 + #401; asked after #404's fix went up as #407): the owner's
  own 2-player test of the Blender ball with its black band and its roll (at most 2.5 turns a second, Q287) on both
  screens: "tested, good to merge". So #403's and #405's last boxes are met.
- **Q291 merge the stack** (session 92, recommended): **"Yes, merge all 4"**: #403 (the ball's look), #405 (its roll),
  #406 (Roblox never loads a character on its own, #394), #407 (the CI flake, #404), squashed in order, each later
  branch rebuilt on the new main with its tree checked and CI green before its merge.
- **Q292 publish after the merge** (session 92, recommended): **"Yes, publish after the merge"**: the new main built to
  build/game.rbxl and published by the owner (place 74253300416513, on 3332f73 since 2026-11-05); the publish window
  closed by me.
- **Q293 no CI retry** (session 92, recommended): **"No retry"**: a red cloud run stays red, and a flake is diagnosed
  like #404; a retry would also pass a real, sometimes-slow problem, which #407's scaled budgets are there to catch.
- **RC's lap moment studied for the captions** (session 92, the Presentation part's next item, Q181/Q182; Video 35,
  `...2026-11-01 211344.mp4`, 'Fallen Stadium', at 5.8-8.8 s (lap 1) and 42.0-44.4 s (lap 2), 10-20 frames a
  second; crops in the durable handoffs folder `s92/frames/cap_rc_*.jpg`). What RC does when the carrier's team
  completes a lap:
  - **The goal shows its worth in its middle:** the goal ring's centre disc glows in the possessing team's colour
    with the worth in blocky digits, "+1" at 42.8 s and "+3" from 42.9 s, about 0.1-0.15 s after the carrier passed
    the gate (42.75 s), before anything else arrives; it reads from anywhere the goal is in view.
  - **A fireball from the gate to the goal:** about 0.2 s after the gate (42.95 s) a fireball, white-hot head and a long
    orange tail, comes from over the outer wall behind the skater and streaks along the wall's top to the goal ring
    in about 0.3 s (43.0-43.3 s); then thin orange streaks along the wall fade over about a second (to ~44.4 s).
  - **The caption:** "Lap 2 Completed" in a pink-orange outlined script under the scoreboard from ~42.9 s (ours:
    LAP n COMPLETED, #356).
  - **A feed line at the bottom centre:** "Orange has a chance to score!" after lap 1 (7.5-8.8 s), "2 laps for
    Orange!" after lap 2 (from ~43.5 s), a small white box with dark text (ours: "<Team> goal is active!", Q191).
  - **Fire trails from the skates:** the carrier's two skates sometimes leave long orange fire trails on the ground
    behind them, but not because of the lap: within the same streak they show at 40-42 s and 47 s and are gone at
    43-45 s, while the skater slows to throw (44.7 s); none at 5.8-6.6 s (standing, throwing), present at 7.6-8.6 s
    (skating on). So they follow the skater's motion (speed or pumping: not settled); when exactly, and whether
    every skater has them, is not seen yet.
  Ours today at a lap: the LAP n COMPLETED banner, the scoreboard's lap chips, the goal-active message, the next
  gate's glowing wall and chevron (#376/#384); the goal ring (white rim, radius 7, 29 studs up, a panel while
  closed) shows nothing of its worth, and nothing flies or burns. Next: draw RC's moment beside ours on the design
  page (animated), then ask one question at a time.
- **Q294 the goal shows its worth** (session 92, the captions; the owner's /login moved the design page to
  https://claude.ai/artifact/VBbQKJJuUCXoLmV4oDiNNZ, the earlier 2VPvUoeq1YxxQFhw3quNhw being the previous account's;
  section 'When your team completes a lap': RC's frames, ours today, and our lap drawn live with each RC piece
  switchable, desktop and phone): **"Yes as drawn"** (recommended): a see-through disc in the possessing team's
  colour inside the open goal, +1/+3/+5 in our banner lettering, popping when it changes; the ball flies through it;
  the HUD's chip stays. With two new items in the owner's words: "also in my todo list, is that I am going to update
  the goal in the arena map to match RC structure, it shouldn't be a hanging disk, and to be thick and more at the
  top, but not sure if we do it later or now? what is in our current todo list first? also a small todo, I want to
  explore having the ball color in neon colors, like RC, not bare orange and blue, and for anything else like RC,
  it is has more brighter colors for some stuff, like neon I think". So: **RC's goal structure** (not a disc hanging
  from an arm: a thick goal, higher up) and **neon colours** (the ball and other things brighter, like RC), each
  studied in RC's frames and shown on the page first; their place in the order asked next.
- **Q295 the order: the goal and the colours first** (session 92, recommended; asked after the owner's two new items,
  with the current list: captions, goal sequence, intro/kickoff cameras, podium, drop-in, camera pitch, then M1's
  close): **"Goal + colours before the captions build"**: the captions' remaining questions now (the fireball, the
  skates' fire, the bottom line's words), then RC's goal structure (frames, page, a playable trial), then neon
  colours (page), then the captions built on the new goal in the new colours, so nothing is built twice.
- **Q296 the fireball not seen** (session 92, the captions; design page version 1): asked whether to have RC's
  fireball as drawn; the owner: "didn't see a fireball". Found: the drawing flew it along the outer wall's top, which
  sits above our camera's view (our glass is 120 studs tall, RC's far lower relative to its camera), so it showed only
  at the goal. Version 2 flies it along the outer glass at about the goal's height, in from the right edge, with the
  streaks following its path; asked again.
- **Q297 the fireball, as drawn** (session 92, recommended; design page version 2): **"Yes, as drawn"**: on each lap
  a fireball in the team's colour flies from the gate just passed along the outer glass at about the goal's height
  into the goal in 0.35 s, a flash at the goal, then streaks along its path fade over 1.1 s; every screen shows it on
  its own; it does nothing to play. Built with the captions, on the new goal.
- **Q298 skate fire for everyone** (session 92; not the recommended trial): "Yes we need to have skate fier, it is
  for everyone, in the teams color, and while the character is moving, like speeding, pumping, any movement". So
  every skater's two skates leave fire trails in their team's colour whenever they move (skating, pumping, any
  motion), none while still; a trail drawn behind a moving skate grows with its speed. Not tied to the lap. Built
  with the captions (its own issue).
- **Q299 the bottom line's words** (session 92, recommended): **"Today's, plus lap counts"**: lap 1 ORANGE GOAL IS
  ACTIVE! (as today, Q191; RC's words in Video 4), lap 2 2 LAPS FOR ORANGE!, lap 3 3 LAPS FOR ORANGE! (Video 35's
  form), same place and look as today. Not chosen: today's only; Video 35's "has a chance to score!". So the
  captions' design is settled (Q294, Q297-Q299); next: RC's goal structure, then neon colours (Q295), then the
  captions' issues.
- **RC's goal structure studied** (session 92, for the owner's Q294 item; Video 4 Pixel City at 363-367 s, 2-5
  frames a second, zoomed at full resolution; Video 35 Fallen Stadium at 56.5-60.5 s; crops in the durable handoffs
  folder `s92/frames/goal_rc_*.jpg`). Pixel City's goal is **a thick, rounded, glossy housing** (silver-white with a
  purple band, deep like a lens hood, so from the side it reads as a capsule) round **the glowing disc** (the team's
  colour, the worth in its middle), **mounted on a tall striped pillar beside it** (purple with yellow stripes), high
  over the track by the outer side; no thin ring and no hanging arm. Fallen Stadium's goal sits high against its stone
  archway (not resolved closer in that video). Also seen at a goal (Video 35, 58.9-60.5 s; for the goal-sequence
  item): "GOAL" bursts out of the ring in the world, the scorer's line "Heatblast123 scored 3 points!" top left, the
  scorer's points big on the scoreboard ("3"), and a bottom line "Orange never stops!"; in Video 4 the bottom line
  "Two time's the charm!" after the second goal. Ours: a white rim (radius 7, 29 studs up) hanging from a thin arm,
  a translucent panel while closed. Next: draw the goal's options on the page (and a Studio render of each), then a
  playable trial of its height.
- **Q300 the goal on the wall, and the fireball lines** (session 92; the design page version 3, section 'A goal like
  RC's: thick, rounded, high': A a rounded housing modelled in Blender on a pillar, B a deeper rim of 32 blocks by the
  arena's code). The owner: "let's use blender, but not quite that model, the goal should be attached to the wall,
  not attached by a pole, here is a video I just recorded from RC, inspecting more the goal, take a thorough look at
  it, and one thing I also noticed, about the fireball to the goal, first, on each marker the player pass, the
  fireball goes from the previous marker to the next marker and stop, and same thing when he goes in to the next
  marker, till he reach the goal marker and compelete a lap, then if he starts another lap, there is a second
  fireball line, and same thing fireball from marker to marker in the second line, so basically there are 3 lines on
  top of each other, take a thorough look in the video, and by that, I think we can remove the vertical line that
  goes with the ball currently in the glass wall and have these or if you can find a cool way to include them
  together not sure, here is the video: "D:\Screenshots\Videos\Screen Recording 2026-11-06 132044.mp4", and then
  also if it would help, look at the fire trails from the skates and trail from the ball". So: **the goal is modelled
  in Blender (A), but attached to the wall, not on a pole** (its shape from the new video); **the fireball is not one
  streak per lap**: at each marker passed, a fire line runs from the previous marker to the next and stays, marker
  by marker round the lap; each lap adds a line above the last, so up to 3 stacked lines (Q297 corrected); the
  carrier's vertical beam on the glass (#376's CarrierBeam) may go in their favour, or both combined; and the skate
  trails and the ball's trail to be studied too. The new video is **Video 36**: `D:\Screenshots\Videos\Screen
  Recording 2026-11-06 132044.mp4`.
- **Video 36, overview** (session 92; the owner's RC recording for Q300, `D:\Screenshots\Videos\Screen Recording
  2026-11-06 132044.mp4`, 1:53, 1916 x 1078, 30 fps; a red-and-blue map with dragon towers; read at one frame every
  2 s, not yet frame by frame). The owner (Orange) alone: the kickoff (0-12 s, the count 5..1 in the goal's disc),
  "GO ORANGE TEAM!" (~10 s), three carried laps, "Lap 3 Completed" (~86 s), a +5 GOAL, ORANGE TEAM WINS, the replay
  with the scorer plate "+5 PTS" (from ~92 s), then the players screen. Seen:
  - **The goal close up** (6-24 s, the camera turned on it; the replay 92-110 s): a thick, deep, rounded housing in
    the map's red and black (a brand word on its shell), the glowing disc inside, joined to a big white light
    panel beside it, the unit held high above the stands' rim and hanging from red rails above (corrected after a
    marked frame: no tower from the floor); not on a free pole.
  - **Fire lines along the wall's top:** orange lines along the top of the outer wall and stands that grow as the
    laps go on (several stacked by ~54-80 s); the owner's reading (Q300): marker to marker, one line per lap, up to
    3. A big fireball streak shows at ~54-56 s. To read frame by frame at each gate.
  - **Bottom lines:** "And we're off!" (kickoff), "It's about time for Orange" (~42 s), "Orange is trying a second
    lap" (~62-70 s), "3 points if Orange scores!" (~76 s), "Orange is on a quest for a donut!" (~84-86 s), "Three!" (the kickoff count, ~8 s), "5 points if
    Orange scores!" (~88 s), "And the ball goes in!" (the goal).
  - **Skate fire** whenever the skater moves (long orange trails at 47-76 km/h); **the carried ball leaves white
    wavy trails** behind it (~52 s, ~74 s, ~94 s).
  Next: frame by frame at 5-10 frames a second: the goal (6-24 s, 92-110 s), each gate's line (40-90 s), the skate
  and ball trails; crops to `s92/frames/v36_*`.
- **Video 36, the fire lines (first lap)** (session 92; 36-56 s at one frame a second, the top half): the ball is
  caught at ~37 s; the carrier passes a gate at ~41-42 s (its orange lines on the glass); at ~44 s a fireball runs
  along the top of the outer wall (where the wall meets the stands) and leaves a thin orange line along that rim that
  stays (45-47 s and on); the next gate at ~48-49 s (the glass panel glowing) sends another fireball (~50 s) whose
  line continues the first along the rim (51-55 s). This matches the owner's Q300 reading: per gate, fire from the
  passed marker to the next, the line staying. The lines sit at the outer wall's top edge, visible from most of the
  track there (RC's wall is low next to the stands); ours is glass 120 studs tall, so our lines need a height that
  shows (a page question). Not read yet: the exact start and end of each line, the second and third laps' lines
  above (~62-86 s), and what happens to the lines at a goal or a lost ball.
- **Video 36, the fire lines (laps 2 and 3) and the goal** (session 92; 60-88 s at one frame a second, the top
  half): each gate passed (the big orange U-shaped frame of lines on the glass at ~61, 66, 69, 73, 82, 85 s) is
  followed 1-2 s later by a fireball along the rim (~63, 67, 70, 74, 78, 83 s); the lines it leaves stay, and by
  76-87 s three or four parallel orange lines run stacked along the outer wall's top edge (the owner's "3 lines on
  top of each other", Q300). "Lap 2 Completed" at ~74-76 s; the goal's disc shows "+3" by ~79 s. The goal seen close
  at 60-63 s and 77-79 s: a thick red housing, rounded like a heart or shield, a black inner rim, the glowing disc
  with the worth, joined to a big white light panel beside it, the unit high above the stands' rim (no tower from the floor:
  corrected after a marked frame).
  Still to read frame by frame (5-10 a second): where exactly each line starts and ends (marker to marker), how far
  apart the stacked lines are, and what the lines do at the goal and after it (~88-92 s).
- **Video 36, one gate at four frames a second** (session 92; 41.5-46.0 s): the carrier passes the gate at ~43.75 s
  (the gate's U-shaped frame of orange lines on the glass flashes bright); ~0.25 s later (~44.0 s) a fireball
  leaves from that gate and flies FORWARD along the outer wall's top edge (where it meets the stands), toward the
  next marker ahead, a long streak behind it (44.0-44.75 s, out of view ahead after that); its line stays along the
  rim (44.5-45.75 s and on). So each line runs from the gate just passed to the next marker, as the owner said
  (Q300); the next gate's fireball then carries the line on. Not seen in this stretch: the flight's full time to
  the next marker.
- **Video 36, lap 3 and the trails** (session 92; 87-93 s at two frames a second): the last gate at ~89.5 s, "Lap 3
  Completed" from ~90 s, the goal's disc showing "+5" from ~90.5 s; the stacked fire lines (four or five along the
  rim by then) stay up to the goal. All along, the carried ball leaves two thin white wavy trails behind it, and the
  skates two long orange fire trails (Q298). Not read: the goal's own moment (~93 s on, the goal-sequence item) and
  whether the lines clear at the goal.
- **Q301 the lines replace the beam** (session 92, recommended; the design page version 4, section 'Fire lines from
  marker to marker, one per lap': RC Video 36 frames at 43.75/44.25/45.5/86 s, a top-down lap animation, our
  straight with the lines along the top of our solid outer wall, 40 studs up, the beam switchable): **"Lines replace
  the beam"**: each marker passed sends a fireball forward along the wall's top to the next marker, its line
  staying, one line per lap, stacked (three by lap 3); the carrier's tall beam on the glass (Arena spec 5.4,
  CarrierBeam) goes; the ball badge and name tags still show who carries. Q297's single fireball to the goal is
  replaced by these lines.
- **Q302 the lines at the solid wall's top** (session 92, recommended): **"At the solid wall's top, as drawn"**: the
  three fire lines run along the top of our solid outer wall (40 studs up, where the glass begins), at about 40, 42
  and 44 studs, like RC's wall-top edge by the stands; checked in a Studio Play shot on the page before it is built.
  Not chosen: lower on the wall (~20 studs); a trial of both.
- **Q303 the lines clear when the streak ends** (session 92, recommended; Video 36 at 92-98 s: the stacked lines
  gone the moment of GOAL at ~95 s, only the arena's own blue stripes left; a ball lost to the other team not in the
  video): **"When the streak ends"**: at a goal or when the other team takes the ball, the lines fade out quickly
  (~0.3 s), the same moment the lap chips empty; the other team's lines then start from their first marker.
- **Q304 the goal fixed onto the wall** (session 92; the design page version 5, section 'A goal like RC's', block
  'Your Q300: on the wall, not on a pole': Video 36's goal at 8/14/62 s and two rough Blender sketches of our housing
  fixed onto the wall by a plate, 29 and 48 studs up): **"Fixed onto the wall with a plate"** (not the recommended
  tower), with the owner's words: "but what do you mean a tower in the wall like Video 36? where is the tower? can
  you explain more? also make note, that for goal, later we also have skins, for goal and goal score, like
  finishing, like in the video where if you can notice the white thunder and lightning, so give me more real
  iterations of the goal to see". So: the housing is held onto our outer wall by a short thick plate (no tower, no
  pole); **later: goal skins and goal-score effects** (a finishing burst when a goal is scored, like Video 36's white
  thunder and lightning at the goal; with the cosmetics milestone, M8, and the goal-sequence item); next: **more
  real iterations of the goal's look** (several housing designs, rendered properly in an arena setting), and an
  answer on the "tower" (corrected after marking the frame: there is no tower; the tall white block beside the housing
  at 8 s and 62 s is a big light panel joined to it, the unit held high above the stands' rim, hanging from red
  rails above, seen from behind at 14 s).
- **Q305 the lens goal, refined** (session 92; the design page version 7, block 'Four goals fixed onto our wall':
  1 Lens (recommended), 2 Shield, 3 Rounded square, 4 Hexagon, Blender renders in a slice of our arena, each held
  onto the outer wall by a plate at 29 studs): **Lens**, with the owner's words: "but it should be a little bigger,
  and if possible the text inside follow the text font or anything else that look cool, modern and vibrant and bold
  also to be clear, and the outer of the lens, should be thinner, and more width to the back place, like if we look
  at it from below and behind". So: the lens housing, a little bigger; its number in our bold banner lettering (look
  C's Luckiest Guy, white with a dark outline) or another bold, clear, vibrant face; the ring's front edge thinner;
  the housing deeper toward the back (its depth seen from below and behind). Drawn again from the front and from
  below and behind before its height and size trial.
- **Q306 the number both ways, the goal sunk into the wall** (session 92; the design page version 8, block 'The
  lens, refined'; asked whether the look is settled before its height and size trial): the owner: "Ok, two more
  things, the goal hint like the +1,+3,+5 should be either on the middle and visible from front and behind, or on
  both sides, and one more thing, like RC, the goal should be a little immersed to the wall on the right side, take
  a thorough look, the goal not a complete full circle, the right side is a little immersed into the wall". So: the
  worth disc sits in the middle of the housing with the number readable from the front and from behind (or a number
  on each face); and the housing's wall side is sunk a little into the outer wall (RC's goal is not a free full
  circle: its wall side goes into the wall), drawn again before the trial.
- **Q307 the lens look settled** (session 93, recommended; the design page version 9, block 'The lens, refined':
  the housing's wall side sunk 3.5 studs into the outer wall, the disc in the body's middle with the number on both
  faces): **"Yes, build this look"**. Not chosen: sink it deeper; sink it less. Next: a playable Studio trial of the
  goal's height and size, then neon colours (Q295), then the tickets.
- **Q308 the goal trial, and lower solid walls with glass above** (session 93, recommended; the design page version
  10, section 'Where the lens goal sits on our wall': the goal's gate cut across to scale, the lens sunk 3.5 studs
  into the wall at centres 42/45/48/52; found: at the goal's gate our outer wall stands upright only above ~32 studs,
  so a goal sunk into it needs a centre of ~40 or more): **"Yes, build this trial"** (keys 1-4 the centre at 42 / 45 /
  48 / 52, keys 5-7 the opening 7 / 8 / 9), with the owner's words: "but also I'd like to lower the gray wall and
  switch them to glass, like RC, real ground are way shorter than ours, both in outer and middle walls, take a
  thorough look and let's do that". So: **our solid (gray) walls, the outer wall and the middle (inner) bank, become
  much lower, glass above them, like RC's**: studied in RC's frames (heights in skater heights), drawn to scale on the
  page and tried in Studio together with the goal (a lower solid wall also changes how low the goal can sit).
- **RC's solid walls read** (session 93, for Q308; single frames, rough, the skater nearer the camera than the wall
  so the wall reads low; crops in the durable handoffs folder `s93/frames/`): **Video 36** (the red/blue map) at 24 s
  and 92 s: the outer wall a short red curve up from the floor and a white rim, about one skater height, the crowd
  standing right behind it (no glass seen above it there); the middle a low ramp with white chevrons. **Video 14**
  (Mexico Arena) at 4.25 s: a wide red bank, then a black band and an ad board about as tall as the skater, then
  glass with the crowd behind: about two skater heights solid in all. **Video 20** (Pinball Stadium): the wooden floor
  curving up into a green band and a white edge, then the stands' glass. Ours: the outer wall solid to 40 studs, 27
  (4.6 skater heights) above where the floor starts curving up (12.8 on the straights, 14 on the curved ends); the
  middle bank solid to 16 (2.7 skater heights).
- **Q309 same shape, glass lower, climbing unchanged** (session 93; the design page version 11, section 'The goal on
  our wall, and glass lower down': RC's frames, our goal's gate cut across to scale with the glass line switchable):
  **"Yes, same shape, glass lower"** (recommended), with the owner's correction: "yes but don't stop climbing at the
  new line, keep the climbing the same". So: the shape skaters ride stays as today (trial 6); the upper part of the
  same surface only LOOKS like glass; climbing (Q84) still goes up to where it ends today (the outer wall's old solid
  top at 40, the middle bank's at 16), so it is no longer tied to how a surface looks. In the trial, key 8 cycles the
  outer wall's glass line (40 today / 28 / 24 / 20 studs above the lowest floor) and key 9 the middle bank's (16
  today / 12 / 9 / 6), beside the goal's keys 1-7. Not chosen: reshaping the walls' curved feet.
- **Q310 the goal's centre at 52** (session 93; after playing the trial: keys 1-4 the lens stand-in's centre at 42 /
  45 / 48 / 52 studs above the lowest floor, sunk 3.5 into the outer wall at the goal's gate): **"52 (key 4)"**, the
  highest tried (no option was recommended): the housing from 40.6 to 63.4, its opening's centre 8.9 skater heights
  up, 7.9 studs out from the wall.
- **Q311 the goal's opening at 9** (session 93; after playing the trial, keys 5-7 the opening 7 / 8 / 9 at the
  centre 52): **"9 (key 7)"**, the biggest tried (not the recommended 8). Correction to my question's words: 7 / 8 / 9
  is the opening's RADIUS (Arena.goal.ringRadius), not its width across; at 9 the opening is 18 studs across (today
  14) and the housing reaches 12.4 from the centre (24.8 across). The owner chose by what they played, which used
  the real sizes.
- **Q312 the outer glass from 20, set per map** (session 93; after playing the trial, key 8 the outer wall's glass
  line 40 / 28 / 24 / 20 studs above the lowest floor): the owner: "20, by default, but maybe for later arena map
  customization can chance it for other arenas". So: the outer wall looks like glass from 20 studs up by default
  (about 1.2 skater heights above where the floor starts curving up on the straights; the lowest tried; not the
  recommended 24), and the line is a per-map setting (config), so other arenas can set their own.
- **Q313 the middle glass from 6** (session 93; after playing the trial, key 9 the middle bank's glass line 16 / 12 /
  9 / 6 studs above the floor): **"6"**, the lowest tried (not the recommended 9): about one skater height, like Video
  36's low chevron ramp; a per-map setting like the outer wall's (Q312), 6 by default. So the trial's settled
  picks: the goal's centre 52 (Q310), its opening radius 9 (Q311), the outer glass from 20 (Q312), the middle glass
  from 6 (Q313); climbing unchanged (Q309). Next: restore Studio's copies, then neon colours (Q295), then the tickets.
- **Q314 the goal redesigned: melted into the wall, a tower bar, smooth** (session 93; asked after the trial whether
  to stop it and restore Studio's copies): the owner, on the trial's goal (a ring of 32 blocks sunk 3.5 into the
  wall standing in for the lens): "Well, I still don't like the goal, first it looks like a full circle immersed into
  the wall, which is not cool, it should be cut off, it should be like melted into the wall, maybe we can add the
  tower bar vertical to the goal like RC to help ease the goal into that, and most importantly, I don't like the goal
  because it is too strict, too many sharp edge, we want the game to be cool, modern, so unleash your UI, 3D modeling
  skills, and help me create a good goal, like RC, take a thorough look from all videos". So: **a new goal design**,
  studied in every RC video's goal first: the housing cut off at the wall and blended into it ("melted", not a full
  circle pushed in), a vertical tower bar beside it like RC's (Video 36's tall light panel joined to the housing) to
  ease the goal into the wall, smooth rounded forms with no sharp edges, cool and modern; modelled in Blender and
  rendered in our arena at the trial's picks (centre 52, opening radius 9, outer glass from 20) before asking. The
  trial stays running for now.
- **Q315 the Halo pylon** (session 93, recommended; the design page version 13, section 'A goal that grows out of
  the wall': RC's goals (Pixel City's ring on a striped neon pillar; Video 36's thick ring, cross plate and tall
  light tower) and three Blender designs at the trial's picks, each ring and tower melted into one smooth body
  (signed-distance union and fillet, the opening cut back out round), shown from down the track, front, side and
  below-behind): **"1 Halo pylon"**: a slim pylon in the outer wall from the solid rim at 20 to 84 studs, two neon
  strips down its face, swelling round the ring's wall side so the ring grows out of it; the ring's centre 67 studs
  out from the middle glass (4 further from the wall than the trial's, so the whole opening stays in front of the
  pylon, which stands 3 out of the glass), 52 up, opening radius 9. Not chosen: the light tower, the fin. Colours
  (shell, neon, disc) come from the neon colours round (Q295), next.
- **RC's colours sampled for the neon round** (session 93, the owner's Q294 item, Q295's order; Video 36, pixels
  averaged over 7 x 7 patches with PIL in `s93/frames/`, so JPEG-softened, rough): the HUD's blue team badge
  **#0eb2f7** (a cyan-azure), the orange ball badge **#ea5e0f** and the speed digits **#e85e11** (a vivid
  red-leaning orange); the gate's U-frame lines and the fire lines glow orange with near-white cores (52 s); the skate
  fire orange-red. The ball badge is white with black lines while nobody carries (24 s) and turns the carrier's team
  orange when the owner catches it (37 s); the carried ball itself reads orange-lit in the glove (92 s, one blurred
  frame: not settled whether the 3D ball changes colour). Ours today: world team colours (Config.UI.teamColors,
  the gate panels' and goal's Neon glow) Blue #0d69ac and Orange #da8541, duller and darker than RC's; the HUD's
  (UI hud look) Blue #3d8bff and Orange #ff9a3c; the ball white with a black band (Q275). Noted in session 92's
  handoff: a probe's Neon-material orange read yellow, so a neon pick may need a deeper base (to check in renders).
  Next: the page (today vs RC's sampled colours vs neon picks tuned for Roblox's Neon, on our real ball, a gate
  panel, the goal and the HUD), then grill.
- **Q316 RC's team colours, tried first** (session 93, recommended; the design page version 14, section 'Brighter
  team colours, like RC's': RC's colours sampled from Video 36, ours, and a Studio render of each in Neon and plain):
  **"RC's colours, and let's test it before"**: orange **#ea5e0f** and blue **#0eb2f7** for the team colour
  everywhere (the world's glow on the gate walls, the open goal, the fire lines and the skate fire; the HUD to match),
  replacing today's world #da8541 (which glows yellow in Neon) / #0d69ac and the HUD's #ff9a3c / #3d8bff; first a
  playable Studio trial of them (Studio's copies only) before anything is built.
- **Q317 a key to switch the colour modes** (session 94; asked after Q316's trial was Play-checked: RC's blue
  #0eb2f7 and orange #ea5e0f in the world and on the HUD, 0 warnings; a skater on Blue's lit lap chips read clearly
  against empty ones; RC's darker orange computed at 4.4:1 against an empty chip, today's HUD orange 7.1:1, the blue
  6.2:1 against today's 4.5:1; options: RC's everywhere (recommended), RC's world + today's HUD, RC's with a lighter
  HUD orange, back to today's): the owner: "can you add a key to switch between the modes so I can visualize the
  difference? and have all the options, like RC colors everywhere, RC world and todays HUD, RC but a ligher HUD
  orange, todays colours". So the trial gets keys 1-4, one per option, switching live (the world's glow, the spawn
  pads, the carried ball, the HUD); the lighter HUD orange tried is #f47a34 (RC's hue, lifted: 5.5:1 against an
  empty chip); Tab+T switches team to see the other team's chips. The pick is asked after the owner plays it (Q318).
- **Q318 RC's colours everywhere** (session 94, recommended; after playing the trial's keys 1-4): **"1 RC's
  everywhere"**: blue **#0eb2f7** and orange **#ea5e0f** for the world (the gate walls' and the open goal's glow,
  the spawn pads, the carried ball, the marks; later the fire lines and the skate fire) and for the HUD alike, one
  colour pair in the config (today's two pairs, the world's and the HUD look's, become one). Not chosen: RC's world
  with today's HUD; RC's with a lighter HUD orange #f47a34; today's. Next: the team-colour ticket with the others.
- **RC's carried ball glows in the team's colour** (session 94, Q294's first item "the ball color in neon colors";
  single compressed frames, rough; crops in the durable handoffs folder `s94/frames/`): **Video 4** (Pixel City) at
  ~104.5-105 s, a Blue AI skater carries: the ball in the glove glows a pale cyan-white disc with a dark rim (its
  wavy trails and skate fire cyan too); **Video 36** at ~37.4-37.9 s, the owner (Orange) at night: the ball's lit
  side glows yellow-orange, the rest reads dark; **Video 35** at ~4.2 s, Orange in daylight: the part showing under
  the big glove glows yellow-orange. The loose ball reads white (Video 36 at ~36.3 s, in flight). The ball badge over
  the carrier turns the team's colour (ours already does, BallBadge). Ours today: the carried ball is PAINTED the
  team's world colour (WorldMarkers.wear writes the look's Color; the band picture stays black), no glow.
  Studio facts (Play probes on the real ball, restored after): the SurfaceAppearance's EmissiveTint and
  EmissiveStrength can be written at run time (client); with no EmissiveMaskContent nothing glows; a mask made in
  memory (EditableImage) makes it glow but drops the band picture (ColorMap) while set; an uploaded picture set as
  the mask at run time keeps the band; the glow scales with the part's colour (a black base gave no glow, a white
  base a white-hot core with a team halo, the team colour a team glow); Neon material on the ball does nothing under
  its paint. EmissiveMaskContent is Plugin security (set through the skin's model file, like ColorMap). Design page
  https://claude.ai/artifact/Wo2ebE8d7wV5FU3gCbgHVX (this account's, session 94), section 'The carried ball glows in
  its team's colour, like RC's': RC's three frames; ours A painted, B glowing in the team's colour, C white-hot with
  a team halo, each in blue and orange; B from the game's camera.
- **Q319 the carried ball glows in its team's colour** (session 94, recommended; the design page
  https://claude.ai/artifact/Wo2ebE8d7wV5FU3gCbgHVX, section 'The carried ball glows in its team's colour, like
  RC's': A painted, B glowing in the team's colour, C white-hot with a team halo): **"B Glowing team colour but the
  black band should be more black, not light like that, or is that already done"**. So: while carried, the ball's
  coloured part glows in the team's colour (cyan for Blue, yellow-orange for Orange, RC's #0eb2f7 / #ea5e0f, Q318)
  and the band stays fully black, as in A (the light band in B's renders came from the test's in-memory mask, which
  drops the band picture; an uploaded mask keeps it, checked); the loose ball stays white with its black band, no
  glow. Needs one picture uploaded by the owner (the glow mask: white where it glows, black on the band), then a
  playable trial of the brightness; the band's blackness checked on the real build before that question.
- **Q320 the tickets: eight issues, in order** (session 94, recommended; the to-tickets breakdown): **"Yes, file all
  8"**: 1 team colours, RC's pair shared by the world and the HUD (Q316-Q318), none; 2 the walls' glass lines, outer
  20 / middle 6 per map, look only (Q308-Q313), none; 3 the goal, the Halo pylon made in Blender (Q314-Q315), blocked
  by 2; 4 the goal's worth disc (Q294, Q306), blocked by 3; 5 fire lines marker to marker replacing the carrier's beam
  (Q300-Q303; their height asked with a Studio shot when built), blocked by 2; 6 skate fire (Q298), none; 7 the bottom
  line's lap counts (Q299), none; 8 the carried ball's glow, band black (Q319), blocked by 1. Each one PR, test-first.
- **Q321 #408's PR now, the 2-player check later** (session 94, recommended; #408 built: RC's pair everywhere,
  1438/1438, mutations 7/7, Play as Blue and Orange, the design page's 'RC's blue and orange, everywhere' section):
  **"Open the PR, I'll 2-player later"**: the PR opens with CI green; the owner checks the whole stack in one 2-player
  Play (one player per team) before its merge, as with #400/#401 (Q290).
- **Q322 #409 shipped** (session 95, recommended; #409 built: the outer wall looks like glass from 20 and the middle
  bank from 6, each line a clean edge on the straights, the corners and the curved ends, riding and climbing
  unchanged (to 40 and 16); 1446/1446, 27/27 mutations, 0 warnings; the arena 13,652 parts (12,752 before; limit
  15,666), its build ~0.21 s (was ~0.27 s); Play shots on the design page, which the owner's /login moved to
  https://claude.ai/artifact/7i4DcQZNXCxbWfNaiD7bM8, section 'The walls look like glass lower down'): **"Yes, ship
  it"**: the PR opens stacked on #416; the owner's 2-player check of the whole stack stays before its merge (Q321).
- **Q323 the goal opens like doors** (session 97; #410's open look, G15: on the Halo pylon the panel's 16-stud slide
  up leaves it 2 studs inside the 18-wide opening and rising through the housing; asked A today's 16 / B up 20 / C
  fade out in place (recommended), with real Play frames on the design page, now
  https://claude.ai/artifact/5ddsaHeYTvd7w5sKh9zDk6 after the /login to chouikhmohamedali, section 'The Halo pylon
  goal, on our wall'; asked too whether to judge by a playable trial or the page): **"The page is enough, but I want
  it to open like either a two sides door like an elevator door opens, from the middle, or a one side that open from
  the left to the right to the wall"**: none of A/B/C; two new looks to draw on the page first (D elevator doors
  splitting from the middle, E one door sliding right toward the outer wall, as an oncoming skater sees it), then
  ask which.
- **Q324 elevator doors** (session 97, recommended; both drawn on the design page, section 'The goal opens like
  doors': D two halves parting from the middle into the housing's left side and the pylon, E one door sliding left
  to right into the pylon; each door drawn as 10 bars that shorten into the housing, so it never shows outside the
  goal; solid in today's colour, since see-through bars show thin light lines where they meet): **"D elevator
  doors"**: the centre, where players aim, clears first.
- **Q325 the strips glow with the lip** (session 97, recommended; the pylon's two neon strips, drawn on the design
  page in Play close up and from the lane: 1 white neon always / 2 team colour while the goal is open, white neon
  while shut / 3 dark like the band): **"2 glow with the lip"**: from the lane the lit lip alone is a thin line; the
  strips make an open goal easy to spot.
- **Q326 #410 shipped** (session 97, recommended; #410 built: the Halo pylon dressing the goal, its door opening like
  elevator doors (Q324) and its strips glowing with the lip (Q325); 1474/1474, 36/36 mutations + 1 cost-only guard
  measured, 0 warnings; the real build in Play on the design page https://claude.ai/artifact/5ddsaHeYTvd7w5sKh9zDk6,
  section 'The goal opens like elevator doors'): **"just two questions are the goal worth hint later in the todo?,
  and the goal score effects that later in the art milestone, is it fine if we insta close the goal after a goal
  score now?, otherwise just ship it yes"**: answered: the worth is #411, next (+1/+3/+5 on a disc in the team's
  colour); the rules already close the goal the moment the ball goes in (MatchEngine.pointScored -> closeGoal), the
  lip and strips go white at once and the doors slide shut over 0.4 s during the celebration, so that stays until the
  goal sequence (Presentation items) and the art milestone's effects. The PR opens stacked on #417; the owner's
  2-player check of the whole stack stays before its merge (Q321).
- **Q327 the worth disc fits the opening and glows like the markers** (session 97; #411 built: a disc in the team
  colour at 0.2 transparency over 0.92 of the opening, +1/+3/+5 popping; Play shots on the design page section 'The
  goal shows its worth'; asked to ship): **"make the circle fit more the goal, currently it is not well adjusted on
  the ends, and second, make it more neon, like the markers color, more see through, and finally one question, did
  we already make the ball color neon or not yet?"**: the disc fills the whole opening (fill 1), glows in the gate
  markers' look (UI.arenaGlow.material Neon at the glass's transparency, 0.85, as the next gate's wall shows);
  answered: the carried ball's glow is #415 (Q319 look B, band black), not built yet; it needs the owner's upload of
  a glow mask, after #412-#414.

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
