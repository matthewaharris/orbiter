# Orbiter

A gravity-slingshot game: set your launch angle, power, and **timing**, then let planets, stars,
and space weather carry your ship to the portal. It plays in 2D, but every planet, star, and ship is
rendered in full 3D, and you can drop into a 3D chase cam mid-flight.

Inspired by the early-2000s flash slingshot games. Play is organized into roguelite runs, and
KSP-style ship building is planned.

## How a run works

- Clear the sectors in order. **Every launch burns 1 fuel cell**, and **crashing costs 1 hull**.
- The run ends when your hull or fuel hits 0, or when you clear the last sector.
- Clearing a sector gives +3 fuel and stardust. A first-try clear adds +1 fuel and +5 stardust;
  clearing without the aim preview adds +10 stardust.
- After each clear, **pick 1 of 3 upgrades** (catalog in `game/scripts/upgrades.gd`):

| Upgrade | Effect |
|---|---|
| Kick Booster | Tap SPACE mid-flight to thrust toward your cursor (charges per launch) |
| Singularity Seed | Right-click while aiming to place a black hole; right-click it again to pick it up |
| Long-Range Sensors | Longer aim preview |
| Hull Plating | +1 max hull |
| Deflector Shield | Bounce off one planet impact per launch |
| Magnetic Shield | Wind, storms, and CMEs push you 45% less |
| Overcharged Bands | +15% launch speed |
| Portal Magnet | Bigger portal catch radius |
| Fuel Cache / Field Repair | Consumables: +4 fuel / +2 hull |

- Stardust is banked between runs (saved to `user://orbiter_save.cfg`); Phase 3 will spend it on ship parts.

- Design and roadmap: [`docs/PLAN.md`](docs/PLAN.md)
- Planet, star, and hazard design: [`docs/WORLD_SCHEME.md`](docs/WORLD_SCHEME.md)

## Run it

1. Install **Godot 4.7** (standard, not .NET): `winget install GodotEngine.GodotEngine`
2. Open Godot → **Import** → pick `game/project.godot` → **Run** (F5)

## Controls

| Input | Action |
|---|---|
| Drag the mouse (pull back from the slingshot) | Set angle and power |
| A/D or ←/→ | Fine-tune angle (hold **Shift** for extra fine) |
| W/S or ↑/↓ | Fine-tune power |
| **Space** | Launch (mid-flight: boost, if you have Kick Booster) |
| **Right-click** | Place / pick up a black hole (Singularity Seed) |
| 1 / 2 / 3 | Pick an upgrade card |
| **C** / Tab | Toggle the 3D chase cam |
| **P** | Toggle the aim preview (off = hard mode) |
| **R** | Reset the ship |
| Enter / click | Start a new run after the run ends |

## Project layout

```
game/                 Godot project (open game/project.godot)
  scenes/main.tscn    Game shell: environment, sky, cameras
  scenes/levels/      One .tscn per level: edit these in the Godot editor
  scripts/            GDScript (planet.gd, star.gd, ship.gd, main.gd ...)
  shaders/            Procedural planet / star / sky / portal shaders
  data/planets/       PlanetType archetypes (.tres): tweak colors and weather in the inspector
  assets/models/      .glb models exported from Blender
tools/blender/        Python scripts that build the 3D models
docs/                 Design docs
```

## Making a level (great first task!)

1. In Godot, duplicate `scenes/levels/level_01.tscn`.
2. Drag planets around. They render live in the editor. Change `radius`, `mass`, and `planet_type`.
3. To make a moon, set **Orbit → Orbit Center** to another planet and give it an `orbit_radius`.
4. Add the new file to the `LEVELS` list in `scripts/game.gd`.
5. Check that it's beatable: `godot --headless --path game -- --solve`

## Rebuilding 3D models

```
blender --background --factory-startup --python tools/blender/build_ship.py
blender --background --factory-startup --python tools/blender/build_portal.py
```

Each script exports to `game/assets/models/` and renders a preview to `tools/blender/previews/`.

## Developer command-line flags

Pass these after `--`, for example `godot --path game -- --level=3 --chase`:

| Flag | Effect |
|---|---|
| `--level=N` | Start the run on sector N |
| `--upgrades=boost,singularity,...` | Grant upgrades (ids from `upgrades.gd`) |
| `--hull=N`, `--fuel=N` | Override starting hull / fuel |
| `--hole-at=X,Y` | Place a black hole (needs `--upgrades=singularity`) |
| `--boost-at=SEC` | Auto-boost toward the portal SEC seconds after `--launch-at` |
| `--picker` | Open the upgrade picker immediately |
| `--aim=DEG,POWER` | Preset the aim, e.g. `--aim=16,0.7` |
| `--launch-at=SEC` | Launch automatically after SEC seconds |
| `--chase` | Start in the chase cam |
| `--no-preview` | Start with the preview off |
| `--shot=out.png --shot-delay=SEC` | Save a screenshot, then quit |
| `--solve` | Brute-force every level and report how many launches win |

## Collaborating

- `main` should always run. Do your work on a branch: `git switch -c my-feature`.
- Open a pull request on GitHub, and get the other person to play it before merging.
