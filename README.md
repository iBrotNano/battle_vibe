# NEON CARNAGE

A 2D cyberpunk **beat 'em up** for Godot 4, built entirely in GDScript, with procedural districts and endless Diablo-style character progression.

> The city is a machine that eats the poor. Gangs sell chrome, guns and dreams by the gram.
> You are **VEX** — a slab of muscle and bad wiring with nothing left to lose.
> Fight through the sprawl, take their augments, get stronger. Forever.

![Godot 4.5](https://img.shields.io/badge/Godot-4.5-478cbf) ![GDScript](https://img.shields.io/badge/GDScript-100%25-ff2e88)

## Features

- **Arcade beat 'em up combat** — ground-plane movement (X/Y depth), 3-hit light combo, heavy breaker, i-frame dash and an Overclock shockwave burst.
- **Procedural districts** — every run generates a new sequence of arenas, waves, gang compositions, city backdrops and neon signage from a seed.
- **Endless leveling** — infinite character levels, 3 stat points per level and no cap. Allocate points in real time with keys `1-4`.
- **Diablo-style loot** — auto-equipping weapons, armor and implants with five rarities and randomized cyberpunk affixes (damage, crit, lifesteal, armor, energy…). Worse drops are salvaged into credits.
- **Enemies scale with your power** — a threat value derived from level, total stats, gear power and district depth scales enemy HP, damage, speed and rewards. Elites appear as districts deepen.
- **Four enemy archetypes** — pipe thugs, ranged gunners, armored bruisers and diving drones, with telegraphed attacks and stagger.
- **Cyberpunk presentation** — 100% procedural vector art: parallax skyline, Japanese neon signs, wet asphalt reflections, rain, scanlines, vignette, screen shake, hitstop, damage numbers and sparks.
- **Procedural audio** — 22 synthesized cyberpunk sound effects (punches, swings, gunfire, dashes, level-up chimes, gates, portals, UI) generated at boot with no audio files.
- **Roguelite reboot** — flatline and reboot the current district for 25% of your XP; levels and gear survive.

No external art or audio assets are required. Every sprite, backdrop, effect and sound is generated with GDScript.

## Running

1. Install **Godot 4.3+** (developed and validated on 4.5).
2. Open `project.godot` in the Godot editor.
3. Press **F5** (or run `godot --path .`).

The main scene is `scenes/Main.tscn`. Everything else is built at runtime from `scripts/`.

## Controls

| Action | Keys |
| --- | --- |
| Move (X + depth) | `WASD` / arrow keys |
| Light attack (combo) | `J` / left mouse |
| Heavy attack | `K` / right mouse |
| Dash (i-frames) | `Space` / `Shift` |
| Overclock burst (50 EN) | `Q` |
| Spend stat points | `1` Strength · `2` Vitality · `3` Agility · `4` Tech |
| Fullscreen | `F11` |
| Cycle window resolution | `F10` |
| Mute / unmute audio | `M` |
| Start / reboot | `Enter` / `R` |
| Quit | `Esc` |

## Display and resolution

The game is authored at a **1280×720 design resolution** and scaled with Godot's `canvas_items` stretch mode, so fullscreen and any window size still look crisp and keep the HUD layout intact.

- The game starts in **fullscreen by default**.
- Press **F11** at any time to toggle fullscreen / windowed mode.
- Press **F10** while windowed to cycle: 1280×720, 1600×900, 1920×1080, 2560×1440 and the native desktop resolution (options larger than your monitor are skipped). Pressing F10 in fullscreen returns to a window at the next size.
- Choices are saved to `user://neon_carnage.cfg` and restored on the next launch.

To change the base design resolution itself (e.g. author at 1920×1080), edit `window/size/viewport_width` and `viewport_height` in `project.godot`; note that the HUD uses 1280×720 coordinates, so its positions would need scaling.

## Audio

There are no audio files in the project. The `Sfx` autoload (`scripts/audio.gd`) synthesizes every sound into `AudioStreamWAV` buffers at boot and plays them through a pool of 24 positional `AudioStreamPlayer2D` nodes and 8 UI players.

- Swings, impacts, dashes, Overclock, gunfire and deaths are positional: they pan and attenuate relative to the camera.
- UI, loot, level-up, sector-clear and district-clear cues are non-positional so they are always audible.
- Press **M** at any time to mute or unmute. The choice lasts for the session.
- Volume follows the Godot **Master** bus, so it also respects your system volume and any mixer settings you add later.

To add or reshape sounds, edit the generator helpers in `scripts/audio.gd` (`_whoosh`, `_impact`, `_chime`, `_gunshot`, …) and the mapping in `_generate_all()`. Call them with `Sfx.play("name", world_position, volume_db, pitch)` or `Sfx.play_ui("name", volume_db, pitch)`.

## How the game works

### Combat
Attacks resolve on the ground plane within a forward reach and a forgiving depth window. Hits grant energy, trigger hitstop, shake, sparks and damage numbers. The third light hit and the heavy attack are combo finishers. Player damage scales with **Strength** and weapon affixes; crit scales with **Tech**.

### Stats
| Stat | Effect |
| --- | --- |
| Strength | melee damage |
| Vitality | max HP + damage reduction |
| Agility | move speed, attack rate, dash cooldown |
| Tech | crit chance/damage, implant energy |

### Threat scaling
`Game.threat()` combines level, total allocated stats, equipped gear power and district depth. Enemies compute HP, damage, speed and XP from it at spawn, so loot and stat choices immediately make the streets meaner — but richer.

### Districts and arenas
`Level` generates 3–5 arenas per district. Entering one locks neon gates, spawns 2–4 waves and scales enemy mix by district. Clearing all waves grants XP, a guaranteed piece of loot, credits and healing. Reaching the end of the district advances to a newly generated district with a higher threat level.

### Progression loop
Kill → XP/loot/credits → level up (3 points) → spend points + equip better gear → threat rises → enemies get stronger and drop better gear → repeat endlessly.

## Project layout

```
project.godot            Autoloads (Game, Fx, Settings, Sfx), input map is registered by Game
scenes/Main.tscn         Minimal root; the game is assembled in code
scripts/
  game.gd                Autoload: leveling, stats, threat, gear, signals
  fx.gd                  Autoload: hitstop, shake, flashes, damage numbers
  audio.gd               Autoload: procedural SFX synthesis + pooled playback
  settings.gd            Autoload: fullscreen / window size, persisted config
  main.gd                Run flow, camera, atmosphere, district transitions
  level.gd               Procedural arenas, waves, gates, rewards
  backdrop.gd            Parallax city, skyline, street, neon, props
  player.gd              Movement, combo/heavy/dash/burst, vector-art body
  enemy.gd               Thug / gunner / bruiser / drone AI and art
  actor.gd               Shared ground-plane actor + death/knockback
  loot.gd                Rarity rolls, affixes, item names
  hud.gd                 HUD, title, death screen, banners, stats/loot UI
  hud_panel.gd, ui_bar.gd, rain.gd, projectile.gd, spark.gd,
  shockwave.gd, damage_number.gd
```

## Tuning

- **Player power curve / scaling:** `scripts/game.gd` → `derived()` and `threat()`.
- **Enemy base stats and scaling:** `scripts/enemy.gd` → `configure()`.
- **Loot frequency/rarity/affixes:** `scripts/loot.gd` and `Game.award_loot()`.
- **Arena count, widths, wave sizes, enemy mix:** `scripts/level.gd`.
- **Combat timing/reach/damage multipliers:** constants at the top of `scripts/player.gd`.

## Possible next steps

- Persistent save/load between sessions.
- Music/ambient loops and gamepad support.
- Character/skill trees beyond flat stats, active implant abilities.
- A vendor or stash to compare gear instead of auto-equip.
- Hand-drawn sprite sheets layered over the current procedural silhouettes.

## License

MIT — see `LICENSE`.
