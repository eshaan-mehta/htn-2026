# How Humanity's Last Fight works

The whole game is one Lua file, `last_fight.lua`, about 385 lines. It runs on the Hack the North 2026 Hacker Badge: an ESP32-C3 at 80 MHz, a 320x240 screen driven by LVGL, six RGB LEDs, and a handful of buttons. This document explains how the game is built and why it is built that way.

Contents

1. [The badge and its limits](#1-the-badge-and-its-limits)
2. [File layout and lifecycle](#2-file-layout-and-lifecycle)
3. [State machine](#3-state-machine)
4. [Timing: fixed-step simulation](#4-timing-fixed-step-simulation)
5. [Rendering with boxes](#5-rendering-with-boxes)
6. [Stage themes](#6-stage-themes)
7. [Fighter physics](#7-fighter-physics)
8. [Attacks, blocking, knockback](#8-attacks-blocking-knockback)
9. [Stocks, ring-outs, KO](#9-stocks-ring-outs-ko)
10. [The AI](#10-the-ai)
11. [End screens and the typewriter](#11-end-screens-and-the-typewriter)
12. [The AGI cutscene](#12-the-agi-cutscene)
13. [LEDs](#13-leds)
14. [Memory: the real budget](#14-memory-the-real-budget)
15. [Optimizations](#15-optimizations)
16. [Testing without a badge](#16-testing-without-a-badge)
17. [Things that did not work](#17-things-that-did-not-work)
18. [Function index](#18-function-index)

## 1. The badge and its limits

The badge runs Lua apps in a sandbox. An app gets four callbacks (`on_enter`, `on_tick`, `on_button`, `on_exit`) and a `badge` table with the hardware API. The parts of that API this game uses:

| API | Used for |
|---|---|
| `badge.ui.box`, `badge.ui.label` | Every visual. There is no canvas, no pixel access, and no sprite sheet. |
| `widget:set_pos`, `set_size`, `hidden`, `style`, `set_text`, `set_border`, `align` | Moving and recoloring widgets. This is the entire animation toolkit. |
| `badge.input.is_down`, `on_button` | Held buttons and press events. |
| `badge.led.set`, `set_all`, `clear`, `show` | The six LEDs. |
| `badge.sys.ms`, `badge.sys.random`, `badge.sys.stats`, `badge.sys.log` | Clock, RNG, heap numbers, serial log. |

Constraints that I had to keep in mind:

- **Widget based design** Everything on screen is a rectangle with an optional corner radius. Fighters, hills, clouds, stars, blood, all boxes.
- **RAM.** The manifest asks for a 96 KiB Lua quota, but the badge has about 76 KB of free system heap when the launcher is open. Compiling the file eats most of it. Section 14 covers this in detail.
- **No usable radio.** The game was intially designed as a two-badge PvP fighter, but due to the high memory demands of the bluetooth module, I pivoted to a PvE game.
- **Tick budget.** The firmware calls `on_tick` repeatedly and kills the app if one call runs too long. No heavy work in a single tick.

## 2. File layout and lifecycle

The file starts with a manifest block the badge IDE reads:

```
--[==[badge-app
slug=last_fight
name=Humanity's Last Fight
icon=HLF
api=2
heap_kb=96
wake_lock=1
]==]
```

`slug` is the folder name on the badge. `heap_kb=96` raises the Lua quota from 48 KiB. `wake_lock=1` keeps the screen on during a match.

After the manifest, the file is organized top to bottom as constants and data tables, then small helpers, then game systems, then the four callbacks. All state lives in module-level locals so every function can reach it without passing it around.

Lifecycle:

- `on_enter(root)` logs heap usage, builds every widget the game will ever use, applies the current theme, and shows the menu.
- `on_tick()` advances the clock, runs whichever state is active, and refreshes the LEDs every 50 ms.
- `on_button(b, kind)` handles presses. Held buttons are polled instead.
- `on_exit()` turns the LEDs off.

## 3. State machine

One string variable, `st`, holds the state.

| State | What is on screen | Leaves when |
|---|---|---|
| `menu` | Title, controls, difficulty selector over a dimmed live stage | A pressed, goes to `count` |
| `count` | 3, 2, 1, FIGHT! | 3.6 s elapsed, goes to `play` |
| `play` | The fight | When a fighter loses, goes to `ko` or `cut` |
| `ko` | Result headline with typed text feeling, rematch prompt | A restarts (`count`), B or Start goes to `menu` |
| `cut` | The cutscene(s) | 11.5 s elapsed, goes to `ko`. Start skips to `menu` |

Other state variables: `di` is the difficulty index 1 to 3, `ct` is the timestamp the current state began, `kw` is the winner index after a KO, `Z` is the cutscene zoom factor, `acc` and `last` drive the fixed-step clock.

## 4. Timing: fixed-step simulation

Game logic runs in fixed 20 ms steps regardless of how often `on_tick` is called. Each tick:

```lua
acc = math.min(acc + now - last, STEP * 3)
last = now
while acc >= STEP do
  acc = acc - STEP
  -- read inputs, run AI, step both fighters
end
draw(F[1]); draw(F[2])
```

`acc` accumulates real time. The loop consumes it in 20 ms chunks so physics is deterministic no matter the frame rate. The cap at three steps means a long stall slows the game briefly instead of running a burst of catch-up steps. Rendering happens once per tick, after the steps.

Input has two paths. Held buttons (Left, Right, B for block) are polled with `is_down` at each step. Presses (A for attack, Up for jump) arrive through `on_button` and are latched into `pa` and `pu`. The next step consumes and clears them. A press between steps is never lost and never counted twice.

## 5. Rendering with boxes

Every widget is created once in `on_enter` and reused forever. Nothing is created or deleted during play. Animation is `set_pos`, `set_size`, `hidden`, and `style`.

Draw order is creation order, so `on_enter` creates back to front:

1. Four sky bands, 320x60 each. Four colors stacked make a fake vertical gradient.
2. Four hills, bottom-aligned boxes of different widths and heights.
3. Ten stars, 3x3 boxes at `((k*61) % 310 + 4, (k*37) % 90 + 6)`. The formula gives a scattered layout with no coordinate table.
4. One orb, the sun or moon.
5. Six cloud boxes: three bodies and three smaller bumps offset up and right.
6. Dirt under the platform, then the platform itself.
7. The two fighters, three boxes each.
8. HUD labels, stock dots, and the YOU / AI name tags.
9. The blood pool for the cutscene.
10. A full-screen black overlay, then the menu and message labels.

A fighter is three boxes anchored to its feet position `(x, y)`:

| Box | Size | Position | Notes |
|---|---|---|---|
| Body | 14x22, radius 2 | `(x-7, y-22)` | Yellow for you, red for the AI. Darker shade while blocking. |
| Head | 10x10, radius 3 | `(x-5, y-32)` | Lighter tint of the body color. |
| Attack | 18x12, radius 2 | `(x+7, y-22)` facing right, `(x-25, y-22)` facing left | White. Visible only during active attack frames. |

`draw(f)` moves the three boxes and caches two booleans per fighter: `sa` (attack box visible) and `sb` (block color applied). It only calls `hidden` or `style` when the value changes. Each of those calls invalidates a screen region in LVGL, so skipping redundant ones matters on an 80 MHz chip. A fighter waiting to respawn is parked at `(-50, -50)`.

The HUD is two labels ("You 30%", "AI 10%") at the top corners and three 10x10 red dots per side for stocks. `hudup()` rewrites both labels and hides dots for lost stocks. It runs only when something changed: a hit or a fall.

The menu draws over the live stage. The black overlay at 130/255 opacity dims everything behind it, and the title, control legend, and difficulty selector sit on top. Because the stage underneath is real, changing difficulty in the menu previews that stage's environment through the dim.

Labels use fonts 14, 16, 20, and 24. Multi-line text uses explicit `\n` breaks rather than relying on wrapping.

## 6. Stage themes

All three environments share one set of widgets. The `TH` table has one row of 16 values per difficulty:

```
sky1 sky2 sky3 sky4  hillColor hillRadius  cloudColor  starColor
orbColor orbW orbH orbX orbY  platformColor dirtColor platformBorder
```

`theme()` walks the widgets and restyles them from the row. Switching environments is a data change, not new code, which is why three stages fit in the memory budget.

| | CHATBOT | AGENT | AGI |
|---|---|---|---|
| Sky | Blue, lighter toward the horizon | Deep purple to dusty pink | Black to dark red |
| Hills | Muted blue, rounded | Near-black, rounded | Pure black, square (radius 0), read as towers |
| Clouds | White | Storm grey | Dark red smoke |
| Stars | Hidden | White | Red embers |
| Orb | Yellow sun, 30 px | Pale moon, 24 px | None |
| Platform | Grass green with brown dirt | Dead olive with dark dirt | Near-black with a 2 px red border |

Two details came from testing on hardware. The CHATBOT hills were originally green and merged visually with the green platform, so they became blue and read as distant. The orb sits at the top centre, at y 6 to 36, because the stock dots occupy y 34 to 44 at both sides and anything there covers them.

## 7. Fighter physics

`step(f, o)` advances fighter `f` by one 20 ms step. `o` is the opponent. The player and the AI run the exact same function; the only difference is who fills in the input table `f.inp`.

Constants, per step:

| Constant | Value | Meaning |
|---|---|---|
| `G` | 0.4 | Gravity added to `vy` each step, capped at 9 |
| `WALK` | 3 | Horizontal speed, multiplied by the fighter's `spd` |
| Jump | -7 | Set as `vy` on jump |
| `PY` | 170 | Platform surface y |
| `PX1`, `PX2` | 40, 280 | Platform left and right edges |

Movement rules:

- Walking sets `vx` directly and turns the fighter. No input on the ground sets `vx` to 0. A fighter that cannot act (stunned or mid-attack) on the ground decelerates by 40% per step.
- Jump sets `vy = -7`. In the air, one more jump is allowed if `dj` (double jump available) is true. Landing resets it.
- Landing happens when `vy > 0`, the fighter crossed `PY` this step, and `x` is within 6 px of the platform. It snaps `y` to `PY` and clears `air`. Walking past an edge sets `air` and gravity takes over.
- Ring-out is `y > 260`, `x < -40`, or `x > 360`. See section 9.

## 8. Attacks, blocking, knockback

An attack is a counter, `f.atk`, that runs from 1 to 17 (340 ms) and then returns to 0.

| Frames | Phase | Effect |
|---|---|---|
| 1 to 4 | Startup | Nothing yet. The AI reads frame 1 to decide whether to block. |
| 5 to 9 | Active | Attack box visible. Hit test runs. |
| 10 to 17 | Recovery | Vulnerable. The AI reads frame 10 to punish. |

Starting an attack on the ground stops horizontal movement. Attacks are allowed in the air.

The hit test runs during active frames, once per swing (the `hit` flag). It hits when the opponent is alive and within 16 px horizontally of a point 16 px in front of the attacker and within 22 px vertically.

Blocking is B held on the ground while free to act, with no cooldown pending. Letting go, or losing the ground, drops the block and starts a 10-step cooldown (`bcd`), so it cannot be held forever or tapped repeatedly. A block only counts against attacks from the front: `d * o.face < 0`, where `d` is the direction from attacker to defender. A blocked hit pushes the defender back 2 px per step for a moment and does nothing else.

An unblocked hit:

```lua
o.dmg = o.dmg + 10
o.vx  = d * (3 + o.dmg * 0.06)
o.vy  = -(2 + o.dmg * 0.03)
o.stun = 8 + floor(o.dmg / 8)
```

Knockback and stun scale with accumulated damage. At 50% a hit sends the victim at 6 px per step sideways with 14 steps of stun. At 100% it is 9 px per step and 20 steps. The hit also cancels the victim's attack, drops their block, marks them airborne, and sets a 100 ms flash timer the LEDs read.

## 9. Stocks, ring-outs, KO

Each fighter starts with three stocks. Falling below the screen or far past either side removes one. If stocks remain, the fighter goes into a 50-step (1 s) dead state, hidden off-screen, then respawns above the platform centre and falls in. The message "You fell!" or "AI fell!" shows until respawn.

When a fighter loses its last stock, `kw` becomes the winner's index and `END[di][kw]` decides what happens next. `END` holds one win line and one loss line per difficulty. A string means the result screen. `false` means the cutscene. Only the AGI loss is `false`.

## 10. The AI

`ainp(f, o)` runs once per step before `step()`. It writes into the AI's input table exactly like a controller would, so the AI has no physics advantages. Its edge is reaction time and the fact that it reads the player's attack counter directly.

Per-difficulty parameters from the `DIFF` table:

| Parameter | CHATBOT | AGENT | AGI | Meaning |
|---|---|---|---|---|
| `spd` | 0.6 | 1.0 | 1.25 | Walk speed multiplier |
| `cd` | 90 | 45 | 38 | Steps between attacks |
| `bp` | 0 | 30 | 65 | Percent chance to block a swing it sees starting |
| `pun` | no | no | yes | Attacks into the player's recovery frames |
| `hop` | no | no | yes | Random jumps and air hops |
| `tm` | 5 | 40 | 100 | Percent chance per step to attack when in range and off cooldown |
| `rec` | no | yes | yes | Uses double jump to get back to the platform |

Behaviour each step:

1. **Approach.** If the player is alive and more than 26 px away, walk toward them. Otherwise stand and face them.
2. **Attack.** When the cooldown timer `f.t` has expired and the player is within 30 px, attack with probability `tm`. Weak AIs (`tm < 50`) also throw a rare early swing from up to 70 px away, 1% per step, so they are not perfectly passive. With `pun`, the AI attacks immediately if the player is within 36 px and has just entered recovery (`o.atk == 10`). Any attack resets `f.t` to `cd`.
3. **Block.** If the player's swing just started (`o.atk == 1`) within 44 px, block with probability `bp` and hold it for 14 steps. That covers the active frames.
4. **Recover.** In the air past an edge, steer back toward the platform. With `rec` and a double jump available, jump. With `hop`, there is a 4% per step chance to double jump while falling and a 2% chance to hop on the ground.

CHATBOT never blocks, never recovers, and attacks about once every two seconds if you stand next to it. AGI attacks the moment it is in range, blocks two thirds of your swings, punishes every whiff, and gets back on stage.

## 11. End screens and the typewriter

On a KO that is not the AGI loss, the headline "YOU WIN!" or "AI WINS" appears at once in font 24. After 800 ms the flavor line from `END` types in below it at 140 ms per character. The rematch prompt appears only when the line is complete.

`typ(w, tx, t)` does the typing. Given a widget, the full text, and elapsed milliseconds, it computes how many characters should be visible, and calls `set_text` only when that number changed since the last call (cached in `sn`). It returns true once the whole string is shown. The cutscene uses the same function for its line.

## 12. The AGI cutscene

Losing to AGI triggers an 11.5 second scene. It is drawn with the same fighter boxes, moved and resized every tick.

**Camera.** `wb(w, x, y, ww, hh)` places a widget from world coordinates, scaling about the player's spot `(150, PY)` by the zoom factor `Z`:

```
screen_x = 150 + (x - 150) * Z
screen_y = PY  + (y - PY)  * Z
size     = (ww * Z, hh * Z)
```

Every object on the platform (platform, dirt, both fighters, the blade, the pool) is drawn through `wb` each tick. Sky, clouds, and stars are not scaled, which reads as distance. `Z` eases from 1 to 2.2 over 1.5 seconds with `u = 1 - min(1, t/1500); Z = 2.2 - 1.2 * u * u`.

**Setup at the KO.** The AI is placed at world x 236, which is off-screen once zoomed. Both attack boxes hide. The AI's attack box is recolored red to become the blade. HUD, stock dots, and hills hide. The menu overlay is recolored white at 230/255 opacity but stays hidden. The message label turns red.

**Timeline**, `t` in milliseconds since the KO:

| t | What happens |
|---|---|
| 0 to 1500 | Zoom in. The player trembles, x alternating 150 and 151 every 100 ms. LEDs beat slow red. |
| 1500 to 2500 | Hold. |
| 2500 to 5500 | The AI walks in from the right, world x 236 to 176 at 0.02 px per ms. |
| 5500 | Blade appears raised above the AI's head. |
| 6500 to 6700 | Blade drops to neck height. The white overlay covers the screen. All LEDs white. |
| 6700 | Overlay and blade hide. The body box becomes 22x10 lying on the platform. The head becomes a projectile at `(150, PY-27)` with velocity `(-1.6, -5)`. The pool appears. |
| 6700 onward | Fixed-step physics on the head: gravity, a bounce when it meets the platform (`vy * -0.4`, `vx * 0.7`), then it rolls off the left edge. The pool widens from 4 to 60 world pixels over 3.4 s. |
| 7800 | "It's our time now" types into the red message label. |
| 11500 | State becomes `ko`. Rematch prompt appears. |

Start skips to the menu at any point. `place()`, which both the menu and a rematch call, undoes everything the cutscene changed: `Z` back to 1, fighter box sizes, blade color, overlay back to black at 130, message color white, hills shown, pool hidden.

## 13. LEDs

`leds(now)` runs every 50 ms. `SIDE` maps the left three LEDs `{1, 6, 5}` to you and the right three `{2, 3, 4}` to the AI.

| State | LEDs |
|---|---|
| `menu` | Difficulty color: dim green, amber, or red |
| `count` | White brightening with each count, green on FIGHT! |
| `play` | Each side fades green to red as that fighter's damage climbs from 0 to 100%. White for 100 ms after taking a hit. |
| `ko` | Winner's body color on all six |
| `cut` | Red heartbeat every 400 ms, all white during the strike |

The damage ramp is `t = min(dmg, 100) / 50`, red `150 * min(1, t)`, green `150 * min(1, 2 - t)`.

## 14. Memory: the real budget

This is the biggest constraint that determined the game's direction

The badge reports about 76 KB of free system heap with the launcher open, with a largest contiguous block of about 62 KB. Opening an app compiles its Lua source in that space. Every function, table, string, and constant array becomes a separate heap allocation with its own bookkeeping overhead. Compiled code lands around 2.5 to 2.75 bytes of RAM per byte of source, on top of about 16 KB for the Lua runtime itself.

A build that grew to 16.1 KB of source failed to open with:

```
Lua memory limit exceeded (used 41855 / limit 98304, peak 48125)
```

Used and peak are far below the 96 KiB quota. The message is the badge's generic error for the system allocator returning nothing. The quota was never the limit. Physical RAM was.

Two findings from that failure:

- **Source text size does not matter.** A minified copy of the same file, 12.6 KB with identical bytecode, failed the same way. Comments and whitespace cost nothing.
- **Compiled size does.** Stripped bytecode from `luac -s` is a good proxy. The version that ran was 13,974 bytes. The one that failed was 15,286. The current file is 13,994. Treat about 14.0 KB as the ceiling.

Widgets are cheap, roughly 140 bytes each. The game's fifty-odd widgets are not the problem. Code is.

## 15. Optimizations

Changes made specifically to fit, roughly in order of how much they saved:

- **Blood particles removed.** Six boxes with their own spawn and physics loops. The pool alone carries the effect.
- **Stock hearts became dots.** The hearts were `line` widgets drawn from an 11-point table, which is 12 Lua tables and their allocations. A 10x10 box with radius 5 is one call.
- **Theme table flattened.** Nested sub-tables for sky, hills, and orb became one flat row of 16 values per theme. Nine fewer tables at load and simpler indexing code.
- **Shared widgets, restyled.** One set of background widgets for all three stages instead of three sets. `theme()` is data-driven.
- **Camera helpers inlined.** `sx` and `sy` folded into `wb`, and the scene-drawing function folded into `cut`. Every function is a Proto with several allocations.
- **LED simplification.** The KO chase (a rotating lit LED with its own timer state) became a solid color. The countdown's per-LED loop became `set_all`.
- **Helpers for repeated patterns.** `box`, `label`, `hint`, `typ`, and `wb` replace sequences that appeared many times. Fewer instructions and fewer distinct constants.
- **`floor` as a local.** `math.floor` is called more than twenty times. A local upvalue is one instruction per use instead of two table lookups.
- **Constants shared.** The rematch prompt string exists once as `RM`.
- **Stars from a formula.** Ten positions computed from `k` rather than stored.

Runtime allocations are minimal as well. Input tables are reused, no widgets are created after `on_enter`, and per-tick garbage is limited to a small style table when a fighter starts or stops blocking or attacking, plus the HUD string when damage changes.

## 16. Testing without a badge

Most iteration happened without hardware. A stub `badge` table stands in for the real API:

- Widgets are Lua tables whose methods record calls and raise an error if any coordinate or size argument is not an integer, since LVGL rejects fractional values.
- `badge.sys.ms` returns a clock the script advances by 25 ms per tick.
- `badge.input.is_down` can be forced to report Left held, so the player walks off the platform and loses on purpose.
- `badge.sys.random` uses `math.random`.

Scripts load the game, call `on_enter`, then drive `on_button` and `on_tick` through menu, all three difficulties, a full countdown and fight, a KO with typed text, the entire cutscene, and a rematch afterward. They print the sequence of `set_text` calls with timestamps, which verifies the typewriter pacing and the cutscene timeline, and they surface nil-index and non-integer bugs before anything is pushed to a badge.

Alongside that, `luac -p` checks syntax and `luac -s` gives the bytecode size to hold against the 14 KB ceiling. Each harness script is under 60 lines of plain Lua and needs only the standard `lua` interpreter.

## 17. Things that did not work

- **Two-badge multiplayer.** The original design was a 1v1 fighter over the badge radio: each badge simulates its own fighter, broadcasts position and state, and the receiver decides whether it was hit. Pairing was going to be a physical bump detected by the accelerometer. On firmware v0.1.2-392, `badge.radio.enable()` consumed about 47 KB during Bluetooth initialization and then timed out waiting for host sync, even for the vendor's own 1.7 KB demo. Netplay is blocked at the firmware level. The AI opponent replaced it.
- **Pixel-art sprites.** The plan was to generate LVGL image files at launch from palette strings and animate by showing and hiding image widgets. Each frame costs about 1.2 KB of RAM and mirrored facings need separate files. The memory was not there. Fighters stayed as boxes.

## 18. Function index

| Function | Role |
|---|---|
| `spawn(f, x)` | Reset a fighter's motion and combat fields at x, above the platform |
| `hudup()` | Rewrite damage labels and stock dots |
| `hint(t)` | Set or hide the bottom hint line |
| `typ(w, tx, t)` | Typewriter reveal, returns true when done |
| `wb(w, x, y, ww, hh)` | Place a widget from world coordinates through the zoom `Z` |
| `draw(f)` | Position a fighter's three boxes, with change caching |
| `place(m)` | Put both fighters on the platform, reset everything a cutscene touched, show or hide menu widgets |
| `cut(now)` | Run the AGI loss cutscene for the current tick |
| `theme()` | Restyle all background widgets for the current difficulty |
| `menu()` | Enter the menu state |
| `start(now)` | Load AI parameters and enter the countdown |
| `ainp(f, o)` | AI: fill in the AI fighter's inputs |
| `step(f, o)` | One 20 ms physics and combat step for a fighter |
| `leds(now)` | Set the six LEDs for the current state |
| `box(...)`, `label(...)` | Create a styled box or label in one call |
| `on_enter`, `on_tick`, `on_button`, `on_exit` | Badge callbacks |
