# Feather & Tail

MNKISWAN game-jam prototype - theme: **Pacifist**. Godot 4.6 (GL Compatibility).

> **Harm no one. Avoid the guards. Escape together.**
>
> MNKI and Swan are pacifists. MNKI can change the path, Swan can see the path, either can lead - and the garden is patrolled by teddy-bear guards who must be avoided, never hurt.

## Run
1. Open Godot 4.6, Import -> select `project.godot`.
2. Press F5. (Main scene: `Menus/Main_Menu.tscn`.)

## Controls
| Key | Action |
|---|---|
| WASD / arrows | Move the active (leading) character |
| Tab | Swap who leads (the other follows) |
| Left click | Command the follower to a spot you have already seen |
| H | Follower holds position / follows again |
| X or right click | Cancel command |
| F (hold, MNKI) | Cut an adjacent hedge - noisy! |
| E (hold, MNKI) | Disarm an adjacent garden trap |
| Shift (MNKI) | Sneak (smaller detection range) |
| Space (Swan) | Chirp - lures nearby guards to investigate the sound |
| Esc / R | Pause / restart |
| M | Mute / unmute all sound |

## Sound
Everything is synthesised by `tools/make_audio.py` (no samples, no licences) and played by the `Sound` autoload.
- **Adaptive music**: a calm garden theme plays all the time; a tense A-minor stem (same tempo, perfectly in sync) fades in
  when a teddy notices, searches for or chases MNKI, and fades back out when you are safe. The music carries across scenes.
