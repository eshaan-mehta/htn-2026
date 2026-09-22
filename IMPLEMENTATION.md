# How Humanity's Last Fight works

The whole game is one Lua file, `last_fight.lua`, about 375 lines. It runs on the Hack the North 2026 Hacker Badge: an ESP32-C3 at 80 MHz, a 320x240 screen driven by LVGL, six RGB LEDs, and a handful of buttons. This document explains how the game is built and why it is built that way.

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
12. [The AGI cutscenes](#12-the-agi-cutscenes)
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
| `widget:set_pos`, `set_size`, `hidden`, `style`, `set_color`, `set_text`, `set_border`, `align` | Moving and recoloring widgets. This is the entire animation toolkit. |
| `badge.input.is_down`, `on_button` | Held buttons and press events. |
| `badge.led.set`, `set_all`, `clear`, `show` | The six LEDs. |
| `badge.sys.ms`, `badge.sys.random` | Clock and RNG. |

Constraints that I had to keep in mind:

- **Widget based design.** Everything on screen is a rectangle with an optional corner radius. Fighters, hills, clouds, stars, blood, all boxes.
- **RAM.** The manifest asks for a 96 KiB Lua quota, but the badge has about 76 KB of free system heap when the launcher is open. Compiling the file eats most of it. Section 14 covers this in detail.
- **No usable radio.** The game was initially designed as a two-badge PvP fighter, but due to the high memory demands of the Bluetooth module, I pivoted to a PvE game.
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

After the manifest, the file is organized top to bottom as constants, then small helpers, then game systems, then the four callbacks. All state lives in module-level locals so every function can reach it without passing it around. Most of the game's data is not in Lua tables but in short binary strings decoded on use (section 15 explains why).

Lifecycle:

- `on_enter(root)` builds every widget the game will ever use, then calls `place(1)` to show the menu.
- `on_tick()` advances the clock, runs whichever state is active, and refreshes the LEDs every 50 ms.
- `on_button(b, kind)` handles presses. Held buttons are polled instead.
- `on_exit()` turns the LEDs off.

Two files ship alongside the source. `last_fight.min.lua` is the same program with comments and spacing stripped, for pasting into the IDE. `tools/minify.py` generates it, dropping comments, blank lines and optional spacing, so its line numbers do not match the readable file.

## 3. State machine

One integer variable, `st`, holds the state.

| `st` | State | What is on screen | Leaves when |
|---|---|---|---|
| 1 | menu | Title, controls, difficulty selector over a dimmed live stage | A pressed, goes to 2 |
| 2 | countdown | 3, 2, 1, FIGHT! | 3.6 s elapsed, goes to 3 |
| 3 | play | The fight | When a fighter loses, goes to 5 or 4 |
| 4 | cutscene | The AGI ending, win or loss | 11.5 s elapsed, goes to 5. Start skips to 1 |
| 5 | ko | Result headline with typed text, rematch prompt | A restarts (2), B or Start goes to 1 |

Every transition except 3 to 5 goes through one function, `place(m, now)`, where `m` is the state to enter. It sets up the whole scene for that state: which widgets are hidden, the overlay colour, fighter positions, AI parameters, LED state, and it re-applies the stage theme. Having one setup function means a cutscene or a menu visit can change anything it likes, because the next `place()` puts everything back.

Other state variables: `di` is the difficulty index 1 to 3, `ct` is the timestamp the current state began, `kw` is the winner index after a KO, `Z` is the cutscene zoom factor, `acc` and `last` drive the fixed-step clock, and `god` is the god-mode toggle.

## 4. Timing: fixed-step simulation

Game logic runs in fixed 20 ms steps regardless of how often `on_tick` is called. Each tick in state 3:

```lua
acc = min(acc + now - last, STEP * 3)
last = now
while acc >= STEP and st == 3 do
  acc = acc - STEP
  -- read inputs, run AI, step both fighters
end
frame()
```

`acc` accumulates real time. The loop consumes it in 20 ms chunks so physics is deterministic no matter the frame rate. The cap at three steps means a long stall slows the game briefly instead of running a burst of catch-up steps. The `st == 3` guard stops the loop the moment a step ends the fight, so a slow tick cannot run a second step over the KO. Rendering happens once per tick, after the steps.

Input has two paths. Held buttons (Left, Right, B for block) are polled with `is_down` at each step. Presses (A for attack, Up for jump) arrive through `on_button`, which writes them straight into your input table as `atk` and `up`. The step loop clears them after each step. A press between steps is never lost and never counted twice.

## 5. Rendering with boxes

Every widget is created once in `on_enter` and reused forever. Nothing is created or deleted during play. Animation is `set_pos`, `set_size`, `hidden`, and `set_color`.

Draw order is creation order, so `on_enter` creates back to front:

1. Four sky bands, 320x60 each. Four colors stacked make a fake vertical gradient.
2. Four hills, bottom-aligned boxes of different widths and heights.
3. Ten stars, 3x3 boxes at `((k*61) % 310 + 4, (k*37) % 90 + 6)`. The formula gives a scattered layout with no coordinate table.
4. One orb, the sun or moon.
5. Six cloud boxes: three bodies and three smaller bumps offset up and right.
6. Dirt under the platform, then the platform itself.
7. The two fighters, three boxes each.
8. HUD labels, stock dots, and the YOU / AI name tags.
9. The blood pool for the loss cutscene.
10. A full-screen black overlay, then the seven text labels.

The seven labels (title, key legend, action legend, difficulty, hint, message, sub-line) are built from one spec string, `name|text|font|align|anchor|dx|dy;...`, walked with `gmatch`. It replaced seven near-identical call sequences with one loop.

A fighter is three boxes anchored to its feet position `(x, y)`:

| Box | Size | Position | Notes |
|---|---|---|---|
| Body | 14x22, radius 2 | `(x-7, y-22)` | Gold for you, red for the AI. Darker shade while blocking. |
| Head | 10x10, radius 3 | `(x-5, y-32)` | Lighter tint of the body color. |
| Attack | 18x12, radius 2 | `(x+7, y-22)` facing right, `(x-25, y-22)` facing left | Body color. Visible only during active attack frames. |

The six colours live in one flat table, `FC`: bodies at 1 and 2, heads at 3 and 4, blocking bodies at 5 and 6, so the blocking colour is `FC[f.i + 4]`.

`draw(f)` places the three boxes through `wb()`, the camera helper from section 12, so the same function draws the fight (zoom 1) and the cutscene (zoom up to 2.2). It caches two booleans per fighter: `sa` (attack box visible) and `sb` (block color applied), and only calls `hidden` or `set_color` when the value changes. Each of those calls invalidates a screen region in LVGL, so skipping redundant ones matters on an 80 MHz chip. A fighter waiting to respawn is parked at `(-50, -50)`. `frame()` draws the platform, the dirt, and both fighters; it is the one call every state uses to refresh the stage.

The HUD is two labels ("You 30%", "AI 10%") at the top corners and three 10x10 red dots per side for stocks. `hudup()` rewrites both labels and hides dots for lost stocks. It runs only when something changed: a hit or a fall.

The menu draws over the live stage. The black overlay at 130/255 opacity dims everything behind it, and the title, control legend, and difficulty selector sit on top. Setting a box's `bg_color` also makes it opaque, and the firmware applies the keys of one `style{}` table in no fixed order, so `place()` sets the overlay's colour with `set_color` first and its opacity with a separate `style{bg_opa}` call. An earlier build put both in one table and the menu came out opaque on some launches, depending on which key was applied last. Because the stage underneath is real, changing difficulty in the menu previews that stage's environment through the dim.

Labels use fonts 14, 16, 20, and 24. Multi-line text uses explicit `\n` breaks rather than relying on wrapping.

## 6. Stage themes

All three environments share one set of widgets. The difficulty data is a 126-byte binary string, 42 bytes per difficulty, laid out big-endian:

```
sky1 sky2 sky3 sky4 hill   (3 bytes each)   hillRadius (1)
cloud star orb            (3 each, 0 = none)  orbSize orbX orbY (1 each)
platform dirt border      (3 each)           borderWidth (1)
aiSpeed aiCooldown aiBlock aiAggression (1 each, section 10)
```

`theme(d)` unpacks the row for difficulty `d` with one `unpack` call into twenty locals, restyles the widgets from the first sixteen and writes the AI's parameters from the last four. Switching environments is a data change, not new code, which is why three stages fit in the memory budget. `d` defaults to the selected difficulty; the win cutscene passes 1 to bring back the daytime stage, and the next `place()` restores the real one.

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

Blocking is B held on the ground while free to act, with no cooldown pending. Letting go, or losing the ground, drops the block and starts a 10-step cooldown (`bcd`), so it cannot be held forever or tapped repeatedly. The stun, block-cooldown and AI timers count down every step without a floor, so `<= 0` means expired and idle fighters carry negative counters. A block only counts against attacks from the front: `d * o.face < 0`, where `d` is the direction from attacker to defender. A blocked hit pushes the defender back 2 px per step for a moment and does nothing else.

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

When a fighter loses its last stock, `kw` becomes the winner's index. The end line for every difficulty and outcome comes from one six-entry table indexed by `di * 2 + kw - 2` and is stored in `sub`. On CHATBOT and AGENT the game goes straight to state 5 with a headline, and the line types in below it. On AGI, either outcome starts a cutscene, which types the same `sub` into the message label: the KO handler zeroes both attack counters so no attack box lingers, clears the winner's respawn timer, and calls `place(4)`.

## 10. The AI

`ainp(f, o)` runs once per step before `step()`. It writes into the AI's input table exactly like a controller would, so the AI has no physics advantages. Its edge is reaction time and the fact that it reads the player's attack counter directly.

The per-difficulty parameters are the last four bytes of the difficulty row in section 7: speed times 20, attack cooldown, block chance, aggression. `theme()` writes them into the AI fighter whenever it applies a row (the win cutscene's `theme(1)` briefly writes CHATBOT's values, after the fight is over; the next `place()` restores the real ones).

| Parameter | CHATBOT | AGENT | AGI | Meaning |
|---|---|---|---|---|
| `spd` | 0.6 | 1.0 | 1.25 | Walk speed multiplier |
| `cd` | 90 | 45 | 38 | Steps between attacks |
| `bp` | 0 | 30 | 65 | Percent chance to block a swing it sees starting |
| `tm` | 5 | 40 | 100 | Percent chance per step to attack when in range and off cooldown |
| hop (`di == 3`) | no | no | yes | Punishes recovery frames, random jumps and air hops |
| recover (`di > 1`) | no | yes | yes | Uses double jump to get back to the platform |

The first four live in fighter fields. The last two are tests on `di` written where they are used, since the difficulty cannot change during a fight.

Behaviour each step:

1. **Approach.** If the player is alive and more than 26 px away, walk toward them. Otherwise stand and face them.
2. **Attack.** When the cooldown timer `f.t` has expired and the player is within 30 px, attack with probability `tm`. Weak AIs (`tm < 50`) also throw a rare early swing from up to 70 px away, 1% per step, so they are not perfectly passive. With `hop`, the AI attacks immediately if the player is within 36 px and has just entered recovery (`o.atk == 10`). Any attack resets `f.t` to `cd`.
3. **Block.** If the player's swing just started (`o.atk == 1`) within 44 px, block with probability `bp` and hold it for 14 steps. That covers the active frames.
4. **Recover.** In the air past an edge, steer back toward the platform. With `rec` and a double jump available, jump. With `hop`, there is a 4% per step chance to double jump while falling and a 2% chance to hop on the ground.

CHATBOT never blocks, never recovers, and attacks about once every two seconds if you stand next to it. AGI attacks the moment it is in range, blocks two thirds of your swings, punishes every whiff, and gets back on stage.

**God mode.** The badge exposes the slide switch next to the USB-C port as `BUTTON.AUX1`, and a flip arrives in `on_button` as a single press or release event. `on_button` toggles a `god` flag on any AUX1 event before it filters for presses, so the switch is edge-triggered: whichever position it starts in is normal. When a fight starts with the flag set, `place(2)` gives the AI 200 % damage, one stock and a zero block chance, so the first hit rings it out. The whole feature is three lines and 84 bytes of bytecode.

## 11. End screens and the typewriter

On a KO on CHATBOT or AGENT, the headline "YOU WIN!" or "AI WINS" appears at once in font 24. After 800 ms the flavor line types in below it at 140 ms per character. The rematch prompt appears only when the line is complete.

`typ(w, tx, t)` does the typing. Given a widget, the full text, and elapsed milliseconds, it computes how many characters should be visible, and calls `set_text` only when that number changed since the last call (cached in `sn`). It returns true once the whole string is shown. Both cutscenes use the same function for their line, typed into the message label instead of the sub line.

## 12. The AGI cutscenes

Both AGI endings are one 11.5 second scene driven by `cut(now)`, with the roles swapped. `p` is the victim and `a` the attacker: the AI when you lose, you when you win. The scene is drawn with the ordinary fighter boxes through `frame()`, moved and resized every tick.

**Camera.** `wb(w, x, y, ww, hh)` places a widget from world coordinates, scaling about the spot `(150, PY)` by the zoom factor `Z`:

```
screen_x = 150 + (x - 150) * Z
screen_y = PY  + (y - PY)  * Z
size     = (ww * Z, hh * Z)
```

Everything on the platform (platform, dirt, both fighters, the weapon, the pool) is drawn through `wb` each tick. Sky and stars are not scaled, which reads as distance. `Z` eases from 1 to 2.2 over 1.5 seconds with `u = min(0, t - 1500); Z = 2.2 - u * u / 1875000` (`u` is the time left, so `u * u / 1500^2` is the same ease-out as `1.2 * (1 - t/1500)^2` with one fewer operation and no second float constant).

**Setup at the KO** (`place(4)`). Hills and clouds hide, so the sky stays clear behind the final line. HUD, stock dots, and both attack boxes hide. The AI's attack box is recolored red to become its blade. The overlay is recolored to fully opaque white but stays hidden. The winner is not moved here: the walk-in formula below places it from the first tick. The message label turns red for a loss and stays white for a win.

**Timeline**, `t` in milliseconds since the KO:

| t | Both endings | Loss only (AI attacks) | Win only (you attack) |
|---|---|---|---|
| 0 to 1500 | Zoom in. The victim trembles, x alternating 150 and 151 every 100 ms. | LEDs beat slow red. | LEDs beat slow yellow. |
| 0 to 5500 | The attacker walks in 110 world px at 0.02 px per ms, `x = max(176, 236 - (t - 2500) * 0.02)`, mirrored for you. It is in view at the edge for the first second, the zoom carries it off-screen, and it walks back in around 2.9 s. | From the right, 286 to 176. | From the left, 14 to 124. |
| 5500 to 6500 | Weapon appears at body height in front of the attacker. | Blade holds still. | Wind-up: the fist snaps back 20 px in 200 ms (`a.x - min(14, t/10 - 556)`) and stays cocked for the remaining 800 ms. |
| 6500 | Strike, one shot. Weapon snaps onto the victim's body at x 141. Then 200 ms of hitstop with nothing moving. | White overlay covers the screen. | You lunge 8 px forward. No flash. |
| 6500 to 6700 | LEDs white (150) in both endings. | | |
| 6700 | Launch, one shot. Overlay and weapon hide. | Body becomes 22x10 lying flat. The head becomes a projectile at `(150, PY-27)` with velocity `(-1.6, -5)`. The pool appears. | The whole AI launches with velocity `(7, -13)`. No pool. |
| 6700 onward | Fixed-step physics on the projectile: gravity, a bounce whenever it comes down onto platform height (`vy * -0.4`, `vx * 0.7`). Physics stops once it passes y 300. | The head rolls off the left edge. The pool widens from 4 to 60 world px over 3.4 s. | The AI rockets off the top right corner in about 0.15 s. When it passes x 240, about 0.25 s after launch, `theme(1)` switches the stage to the CHATBOT daytime sky and sun. It keeps flying, and later bounces, far off-screen; the bounce has no x check because neither projectile is ever on screen when it comes back down. |
| 7800 | The line types into the message label. | "It's our time now" in red. | "Humanity is safe at last." in white. |
| 11500 | State 5. On the next tick the end-screen path in `on_tick` finds the line complete, clears `sub` and shows the rematch prompt. | LEDs red. | LEDs gold. |

The one-shot moments use the victim's `cut` field: `nil` before the strike, 0 during the hitstop, the winner index after the launch, and 3 once the daytime switch has fired, so nothing runs twice on a jittery tick.

The strike must be a one-shot for more than tidiness. In LVGL, un-hiding an object that is already visible still invalidates its whole area, and the overlay is the whole screen. An earlier build called `W.over:hidden(false)` on every tick of the flash, so each of those ticks forced a full-screen redraw with the translucent white blended over every widget, on top of the six LEDs at full white. That build occasionally froze the badge on battery during the flash. Now the overlay is shown once, it is fully opaque so LVGL skips everything underneath it instead of blending, and the LEDs flash at 150, the same brightness the countdown already uses. `draw()` reads `cut == 2` for the lying-flat pose.

Start skips to the menu at any point. `place()`, which the menu and a rematch call, undoes everything the cutscene changed: `Z` back to 1, attack box size and colour, overlay back to black at 130, message colour white, hills and clouds shown, pool hidden, and the real stage theme.

## 13. LEDs

`leds(now)` runs every 50 ms. LEDs 1, 6 and 5 are your side and 2, 3 and 4 the AI's; the loop picks the fighter with a six-byte lookup string, `F[("\1\2\2\2\1\1"):byte(k)]`.

| State | LEDs |
|---|---|
| 1 menu | Difficulty color: dim green, amber, or red, rows 1 to 3 of a 15-byte colour string |
| 2 countdown | White brightening with each count, green on FIGHT! |
| 3 play | Each side fades green to red as that fighter's damage climbs from 0 to 100%. White for 100 ms after taking a hit. |
| 4 cutscene | Heartbeat every 400 ms, red for the AI, yellow for you. All six at 150 white for the 200 ms strike in either ending. |
| 5 ko | Winner's body color on all six, rows 4 and 5 of the same string |

The damage ramp is integer arithmetic: `t = min(dmg, 100) * 3`, red `min(150, t)`, green `min(150, 300 - t)`. Red reaches full at 50% damage, green reaches zero at 100%. An earlier float version of the same ramp produced 59 and 29 instead of 60 and 30 at 80% and 90% damage because of rounding; the integer form is smaller and exact.

## 14. Memory: the real budget

This is the biggest constraint that determined the game's direction.

The badge reports about 76 KB of free system heap with the launcher open, with a largest contiguous block of about 62 KB. Opening an app compiles its Lua source in that space. Every function, table, string, and constant array becomes a separate heap allocation with its own bookkeeping overhead, on top of about 16 KB for the Lua runtime itself.

A build that grew to 16.1 KB of source failed to open with:

```
Lua memory limit exceeded (used 41855 / limit 98304, peak 48125)
```

Used and peak are far below the 96 KiB quota. The message is the badge's generic error for the system allocator returning nothing. The quota was never the limit. Physical RAM was.

Findings from that failure:

- **Source text size does not matter.** A minified copy of the same file, with identical bytecode, failed the same way. Comments and whitespace cost nothing, which is also why `last_fight.min.lua` fits exactly as well as the readable file.
- **Compiled size does.** Stripped bytecode from `luac -s` is the proxy. The largest build known to run was 13,994 bytes; the one that failed was 15,286. Treat 14.0 KB as the ceiling. The current file compiles to about 11.0 KB.
- **Measure with the right Lua.** The badge runs Lua 5.5 (it logs `_VERSION` as `Lua 5.5`), which is also what Homebrew's `luac` is. Lua 5.4's `luac` stores integer constants in 9 bytes where 5.5 uses 2 to 5, so its numbers run about 6% high; use plain `luac`.

Widgets are cheap, roughly 140 bytes each, and are allocated only after compilation succeeded. The game's fifty-two widgets are not the problem. Code is.

## 15. Optimizations

The compiled size went from 13,994 bytes to about 12.3 KB, which is what paid for the win cutscene, and a second pass took it to about 11.0 KB. Changes, roughly in order of how much they saved, all verified to leave the game's visible behaviour byte-for-byte identical with the harness in section 16:

- **Data as strings, not tables.** Every integer literal outside the small immediate range, which includes every 0xRRGGBB colour, is a constant-table entry in each function that uses it, plus instructions to load it and store it into a table. Packing the theme rows, AI parameters, hill geometry, cloud rows and menu LED colours into binary strings and decoding them with `string.unpack` or `string.byte` costs 1 to 3 bytes per value. This was the single biggest win.
- **One scene setup.** `menu()`, `start()` and the cutscene setup in the KO handler were three copies of the same hide-and-restyle work. They became `place(m, now)`, and states became integers so `st = m` is one store.
- **Draw everything through the camera.** `draw()` used to place boxes directly and the cutscene had its own copies of the same arithmetic. Routing `draw()` through `wb()` and adding `frame()` removed four hand-written placement sequences and made the cutscene reuse the fight's renderer.
- **`set_color` instead of `style{}`.** A style call builds a table each time; `w:set_color(c)` is one method call with no table. Applied everywhere a single colour changes.
- **Integer division.** `floor(x / n)` became `x // n` where both sides are integers, and the `floor` call on fighter positions moved into `wb()`.
- **`<const>` locals.** Declaring the platform geometry, gravity, step and rematch-prompt constants `<const>`, one per `local` line, lets the compiler fold them into instruction operands instead of upvalue loads. About 340 bytes.
- **Fewer, shared constants.** `badge.led` and `math.min` cached in locals; "You" and "AI" in one table used by the HUD and the fall message; fighter colours in one flat table instead of three; the platform border width stored in the theme data instead of computed.
- **Simpler logic with identical results.** The AI's attack decision factored into one boolean expression, the six-LED loop without a side table, button dispatch by button first, the punish and hop flags merged since they were only ever set together, constant-valued multiple assignments split into single stores (each is one instruction with a constant operand), and a spec-string loop for the seven labels.
- **Dropping fields that are always set before use.** The fighter constructor no longer initialises `face`, `stk` or the AI parameters.
- **Earlier rounds** (before this pass): blood particles removed, stock hearts became dots, the theme table flattened, background widgets shared across stages, camera helpers inlined, LED chase simplified, `floor` as a local, stars from a formula.

The second pass, about 1,350 bytes, came from reading the `luac -l -l` listing with the Lua 5.5 cost model in mind. Every arithmetic operator emits a metamethod-fallback instruction after itself, so each `+ - * /` costs 8 bytes; every float constant costs 9 bytes; a table field read is an instruction plus a string constant; a `k and A or B` expression costs six instructions. What paid:

- **String functions as methods.** `("fmt"):unpack(s, i)` and `(s):byte(i, j)` compile to one `SELF` instruction and drop the `string` global lookup and its constant from each function that used it.
- **Cache repeated reads in locals.** Inside `step`, the fighter's `x`, `y`, `vy`, `atk` and `air` are read into locals once and the table is written back once; `badge`, `math.abs`, `badge.input.is_down`, `badge.ui.label` and `W.msg` are locals or upvalues where they are used more than twice. Each table read saved is 4 bytes plus, often, a constant.
- **Branches instead of `k and A or B` chains.** The launch velocities are one `if k then ... else ... end` with constant-operand stores, 40 bytes less than four conditional expressions.
- **Cutscene time in tenths.** `h = t // 100` makes every phase threshold an immediate operand instead of a load and compare, and reuses the division the tremble already did.
- **Fewer operators.** The zoom is `2.2 - u * u / 1875000` with `u = min(0, t - 1500)` (one operator and one float fewer than `2.2 - 1.2 * (1 - t/1500)^2`, same curve); the walk-in is `min(-176, ...)` on the negated coordinate so the mirror is `300 + x` or `-x`; `(atk + 1) % 18` replaces a compare and reset; `dmg // 8` replaces `floor(dmg / 8)`; the pool width folds its `+ 4` into the time offset; the attacker is placed by the walk-in formula from the first tick, so the KO handler no longer positions it.
- **One head call in `draw`.** The lying-flat pose only changes the head's y, so the head is placed once after the branch.
- **`<const>` on the theme string** so it loads straight into the argument register, and `PY + 0` where a field is set to `PY`: a bare `<const>` name on the right of a field store compiles to a load and a store, while any folded expression becomes one store with a constant operand.
- **The AGI line rides in `sub`.** The KO handler picks the end line for every difficulty from one six-entry table; the cutscene types it from `sub`, and when it sets state 5 the ordinary end-screen path in `on_tick` sees the line is already fully shown, clears `sub` and shows the rematch prompt. `hint()` was inlined at its three call sites.
- **Invariants that make a check redundant.** A dead fighter always has `atk` 0, so `draw` no longer tests `dead`; neither cutscene projectile is on screen when it comes back down, so the bounce has no x-range check; the hint label's text is empty exactly when it used to be hidden, and an empty label draws nothing, so the `hidden` toggles went; the first-tick `last` initialisation went because `acc` is reset when a fight starts and is unread before; the countdown's clamp to zero went because the elapsed time is always under 3.6 s in that branch.
- **Hit test as a range.** `abs(a - b) < n` became `d > -n and d < n` on a difference computed once, which also removed `math.abs` from `step`; `atk // 5 == 1` is the active window of steps 5 to 9 in one comparison.
- **Shared arithmetic.** The knockback velocities share one product: `kb = 3 + dm * 0.06`, `vx = d * kb`, `vy = (kb + 1) / -2`, which is bit-identical to `-(2 + dm * 0.03)` for every damage value and drops a float constant.
- **Derived flags tested at the use site.** The AI's hop and recover flags were `di == 3` and `di > 1` stored in fields; testing `di` where they are read costs the same per use and removed the stores.
- **HUD widgets on the fighter.** The damage label, stock dots and name tag moved from three parallel arrays onto the fighter table, which removed three tables and eleven upvalue references.
- **One colour string for LEDs.** The menu colours and the two winner colours share one 15-byte string indexed by state, replacing the shift-and-mask split of the fighter colour.
- **String literals joined with `\z`** instead of `..`, which the compiler does not fold.
- **Timers without a floor.** Stun, block cooldown and the AI's block timer decrement unconditionally and are tested with `<= 0`, which removes a compare and branch per timer per step.
- **Presses written into the input table** by `on_button` instead of two latch variables copied in every step.
- **Module locals grouped** so the nil ones share one instruction, and `box()` moved inside `on_enter` so it needs no root upvalue.
- **AI parameters in the difficulty row** decoded by the same `unpack` as the stage colours.

Measured and rejected: the factory table form `badge.ui.box{...}` is larger than positional calls; shortening field names to one letter saved little (Lua 5.5 deduplicates identical strings across the whole chunk, so a name is paid for once, not once per function); dropping the draw caches saved bytes but adds LVGL work every tick; inlining `cut`, `ainp`, `leds` and `draw` into `on_tick` would save about 270 bytes at a real cost in readability and is held in reserve; caching `badge.ui` and `badge.input` in upvalues and other single-use locals measured at zero; folding the walk multiplier into the speed field is one ulp off for CHATBOT.

Runtime allocations are minimal as well. Input tables are reused, no widgets are created after `on_enter`, and per-tick garbage is limited to the HUD string when damage changes and the decoded theme locals when a stage is applied.

## 16. Testing without a badge

Most iteration happened without hardware, with a desktop Lua 5.5, the version the badge runs.

`tools/trace.lua` is a visual-equivalence harness. It stands in a fake `badge` table whose widgets record every state change, gives `badge.sys.ms` a simulated clock and `badge.sys.random` a fixed seed, and scripts a full session: cycling the difficulty selector, idling to a loss on all three difficulties including the loss cutscene, an aggressive scripted player who chases and attacks and reaches the win ending, rematches, and returns to the menu. It writes one line per widget property that changed on each tick, plus every LED frame, about 39,000 lines. Run it before and after a change and `cmp` the two files: identical output means the game looks identical. Every optimization in section 15 was accepted only on an identical trace, and the harness caught a wrong-sign bug in the win cutscene's flash within minutes.

It also raises an error if any coordinate or size is not an integer, since LVGL rejects fractional values, and it reports which texts were seen so you can confirm a scenario reached the ending it was meant to.

Alongside that, `luac -p` checks syntax, `luac -s` gives the bytecode size to hold against the ceiling in section 14, and `luac -l -l` shows per-function instruction counts and constant tables when hunting for bytes.

## 17. Things that did not work

- **Two-badge multiplayer.** The original design was a 1v1 fighter over the badge radio: each badge simulates its own fighter, broadcasts position and state, and the receiver decides whether it was hit. Pairing was going to be a physical bump detected by the accelerometer. On firmware v0.1.2-392, `badge.radio.enable()` consumed about 47 KB during Bluetooth initialization and then timed out waiting for host sync, even for the vendor's own 1.7 KB demo. Netplay is blocked at the firmware level. The AI opponent replaced it.
- **Pixel-art sprites.** The plan was to generate LVGL image files at launch from palette strings and animate by showing and hiding image widgets. Each frame costs about 1.2 KB of RAM and mirrored facings need separate files. The memory was not there. Fighters stayed as boxes.
- **Rendering tricks for memory.** Hiding widgets, parking them off-screen, drawing less often, or creating them lazily change nothing about the compile-time failure, because it happens before the first widget exists.

## 18. Function index

| Function | Role |
|---|---|
| `spawn(f, x)` | Reset a fighter's motion and combat fields at x, above the platform |
| `hudup(c)` | Rewrite damage labels and stock dots; `c` hides all dots for a cutscene |
| `typ(w, tx, t)` | Typewriter reveal, returns true when done |
| `wb(w, x, y, ww, hh)` | Place a widget from world coordinates through the zoom `Z` |
| `draw(f)` | Position a fighter's three boxes through `wb`, with change caching |
| `frame()` | Draw platform, dirt and both fighters at the current zoom |
| `theme(d)` | Decode and apply the stage theme for difficulty `d` (default: selected) |
| `place(m, now)` | Set up the scene for state `m` and enter it |
| `cut(now)` | Run the AGI cutscene, win or loss, for the current tick |
| `ainp(f, o)` | AI: fill in the AI fighter's inputs |
| `step(f, o)` | One 20 ms physics and combat step for a fighter |
| `leds(now)` | Set the six LEDs for the current state |
| `box(...)` (inside `on_enter`) | Create a styled box in one call |
| `on_enter`, `on_tick`, `on_button`, `on_exit` | Badge callbacks |
