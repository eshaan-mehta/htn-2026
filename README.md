# Humanity's Last Fight

<img src="icon.png" width="84" height="84" alt="Humanity's Last Fight icon" class="center-block" >

HELP! AI is taking over and it's your job to save the species against the rise of AGI. Fight back against the AI revolution in a one-on-one platform fighter for the **Hack the North 2026 Hacker Badge**

You play a human. Your opponent is an AI. Knock it off the stage three times before it does the same to you.

## The game

Smash-style rules: there are no health bars. Every hit you land adds damage percent to your opponent, and the higher their damage, the further they fly when you hit them. Knock them off the edge of the platform and they lose a stock. There are 3 levels of difficulty

Pick a difficulty on the title screen. Each one is a different opponent and a different stage:

| Difficulty | Opponent | Stage |
|---|---|---|
| **CHATBOT** | AI from 2022. Slow, rarely blocks, never recovers if it falls. | Daytime hills |
| **AGENT** | Modern AI. Faster, blocks, jumps back to the stage when knocked off. | Sunset |
| **AGI** | Punishes your whiffs, double-jumps, reads your attacks. | Something has gone wrong |

Try beating AGI if you can (even I haven't been able to yet)

### Controls

**Title screen**

| Button | Action |
|---|---|
| Left / Right | Change difficulty |
| A | Start |

**In a fight**

| Button | Action |
|---|---|
| Left / Right | Move |
| Up | Jump. Press again in the air to double jump. |
| A | Attack |
| B (hold) | Block. Blocking only works on the ground and only from the front. Releasing it puts you on a short cooldown. |
| Start | Back to the title screen |

**After a KO**

| Button | Action |
|---|---|
| A | Rematch |
| B | Title screen |

The badge LEDs track the fight. Your three LEDs and the AI's three LEDs shift from green to red as damage climbs, and flash white on a hit.

## How it works

If you would like to learn more, read [IMPLEMENTATION.md](IMPLEMENTATION.md). It explains everything from the rendering hack that made this possible, the physics and combat rules, how each AI difficulty is tuned, the cutscenes, the badge's memory constraints and optimizations.

## Flashing it onto your badge (Build from source)

You need a desktop Chrome or Edge browser, a USB-C **data** cable, and the badge IDE at **https://badge.hackthenorth.com/ide/**.

1. Copy the entire contents of [`last_fight.lua`](last_fight.lua), including the `--[==[badge-app ... ]==]` header at the top.
2. Open the [Badge IDE](https://badge.hackthenorth.com/ide/). If you have work in the editor already, save it first with **Download app**.
3. Click **Import app** and paste the whole file. Check that the slug shows as `last_fight`, then click **Replace editor files**.
4. Optional but recommended: download [`icon.png`](icon.png) from this repo, click **Choose image** in the IDE, and select it. This gives the game a proper launcher icon instead of the `HLF` text fallback. The image is already 42×42, the badge's icon size, so it needs no cropping.
5. Turn the badge **off**, plug in the USB-C cable and enable the connection from your computer
6. Click **Connect** and choose **USB JTAG/serial debug unit** (sometimes labelled Espressif) in the browser's device picker. Close any other tabs or tools using the badge's serial port first.
7. Click **Push** and keep the cable connected until the upload finishes.
8. Find **Humanity's Last Fight** in the badge launcher and press **A**.

**Troubleshooting:** if the app fails to open with `Lua memory limit exceeded` in the IDE console, the badge did not have enough free RAM to compile the file. Reboot the badge and try opening the app again straight from the launcher. 

## Share it with others :)

The badge's built-in **Share** app sends any installed app to another badge over Bluetooth.

On your badge, open **Share → Send an app**, pick **Humanity's Last Fight**, and press **A: offer app**. Leave that screen open. On your friend's badge, open **Share → Receive an app** and press **A: accept**. Keep the badges close and still until the transfer finishes, and the game will show up in their launcher.

Now go save humanity against the rise of AI!