- Garden ambience (wind, stream, birds), footsteps (sand / wooden bridge / Swan's wing-beats - quieter when sneaking),
  hedge cutting, trap disarming, fruit pickups (pitch rises with each fruit), chirp, swap, commands, teddy "?" / "!" cues,
  caught / hurt stings, exit-opening fanfare, win and lose jingles, UI hover / click sounds on every button.
- Master / Music / Effects volume sliders live in **Options** (title) and in the **pause menu**; they are saved. `M` mutes.
- Pausing / winning / losing muffles the music with a low-pass filter.

## Polish
Scene fade transitions, screen shake (when caught, hedge cut), sparkle / leaf / droplet particles, and smooth
acceleration + braking on the leading character.

## Performance notes
The garden used to be re-drawn from scratch every frame. Now (see the header of `Game/WorldDraw.gd`):
- terrain is split into 8x8-tile **chunks** that are drawn once and cached by the engine; only a chunk that gains newly
  discovered tiles (or a cut hedge) is redrawn
- only the genuinely animated bits (stream, lamps, ponds, fountain, exit gate) and the actors are redrawn each frame
- the fog is its own layer, redrawn only when the visible area changes; the minimap is a cached texture
- visibility is only recomputed when MNKI or Swan changes tile; teddy view cones are cached until they move / turn / terrain changes
- the second split-screen viewport is not rendered at all while the view is merged; 3D is disabled on both viewports
- frame time is clamped so a hitch can never push anyone through a wall
Measured in a headless benchmark (`tools/bench.gd`): about 5.4 ms -> 0.7 ms of script + draw work per frame.
`tools/dialogue_test.gd` checks the sling tower (hit / dodge), the chase and hide rules and the chat; `tools/shot.gd` saves staged screenshots (needs a display).
`tools/smoke_test.gd` plays the game with scripted input (menu, movement, caught, fruit, pause, win, restart, lose)
and prints any script error:  `godot --headless --fixed-fps 60 --script res://tools/smoke_test.gd`

## Teddy chases, hiding, sling towers and dialogue (new)
**Chasing is now a real chase.** Teddies notice faster, see a little farther and run *faster than MNKI's walk* (124 vs 105), so running in the open
does not work any more. When one spots MNKI it shouts, and every teddy within ~11 tiles comes to investigate (they walk to where MNKI is).
**Hiding is how you get rid of them:** step into a bush while the chasing teddy is still more than ~2.3 tiles away and, half a second later, it loses
the trail and starts searching; stay still until it wanders off. Hide too late (teddy right behind you) and it walks up to the bush and finds you.
A searching teddy walks to where it last saw MNKI, then looks around. A fourth patrol was added.

**Sling teddies on watchtowers (2 per garden).** A teddy on a stone tower watches the sky. When Swan flies within 6.5 tiles it notices her (`?`),
takes aim (`!`) and a red target appears where the pebble will land. The pebble is slow and lobbed over the walls, so Swan dodges by moving off the
target. A hit only bonks her: she is dizzy for 1.8 s (cannot move) and safe for 3.6 s. The win screen counts "Swan bonked". Faint red rings show each
tower's range. Logic: `Game/Tower.gd` (range / timings at the top), pebbles + bonk in `Game.gd`, drawing in `WorldDraw.gd` (`_draw_tower`).

**Dialogue everywhere** (`Game/Speech.gd` holds every line - edit or add lines there). Speech bubbles pop up over MNKI, Swan, the guards and the
tower teddy for: collecting apples / pears, cutting hedges, disarming traps, hiding, swapping leader, commanding or holding the follower, chirping,
a teddy noticing / chasing / searching / losing you / catching you, the sling teddy noticing / aiming / hitting / missing, the locked gate, and
all the fruit being collected. When it is calm and the friends are close, MNKI and Swan have little **conversations about love and wisdom**
(18 of them, dealt like a shuffled deck so nothing repeats until all were heard). Each speaker also gets a tiny voice blip.

## Camera
One shared view while MNKI and Swan are close. When they drift far apart the screen
splits smoothly into two panels (side by side or stacked, depending on where they are),
and merges again when they meet. The leading character's panel has a gold frame, and a
minimap in the corner shows what has been scouted.

## How the Pacifist theme lives in the systems
- No attack, no health, no weapons. The teddy guards walk MNKI back to the gate if they catch him.
- **Harming a teddy fails the run.** Garden traps sit in corridors. A teddy that is chasing in a hurry will run over one and get hurt. Teddies on patrol or investigating noise walk around traps, and a teddy that loses sight of you turns careful again. Break line of sight, hide in a bush, or disarm traps (hold E) before anything gets chased through them.
- A red "DANGER" warning appears when a chasing teddy is heading for a trap. The HUD shows a "Teddies hurt" counter (heart icon) that should stay at 0.
- Swan flies over hedges, low walls and streams and reveals a wide area including teddy view cones.
- MNKI cuts hedges for shortcuts, but the noise pulls teddies over: risk vs. reward.
- The follower never walks blindly into a teddy's view cone: it stops and waits.
- Red apples (in baskets) are for MNKI, golden pears (on little pear trees behind low garden walls) are for Swan.
- The **exit gate** beside the fountain is locked until every fruit is collected. Bring both friends through it to win.

## The garden (all vector placeholders)
Trees (green, blossom, autumn gold), flower planters and wild flowers, hedges, bushes (hiding spots), ponds with lily pads,
**streams with wooden bridges** (water blocks MNKI, Swan flies over it, bridges let both cross), a fountain, lamp posts,
statues, benches, bird baths, picnic blankets, mushrooms, butterflies, the entrance **gate** and the **exit** gate.
Decoration is placed by a per-tile hash of the maze seed, so it never flickers and every random garden looks different.

## Files
- `Autoloads/PlayerData.gd` - input registration, best time, maze seed, saved volume settings
- `Autoloads/Sound.gd` - audio buses, adaptive music, ambience, SFX pool (`Sound.play("name")`)
- `Autoloads/Transition.gd` - fade-to-black scene changes
- `Game/AudioOptions.gd` - the volume sliders; `Game/DrawProxy.gd` - helper node for WorldDraw's cached layers
- `tools/` - `make_audio.py` (sound generator), `smoke_test.gd`, `bench.gd`
- `Game/Level.gd` - maze generation (seeded), tiles, line of sight, A* grids
- `Game/Guard.gd` - teddy guard AI: patrol / notice / chase / search / recover
- `Game/Hero.gd` - character data
- `Game/Tower.gd` - sling teddy on a watchtower; `Game/Speech.gd` - speech bubbles and all dialogue lines
- `Game/Game.gd` - leader/follower, split-screen cameras, hedge cutting, trap disarming, fruit, fog of war, HUD, win/lose
- `Game/WorldDraw.gd` - draws the garden (shared by both camera views)
- `Game/Sprites.gd` - vector placeholder MNKI, Swan and teddy guard (used by the game and the title screen)
- `UI/GardenTheme.tres` - shared menu / panel / button theme (textures from `Art/Common`)
- `UI/HUD.gd` + `UI/HUD.tscn` - HUD
- `Menus/Main_Menu.*` - title, how to play

## Using your own art (GUI / HUD / icons are real scenes now)
Nothing in the UI is drawn in code any more. Every screen is a `.tscn` with a named node hierarchy - open it, select a node,
drop your texture on it. Every image is a PNG slot in `Art/` (full list: `Art/README.txt`); replace the file with the same name
and it just works. Colours / fonts / sizes: `UI/GardenTheme.tres` (buttons, panels, sliders, label styles), set as the project theme.

| Scene | What it is |
|---|---|
| `Menus/Main_Menu.tscn` | title: Background, TitleCard, Logo, buttons (+ instances of HowToPlay, OptionsMenu) |
| `Menus/HowToPlay.tscn`, `Menus/OptionsMenu.tscn` | overlays |
| `UI/HUD.tscn` | in-game HUD: SplitFrames, TopBar (FruitPanel / LeaderPanel / PeacePanel), Minimap, KeyHints, TouchControls, Toast, Pause/Win/Lose |
| `UI/PauseMenu.tscn`, `UI/WinScreen.tscn`, `UI/LoseScreen.tscn` | end / pause screens (banners, badge, stat icons) |
| `UI/Minimap.tscn`, `UI/SpeechBubble.tscn`, `UI/TouchControls.tscn`, `UI/RotateDevice.tscn` | HUD parts |
| `UI/Components/*.tscn` | reusable bits: FruitSlot, KeyHint, StatRow, VolumeRow, OptionsPanel, TouchButton |
| `Autoloads/Transition.tscn` | fade overlay (autoload) |
| `Game/Game.tscn` | Views (2 viewports + cameras), World, BubbleLayer, AlertIcons, HUD |

Scripts only fill these nodes with data (`UI/HUD.gd`, `Game/BubbleLayer.gd`, ...). Placeholder art: `tools/make_ui_placeholders.py`
(never overwrites). Screenshots of every screen: `godot --path . --script res://tools/ui_shots.gd` (needs a display).
The garden world (trees, water, gate, characters) is still vector code in `Game/WorldDraw.gd` / `Game/Sprites.gd`.

## Tuning (top of each script)
`Game.gd`: speeds, `CUT_TIME`, `CHIRP_COOLDOWN`, `BONK_STUN`. `Guard.gd`: `VIEW_RANGE`, `CHASE_SPEED`, `HIDE_SAFE`, `HALF_ANGLE_COS`. `Tower.gd`: `RANGE`, `AIM_TIME`, `COOLDOWN`, `LEAD`. `Level.gd`: tower count in `_place_towers`.
`Level.gd`: maze size `CW`/`CH`, shortcut count (14), bush count (22), bridge count (4, in `_place_bridges`).

## Still to do
Real art, tutorial prompts, export presets and a final playtest.
